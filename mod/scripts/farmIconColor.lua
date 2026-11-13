FarmIconColor = {}

FarmIconColor.MOD_NAME = g_currentModName or "farmIconColor"
FarmIconColor.MOD_DIRECTORY = g_currentModDirectory or ""
FarmIconColor.CONFIG_FILE = FarmIconColor.MOD_DIRECTORY .. "xml/farmIconColor.xml"
FarmIconColor.SAVE_FILE_NAME = "farmIconColor.xml"
FarmIconColor.CUSTOM_LOGO_DIRECTORY_NAME = "customLogos"
FarmIconColor.HOTSPOT_REFRESH_INTERVAL = 1000
FarmIconColor.FARM_APPLY_CHECK_INTERVAL = 1000
FarmIconColor.NETWORK_SYNC_INTERVAL = 5000
FarmIconColor.PROTOTYPE_COLOR_PICKER_KEY_NAME = "F9"
FarmIconColor.PROTOTYPE_LOGO_PREVIOUS_KEY_NAME = "NUMPAD 4"
FarmIconColor.PROTOTYPE_LOGO_NEXT_KEY_NAME = "NUMPAD 6"
FarmIconColor.CUSTOM_LOGO_IMPORT_KEY_NAME = "INSERT"
FarmIconColor.CUSTOM_LOGO_IMPORT_ACTION_NAME = "FARMICONCOLOR_IMPORT_CUSTOM_LOGO"
FarmIconColor.LOGO_SELECTOR_OVERLAY_ENABLED = false

-- Release build: keep ModHub log.txt clean.
-- Set to true only during local development.
FarmIconColor.DEBUG = false

function FarmIconColor:debugPrint(...)
    if self.DEBUG ~= true then
        return
    end

    local nativePrint = _G ~= nil and _G["print"] or nil
    if nativePrint == nil then
        return
    end

    local args = {...}
    for i = 1, #args do
        args[i] = tostring(args[i])
    end

    nativePrint(table.concat(args, " "))
end

FarmIconColor.LOGO_SELECTOR_OVERLAY_LABEL_X = 0.380
FarmIconColor.LOGO_SELECTOR_OVERLAY_BOX_X = 0.505
FarmIconColor.LOGO_SELECTOR_OVERLAY_BOX_Y = 0.430
FarmIconColor.LOGO_SELECTOR_OVERLAY_BOX_W = 0.205
FarmIconColor.LOGO_SELECTOR_OVERLAY_BOX_H = 0.036
FarmIconColor.LOGO_SELECTOR_OVERLAY_BUTTON_W = 0.028

FarmIconColor.LOGO_SELECTOR_OVERLAY_TEXT_SIZE = 0.0115
FarmIconColor.LOGO_SELECTOR_OVERLAY_LABEL_SIZE = 0.0105
FarmIconColor.NATIVE_LOGO_SELECTOR_TEXT_OVERLAY_ENABLED = false
FarmIconColor.NATIVE_LOGO_SELECTOR_TEXT_OVERLAY_SIZE = 0.0105
FarmIconColor.NATIVE_LOGO_SELECTOR_TEXT_CENTER_PADDING = 8

FarmIconColor.GUI_INSPECTOR_KEY_NAME = "F10"
FarmIconColor.GUI_INSPECTOR_ENABLED = false

function FarmIconColor:loadMap()
    FarmIconColor:debugPrint(string.format("[%s] Loading script", self.MOD_NAME))

    self.farms = {}
    self.logos = {}
    self.logoColors = {}
    self.colorApplied = false
    self.originalFarmColors = {}
    self.appliedFarmId = nil
    self.appliedColor = nil
    self.hotspotRefreshTimer = 0
    self.farmApplyCheckTimer = 0
    self.lastFarmMenuOpen = false
    self.lastFarmMenuPageLabel = nil
    self.hotspotApplyLogTimer = 0
    self.hotspotApplyLogged = false
    self.waitingForFarmLogged = false
    self.farmMenuLogoApplyLogged = false
    self.farmDialogLogoApplyLogged = false
    self.farmDialogCustomLogoApplyLogged = false
    self.prototypeColorPickerHotkeyDown = false
    self.prototypeColorPickerInputMissingLogged = false
    self.prototypeColorPickerFarmId = nil
    self.prototypeColorPickerPresetColors = nil
    self.prototypeColorPickerPendingFarmCreation = false
    self.pendingFarmCreationColor = nil
    self.pendingFarmCreationLogoName = nil
    self.pendingFarmCreationColorApplied = false
    self.pendingFarmCreationKnownFarmIds = nil
    self.runtimeFarmColors = {}
    self.runtimeFarmLogos = {}
    self.savegameDataLoaded = false
    self.savegameDataLoadAttempted = false
    self.savegameSaveLogged = false
    self.farmDialogColorButtonHookLogged = false
    self.farmDialogVanillaColorControlsHiddenLogged = false
    self.pendingDialogLogoRefreshFarmId = nil
    self.pendingDialogLogoRefreshColor = nil
    self.pendingDialogLogoRefreshFrames = 0
    self.logoOrder = {}
    self.logoL10n = {}
    self.customLogoDisplayNames = {}
    self.customLogoPaths = {}
    self.customLogosLoaded = false
    self.customLogoDirectory = nil
    self.customLogoMissingModSettingsDirectoryLogged = false
    self.customLogoDirectoryCreationLogged = false
    self.logoSelectorPreviousKeyDown = false
    self.logoSelectorNextKeyDown = false
    self.logoSelectorInputMissingLogged = false
    self.customLogoImportKeyDown = false
    self.customLogoImportInputMissingLogged = false
    self.farmDialogImportButtonLogged = false
    self.customLogoPngDiagnosticDone = false
    self.generatedCustomLogoPaths = {}
    self.logoSelectorOverlayMissingFunctionsLogged = false
    self.logoSelectorOverlayLogged = false
    self.logoSelectorDrawCalledLogged = false
    self.farmDialogGuiDebugLogged = false
    self.guiInspectorKeyDown = false
    self.guiInspectorInputMissingLogged = false
    self.guiInspectorDumpCount = 0
    self.runtimeFarmColorApplyTimer = 0
    self.runtimeFarmGameColorAppliedSignatures = {}
    self.landMapColorRefreshTimer = 0
    self.forceSavedFarmColorSyncTime = 0
    self.visibleLandMenuColorRefreshTimer = 0
    self.lastForcedLandMenuColorSignature = nil
    self.networkSyncTimer = 0
    self.networkSyncInitialTimer = 0
    self.networkSyncInitialCount = 0
    self.networkSyncApplyInProgress = false
    self.networkSyncLastSendSignature = nil
    self.networkSyncLastBroadcastSignature = nil

    self:loadConfig()
end

function FarmIconColor:deleteMap()
    self:restoreNativeLogoSelectorToOriginalParent()
    if (type(self.runtimeFarmColors) == "table" and next(self.runtimeFarmColors) ~= nil)
        or (type(self.runtimeFarmLogos) == "table" and next(self.runtimeFarmLogos) ~= nil) then
        self:saveSavegameData("deleteMap safety save")
    end

    FarmIconColor:debugPrint(string.format("[%s] Unloading script", self.MOD_NAME))
end

function FarmIconColor:update(dt)

    self:safeCall("tryLoadCustomLogos", function()
        self:tryLoadCustomLogos()
    end)

    self:safeCall("tryLoadSavegameData", function()
        self:tryLoadSavegameData()
    end)

    self:safeCall("updateNetworkSync", function()
        self:updateNetworkSync(dt)
    end)

    if (self.forceSavedFarmColorSyncTime or 0) > 0 then
        self.forceSavedFarmColorSyncTime = math.max(0, (self.forceSavedFarmColorSyncTime or 0) - dt)
        self:safeCall("force saved farm colors after load", function()
            self:forceApplyAllSavedFarmVisualColors("forced savegame color sync")
        end)
    elseif self:isMapOrLandsMenuVisible() then
        self.visibleLandMenuColorRefreshTimer = (self.visibleLandMenuColorRefreshTimer or 0) + dt

        if self.visibleLandMenuColorRefreshTimer >= 500 then
            self.visibleLandMenuColorRefreshTimer = 0
            self:safeCall("force saved farm colors on visible lands menu", function()
                self:forceApplyAllSavedFarmVisualColors("visible map/lands page")
            end)
        end
    else
        self.visibleLandMenuColorRefreshTimer = 0
    end

    self.runtimeFarmColorApplyTimer = (self.runtimeFarmColorApplyTimer or 0) + dt
    if self.runtimeFarmColorApplyTimer >= self.FARM_APPLY_CHECK_INTERVAL then
        self.runtimeFarmColorApplyTimer = 0
        self:safeCall("applyAllRuntimeFarmGameColors", function()
            self:applyAllRuntimeFarmGameColors("periodic saved/runtime colors")
        end)
    end

    if not self:hasVisibleFarmEditDialog() then
        self:restoreNativeLogoSelectorToOriginalParent()
    end

    if not self.colorApplied then
        self.farmApplyCheckTimer = self.farmApplyCheckTimer + dt

        if self.farmApplyCheckTimer >= self.FARM_APPLY_CHECK_INTERVAL then
            self.farmApplyCheckTimer = 0
            self:tryApplyCurrentFarmConfig("periodic farm check")
        end
    end

    if self.appliedFarmId ~= nil and self.appliedColor ~= nil then
        self.hotspotRefreshTimer = self.hotspotRefreshTimer + dt
        self.hotspotApplyLogTimer = self.hotspotApplyLogTimer + dt

        if self.hotspotRefreshTimer >= self.HOTSPOT_REFRESH_INTERVAL then
            self.hotspotRefreshTimer = 0

            local currentColor = self:getAppliedFarmCurrentColor()

            if currentColor ~= nil then
                self.appliedColor = self:copyColor(currentColor) or currentColor
                self:applyMapHotspotColors(self.appliedFarmId, self.appliedColor)
            end
        end

    end

    if self.applyToFarmMenuLogo then
        self:safeCall("applyPendingFarmCreationColor", function()
            self:applyPendingFarmCreationColor()
        end)
        self:safeCall("checkFarmMenuOpen", function()
            self:checkFarmMenuOpen()
        end)
        self:safeCall("applyActiveFarmDialogLogoColors", function()
            self:applyActiveFarmDialogLogoColors()
        end)
        self:safeCall("processPendingDialogLogoRefresh", function()
            self:processPendingDialogLogoRefresh()
        end)
        self:safeCall("hideActiveFarmDialogVanillaColorControls", function()
            self:hideActiveFarmDialogVanillaColorControls()
        end)
        self:safeCall("hookActiveFarmDialogColorPickerButton", function()
            self:hookActiveFarmDialogColorPickerButton()
        end)
        self:safeCall("ensureActiveFarmDialogImportButton", function()
            self:ensureActiveFarmDialogImportButton()
        end)
        self:safeCall("updateActiveFarmDialogLogoSelectorLabel", function()
            self:updateActiveFarmDialogLogoSelectorLabel()
        end)
    end

    self:safeCall("checkPrototypeColorPickerHotkey", function()
        self:checkPrototypeColorPickerHotkey()
    end)

    self:safeCall("checkPrototypeLogoSelectorHotkeys", function()
        self:checkPrototypeLogoSelectorHotkeys()
    end)

    self:safeCall("checkCustomLogoImportHotkey", function()
        self:checkCustomLogoImportHotkey()
    end)

    self:safeCall("checkGuiInspectorHotkey", function()
        self:checkGuiInspectorHotkey()
    end)
end

function FarmIconColor:safeCall(label, callback)
    local success, message = pcall(callback)

    if not success then
        FarmIconColor:debugPrint(string.format("[%s] ERROR in %s: %s", self.MOD_NAME, tostring(label), tostring(message)))
    end
end

function FarmIconColor:loadConfig()
    local xmlFile = loadXMLFile("farmIconColorConfig", self.CONFIG_FILE)

    if xmlFile == nil or xmlFile == 0 then
        FarmIconColor:debugPrint(string.format("[%s] ERROR: Unable to load config file: %s", self.MOD_NAME, self.CONFIG_FILE))
        return
    end

    self.applyToFarmLogo = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToFarmLogo#value"), true)
    self.applyToPlayerCursor = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToPlayerCursor#value"), true)
    self.applyToFarmland = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToFarmland#value"), true)
    self.applyToFieldNumbers = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToFieldNumbers#value"), true)
    self.applyToVehicleHotspots = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToVehicleHotspots#value"), true)
    self.applyToObjectHotspots = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToObjectHotspots#value"), true)
    self.applyToFarmMenuLogo = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyToFarmMenuLogo#value"), true)
    self.applyLogoSpecificColorsFromXml = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.applyLogoSpecificColors#value"), false)
    self.applyLogoSpecificColors = false
    self.allowCustomLogos = Utils.getNoNil(getXMLBool(xmlFile, "farmIconColor.settings.allowCustomLogos#value"), true)
    self.defaultColor = Utils.getNoNil(getXMLString(xmlFile, "farmIconColor.defaultColor#value"), "0.3 1 0.3 1")

    local logoIndex = 0
    while true do
        local key = string.format("farmIconColor.logos.logo(%d)", logoIndex)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local name = getXMLString(xmlFile, key .. "#name")
        local texture = getXMLString(xmlFile, key .. "#texture")
        local color = getXMLString(xmlFile, key .. "#color")
        local l10n = getXMLString(xmlFile, key .. "#l10n") or getXMLString(xmlFile, key .. "#titleKey")

        if name ~= nil then
            local normalizedName = self:normalizeLogoName(name)

            if texture ~= nil and texture ~= "" then
                self.logos[normalizedName] = texture

                self:addLogoToOrder(normalizedName)
            end

            if color ~= nil then
                self.logoColors[normalizedName] = color
            end

            if l10n ~= nil then
                self.logoL10n[normalizedName] = l10n
            end

            FarmIconColor:debugPrint(string.format("[%s] Logo configured: %s -> %s color=%s l10n=%s", self.MOD_NAME, normalizedName, tostring(texture), tostring(color), tostring(l10n)))
        end

        logoIndex = logoIndex + 1
    end

    local farmIndex = 0
    while true do
        local key = string.format("farmIconColor.farms.farm(%d)", farmIndex)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local id = getXMLString(xmlFile, key .. "#id")
        local color = getXMLString(xmlFile, key .. "#color")
        local logo = getXMLString(xmlFile, key .. "#logo")
        local logoColor = getXMLString(xmlFile, key .. "#logoColor")

        if id ~= nil then
            self.farms[tostring(id)] = {
                color = color,
                logo = logo or "none",
                logoColor = logoColor
            }

            FarmIconColor:debugPrint(string.format("[%s] Farm configured: id=%s color=%s logo=%s logoColor=%s", self.MOD_NAME, tostring(id), tostring(color), tostring(logo), tostring(logoColor)))
        end

        farmIndex = farmIndex + 1
    end

    FarmIconColor:debugPrint(string.format("[%s] Config loaded from %s", self.MOD_NAME, self.CONFIG_FILE))
    FarmIconColor:debugPrint(string.format("[%s] Default color: %s", self.MOD_NAME, tostring(self.defaultColor)))

    if self.logoOrder ~= nil then
        FarmIconColor:debugPrint(string.format("[%s] Selectable logo order: %s", self.MOD_NAME, table.concat(self.logoOrder, ", ")))
    end

    delete(xmlFile)
end


function FarmIconColor:joinPath(directory, filename)
    if directory == nil or directory == "" then
        return nil
    end

    local separator = "/"

    if string.sub(directory, -1) == "/" or string.sub(directory, -1) == "\\" then
        separator = ""
    end

    return directory .. separator .. filename
end

function FarmIconColor:ensureFolderExists(directory)
    if directory == nil or directory == "" then
        return false, "empty directory"
    end

    if createFolder == nil then
        return false, "createFolder unavailable"
    end

    local success, result = pcall(function()
        return createFolder(directory)
    end)

    if not success then
        return false, tostring(result)
    end

    return true, result
end


function FarmIconColor:ensureCustomLogoReadme(directory)
    if directory == nil or directory == "" then
        return false, "empty directory"
    end

    local filename = self:joinPath(directory, "README.txt")

    if fileExists ~= nil and fileExists(filename) then
        return true, "already exists"
    end

    if createFile == nil or fileWrite == nil or FileAccess == nil or FileAccess.WRITE == nil then
        return false, "GIANTS file API unavailable"
    end

    local success, result = pcall(function()
        local fileId = createFile(filename, FileAccess.WRITE)

        if fileId == nil or fileId == 0 then
            return false, "createFile failed"
        end

        local content =
            "Farm Icon Color - Custom Logos\n" ..
            "================================\n\n" ..
            "This folder is created automatically by Farm Icon Color.\n" ..
            "Place your personal farm logos (.dds) here.\n\n" ..
            "Location:\n" ..
            "Documents/My Games/FarmingSimulator2025/modSettings/FS25_farmIconColor/customLogos/\n\n" ..
            "Required format:\n" ..
            "- DDS\n" ..
            "- 256x256 pixels\n" ..
            "- Pure white logo (#FFFFFF)\n" ..
            "- Transparent background / alpha channel\n" ..
            "- BC3 / DXT5 compression\n" ..
            "- Mipmaps enabled\n\n" ..
            "While the farm creation/edit menu is open, the administrator can press INSERT (Import) to rescan this folder.\n" ..
            "Custom logos are loaded after the logos included with the mod.\n"

        fileWrite(fileId, content)
        delete(fileId)

        return true, "README.txt created"
    end)

    if not success then
        return false, tostring(result)
    end

    if type(result) == "table" then
        return result[1], result[2]
    end

    return result == true, tostring(result)
end

function FarmIconColor:getMissionSavegameKey()
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil

    if missionInfo ~= nil and missionInfo.savegameIndex ~= nil then
        return "savegame" .. tostring(missionInfo.savegameIndex)
    end

    local legacyDirectory = self:getLegacySavegameDirectory()

    if legacyDirectory ~= nil and legacyDirectory ~= "" then
        local normalized = tostring(legacyDirectory)
        normalized = string.gsub(normalized, "[^%w_%-]", "_")
        return normalized
    end

    return "savegame_unknown"
end

function FarmIconColor:getLegacySavegameDirectory()
    local mission = g_currentMission
    local missionInfo = mission ~= nil and mission.missionInfo or nil
    local directory = nil

    if missionInfo ~= nil then
        local directoryCandidates = {
            missionInfo.savegameDirectory,
            missionInfo.savegameDir,
            missionInfo.savegamePath,
            missionInfo.savegameDirectoryPath
        }

        for _, candidate in ipairs(directoryCandidates) do
            if candidate ~= nil and tostring(candidate) ~= "" then
                directory = tostring(candidate)
                break
            end
        end

        if directory == nil and missionInfo.savegameIndex ~= nil and getUserProfileAppPath ~= nil then
            local profilePath = getUserProfileAppPath()
            if profilePath ~= nil and tostring(profilePath) ~= "" then
                directory = self:joinPath(tostring(profilePath), "savegame" .. tostring(missionInfo.savegameIndex))
            end
        end
    end

    if directory == nil and mission ~= nil then
        local dynamicInfo = mission.missionDynamicInfo
        if dynamicInfo ~= nil and dynamicInfo.savegameIndex ~= nil and getUserProfileAppPath ~= nil then
            local profilePath = getUserProfileAppPath()
            if profilePath ~= nil and tostring(profilePath) ~= "" then
                directory = self:joinPath(tostring(profilePath), "savegame" .. tostring(dynamicInfo.savegameIndex))
            end
        end
    end

    return directory
end

function FarmIconColor:getLegacySavegameDataFilename()
    local directory = self:getLegacySavegameDirectory()

    if directory == nil or directory == "" then
        return nil
    end

    return self:joinPath(directory, self.SAVE_FILE_NAME)
end

function FarmIconColor:getCustomLogoDirectory()
    -- Custom logos are intentionally stored in modSettings instead of savegameX.
    -- This makes the import folder stable for local players and multiplayer admins,
    -- even when FS25 rebuilds/replaces the active savegame directory.
    local settingsDirectory = self:getModSettingsSaveDirectory()

    if settingsDirectory == nil or settingsDirectory == "" then
        if not self.customLogoMissingModSettingsDirectoryLogged then
            self.customLogoMissingModSettingsDirectoryLogged = true
            FarmIconColor:debugPrint(string.format("[%s] customLogos: modSettings directory not available yet", self.MOD_NAME))
        end
        return nil
    end

    local directory = self:joinPath(settingsDirectory, self.CUSTOM_LOGO_DIRECTORY_NAME)
    local folderCallOk, folderResult = self:ensureFolderExists(directory)
    local readmeOk, readmeResult = self:ensureCustomLogoReadme(directory)

    if not self.customLogoDirectoryCreationLogged then
        self.customLogoDirectoryCreationLogged = true
        FarmIconColor:debugPrint(string.format("[%s] customLogos: settings=%s", self.MOD_NAME, tostring(settingsDirectory)))
        FarmIconColor:debugPrint(string.format("[%s] customLogos: directory=%s folderCallOk=%s folderResult=%s", self.MOD_NAME, tostring(directory), tostring(folderCallOk), tostring(folderResult)))
        FarmIconColor:debugPrint(string.format("[%s] customLogos: README create=%s result=%s", self.MOD_NAME, tostring(readmeOk), tostring(readmeResult)))
    end

    if folderCallOk ~= true or readmeOk ~= true then
        return nil
    end

    return directory
end


function FarmIconColor:sanitizeCustomLogoId(filename)
    if filename == nil then
        return nil
    end

    local basename = tostring(filename)
    basename = string.gsub(basename, "\\", "/")
    basename = string.match(basename, "([^/]+)$") or basename
    basename = string.gsub(basename, "%.[Dd][Dd][Ss]$", "")

    local id = string.lower(basename)
    id = string.gsub(id, "[^%w_%-]+", "_")
    id = string.gsub(id, "_+", "_")
    id = string.gsub(id, "^_+", "")
    id = string.gsub(id, "_+$", "")

    if id == "" then
        return nil
    end

    return "custom_" .. id, basename
end

function FarmIconColor:registerCustomLogoFile(filename)
    if filename == nil then
        return false
    end

    local fileText = tostring(filename)

    if string.match(fileText, "%.[Dd][Dd][Ss]$") == nil then
        return false
    end

    local logoId, displayName = self:sanitizeCustomLogoId(fileText)

    if logoId == nil then
        return false
    end

    local fullPath = fileText
    local hasPath = string.find(fileText, "/", 1, true) ~= nil or string.find(fileText, "\\", 1, true) ~= nil or string.match(fileText, "^%a:") ~= nil

    if not hasPath and self.customLogoDirectory ~= nil then
        fullPath = self:joinPath(self.customLogoDirectory, fileText)
    end

    if fileExists ~= nil and not fileExists(fullPath) then
        FarmIconColor:debugPrint(string.format("[%s] customLogos TEST: ignored missing file=%s", self.MOD_NAME, tostring(fullPath)))
        return false
    end

    if self.logos[logoId] ~= nil then
        FarmIconColor:debugPrint(string.format("[%s] customLogos TEST: ignored duplicate id=%s file=%s", self.MOD_NAME, tostring(logoId), tostring(fullPath)))
        return false
    end

    self.logos[logoId] = fullPath
    self.customLogoPaths[logoId] = fullPath
    self.customLogoDisplayNames[logoId] = displayName or logoId
    self:addLogoToOrder(logoId)

    FarmIconColor:debugPrint(string.format("[%s] customLogos TEST: loaded id=%s name=%s file=%s", self.MOD_NAME, tostring(logoId), tostring(displayName), tostring(fullPath)))
    return true
end

function FarmIconColor:onCustomLogoFile(filename)
    if filename == nil then
        return
    end

    local fileText = tostring(filename)

    if string.match(fileText, "%.[Dd][Dd][Ss]$") == nil then
        return
    end

    self.pendingCustomLogoFiles = self.pendingCustomLogoFiles or {}
    table.insert(self.pendingCustomLogoFiles, fileText)
end

