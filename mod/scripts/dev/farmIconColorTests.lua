-- ============================================================================
-- FS25_farmIconColor - TESTS TEMPORAIRES (build de test uniquement)
-- ============================================================================
-- A RETIRER avant publication : supprimer ce fichier, le dossier dev/ et la
-- ligne correspondante dans modDesc.xml.
--
-- Declenchement : une seule fois par session, au premier Import (INSER / bouton
-- Importer) fait par l'admin dans la fenetre de modification de ferme.
--
-- TEST-A : le mod GENERE un DDS (DXT5, 256x256, 4 quadrants) et l'ecrit avec
--          createFile/fileWrite. Les donnees contiennent volontairement des
--          octets 0x00, 0x0A, 0x0D et 0x1A : si fileWrite tronque ou convertit
--          les fins de ligne, l'image sera du bruit.
-- TEST-B : le mod LIT dev/testB_tractor.xml (DDS du tracteur encode en Base64),
--          le decode, verifie la somme de controle Adler-32, puis ecrit le DDS.
--
-- Les deux logos sont ajoutes a la fin de la liste : "TEST A" et "TEST B".
-- Resultat dans log.txt : lignes [FS25_farmIconColor][TEST-A] et [TEST-B].
-- ============================================================================

FarmIconColorTests = {}
FarmIconColorTests.PREFIX = "[FS25_farmIconColor]"
FarmIconColorTests.done = false

function FarmIconColorTests.log(tag, message)
    print(string.format("%s[%s] %s", FarmIconColorTests.PREFIX, tag, tostring(message)))
end

-- ---------------------------------------------------------------- helpers ---

local function u32le(value)
    value = math.floor(tonumber(value) or 0) % 4294967296
    return string.char(value % 256, math.floor(value / 256) % 256,
        math.floor(value / 65536) % 256, math.floor(value / 16777216) % 256)
end

local function u16le(value)
    return string.char(value % 256, math.floor(value / 256) % 256)
end

