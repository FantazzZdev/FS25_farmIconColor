-- ============================================================================
-- FS25_farmIconColor - Shared custom logos (server catalog + network transfer)
-- ============================================================================
-- Lua cannot read the bytes of a .dds file, but it can read text from an XML
-- file, send strings over the network and write binary files. A "logo package"
-- is therefore an XML file holding the original DDS encoded in Base64. It is
-- created by tools/logo-converter (outside the game).
--
--   ADMIN  customLogos/MyLogo.xml --Import--> (client admin: upload in chunks)
--   SERVER validates, stores the catalog in savegameX/farmIconColorLogos.xml,
--          announces it (manifest) to every client
--   CLIENT downloads only the missing logos, verifies size + Adler-32,
--          writes modSettings/FS25_farmIconColor/cache/<adler>_<bytes>.dds
--          and registers the logo in FarmIconColor.logos
--
-- The existing farmId/color/logoName sync (FarmIconColorSyncEvent) is untouched:
-- a shared logo simply has the same id on every machine.
-- ============================================================================

FarmIconColorLogoSync = {}
local LS = FarmIconColorLogoSync

LS.CATALOG_FILE_NAME = "farmIconColorLogos.xml"
LS.PACKAGE_ROOT = "farmIconColorLogo"
LS.CHUNK_SIZE = 4096                -- Base64 characters per network event
LS.MAX_LOGOS = 64
LS.MAX_BYTES = 512 * 1024           -- decoded DDS size limit
LS.MAX_BASE64 = math.ceil(LS.MAX_BYTES / 3) * 4
LS.MAX_CHUNKS = math.ceil(LS.MAX_BASE64 / LS.CHUNK_SIZE)
LS.MAX_NAME_LENGTH = 48
LS.SEND_INTERVAL = 50               -- ms between two send batches
LS.CHUNKS_PER_SEND = 2
LS.UPLOAD_CONFIRM_TIMEOUT = 20000  -- ms without server confirmation before warning the admin
LS.HELLO_DELAY = 2000               -- ms after joining before asking the manifest
LS.deletedPackages = {}
LS.deletedLocalLogos = {}
LS.catalogById = {}

-- ------------------------------------------------------------- utilities ---

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_MAP = {}
for i = 1, 64 do
    B64_MAP[string.byte(B64_ALPHABET, i)] = i - 1
end

function LS.cleanBase64(text)
    return (string.gsub(tostring(text or ""), "[^%w%+/=]", ""))
end

function LS.base64Decode(text)
    local out, n = {}, 0

    if #text % 4 ~= 0 then
        return nil
    end

    for i = 1, #text, 4 do
        local c1, c2, c3, c4 = string.byte(text, i, i + 3)
        local v1, v2 = B64_MAP[c1], B64_MAP[c2]

        if v1 == nil or v2 == nil then
            return nil
        end

        local v3 = B64_MAP[c3] -- '=' (padding) -> nil
        local v4 = B64_MAP[c4]
        local triple = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        local b1 = math.floor(triple / 65536)
        local b2 = math.floor(triple / 256) % 256
        local b3 = triple % 256

        n = n + 1
        if v4 ~= nil then
            out[n] = string.char(b1, b2, b3)
        elseif v3 ~= nil then
            out[n] = string.char(b1, b2)
        else
            out[n] = string.char(b1)
        end
    end

    return table.concat(out)
end

function LS.adler32(data)
    local a, b = 1, 0

    for i = 1, #data do
        a = (a + string.byte(data, i)) % 65521
        b = (b + a) % 65521
    end

    return b * 65536 + a
end

local function readU32le(data, offset)
    local b1, b2, b3, b4 = string.byte(data, offset + 1, offset + 4)
    return (b1 or 0) + (b2 or 0) * 256 + (b3 or 0) * 65536 + (b4 or 0) * 16777216
end

-- Minimal structural check of a DDS file (magic, header size, sane dimensions).
function LS.isValidDds(data)
    if type(data) ~= "string" or #data < 128 or string.sub(data, 1, 4) ~= "DDS " then
        return false
    end

    local headerSize = readU32le(data, 4)
    local height = readU32le(data, 12)
    local width = readU32le(data, 16)

    return headerSize == 124 and width >= 16 and height >= 16 and width <= 1024 and height <= 1024
end

function LS.sanitizeName(name)
    local text = tostring(name or "")
    text = string.gsub(text, "[%c<>\"&]", "")
    text = string.sub(text, 1, LS.MAX_NAME_LENGTH)

    if text == "" then
        return nil
    end

    return text
end

function LS.getCacheFilename(entry)
    local directory = FarmIconColor:getModSettingsSaveDirectory()

    if directory == nil then
        return nil
    end

    local cacheDirectory = FarmIconColor:joinPath(directory, "cache")
    FarmIconColor:ensureFolderExists(cacheDirectory)

    return FarmIconColor:joinPath(cacheDirectory, string.format("%d_%d.dds", entry.adler, entry.bytes))
end