function FarmIconColor:tryLoadCustomLogos()
    if self.customLogosLoaded == true or self.allowCustomLogos ~= true then
        return self.customLogosLoaded == true
    end

    -- Every game instance gets its own local modSettings/customLogos import folder.
    -- In multiplayer this is especially important for the administrator client,
    -- which will later use this folder as the source for server-side logo import.
    local directory = self:getCustomLogoDirectory()

    if directory == nil or directory == "" then
        return false
    end

    self.customLogoDirectory = directory
    self.customLogoDisplayNames = self.customLogoDisplayNames or {}
    self.customLogoPaths = self.customLogoPaths or {}
    self.pendingCustomLogoFiles = {}

    if getFiles == nil then
        FarmIconColor:debugPrint(string.format("[%s] customLogos TEST: getFiles unavailable", self.MOD_NAME))
        self.customLogosLoaded = true
        return false
    end

    local success, result = pcall(function()
        return getFiles(directory, "onCustomLogoFile", self)
    end)

    if not success then
        FarmIconColor:debugPrint(string.format("[%s] customLogos TEST: scan failed directory=%s error=%s", self.MOD_NAME, tostring(directory), tostring(result)))
        return false
    end

    table.sort(self.pendingCustomLogoFiles, function(a, b)
        return string.lower(tostring(a)) < string.lower(tostring(b))
    end)

    local loadedCount = 0
    for _, filename in ipairs(self.pendingCustomLogoFiles) do
        if self:registerCustomLogoFile(filename) then
            loadedCount = loadedCount + 1
        end
    end

    self.pendingCustomLogoFiles = nil
    self.customLogosLoaded = true
    FarmIconColor:debugPrint(string.format("[%s] customLogos TEST: scan complete directory=%s files=%s loaded=%d totalSelectable=%d", self.MOD_NAME, tostring(directory), tostring(result), loadedCount, #(self.logoOrder or {})))

    return true
end

function FarmIconColor:clearRegisteredCustomLogos()
    local customPaths = self.customLogoPaths or {}

    for logoId, _ in pairs(customPaths) do
        self.logos[logoId] = nil

        if type(self.logoOrder) == "table" then
            for index = #self.logoOrder, 1, -1 do
                if self.logoOrder[index] == logoId then
                    table.remove(self.logoOrder, index)
                end
            end
        end
    end

    self.customLogoDisplayNames = {}
    self.customLogoPaths = {}
    self.customLogosLoaded = false
end

function FarmIconColor:diagnoseCustomLogoEngineIOSupport()
    if self.customLogoDdsRoundtripDiagnosticDone == true then
        return false
    end

    self.customLogoDdsRoundtripDiagnosticDone = true

    local prefix = "[FS25_farmIconColor][DDS-ROUNDTRIP]"
    local function diag(message)
        print(string.format("%s %s", prefix, tostring(message)))
    end

    local sourcePath = nil
    local logoId = nil
    if type(self.logoOrder) == "table" and type(self.customLogoPaths) == "table" then
        for _, candidateId in ipairs(self.logoOrder) do
            local candidatePath = self.customLogoPaths[candidateId]
            if candidatePath ~= nil and candidatePath ~= "" then
                logoId = candidateId
                sourcePath = tostring(candidatePath)
                break
            end
        end
    end

    if sourcePath == nil then
        diag("no custom DDS available for roundtrip diagnostic")
        return false
    end

    if type(createBitVectorMap) ~= "function"
        or type(loadBitVectorMapFromFile) ~= "function"
        or type(getBitVectorMapSize) ~= "function"
        or type(getBitVectorMapPoint) ~= "function" then
        diag("required BitVectorMap APIs unavailable")
        return false
    end

    if type(createFile) ~= "function" or type(fileWrite) ~= "function"
        or type(FileAccess) ~= "table" or FileAccess.WRITE == nil then
        diag("required binary output APIs unavailable")
        return false
    end

    local function isUsableHandle(value)
        return value ~= nil and value ~= 0
    end

    local function safeDeleteHandle(handle)
        if isUsableHandle(handle) and type(delete) == "function" then
            pcall(function()
                delete(handle)
            end)
        end
    end

    local function u32le(value)
        value = math.floor(tonumber(value) or 0) % 4294967296
        return string.char(
            value % 256,
            math.floor(value / 256) % 256,
            math.floor(value / 65536) % 256,
            math.floor(value / 16777216) % 256
        )
    end

    local mapId = nil
    local okCreate, createdMap = pcall(function()
        return createBitVectorMap("FarmIconColorDdsRoundtrip")
    end)
    if okCreate and isUsableHandle(createdMap) then
        mapId = createdMap
    else
        diag(string.format("createBitVectorMap failed callOk=%s mapId=%s", tostring(okCreate), tostring(createdMap)))
        return false
    end

    -- Important: request exactly 8 bits. For a 256x256 BC3/DXT5 texture the
    -- top mip contains exactly 65,536 compressed bytes (64x64 blocks x 16 B).
    -- Previous diagnostics displayed these bytes as if they were pixels, which
    -- produced the characteristic horizontal garbage seen on screen. Here we
    -- keep them as bytes and rebuild a standard single-mip DXT5 DDS container.
    local okLoad, loadResult = pcall(function()
        return loadBitVectorMapFromFile(mapId, sourcePath, 8)
    end)
    if not okLoad or loadResult ~= true then
        diag(string.format("load DDS as 8-bit payload failed callOk=%s result=%s path=%s", tostring(okLoad), tostring(loadResult), sourcePath))
        safeDeleteHandle(mapId)
        return false
    end

    local okSize, width, height = pcall(function()
        return getBitVectorMapSize(mapId)
    end)
    if not okSize or type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        diag(string.format("invalid payload map size width=%s height=%s", tostring(width), tostring(height)))
        safeDeleteHandle(mapId)
        return false
    end

    width = math.floor(width)
    height = math.floor(height)

    if width > 512 or height > 512 or width % 4 ~= 0 or height % 4 ~= 0 then
        diag(string.format("unsupported DDS dimensions %dx%d (must be <=512 and multiples of 4)", width, height))
        safeDeleteHandle(mapId)
        return false
    end

    local expectedBc3Bytes = math.floor((width + 3) / 4) * math.floor((height + 3) / 4) * 16
    local mapByteCount = width * height

    diag(string.format(
        "source id=%s size=%dx%d mapBytes=%d expectedBC3TopMip=%d hypothesisMatch=%s",
        tostring(logoId), width, height, mapByteCount, expectedBc3Bytes, tostring(mapByteCount == expectedBc3Bytes)
    ))

    if mapByteCount ~= expectedBc3Bytes then
        diag("8-bit map size does not match a BC3/DXT5 top mip; refusing reconstruction")
        safeDeleteHandle(mapId)
        return false
    end

    local payloadParts = {}
    local payloadChecksumA = 1
    local payloadChecksumB = 0
    local minValue = 255
    local maxValue = 0
    local zeroCount = 0

    local okRead, readError = pcall(function()
        for y = 0, height - 1 do
            local row = {}
            for x = 0, width - 1 do
                local value = getBitVectorMapPoint(mapId, x, y, 0, 8)
                if type(value) ~= "number" then
                    error(string.format("invalid byte at x=%d y=%d value=%s", x, y, tostring(value)))
                end

                value = math.max(0, math.min(255, math.floor(value)))
                row[#row + 1] = string.char(value)

                if value < minValue then minValue = value end
                if value > maxValue then maxValue = value end
                if value == 0 then zeroCount = zeroCount + 1 end

                -- Lightweight Adler-32-style checksum for comparing future
                -- network payloads without requiring file read access.
                payloadChecksumA = (payloadChecksumA + value) % 65521
                payloadChecksumB = (payloadChecksumB + payloadChecksumA) % 65521
            end
            payloadParts[#payloadParts + 1] = table.concat(row)
        end
    end)

    safeDeleteHandle(mapId)

    if not okRead then
        diag(string.format("payload extraction failed error=%s", tostring(readError)))
        return false
    end

    local payload = table.concat(payloadParts)
    local checksum = payloadChecksumB * 65536 + payloadChecksumA

    -- Standard DDS header, legacy FOURCC DXT5/BC3, one mip level.
    local DDSD_CAPS = 0x00000001
    local DDSD_HEIGHT = 0x00000002
    local DDSD_WIDTH = 0x00000004
    local DDSD_PIXELFORMAT = 0x00001000
    local DDSD_LINEARSIZE = 0x00080000
    local DDPF_FOURCC = 0x00000004
    local DDSCAPS_TEXTURE = 0x00001000

    local headerParts = {
        "DDS ",
        u32le(124),
        u32le(DDSD_CAPS + DDSD_HEIGHT + DDSD_WIDTH + DDSD_PIXELFORMAT + DDSD_LINEARSIZE),
        u32le(height),
        u32le(width),
        u32le(expectedBc3Bytes),
        u32le(0), -- depth
        u32le(0)  -- mipMapCount (single top mip only)
    }

    for _ = 1, 11 do
        headerParts[#headerParts + 1] = u32le(0)
    end

    headerParts[#headerParts + 1] = u32le(32)          -- DDS_PIXELFORMAT size
    headerParts[#headerParts + 1] = u32le(DDPF_FOURCC)
    headerParts[#headerParts + 1] = "DXT5"
    headerParts[#headerParts + 1] = u32le(0)           -- RGBBitCount
    headerParts[#headerParts + 1] = u32le(0)           -- R mask
    headerParts[#headerParts + 1] = u32le(0)           -- G mask
    headerParts[#headerParts + 1] = u32le(0)           -- B mask
    headerParts[#headerParts + 1] = u32le(0)           -- A mask
    headerParts[#headerParts + 1] = u32le(DDSCAPS_TEXTURE)
    headerParts[#headerParts + 1] = u32le(0)           -- caps2
    headerParts[#headerParts + 1] = u32le(0)           -- caps3
    headerParts[#headerParts + 1] = u32le(0)           -- caps4
    headerParts[#headerParts + 1] = u32le(0)           -- reserved2

    local header = table.concat(headerParts)
    if #header ~= 128 then
        diag(string.format("internal DDS header size error bytes=%d", #header))
        return false
    end

    local ddsData = header .. payload
    local baseDirectory = self:getModSettingsSaveDirectory()
    if baseDirectory == nil or baseDirectory == "" then
        diag("modSettings output directory unavailable")
        return false
    end

    local generatedDirectory = self:joinPath(baseDirectory, "generatedLogos")
    self:ensureFolderExists(generatedDirectory)
    local outputPath = self:joinPath(generatedDirectory, tostring(logoId or "custom_logo") .. "_roundtrip.dds")

    local fileHandle = 0
    local okOpen, openedHandle = pcall(function()
        return createFile(outputPath, FileAccess.WRITE)
    end)
    if okOpen then
        fileHandle = openedHandle or 0
    end

    if not isUsableHandle(fileHandle) then
        diag(string.format("createFile WRITE failed path=%s handle=%s", outputPath, tostring(fileHandle)))
        return false
    end

    local okWrite, writeResult = pcall(function()
        return fileWrite(fileHandle, ddsData)
    end)
    safeDeleteHandle(fileHandle)

    local exists = type(fileExists) == "function" and fileExists(outputPath) or false
    diag(string.format(
        "reconstructed DDS write callOk=%s result=%s payloadBytes=%d totalBytes=%d checksum=%s min=%d max=%d zeros=%d exists=%s path=%s",
        tostring(okWrite), tostring(writeResult), #payload, #ddsData, tostring(checksum), minValue, maxValue, zeroCount, tostring(exists), outputPath
    ))

    if not okWrite or not exists then
        return false
    end

    local textureUsable = false
    if type(createMaterialTextureFromFile) == "function" then
        local okTexture, textureId = pcall(function()
            return createMaterialTextureFromFile(outputPath, true, false)
        end)
        textureUsable = okTexture and isUsableHandle(textureId)
        diag(string.format(
            "reconstructed DDS texture load callOk=%s textureId=%s usable=%s",
            tostring(okTexture), tostring(textureId), tostring(textureUsable)
        ))
        if textureUsable then
            safeDeleteHandle(textureId)
        end
    end

    if textureUsable and logoId ~= nil then
        self.generatedCustomLogoPaths = self.generatedCustomLogoPaths or {}
        self.generatedCustomLogoPaths[logoId] = outputPath
        self.logos[logoId] = outputPath
        diag(string.format("reconstructed DDS activated for logo=%s", tostring(logoId)))
    end

    return textureUsable
end

function FarmIconColor:importCustomLogosFromFolder()
    if not self:isCurrentUserFarmIconAdmin() then
        return false
    end

    -- Keep already registered custom logos in their current selector order.
    -- A manual import only scans for files that are not registered yet, so
    -- newly added DDS files are appended after the existing custom logos.
    self.customLogosLoaded = false
    local loaded = self:tryLoadCustomLogos()

    FarmIconColor:debugPrint(string.format("[%s] customLogos import refresh completed loaded=%s totalSelectable=%d", self.MOD_NAME, tostring(loaded), #(self.logoOrder or {})))

    if loaded == true then
        self:diagnoseCustomLogoEngineIOSupport()
    end

    return loaded == true
end

function FarmIconColor:getModSettingsSaveDirectory()
    if getUserProfileAppPath == nil then
        return nil
    end

    local profilePath = getUserProfileAppPath()

    if profilePath == nil or tostring(profilePath) == "" then
        return nil
    end

    local modSettingsDirectory = self:joinPath(tostring(profilePath), "modSettings")
    local directory = self:joinPath(modSettingsDirectory, "FS25_farmIconColor")

    self:ensureFolderExists(modSettingsDirectory)
    self:ensureFolderExists(directory)

    return directory
end

function FarmIconColor:getSavegameDataFilename()
    local directory = self:getModSettingsSaveDirectory()

    if directory ~= nil and directory ~= "" then
        return self:joinPath(directory, self:getMissionSavegameKey() .. ".xml")
    end

    return self:getLegacySavegameDataFilename()
end

function FarmIconColor:isMultiplayerGame()
    local mission = g_currentMission

    if type(mission) ~= "table" then
        return false
    end

    local dynamicInfo = mission.missionDynamicInfo

    if type(dynamicInfo) == "table" and dynamicInfo.isMultiplayer ~= nil then
        return dynamicInfo.isMultiplayer == true
    end

    local missionInfo = mission.missionInfo

    if type(missionInfo) == "table" and missionInfo.isMultiplayer ~= nil then
        return missionInfo.isMultiplayer == true
    end

    if mission.isMultiplayer ~= nil then
        return mission.isMultiplayer == true
    end

    return false
end

function FarmIconColor:isClientOnlyMultiplayer()
    return self:isMultiplayerGame() and g_client ~= nil and g_server == nil
end

function FarmIconColor:isAuthoritativeInstance()
    return not self:isClientOnlyMultiplayer()
end

function FarmIconColor:tryLoadSavegameData()
    if self.savegameDataLoaded == true then
        return true
    end

    if not self:isAuthoritativeInstance() then
        self.savegameDataLoaded = true
        self.savegameDataLoadAttempted = true

        if not self.clientLocalSavegameSkipLogged then
            self.clientLocalSavegameSkipLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Multiplayer client: local savegame data skipped, waiting for server sync", self.MOD_NAME))
        end

        return false
    end

    local filename = self:getSavegameDataFilename()
    local primaryFilename = filename
    local loadedFromLegacy = false

    if filename == nil then
        return false
    end

    if fileExists ~= nil and not fileExists(filename) then
        local legacyFilename = self:getLegacySavegameDataFilename()

        if legacyFilename ~= nil and legacyFilename ~= filename and fileExists(legacyFilename) then
            filename = legacyFilename
            loadedFromLegacy = true
            FarmIconColor:debugPrint(string.format("[%s] Savegame data primary file missing, loading legacy file: %s", self.MOD_NAME, tostring(legacyFilename)))
        else
            if not self.savegameDataLoadAttempted then
                self.savegameDataLoadAttempted = true
                FarmIconColor:debugPrint(string.format("[%s] No savegame data file yet: %s", self.MOD_NAME, tostring(primaryFilename)))
            end

            self.savegameDataLoaded = true
            return false
        end
    end

    local xmlFile = loadXMLFile("farmIconColorSavegame", filename)

    if xmlFile == nil or xmlFile == 0 then
        if not self.savegameDataLoadAttempted then
            self.savegameDataLoadAttempted = true
            FarmIconColor:debugPrint(string.format("[%s] Savegame data not loaded yet: %s", self.MOD_NAME, tostring(filename)))
        end

        return false
    end

    local count = 0
    local index = 0

    while true do
        local key = string.format("farmIconColor.farm(%d)", index)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local farmId = getXMLString(xmlFile, key .. "#id")
        local colorText = getXMLString(xmlFile, key .. "#color")
        local logoName = getXMLString(xmlFile, key .. "#logo")

        if self:isValidFarmId(farmId) then
            local idKey = tostring(farmId)
            local color = self:parseColor(colorText)

            if color ~= nil then
                self.runtimeFarmColors[idKey] = color
                count = count + 1
            end

            if logoName ~= nil then
                logoName = self:normalizeLogoName(logoName)

                if logoName ~= nil and self.logos[logoName] ~= nil then
                    self.runtimeFarmLogos[idKey] = logoName
                end
            end
        end

        index = index + 1
    end

    delete(xmlFile)
    self.savegameDataLoaded = true
    self.savegameDataLoadAttempted = true

    FarmIconColor:debugPrint(string.format("[%s] Savegame data loaded from %s entries=%s", self.MOD_NAME, tostring(filename), tostring(count)))

    self.runtimeFarmGameColorAppliedSignatures = {}
    self.forceSavedFarmColorSyncTime = 10000
    self:safeCall("apply saved farm colors immediately after load", function()
        self:forceApplyAllSavedFarmVisualColors("savegame data loaded")
    end)

    if loadedFromLegacy then
        self:saveSavegameData("migrate legacy savegame data to modSettings")
    end

    return true
end

function FarmIconColor:saveSavegameData(source)
    if not self:isAuthoritativeInstance() then
        if not self.clientLocalSavegameSaveSkipLogged then
            self.clientLocalSavegameSaveSkipLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Multiplayer client: local savegame save skipped (%s)", self.MOD_NAME, tostring(source)))
        end

        return false
    end

    local filename = self:getSavegameDataFilename()

    if filename == nil then
        FarmIconColor:debugPrint(string.format("[%s] Savegame data save skipped: no savegame directory (%s)", self.MOD_NAME, tostring(source)))
        return false
    end

    local xmlFile = createXMLFile("farmIconColorSavegame", filename, "farmIconColor")

    if xmlFile == nil or xmlFile == 0 then
        FarmIconColor:debugPrint(string.format("[%s] Savegame data save failed: %s (%s)", self.MOD_NAME, tostring(filename), tostring(source)))
        return false
    end

    local farmKeys = {}
    local seen = {}

    if type(self.runtimeFarmColors) == "table" then
        for farmId, _ in pairs(self.runtimeFarmColors) do
            if not seen[tostring(farmId)] then
                table.insert(farmKeys, tostring(farmId))
                seen[tostring(farmId)] = true
            end
        end
    end

    if type(self.runtimeFarmLogos) == "table" then
        for farmId, _ in pairs(self.runtimeFarmLogos) do
            if not seen[tostring(farmId)] then
                table.insert(farmKeys, tostring(farmId))
                seen[tostring(farmId)] = true
            end
        end
    end

    table.sort(farmKeys, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)

    for index, farmId in ipairs(farmKeys) do
        local key = string.format("farmIconColor.farm(%d)", index - 1)
        local color = type(self.runtimeFarmColors) == "table" and self.runtimeFarmColors[tostring(farmId)] or nil
        local logo = type(self.runtimeFarmLogos) == "table" and self.runtimeFarmLogos[tostring(farmId)] or nil

        setXMLString(xmlFile, key .. "#id", tostring(farmId))

        if color ~= nil then
            setXMLString(xmlFile, key .. "#color", self:colorToRgbaText(color) or "")
        end

        if logo ~= nil then
            setXMLString(xmlFile, key .. "#logo", tostring(logo))
        end
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)

    FarmIconColor:debugPrint(string.format("[%s] Savegame data saved from %s to %s entries=%s", self.MOD_NAME, tostring(source), tostring(filename), tostring(#farmKeys)))

    return true
end

function FarmIconColor:getCurrentFarmId()
    if g_currentMission == nil then
        return nil
    end

    if g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
        local farmId = g_currentMission.player.farmId

        if self:isValidFarmId(farmId) then
            return farmId
        end
    end

    if g_currentMission.getFarmId ~= nil then
        local farmId = g_currentMission:getFarmId()

        if self:isValidFarmId(farmId) then
            return farmId
        end
    end

    return nil
end

function FarmIconColor:isValidFarmId(farmId)
    local numericFarmId = tonumber(farmId)

    return numericFarmId ~= nil and numericFarmId > 0
end

function FarmIconColor:getFarmName(farmId)
    if farmId == nil or g_farmManager == nil or g_farmManager.getFarmById == nil then
        return nil
    end

    local farm = g_farmManager:getFarmById(tonumber(farmId) or farmId)

    if farm == nil then
        return nil
    end

    return farm.name
end

function FarmIconColor:tryApplyCurrentFarmConfig(source)
    local farmId = self:getCurrentFarmId()

    if farmId == nil then
        if not self.waitingForFarmLogged then
            self.waitingForFarmLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Current player farmId: not available yet (%s)", self.MOD_NAME, tostring(source)))
        end

        return false
    end

    local farmName = self:getFarmName(farmId) or "unknown"
    local configuredFarm = self.farms[tostring(farmId)]
    local savedColor = self:getRuntimeFarmColor(farmId)
    local savedLogo = type(self.runtimeFarmLogos) == "table" and self.runtimeFarmLogos[tostring(farmId)] or nil

    self.waitingForFarmLogged = false

    FarmIconColor:debugPrint(string.format("[%s] Current player farmId: %s", self.MOD_NAME, tostring(farmId)))
    FarmIconColor:debugPrint(string.format("[%s] Current player farm name: %s", self.MOD_NAME, tostring(farmName)))

    if configuredFarm == nil then
        configuredFarm = {
            color = self.defaultColor,
            logo = "none"
        }

        FarmIconColor:debugPrint(string.format("[%s] No custom config for farmId=%s, applying default color: %s", self.MOD_NAME, tostring(farmId), tostring(self.defaultColor)))
    else
        FarmIconColor:debugPrint(string.format("[%s] Custom config for farmId=%s color=%s logo=%s", self.MOD_NAME, tostring(farmId), tostring(configuredFarm.color), tostring(configuredFarm.logo)))
    end

    if savedColor ~= nil or savedLogo ~= nil then
        configuredFarm = {
            color = self:colorToRgbaText(savedColor) or configuredFarm.color or self.defaultColor,
            logo = savedLogo or configuredFarm.logo
        }

        FarmIconColor:debugPrint(string.format("[%s] Savegame override for farmId=%s color=%s logo=%s", self.MOD_NAME, tostring(farmId), tostring(configuredFarm.color), tostring(configuredFarm.logo)))
    end

    self:applyConfiguredFarmColor(farmId, configuredFarm)

    return self.colorApplied
end

function FarmIconColor:getFarmById(farmId)
    if farmId == nil or g_farmManager == nil or g_farmManager.getFarmById == nil then
        return nil
    end

    local numericFarmId = tonumber(farmId)

    if numericFarmId ~= nil then
        return g_farmManager:getFarmById(numericFarmId)
    end

    return g_farmManager:getFarmById(farmId)
end

function FarmIconColor:valueToString(value)
    if type(value) ~= "table" then
        return tostring(value)
    end

    local values = {}
    local count = 0

    for key, item in pairs(value) do
        count = count + 1

        if count > 8 then
            table.insert(values, "...")
            break
        end

        table.insert(values, string.format("%s=%s", tostring(key), tostring(item)))
    end

    return "{" .. table.concat(values, ", ") .. "}"
end

function FarmIconColor:getObjectFarmId(object)
    if object == nil then
        return nil
    end

    if object.farmId ~= nil then
        return object.farmId
    end

    if object.owner ~= nil then
        return object.owner
    end

    if object.ownerFarmId ~= nil then
        return object.ownerFarmId
    end

    if object.getOwnerFarmId ~= nil then
        local success, farmId = pcall(function()
            return object:getOwnerFarmId()
        end)

        if success then
            return farmId
        end
    end

    if object.vehicle ~= nil and object.vehicle.getOwnerFarmId ~= nil then
        local success, farmId = pcall(function()
            return object.vehicle:getOwnerFarmId()
        end)

        if success then
            return farmId
        end
    end

    if object.placeable ~= nil and object.placeable.getOwnerFarmId ~= nil then
        local success, farmId = pcall(function()
            return object.placeable:getOwnerFarmId()
        end)

        if success then
            return farmId
        end
    end

    return nil
end

function FarmIconColor:getObjectClassName(object)
    if object == nil then
        return "nil"
    end

    if object.className ~= nil then
        return tostring(object.className)
    end

    if object.name ~= nil then
        return tostring(object.name)
    end

    return tostring(object)
end

function FarmIconColor:describeHotspotFields(hotspot)
    local fields = {
        "farmId",
        "ownerFarmId",
        "color",
        "bgColor",
        "backgroundColor",
        "iconColor",
        "labelColor",
        "labelBgColor",
        "labelBackgroundColor",
        "numberColor",
        "fieldColor",
        "overlayColor",
        "textColor",
        "overlay",
        "backgroundOverlay",
        "labelOverlay",
        "numberOverlay",
        "fieldNumberOverlay",
        "isBlinking",
        "vehicle",
        "placeable",
        "player"
    }

    local values = {}

    for _, fieldName in ipairs(fields) do
        local value = hotspot[fieldName]

        if value ~= nil then
            table.insert(values, string.format("%s=%s", fieldName, self:valueToString(value)))
        end
    end

    local methods = {
        "setColor",
        "setBgColor",
        "setBackgroundColor",
        "setIconColor",
        "setLabelColor",
        "setFieldColor",
        "setTextColor",
        "setLabelTextColor",
        "setNumberTextColor"
    }

    for _, methodName in ipairs(methods) do
        if hotspot[methodName] ~= nil then
            table.insert(values, string.format("method:%s", methodName))
        end
    end

    return table.concat(values, "; ")
end

function FarmIconColor:isFieldNumberHotspot(hotspot)
    if type(hotspot) ~= "table" then
        return false
    end

    if hotspot.vehicle ~= nil or hotspot.placeable ~= nil or hotspot.player ~= nil then
        return false
    end

    if hotspot.farmId ~= nil and hotspot.ownerFarmId ~= nil and hotspot.color ~= nil and hotspot.textColor ~= nil then
        return true
    end

    return false
end


function FarmIconColor:applyAllRuntimeFarmGameColors(source)
    if type(self.runtimeFarmColors) ~= "table" then
        return 0
    end

    local totalChanged = 0
    local totalFarms = 0

    for farmId, color in pairs(self.runtimeFarmColors) do
        if self:isValidFarmId(farmId) and type(color) == "table" then
            local numericFarmId = tonumber(farmId) or farmId
            local changed = self:applyGameFarmColorInPlace(numericFarmId, color, source or "runtime farm colors")

            if changed > 0 then
                totalChanged = totalChanged + changed
                totalFarms = totalFarms + 1
            end
        end
    end

    if totalChanged > 0 then
        self:refreshFarmlandAndMapColors(source or "runtime farm colors")
    end

    return totalChanged
end

function FarmIconColor:applyGameFarmColorInPlace(farmId, color, source)
    if not self:isValidFarmId(farmId) then
        return 0
    end

    local customColor = self:copyColor(color)

    if customColor == nil then
        return 0
    end

    local farm = self:getFarmById(farmId)

    if farm == nil then
        return 0
    end

    local changed = 0
    local colorIndex = farm.color

    if colorIndex ~= nil and Farm ~= nil and type(Farm.COLORS) == "table" and type(Farm.COLORS[colorIndex]) == "table" then
        if self.originalFarmColors[colorIndex] == nil then
            self.originalFarmColors[colorIndex] = self:copyColor(Farm.COLORS[colorIndex])
        end

        self:setColorTable(Farm.COLORS[colorIndex], customColor)
        changed = changed + 1
    end

    if farm.getColor ~= nil then
        local success, farmColor = pcall(function()
            return farm:getColor()
        end)

        if success and type(farmColor) == "table" then
            self:setColorTable(farmColor, customColor)
            changed = changed + 1
        end
    end

    self:applyColorFields(farm, customColor, {
        "uiColor",
        "mapColor",
        "farmlandColor",
        "landColor",
        "hotspotColor"
    })

    self:applyMapHotspotColors(farmId, customColor)

    local signature = tostring(farmId) .. ":" .. tostring(self:colorToRgbaText(customColor))
    local sourceText = tostring(source or "")
    local forceRefresh = string.find(sourceText, "force", 1, true) ~= nil
        or string.find(sourceText, "savegame data loaded", 1, true) ~= nil
        or string.find(sourceText, "visible map/lands page", 1, true) ~= nil

    if self.runtimeFarmGameColorAppliedSignatures == nil then
        self.runtimeFarmGameColorAppliedSignatures = {}
    end

    local signatureChanged = self.runtimeFarmGameColorAppliedSignatures[tostring(farmId)] ~= signature

    if changed > 0 and (signatureChanged or forceRefresh) then
        self.runtimeFarmGameColorAppliedSignatures[tostring(farmId)] = signature

        if signatureChanged then
            FarmIconColor:debugPrint(string.format("[%s] Applied saved color to game farm color tables farmId=%s colorIndex=%s color=%s source=%s", self.MOD_NAME, tostring(farmId), tostring(colorIndex), self:valueToString(customColor), tostring(source)))
        end
    end

    if signatureChanged or forceRefresh then
        return changed
    end

    return 0
end

function FarmIconColor:refreshFarmlandAndMapColors(source)
    local refreshed = 0

    local managers = {
        g_farmlandManager,
        g_fieldManager,
        g_currentMission ~= nil and g_currentMission.farmlandManager or nil,
        g_currentMission ~= nil and g_currentMission.fieldManager or nil,
        g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.ingameMap or nil
    }

    local methodNames = {
        "updateColors",
        "updateFarmColors",
        "updateFarmlandColors",
        "updateFarmlandMapping",
        "updateFarmlands",
        "updateMapColors",
        "rebuild",
        "rebuildMap",
        "invalidate",
        "setTerrainDirty"
    }

    for _, manager in ipairs(managers) do
        if type(manager) == "table" then
            for _, methodName in ipairs(methodNames) do
                if type(manager[methodName]) == "function" then
                    local success = pcall(function()
                        manager[methodName](manager)
                    end)

                    if success then
                        refreshed = refreshed + 1
                    end
                end
            end
        end
    end

    if refreshed > 0 then
        FarmIconColor:debugPrint(string.format("[%s] Requested farmland/map color refresh calls=%s source=%s", self.MOD_NAME, tostring(refreshed), tostring(source)))
    end

    return refreshed
end


function FarmIconColor:forceApplyAllSavedFarmVisualColors(source)
    if type(self.runtimeFarmColors) ~= "table" or next(self.runtimeFarmColors) == nil then
        return 0
    end

    local changed = 0

    changed = changed + (self:applyAllRuntimeFarmGameColors(source or "forced saved farm colors") or 0)
    changed = changed + (self:applyAllRuntimeMapHotspotColors(source or "forced saved farm colors") or 0)
    changed = changed + (self:applyRuntimeFarmColorsToMapAndMenuCaches(source or "forced saved farm colors") or 0)

    if changed > 0 then
        self:refreshFarmlandAndMapColors(source or "forced saved farm colors")
    end

    return changed
end

function FarmIconColor:applyAllRuntimeMapHotspotColors(source)
    if type(self.runtimeFarmColors) ~= "table" then
        return 0
    end

    local changed = 0

    for farmId, color in pairs(self.runtimeFarmColors) do
        if self:isValidFarmId(farmId) and type(color) == "table" then
            local before = changed
            self:applyMapHotspotColors(tonumber(farmId) or farmId, color)
            changed = before + 1
        end
    end

    return changed
end

function FarmIconColor:isMapOrLandsMenuVisible()
    local menu = g_currentMission ~= nil and g_currentMission.inGameMenu or nil

    if type(menu) ~= "table" then
        return false
    end

    local page = self:getCurrentIngameMenuPage(menu)

    if type(page) ~= "table" then
        return false
    end

    local pageText = string.lower(self:describeGuiPage(page) or "")

    if string.find(pageText, "map", 1, true) ~= nil
        or string.find(pageText, "land", 1, true) ~= nil
        or string.find(pageText, "farmland", 1, true) ~= nil
        or string.find(pageText, "terre", 1, true) ~= nil then
        return true
    end

    return g_currentMission.hud ~= nil and type(g_currentMission.hud.ingameMap) == "table"
end

function FarmIconColor:applyRuntimeFarmColorsToMapAndMenuCaches(source)
    if type(self.runtimeFarmColors) ~= "table" or next(self.runtimeFarmColors) == nil then
        return 0
    end

    local changed = 0
    local visited = {}
    local roots = {
        g_farmlandManager,
        g_fieldManager,
        g_farmManager,
        g_currentMission ~= nil and g_currentMission.farmlandManager or nil,
        g_currentMission ~= nil and g_currentMission.fieldManager or nil,
        g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.ingameMap or nil,
        g_currentMission ~= nil and g_currentMission.inGameMenu or nil
    }

    for _, root in ipairs(roots) do
        changed = changed + self:applyRuntimeFarmColorsToObjectTree(root, nil, 0, 6, 4500, visited)
    end

    local signature = tostring(source) .. ":" .. tostring(changed)

    if changed > 0 and self.lastForcedLandMenuColorSignature ~= signature then
        self.lastForcedLandMenuColorSignature = signature
        FarmIconColor:debugPrint(string.format("[%s] Applied saved colors to map/lands cached objects changed=%s source=%s", self.MOD_NAME, tostring(changed), tostring(source)))
    end

    return changed
end

function FarmIconColor:applyRuntimeFarmColorsToObjectTree(object, inheritedFarmId, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(object) ~= "table" or depth > maxDepth then
        return 0
    end

    if visited[object] then
        return 0
    end

    visited[object] = true

    local farmId = self:getObjectFarmId(object) or inheritedFarmId
    local changed = 0

    if farmId ~= nil then
        local color = self:getRuntimeFarmColor(farmId)

        if color ~= nil then
            changed = changed + self:applyGenericFarmColorCacheObject(object, color)
        end
    end

    if type(object.elementFarmIdMap) == "table" then
        for mappedElement, mappedFarmId in pairs(object.elementFarmIdMap) do
            if remaining <= 0 then
                break
            end

            if type(mappedElement) == "table" and self:isValidFarmId(mappedFarmId) then
                changed = changed + self:applyRuntimeFarmColorsToObjectTree(mappedElement, mappedFarmId, depth + 1, maxDepth, remaining, visited)
                remaining = remaining - 1
            end
        end
    end

    remaining = remaining - 1

    if type(object.elements) == "table" then
        for _, child in ipairs(object.elements) do
            if remaining <= 0 then
                break
            end

            changed = changed + self:applyRuntimeFarmColorsToObjectTree(child, farmId, depth + 1, maxDepth, remaining, visited)
            remaining = remaining - 1
        end
    end

    local allowedKeyFragments = {
        "farm", "Farm", "land", "Land", "farmland", "Farmland", "field", "Field",
        "map", "Map", "overlay", "Overlay", "legend", "Legend", "color", "Color",
        "hotspot", "Hotspot", "row", "Row", "list", "List", "page", "Page", "box", "Box"
    }

    for key, value in pairs(object) do
        if remaining <= 0 then
            break
        end

        if type(value) == "table" and key ~= "parent" and key ~= "target" and key ~= "mission" then
            local keyText = tostring(key)
            local allowed = false

            for _, fragment in ipairs(allowedKeyFragments) do
                if string.find(keyText, fragment, 1, true) ~= nil then
                    allowed = true
                    break
                end
            end

            if allowed then
                changed = changed + self:applyRuntimeFarmColorsToObjectTree(value, farmId, depth + 1, maxDepth, remaining, visited)
                remaining = remaining - 1
            end
        end
    end

    return changed
end

function FarmIconColor:applyGenericFarmColorCacheObject(object, color)
    if type(object) ~= "table" or type(color) ~= "table" then
        return 0
    end

    local changed = 0

    changed = changed + self:applyColorFields(object, color, {
        "color",
        "colorActive",
        "colorSelected",
        "colorDisabled",
        "bgColor",
        "backgroundColor",
        "backgroundColorActive",
        "iconColor",
        "imageColor",
        "labelColor",
        "labelBgColor",
        "labelBackgroundColor",
        "mapColor",
        "landColor",
        "farmlandColor",
        "farmlandOverlayColor",
        "fieldColor",
        "fieldOwnerColor",
        "ownerColor",
        "ownershipColor",
        "overlayColor",
        "terrainColor",
        "fillColor",
        "renderColor"
    })

    changed = changed + self:applyOverlayFields(object, color, {
        "overlay",
        "backgroundOverlay",
        "iconOverlay",
        "imageOverlay",
        "labelOverlay",
        "colorOverlay",
        "mapOverlay",
        "landOverlay",
        "farmlandOverlay",
        "fieldOverlay",
        "ownershipOverlay"
    })

    changed = changed + self:applyHotspotColorMethods(object, color)

    if object.setImageColor ~= nil then
        local guiColor = self:toGuiDisplayColor(color)
        local success = pcall(function()
            object:setImageColor(self:getGuiNormalState(), guiColor[1], guiColor[2], guiColor[3], guiColor[4] or 1)
        end)

        if not success then
            success = pcall(function()
                object:setImageColor(guiColor)
            end)
        end

        if success then
            changed = changed + 1
        end
    end

    if object.setOverlayColor ~= nil then
        local guiColor = self:toGuiDisplayColor(color)
        local success = pcall(function()
            object:setOverlayColor(self:getGuiNormalState(), guiColor[1], guiColor[2], guiColor[3], guiColor[4] or 1)
        end)

        if not success then
            success = pcall(function()
                object:setOverlayColor(guiColor)
            end)
        end

        if success then
            changed = changed + 1
        end
    end

    if object.updateColors ~= nil then
        pcall(function()
            object:updateColors()
        end)
    end

    if object.invalidateLayout ~= nil then
        pcall(function()
            object:invalidateLayout()
        end)
    end

    if object.updateAbsolutePosition ~= nil then
        pcall(function()
            object:updateAbsolutePosition()
        end)
    end

    return changed
end

function FarmIconColor:applyConfiguredFarmColor(farmId, configuredFarm)
    if self.colorApplied then
        return
    end

    if not self.applyToFarmLogo and not self.applyToPlayerCursor and not self.applyToFarmland and not self.applyToFieldNumbers and not self.applyToVehicleHotspots and not self.applyToObjectHotspots and not self.applyToFarmMenuLogo then
        FarmIconColor:debugPrint(string.format("[%s] Color apply skipped: all apply settings are disabled", self.MOD_NAME))
        return
    end

    local farm = self:getFarmById(farmId)

    if farm == nil then
        FarmIconColor:debugPrint(string.format("[%s] Color apply skipped: farm object not available", self.MOD_NAME))
        return
    end

    if Farm == nil or Farm.COLORS == nil then
        FarmIconColor:debugPrint(string.format("[%s] Color apply skipped: Farm.COLORS not available", self.MOD_NAME))
        return
    end

    local colorIndex = farm.color

    if colorIndex == nil then
        FarmIconColor:debugPrint(string.format("[%s] Color apply skipped: farm.color not available", self.MOD_NAME))
        return
    end

    local customColor, colorSource = self:getConfiguredFarmColor(configuredFarm)

    if customColor == nil then
        FarmIconColor:debugPrint(string.format("[%s] Color apply skipped: invalid color source '%s'", self.MOD_NAME, tostring(colorSource)))
        return
    end

    local currentColor = nil

    if farm.getColor ~= nil then
        local success, color = pcall(function()
            return farm:getColor()
        end)

        if success and type(color) == "table" then
            currentColor = color
        end
    end

    if currentColor == nil and Farm.COLORS[colorIndex] ~= nil then
        currentColor = Farm.COLORS[colorIndex]
    end

    if currentColor == nil then
        FarmIconColor:debugPrint(string.format("[%s] Color apply skipped: current farm color table not available", self.MOD_NAME))
        return
    end

    if self.originalFarmColors[colorIndex] == nil then
        self.originalFarmColors[colorIndex] = self:copyColor(currentColor)
    end

    currentColor[1] = customColor[1]
    currentColor[2] = customColor[2]
    currentColor[3] = customColor[3]
    currentColor[4] = customColor[4]

    if type(Farm.COLORS[colorIndex]) == "table" then
        Farm.COLORS[colorIndex][1] = customColor[1]
        Farm.COLORS[colorIndex][2] = customColor[2]
        Farm.COLORS[colorIndex][3] = customColor[3]
        Farm.COLORS[colorIndex][4] = customColor[4]
    end

    self.colorApplied = true
    self.appliedFarmId = farmId
    self.appliedColor = self:copyColor(customColor) or customColor

    FarmIconColor:debugPrint(string.format("[%s] Applied custom color in-place for farmId=%s colorIndex=%s color=%s source=%s", self.MOD_NAME, tostring(farmId), tostring(colorIndex), self:valueToString(customColor), tostring(colorSource)))

    if farm.getColor ~= nil then
        local success, color = pcall(function()
            return farm:getColor()
        end)

        if success then
            FarmIconColor:debugPrint(string.format("[%s] Farm getColor() after apply: %s", self.MOD_NAME, self:valueToString(color)))
        else
            FarmIconColor:debugPrint(string.format("[%s] Farm getColor() after apply failed: %s", self.MOD_NAME, tostring(color)))
        end
    end

    self:applyMapHotspotColors(farmId, customColor)
end

function FarmIconColor:getLogoSelectorKeyCode(candidates)
    if Input == nil then
        return nil
    end

    for _, keyName in ipairs(candidates) do
        if Input[keyName] ~= nil then
            return Input[keyName]
        end
    end

    return nil
end

function FarmIconColor:checkPrototypeLogoSelectorHotkeys()
    if Input == nil or Input.isKeyPressed == nil then
        if not self.logoSelectorInputMissingLogged then
            self.logoSelectorInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Logo selector hotkeys unavailable: Input system not found", self.MOD_NAME))
        end

        return
    end

    local previousKey = self:getLogoSelectorKeyCode({
        "KEY_KP_4",
        "KEY_KP4",
        "KEY_NUMPAD4",
        "KEY_NUM_4"
    })

    local nextKey = self:getLogoSelectorKeyCode({
        "KEY_KP_6",
        "KEY_KP6",
        "KEY_NUMPAD6",
        "KEY_NUM_6"
    })

    if previousKey == nil or nextKey == nil then
        if not self.logoSelectorInputMissingLogged then
            self.logoSelectorInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Logo selector hotkeys unavailable: numpad 4/6 key codes not found", self.MOD_NAME))
        end

        return
    end

    if not self:hasVisibleFarmEditDialog() or g_gui.currentListener == ColorPickerDialog then
        self.logoSelectorPreviousKeyDown = false
        self.logoSelectorNextKeyDown = false
        return
    end

    local successPrevious, previousPressed = pcall(function()
        return Input.isKeyPressed(previousKey)
    end)

    local successNext, nextPressed = pcall(function()
        return Input.isKeyPressed(nextKey)
    end)

    if not successPrevious or not successNext then
        return
    end

    if previousPressed and not self.logoSelectorPreviousKeyDown then
        self:selectLogoInActiveFarmDialog(-1)
    end

    if nextPressed and not self.logoSelectorNextKeyDown then
        self:selectLogoInActiveFarmDialog(1)
    end

    self.logoSelectorPreviousKeyDown = previousPressed
    self.logoSelectorNextKeyDown = nextPressed
end

function FarmIconColor:selectLogoInActiveFarmDialog(offset)
    self:ensureSelectableLogos()

    local currentLogoName = self:getActiveFarmDialogLogoName()
    local newLogoName = self:getLogoNameByOffset(currentLogoName, offset)

    self:setLogoInActiveFarmDialogByName(newLogoName)
end

function FarmIconColor:setLogoInActiveFarmDialogByIndex(index)
    self:ensureSelectableLogos()

    local logoIndex = tonumber(index)

    if logoIndex == nil then
        return
    end

    logoIndex = math.floor(logoIndex)

    if logoIndex < 1 or logoIndex > #self.logoOrder then
        return
    end

    self:setLogoInActiveFarmDialogByName(self.logoOrder[logoIndex])
end

function FarmIconColor:setLogoInActiveFarmDialogByName(newLogoName)
    self:ensureSelectableLogos()

    if newLogoName == nil or self.logos[newLogoName] == nil then
        return
    end

    local farmId = self:getActiveFarmDialogFarmId()
    local isExistingFarm = self:isValidFarmId(farmId)
    local color = nil

    if isExistingFarm then
        color = self:getRuntimeFarmColor(farmId)
            or self:getCurrentColorForFarmId(farmId)
            or self:getSelectedDialogColor()
            or self:parseColor(self.defaultColor)

        self:setRuntimeFarmLogo(farmId, newLogoName, "existing farm logo selector")
    else
        if self.pendingFarmCreationKnownFarmIds == nil then
            self:snapshotFarmIdsForPendingCreation("logo selector")
        end

        color = self.pendingFarmCreationColor or {1, 1, 1, 1}
        self.pendingFarmCreationLogoName = newLogoName
        self.pendingFarmCreationColorApplied = false
    end

    self.farmDialogCustomLogoApplyLogged = false
    self.farmDialogLogoApplyLogged = false
    self.lastDialogLogoColorSignature = nil

    local logoElement = self:getVisibleDialogPreviewLogoElement()

    if logoElement ~= nil then
        logoElement.farmIconColorLogoName = newLogoName
        logoElement.farmIconColorTextureFilename = nil
        logoElement.farmIconColorTextureLogged = false

        self:applyCustomLogoTexture(logoElement)

        if color ~= nil then
            self:applyGuiImageElementColor(logoElement, color)
        end
    end

    self:scheduleDialogLogoRefresh(isExistingFarm and farmId or nil, color, 10)

    FarmIconColor:debugPrint(string.format(
        "[%s] Selected farm logo: %s farmId=%s",
        self.MOD_NAME,
        tostring(self:getLogoDisplayName(newLogoName)),
        tostring(farmId)
    ))

    self:updateActiveFarmDialogLogoSelectorLabel()
end

function FarmIconColor:getActiveFarmDialogLogoName()
    local farmId = self:getActiveFarmDialogFarmId()

    if self:isValidFarmId(farmId) then
        local runtimeLogo = self.runtimeFarmLogos ~= nil and self.runtimeFarmLogos[tostring(farmId)] or nil

        if runtimeLogo ~= nil and self.logos[runtimeLogo] ~= nil then
            return runtimeLogo
        end

        return self:getConfiguredLogoNameForFarmId(farmId) or self:getDefaultCustomLogoName()
    end

    if self.pendingFarmCreationLogoName == nil then
        self.pendingFarmCreationLogoName = self:getDefaultCustomLogoName()
    end

    return self.pendingFarmCreationLogoName
end

function FarmIconColor:getLogoSelectorLabelText()
    local logoName = self:getActiveFarmDialogLogoName()
    local displayName = self:getLogoDisplayName(logoName)
    local selectorLabel = self:getTranslatedText("farmIconColor_logoSelector", "Logo de la ferme")





    local nbsp = string.char(194, 160)
    local valuePadding = string.rep(nbsp, 16)


    return string.format("%s:%s<  %s  >", tostring(selectorLabel), valuePadding, tostring(displayName))
end

function FarmIconColor:getTranslatedText(key, fallback)
    if key ~= nil and g_i18n ~= nil and g_i18n.getText ~= nil then
        local success, text = pcall(function()
            return g_i18n:getText(key)
        end)

        if success and text ~= nil and text ~= "" and text ~= key then
            return text
        end
    end

    return fallback
end

function FarmIconColor:hookFarmDialogLogoSelectorLabel(element)
    if type(element) ~= "table" or element.farmIconColorLogoSelectorClickHooked == true then
        return
    end

    element.farmIconColorLogoSelectorClickHooked = true
    element.farmIconColorLogoSelectorLabel = true
    element.disabled = false

    if element.setDisabled ~= nil then
        pcall(function()
            element:setDisabled(false)
        end)
    end

    element.onClickCallback = function()
        FarmIconColor:selectLogoInActiveFarmDialog(1)
    end
end


function FarmIconColor:prepareFarmDialogLogoSelectorLabelElement(element)
    if type(element) ~= "table" then
        return
    end






    local wantedWidth = 0.0780
    local wantedHeight = 0.018518518518518517

    if type(element.size) == "table" then
        element.size[1] = wantedWidth

        if element.size[2] == nil or element.size[2] < wantedHeight then
            element.size[2] = wantedHeight
        end
    end

    if element.setSize ~= nil then
        pcall(function()
            element:setSize(wantedWidth, wantedHeight)
        end)
    end

    if element.setTextAlignment ~= nil and RenderText ~= nil and RenderText.ALIGN_RIGHT ~= nil then
        pcall(function()
            element:setTextAlignment(RenderText.ALIGN_RIGHT)
        end)
    end

    if RenderText ~= nil and RenderText.ALIGN_RIGHT ~= nil then
        element.textAlignment = RenderText.ALIGN_RIGHT
    end

    element.clipText = false
    element.doLineWrapping = false



    self.nativeLogoSelectorLabelProfile = element.profile
    self.nativeLogoSelectorLabelTextSize = tonumber(element.textSize)
        or tonumber(element.fontSize)
        or tonumber(element.textSizeBackup)
        or 0.0105
end

function FarmIconColor:getLogoSelectorTitleText()
    local selectorLabel = self:getTranslatedText("farmIconColor_logoSelector", "Logo de la ferme")

    return tostring(selectorLabel) .. ":"
end

function FarmIconColor:shouldShowLogoSelectorText()
    return false
end

function FarmIconColor:getLogoSelectorDisplayTexts()
    self:ensureSelectableLogos()

    local texts = {}
    local showSelectorText = self:shouldShowLogoSelectorText()

    for _, logoName in ipairs(self.logoOrder) do
        if showSelectorText then
            table.insert(texts, self:getLogoDisplayName(logoName))
        else
            table.insert(texts, "")
        end
    end

    return texts
end

function FarmIconColor:findNativeMultiTextOptionTemplate()
    if self.nativeLogoSelectorElement ~= nil then
        return self.nativeLogoSelectorElement
    end

    if g_gui == nil then
        return nil
    end

    local roots = {
        g_gui.currentListener,
        g_gui.currentGui,
        g_gui.currentScreen,
        g_gui.currentDialog
    }

    if type(g_gui.dialogs) == "table" then
        for _, dialog in pairs(g_gui.dialogs) do
            table.insert(roots, dialog)
        end
    end

    for _, root in ipairs(roots) do
        local candidate = self:findNativeMultiTextOptionTemplateInTree(root, 0, 11, 650, {})

        if candidate ~= nil then
            self.nativeLogoSelectorElement = candidate
            FarmIconColor:debugPrint(string.format("[%s] Native MultiTextOption template captured: profile=%s text=%s", self.MOD_NAME, tostring(candidate.profile), tostring(self:getGuiElementText(candidate))))
            return candidate
        end
    end

    return nil
end

function FarmIconColor:findNativeMultiTextOptionTemplateInTree(element, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    if visited[element] then
        return nil
    end

    visited[element] = true

    if self:isNativeMultiTextOptionSelector(element) then
        return element
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            local candidate = self:findNativeMultiTextOptionTemplateInTree(child, depth + 1, maxDepth, remaining, visited)

            if candidate ~= nil then
                return candidate
            end

            remaining = remaining - 1

            if remaining <= 0 then
                break
            end
        end
    end

    return nil
end

function FarmIconColor:isNativeMultiTextOptionSelector(element)
    if type(element) ~= "table" then
        return false
    end

    if element.farmIconColorNativeLogoSelector == true then
        return true
    end

    local typeName = element.typeName ~= nil and tostring(element.typeName) or ""
    local profile = element.profile ~= nil and tostring(element.profile) or ""

    if string.find(typeName, "MultiTextOption", 1, true) == nil then
        return false
    end

    if string.find(profile, "subCategorySelector", 1, true) == nil and profile ~= "" then
        return false
    end

    if element.setTexts == nil or element.setState == nil or element.getState == nil then
        return false
    end

    local leftButton, rightButton, textElement = self:getNativeLogoSelectorParts(element)

    return leftButton ~= nil and rightButton ~= nil and textElement ~= nil
end

function FarmIconColor:getNativeLogoSelectorParts(selector)
    if type(selector) ~= "table" or type(selector.elements) ~= "table" then
        return nil, nil, nil
    end

    local leftButton = nil
    local rightButton = nil
    local textElement = nil

    for _, child in ipairs(selector.elements) do
        if type(child) == "table" then
            local name = string.lower(tostring(child.name or ""))
            local profile = string.lower(tostring(child.profile or ""))
            local text = string.lower(tostring(self:getGuiElementText(child) or ""))

            if leftButton == nil and (name == "left" or string.find(profile, "arrowleft", 1, true) ~= nil or string.find(text, "arrowleft", 1, true) ~= nil) then
                leftButton = child
            elseif rightButton == nil and (name == "right" or string.find(profile, "arrowright", 1, true) ~= nil or string.find(text, "arrowright", 1, true) ~= nil) then
                rightButton = child
            elseif textElement == nil and (name == "text" or string.find(profile, "selectortext", 1, true) ~= nil) then
                textElement = child
            end
        end
    end

    return leftButton, rightButton, textElement
end

function FarmIconColor:applyNativeLogoSelectorSmallTextStyle(textElement, displayName)
    if type(textElement) ~= "table" then
        return
    end




    local wantedTextSize = tonumber(self.nativeLogoSelectorLabelTextSize) or 0.0105
    local wantedProfile = self.nativeLogoSelectorLabelProfile

    local oldX = type(textElement.position) == "table" and textElement.position[1] or nil
    local oldY = type(textElement.position) == "table" and textElement.position[2] or nil
    local oldW = type(textElement.size) == "table" and textElement.size[1] or nil
    local oldH = type(textElement.size) == "table" and textElement.size[2] or nil

    if wantedProfile ~= nil and wantedProfile ~= "" then
        if textElement.applyProfile ~= nil then
            pcall(function()
                textElement:applyProfile(wantedProfile)
            end)
        end

        if textElement.setProfile ~= nil then
            pcall(function()
                textElement:setProfile(wantedProfile)
            end)
        end

        textElement.profile = wantedProfile
    end



    if oldX ~= nil or oldY ~= nil then
        textElement.position = textElement.position or {}
        textElement.position[1] = oldX or textElement.position[1]
        textElement.position[2] = oldY or textElement.position[2]

        if textElement.setPosition ~= nil then
            pcall(function()
                textElement:setPosition(textElement.position[1], textElement.position[2])
            end)
        end
    end

    if oldW ~= nil or oldH ~= nil then
        textElement.size = textElement.size or {}
        textElement.size[1] = oldW or textElement.size[1]
        textElement.size[2] = oldH or textElement.size[2]

        if textElement.setSize ~= nil then
            pcall(function()
                textElement:setSize(textElement.size[1], textElement.size[2])
            end)
        end
    end

    if displayName ~= nil then




        local displayedName = tostring(displayName)
        local paddingCount = tonumber(self.NATIVE_LOGO_SELECTOR_TEXT_CENTER_PADDING) or 0

        if paddingCount > 0 then
            local nbsp = string.char(194, 160)
            displayedName = string.rep(nbsp, paddingCount) .. displayedName
        end

        self:setGuiElementText(textElement, displayedName)
        textElement.text = displayedName
    end

    if textElement.setTextAlignment ~= nil and RenderText ~= nil and RenderText.ALIGN_CENTER ~= nil then
        pcall(function()
            textElement:setTextAlignment(RenderText.ALIGN_CENTER)
        end)
    end

    if RenderText ~= nil and RenderText.ALIGN_CENTER ~= nil then
        textElement.textAlignment = RenderText.ALIGN_CENTER
    end

    if textElement.setTextSize ~= nil then
        pcall(function()
            textElement:setTextSize(wantedTextSize)
        end)
    end



    textElement.textSize = wantedTextSize
    textElement.fontSize = wantedTextSize
    textElement.textSizeBackup = wantedTextSize
    textElement.textSizeDefault = wantedTextSize
    textElement.farmIconColorForcedTextSize = wantedTextSize

    textElement.clipText = false
    textElement.doLineWrapping = false
end


function FarmIconColor:copySequence(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        if type(item) ~= "table" then
            copy[key] = item
        end
    end

    return copy
end

function FarmIconColor:getElementIndexInParent(element)
    if type(element) ~= "table" or type(element.parent) ~= "table" or type(element.parent.elements) ~= "table" then
        return nil
    end

    for index, child in ipairs(element.parent.elements) do
        if child == element then
            return index
        end
    end

    return nil
end

function FarmIconColor:rememberNativeSelectorOriginalState(selector)
    if type(selector) ~= "table" or selector.farmIconColorOriginalRemembered == true then
        return
    end

    selector.farmIconColorOriginalParent = selector.parent
    selector.farmIconColorOriginalIndex = self:getElementIndexInParent(selector)
    selector.farmIconColorOriginalPosition = self:copySequence(selector.position)
    selector.farmIconColorOriginalSize = self:copySequence(selector.size)
    selector.farmIconColorOriginalTexts = self:copySequence(selector.texts)
    selector.farmIconColorOriginalText = selector.text
    selector.farmIconColorOriginalOnClickCallback = selector.onClickCallback
    selector.farmIconColorOriginalProfile = selector.profile

    local _, _, originalTextElement = self:getNativeLogoSelectorParts(selector)

    if type(originalTextElement) == "table" then
        selector.farmIconColorOriginalTextElement = originalTextElement
        selector.farmIconColorOriginalTextElementProfile = originalTextElement.profile
        selector.farmIconColorOriginalTextElementText = originalTextElement.text
        selector.farmIconColorOriginalTextElementPosition = self:copySequence(originalTextElement.position)
        selector.farmIconColorOriginalTextElementSize = self:copySequence(originalTextElement.size)
        selector.farmIconColorOriginalTextElementTextSize = tonumber(originalTextElement.textSize)
            or tonumber(originalTextElement.fontSize)
            or tonumber(originalTextElement.textSizeBackup)
    end

    if selector.getState ~= nil then
        local success, state = pcall(function()
            return selector:getState()
        end)

        if success then
            selector.farmIconColorOriginalState = state
        end
    else
        selector.farmIconColorOriginalState = selector.state
    end

    selector.farmIconColorOriginalRemembered = true
end

function FarmIconColor:restoreNativeLogoSelectorToOriginalParent()
    local selector = self.nativeLogoSelectorElement

    if type(selector) ~= "table" or selector.farmIconColorNativeLogoSelector ~= true then
        return false
    end

    self:showGuiElement(selector)

    local originalParent = selector.farmIconColorOriginalParent

    if type(originalParent) ~= "table" then
        return false
    end

    self:removeElementFromCurrentParent(selector)

    originalParent.elements = originalParent.elements or {}

    local insertIndex = tonumber(selector.farmIconColorOriginalIndex) or (#originalParent.elements + 1)

    if insertIndex < 1 then
        insertIndex = 1
    end

    if insertIndex > #originalParent.elements + 1 then
        insertIndex = #originalParent.elements + 1
    end

    table.insert(originalParent.elements, insertIndex, selector)
    selector.parent = originalParent

    if selector.farmIconColorOriginalPosition ~= nil then
        selector.position = self:copySequence(selector.farmIconColorOriginalPosition)

        if selector.setPosition ~= nil then
            pcall(function()
                selector:setPosition(selector.position[1], selector.position[2])
            end)
        end
    end

    if selector.farmIconColorOriginalSize ~= nil then
        selector.size = self:copySequence(selector.farmIconColorOriginalSize)

        if selector.setSize ~= nil then
            pcall(function()
                selector:setSize(selector.size[1], selector.size[2])
            end)
        end
    end

    if selector.farmIconColorOriginalTexts ~= nil then
        selector.texts = self:copySequence(selector.farmIconColorOriginalTexts)

        if selector.setTexts ~= nil then
            pcall(function()
                selector:setTexts(selector.texts)
            end)
        end
    end

    if selector.farmIconColorOriginalText ~= nil then
        self:setGuiElementText(selector, selector.farmIconColorOriginalText)
        selector.text = selector.farmIconColorOriginalText
    end

    selector.onClickCallback = selector.farmIconColorOriginalOnClickCallback

    if selector.farmIconColorOriginalState ~= nil then
        selector.state = selector.farmIconColorOriginalState

        if selector.setState ~= nil then
            pcall(function()
                selector:setState(selector.farmIconColorOriginalState)
            end)
        end
    end

    local originalTextElement = selector.farmIconColorOriginalTextElement

    if type(originalTextElement) == "table" then
        self:showGuiElement(originalTextElement)

        if selector.farmIconColorOriginalTextElementProfile ~= nil then
            if originalTextElement.applyProfile ~= nil then
                pcall(function()
                    originalTextElement:applyProfile(selector.farmIconColorOriginalTextElementProfile)
                end)
            end

            if originalTextElement.setProfile ~= nil then
                pcall(function()
                    originalTextElement:setProfile(selector.farmIconColorOriginalTextElementProfile)
                end)
            end

            originalTextElement.profile = selector.farmIconColorOriginalTextElementProfile
        end

        if selector.farmIconColorOriginalTextElementPosition ~= nil then
            originalTextElement.position = self:copySequence(selector.farmIconColorOriginalTextElementPosition)

            if originalTextElement.setPosition ~= nil then
                pcall(function()
                    originalTextElement:setPosition(originalTextElement.position[1], originalTextElement.position[2])
                end)
            end
        end

        if selector.farmIconColorOriginalTextElementSize ~= nil then
            originalTextElement.size = self:copySequence(selector.farmIconColorOriginalTextElementSize)

            if originalTextElement.setSize ~= nil then
                pcall(function()
                    originalTextElement:setSize(originalTextElement.size[1], originalTextElement.size[2])
                end)
            end
        end

        if selector.farmIconColorOriginalTextElementTextSize ~= nil then
            if originalTextElement.setTextSize ~= nil then
                pcall(function()
                    originalTextElement:setTextSize(selector.farmIconColorOriginalTextElementTextSize)
                end)
            end

            originalTextElement.textSize = selector.farmIconColorOriginalTextElementTextSize
            originalTextElement.fontSize = selector.farmIconColorOriginalTextElementTextSize
            originalTextElement.textSizeBackup = selector.farmIconColorOriginalTextElementTextSize
        end

        if selector.farmIconColorOriginalTextElementText ~= nil then
            self:setGuiElementText(originalTextElement, selector.farmIconColorOriginalTextElementText)
            originalTextElement.text = selector.farmIconColorOriginalTextElementText
        end
    end

    selector.farmIconColorNativeLogoSelector = false

    if selector.updateAbsolutePositionRec ~= nil then
        pcall(function()
            selector:updateAbsolutePositionRec()
        end)
    elseif selector.updateAbsolutePosition ~= nil then
        pcall(function()
            selector:updateAbsolutePosition()
        end)
    end

    FarmIconColor:debugPrint(string.format("[%s] Native farm logo selector restored to original GUI parent", self.MOD_NAME))

    return true
end

function FarmIconColor:removeElementFromCurrentParent(element)
    if type(element) ~= "table" or type(element.parent) ~= "table" or type(element.parent.elements) ~= "table" then
        return
    end

    local oldElements = element.parent.elements

    for i = #oldElements, 1, -1 do
        if oldElements[i] == element then
            table.remove(oldElements, i)
        end
    end
end

function FarmIconColor:attachNativeLogoSelectorToFarmDialog(label)
    if type(label) ~= "table" or type(label.parent) ~= "table" then
        return nil
    end

    local parent = label.parent
    local selector = self:findNativeMultiTextOptionTemplate()

    if selector == nil then
        return nil
    end

    if selector.farmIconColorNativeLogoSelector ~= true then
        self:rememberNativeSelectorOriginalState(selector)
        self:removeElementFromCurrentParent(selector)

        parent.elements = parent.elements or {}
        table.insert(parent.elements, selector)

        selector.parent = parent
        selector.farmIconColorNativeLogoSelector = true
        selector.farmIconColorOriginalProfile = selector.profile

        FarmIconColor:debugPrint(string.format("[%s] Native farm logo selector attached to FarmEditDialog row", self.MOD_NAME))
    elseif selector.parent ~= parent then
        self:removeElementFromCurrentParent(selector)

        parent.elements = parent.elements or {}
        table.insert(parent.elements, selector)

        selector.parent = parent
    end

    return selector
end

function FarmIconColor:getGuiElementAbsPosition(element)
    if type(element) ~= "table" then
        return 0, 0
    end

    if type(element.absPosition) == "table" then
        return tonumber(element.absPosition[1]) or 0, tonumber(element.absPosition[2]) or 0
    end

    if type(element.absolutePosition) == "table" then
        return tonumber(element.absolutePosition[1]) or 0, tonumber(element.absolutePosition[2]) or 0
    end

    return 0, 0
end

function FarmIconColor:prepareNativeLogoSelectorElement(selector, label)
    if type(selector) ~= "table" then
        return
    end





    local parent = selector.parent
    local selectorX = 0.084375
    local selectorY = 0
    local selectorW = 0.184375
    local selectorH = 0.03888888888888889

    if type(label) == "table" and type(label.parent) == "table" then
        parent = label.parent

        local labelAbsX = nil
        local parentAbsX = nil

        if type(label.absPosition) == "table" then
            labelAbsX = tonumber(label.absPosition[1])
        elseif type(label.absolutePosition) == "table" then
            labelAbsX = tonumber(label.absolutePosition[1])
        end

        if type(parent.absPosition) == "table" then
            parentAbsX = tonumber(parent.absPosition[1])
        elseif type(parent.absolutePosition) == "table" then
            parentAbsX = tonumber(parent.absolutePosition[1])
        end

        if labelAbsX ~= nil and parentAbsX ~= nil then


            selectorX = (labelAbsX + 0.0320) - parentAbsX
        end
    end

    if type(label) == "table" and type(label.position) == "table" then
        selectorY = label.position[2] or 0
    end

    selector.position = selector.position or {}
    selector.position[1] = selectorX
    selector.position[2] = selectorY

    selector.size = selector.size or {}
    selector.size[1] = selectorW
    selector.size[2] = selectorH

    if selector.setPosition ~= nil then
        pcall(function()
            selector:setPosition(selectorX, selectorY)
        end)
    end

    if selector.setSize ~= nil then
        pcall(function()
            selector:setSize(selectorW, selectorH)
        end)
    end

    self:showGuiElement(selector)

    local leftButton, rightButton, textElement = self:getNativeLogoSelectorParts(selector)

    if leftButton ~= nil then
        self:showGuiElement(leftButton)
    end

    if rightButton ~= nil then
        self:showGuiElement(rightButton)
    end

    if textElement ~= nil then
        if self:shouldShowLogoSelectorText() then
            self:showGuiElement(textElement)
            self:applyNativeLogoSelectorSmallTextStyle(textElement, nil)
        else
            self:showGuiElement(textElement)
            self:setGuiElementText(textElement, "")
            textElement.text = ""
        end
    end

    if selector.updateAbsolutePositionRec ~= nil then
        pcall(function()
            selector:updateAbsolutePositionRec()
        end)
    elseif selector.updateAbsolutePosition ~= nil then
        pcall(function()
            selector:updateAbsolutePosition()
        end)
    end
end

function FarmIconColor:updateNativeLogoSelectorState(selector)
    if type(selector) ~= "table" then
        return false
    end

    self:ensureSelectableLogos()

    local currentLogoName = self:getActiveFarmDialogLogoName()
    local currentIndex = self:getLogoIndex(currentLogoName)
    local texts = self:getLogoSelectorDisplayTexts()

    self.nativeLogoSelectorUpdating = true

    if selector.setTexts ~= nil then
        pcall(function()
            selector:setTexts(texts)
        end)
    end

    selector.texts = texts

    if selector.setState ~= nil then
        pcall(function()
            selector:setState(currentIndex)
        end)
    end

    selector.state = currentIndex

    local _, _, textElement = self:getNativeLogoSelectorParts(selector)

    if textElement ~= nil then
        if self:shouldShowLogoSelectorText() then
            self:showGuiElement(textElement)
            local displayName = self:getLogoDisplayName(currentLogoName)
            self:applyNativeLogoSelectorSmallTextStyle(textElement, displayName)
        else
            self:showGuiElement(textElement)
            self:setGuiElementText(textElement, "")
            textElement.text = ""
        end
    end

    selector.onClickCallback = function()
        if FarmIconColor.nativeLogoSelectorUpdating == true then
            return
        end

        local state = selector.state

        if selector.getState ~= nil then
            local success, result = pcall(function()
                return selector:getState()
            end)

            if success then
                state = result
            end
        end

        FarmIconColor:setLogoInActiveFarmDialogByIndex(state)
    end

    self.nativeLogoSelectorUpdating = false

    return true
end

function FarmIconColor:updateFarmDialogNativeLogoSelector(label)
    local selector = self:attachNativeLogoSelectorToFarmDialog(label)

    if selector == nil then
        return false
    end



    self:prepareNativeLogoSelectorElement(selector, label)
    self:updateNativeLogoSelectorState(selector)
    self:prepareNativeLogoSelectorElement(selector, label)

    return true
end

function FarmIconColor:updateActiveFarmDialogLogoSelectorLabel()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return
    end

    if not self:hasVisibleFarmEditDialog() then
        self:restoreNativeLogoSelectorToOriginalParent()
        self.logoSelectorLastText = nil
        return
    end

    if g_gui.currentListener == ColorPickerDialog then
        self.logoSelectorLastText = nil
        return
    end

    local fallbackLabelText = self:getLogoSelectorLabelText()
    local titleText = self:getLogoSelectorTitleText()
    local changed = 0
    local nativeSelectorUsed = false

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            local label = self:getFarmDialogLogoSelectorLabelElement(dialog)

            if label ~= nil then
                self:showGuiElementWithParents(label)
                self:prepareFarmDialogLogoSelectorLabelElement(label)

                if self:updateFarmDialogNativeLogoSelector(label) then
                    self:setGuiElementText(label, titleText)
                    nativeSelectorUsed = true
                else
                    self:setGuiElementText(label, fallbackLabelText)
                    self:hookFarmDialogLogoSelectorLabel(label)
                end

                label.farmIconColorLogoSelectorLabel = true
                changed = changed + 1
            end

            if type(dialog.target) == "table" then
                local targetLabel = self:getFarmDialogLogoSelectorLabelElement(dialog.target)

                if targetLabel ~= nil and targetLabel ~= label then
                    self:showGuiElementWithParents(targetLabel)
                    self:prepareFarmDialogLogoSelectorLabelElement(targetLabel)

                    if self:updateFarmDialogNativeLogoSelector(targetLabel) then
                        self:setGuiElementText(targetLabel, titleText)
                        nativeSelectorUsed = true
                    else
                        self:setGuiElementText(targetLabel, fallbackLabelText)
                        self:hookFarmDialogLogoSelectorLabel(targetLabel)
                    end

                    targetLabel.farmIconColorLogoSelectorLabel = true
                    changed = changed + 1
                end
            end
        end
    end

    local logText = nativeSelectorUsed and (titleText .. " [native selector]") or fallbackLabelText

    if changed > 0 and self.logoSelectorLastText ~= logText then
        self.logoSelectorLastText = logText
        FarmIconColor:debugPrint(string.format("[%s] Updated farm logo selector label: %s", self.MOD_NAME, tostring(logText)))
    end
end

function FarmIconColor:getFarmDialogLogoSelectorLabelElement(dialog)
    if type(dialog) ~= "table" then
        return nil
    end

    return self:findFarmDialogLogoSelectorLabelElement(dialog, 0, 8, 350, {})
end

function FarmIconColor:findFarmDialogLogoSelectorLabelElement(element, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    if visited[element] then
        return nil
    end

    visited[element] = true

    if element.farmIconColorLogoSelectorLabel == true then
        return element
    end

    if self:isFarmDialogColorLabelElement(element) then
        return element
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            if remaining <= 0 then
                break
            end

            local match = self:findFarmDialogLogoSelectorLabelElement(child, depth + 1, maxDepth, remaining, visited)

            if match ~= nil then
                return match
            end

            remaining = remaining - 1
        end
    end


    for key, value in pairs(element) do
        if remaining <= 0 then
            break
        end

        if type(value) == "table"
            and key ~= "parent"
            and key ~= "target"
            and key ~= "player"
            and key ~= "users"
            and key ~= "farms"
            and key ~= "mission"
            and key ~= "map"
            and key ~= "vehicles"
        then
            local match = self:findFarmDialogLogoSelectorLabelElement(value, depth + 1, maxDepth, remaining, visited)

            if match ~= nil then
                return match
            end

            remaining = remaining - 1
        end
    end

    return nil
end


function FarmIconColor:isSingleplayerGame()
    if g_currentMission == nil then
        return false
    end

    local dynamicInfo = g_currentMission.missionDynamicInfo

    if type(dynamicInfo) == "table" and dynamicInfo.isMultiplayer ~= nil then
        return dynamicInfo.isMultiplayer ~= true
    end

    local missionInfo = g_currentMission.missionInfo

    if type(missionInfo) == "table" and missionInfo.isMultiplayer ~= nil then
        return missionInfo.isMultiplayer ~= true
    end

    if g_currentMission.isMultiplayer ~= nil then
        return g_currentMission.isMultiplayer ~= true
    end

    return false
end

function FarmIconColor:isSoloF9ColorPickerAllowed()
    if not self:isSingleplayerGame() then
        return false
    end

    if g_currentMission == nil or not self:isValidFarmId(self:getCurrentFarmId()) then
        return false
    end

    if self:hasVisibleFarmEditDialog() or self:isBlockingGuiForSoloF9() then
        return false
    end

    return true
end

function FarmIconColor:isBlockingGuiForSoloF9()
    if g_gui == nil then
        return false
    end

    if g_gui.currentListener == ColorPickerDialog then
        return true
    end

    if self:hasVisibleDialog() then
        return true
    end

    local currentObjects = {
        g_gui.currentDialog,
        g_gui.currentScreen,
        g_gui.currentListener,
        g_gui.currentGui,
        type(g_gui.currentGui) == "table" and g_gui.currentGui.target or nil,
        type(g_gui.currentListener) == "table" and g_gui.currentListener.target or nil
    }

    for _, object in ipairs(currentObjects) do
        if self:isGuiObjectBlockingSoloF9(object) then
            return true
        end
    end

    local inGameMenu = g_currentMission ~= nil and g_currentMission.inGameMenu or nil

    if type(inGameMenu) == "table" then
        if inGameMenu.visible == true or inGameMenu.isVisible == true or inGameMenu.isOpen == true or inGameMenu.isOpened == true or inGameMenu.isActive == true then
            return true
        end
    end

    return false
end

function FarmIconColor:isGuiObjectBlockingSoloF9(object)
    if type(object) ~= "table" then
        return false
    end

    if self:isInGameMenu(object) then
        return true
    end

    local labels = {
        object.name,
        object.className,
        object.class,
        object.typeName,
        object.profile,
        object.xmlFilename,
        object.id,
        object.targetName
    }

    local text = ""

    for _, label in ipairs(labels) do
        if label ~= nil then
            text = text .. " " .. tostring(label)
        end
    end

    local lowerText = string.lower(text)

    if string.find(lowerText, "hud", 1, true) ~= nil and string.find(lowerText, "menu", 1, true) == nil then
        return false
    end

    local blockingWords = {
        "menu",
        "dialog",
        "screen",
        "shop",
        "store",
        "construction",
        "wardrobe",
        "license",
        "colorpicker",
        "multiplayer",
        "pause"
    }

    for _, word in ipairs(blockingWords) do
        if string.find(lowerText, word, 1, true) ~= nil then
            return true
        end
    end

    return false
end

function FarmIconColor:getF9KeyCode()
    return self:getLogoSelectorKeyCode({
        "KEY_f9",
        "KEY_F9"
    })
end

function FarmIconColor:setSoloF9DownStateFromInput(f9Key)
    if Input == nil or Input.isKeyPressed == nil or f9Key == nil then
        self.prototypeColorPickerHotkeyDown = false
        return
    end

    local success, isPressed = pcall(function()
        return Input.isKeyPressed(f9Key)
    end)

    self.prototypeColorPickerHotkeyDown = success and isPressed == true
end

function FarmIconColor:checkPrototypeColorPickerHotkey()
    local f9Key = self:getF9KeyCode()

    if not self:isSoloF9ColorPickerAllowed() then
        self:setSoloF9DownStateFromInput(f9Key)
        return
    end

    if Input == nil or Input.isKeyPressed == nil or f9Key == nil then
        if not self.prototypeColorPickerInputMissingLogged then
            self.prototypeColorPickerInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Solo color picker hotkey unavailable: F9 key code not found", self.MOD_NAME))
        end

        return
    end

    local success, isPressed = pcall(function()
        return Input.isKeyPressed(f9Key)
    end)

    if not success then
        if not self.prototypeColorPickerInputMissingLogged then
            self.prototypeColorPickerInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Solo color picker hotkey unavailable: %s", self.MOD_NAME, tostring(isPressed)))
        end

        return
    end

    if isPressed and not self.prototypeColorPickerHotkeyDown then
        self:openColorPickerPrototype()
    end

    self.prototypeColorPickerHotkeyDown = isPressed
end


function FarmIconColor:openColorPickerPrototype()
    if ColorPickerDialog == nil or ColorPickerDialog.show == nil then
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker skipped: ColorPickerDialog not available", self.MOD_NAME))
        return
    end

    local dialogFarmId = self:getActiveFarmDialogFarmId()
    local pendingFarmCreation = self:hasVisibleFarmEditDialog() and not self:isValidFarmId(dialogFarmId)
    local farmId = dialogFarmId
    local currentColor = nil

    if pendingFarmCreation then
        farmId = nil
        self:snapshotFarmIdsForPendingCreation("open prototype ColorPickerDialog")
        currentColor = self.pendingFarmCreationColor or {1, 1, 1, 1}
    else
        farmId = farmId or self:getSelectedFarmMenuFarmId() or self:getCurrentFarmId() or self:getTargetFarmId()
        currentColor = self:getRuntimeFarmColor(farmId) or self:getCurrentColorForFarmId(farmId) or self:getConfiguredColorForFarmId(farmId) or self:parseColor(self.defaultColor)
    end

    if currentColor == nil then
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker skipped: no usable current color for farmId=%s", self.MOD_NAME, tostring(farmId)))
        return
    end

    local customColor = self:copyColor(currentColor)

    if customColor == nil then
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker skipped: invalid current color=%s", self.MOD_NAME, self:valueToString(currentColor)))
        return
    end

    self.prototypeColorPickerFarmId = farmId
    self.prototypeColorPickerPendingFarmCreation = pendingFarmCreation

    local presetColors = self:createColorPickerPresetColors(customColor)
    self.prototypeColorPickerPresetColors = presetColors

    FarmIconColor:debugPrint(string.format("[%s] Opening prototype color picker with %s for farmId=%s pendingFarmCreation=%s currentColor=%s presetCount=%s", self.MOD_NAME, self.PROTOTYPE_COLOR_PICKER_KEY_NAME, tostring(farmId), tostring(pendingFarmCreation), self:valueToString(customColor), tostring(#presetColors)))

    local success, message = pcall(function()
        ColorPickerDialog.show(self.onPrototypeColorPickerConfirmed, self, {farmId = farmId, pendingFarmCreation = pendingFarmCreation}, presetColors, nil, nil, customColor, true, false, true)
    end)

    if not success then
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker open failed: %s", self.MOD_NAME, tostring(message)))
    end
end


function FarmIconColor:onPrototypeColorPickerConfirmed(...)
    local callbackArgs = {n = select("#", ...), ...}

    FarmIconColor:debugPrint(string.format("[%s] Prototype color picker callback args=%s", self.MOD_NAME, self:valueToString(callbackArgs)))

    local farmId = self.prototypeColorPickerFarmId
    local pendingFarmCreation = self.prototypeColorPickerPendingFarmCreation == true

    for index = 1, callbackArgs.n do
        local value = callbackArgs[index]

        if type(value) == "table" and value.farmId ~= nil then
            farmId = value.farmId
        end

        if type(value) == "table" and value.pendingFarmCreation == true then
            pendingFarmCreation = true
        end
    end

    local color = self:extractColorFromCallbackArgs(callbackArgs)

    if color == nil then
        color = self:getColorPickerPresetColorFromCallbackArgs(callbackArgs)
    end

    if color == nil then
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker callback ignored: no color found", self.MOD_NAME))
        return
    end

    if pendingFarmCreation then
        if self.pendingFarmCreationKnownFarmIds == nil then
            self:snapshotFarmIdsForPendingCreation("prototype ColorPickerDialog callback")
        end

        self.pendingFarmCreationColor = self:copyColor(color)
        self.pendingFarmCreationColorApplied = false
        self.farmDialogLogoApplyLogged = false
        self.lastDialogLogoColorSignature = nil
        self:applyVisibleDialogPreviewLogoColor(self.pendingFarmCreationColor)
        self:scheduleDialogLogoRefresh(nil, self.pendingFarmCreationColor, 30)
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker stored pending farm creation color=%s", self.MOD_NAME, self:valueToString(self.pendingFarmCreationColor)))
    elseif self:isValidFarmId(farmId) then
        self:applyRuntimeFarmColor(farmId, color, "prototype ColorPickerDialog")
    else
        FarmIconColor:debugPrint(string.format("[%s] Prototype color picker callback ignored: farmId not available", self.MOD_NAME))
    end
end

function FarmIconColor:getColorPickerPresetColorFromCallbackArgs(callbackArgs)
    if type(callbackArgs) ~= "table" or type(self.prototypeColorPickerPresetColors) ~= "table" then
        return nil
    end

    for index = 1, callbackArgs.n or #callbackArgs do
        local presetIndex = tonumber(callbackArgs[index])

        if presetIndex ~= nil then
            local presetColor = self.prototypeColorPickerPresetColors[presetIndex]

            if presetColor ~= nil then
                FarmIconColor:debugPrint(string.format("[%s] Prototype color picker selected preset index=%s color=%s", self.MOD_NAME, tostring(presetIndex), self:valueToString(presetColor)))
                return self:copyColor(presetColor)
            end
        end
    end

    return nil
end

function FarmIconColor:extractColorFromCallbackArgs(callbackArgs)
    if type(callbackArgs) ~= "table" then
        return nil
    end

    local visited = {}

    for index = 1, callbackArgs.n or #callbackArgs do
        local color = self:findColorInValue(callbackArgs[index], 0, visited)

        if color ~= nil then
            return color
        end
    end

    for index = 1, (callbackArgs.n or #callbackArgs) - 2 do
        local r = tonumber(callbackArgs[index])
        local g = tonumber(callbackArgs[index + 1])
        local b = tonumber(callbackArgs[index + 2])

        if r ~= nil and g ~= nil and b ~= nil then
            return {
                self:clamp(r, 0, 1),
                self:clamp(g, 0, 1),
                self:clamp(b, 0, 1),
                self:clamp(tonumber(callbackArgs[index + 3]) or 1, 0, 1)
            }
        end
    end

    return nil
end

function FarmIconColor:findColorInValue(value, depth, visited)
    if depth > 5 then
        return nil
    end

    local color = self:normalizeColorCandidate(value)

    if color ~= nil then
        return color
    end

    if type(value) ~= "table" then
        return nil
    end

    if visited[value] then
        return nil
    end

    visited[value] = true

    local preferredKeys = {
        "color",
        "customColor",
        "selectedColor",
        "value",
        "values",
        "rgb",
        "linearRgb",
        "linearRGB",
        "diffuseColor"
    }

    for _, key in ipairs(preferredKeys) do
        local nestedColor = self:findColorInValue(value[key], depth + 1, visited)

        if nestedColor ~= nil then
            return nestedColor
        end
    end

    for key, nestedValue in pairs(value) do
        if type(nestedValue) == "table" and key ~= "parent" and key ~= "target" and key ~= "elements" then
            local nestedColor = self:findColorInValue(nestedValue, depth + 1, visited)

            if nestedColor ~= nil then
                return nestedColor
            end
        end
    end

    return nil
end

function FarmIconColor:normalizeColorCandidate(value)
    if type(value) ~= "table" then
        return nil
    end

    if tonumber(value[1]) ~= nil and tonumber(value[2]) ~= nil and tonumber(value[3]) ~= nil then
        return {
            self:clamp(tonumber(value[1]), 0, 1),
            self:clamp(tonumber(value[2]), 0, 1),
            self:clamp(tonumber(value[3]), 0, 1),
            self:clamp(tonumber(value[4]) or 1, 0, 1)
        }
    end

    local nestedColor = value.color or value.values or value.value

    if type(nestedColor) == "table" then
        return self:normalizeColorCandidate(nestedColor)
    end

    if tonumber(value.r) ~= nil and tonumber(value.g) ~= nil and tonumber(value.b) ~= nil then
        return {
            self:clamp(tonumber(value.r), 0, 1),
            self:clamp(tonumber(value.g), 0, 1),
            self:clamp(tonumber(value.b), 0, 1),
            self:clamp(tonumber(value.a) or 1, 0, 1)
        }
    end

    return nil
end

function FarmIconColor:createColorPickerPresetColors(currentColor)
    local colors = {}

    if Farm ~= nil and type(Farm.COLORS) == "table" then
        for _, farmColor in ipairs(Farm.COLORS) do
            local color = self:copyColor(farmColor)

            if color ~= nil then
                table.insert(colors, color)
            end
        end
    end

    if #colors == 0 then
        local fallbackColors = {
            {1, 0, 0, 1},
            {1, 0.42, 0, 1},
            {0.85, 0.08, 0.45, 1},
            {0.5, 0, 0.75, 1},
            {0.3, 0.4, 1, 1},
            {0.1, 0.85, 1, 1},
            {0.45, 1, 0.45, 1}
        }

        for _, fallbackColor in ipairs(fallbackColors) do
            table.insert(colors, fallbackColor)
        end
    end

    local currentPreset = self:copyColor(currentColor)

    if currentPreset ~= nil then
        table.insert(colors, 1, currentPreset)
    end

    return colors
end


function FarmIconColor:applyRuntimeFarmColor(farmId, color, source)
    if farmId == nil then
        FarmIconColor:debugPrint(string.format("[%s] Runtime color apply skipped: farmId not available (%s)", self.MOD_NAME, tostring(source)))
        return
    end

    local colorText = self:colorToRgbaText(color)
    local runtimeColor = self:copyColor(color)

    if colorText == nil or runtimeColor == nil then
        FarmIconColor:debugPrint(string.format("[%s] Runtime color apply skipped: invalid color=%s (%s)", self.MOD_NAME, self:valueToString(color), tostring(source)))
        return
    end

    local wasColorApplied = self.colorApplied

    self.runtimeFarmColors[tostring(farmId)] = runtimeColor
    self:saveSavegameData(source or "runtime farm color")
    self:applyGameFarmColorInPlace(farmId, runtimeColor, source or "runtime farm color")
    self.appliedFarmId = farmId
    self.appliedColor = self:copyColor(runtimeColor)
    self.colorApplied = false
    self:applyConfiguredFarmColor(farmId, {
        color = colorText,
        logo = "runtime"
    })

    if not self.colorApplied then
        self.colorApplied = wasColorApplied
    else
        self.farmMenuLogoApplyLogged = false
        self.farmDialogLogoApplyLogged = false
        self.lastDialogLogoColorSignature = nil

        self:safeCall("forceApplyVisibleFarmLogos after runtime color", function()
            self:forceApplyVisibleFarmLogos(farmId, runtimeColor)
        end)

        self:safeCall("applyActiveFarmDialogLogoColors after runtime color", function()
            self:applyActiveFarmDialogLogoColors()
        end)

        self:scheduleDialogLogoRefresh(farmId, runtimeColor, 30)

        self:safeCall("apply active farm menu colors after runtime color", function()
            self:checkFarmMenuOpen()
        end)

        FarmIconColor:debugPrint(string.format("[%s] Runtime color applied from %s for farmId=%s color=%s", self.MOD_NAME, tostring(source), tostring(farmId), colorText))
    end

    if self.networkSyncApplyInProgress ~= true then
        self:sendNetworkFarmVisual(farmId, runtimeColor, self.runtimeFarmLogos ~= nil and self.runtimeFarmLogos[tostring(farmId)] or nil, source or "runtime farm color")
    end
end

function FarmIconColor:setRuntimeFarmLogo(farmId, logoName, source)
    if not self:isValidFarmId(farmId) then
        return false
    end

    local normalizedLogoName = self:normalizeLogoName(logoName)

    if normalizedLogoName == nil or self.logos[normalizedLogoName] == nil then
        return false
    end

    self.runtimeFarmLogos = self.runtimeFarmLogos or {}
    self.runtimeFarmLogos[tostring(farmId)] = normalizedLogoName
    self:saveSavegameData(source or "runtime farm logo")

    self.farmMenuLogoApplyLogged = false
    self.farmDialogLogoApplyLogged = false
    self.farmDialogCustomLogoApplyLogged = false
    self.lastDialogLogoColorSignature = nil

    local color = self:getRuntimeFarmColor(farmId) or self:getCurrentColorForFarmId(farmId) or self:getConfiguredColorForFarmId(farmId)

    if color ~= nil then
        self:safeCall("refresh visible logo after runtime logo", function()
            self:forceApplyVisibleFarmLogos(farmId, color)
            self:applyActiveFarmDialogLogoColors()
            self:checkFarmMenuOpen()
        end)
    end

    if self.networkSyncApplyInProgress ~= true then
        self:sendNetworkFarmVisual(farmId, color, normalizedLogoName, source or "runtime farm logo")
    end

    return true
end

function FarmIconColor:buildNetworkVisualSignature(farmId, colorText, logoName)
    return tostring(farmId or "") .. ":" .. tostring(colorText or "") .. ":" .. tostring(logoName or "")
end

function FarmIconColor:sendNetworkFarmVisual(farmId, color, logoName, source)
    if not self:isMultiplayerGame() or not self:isValidFarmId(farmId) then
        return false
    end

    if FarmIconColorSyncEvent == nil then
        if not self.networkEventMissingLogged then
            self.networkEventMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Network sync skipped: FarmIconColorSyncEvent is not registered", self.MOD_NAME))
        end
        return false
    end

    local colorText = self:colorToRgbaText(color) or ""
    local normalizedLogoName = self:normalizeLogoName(logoName) or ""

    if normalizedLogoName ~= "" and self.logos[normalizedLogoName] == nil then
        normalizedLogoName = ""
    end

    if colorText == "" and normalizedLogoName == "" then
        return false
    end

    local signature = self:buildNetworkVisualSignature(farmId, colorText, normalizedLogoName)

    if self.networkSyncLastSendSignature == signature and tostring(source or "") ~= "server periodic sync" then
        return true
    end

    self.networkSyncLastSendSignature = signature

    local event = FarmIconColorSyncEvent.new(farmId, colorText, normalizedLogoName)

    if g_server ~= nil then
        g_server:broadcastEvent(event, nil, nil, nil)
        return true
    end

    if g_client ~= nil and g_client.getServerConnection ~= nil then
        local connection = g_client:getServerConnection()

        if connection ~= nil and connection.sendEvent ~= nil then
            connection:sendEvent(event)
            return true
        end
    end

    return false
end

function FarmIconColor:applyNetworkFarmVisual(farmId, colorText, logoName, source)
    if not self:isValidFarmId(farmId) then
        return false
    end

    self.networkSyncApplyInProgress = true

    local idKey = tostring(farmId)
    local color = self:parseColor(colorText)
    local normalizedLogoName = self:normalizeLogoName(logoName)
    local changed = false

    if color ~= nil then
        self.runtimeFarmColors = self.runtimeFarmColors or {}
        self.runtimeFarmColors[idKey] = self:copyColor(color)
        self:applyGameFarmColorInPlace(farmId, color, source or "network sync")
        self.appliedFarmId = farmId
        self.appliedColor = self:copyColor(color)
        self.colorApplied = false
        self:applyConfiguredFarmColor(farmId, {
            color = self:colorToRgbaText(color),
            logo = "network"
        })
        changed = true
    end

    if normalizedLogoName ~= nil and self.logos[normalizedLogoName] ~= nil then
        self.runtimeFarmLogos = self.runtimeFarmLogos or {}
        self.runtimeFarmLogos[idKey] = normalizedLogoName
        self.farmMenuLogoApplyLogged = false
        self.farmDialogLogoApplyLogged = false
        self.farmDialogCustomLogoApplyLogged = false
        self.lastDialogLogoColorSignature = nil
        changed = true
    end

    if changed then
        self:saveSavegameData(source or "network sync")

        local visualColor = color or self:getRuntimeFarmColor(farmId) or self:getCurrentColorForFarmId(farmId) or self:getConfiguredColorForFarmId(farmId)

        if visualColor ~= nil then
            self:safeCall("refresh visuals after network sync", function()
                self:forceApplyVisibleFarmLogos(farmId, visualColor)
                self:applyActiveFarmDialogLogoColors()
                self:checkFarmMenuOpen()
                self:applyMapHotspotColors(farmId, visualColor)
                self:forceApplyAllSavedFarmVisualColors(source or "network sync")
            end)
        end

        FarmIconColor:debugPrint(string.format("[%s] Network farm visual applied farmId=%s color=%s logo=%s source=%s", self.MOD_NAME, tostring(farmId), tostring(colorText), tostring(normalizedLogoName), tostring(source)))
    end

    self.networkSyncApplyInProgress = false

    return changed
end

function FarmIconColor:updateNetworkSync(dt)
    if not self:isMultiplayerGame() or g_server == nil then
        return
    end

    if type(self.runtimeFarmColors) ~= "table" and type(self.runtimeFarmLogos) ~= "table" then
        return
    end

    self.networkSyncTimer = (self.networkSyncTimer or 0) + (dt or 0)
    self.networkSyncInitialTimer = (self.networkSyncInitialTimer or 0) + (dt or 0)

    local initialSync = (self.networkSyncInitialCount or 0) < 6 and self.networkSyncInitialTimer >= 2000
    local periodicSync = self.networkSyncTimer >= self.NETWORK_SYNC_INTERVAL

    if not initialSync and not periodicSync then
        return
    end

    if initialSync then
        self.networkSyncInitialTimer = 0
        self.networkSyncInitialCount = (self.networkSyncInitialCount or 0) + 1
    end

    if periodicSync then
        self.networkSyncTimer = 0
    end

    self:broadcastAllRuntimeFarmVisuals("server periodic sync")
end

function FarmIconColor:broadcastAllRuntimeFarmVisuals(source)
    if g_server == nil or FarmIconColorSyncEvent == nil then
        return 0
    end

    local farmKeys = {}
    local seen = {}

    if type(self.runtimeFarmColors) == "table" then
        for farmId, _ in pairs(self.runtimeFarmColors) do
            if not seen[tostring(farmId)] then
                table.insert(farmKeys, tostring(farmId))
                seen[tostring(farmId)] = true
            end
        end
    end

    if type(self.runtimeFarmLogos) == "table" then
        for farmId, _ in pairs(self.runtimeFarmLogos) do
            if not seen[tostring(farmId)] then
                table.insert(farmKeys, tostring(farmId))
                seen[tostring(farmId)] = true
            end
        end
    end

    table.sort(farmKeys, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)

    local sent = 0

    for _, farmId in ipairs(farmKeys) do
        local color = self.runtimeFarmColors ~= nil and self.runtimeFarmColors[tostring(farmId)] or nil
        local logoName = self.runtimeFarmLogos ~= nil and self.runtimeFarmLogos[tostring(farmId)] or nil

        if color ~= nil or logoName ~= nil then
            if self:sendNetworkFarmVisual(farmId, color, logoName, source or "server sync") then
                sent = sent + 1
            end
        end
    end

    return sent
end

function FarmIconColor:getRuntimeFarmColor(farmId)
    if farmId == nil or type(self.runtimeFarmColors) ~= "table" then
        return nil
    end

    return self:copyColor(self.runtimeFarmColors[tostring(farmId)])
end

function FarmIconColor:getCurrentFarmIdSet()
    local farmIds = {}

    local function addFarmId(farmId)
        if self:isValidFarmId(farmId) then
            farmIds[tostring(farmId)] = farmId
        end
    end

    local function addFarmObject(key, farm)
        if type(farm) == "table" then
            addFarmId(farm.farmId or farm.id or self:getObjectFarmId(farm) or key)
        else
            addFarmId(key)
        end
    end

    if type(g_farmManager) == "table" then
        for _, fieldName in ipairs({"farms", "farmIdToFarm"}) do
            local farms = g_farmManager[fieldName]

            if type(farms) == "table" then
                for key, farm in pairs(farms) do
                    addFarmObject(key, farm)
                end
            end
        end

        if type(g_farmManager.getFarms) == "function" then
            local success, farms = pcall(function()
                return g_farmManager:getFarms()
            end)

            if success and type(farms) == "table" then
                for key, farm in pairs(farms) do
                    addFarmObject(key, farm)
                end
            end
        end
    end

    return farmIds
end

function FarmIconColor:getFarmIdSetCount(farmIds)
    local count = 0

    if type(farmIds) == "table" then
        for _ in pairs(farmIds) do
            count = count + 1
        end
    end

    return count
end

function FarmIconColor:getFarmIdSetText(farmIds)
    local values = {}

    if type(farmIds) == "table" then
        for _, farmId in pairs(farmIds) do
            table.insert(values, tostring(farmId))
        end
    end

    table.sort(values)

    return table.concat(values, ",")
end

function FarmIconColor:snapshotFarmIdsForPendingCreation(source)
    self.pendingFarmCreationKnownFarmIds = self:getCurrentFarmIdSet()

    if self.pendingFarmCreationLogoName == nil then
        self.pendingFarmCreationLogoName = self:getDefaultCustomLogoName()
    end

    if self.pendingFarmCreationLogoName == nil then
        self.pendingFarmCreationLogoName = self:getNextTestLogoNameForNewFarm()
    end

    FarmIconColor:debugPrint(string.format(
        "[%s] Pending farm creation snapshot from %s: count=%s ids=%s",
        self.MOD_NAME,
        tostring(source),
        tostring(self:getFarmIdSetCount(self.pendingFarmCreationKnownFarmIds)),
        self:getFarmIdSetText(self.pendingFarmCreationKnownFarmIds)
    ))
end

function FarmIconColor:findPendingCreatedFarmId()
    local knownFarmIds = self.pendingFarmCreationKnownFarmIds

    if type(knownFarmIds) ~= "table" then
        return nil
    end

    local currentFarmIds = self:getCurrentFarmIdSet()
    local newFarmId = nil
    local newCount = 0

    for key, farmId in pairs(currentFarmIds) do
        if knownFarmIds[key] == nil then
            newFarmId = farmId
            newCount = newCount + 1
        end
    end

    if newCount == 1 then
        return newFarmId
    end

    if newCount > 1 then
        FarmIconColor:debugPrint(string.format(
            "[%s] Pending farm creation color waiting: multiple new farms detected known=%s current=%s",
            self.MOD_NAME,
            self:getFarmIdSetText(knownFarmIds),
            self:getFarmIdSetText(currentFarmIds)
        ))
    end

    return nil
end


function FarmIconColor:applyPendingFarmCreationColor()
    if self.pendingFarmCreationColor == nil and self.pendingFarmCreationLogoName == nil then
        return
    end

    local farmId = self:findPendingCreatedFarmId()

    if not self:isValidFarmId(farmId) then
        return
    end

    local color = self:copyColor(self.pendingFarmCreationColor)
    local logoName = self.pendingFarmCreationLogoName or self:getDefaultCustomLogoName()

    if logoName ~= nil then
        self:ensureTestLogos()
        self:setRuntimeFarmLogo(farmId, logoName, "pending farm creation logo")
        FarmIconColor:debugPrint(string.format("[%s] Applying pending farm creation logo for farmId=%s logo=%s", self.MOD_NAME, tostring(farmId), tostring(logoName)))
    end

    self.pendingFarmCreationColor = nil
    self.pendingFarmCreationLogoName = nil
    self.pendingFarmCreationColorApplied = true
    self.pendingFarmCreationKnownFarmIds = nil

    if color ~= nil then
        FarmIconColor:debugPrint(string.format("[%s] Applying pending farm creation color for farmId=%s color=%s", self.MOD_NAME, tostring(farmId), self:valueToString(color)))
        self:applyRuntimeFarmColor(farmId, color, "pending farm creation")
    else
        self.farmMenuLogoApplyLogged = false

        self:safeCall("apply active farm menu logos after pending logo", function()
            self:checkFarmMenuOpen()
        end)
    end
end

function FarmIconColor:forceApplyVisibleFarmLogos(farmId, color)
    local changed = 0

    changed = changed + self:applyVisibleDialogPreviewLogoColor(color)

    if changed > 0 then
        FarmIconColor:debugPrint(string.format("[%s] Forced visible farm edit dialog logo refresh for farmId=%s changed=%s color=%s", self.MOD_NAME, tostring(farmId), tostring(changed), self:valueToString(color)))
    else
        FarmIconColor:debugPrint(string.format("[%s] Forced visible farm edit dialog logo refresh skipped: no dialog logo element found for farmId=%s color=%s", self.MOD_NAME, tostring(farmId), self:valueToString(color)))
    end
end

function FarmIconColor:scheduleDialogLogoRefresh(farmId, color, frames)
    local refreshColor = self:copyColor(color)

    if refreshColor == nil then
        return
    end

    self.pendingDialogLogoRefreshFarmId = farmId
    self.pendingDialogLogoRefreshColor = refreshColor
    self.pendingDialogLogoRefreshFrames = frames or 20
end

function FarmIconColor:processPendingDialogLogoRefresh()
    if self.pendingDialogLogoRefreshFrames <= 0 or self.pendingDialogLogoRefreshColor == nil then
        return
    end

    if g_gui ~= nil and g_gui.currentListener == ColorPickerDialog then
        return
    end

    if not self:hasVisibleFarmEditDialog() then
        self.pendingDialogLogoRefreshFrames = self.pendingDialogLogoRefreshFrames - 1
        return
    end

    local changed = self:applyVisibleDialogPreviewLogoColor(self.pendingDialogLogoRefreshColor)
    self.pendingDialogLogoRefreshFrames = self.pendingDialogLogoRefreshFrames - 1

    if changed > 0 and self.pendingDialogLogoRefreshFrames == 29 then
        FarmIconColor:debugPrint(string.format("[%s] Delayed farm edit dialog logo refresh for farmId=%s changed=%s color=%s", self.MOD_NAME, tostring(self.pendingDialogLogoRefreshFarmId), tostring(changed), self:valueToString(self.pendingDialogLogoRefreshColor)))
    end
end

function FarmIconColor:hasVisibleFarmEditDialog()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return false
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            return true
        end
    end

    return false
end

function FarmIconColor:colorToRgbaText(color)
    local normalizedColor = self:normalizeColorCandidate(color)

    if normalizedColor == nil then
        return nil
    end

    return string.format("%.6f %.6f %.6f %.6f", normalizedColor[1], normalizedColor[2], normalizedColor[3], normalizedColor[4] or 1)
end

function FarmIconColor:parseColor(colorText)
    if colorText == nil then
        return nil
    end

    local text = tostring(colorText)
    local hex = string.match(text, "^%s*#([%x][%x][%x][%x][%x][%x])%s*$")

    if hex ~= nil then
        return {
            tonumber(string.sub(hex, 1, 2), 16) / 255,
            tonumber(string.sub(hex, 3, 4), 16) / 255,
            tonumber(string.sub(hex, 5, 6), 16) / 255,
            1
        }
    end

    local values = {}

    for value in string.gmatch(text, "%S+") do
        table.insert(values, tonumber(value))
    end

    if #values < 3 then
        return nil
    end

    return {
        self:clamp(values[1], 0, 1),
        self:clamp(values[2], 0, 1),
        self:clamp(values[3], 0, 1),
        self:clamp(values[4] or 1, 0, 1)
    }
end

function FarmIconColor:clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function FarmIconColor:copyColor(color)
    if type(color) ~= "table" then
        return nil
    end

    return {
        color[1],
        color[2],
        color[3],
        color[4]
    }
end

function FarmIconColor:getAppliedFarmCurrentColor()
    if self.appliedFarmId == nil then
        return self.appliedColor
    end

    return self:getRuntimeFarmColor(self.appliedFarmId) or self:getCurrentColorForFarmId(self.appliedFarmId) or self.appliedColor
end


function FarmIconColor:applyMapHotspotColors(farmId, color)
    local ingameMap = g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.ingameMap or nil

    if ingameMap == nil then
        return
    end

    local changed = 0

    changed = changed + self:applyHotspotListColors(ingameMap.hotspots, farmId, color)
    changed = changed + self:applyHotspotListColors(ingameMap.hotspotsRenderLast, farmId, color)
    changed = changed + self:applyHotspotListColors(ingameMap.hotspotsRegular, farmId, color)
    changed = changed + self:applyHotspotListColors(ingameMap.hotspotsPostUpdate, farmId, color)



end

function FarmIconColor:applyHotspotListColors(hotspotList, farmId, color)
    if type(hotspotList) ~= "table" then
        return 0
    end

    local changed = 0

    for _, hotspot in pairs(hotspotList) do
        if type(hotspot) == "table" then
            local hotspotFarmId = self:getObjectFarmId(hotspot)

            if hotspotFarmId ~= nil and tostring(hotspotFarmId) == tostring(farmId) then
                changed = changed + self:applyHotspotColorMethods(hotspot, color)

                if type(hotspot.color) == "table" then
                    self:setColorTable(hotspot.color, color)
                    changed = changed + 1
                end

                changed = changed + self:applyColorFields(hotspot, color, {
                    "bgColor",
                    "backgroundColor",
                    "iconColor",
                    "labelColor",
                    "labelBgColor",
                    "labelBackgroundColor",
                    "numberColor",
                    "fieldColor",
                    "overlayColor",
                    "colorDisabled"
                })

                changed = changed + self:applyOverlayFields(hotspot, color, {
                    "overlay",
                    "backgroundOverlay",
                    "labelOverlay",
                    "numberOverlay",
                    "fieldNumberOverlay"
                })

                if self:isFieldNumberHotspot(hotspot) then
                    changed = changed + self:applyOverlayFields(hotspot, color, {
                        "icon"
                    })
                end

                if self.applyToFieldNumbers and type(hotspot.textColor) == "table" then
                    local textColor = self:getReadableTextColor(color)

                    self:setColorTable(hotspot.textColor, textColor)

                    if type(hotspot.textColorDisabled) == "table" then
                        self:setColorTable(hotspot.textColorDisabled, textColor)
                    end

                    changed = changed + self:applyHotspotTextColorMethods(hotspot, textColor)
                    changed = changed + 1
                end

                changed = changed + self:updateHotspotColors(hotspot)
            end
        end
    end

    return changed
end

function FarmIconColor:setColorTable(target, source)
    target[1] = source[1]
    target[2] = source[2]
    target[3] = source[3]
    target[4] = source[4] or 1
end

function FarmIconColor:applyColorFields(object, color, fieldNames)
    local changed = 0

    for _, fieldName in ipairs(fieldNames) do
        local fieldValue = object[fieldName]

        if type(fieldValue) == "table" then
            self:setColorTable(fieldValue, color)
            changed = changed + 1
        end
    end

    return changed
end

function FarmIconColor:applyOverlayFields(object, color, fieldNames)
    local changed = 0

    for _, fieldName in ipairs(fieldNames) do
        local overlay = object[fieldName]

        if type(overlay) == "table" then
            if overlay.setColor ~= nil then
                local success = pcall(function()
                    overlay:setColor(color[1], color[2], color[3], color[4] or 1)
                end)

                if success then
                    changed = changed + 1
                end
            end

            if overlay.r ~= nil or overlay.g ~= nil or overlay.b ~= nil or overlay.a ~= nil then
                overlay.r = color[1]
                overlay.g = color[2]
                overlay.b = color[3]
                overlay.a = color[4] or 1
                changed = changed + 1
            end

            if overlay.color ~= nil and type(overlay.color) == "table" then
                self:setColorTable(overlay.color, color)
                changed = changed + 1
            end
        end
    end

    return changed
end

function FarmIconColor:updateHotspotColors(hotspot)
    if hotspot.updateColors == nil then
        return 0
    end

    local success = pcall(function()
        hotspot:updateColors()
    end)

    if success then
        return 1
    end

    return 0
end

function FarmIconColor:applyHotspotColorMethods(hotspot, color)
    local changed = 0
    local methodNames = {
        "setColor",
        "setBgColor",
        "setBackgroundColor",
        "setIconColor",
        "setLabelColor",
        "setFieldColor"
    }

    for _, methodName in ipairs(methodNames) do
        if hotspot[methodName] ~= nil then
            local success = pcall(function()
                hotspot[methodName](hotspot, color)
            end)

            if not success then
                success = pcall(function()
                    hotspot[methodName](hotspot, color[1], color[2], color[3], color[4] or 1)
                end)
            end

            if success then
                changed = changed + 1
            end
        end
    end

    return changed
end

function FarmIconColor:applyHotspotTextColorMethods(hotspot, color)
    local changed = 0
    local methodNames = {
        "setTextColor",
        "setLabelTextColor",
        "setNumberTextColor"
    }

    for _, methodName in ipairs(methodNames) do
        if hotspot[methodName] ~= nil then
            local success = pcall(function()
                hotspot[methodName](hotspot, color)
            end)

            if not success then
                success = pcall(function()
                    hotspot[methodName](hotspot, color[1], color[2], color[3], color[4] or 1)
                end)
            end

            if success then
                changed = changed + 1
            end
        end
    end

    return changed
end

function FarmIconColor:getReadableTextColor(backgroundColor)
    local r = backgroundColor[1] or 0
    local g = backgroundColor[2] or 0
    local b = backgroundColor[3] or 0
    local luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)

    if luminance > 0.55 then
        return {0, 0, 0, 1}
    end

    return {1, 1, 1, 1}
end


function FarmIconColor:checkFarmMenuOpen()
    local inGameMenu = self:getInGameMenuCandidate()

    if type(inGameMenu) ~= "table" then
        return
    end

    local currentPage = self:getCurrentInGameMenuPage(inGameMenu)
    local isOpen, pageLabel = self:isFarmMenuPage(inGameMenu, currentPage)

    if isOpen and (not self.lastFarmMenuOpen or pageLabel ~= self.lastFarmMenuPageLabel) then
        self.lastFarmMenuOpen = true
        self.lastFarmMenuPageLabel = pageLabel
        self.farmMenuLogoApplyLogged = false

        FarmIconColor:debugPrint(string.format("[%s] Farm menu opened: page=%s currentPage=%s", self.MOD_NAME, tostring(pageLabel), self:describeGuiPage(currentPage)))

        if type(currentPage) == "table" then
            self:applyFarmMenuLogoColors(currentPage)
        end
    elseif isOpen and type(currentPage) == "table" then
        self:applyFarmMenuLogoColors(currentPage)
    elseif not isOpen and self.lastFarmMenuOpen then
        FarmIconColor:debugPrint(string.format("[%s] Farm menu closed: lastPage=%s", self.MOD_NAME, tostring(self.lastFarmMenuPageLabel)))
        self.lastFarmMenuOpen = false
        self.lastFarmMenuPageLabel = nil
        self.farmMenuLogoApplyLogged = false
        self.farmDialogLogoApplyLogged = false
    end
end

function FarmIconColor:getInGameMenuCandidate()
    local candidates = {
        g_gui ~= nil and g_gui.currentGui ~= nil and g_gui.currentGui.target or nil,
        g_currentMission ~= nil and g_currentMission.inGameMenu or nil,
        g_gui ~= nil and g_gui.currentGui or nil,
        g_gui ~= nil and g_gui.currentListener ~= nil and g_gui.currentListener.target or nil,
        g_gui ~= nil and g_gui.currentListener or nil
    }

    for _, candidate in ipairs(candidates) do
        if self:isInGameMenu(candidate) then
            return candidate
        end
    end

    return nil
end

function FarmIconColor:isInGameMenu(candidate)
    if type(candidate) ~= "table" then
        return false
    end

    if candidate.currentPage ~= nil or candidate.pageFrames ~= nil or candidate.pagingElement ~= nil then
        return true
    end

    if type(candidate.target) == "table" and (candidate.target.currentPage ~= nil or candidate.target.pageFrames ~= nil) then
        return false
    end

    return candidate.name == "InGameMenu" or candidate.className == "InGameMenu"
end

function FarmIconColor:getCurrentInGameMenuPage(inGameMenu)
    if type(inGameMenu) ~= "table" then
        return nil
    end

    if type(inGameMenu.currentPage) == "table" then
        return inGameMenu.currentPage
    end

    if type(inGameMenu.pageFrames) == "table" then
        if inGameMenu.currentPageId ~= nil and type(inGameMenu.pageFrames[inGameMenu.currentPageId]) == "table" then
            return inGameMenu.pageFrames[inGameMenu.currentPageId]
        end

        for _, page in ipairs(inGameMenu.pageFrames) do
            if type(page) == "table" and page.visible == true then
                return page
            end
        end
    end

    return nil
end

function FarmIconColor:isFarmMenuPage(inGameMenu, currentPage)
    if type(currentPage) ~= "table" then
        return false, nil
    end

    local pageFields = {
        "pageFarm",
        "pageFarms",
        "pageMultiplayer",
        "pageMultiplayerFarms"
    }

    for _, fieldName in ipairs(pageFields) do
        if inGameMenu[fieldName] == currentPage then
            return true, fieldName
        end
    end

    local pageLabel = self:describeGuiPage(currentPage)
    local lowerLabel = string.lower(pageLabel)

    if string.find(lowerLabel, "farm", 1, true) ~= nil or string.find(lowerLabel, "multiplayer", 1, true) ~= nil then
        return true, pageLabel
    end

    return false, pageLabel
end

function FarmIconColor:describeGuiPage(page)
    if type(page) ~= "table" then
        return tostring(page)
    end

    local labels = {
        page.name,
        page.className,
        page.profile,
        page.targetName,
        page.id
    }

    for _, label in ipairs(labels) do
        if label ~= nil then
            return tostring(label)
        end
    end

    return tostring(page)
end

function FarmIconColor:applyFarmMenuLogoColors(page)
    if not self.applyToFarmMenuLogo or type(page) ~= "table" or type(page.elementFarmIdMap) ~= "table" then
        return
    end






    if self:hasVisibleDialog() and not self:hasVisibleFarmEditDialog() then
        return
    end

    if g_gui ~= nil and g_gui.currentListener == ColorPickerDialog then
        return
    end

    local changed = 0
    local rows = 0
    for element, farmId in pairs(page.elementFarmIdMap) do
        if self:isValidFarmId(farmId) and type(element) == "table" then
            local color = self:getRuntimeFarmColor(farmId) or self:getCurrentColorForFarmId(farmId) or self:getConfiguredColorForFarmId(farmId)

            if color ~= nil then
                rows = rows + 1
                changed = changed + self:applyFarmListLogoColorInRow(element, farmId, color)
            end
        end
    end

    if changed > 0 and not self.farmMenuLogoApplyLogged then
        self.farmMenuLogoApplyLogged = true
        FarmIconColor:debugPrint(string.format("[%s] Applied custom color to %d farm menu logo element(s) across %d row(s)", self.MOD_NAME, changed, rows))
    end
end

function FarmIconColor:applyFarmListLogoColorInRow(rowElement, farmId, color)
    local logoElement = self:findFarmListLogoElement(rowElement, 0, 4, {})

    if logoElement == nil then
        return 0
    end

    self:prepareFarmLogoElementForCustomTexture(logoElement, farmId)

    return self:applyGuiImageElementColor(logoElement, color)
end

function FarmIconColor:findFarmListLogoElement(element, depth, maxDepth, visited)
    if type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    visited = visited or {}

    if visited[element] then
        return nil
    end

    visited[element] = true

    if self:isFarmListLogoElement(element) then
        return element
    end

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            local match = self:findFarmListLogoElement(child, depth + 1, maxDepth, visited)

            if match ~= nil then
                return match
            end
        end
    end

    return nil
end

function FarmIconColor:isFarmListLogoElement(element)
    if type(element) ~= "table" or self:isColorPickElement(element) then
        return false
    end

    if element.name == "farmIcon" then
        return true
    end

    local profile = element.profile ~= nil and tostring(element.profile) or ""

    return profile == "fs25_multiplayerListItemImage"
end

function FarmIconColor:applyLogoSpecificColorsInElementTree(element, depth, maxDepth)
    if not self.applyLogoSpecificColors or type(element) ~= "table" or depth > maxDepth then
        return 0
    end

    local changed = 0
    local logoColor = self:getConfiguredLogoColorForElement(nil, element)

    if logoColor ~= nil and self:isFarmLogoGuiElement(element) then
        changed = changed + self:applyGuiImageElementColor(element, logoColor)
    end

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            changed = changed + self:applyLogoSpecificColorsInElementTree(child, depth + 1, maxDepth)
        end
    end

    return changed
end

function FarmIconColor:applyActiveFarmDialogLogoColors()
    if not self.applyToFarmMenuLogo then
        return
    end

    if not self:hasVisibleDialog() then
        self.farmDialogLogoApplyLogged = false
        self.farmDialogCustomLogoApplyLogged = false
        self.lastDialogLogoColorSignature = nil
        return
    end

    local dialogFarmId = self:getActiveFarmDialogFarmId()
    local farmId = dialogFarmId

    if farmId == nil and not self:hasVisibleFarmEditDialog() then
        farmId = self:getTargetFarmId()
    end

    local previewLogoElement = self:getVisibleDialogPreviewLogoElement()

    if previewLogoElement ~= nil then
        self:prepareFarmLogoElementForCustomTexture(previewLogoElement, farmId)

        local textureChanged = self:applyCustomLogoTexture(previewLogoElement)

        if textureChanged > 0 and not self.farmDialogCustomLogoApplyLogged then
            self.farmDialogCustomLogoApplyLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Applied custom logo texture to active farm dialog preview for farmId=%s", self.MOD_NAME, tostring(farmId)))
        end
    end

    local color = nil

    if farmId == nil then
        color = self.pendingFarmCreationColor or {1, 1, 1, 1}
    else
        color = self:getRuntimeFarmColor(farmId) or self:getCurrentColorForFarmId(farmId) or self:getSelectedDialogColor() or self:getConfiguredColorForFarmId(farmId)
    end

    if color == nil then
        return
    end

    local changed = self:applyVisibleDialogPreviewLogoColor(color)

    local colorSignature = self:valueToString(color)

    if changed > 0 and (not self.farmDialogLogoApplyLogged or self.lastDialogLogoColorSignature ~= colorSignature) then
        self.farmDialogLogoApplyLogged = true
        self.lastDialogLogoColorSignature = colorSignature
        FarmIconColor:debugPrint(string.format("[%s] Applied farm color to active farm dialog preview logo for farmId=%s color=%s", self.MOD_NAME, tostring(farmId), colorSignature))
    end
end


function FarmIconColor:isCurrentUserFarmIconAdmin()
    local mission = g_currentMission

    if mission == nil then
        return false
    end

    if self:isSingleplayerGame() then
        return true
    end

    -- A listen/self-hosted multiplayer game is authoritative locally: the host is the admin.
    if mission.getIsServer ~= nil and mission.getIsClient ~= nil then
        local successServer, isServer = pcall(function()
            return mission:getIsServer()
        end)
        local successClient, isClient = pcall(function()
            return mission:getIsClient()
        end)

        if successServer and successClient and isServer == true and isClient == true then
            return true
        end
    end

    -- FS25 exposes this flag on multiplayer clients once the server admin password was entered.
    if mission.isMasterUser == true then
        return true
    end

    local userManager = mission.userManager
    local userId = mission.playerUserId

    if userId == nil and type(mission.player) == "table" then
        userId = mission.player.userId
    end

    if type(userManager) ~= "table" or userId == nil or userManager.getUserByUserId == nil then
        return false
    end

    local successUser, user = pcall(function()
        return userManager:getUserByUserId(userId)
    end)

    if not successUser or type(user) ~= "table" or user.getIsMasterUser == nil then
        return false
    end

    local successAdmin, isAdmin = pcall(function()
        return user:getIsMasterUser()
    end)

    return successAdmin and isAdmin == true
end

function FarmIconColor:getInsertKeyCode()
    return self:getLogoSelectorKeyCode({
        "KEY_insert",
        "KEY_INSERT",
        "KEY_Insert"
    })
end

function FarmIconColor:checkCustomLogoImportHotkey()
    local insertKey = self:getInsertKeyCode()
    local canImport = self:hasVisibleFarmEditDialog()
        and g_gui ~= nil
        and g_gui.currentListener ~= ColorPickerDialog
        and self:isCurrentUserFarmIconAdmin()

    if not canImport then
        if Input ~= nil and Input.isKeyPressed ~= nil and insertKey ~= nil then
            local success, pressed = pcall(function()
                return Input.isKeyPressed(insertKey)
            end)
            self.customLogoImportKeyDown = success and pressed == true
        else
            self.customLogoImportKeyDown = false
        end
        return
    end

    if Input == nil or Input.isKeyPressed == nil or insertKey == nil then
        if not self.customLogoImportInputMissingLogged then
            self.customLogoImportInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Custom logo import hotkey unavailable: Insert key code not found", self.MOD_NAME))
        end
        return
    end

    local success, pressed = pcall(function()
        return Input.isKeyPressed(insertKey)
    end)

    if not success then
        return
    end

    if pressed and not self.customLogoImportKeyDown then
        self:importCustomLogosFromFolder()
    end

    self.customLogoImportKeyDown = pressed == true
end

function FarmIconColor:ensureFarmDialogImportButtonMouseRegistration(importButton)
    if type(importButton) ~= "table" or type(importButton.parent) ~= "table" then
        return
    end

    local parent = importButton.parent

    -- GUI mouse events are dispatched through the parent's element list.
    -- Some GIANTS clone paths render the cloned element correctly without
    -- registering it in that list, which makes it visible but not clickable.
    if type(parent.elements) == "table" then
        local registered = false

        for _, child in ipairs(parent.elements) do
            if child == importButton then
                registered = true
                break
            end
        end

        if not registered then
            table.insert(parent.elements, importButton)
        end
    end

    importButton.disabled = false
    importButton.visible = true

    if importButton.setDisabled ~= nil then
        pcall(function()
            importButton:setDisabled(false)
        end)
    end

    if importButton.setVisible ~= nil then
        pcall(function()
            importButton:setVisible(true)
        end)
    end

    if importButton.setIsActive ~= nil then
        pcall(function()
            importButton:setIsActive(true)
        end)
    end
end

function FarmIconColor:hookFarmDialogImportMouseClick(dialog, importButton)
    if type(dialog) ~= "table" or type(importButton) ~= "table" then
        return
    end

    dialog.farmIconColorImportButtonElement = importButton

    if dialog.farmIconColorImportMouseHooked == true or type(dialog.mouseEvent) ~= "function" then
        return
    end

    dialog.farmIconColorImportMouseHooked = true
    dialog.farmIconColorOriginalMouseEvent = dialog.mouseEvent

    dialog.mouseEvent = function(guiSelf, posX, posY, isDown, isUp, button, eventUsed)
        local activeButton = guiSelf.farmIconColorImportButtonElement

        if type(activeButton) == "table"
            and activeButton.visible ~= false
            and activeButton.disabled ~= true
            and FarmIconColor:isCurrentUserFarmIconAdmin()
            and Input ~= nil
            and GuiUtils ~= nil
            and GuiUtils.checkOverlayOverlap ~= nil
            and button == Input.MOUSE_BUTTON_LEFT
            and type(activeButton.absPosition) == "table"
            and type(activeButton.size) == "table" then

            local inside = GuiUtils.checkOverlayOverlap(
                posX,
                posY,
                activeButton.absPosition[1],
                activeButton.absPosition[2],
                activeButton.size[1],
                activeButton.size[2],
                activeButton.hotspot
            )

            if isDown and inside then
                guiSelf.farmIconColorImportMousePressed = true

                if activeButton.setPressed ~= nil then
                    pcall(function()
                        activeButton:setPressed(true)
                    end)
                end

                return true
            end

            if isUp then
                local wasPressed = guiSelf.farmIconColorImportMousePressed == true
                guiSelf.farmIconColorImportMousePressed = false

                if activeButton.setPressed ~= nil then
                    pcall(function()
                        activeButton:setPressed(false)
                    end)
                end

                if inside and wasPressed then
                    FarmIconColor:onFarmDialogImportButtonClicked(guiSelf, activeButton)
                    return true
                end
            end
        elseif isUp then
            guiSelf.farmIconColorImportMousePressed = false
        end

        return guiSelf.farmIconColorOriginalMouseEvent(guiSelf, posX, posY, isDown, isUp, button, eventUsed)
    end
end

function FarmIconColor:positionFarmDialogImportButton(importButton, colorButton)
    if type(importButton) ~= "table" or type(colorButton) ~= "table" then
        return
    end

    local colorPosition = colorButton.position
    local importSize = importButton.size
    local colorSize = colorButton.size

    if type(colorPosition) ~= "table" then
        return
    end

    local x = tonumber(colorPosition[1]) or 0
    local y = tonumber(colorPosition[2]) or 0
    local width = type(colorSize) == "table" and tonumber(colorSize[1]) or nil
    width = width or (type(importSize) == "table" and tonumber(importSize[1]) or nil) or 0.12
    local height = type(colorSize) == "table" and tonumber(colorSize[2]) or nil
    local spacing = 0.010
    local newX = x - width - spacing

    -- Keep the import button out of a parent BoxLayout: we want it exactly to the left
    -- of the existing Color button (the empty footer slot visible in the farm dialog).
    importButton.layoutIgnore = true

    if importButton.setSize ~= nil and height ~= nil then
        pcall(function()
            importButton:setSize(width, height)
        end)
    elseif type(importButton.size) == "table" then
        importButton.size[1] = width
        if height ~= nil then
            importButton.size[2] = height
        end
    end

    if importButton.setPosition ~= nil then
        pcall(function()
            importButton:setPosition(newX, y)
        end)
    else
        importButton.position = importButton.position or {newX, y}
        importButton.position[1] = newX
        importButton.position[2] = y
    end

    if importButton.updateAbsolutePositionRec ~= nil then
        pcall(function()
            importButton:updateAbsolutePositionRec()
        end)
    elseif importButton.updateAbsolutePosition ~= nil then
        pcall(function()
            importButton:updateAbsolutePosition()
        end)
    end
end

function FarmIconColor:ensureActiveFarmDialogImportButton()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return
    end

    local isAdmin = self:isCurrentUserFarmIconAdmin()

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            local colorButton = self:findFarmDialogModifyButton(dialog, 0, 8, 300, {})

            if colorButton == nil and type(dialog.target) == "table" then
                colorButton = self:findFarmDialogModifyButton(dialog.target, 0, 8, 300, {})
            end

            if colorButton ~= nil then
                local importButton = colorButton.farmIconColorImportButtonElement

                if isAdmin and type(importButton) ~= "table" and colorButton.clone ~= nil and type(colorButton.parent) == "table" then
                    local success, cloned = pcall(function()
                        return colorButton:clone(colorButton.parent, false, true)
                    end)

                    if success and type(cloned) == "table" then
                        importButton = cloned
                        colorButton.farmIconColorImportButtonElement = importButton
                        importButton.farmIconColorImportButton = true
                        importButton.farmIconColorColorPickerHooked = false
                        importButton.name = "farmIconColorImportButton"
                        importButton.onClickCallback = function(target, element)
                            FarmIconColor:onFarmDialogImportButtonClicked(target, element or importButton)
                        end
                        importButton.isTriggerableByGlobalAction = false

                        self:setGuiElementText(importButton, self:getTranslatedText("input_FARMICONCOLOR_IMPORT_CUSTOM_LOGO", "Import"))

                        if importButton.setInputAction ~= nil then
                            pcall(function()
                                importButton:setInputAction(self.CUSTOM_LOGO_IMPORT_ACTION_NAME)
                            end)
                        else
                            importButton.inputActionName = self.CUSTOM_LOGO_IMPORT_ACTION_NAME
                        end

                        self:positionFarmDialogImportButton(importButton, colorButton)
                        self:ensureFarmDialogImportButtonMouseRegistration(importButton)
                        self:hookFarmDialogImportMouseClick(dialog, importButton)
                        self:showGuiElementWithParents(importButton)

                        if type(importButton.parent) == "table" and importButton.parent.invalidateLayout ~= nil then
                            pcall(function()
                                importButton.parent:invalidateLayout()
                            end)
                        end

                        if not self.farmDialogImportButtonLogged then
                            self.farmDialogImportButtonLogged = true
                            FarmIconColor:debugPrint(string.format("[%s] Added admin custom-logo import button: %s", self.MOD_NAME, self:describeGuiElement(importButton)))
                        end
                    end
                elseif type(importButton) == "table" then
                    self:setGuiElementText(importButton, self:getTranslatedText("input_FARMICONCOLOR_IMPORT_CUSTOM_LOGO", "Import"))

                    if importButton.setInputAction ~= nil then
                        pcall(function()
                            importButton:setInputAction(self.CUSTOM_LOGO_IMPORT_ACTION_NAME)
                        end)
                    else
                        importButton.inputActionName = self.CUSTOM_LOGO_IMPORT_ACTION_NAME
                    end

                    self:positionFarmDialogImportButton(importButton, colorButton)
                    self:hookFarmDialogImportMouseClick(dialog, importButton)

                    if isAdmin then
                        self:ensureFarmDialogImportButtonMouseRegistration(importButton)
                        self:showGuiElementWithParents(importButton)
                    else
                        self:hideGuiElement(importButton)
                    end
                end
            end
        end
    end
end

function FarmIconColor:onFarmDialogImportButtonClicked(target, element)
    if not self:isCurrentUserFarmIconAdmin() then
        return false
    end

    self:importCustomLogosFromFolder()
    return true
end

function FarmIconColor:hookActiveFarmDialogColorPickerButton()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return
    end

    if g_gui.currentListener == ColorPickerDialog then
        return
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            local button = self:findFarmDialogModifyButton(dialog, 0, 8, 300, {})

            if button == nil and type(dialog.target) == "table" then
                button = self:findFarmDialogModifyButton(dialog.target, 0, 8, 300, {})
            end

            if button ~= nil and button.farmIconColorColorPickerHooked ~= true then
                local hookedButton = button

                hookedButton.farmIconColorColorPickerHooked = true
                hookedButton.farmIconColorOriginalOnClickCallback = hookedButton.onClickCallback
                hookedButton.onClickCallback = function(target, element)
                    FarmIconColor:onFarmDialogColorPickerButtonClicked(target, element or hookedButton)
                end
                local colorButtonText = self:getTranslatedText("input_FARMICONCOLOR_OPEN_SOLO_PICKER", "Change farm color")
                self:setGuiElementText(hookedButton, colorButtonText)
                self:showGuiElement(hookedButton)

                if not self.farmDialogColorButtonHookLogged then
                    self.farmDialogColorButtonHookLogged = true
                    FarmIconColor:debugPrint(string.format("[%s] Hooked farm edit dialog MODIFY button to open ColorPicker: %s", self.MOD_NAME, self:describeGuiElement(hookedButton)))
                end
            end
        end
    end
end


function FarmIconColor:hideActiveFarmDialogVanillaColorControls()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            local changed = self:hideVanillaColorControlsInElementTree(dialog, 0, 8, 350, {})

            if type(dialog.target) == "table" then
                changed = changed + self:hideVanillaColorControlsInElementTree(dialog.target, 0, 8, 350, {})
            end

            if changed > 0 and not self.farmDialogVanillaColorControlsHiddenLogged then
                self.farmDialogVanillaColorControlsHiddenLogged = true
                FarmIconColor:debugPrint(string.format("[%s] Hidden %d vanilla farm color control element(s) in EditFarmDialog", self.MOD_NAME, changed))
            end
        end
    end
end

function FarmIconColor:hideVanillaColorControlsInElementTree(element, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return 0
    end

    if visited[element] then
        return 0
    end

    visited[element] = true

    local changed = 0
    if self:isColorPickElement(element) or self:isFarmDialogColorLabelElement(element) then
        changed = changed + self:hideGuiElement(element)
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            if remaining <= 0 then
                break
            end

            changed = changed + self:hideVanillaColorControlsInElementTree(child, depth + 1, maxDepth, remaining, visited)
            remaining = remaining - 1
        end
    end

    for key, value in pairs(element) do
        if remaining <= 0 then
            break
        end

        if type(value) == "table" and key ~= "parent" and key ~= "target" and key ~= "player" and key ~= "users" and key ~= "farms" then
            changed = changed + self:hideVanillaColorControlsInElementTree(value, depth + 1, maxDepth, remaining, visited)
            remaining = remaining - 1
        end
    end

    return changed
end

function FarmIconColor:countDirectColorPickChildren(element)
    if type(element) ~= "table" or type(element.elements) ~= "table" then
        return 0
    end

    local count = 0

    for _, child in ipairs(element.elements) do
        if self:isColorPickElement(child) then
            count = count + 1
        end
    end

    return count
end

function FarmIconColor:isFarmDialogColorLabelElement(element)
    if type(element) ~= "table" then
        return false
    end



    if element.onClickCallback ~= nil or element.inputActionName ~= nil or self:isGuiButtonElement(element) then
        return false
    end

    local rawText = self:getGuiElementText(element)
    local text = string.lower(rawText)


    if string.find(text, "change", 1, true) ~= nil
        or string.find(text, "modify", 1, true) ~= nil
        or string.find(text, "modifier", 1, true) ~= nil
        or string.find(text, "changer", 1, true) ~= nil
        or string.find(text, "aendern", 1, true) ~= nil
        or string.find(text, "andern", 1, true) ~= nil
        or string.find(text, "ändern", 1, true) ~= nil
        or string.find(rawText, "ÄNDERN", 1, true) ~= nil
        or string.find(rawText, "Ändern", 1, true) ~= nil
    then
        return false
    end

    return string.find(text, "couleur de la fe", 1, true) ~= nil
        or string.find(text, "farm color", 1, true) ~= nil


        or string.find(text, "hoffarbe", 1, true) ~= nil
        or string.find(text, "hof-farbe", 1, true) ~= nil
        or string.find(text, "hof farbe", 1, true) ~= nil
        or string.find(text, "farbe des hof", 1, true) ~= nil
        or string.find(text, "farbe", 1, true) ~= nil
        or string.find(rawText, "Hoffarbe", 1, true) ~= nil
        or string.find(rawText, "HOF-FARBE", 1, true) ~= nil
        or string.find(rawText, "Hof-Farbe", 1, true) ~= nil
        or string.find(rawText, "Farbe", 1, true) ~= nil
        or string.find(rawText, "FARBE", 1, true) ~= nil
end

function FarmIconColor:isGuiButtonElement(element)
    if type(element) ~= "table" then
        return false
    end

    local profile = element.profile ~= nil and tostring(element.profile) or ""
    local typeName = element.typeName ~= nil and tostring(element.typeName) or ""

    return string.find(profile, "button", 1, true) ~= nil
        or string.find(profile, "Button", 1, true) ~= nil
        or string.find(typeName, "Button", 1, true) ~= nil
end

function FarmIconColor:hideGuiElement(element)
    if type(element) ~= "table" or element.farmIconColorHidden == true then
        return 0
    end

    if element.farmIconColorColorPickerHooked == true then
        return 0
    end

    if element.farmIconColorLogoSelectorLabel == true then
        return 0
    end

    element.farmIconColorHidden = true

    if element.setVisible ~= nil then
        pcall(function()
            element:setVisible(false)
        end)
    end

    if element.setDisabled ~= nil then
        pcall(function()
            element:setDisabled(true)
        end)
    end

    element.visible = false
    element.disabled = true

    return 1
end

function FarmIconColor:showGuiElement(element)
    if type(element) ~= "table" then
        return
    end

    element.farmIconColorHidden = false
    element.visible = true
    element.disabled = false

    if element.setVisible ~= nil then
        pcall(function()
            element:setVisible(true)
        end)
    end

    if element.setDisabled ~= nil then
        pcall(function()
            element:setDisabled(false)
        end)
    end
end

function FarmIconColor:showGuiElementWithParents(element)
    local current = element
    local safety = 0

    while type(current) == "table" and safety < 12 do
        self:showGuiElement(current)
        current = current.parent
        safety = safety + 1
    end
end

function FarmIconColor:isFarmEditDialogCandidate(dialog)
    if type(dialog) ~= "table" then
        return false
    end

    if self:isFarmEditDialogObject(dialog) or self:isFarmEditDialogObject(dialog.target) then
        return true
    end

    if self:findFarmDialogModifyButton(dialog, 0, 8, 300, {}) ~= nil then
        return true
    end

    if type(dialog.target) == "table" and self:findFarmDialogModifyButton(dialog.target, 0, 8, 300, {}) ~= nil then
        return true
    end

    return false
end

function FarmIconColor:findFarmDialogModifyButton(element, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    if visited[element] then
        return nil
    end

    visited[element] = true

    if self:isFarmDialogModifyButtonElement(element) then
        return element
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            local button = self:findFarmDialogModifyButton(child, depth + 1, maxDepth, remaining, visited)

            if button ~= nil then
                return button
            end
        end
    end

    return nil
end

function FarmIconColor:isFarmDialogModifyButtonElement(element)
    if type(element) ~= "table" or element.onClickCallback == nil then
        return false
    end

    if element.farmIconColorColorPickerHooked == true then
        return true
    end

    if self:isColorPickElement(element) or self:isFarmDialogColorLabelElement(element) then
        return false
    end

    local text = self:getGuiElementText(element)
    local lowerText = string.lower(text)





    return string.find(lowerText, "modifier", 1, true) ~= nil
        or string.find(lowerText, "modify", 1, true) ~= nil
        or string.find(lowerText, "changer", 1, true) ~= nil
        or string.find(lowerText, "change", 1, true) ~= nil
        or string.find(lowerText, "ändern", 1, true) ~= nil
        or string.find(lowerText, "aendern", 1, true) ~= nil
        or string.find(lowerText, "andern", 1, true) ~= nil
        or string.find(text, "ÄNDERN", 1, true) ~= nil
        or string.find(text, "Ändern", 1, true) ~= nil
        or string.find(text, "ändern", 1, true) ~= nil
        or string.find(text, "AENDERN", 1, true) ~= nil
        or string.find(text, "Aendern", 1, true) ~= nil
end

function FarmIconColor:getGuiElementText(element)
    if type(element) ~= "table" then
        return ""
    end

    local parts = {}

    if element.text ~= nil then
        table.insert(parts, tostring(element.text))
    end

    if element.textRaw ~= nil then
        table.insert(parts, tostring(element.textRaw))
    end

    if element.displayText ~= nil then
        table.insert(parts, tostring(element.displayText))
    end

    if element.name ~= nil then
        table.insert(parts, tostring(element.name))
    end

    if element.profile ~= nil then
        table.insert(parts, tostring(element.profile))
    end

    if element.inputActionName ~= nil then
        table.insert(parts, tostring(element.inputActionName))
    end

    return table.concat(parts, " ")
end

function FarmIconColor:describeGuiElement(element)
    if type(element) ~= "table" then
        return tostring(element)
    end

    return string.format("name=%s text=%s profile=%s inputAction=%s", tostring(element.name), tostring(element.text), tostring(element.profile), tostring(element.inputActionName))
end

function FarmIconColor:setGuiElementText(element, text)
    if type(element) ~= "table" then
        return
    end

    if element.setText ~= nil then
        local success = pcall(function()
            element:setText(text)
        end)

        if success then
            return
        end
    end

    element.text = text
end

function FarmIconColor:onFarmDialogColorPickerButtonClicked(target, element)
    FarmIconColor:debugPrint(string.format("[%s] Farm edit dialog MODIFY button clicked: opening ColorPicker instead of vanilla action", self.MOD_NAME))
    self:openColorPickerPrototype()
end

function FarmIconColor:getActiveFarmDialogFarmId()
    if g_gui == nil then
        return nil
    end

    local candidates = {
        g_gui.currentListener,
        g_gui.currentDialog
    }

    if type(g_gui.dialogs) == "table" then
        for _, dialog in pairs(g_gui.dialogs) do
            if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
                table.insert(candidates, dialog)

                if type(dialog.target) == "table" then
                    table.insert(candidates, dialog.target)
                end
            end
        end
    end

    for _, candidate in ipairs(candidates) do
        if self:isFarmEditDialogObject(candidate) then
            local farmId = self:findFarmIdInDialogObject(candidate, 0, 5, {})

            if self:isValidFarmId(farmId) then
                return farmId
            end
        end
    end

    return nil
end

function FarmIconColor:isFarmEditDialogObject(value)
    if type(value) ~= "table" then
        return false
    end

    local name = value.name ~= nil and tostring(value.name) or ""
    local xmlFilename = value.xmlFilename ~= nil and tostring(value.xmlFilename) or ""

    return name == "EditFarmDialog"
        or string.find(name, "EditFarmDialog", 1, true) ~= nil
        or string.find(xmlFilename, "EditFarmDialog", 1, true) ~= nil
end

function FarmIconColor:findFarmIdInDialogObject(value, depth, maxDepth, visited)
    if type(value) ~= "table" or depth > maxDepth then
        return nil
    end

    if visited[value] then
        return nil
    end

    visited[value] = true

    local directKeys = {
        "farmId",
        "selectedFarmId",
        "currentFarmId",
        "editFarmId"
    }

    for _, key in ipairs(directKeys) do
        if self:isValidFarmId(value[key]) then
            return value[key]
        end
    end

    local farmKeys = {
        "farm",
        "selectedFarm",
        "currentFarm",
        "editFarm"
    }

    for _, key in ipairs(farmKeys) do
        local farm = value[key]

        if type(farm) == "table" then
            if self:isValidFarmId(farm.farmId) then
                return farm.farmId
            end

            if self:isValidFarmId(farm.id) then
                return farm.id
            end
        end
    end

    for key, nestedValue in pairs(value) do
        if type(nestedValue) == "table" and key ~= "parent" and key ~= "target" and key ~= "player" and key ~= "users" and key ~= "farms" and key ~= "elements" then
            local farmId = self:findFarmIdInDialogObject(nestedValue, depth + 1, maxDepth, visited)

            if self:isValidFarmId(farmId) then
                return farmId
            end
        end
    end

    return nil
end

function FarmIconColor:getTargetFarmId()
    local dialogFarmId = self:getActiveFarmDialogFarmId()

    if dialogFarmId ~= nil then
        return dialogFarmId
    end

    if self.appliedFarmId ~= nil then
        return self.appliedFarmId
    end

    return self:getCurrentFarmId()
end

function FarmIconColor:hasVisibleDialog()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return false
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) then
            return true
        end
    end

    return false
end

function FarmIconColor:getSelectedDialogColor()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return nil
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) then
            local color = self:findSelectedColorButtonColor(dialog, 0, 8, 250, {})

            if color ~= nil then
                return color
            end

            if type(dialog) == "table" and type(dialog.target) == "table" then
                color = self:findSelectedColorButtonColor(dialog.target, 0, 8, 250, {})

                if color ~= nil then
                    return color
                end
            end
        end
    end

    return nil
end

function FarmIconColor:findSelectedColorButtonColor(element, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    if visited[element] then
        return nil
    end

    visited[element] = true

    if self:isColorPickElement(element) and self:isGuiElementSelected(element) then
        local color = self:getGuiElementOverlayColor(element)

        if color ~= nil then
            return color
        end
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            local color = self:findSelectedColorButtonColor(child, depth + 1, maxDepth, remaining, visited)

            if color ~= nil then
                return color
            end
        end
    end

    for key, value in pairs(element) do
        if remaining <= 0 then
            break
        end

        if self:shouldScanGuiField(key, value) then
            local color = self:findSelectedColorButtonColor(value, depth + 1, maxDepth, remaining, visited)

            if color ~= nil then
                return color
            end

            remaining = remaining - 1
        end
    end

    return nil
end

function FarmIconColor:applyVisibleDialogPreviewLogoColor(color)
    local bestElement = self:getVisibleDialogPreviewLogoElement()

    if bestElement ~= nil then
        self:prepareFarmLogoElementForCustomTexture(bestElement)
    end

    local changed = self:applyVisibleFarmEditDialogLogoColors(color)

    if changed > 0 then
        if bestElement ~= nil then
        end

        return changed
    end

    if bestElement ~= nil then
        changed = self:applyGuiImageElementColor(bestElement, color)
        return changed
    end

    return 0
end

function FarmIconColor:getVisibleDialogPreviewLogoElement()
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return nil
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            local logoElement = self:getFarmEditDialogLogoElement(dialog)

            if logoElement ~= nil then
                return logoElement
            end
        end
    end

    return nil
end

function FarmIconColor:applyVisibleFarmEditDialogLogoColors(color)
    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return 0
    end

    local changed = 0

    for _, dialog in pairs(g_gui.dialogs) do
        if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
            local logoElement = self:getFarmEditDialogLogoElement(dialog)

            if logoElement ~= nil then
                self:prepareFarmLogoElementForCustomTexture(logoElement, self:getActiveFarmDialogFarmId())
                changed = changed + self:applyGuiImageElementColor(logoElement, color)
            end
        end
    end

    return changed
end

function FarmIconColor:getFarmEditDialogLogoElement(dialog)
    if type(dialog) ~= "table" then
        return nil
    end

    if type(dialog.farmIconPreview) == "table" then
        return dialog.farmIconPreview
    end

    if type(dialog.target) == "table" and type(dialog.target.farmIconPreview) == "table" then
        return dialog.target.farmIconPreview
    end

    local element = self:findFarmEditDialogLogoElement(dialog, 0, 8, {})

    if element ~= nil then
        return element
    end

    if type(dialog.target) == "table" then
        return self:findFarmEditDialogLogoElement(dialog.target, 0, 8, {})
    end

    return nil
end

function FarmIconColor:findFarmEditDialogLogoElement(element, depth, maxDepth, visited)
    if type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    visited = visited or {}

    if visited[element] then
        return nil
    end

    visited[element] = true

    if self:isFarmEditDialogLogoElement(element) then
        return element
    end

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            local match = self:findFarmEditDialogLogoElement(child, depth + 1, maxDepth, visited)

            if match ~= nil then
                return match
            end
        end
    end

    return nil
end

function FarmIconColor:isFarmEditDialogLogoElement(element)
    if type(element) ~= "table" or self:isColorPickElement(element) then
        return false
    end

    local profile = element.profile ~= nil and tostring(element.profile) or ""

    if profile == "fs25_editFarmDialogFarmIcon" then
        return true
    end

    return false
end

function FarmIconColor:applyFarmLogoGuiElementsInTree(element, color, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return 0
    end

    if visited[element] then
        return 0
    end

    visited[element] = true

    local changed = 0

    if self:isFarmLogoGuiElement(element) and not self:isColorPickElement(element) then
        self:prepareFarmLogoElementForCustomTexture(element)
        changed = changed + self:applyGuiImageElementColor(element, color)
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            if remaining <= 0 then
                break
            end

            changed = changed + self:applyFarmLogoGuiElementsInTree(child, color, depth + 1, maxDepth, remaining, visited)
            remaining = remaining - 1
        end
    end

    return changed
end

function FarmIconColor:applyFarmLogoGuiElementsInNamedFields(element, color, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return 0
    end

    if visited[element] then
        return 0
    end

    visited[element] = true

    local changed = 0

    if self:isFarmLogoGuiElement(element) and not self:isColorPickElement(element) then
        changed = changed + self:applyGuiImageElementColor(element, color)
    end

    remaining = remaining - 1

    for key, value in pairs(element) do
        if remaining <= 0 then
            break
        end

        if self:shouldScanFarmDialogLogoField(key, value) then
            changed = changed + self:applyFarmLogoGuiElementsInNamedFields(value, color, depth + 1, maxDepth, remaining, visited)
            remaining = remaining - 1
        end
    end

    return changed
end

function FarmIconColor:shouldScanFarmDialogLogoField(key, value)
    if type(value) ~= "table" then
        return false
    end

    local keyText = tostring(key)

    if keyText == "parent"
        or keyText == "target"
        or keyText == "delegate"
        or keyText == "dataSource"
        or keyText == "inGameMenu"
        or keyText == "currentPage"
        or keyText == "farmList"
        or keyText == "elementFarmIdMap"
        or keyText == "farms"
        or keyText == "users"
        or keyText == "player" then
        return false
    end

    return string.find(keyText, "farmIcon", 1, true) ~= nil
        or string.find(keyText, "FarmIcon", 1, true) ~= nil
        or string.find(keyText, "logo", 1, true) ~= nil
        or string.find(keyText, "Logo", 1, true) ~= nil
        or string.find(keyText, "icon", 1, true) ~= nil
        or string.find(keyText, "Icon", 1, true) ~= nil
        or string.find(keyText, "image", 1, true) ~= nil
        or string.find(keyText, "Image", 1, true) ~= nil
        or string.find(keyText, "preview", 1, true) ~= nil
        or string.find(keyText, "Preview", 1, true) ~= nil
end

function FarmIconColor:findLargestDialogLogoElement(element, depth, maxDepth, remaining, visited, bestElement, bestArea)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return bestElement, bestArea
    end

    if visited[element] then
        return bestElement, bestArea
    end

    visited[element] = true

    if self:isFarmLogoGuiElement(element) and not self:isColorPickElement(element) then
        local area = self:getGuiElementArea(element)

        if area > bestArea then
            bestElement = element
            bestArea = area
        end
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            bestElement, bestArea = self:findLargestDialogLogoElement(child, depth + 1, maxDepth, remaining, visited, bestElement, bestArea)
        end
    end

    return bestElement, bestArea
end

function FarmIconColor:shouldScanGuiField(key, value)
    if type(value) ~= "table" or key == "parent" or key == "target" or key == "player" or key == "users" or key == "farms" then
        return false
    end

    local keyText = tostring(key)

    return string.find(keyText, "farm", 1, true) ~= nil
        or string.find(keyText, "Farm", 1, true) ~= nil
        or string.find(keyText, "icon", 1, true) ~= nil
        or string.find(keyText, "Icon", 1, true) ~= nil
        or string.find(keyText, "image", 1, true) ~= nil
        or string.find(keyText, "Image", 1, true) ~= nil
        or string.find(keyText, "dialog", 1, true) ~= nil
        or string.find(keyText, "Dialog", 1, true) ~= nil
        or string.find(keyText, "preview", 1, true) ~= nil
        or string.find(keyText, "Preview", 1, true) ~= nil
        or string.find(keyText, "color", 1, true) ~= nil
        or string.find(keyText, "Color", 1, true) ~= nil
end

function FarmIconColor:isColorPickElement(element)
    if type(element) ~= "table" then
        return false
    end

    local profile = element.profile ~= nil and tostring(element.profile) or ""
    local name = element.name ~= nil and tostring(element.name) or ""
    local typeName = element.typeName ~= nil and tostring(element.typeName) or ""
    local overlay = element.overlay
    local sliceId = type(overlay) == "table" and overlay.sliceId ~= nil and tostring(overlay.sliceId) or ""

    return string.find(profile, "color", 1, true) ~= nil
        or string.find(profile, "Color", 1, true) ~= nil
        or string.find(name, "color", 1, true) ~= nil
        or string.find(name, "Color", 1, true) ~= nil
        or string.find(typeName, "ColorPick", 1, true) ~= nil
        or sliceId == "gui.colorPreset"
end

function FarmIconColor:isGuiElementSelected(element)
    if element.selected == true or element.focused == true then
        return true
    end

    if element.getIsSelected ~= nil then
        local success, result = pcall(function()
            return element:getIsSelected()
        end)

        if success and result == true then
            return true
        end
    end

    return false
end

function FarmIconColor:getGuiElementOverlayColor(element)
    if type(element) ~= "table" or type(element.overlay) ~= "table" then
        return nil
    end

    if type(element.overlay.color) == "table" then
        return self:copyColor(element.overlay.color)
    end

    if GuiOverlay ~= nil and GuiOverlay.getOverlayColor ~= nil then
        local success, color = pcall(function()
            return GuiOverlay.getOverlayColor(element.overlay, GuiOverlay.STATE_NORMAL)
        end)

        if success and type(color) == "table" then
            return self:copyColor(color)
        end
    end

    return nil
end

function FarmIconColor:getGuiElementArea(element)
    local size = type(element.absSize) == "table" and element.absSize or element.size

    if type(size) == "table" and size[1] ~= nil and size[2] ~= nil then
        return (tonumber(size[1]) or 0) * (tonumber(size[2]) or 0)
    end

    return 0
end

function FarmIconColor:getSelectedFarmMenuFarmId()
    local inGameMenu = self:getInGameMenuCandidate()

    if type(inGameMenu) ~= "table" then
        return self:getCurrentFarmId()
    end

    local currentPage = self:getCurrentInGameMenuPage(inGameMenu)

    if type(currentPage) == "table" then
        if currentPage.selectedFarmId ~= nil then
            return currentPage.selectedFarmId
        end

        if type(currentPage.currentFarm) == "table" and currentPage.currentFarm.farmId ~= nil then
            return currentPage.currentFarm.farmId
        end
    end

    return self:getCurrentFarmId()
end

function FarmIconColor:applyNamedFarmIconColorInElementTree(element, color, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return 0
    end

    visited = visited or {}

    if visited[element] then
        return 0
    end

    visited[element] = true

    local changed = 0

    if self:isFarmLogoGuiElement(element) then
        changed = changed + self:applyGuiImageElementColor(element, color)
    end

    remaining = remaining - 1

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            if remaining <= 0 then
                break
            end

            changed = changed + self:applyNamedFarmIconColorInElementTree(child, color, depth + 1, maxDepth, remaining, visited)
            remaining = remaining - 1
        end
    end

    local scannedFields = 0

    for key, value in pairs(element) do
        if remaining <= 0 or scannedFields >= 30 then
            break
        end

        if type(value) == "table" and key ~= "parent" and key ~= "target" and key ~= "player" and key ~= "users" and key ~= "farms" then
            local keyText = tostring(key)

            if string.find(keyText, "farm", 1, true) ~= nil
                or string.find(keyText, "Farm", 1, true) ~= nil
                or string.find(keyText, "icon", 1, true) ~= nil
                or string.find(keyText, "Icon", 1, true) ~= nil
                or string.find(keyText, "image", 1, true) ~= nil
                or string.find(keyText, "Image", 1, true) ~= nil
                or string.find(keyText, "dialog", 1, true) ~= nil
                or string.find(keyText, "Dialog", 1, true) ~= nil
                or string.find(keyText, "preview", 1, true) ~= nil
                or string.find(keyText, "Preview", 1, true) ~= nil then
                scannedFields = scannedFields + 1
                changed = changed + self:applyNamedFarmIconColorInElementTree(value, color, depth + 1, maxDepth, remaining, visited)
                remaining = remaining - 1
            end
        end
    end

    return changed
end

function FarmIconColor:isDialogVisible(dialog)
    if type(dialog) ~= "table" then
        return false
    end

    if dialog.visible == true then
        return true
    end

    if type(dialog.target) == "table" and dialog.target.visible == true then
        return true
    end

    if type(dialog.elements) == "table" then
        for _, element in ipairs(dialog.elements) do
            if type(element) == "table" and element.visible == true then
                return true
            end
        end
    end

    return false
end

function FarmIconColor:normalizeLogoName(value)
    if value == nil then
        return nil
    end

    local text = string.lower(tostring(value))
    text = string.gsub(text, "\\", "/")
    text = string.gsub(text, "^gui%.multiplayer_", "")
    text = string.gsub(text, ".*gui%.multiplayer_", "")
    text = string.gsub(text, "^multiplayer_", "")
    text = string.gsub(text, "^logo_", "")

    local filename = string.match(text, "([^/]+)$")

    if filename ~= nil then
        text = filename
    end

    text = string.gsub(text, "%.[%w_]+$", "")

    if text == "" or text == "farmicon" or text == "farm_icon" then
        return nil
    end

    return text
end

function FarmIconColor:getLogoNameFromGuiElement(element)
    if type(element) ~= "table" then
        return nil
    end

    if element.farmIconColorLogoName ~= nil then
        return element.farmIconColorLogoName
    end

    local overlay = element.overlay

    if type(overlay) == "table" and overlay.sliceId ~= nil then
        local sliceId = tostring(overlay.sliceId)

        if self:isFarmLogoSliceId(sliceId) then
            local logoName = self:normalizeLogoName(sliceId)
            element.farmIconColorLogoName = logoName
            return logoName
        end
    end

    local candidates = {
        element.imageFilename,
        element.filename,
        element.profile,
        element.name
    }

    for _, candidate in ipairs(candidates) do
        local logoName = self:normalizeLogoName(candidate)

        if logoName ~= nil and self.logoColors[logoName] ~= nil then
            element.farmIconColorLogoName = logoName
            return logoName
        end
    end

    return nil
end

function FarmIconColor:isKnownLogoName(logoName)
    local normalizedName = self:normalizeLogoName(logoName)

    if normalizedName == nil then
        return false
    end

    return self.logos[normalizedName] ~= nil or self.logoColors[normalizedName] ~= nil
end

function FarmIconColor:isFarmLogoSliceId(sliceId)
    if sliceId == nil then
        return false
    end

    local sliceText = tostring(sliceId)

    if string.find(sliceText, "gui.multiplayer_", 1, true) == nil then
        return false
    end

    local blockedFragments = {
        "blackBox",
        "plus",
        "farm_middle",
        "farm_left",
        "farm_right",
        "colorPreset"
    }

    for _, fragment in ipairs(blockedFragments) do
        if string.find(sliceText, fragment, 1, true) ~= nil then
            return false
        end
    end

    return self:isKnownLogoName(sliceText)
end

function FarmIconColor:ensureTestLogos()



    self:ensureSelectableLogos()
end

function FarmIconColor:addLogoToOrder(logoName)
    if logoName == nil then
        return
    end

    self.logoOrder = self.logoOrder or {}

    for _, existingLogoName in ipairs(self.logoOrder) do
        if existingLogoName == logoName then
            return
        end
    end

    table.insert(self.logoOrder, logoName)
end

function FarmIconColor:ensureSelectableLogos()
    self.logos = self.logos or {}
    self.logoOrder = self.logoOrder or {}





    if #self.logoOrder == 0 and self.logos["chicken"] ~= nil then
        self:addLogoToOrder("chicken")
    end
end

function FarmIconColor:getLogoIndex(logoName)
    self:ensureSelectableLogos()

    for index, currentLogoName in ipairs(self.logoOrder) do
        if currentLogoName == logoName then
            return index
        end
    end

    return 1
end

function FarmIconColor:getLogoNameByOffset(currentLogoName, offset)
    self:ensureSelectableLogos()

    local logoCount = #self.logoOrder

    if logoCount <= 0 then
        return nil
    end

    local currentIndex = self:getLogoIndex(currentLogoName)
    local newIndex = ((currentIndex - 1 + offset) % logoCount) + 1

    return self.logoOrder[newIndex]
end

function FarmIconColor:getGameLanguageShort()
    local language = nil

    if g_languageShort ~= nil then
        language = tostring(g_languageShort)
    elseif g_i18n ~= nil then
        if g_i18n.currentLanguage ~= nil then
            language = tostring(g_i18n.currentLanguage)
        elseif g_i18n.languageShort ~= nil then
            language = tostring(g_i18n.languageShort)
        end
    end

    language = string.lower(language or "fr")

    if string.sub(language, 1, 2) == "fr" then
        return "fr"
    end

    return "en"
end

function FarmIconColor:getLogoFallbackDisplayName(logoName)
    local names = {
        cluster = {
            fr = "Grappe",
            en = "Grape"
        },
        carrot = {
            fr = "Carotte",
            en = "Carrot"
        },
        square_ball = {
            fr = "Balle carrée",
            en = "Square bale"
        }
    }

    local entry = names[logoName]

    if entry == nil then
        return nil
    end

    return entry[self:getGameLanguageShort()] or entry.en or logoName
end

function FarmIconColor:getLogoDisplayName(logoName)
    if logoName == nil then
        return "none"
    end

    if self.customLogoDisplayNames ~= nil and self.customLogoDisplayNames[logoName] ~= nil then
        return tostring(self.customLogoDisplayNames[logoName])
    end

    local l10nKey = self.logoL10n ~= nil and self.logoL10n[logoName] or nil

    if l10nKey ~= nil and g_i18n ~= nil and g_i18n.getText ~= nil then
        local success, translatedText = pcall(function()
            return g_i18n:getText(l10nKey)
        end)

        if success and translatedText ~= nil and translatedText ~= "" and translatedText ~= l10nKey and string.sub(tostring(translatedText), 1, 8) ~= "Missing " then
            return translatedText
        end
    end

    local fallbackName = self:getLogoFallbackDisplayName(logoName)

    if fallbackName ~= nil then
        return fallbackName
    end

    return logoName
end

function FarmIconColor:getDefaultCustomLogoName()
    self:ensureSelectableLogos()

    if self.logoOrder ~= nil and self.logoOrder[1] ~= nil then
        return self.logoOrder[1]
    end

    return "chicken"
end

function FarmIconColor:getNextTestLogoNameForNewFarm()


    return self:getDefaultCustomLogoName()
end

function FarmIconColor:getLogoNameForFarmId(farmId)
    self:ensureSelectableLogos()

    if self:isValidFarmId(farmId) and type(self.runtimeFarmLogos) == "table" then
        local runtimeLogo = self.runtimeFarmLogos[tostring(farmId)]

        if runtimeLogo ~= nil and self.logos[runtimeLogo] ~= nil then
            return runtimeLogo
        end
    end

    if farmId == nil and self:hasVisibleFarmEditDialog() then
        if self.pendingFarmCreationLogoName == nil then
            self.pendingFarmCreationLogoName = self:getDefaultCustomLogoName()
        end

        return self.pendingFarmCreationLogoName
    end

    return self:getConfiguredLogoNameForFarmId(farmId) or self:getDefaultCustomLogoName()
end

function FarmIconColor:getConfiguredLogoNameForFarmId(farmId)
    local configuredFarm = farmId ~= nil and self.farms[tostring(farmId)] or nil
    local configuredLogo = configuredFarm ~= nil and self:normalizeLogoName(configuredFarm.logo) or nil

    if configuredLogo ~= nil and self.logos[configuredLogo] ~= nil then
        return configuredLogo
    end

    return nil
end

function FarmIconColor:prepareFarmLogoElementForCustomTexture(element, farmId)
    if type(element) ~= "table" then
        return
    end

    local logoName = self:getLogoNameForFarmId(farmId)

    if logoName ~= nil and self.logos[logoName] ~= nil then
        if element.farmIconColorLogoName ~= logoName then
            element.farmIconColorLogoName = logoName
            element.farmIconColorTextureFilename = nil
            element.farmIconColorTextureLogged = false
        end

        return
    end

    if element.farmIconColorLogoName == nil then
        element.farmIconColorLogoName = self:getConfiguredLogoNameForFarmId(farmId) or self:getLogoNameFromGuiElement(element) or self:getDefaultCustomLogoName()
    end
end

function FarmIconColor:findLogoNameInElementTree(element, depth, maxDepth, visited)
    if type(element) ~= "table" or depth > maxDepth then
        return nil
    end

    visited = visited or {}

    if visited[element] then
        return nil
    end

    visited[element] = true

    local logoName = self:getLogoNameFromGuiElement(element)

    if logoName ~= nil then
        return logoName
    end

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            logoName = self:findLogoNameInElementTree(child, depth + 1, maxDepth, visited)

            if logoName ~= nil then
                return logoName
            end
        end
    end

    return nil
end

function FarmIconColor:getLogoColorByName(logoName)
    local normalizedName = self:normalizeLogoName(logoName)

    if normalizedName == nil then
        return nil
    end

    return self:parseColor(self.logoColors[normalizedName])
end

function FarmIconColor:getConfiguredLogoColorForFarmId(farmId)
    local configuredFarm = self.farms[tostring(farmId)]

    if configuredFarm == nil then
        return nil
    end

    if configuredFarm.logoColor ~= nil then
        return self:parseColor(configuredFarm.logoColor)
    end

    return self:getLogoColorByName(configuredFarm.logo)
end

function FarmIconColor:getConfiguredLogoColorForElement(farmId, element)
    if not self.applyLogoSpecificColors then
        return nil
    end

    local logoName = self:findLogoNameInElementTree(element, 0, 5, {})
    local color = self:getLogoColorByName(logoName)

    if color ~= nil then
        return color
    end

    if element ~= nil then
        return nil
    end

    return self:getConfiguredLogoColorForFarmId(farmId)
end

function FarmIconColor:getConfiguredFarmColor(configuredFarm)
    if configuredFarm ~= nil then
        local colorText = configuredFarm.color

        if colorText ~= nil then
            local normalizedColorText = string.lower(tostring(colorText))

            if normalizedColorText ~= "" and normalizedColorText ~= "logo" and normalizedColorText ~= "sameaslogo" and normalizedColorText ~= "inherit" then
                return self:parseColor(colorText), colorText
            end
        end

        local logoName = self:normalizeLogoName(configuredFarm.logo)

        if logoName ~= nil and self.logoColors[logoName] ~= nil then
            return self:parseColor(self.logoColors[logoName]), string.format("logo:%s=%s", tostring(logoName), tostring(self.logoColors[logoName]))
        end
    end

    return self:parseColor(self.defaultColor), self.defaultColor
end

function FarmIconColor:getConfiguredColorForFarmId(farmId)
    local configuredFarm = self.farms[tostring(farmId)]

    if configuredFarm ~= nil then
        local color = self:getConfiguredFarmColor(configuredFarm)

        if color ~= nil then
            return color
        end
    end

    local farm = self:getFarmById(farmId)

    if farm ~= nil then
        if farm.getColor ~= nil then
            local success, color = pcall(function()
                return farm:getColor()
            end)

            if success and type(color) == "table" then
                return color
            end
        end

        if farm.color ~= nil and Farm ~= nil and type(Farm.COLORS) == "table" then
            return Farm.COLORS[farm.color]
        end
    end

    return self:parseColor(self.defaultColor)
end

function FarmIconColor:getCurrentColorForFarmId(farmId)
    local farm = self:getFarmById(farmId)

    if farm == nil then
        return nil
    end

    if farm.getColor ~= nil then
        local success, color = pcall(function()
            return farm:getColor()
        end)

        if success and type(color) == "table" then
            return color
        end
    end

    if farm.color ~= nil and Farm ~= nil and type(Farm.COLORS) == "table" then
        return Farm.COLORS[farm.color]
    end

    return nil
end

function FarmIconColor:applyFarmIconColorInElementTree(element, farmId, color, depth, maxDepth)
    if type(element) ~= "table" or depth > maxDepth then
        return 0
    end

    local changed = 0

    if self:isFarmLogoGuiElement(element) and not self:isColorPickElement(element) then
        self:prepareFarmLogoElementForCustomTexture(element, farmId)
        changed = changed + self:applyGuiImageElementColor(element, color)
    end

    if type(element.elements) == "table" then
        for _, child in ipairs(element.elements) do
            changed = changed + self:applyFarmIconColorInElementTree(child, farmId, color, depth + 1, maxDepth)
        end
    end

    return changed
end

function FarmIconColor:isFarmLogoGuiElement(element)
    if type(element) ~= "table" then
        return false
    end

    if self:isColorPickElement(element) then
        return false
    end

    if element.farmIconColorLogoName ~= nil then
        return true
    end

    if element.name == "farmIcon" then
        return true
    end

    local profile = element.profile ~= nil and tostring(element.profile) or ""

    if string.find(profile, "farmIcon", 1, true) ~= nil
        or string.find(profile, "FarmIcon", 1, true) ~= nil then
        return true
    end

    local overlay = element.overlay

    if type(overlay) == "table" and overlay.sliceId ~= nil then
        if self:isFarmLogoSliceId(overlay.sliceId) then
            return true
        end
    end

    return false
end

function FarmIconColor:applyGuiImageElementColor(element, color)
    local sourceColor = self:normalizeColorCandidate(color)

    if sourceColor == nil then
        return 0
    end

    if self:isFarmEditDialogLogoElement(element) then
    end

    local textureChanged = self:applyCustomLogoTexture(element)
    local color = self:toGuiDisplayColor(sourceColor)

    local changed = textureChanged

    if self:isFarmEditDialogLogoElement(element) then
    end

    if element.setImageColor ~= nil then
        local success = pcall(function()
            element:setImageColor(self:getGuiNormalState(), color[1], color[2], color[3], color[4] or 1)
        end)

        if not success then
            success = pcall(function()
                element:setImageColor(color)
            end)
        end

        if success then
            changed = changed + 1
        end
    end

    if element.setOverlayColor ~= nil then
        local success = pcall(function()
            element:setOverlayColor(self:getGuiNormalState(), color[1], color[2], color[3], color[4] or 1)
        end)

        if not success then
            success = pcall(function()
                element:setOverlayColor(color)
            end)
        end

        if success then
            changed = changed + 1
        end
    end




    changed = changed + self:applyGuiOverlayColor(element.overlay, color)

    if self:isFarmEditDialogLogoElement(element) then
    end

    return changed
end

function FarmIconColor:getGuiNormalState()
    if GuiOverlay ~= nil and GuiOverlay.STATE_NORMAL ~= nil then
        return GuiOverlay.STATE_NORMAL
    end

    return 1
end


function FarmIconColor:applyCustomLogoTexture(element)
    if element ~= nil and type(element) == "table" and element.farmIconColorLogoName == nil then
        element.farmIconColorLogoName = self:getDefaultCustomLogoName()
    end
    if type(element) ~= "table" then
        return 0
    end

    local logoName = self:getLogoNameFromGuiElement(element)
    local texture = logoName ~= nil and self.logos[logoName] or nil

    if texture == nil or texture == "" then
        return 0
    end

    local filename = self:resolveModTextureFilename(texture)

    if filename == nil then
        return 0
    end

    local changed = 0
    local overlay = element.overlay
    local currentFilename = nil

    if type(overlay) == "table" then
        currentFilename = overlay.filename or overlay.filenameNormal
    end

    currentFilename = currentFilename or element.imageFilename or element.filename

    local alreadyApplied = element.farmIconColorTextureFilename == filename and currentFilename == filename

    if not alreadyApplied then
        if element.setImageFilename == nil then
            if self:shouldPreserveAtlasLogoSlice(element) then
                return 0
            end

            self:prepareCustomLogoOverlayStates(element, filename)
            element.farmIconColorTextureFilename = filename
            return 0
        end

        local success, errorMessage = pcall(function()
            element:setImageFilename(filename)
        end)

        if not success then
            FarmIconColor:debugPrint(string.format("[%s] setImageFilename failed for farm logo texture=%s error=%s", self.MOD_NAME, tostring(filename), tostring(errorMessage)))
            return 0
        end
        changed = changed + 1
    end

    if self:shouldPreserveAtlasLogoSlice(element) then
        self:prepareCustomLogoFullImageUvs(element)
    else
        self:prepareCustomLogoOverlayStates(element, filename)
    end

    element.farmIconColorTextureFilename = filename

    if changed > 0 and not element.farmIconColorTextureLogged then
        element.farmIconColorTextureLogged = true
        FarmIconColor:debugPrint(string.format("[%s] Applied custom logo texture for %s: %s", self.MOD_NAME, tostring(logoName), tostring(filename)))
    end

    return changed
end

function FarmIconColor:prepareCustomLogoFullImageUvs(element)
    if type(element) ~= "table" or type(element.overlay) ~= "table" then
        return
    end

    local overlay = element.overlay
    local fullUvs = {0, 0, 0, 1, 1, 0, 1, 1}

    overlay.sliceId = nil
    overlay.uvs = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}

    if overlay.sliceIdNormal ~= nil or overlay.uvsNormal ~= nil then
        overlay.sliceIdNormal = nil
        overlay.uvsNormal = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    end

    if overlay.sliceIdFocused ~= nil or overlay.uvsFocused ~= nil then
        overlay.sliceIdFocused = nil
        overlay.uvsFocused = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    end

    if overlay.sliceIdHighlighted ~= nil or overlay.uvsHighlighted ~= nil then
        overlay.sliceIdHighlighted = nil
        overlay.uvsHighlighted = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    end

    if overlay.sliceIdDisabled ~= nil or overlay.uvsDisabled ~= nil then
        overlay.sliceIdDisabled = nil
        overlay.uvsDisabled = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    end

    if overlay.sliceIdSelected ~= nil or overlay.uvsSelected ~= nil then
        overlay.sliceIdSelected = nil
        overlay.uvsSelected = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    end

    if overlay.sliceIdPressed ~= nil or overlay.uvsPressed ~= nil then
        overlay.sliceIdPressed = nil
        overlay.uvsPressed = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    end

    if GuiOverlay ~= nil and type(GuiOverlay.OVERLAY_STATE_SUFFIXES) == "table" then
        for _, stateName in pairs(GuiOverlay.OVERLAY_STATE_SUFFIXES) do
            if overlay["sliceId" .. stateName] ~= nil or overlay["uvs" .. stateName] ~= nil then
                overlay["sliceId" .. stateName] = nil
                overlay["uvs" .. stateName] = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
            end
        end
    end
end

function FarmIconColor:shouldPreserveAtlasLogoSlice(element)
    if type(element) ~= "table" then
        return true
    end

    local profile = element.profile ~= nil and tostring(element.profile) or ""
    local name = element.name ~= nil and tostring(element.name) or ""




    if profile == "fs25_editFarmDialogFarmIcon" then
        return true
    end

    if profile == "fs25_multiplayerListItemImage" or name == "farmIcon" then
        return true
    end

    return false
end

function FarmIconColor:prepareCustomLogoOverlayStates(element, filename)
    if type(element) ~= "table" or type(element.overlay) ~= "table" or filename == nil then
        return
    end

    local overlay = element.overlay
    local fullUvs = {0, 0, 0, 1, 1, 0, 1, 1}

    overlay.farmIconColorOriginalSliceId = overlay.farmIconColorOriginalSliceId or overlay.sliceId
    element.imageFilename = filename
    element.filename = filename
    overlay.filename = filename
    overlay.sliceId = nil
    overlay.uvs = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}

    overlay.filenameNormal = filename
    overlay.filenameFocused = filename
    overlay.filenameHighlighted = filename
    overlay.filenameDisabled = filename
    overlay.filenameSelected = filename
    overlay.filenamePressed = filename
    overlay.sliceIdNormal = nil
    overlay.sliceIdFocused = nil
    overlay.sliceIdHighlighted = nil
    overlay.sliceIdDisabled = nil
    overlay.sliceIdSelected = nil
    overlay.sliceIdPressed = nil
    overlay.uvsNormal = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    overlay.uvsFocused = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    overlay.uvsHighlighted = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    overlay.uvsDisabled = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    overlay.uvsSelected = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
    overlay.uvsPressed = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}

    if GuiOverlay ~= nil and type(GuiOverlay.OVERLAY_STATE_SUFFIXES) == "table" then
        for _, stateName in pairs(GuiOverlay.OVERLAY_STATE_SUFFIXES) do
            overlay["filename" .. stateName] = filename
            overlay["sliceId" .. stateName] = nil
            overlay["uvs" .. stateName] = table.clone ~= nil and table.clone(fullUvs) or {0, 0, 0, 1, 1, 0, 1, 1}
        end
    end
end

function FarmIconColor:resolveModTextureFilename(texture)
    if texture == nil then
        return nil
    end

    local filename = tostring(texture)

    if filename == "" then
        return nil
    end

    -- Custom logos are loaded from the active savegame directory, not from the mod ZIP.
    if string.sub(filename, 1, 1) == "$"
        or string.match(filename, "^%a:[/\\]") ~= nil
        or string.sub(filename, 1, 1) == "/"
        or (self.customLogoDirectory ~= nil and string.sub(filename, 1, string.len(self.customLogoDirectory)) == self.customLogoDirectory) then
        return filename
    end

    return self.MOD_DIRECTORY .. filename
end

function FarmIconColor:applyGuiOverlayColor(overlay, color)
    if type(overlay) ~= "table" then
        return 0
    end

    local changed = 0

    if overlay.setColor ~= nil then
        local success = pcall(function()
            overlay:setColor(color[1], color[2], color[3], color[4] or 1)
        end)

        if success then
            changed = changed + 1
        end
    end

    if overlay.r ~= nil or overlay.g ~= nil or overlay.b ~= nil or overlay.a ~= nil then
        overlay.r = color[1]
        overlay.g = color[2]
        overlay.b = color[3]
        overlay.a = color[4] or 1
        changed = changed + 1
    end

    if type(overlay.color) == "table" then
        self:setColorTable(overlay.color, color)
        changed = changed + 1
    end

    return changed
end

function FarmIconColor:toGuiDisplayColor(color)
    local normalizedColor = self:normalizeColorCandidate(color)

    if normalizedColor == nil then
        return color
    end

    return {
        self:linearToSrgb(normalizedColor[1]),
        self:linearToSrgb(normalizedColor[2]),
        self:linearToSrgb(normalizedColor[3]),
        normalizedColor[4] or 1
    }
end

function FarmIconColor:linearToSrgb(value)
    value = tonumber(value) or 0

    if value <= 0 then
        return 0
    end

    if value >= 1 then
        return 1
    end

    if value <= 0.0031308 then
        return 12.92 * value
    end

    return 1.055 * math.pow(value, 1 / 2.4) - 0.055
end


function FarmIconColor:getGuiInspectorKeyCode()
    return self:getLogoSelectorKeyCode({
        "KEY_f10",
        "KEY_F10"
    })
end

function FarmIconColor:checkGuiInspectorHotkey()
    if self.GUI_INSPECTOR_ENABLED ~= true then
        return
    end

    if Input == nil or Input.isKeyPressed == nil then
        if not self.guiInspectorInputMissingLogged then
            self.guiInspectorInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] GUI inspector unavailable: Input system not found", self.MOD_NAME))
        end

        return
    end

    local keyCode = self:getGuiInspectorKeyCode()

    if keyCode == nil then
        if not self.guiInspectorInputMissingLogged then
            self.guiInspectorInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] GUI inspector unavailable: F10 key code not found", self.MOD_NAME))
        end

        return
    end

    local success, isPressed = pcall(function()
        return Input.isKeyPressed(keyCode)
    end)

    if not success then
        if not self.guiInspectorInputMissingLogged then
            self.guiInspectorInputMissingLogged = true
            FarmIconColor:debugPrint(string.format("[%s] GUI inspector unavailable: %s", self.MOD_NAME, tostring(isPressed)))
        end

        return
    end

    if isPressed and not self.guiInspectorKeyDown then
        self:debugDumpCurrentGuiInspector("F10")
    end

    self.guiInspectorKeyDown = isPressed
end

function FarmIconColor:debugDumpCurrentGuiInspector(reason)
    self.guiInspectorDumpCount = (self.guiInspectorDumpCount or 0) + 1

    FarmIconColor:debugPrint(string.format("[%s] GUI inspector dump start #%s reason=%s", self.MOD_NAME, tostring(self.guiInspectorDumpCount), tostring(reason)))

    if g_gui == nil then
        FarmIconColor:debugPrint(string.format("[%s] GUI inspector: g_gui is nil", self.MOD_NAME))
        FarmIconColor:debugPrint(string.format("[%s] GUI inspector dump end", self.MOD_NAME))
        return
    end

    FarmIconColor:debugPrint(string.format(
        "[%s] GUI inspector currentListener=%s currentGui=%s currentScreen=%s currentDialog=%s",
        self.MOD_NAME,
        self:describeGuiObject(g_gui.currentListener),
        self:describeGuiObject(g_gui.currentGui),
        self:describeGuiObject(g_gui.currentScreen),
        self:describeGuiObject(g_gui.currentDialog)
    ))

    local visitedTrees = {}

    self:debugDumpGuiObjectForInspector("currentListener", g_gui.currentListener, visitedTrees)
    self:debugDumpGuiObjectForInspector("currentGui", g_gui.currentGui, visitedTrees)
    self:debugDumpGuiObjectForInspector("currentScreen", g_gui.currentScreen, visitedTrees)
    self:debugDumpGuiObjectForInspector("currentDialog", g_gui.currentDialog, visitedTrees)

    if type(g_gui.dialogs) == "table" then
        local dialogCount = 0

        for dialogKey, dialog in pairs(g_gui.dialogs) do
            if type(dialog) == "table" and self:isDialogVisible(dialog) then
                dialogCount = dialogCount + 1
                self:debugDumpGuiObjectForInspector("dialogs[" .. tostring(dialogKey) .. "]", dialog, visitedTrees)

                if dialogCount >= 3 then
                    break
                end
            end
        end
    end

    FarmIconColor:debugPrint(string.format("[%s] GUI inspector dump end", self.MOD_NAME))
end

function FarmIconColor:debugDumpGuiObjectForInspector(label, element, visitedTrees)
    if type(element) ~= "table" then
        return
    end

    if visitedTrees[element] then
        return
    end

    visitedTrees[element] = true

    FarmIconColor:debugPrint(string.format("[%s] GUI inspector object %s: %s", self.MOD_NAME, tostring(label), self:describeGuiObject(element)))

    self:debugDumpGuiElementTree(element, tostring(label), 0, 9, 260, {})
    self:debugDumpGuiSelectorCandidates(element, tostring(label), 0, 10, 120, {})
end

function FarmIconColor:describeGuiObject(element)
    if type(element) ~= "table" then
        return tostring(element)
    end

    return string.format(
        "type=%s name=%s profile=%s text=%s visible=%s disabled=%s class=%s",
        tostring(element.typeName),
        tostring(element.name),
        tostring(element.profile),
        tostring(self:getGuiElementText(element)),
        tostring(element.visible),
        tostring(element.disabled),
        tostring(element.className or element.class or element.xmlFilename)
    )
end

function FarmIconColor:debugDumpGuiSelectorCandidates(element, path, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return remaining
    end

    if visited[element] then
        return remaining
    end

    visited[element] = true

    local text = self:getGuiElementText(element)
    local profile = element.profile ~= nil and tostring(element.profile) or ""
    local typeName = element.typeName ~= nil and tostring(element.typeName) or ""
    local name = element.name ~= nil and tostring(element.name) or ""
    local combined = string.lower(typeName .. " " .. profile .. " " .. name .. " " .. tostring(text))
    local methods = self:getGuiInspectorMethodList(element)
    local callbacks = self:getGuiInspectorCallbackList(element)
    local state = self:debugValueToString(element.state)
    local texts = self:debugValueToString(element.texts)

    local isCandidate = false

    if string.find(combined, "multi", 1, true) ~= nil
        or string.find(combined, "option", 1, true) ~= nil
        or string.find(combined, "select", 1, true) ~= nil
        or string.find(combined, "slider", 1, true) ~= nil
        or string.find(combined, "arrow", 1, true) ~= nil
        or string.find(combined, "left", 1, true) ~= nil
        or string.find(combined, "right", 1, true) ~= nil
        or string.find(combined, "button", 1, true) ~= nil
        or string.find(methods, "setState", 1, true) ~= nil
        or string.find(methods, "setTexts", 1, true) ~= nil
        or string.find(methods, "getState", 1, true) ~= nil
        or element.state ~= nil
        or element.texts ~= nil
        or callbacks ~= ""
    then
        isCandidate = true
    end

    if isCandidate then
        FarmIconColor:debugPrint(string.format(
            "[%s] GUI selector candidate path=%s depth=%d type=%s name=%s profile=%s text=%s state=%s texts=%s methods=%s callbacks=%s pos=%s abs=%s size=%s",
            self.MOD_NAME,
            tostring(path),
            tonumber(depth) or 0,
            tostring(typeName),
            tostring(name),
            tostring(profile),
            tostring(text),
            tostring(state),
            tostring(texts),
            tostring(methods),
            tostring(callbacks),
            self:debugValueToString(element.position),
            self:debugValueToString(element.absPosition),
            self:debugValueToString(element.size)
        ))

        remaining = remaining - 1
    end

    if type(element.elements) == "table" then
        for index, child in ipairs(element.elements) do
            if remaining <= 0 then
                break
            end

            remaining = self:debugDumpGuiSelectorCandidates(child, path .. ".elements[" .. tostring(index) .. "]", depth + 1, maxDepth, remaining, visited)
        end
    end

    return remaining
end

function FarmIconColor:getGuiInspectorMethodList(element)
    if type(element) ~= "table" then
        return ""
    end

    local names = {
        "setState",
        "getState",
        "setTexts",
        "setText",
        "setLabel",
        "setDisabled",
        "setVisible",
        "setPosition",
        "setSize",
        "raiseClickCallback",
        "onClick",
        "mouseEvent",
        "inputEvent",
        "onFocus",
        "onLeave"
    }

    local found = {}

    for _, methodName in ipairs(names) do
        if type(element[methodName]) == "function" then
            table.insert(found, methodName)
        end
    end

    return table.concat(found, ",")
end

function FarmIconColor:getGuiInspectorCallbackList(element)
    if type(element) ~= "table" then
        return ""
    end

    local names = {
        "onClickCallback",
        "onClickCallbackElement",
        "onEnterCallback",
        "onLeaveCallback",
        "onFocusCallback",
        "onEscCallback",
        "onChangeCallback",
        "onChangedCallback",
        "onClickAction",
        "inputActionName"
    }

    local found = {}

    for _, fieldName in ipairs(names) do
        if element[fieldName] ~= nil then
            table.insert(found, fieldName .. "=" .. tostring(element[fieldName]))
        end
    end

    return table.concat(found, ",")
end

function FarmIconColor:debugDumpActiveFarmDialogStructure()
    if self.farmDialogGuiDebugLogged == true then
        return
    end

    if not self:hasVisibleFarmEditDialog() or g_gui == nil or g_gui.currentListener == ColorPickerDialog then
        return
    end

    self.farmDialogGuiDebugLogged = true
    FarmIconColor:debugPrint(string.format("[%s] FarmEditDialog GUI debug dump start", self.MOD_NAME))

    if type(g_gui.dialogs) == "table" then
        for dialogKey, dialog in pairs(g_gui.dialogs) do
            if self:isDialogVisible(dialog) and self:isFarmEditDialogCandidate(dialog) then
                FarmIconColor:debugPrint(string.format("[%s] FarmEditDialog candidate dialogKey=%s type=%s name=%s profile=%s", self.MOD_NAME, tostring(dialogKey), tostring(dialog.typeName), tostring(dialog.name), tostring(dialog.profile)))
                self:debugDumpGuiElementTree(dialog, "dialog", 0, 6, 180, {})

                if type(dialog.target) == "table" then
                    self:debugDumpGuiElementTree(dialog.target, "target", 0, 6, 180, {})
                end
            end
        end
    end

    FarmIconColor:debugPrint(string.format("[%s] FarmEditDialog GUI debug dump end", self.MOD_NAME))
end

function FarmIconColor:debugDumpGuiElementTree(element, path, depth, maxDepth, remaining, visited)
    if remaining <= 0 or type(element) ~= "table" or depth > maxDepth then
        return remaining
    end

    if visited[element] then
        return remaining
    end

    visited[element] = true

    local text = self:getGuiElementText(element)
    local lowerText = string.lower(text or "")
    local profile = element.profile ~= nil and tostring(element.profile) or ""
    local typeName = element.typeName ~= nil and tostring(element.typeName) or ""
    local name = element.name ~= nil and tostring(element.name) or ""
    local isInteresting = lowerText ~= ""
        or profile ~= ""
        or typeName ~= ""
        or name ~= ""
        or element.position ~= nil
        or element.absPosition ~= nil

    if isInteresting then
        local pos = self:debugValueToString(element.position)
        local absPos = self:debugValueToString(element.absPosition)
        local size = self:debugValueToString(element.size)
        FarmIconColor:debugPrint(string.format(
            "[%s] GUI %s depth=%d visible=%s disabled=%s type=%s name=%s profile=%s text=%s pos=%s abs=%s size=%s",
            self.MOD_NAME, tostring(path), tonumber(depth) or 0, tostring(element.visible), tostring(element.disabled), tostring(typeName), tostring(name), tostring(profile), tostring(text), tostring(pos), tostring(absPos), tostring(size)
        ))
        remaining = remaining - 1
    end

    if type(element.elements) == "table" then
        for index, child in ipairs(element.elements) do
            if remaining <= 0 then
                break
            end

            remaining = self:debugDumpGuiElementTree(child, path .. ".elements[" .. tostring(index) .. "]", depth + 1, maxDepth, remaining, visited)
        end
    end

    return remaining
end

function FarmIconColor:debugValueToString(value)
    if type(value) ~= "table" then
        return tostring(value)
    end

    local parts = {}

    for index = 1, math.min(#value, 4) do
        table.insert(parts, tostring(value[index]))
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

function FarmIconColor:draw()
    if self.NATIVE_LOGO_SELECTOR_TEXT_OVERLAY_ENABLED == true then
        self:safeCall("drawNativeLogoSelectorTextOverlay", function()
            self:drawNativeLogoSelectorTextOverlay()
        end)
    end

    if self.LOGO_SELECTOR_OVERLAY_ENABLED ~= true then
        return
    end

    self:safeCall("drawFarmDialogLogoSelectorOverlay", function()
        self:drawFarmDialogLogoSelectorOverlay()
    end)
end

function FarmIconColor:drawNativeLogoSelectorTextOverlay()
    if not self:hasVisibleFarmEditDialog() or g_gui == nil or g_gui.currentListener == ColorPickerDialog then
        return
    end

    if renderText == nil or setTextColor == nil or setTextAlignment == nil or RenderText == nil then
        return
    end

    local selector = self.nativeLogoSelectorElement

    if type(selector) ~= "table" or selector.farmIconColorNativeLogoSelector ~= true then
        return
    end

    local leftButton, rightButton, textElement = self:getNativeLogoSelectorParts(selector)




    local leftX, leftY = self:getGuiElementAbsPosition(leftButton)
    local rightX, rightY = self:getGuiElementAbsPosition(rightButton)
    local textX, textY = self:getGuiElementAbsPosition(textElement)

    local leftW = 0.021875
    local leftH = 0.03888888888888889
    local rightW = 0.021875
    local textW = 0

    if type(leftButton) == "table" and type(leftButton.size) == "table" then
        leftW = tonumber(leftButton.size[1]) or leftW
        leftH = tonumber(leftButton.size[2]) or leftH
    end

    if type(rightButton) == "table" and type(rightButton.size) == "table" then
        rightW = tonumber(rightButton.size[1]) or rightW
    end

    if type(textElement) == "table" and type(textElement.size) == "table" then
        textW = tonumber(textElement.size[1]) or 0
    end

    local drawX = nil
    local drawY = nil

    if leftX ~= 0 or rightX ~= 0 then
        drawX = (leftX + leftW + rightX) * 0.50
        drawY = leftY + leftH * 0.50
    elseif textW > 0 then
        drawX = textX + textW * 0.50
        drawY = textY + leftH * 0.50
    else
        return
    end

    if not self:shouldShowLogoSelectorText() then
        return
    end

    local logoName = self:getActiveFarmDialogLogoName()
    local displayName = self:getLogoDisplayName(logoName)
    local textSize = self.NATIVE_LOGO_SELECTOR_TEXT_OVERLAY_SIZE or 0.0105

    if setTextBold ~= nil then
        setTextBold(true)
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_CENTER)

    if setTextVerticalAlignment ~= nil and RenderText.VERTICAL_ALIGN_MIDDLE ~= nil then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        renderText(drawX, drawY, textSize, tostring(displayName))
    else


        renderText(drawX, drawY - textSize * 0.45, textSize, tostring(displayName))
    end

    if setTextBold ~= nil then
        setTextBold(false)
    end

    if setTextVerticalAlignment ~= nil and RenderText.VERTICAL_ALIGN_BASELINE ~= nil then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

function FarmIconColor:drawFarmDialogLogoSelectorOverlay()
    if not self:hasVisibleFarmEditDialog() or g_gui == nil or g_gui.currentListener == ColorPickerDialog then
        return
    end

    if drawFilledRect == nil or renderText == nil or setTextColor == nil or setTextAlignment == nil or RenderText == nil then
        if not self.logoSelectorOverlayMissingFunctionsLogged then
            self.logoSelectorOverlayMissingFunctionsLogged = true
            FarmIconColor:debugPrint(string.format("[%s] Logo selector overlay unavailable: missing draw/text engine functions", self.MOD_NAME))
        end

        return
    end

    local selectorTitle = self:getTranslatedText("farmIconColor_logoSelector", "Logo de la ferme")
    local logoName = self:getActiveFarmDialogLogoName()
    local displayName = self:getLogoDisplayName(logoName)
    local showSelectorText = self:shouldShowLogoSelectorText()

    local boxX = self.LOGO_SELECTOR_OVERLAY_BOX_X
    local boxY = self.LOGO_SELECTOR_OVERLAY_BOX_Y
    local boxW = self.LOGO_SELECTOR_OVERLAY_BOX_W
    local boxH = self.LOGO_SELECTOR_OVERLAY_BOX_H
    local buttonW = self.LOGO_SELECTOR_OVERLAY_BUTTON_W

    local pixelX = 0.0007
    local pixelY = 0.0012

    if g_screenWidth ~= nil and g_screenWidth > 0 then
        pixelX = 1 / g_screenWidth
    end

    if g_screenHeight ~= nil and g_screenHeight > 0 then
        pixelY = 1 / g_screenHeight
    end


    drawFilledRect(boxX, boxY, boxW, boxH, 0.11, 0.11, 0.11, 0.96)


    drawFilledRect(boxX, boxY, buttonW, boxH, 0.08, 0.08, 0.08, 0.98)
    drawFilledRect(boxX + boxW - buttonW, boxY, buttonW, boxH, 0.08, 0.08, 0.08, 0.98)


    drawFilledRect(boxX, boxY, boxW, pixelY, 0.55, 0.78, 0.00, 1.00)
    drawFilledRect(boxX, boxY + boxH - pixelY, boxW, pixelY, 0.55, 0.78, 0.00, 1.00)
    drawFilledRect(boxX, boxY, pixelX, boxH, 0.55, 0.78, 0.00, 1.00)
    drawFilledRect(boxX + boxW - pixelX, boxY, pixelX, boxH, 0.55, 0.78, 0.00, 1.00)

    if setTextBold ~= nil then
        setTextBold(true)
    end


    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)

    if setTextVerticalAlignment ~= nil and RenderText.VERTICAL_ALIGN_MIDDLE ~= nil then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    end

    renderText(
        self.LOGO_SELECTOR_OVERLAY_LABEL_X,
        boxY + boxH * 0.50,
        self.LOGO_SELECTOR_OVERLAY_LABEL_SIZE,
        tostring(selectorTitle) .. " :"
    )


    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)

    renderText(boxX + buttonW * 0.50, boxY + boxH * 0.50, self.LOGO_SELECTOR_OVERLAY_TEXT_SIZE, "<")
    renderText(boxX + boxW - buttonW * 0.50, boxY + boxH * 0.50, self.LOGO_SELECTOR_OVERLAY_TEXT_SIZE, ">")

    if showSelectorText then
        renderText(boxX + boxW * 0.50, boxY + boxH * 0.50, self.LOGO_SELECTOR_OVERLAY_TEXT_SIZE, tostring(displayName))
    end


    if setTextBold ~= nil then
        setTextBold(false)
    end

    if setTextVerticalAlignment ~= nil and RenderText.VERTICAL_ALIGN_BASELINE ~= nil then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)

    if not self.logoSelectorOverlayLogged then
        self.logoSelectorOverlayLogged = true
        FarmIconColor:debugPrint(string.format("[%s] Drawing farm logo selector overlay", self.MOD_NAME))
    end
end


FarmIconColorSyncEvent = {}
local FarmIconColorSyncEvent_mt = Class(FarmIconColorSyncEvent, Event)
InitEventClass(FarmIconColorSyncEvent, "FarmIconColorSyncEvent")

function FarmIconColorSyncEvent.emptyNew()
    local self = Event.new(FarmIconColorSyncEvent_mt)
    return self
end

function FarmIconColorSyncEvent.new(farmId, colorText, logoName)
    local self = FarmIconColorSyncEvent.emptyNew()
    self.farmId = tostring(farmId or "")
    self.colorText = tostring(colorText or "")
    self.logoName = tostring(logoName or "")
    return self
end

function FarmIconColorSyncEvent:readStream(streamId, connection)
    self.farmId = streamReadString(streamId)
    self.colorText = streamReadString(streamId)
    self.logoName = streamReadString(streamId)
    self:run(connection)
end

function FarmIconColorSyncEvent:writeStream(streamId, connection)
    streamWriteString(streamId, tostring(self.farmId or ""))
    streamWriteString(streamId, tostring(self.colorText or ""))
    streamWriteString(streamId, tostring(self.logoName or ""))
end

function FarmIconColorSyncEvent:run(connection)
    if FarmIconColor ~= nil then
        local farmId = tonumber(self.farmId) or self.farmId
        FarmIconColor:applyNetworkFarmVisual(farmId, self.colorText, self.logoName, "network event")




        if connection ~= nil and connection.getIsServer ~= nil and not connection:getIsServer() and g_server ~= nil then
            g_server:broadcastEvent(FarmIconColorSyncEvent.new(self.farmId, self.colorText, self.logoName), nil, connection, nil)
        end
    end
end


-- Custom logo source files live in modSettings/FS25_farmIconColor/customLogos.
-- Do not mirror this folder into savegameX/tempsavegame: dedicated-server providers
-- can filter arbitrary nested savegame folders. Imported logo persistence is handled
-- separately through the mod-owned save data channel.

addModEventListener(FarmIconColor)