function FarmIconColorTests.adler32(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + string.byte(data, i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_MAP = {}
for i = 1, 64 do
    B64_MAP[string.byte(B64_ALPHABET, i)] = i - 1
end

function FarmIconColorTests.base64Decode(text)
    text = string.gsub(text, "[^%w%+/=]", "")
    local out, n = {}, 0

    for i = 1, #text, 4 do
        local c1, c2, c3, c4 = string.byte(text, i, i + 3)
        local v1, v2 = B64_MAP[c1], B64_MAP[c2]
        if v1 == nil or v2 == nil then
            return nil, "invalid base64 at " .. tostring(i)
        end

        local v3 = c3 ~= nil and B64_MAP[c3] or nil -- '=' -> nil (padding)
        local v4 = c4 ~= nil and B64_MAP[c4] or nil
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

-- Standard 128-byte DDS header, FOURCC DXT5, one mip level.
function FarmIconColorTests.buildDxt5Header(width, height)
    local linearSize = math.floor((width + 3) / 4) * math.floor((height + 3) / 4) * 16
    local parts = {
        "DDS ", u32le(124),
        u32le(0x1 + 0x2 + 0x4 + 0x1000 + 0x80000), -- CAPS|HEIGHT|WIDTH|PIXELFORMAT|LINEARSIZE
        u32le(height), u32le(width), u32le(linearSize), u32le(0), u32le(0)
    }
    for _ = 1, 11 do
        parts[#parts + 1] = u32le(0)
    end
    parts[#parts + 1] = u32le(32)
    parts[#parts + 1] = u32le(0x4) -- DDPF_FOURCC
    parts[#parts + 1] = "DXT5"
    for _ = 1, 5 do
        parts[#parts + 1] = u32le(0)
    end
    parts[#parts + 1] = u32le(0x1000) -- DDSCAPS_TEXTURE
    for _ = 1, 4 do
        parts[#parts + 1] = u32le(0)
    end
    return table.concat(parts)
end

-- One solid 4x4 DXT5 block. In BC3 the colour block is always 4-colour mode,
-- so with color0 == color1 every index gives the same colour: the index bytes
-- can carry the "dangerous" bytes 0A 0D 1A 00 without changing the image.
local function solidDxt5Block(r, g, b, a)
    local rgb565 = math.floor(r / 8) * 2048 + math.floor(g / 4) * 32 + math.floor(b / 8)
    local alphaBlock = string.char(a, a, 0, 0, 0, 0, 0, 0)
    local colorBlock = u16le(rgb565) .. u16le(rgb565) .. "\10\13\26\0"
    return alphaBlock .. colorBlock
end

-- 256x256: top-left RED, top-right GREEN, bottom-left BLUE, bottom-right TRANSPARENT.
function FarmIconColorTests.buildQuadrantDds()
    local size = 256
    local blocksPerRow = size / 4
    local half = blocksPerRow / 2
    local red = solidDxt5Block(255, 0, 0, 255)
    local green = solidDxt5Block(0, 255, 0, 255)
    local blue = solidDxt5Block(0, 0, 255, 255)
    local clear = solidDxt5Block(0, 0, 0, 0)

    local topRow = string.rep(red, half) .. string.rep(green, half)
    local bottomRow = string.rep(blue, half) .. string.rep(clear, half)

    return FarmIconColorTests.buildDxt5Header(size, size)
        .. string.rep(topRow, half) .. string.rep(bottomRow, half)
end

function FarmIconColorTests.writeBinaryFile(path, data)
    if type(createFile) ~= "function" or type(fileWrite) ~= "function" or FileAccess == nil then
        return false, "file API unavailable"
    end

    local okOpen, handle = pcall(createFile, path, FileAccess.WRITE)
    if not okOpen or handle == nil or handle == 0 then
        return false, "createFile failed: " .. tostring(handle)
    end

    local okWrite, err = pcall(fileWrite, handle, data)
    pcall(delete, handle)

    if not okWrite then
        return false, "fileWrite error: " .. tostring(err)
    end

    if type(fileExists) == "function" and not fileExists(path) then
        return false, "file missing after write"
    end

    return true
end

function FarmIconColorTests.registerLogo(fic, logoId, displayName, path)
    fic.logos[logoId] = path
    fic.customLogoPaths = fic.customLogoPaths or {}
    fic.customLogoDisplayNames = fic.customLogoDisplayNames or {}
    fic.customLogoPaths[logoId] = path
    fic.customLogoDisplayNames[logoId] = displayName
    fic:addLogoToOrder(logoId)
end

-- ------------------------------------------------------------------ tests ---

function FarmIconColorTests.runTestA(fic, cacheDir)
    local data = FarmIconColorTests.buildQuadrantDds()
    local path = fic:joinPath(cacheDir, "test_a_quadrants.dds")
    local ok, err = FarmIconColorTests.writeBinaryFile(path, data)

    if not ok then
        FarmIconColorTests.log("TEST-A", "FAIL write: " .. tostring(err))
        return
    end

    FarmIconColorTests.registerLogo(fic, "test_a", "TEST A", path)
    FarmIconColorTests.log("TEST-A", string.format(
        "WRITTEN bytes=%d adler32=%d path=%s -> choisir le logo 'TEST A' : attendu ROUGE | VERT / BLEU | TRANSPARENT",
        #data, FarmIconColorTests.adler32(data), path))
end

function FarmIconColorTests.runTestB(fic, cacheDir)
    local xmlPath = fic.MOD_DIRECTORY .. "dev/testB_tractor.xml"
    local xmlFile = loadXMLFile("farmIconColorTestB", xmlPath)

    if xmlFile == nil or xmlFile == 0 then
        FarmIconColorTests.log("TEST-B", "FAIL cannot open " .. xmlPath)
        return
    end

    local key = "farmIconColorLogo.logo"
    local expectedBytes = getXMLInt(xmlFile, key .. "#bytes")
    local expectedB64 = getXMLInt(xmlFile, key .. "#base64Length")
    local expectedAdler = tonumber(getXMLString(xmlFile, key .. "#adler32"))
    local text = getXMLString(xmlFile, key .. ".data") or ""
    delete(xmlFile)

    local cleaned = string.gsub(text, "[^%w%+/=]", "")
    if #cleaned ~= expectedB64 then
        FarmIconColorTests.log("TEST-B", string.format(
            "FAIL XML read truncated: base64 read=%d expected=%s", #cleaned, tostring(expectedB64)))
        return
    end

    local data, decodeErr = FarmIconColorTests.base64Decode(cleaned)
    if data == nil then
        FarmIconColorTests.log("TEST-B", "FAIL decode: " .. tostring(decodeErr))
        return
    end

    local adler = FarmIconColorTests.adler32(data)
    if #data ~= expectedBytes or adler ~= expectedAdler then
        FarmIconColorTests.log("TEST-B", string.format(
            "FAIL checksum bytes=%d/%s adler32=%d/%s", #data, tostring(expectedBytes), adler, tostring(expectedAdler)))
        return
    end

    local path = fic:joinPath(cacheDir, "test_b_tractor.dds")
    local ok, err = FarmIconColorTests.writeBinaryFile(path, data)
    if not ok then
        FarmIconColorTests.log("TEST-B", "FAIL write: " .. tostring(err))
        return
    end

    FarmIconColorTests.registerLogo(fic, "test_b", "TEST B", path)
    FarmIconColorTests.log("TEST-B", string.format(
        "XML OK base64=%d bytes=%d adler32 OK, WRITTEN path=%s -> choisir le logo 'TEST B' : attendu le TRACTEUR net",
        #cleaned, #data, path))
end

function FarmIconColorTests.run(fic)
    if FarmIconColorTests.done then
        return
    end
    FarmIconColorTests.done = true

    local baseDir = fic:getModSettingsSaveDirectory()
    if baseDir == nil then
        FarmIconColorTests.log("TESTS", "FAIL modSettings directory unavailable")
        return
    end

    local cacheDir = fic:joinPath(baseDir, "cache")
    fic:ensureFolderExists(cacheDir)

    local okA, errA = pcall(FarmIconColorTests.runTestA, fic, cacheDir)
    if not okA then
        FarmIconColorTests.log("TEST-A", "FAIL lua error: " .. tostring(errA))
    end

    local okB, errB = pcall(FarmIconColorTests.runTestB, fic, cacheDir)
    if not okB then
        FarmIconColorTests.log("TEST-B", "FAIL lua error: " .. tostring(errB))
    end
end

-- Hook on the existing import, without modifying farmIconColor.lua.
if FarmIconColor ~= nil and FarmIconColor.importCustomLogosFromFolder ~= nil then
    local originalImport = FarmIconColor.importCustomLogosFromFolder

    FarmIconColor.importCustomLogosFromFolder = function(self, ...)
        local result = originalImport(self, ...)

        if self:isCurrentUserFarmIconAdmin() then
            FarmIconColorTests.run(self)
        end

        return result
    end
end