function LS.writeBinaryFile(path, data)
    if type(createFile) ~= "function" or type(fileWrite) ~= "function" or FileAccess == nil then
        return false
    end

    local okOpen, handle = pcall(createFile, path, FileAccess.WRITE)
    if not okOpen or handle == nil or handle == 0 then
        return false
    end

    local okWrite = pcall(fileWrite, handle, data)
    pcall(delete, handle)

    return okWrite and (fileExists == nil or fileExists(path))
end

function LS.notify(textKey, fallback, value, isError)
    local mission = g_currentMission

    if mission == nil or mission.addIngameNotification == nil or g_client == nil then
        return
    end

    local text = string.format(FarmIconColor:getTranslatedText(textKey, fallback), tostring(value or ""))
    local notificationType = nil

    if FSBaseMission ~= nil then
        notificationType = isError and FSBaseMission.INGAME_NOTIFICATION_CRITICAL or FSBaseMission.INGAME_NOTIFICATION_OK
    end

    pcall(function()
        mission:addIngameNotification(notificationType, text)
    end)
end

-- ------------------------------------------------------------- lifecycle ---

function LS:loadMap()
    self.catalog = {}          -- ordered list of entries
    self.catalogById = {}
    self.incoming = {}         -- [senderKey][logoId] = assembly
    self.outQueue = {}         -- { {connection=, event=} }
    self.sendTimer = 0
    self.helloTimer = 0
    self.helloSent = false
    self.pendingPackageFiles = nil
    self.catalogHadEntries = false
    self.pendingUploads = {}   -- [logoId] = {name=, elapsed=} until the server confirms
    self.localOnlyNotified = {}
    self:loadDeletedList()

    if FarmIconColor:isAuthoritativeInstance() then
        FarmIconColor:safeCall("load shared logo catalog", function()
            self:loadCatalogFromSavegame()
        end)
    end
end

function LS:deleteMap()
    self.catalog = {}
    self.catalogById = {}
    self.incoming = {}
    self.outQueue = {}
end

function LS:update(dt)
    if self.catalog == nil then
        return
    end

    -- A multiplayer client asks the server for the logo manifest once.
    if not self.helloSent and FarmIconColor:isClientOnlyMultiplayer() then
        self.helloTimer = self.helloTimer + dt

        if self.helloTimer >= self.HELLO_DELAY then
            local connection = g_client ~= nil and g_client:getServerConnection() or nil

            if connection ~= nil then
                self.helloSent = true
                connection:sendEvent(FarmIconColorLogoEvent.newHello())
            end
        end
    end

    -- Uploads the server never confirmed (no admin rights on the server, lost
    -- connection...): tell the admin instead of failing silently.
    if self.pendingUploads ~= nil and #self.outQueue == 0 then
        for id, pending in pairs(self.pendingUploads) do
            pending.elapsed = pending.elapsed + dt

            if pending.elapsed >= self.UPLOAD_CONFIRM_TIMEOUT then
                self.pendingUploads[id] = nil
                self.notify("farmIconColor_logoUploadFailed", "The server did not accept the logo: %s", pending.name, true)
            end
        end
    end

    if #self.outQueue > 0 then
        self.sendTimer = self.sendTimer + dt

        if self.sendTimer >= self.SEND_INTERVAL then
            self.sendTimer = 0

            for _ = 1, self.CHUNKS_PER_SEND do
                local item = table.remove(self.outQueue, 1)

                if item == nil then
                    break
                end

                pcall(function()
                    item.connection:sendEvent(item.event)
                end)
            end
        end
    end
end

-- -------------------------------------------------------------- catalog ---

-- Registers a logo file in FarmIconColor so every menu/map/hotspot can use it.
function LS:registerLogo(entry, path)
    local fic = FarmIconColor

    fic.logos[entry.id] = path
    fic.customLogoPaths = fic.customLogoPaths or {}
    fic.customLogoDisplayNames = fic.customLogoDisplayNames or {}
    fic.customLogoPaths[entry.id] = path
    fic.customLogoDisplayNames[entry.id] = entry.name
    fic:addLogoToOrder(entry.id)

    -- Force visible logo elements to pick up the (possibly new) file.
    fic.farmMenuLogoApplyLogged = false
    fic.farmDialogCustomLogoApplyLogged = false
    fic.lastDialogLogoColorSignature = nil

    self:notifyLogosChanged()
end

function LS:notifyLogosChanged()
    if FarmIconColorLogoPicker ~= nil and FarmIconColorLogoPicker.onLogosChanged ~= nil then
        FarmIconColor:safeCall("refresh logo picker", function()
            FarmIconColorLogoPicker:onLogosChanged()
        end)
    end
end

-- Removes a logo from every list of FarmIconColor (menus fall back to the default logo).
function LS:unregisterLogo(id)
    local fic = FarmIconColor

    fic.logos[id] = nil

    if fic.customLogoPaths ~= nil then
        fic.customLogoPaths[id] = nil
    end

    if fic.customLogoDisplayNames ~= nil then
        fic.customLogoDisplayNames[id] = nil
    end

    for index = #(fic.logoOrder or {}), 1, -1 do
        if fic.logoOrder[index] == id then
            table.remove(fic.logoOrder, index)
        end
    end

    if fic.pendingFarmCreationLogoName == id then
        fic.pendingFarmCreationLogoName = nil
    end

    fic.farmMenuLogoApplyLogged = false
    fic.farmDialogCustomLogoApplyLogged = false
    fic.lastDialogLogoColorSignature = nil

    self:notifyLogosChanged()
end

-- Makes sure the DDS exists in the local cache, then registers it.
-- data (Base64) is only decoded when the cache file is missing.
function LS:materializeEntry(entry, decoded)
    local path = self.getCacheFilename(entry)

    if path == nil then
        return false
    end

    if fileExists == nil or not fileExists(path) then
        if decoded == nil then
            decoded = entry.data ~= nil and self.base64Decode(entry.data) or nil
        end

        if decoded == nil or #decoded ~= entry.bytes or self.adler32(decoded) ~= entry.adler or not self.isValidDds(decoded) then
            return false
        end

        if not self.writeBinaryFile(path, decoded) then
            return false
        end
    end

    self:registerLogo(entry, path)

    return true
end

-- Server/host only: adds or replaces a logo in the authoritative catalog.
function LS:addToCatalog(entry, decoded)
    local existing = self.catalogById[entry.id]

    if existing == nil and #self.catalog >= self.MAX_LOGOS then
        return false, "limit"
    end

    if not self:materializeEntry(entry, decoded) then
        return false, "invalid"
    end

    if existing ~= nil then
        for index, catalogEntry in ipairs(self.catalog) do
            if catalogEntry.id == entry.id then
                self.catalog[index] = entry
            end
        end
    else
        table.insert(self.catalog, entry)
    end

    self.catalogById[entry.id] = entry
    self.catalogHadEntries = true
    FarmIconColor:saveSavegameData("shared logo catalog")

    if g_server ~= nil and FarmIconColor:isMultiplayerGame() then
        g_server:broadcastEvent(FarmIconColorLogoEvent.newManifest(self.catalog), nil, nil, nil)
    end

    return true
end

function LS:loadCatalogFromSavegame()
    if not FarmIconColor:isExistingSavegame() then
        return
    end

    local filename = FarmIconColor:joinPath(FarmIconColor:getSavegameDirectoryForData(), self.CATALOG_FILE_NAME)

    if fileExists == nil or not fileExists(filename) then
        return
    end

    local xmlFile = loadXMLFile("farmIconColorLogoCatalog", filename)

    if xmlFile == nil or xmlFile == 0 then
        return
    end

    local index = 0

    while index < self.MAX_LOGOS do
        local key = string.format("farmIconColorLogos.logo(%d)", index)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local entry = {
            id = getXMLString(xmlFile, key .. "#id"),
            name = self.sanitizeName(getXMLString(xmlFile, key .. "#name")),
            bytes = getXMLInt(xmlFile, key .. "#bytes"),
            adler = tonumber(getXMLString(xmlFile, key .. "#adler32")),
            tintable = getXMLBool(xmlFile, key .. "#tintable") == true,
            data = self.cleanBase64(getXMLString(xmlFile, key .. ".data"))
        }

        if entry.id ~= nil and entry.name ~= nil and entry.bytes ~= nil and entry.adler ~= nil
            and self.catalogById[entry.id] == nil and self:materializeEntry(entry, nil) then
            table.insert(self.catalog, entry)
            self.catalogById[entry.id] = entry
            self.catalogHadEntries = true
        end

        index = index + 1
    end

    delete(xmlFile)
end

function LS:onGameSaved(missionInfo)
    if self.catalog == nil or not FarmIconColor:isAuthoritativeInstance() then
        return
    end

    -- An empty catalog is still written when logos were deleted, so they do not come back.
    if #self.catalog == 0 and not self.catalogHadEntries then
        return
    end

    if type(missionInfo) ~= "table" or missionInfo.savegameDirectory == nil then
        return
    end

    local filename = FarmIconColor:joinPath(tostring(missionInfo.savegameDirectory), self.CATALOG_FILE_NAME)
    local xmlFile = createXMLFile("farmIconColorLogoCatalog", filename, "farmIconColorLogos")

    if xmlFile == nil or xmlFile == 0 then
        return
    end

    setXMLInt(xmlFile, "farmIconColorLogos#version", 1)

    for index, entry in ipairs(self.catalog) do
        local key = string.format("farmIconColorLogos.logo(%d)", index - 1)
        setXMLString(xmlFile, key .. "#id", entry.id)
        setXMLString(xmlFile, key .. "#name", entry.name)
        setXMLInt(xmlFile, key .. "#bytes", entry.bytes)
        setXMLString(xmlFile, key .. "#adler32", string.format("%d", entry.adler))
        setXMLBool(xmlFile, key .. "#tintable", entry.tintable == true)
        setXMLString(xmlFile, key .. ".data", entry.data)
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

-- ------------------------------------------------- admin: local packages ---

function LS:onPackageFile(filename, isDirectory)
    if isDirectory == true or filename == nil then
        return
    end

    if string.match(tostring(filename), "%.[Xx][Mm][Ll]$") ~= nil then
        table.insert(self.pendingPackageFiles, tostring(filename))
    end
end

-- Reads customLogos/<name>.xml. Returns entry, decoded DDS  or  nil, errorKey.
function LS:readPackage(path, filename)
    local xmlFile = loadXMLFile("farmIconColorLogoPackage", path)

    if xmlFile == nil or xmlFile == 0 then
        return nil, "invalid"
    end

    local key = self.PACKAGE_ROOT .. ".logo"
    local baseName = string.gsub(tostring(filename), "%.[Xx][Mm][Ll]$", "")
    local name = self.sanitizeName(getXMLString(xmlFile, key .. "#name") or baseName)
    local bytes = getXMLInt(xmlFile, key .. "#bytes")
    local adler = tonumber(getXMLString(xmlFile, key .. "#adler32"))
    local tintable = getXMLBool(xmlFile, key .. "#tintable") == true
    local known = name ~= nil and self.catalogById[(FarmIconColor:sanitizeCustomLogoId(name))] or nil

    -- Already shared with the same content: nothing to do, skip the decoding.
    if known ~= nil and known.adler == adler and known.bytes == bytes then
        delete(xmlFile)
        return nil, "known"
    end

    -- Deleted earlier from the logo picker: ignored until the file is replaced.
    if adler ~= nil and self.deletedPackages[tostring(adler)] then
        delete(xmlFile)
        return nil, "deleted"
    end

    local data = self.cleanBase64(getXMLString(xmlFile, key .. ".data"))
    delete(xmlFile)

    if name == nil or bytes == nil or adler == nil or bytes > self.MAX_BYTES or #data > self.MAX_BASE64 then
        return nil, "invalid"
    end

    local decoded = self.base64Decode(data)

    if decoded == nil or #decoded ~= bytes or self.adler32(decoded) ~= adler or not self.isValidDds(decoded) then
        return nil, "invalid"
    end

    local entry = {
        id = (FarmIconColor:sanitizeCustomLogoId(name)),
        name = name,
        bytes = bytes,
        adler = adler,
        tintable = tintable,
        data = data
    }

    if entry.id == nil then
        return nil, "invalid"
    end

    return entry, decoded
end

function LS:importPackagesFromFolder()
    local directory = FarmIconColor.customLogoDirectory

    if directory == nil or getFiles == nil or self.catalog == nil then
        return
    end

    self.pendingPackageFiles = {}
    pcall(function()
        getFiles(directory, "onPackageFile", self)
    end)

    local files = self.pendingPackageFiles
    self.pendingPackageFiles = nil

    table.sort(files, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    for _, filename in ipairs(files) do
        local entry, decodedOrError = self:readPackage(FarmIconColor:joinPath(directory, filename), filename)

        if entry ~= nil then
            self:publishEntry(entry, decodedOrError)
        elseif decodedOrError == "invalid" then
            self.notify("farmIconColor_logoInvalid", "Invalid logo file: %s", filename, true)
        elseif decodedOrError == "deleted" then
            self.notify("farmIconColor_logoIgnored", "Deleted logo ignored, remove the file: %s", filename, true)
        end
    end
end

function LS:publishEntry(entry, decoded)
    if g_server ~= nil then
        -- Singleplayer or self-hosted host: we are the catalog owner.
        local ok, reason = self:addToCatalog(entry, decoded)

        if ok then
            self.notify("farmIconColor_logoShared", "Logo shared: %s", entry.name, false)
        elseif reason == "limit" then
            self.notify("farmIconColor_logoLimit", "Logo limit reached (%s)", self.MAX_LOGOS, true)
        else
            self.notify("farmIconColor_logoInvalid", "Invalid logo file: %s", entry.name, true)
        end

        return
    end

    -- Admin on a dedicated server: cache it locally (no re-download), then upload.
    if not self:materializeEntry(entry, decoded) then
        self.notify("farmIconColor_logoInvalid", "Invalid logo file: %s", entry.name, true)
        return
    end

    local connection = g_client ~= nil and g_client:getServerConnection() or nil

    if connection == nil then
        return
    end

    self:queueChunks(connection, entry, FarmIconColorLogoEvent.KIND_UPLOAD)
    self.pendingUploads = self.pendingUploads or {}
    self.pendingUploads[entry.id] = {name = entry.name, elapsed = 0}
    self:notifyLogosChanged()
    self.notify("farmIconColor_logoUploading", "Sending logo to server: %s", entry.name, false)
end

function LS:queueChunks(connection, entry, kind)
    local total = math.max(1, math.ceil(#entry.data / self.CHUNK_SIZE))

    for index = 1, total do
        local chunk = string.sub(entry.data, (index - 1) * self.CHUNK_SIZE + 1, index * self.CHUNK_SIZE)
        table.insert(self.outQueue, {
            connection = connection,
            event = FarmIconColorLogoEvent.newChunk(kind, entry, index, total, chunk)
        })
    end
end

-- ---------------------------------------------------------- network side ---

function LS:isConnectionMasterUser(connection)
    local userManager = g_currentMission ~= nil and g_currentMission.userManager or nil

    if connection == nil or type(userManager) ~= "table" or userManager.getUserByConnection == nil then
        return false
    end

    local ok, isMaster = pcall(function()
        return userManager:getUserByConnection(connection):getIsMasterUser()
    end)

    return ok and isMaster == true
end

-- Server: a client wants the manifest.
function LS:onHello(connection)
    if g_server ~= nil and self.catalog ~= nil and #self.catalog > 0 then
        connection:sendEvent(FarmIconColorLogoEvent.newManifest(self.catalog))
    end
end

-- Client: register what is cached, request what is missing.
function LS:onManifest(entries)
    if g_server ~= nil or self.catalog == nil then
        return
    end

    local missing = {}
    local stillShared = {}

    for _, entry in ipairs(entries) do
        local name = self.sanitizeName(entry.name)
        local id = name ~= nil and (FarmIconColor:sanitizeCustomLogoId(name)) or nil
        if id ~= nil then
            stillShared[id] = true

            if self.pendingUploads ~= nil and self.pendingUploads[id] ~= nil then
                local pending = self.pendingUploads[id]
                self.pendingUploads[id] = nil
                self.notify("farmIconColor_logoShared", "Logo shared: %s", pending.name, false)
            end
        end
    end

    -- Logos deleted by the admin since the last manifest.
    for id, _ in pairs(self.catalogById) do
        if not stillShared[id] then
            self.catalogById[id] = nil
            self:unregisterLogo(id)
        end
    end

    for _, entry in ipairs(entries) do
        -- The id is always derived from the name, never trusted as sent.
        entry.name = self.sanitizeName(entry.name)
        entry.id = entry.name ~= nil and (FarmIconColor:sanitizeCustomLogoId(entry.name)) or nil

        if entry.id ~= nil and type(entry.bytes) == "number" and type(entry.adler) == "number"
            and entry.bytes > 0 and entry.bytes <= self.MAX_BYTES then
            self.catalogById[entry.id] = entry

            if not self:materializeEntry(entry, nil) then
                table.insert(missing, entry.id)
            end
        end
    end

    if #missing > 0 then
        local connection = g_client ~= nil and g_client:getServerConnection() or nil

        if connection ~= nil then
            connection:sendEvent(FarmIconColorLogoEvent.newRequest(missing))
        end
    end
end

-- Server: send the requested logos (throttled by the out queue).
function LS:onRequest(connection, ids)
    if g_server == nil or self.catalog == nil then
        return
    end

    for _, id in ipairs(ids) do
        local entry = self.catalogById[id]

        if entry ~= nil then
            self:queueChunks(connection, entry, FarmIconColorLogoEvent.KIND_CHUNK)
        end
    end
end

-- Both directions: assemble chunks, verify and apply.
function LS:onChunk(connection, kind, event)
    if self.catalog == nil then
        return
    end

    local isUpload = kind == FarmIconColorLogoEvent.KIND_UPLOAD

    if isUpload then
        -- Only the server accepts uploads, and only from the admin.
        if g_server == nil or not self:isConnectionMasterUser(connection) then
            return
        end
    elseif g_server ~= nil then
        return
    end

    local name = self.sanitizeName(event.name)
    local id = name ~= nil and (FarmIconColor:sanitizeCustomLogoId(name)) or nil

    if id == nil or event.total < 1 or event.total > self.MAX_CHUNKS or event.index < 1 or event.index > event.total
        or event.bytes < 1 or event.bytes > self.MAX_BYTES or #event.chunk > self.CHUNK_SIZE then
        return
    end

    local senderKey = isUpload and connection or "server"
    self.incoming[senderKey] = self.incoming[senderKey] or {}
    local assembly = self.incoming[senderKey][id]

    if event.index == 1 or assembly == nil or assembly.total ~= event.total or assembly.adler ~= event.adler then
        assembly = {total = event.total, adler = event.adler, bytes = event.bytes, received = 0, parts = {}}
        self.incoming[senderKey][id] = assembly
    end

    if assembly.parts[event.index] == nil then
        assembly.parts[event.index] = event.chunk
        assembly.received = assembly.received + 1
    end

    if assembly.received < assembly.total then
        return
    end

    self.incoming[senderKey][id] = nil

    local data = table.concat(assembly.parts)
    local decoded = self.base64Decode(data)
    local entry = {
        id = id,
        name = name,
        bytes = event.bytes,
        adler = event.adler,
        tintable = event.tintable,
        data = data
    }

    if decoded == nil or #decoded ~= entry.bytes or self.adler32(decoded) ~= entry.adler or not self.isValidDds(decoded) then
        return
    end

    if isUpload then
        self:addToCatalog(entry, decoded)
    else
        entry.data = nil -- clients keep only the cache file
        if self:materializeEntry(entry, decoded) then
            self.catalogById[id] = entry
        end
    end
end

-- ------------------------------------------------------------- deletion ---
-- Deleted logos are remembered on the admin's PC (modSettings/FS25_farmIconColor/
-- deletedLogos.xml) so that the next Import does not bring them back while the
-- file is still in customLogos/. A new/modified file has another checksum and
-- is imported normally.

function LS:getDeletedListFilename()
    local directory = FarmIconColor:getModSettingsSaveDirectory()
    return directory ~= nil and FarmIconColor:joinPath(directory, "deletedLogos.xml") or nil
end

function LS:loadDeletedList()
    self.deletedPackages = {}
    self.deletedLocalLogos = {}

    local filename = self:getDeletedListFilename()

    if filename == nil or fileExists == nil or not fileExists(filename) then
        return
    end

    local xmlFile = loadXMLFile("farmIconColorDeletedLogos", filename)

    if xmlFile == nil or xmlFile == 0 then
        return
    end

    local index = 0
    while index < 1000 do
        local key = string.format("deletedLogos.package(%d)", index)
        if not hasXMLProperty(xmlFile, key) then
            break
        end
        local adler = getXMLString(xmlFile, key .. "#adler32")
        if adler ~= nil then
            self.deletedPackages[adler] = true
        end
        index = index + 1
    end

    index = 0
    while index < 1000 do
        local key = string.format("deletedLogos.local(%d)", index)
        if not hasXMLProperty(xmlFile, key) then
            break
        end
        local id = getXMLString(xmlFile, key .. "#id")
        if id ~= nil then
            self.deletedLocalLogos[id] = true
        end
        index = index + 1
    end

    delete(xmlFile)
end

function LS:saveDeletedList()
    local filename = self:getDeletedListFilename()

    if filename == nil then
        return
    end

    local xmlFile = createXMLFile("farmIconColorDeletedLogos", filename, "deletedLogos")

    if xmlFile == nil or xmlFile == 0 then
        return
    end

    local index = 0
    for adler, _ in pairs(self.deletedPackages or {}) do
        setXMLString(xmlFile, string.format("deletedLogos.package(%d)#adler32", index), adler)
        index = index + 1
    end

    index = 0
    for id, _ in pairs(self.deletedLocalLogos or {}) do
        setXMLString(xmlFile, string.format("deletedLogos.local(%d)#id", index), id)
        index = index + 1
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function LS:isLocalLogoDeleted(id)
    return self.deletedLocalLogos ~= nil and self.deletedLocalLogos[id] == true
end

-- "shared" (server catalog), "local" (.dds only on this PC) or nil (built-in).
-- Can this logo be applied to a farm right now? On a multiplayer client only the
-- built-in logos and the logos shared by the server are known to the server
-- (and to the other players); a raw .dds or an unconfirmed upload is not.
function LS:isLogoUsableInMultiplayer(id)
    local fic = FarmIconColor

    if id == nil or not fic:isClientOnlyMultiplayer() then
        return true
    end

    if self.catalogById ~= nil and self.catalogById[id] ~= nil then
        return true
    end

    return fic.customLogoPaths == nil or fic.customLogoPaths[id] == nil
end

-- Raw .dds files are never sent to the server: on a multiplayer client tell the
-- admin to convert them into a shareable .xml package.
function LS:notifyLocalOnlyLogos()
    local fic = FarmIconColor

    if not fic:isClientOnlyMultiplayer() or fic.customLogoPaths == nil then
        return
    end

    self.localOnlyNotified = self.localOnlyNotified or {}

    for id, _ in pairs(fic.customLogoPaths) do
        if not self:isLogoUsableInMultiplayer(id)
            and (self.pendingUploads == nil or self.pendingUploads[id] == nil)
            and not self.localOnlyNotified[id] then
            self.localOnlyNotified[id] = true
            self.notify("farmIconColor_logoLocalOnly", "%s: .dds file not shared, convert it to .xml with the logo converter", fic:getLogoDisplayName(id), true)
        end
    end
end

function LS:getDeletableKind(id)
    if id == nil then
        return nil
    end

    if self.catalogById ~= nil and self.catalogById[id] ~= nil then
        return "shared"
    end

    local fic = FarmIconColor
    if fic.customLogoPaths ~= nil and fic.customLogoPaths[id] ~= nil then
        return "local"
    end

    return nil
end

-- Admin action from the logo picker.
function LS:deleteLogo(id)
    local fic = FarmIconColor
    local kind = self:getDeletableKind(id)

    if kind == nil or not fic:isCurrentUserFarmIconAdmin() then
        return false
    end

    local displayName = fic:getLogoDisplayName(id)

    if kind == "local" then
        self.deletedLocalLogos[id] = true
        self:saveDeletedList()
        self:resetFarmsUsingLogo(id)
        self:unregisterLogo(id)
    else
        local entry = self.catalogById[id]

        if entry.adler ~= nil then
            self.deletedPackages[string.format("%d", entry.adler)] = true
            self:saveDeletedList()
        end

        if g_server ~= nil then
            self:removeFromCatalog(id)
        else
            local connection = g_client ~= nil and g_client:getServerConnection() or nil
            if connection ~= nil then
                connection:sendEvent(FarmIconColorLogoEvent.newDelete(id))
            end
        end
    end

    self.notify("farmIconColor_logoDeleted", "Logo deleted: %s", displayName, false)
    return true
end

-- Server: farms that used the deleted logo get the default logo (synced to everyone).
function LS:resetFarmsUsingLogo(id)
    local fic = FarmIconColor

    if not fic:isAuthoritativeInstance() or type(fic.runtimeFarmLogos) ~= "table" then
        return
    end

    local farmIds = {}
    for farmId, logoName in pairs(fic.runtimeFarmLogos) do
        if logoName == id then
            table.insert(farmIds, farmId)
        end
    end

    for _, farmId in ipairs(farmIds) do
        fic.runtimeFarmLogos[farmId] = nil
        local fallback = nil

        for _, logoName in ipairs(fic.logoOrder or {}) do
            if logoName ~= id and fic.logos[logoName] ~= nil then
                fallback = logoName
                break
            end
        end

        if fallback ~= nil then
            fic:setRuntimeFarmLogo(tonumber(farmId) or farmId, fallback, "logo deleted")
        else
            fic:saveSavegameData("logo deleted")
        end
    end
end

-- Server/host: removes a shared logo and tells every client.
function LS:removeFromCatalog(id)
    if self.catalogById[id] == nil then
        return false
    end

    for index = #self.catalog, 1, -1 do
        if self.catalog[index].id == id then
            table.remove(self.catalog, index)
        end
    end

    self.catalogById[id] = nil
    self:resetFarmsUsingLogo(id)
    self:unregisterLogo(id)
    FarmIconColor:saveSavegameData("shared logo deleted")

    if g_server ~= nil and FarmIconColor:isMultiplayerGame() then
        g_server:broadcastEvent(FarmIconColorLogoEvent.newManifest(self.catalog), nil, nil, nil)
    end

    return true
end

-- Server: delete request from a client (admin only).
function LS:onDeleteRequest(connection, id)
    if g_server == nil or self.catalog == nil or not self:isConnectionMasterUser(connection) then
        return
    end

    self:removeFromCatalog(tostring(id or ""))
end

-- Hook on the existing admin import (INSERT / Import button): after the .dds
-- scan, also share the .xml logo packages found in customLogos/.
if FarmIconColor ~= nil and FarmIconColor.importCustomLogosFromFolder ~= nil then
    local originalImport = FarmIconColor.importCustomLogosFromFolder

    FarmIconColor.importCustomLogosFromFolder = function(self, ...)
        local result = originalImport(self, ...)

        if self:isCurrentUserFarmIconAdmin() then
            self:safeCall("import shared logo packages", function()
                LS:importPackagesFromFolder()
                LS:notifyLocalOnlyLogos()
            end)
        end

        return result
    end
end

if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo)
        FarmIconColor:safeCall("save shared logo catalog", function()
            LS:onGameSaved(missionInfo)
        end)
    end)
end

-- ================================================================ event ===

FarmIconColorLogoEvent = {}
local FarmIconColorLogoEvent_mt = Class(FarmIconColorLogoEvent, Event)
InitEventClass(FarmIconColorLogoEvent, "FarmIconColorLogoEvent")

FarmIconColorLogoEvent.KIND_HELLO = 1     -- client -> server : send me the manifest
FarmIconColorLogoEvent.KIND_MANIFEST = 2  -- server -> client : list of shared logos
FarmIconColorLogoEvent.KIND_REQUEST = 3   -- client -> server : send me these logos
FarmIconColorLogoEvent.KIND_CHUNK = 4     -- server -> client : one piece of a logo
FarmIconColorLogoEvent.KIND_UPLOAD = 5    -- admin client -> server : one piece of a logo
FarmIconColorLogoEvent.KIND_DELETE = 6    -- admin client -> server : delete this shared logo

function FarmIconColorLogoEvent.emptyNew()
    return Event.new(FarmIconColorLogoEvent_mt)
end

function FarmIconColorLogoEvent.newHello()
    local self = FarmIconColorLogoEvent.emptyNew()
    self.kind = FarmIconColorLogoEvent.KIND_HELLO
    return self
end

function FarmIconColorLogoEvent.newManifest(catalog)
    local self = FarmIconColorLogoEvent.emptyNew()
    self.kind = FarmIconColorLogoEvent.KIND_MANIFEST
    self.entries = {}

    for index, entry in ipairs(catalog) do
        if index > 255 then
            break
        end
        table.insert(self.entries, entry)
    end

    return self
end

function FarmIconColorLogoEvent.newRequest(ids)
    local self = FarmIconColorLogoEvent.emptyNew()
    self.kind = FarmIconColorLogoEvent.KIND_REQUEST
    self.ids = {}

    for index, id in ipairs(ids) do
        if index > 255 then
            break
        end
        table.insert(self.ids, id)
    end

    return self
end

function FarmIconColorLogoEvent.newDelete(id)
    local self = FarmIconColorLogoEvent.emptyNew()
    self.kind = FarmIconColorLogoEvent.KIND_DELETE
    self.id = id
    return self
end

function FarmIconColorLogoEvent.newChunk(kind, entry, index, total, chunk)
    local self = FarmIconColorLogoEvent.emptyNew()
    self.kind = kind
    self.name = entry.name
    self.bytes = entry.bytes
    self.adler = entry.adler
    self.tintable = entry.tintable == true
    self.index = index
    self.total = total
    self.chunk = chunk
    return self
end

-- Every field is always read, whatever its value, so a bad packet can never
-- desynchronise the network stream; validation happens afterwards in LS.
function FarmIconColorLogoEvent:readStream(streamId, connection)
    self.kind = streamReadUInt8(streamId)

    if self.kind == FarmIconColorLogoEvent.KIND_MANIFEST then
        self.entries = {}
        local count = streamReadUInt8(streamId)

        for _ = 1, count do
            table.insert(self.entries, {
                id = streamReadString(streamId),
                name = streamReadString(streamId),
                bytes = streamReadInt32(streamId),
                adler = tonumber(streamReadString(streamId)),
                tintable = streamReadBool(streamId)
            })
        end
    elseif self.kind == FarmIconColorLogoEvent.KIND_REQUEST then
        self.ids = {}
        local count = streamReadUInt8(streamId)

        for _ = 1, count do
            table.insert(self.ids, streamReadString(streamId))
        end
    elseif self.kind == FarmIconColorLogoEvent.KIND_CHUNK or self.kind == FarmIconColorLogoEvent.KIND_UPLOAD then
        self.name = streamReadString(streamId)
        self.bytes = streamReadInt32(streamId)
        self.adler = tonumber(streamReadString(streamId))
        self.tintable = streamReadBool(streamId)
        self.index = streamReadInt32(streamId)
        self.total = streamReadInt32(streamId)
        self.chunk = streamReadString(streamId)
    elseif self.kind == FarmIconColorLogoEvent.KIND_DELETE then
        self.id = streamReadString(streamId)
    end

    self:run(connection)
end

function FarmIconColorLogoEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.kind)

    if self.kind == FarmIconColorLogoEvent.KIND_MANIFEST then
        streamWriteUInt8(streamId, #self.entries)

        for _, entry in ipairs(self.entries) do
            streamWriteString(streamId, entry.id)
            streamWriteString(streamId, entry.name)
            streamWriteInt32(streamId, entry.bytes)
            streamWriteString(streamId, string.format("%d", entry.adler))
            streamWriteBool(streamId, entry.tintable == true)
        end
    elseif self.kind == FarmIconColorLogoEvent.KIND_REQUEST then
        streamWriteUInt8(streamId, #self.ids)

        for _, id in ipairs(self.ids) do
            streamWriteString(streamId, id)
        end
    elseif self.kind == FarmIconColorLogoEvent.KIND_CHUNK or self.kind == FarmIconColorLogoEvent.KIND_UPLOAD then
        streamWriteString(streamId, self.name)
        streamWriteInt32(streamId, self.bytes)
        streamWriteString(streamId, string.format("%d", self.adler))
        streamWriteBool(streamId, self.tintable)
        streamWriteInt32(streamId, self.index)
        streamWriteInt32(streamId, self.total)
        streamWriteString(streamId, self.chunk)
    elseif self.kind == FarmIconColorLogoEvent.KIND_DELETE then
        streamWriteString(streamId, tostring(self.id or ""))
    end
end

function FarmIconColorLogoEvent:run(connection)
    local fromClient = connection ~= nil and connection.getIsServer ~= nil and not connection:getIsServer()

    FarmIconColor:safeCall("logo event", function()
        if self.kind == FarmIconColorLogoEvent.KIND_HELLO and fromClient then
            LS:onHello(connection)
        elseif self.kind == FarmIconColorLogoEvent.KIND_MANIFEST and not fromClient then
            LS:onManifest(self.entries or {})
        elseif self.kind == FarmIconColorLogoEvent.KIND_REQUEST and fromClient then
            LS:onRequest(connection, self.ids or {})
        elseif self.kind == FarmIconColorLogoEvent.KIND_CHUNK and not fromClient then
            LS:onChunk(connection, self.kind, self)
        elseif self.kind == FarmIconColorLogoEvent.KIND_UPLOAD and fromClient then
            LS:onChunk(connection, self.kind, self)
        elseif self.kind == FarmIconColorLogoEvent.KIND_DELETE and fromClient then
            LS:onDeleteRequest(connection, self.id)
        end
    end)
end

addModEventListener(FarmIconColorLogoSync)
