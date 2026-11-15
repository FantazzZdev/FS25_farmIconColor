-- FS25_farmIconColor - DIAGNOSTIC (TEST BUILD ONLY, never shipped to ModHub)
-- Writes "[FIC-DIAG]" lines in log.txt about the farm dialog button row and the
-- custom logo import. Loaded only by the test ZIP (tools/build-diag.sh).

local DIAG = {frames = 0, dumpedAt = nil, lastBox = nil}

local function log(fmt, ...)
    Logging.info("[FIC-DIAG] " .. fmt, ...)
end

local function fmtVec(v)
    if type(v) ~= "table" then
        return tostring(v)
    end

    return string.format("%.4f,%.4f", tonumber(v[1]) or -1, tonumber(v[2]) or -1)
end

local function describeOverlay(element)
    local o = element.overlay

    if type(o) ~= "table" then
        return "overlay=nil"
    end

    local c = o.color
    local colorText = type(c) == "table" and string.format("%.2f,%.2f,%.2f,%.2f", c[1] or -1, c[2] or -1, c[3] or -1, c[4] or -1) or tostring(c)

    return string.format("file=%s slice=%s color=%s", tostring(o.filename), tostring(o.sliceId), colorText)
end

local function dumpBox(box, label)
    log("---- %s: box=%s profile=%s elements=%d", label, tostring(box.typeName), tostring(box.profile), #box.elements)

    for index, e in ipairs(box.elements) do
        log("  #%d type=%s profile=%s text=%s visible=%s alpha=%s disabled=%s ignoreLayout=%s pos=%s size=%s ficSep=%s ficBtn=%s %s",
            index, tostring(e.typeName), tostring(e.profile), tostring(e.text), tostring(e.visible), tostring(e.alpha),
            tostring(e.disabled), tostring(e.ignoreLayout), fmtVec(e.absPosition), fmtVec(e.absSize),
            tostring(e.farmIconColorFooterSeparator), tostring(e.farmIconColorLogoPickerButton), describeOverlay(e))
    end
end

-- Button row: dump right after the Logos button is placed, then 60 frames later.
local originalPlace = FarmIconColorLogoPicker.placeInFooterLayout
FarmIconColorLogoPicker.placeInFooterLayout = function(self, button, colorButton)
    local result = originalPlace(self, button, colorButton)
    local box = colorButton.parent

    if type(box) == "table" and type(box.elements) == "table" then
        if DIAG.lastBox ~= box then
            DIAG.lastBox = box
            DIAG.frames = 0
            log("placeInFooterLayout result=%s colorParent=%s invalidateLayout=%s", tostring(result), tostring(box.typeName), tostring(box.invalidateLayout ~= nil))
            dumpBox(box, "first frame")
        end

        DIAG.frames = DIAG.frames + 1

        if DIAG.frames == 60 then
            dumpBox(box, "60 frames later")
        end
    end

    return result
end

-- Import chain.
local D = FarmIconColorLogoPickerDialog
local originalClickImport = D.onClickImport
D.onClickImport = function(self, ...)
    log("onClickImport clicked admin=%s", tostring(FarmIconColor:isCurrentUserFarmIconAdmin()))
    return originalClickImport(self, ...)
end

local originalImport = FarmIconColor.importCustomLogosFromFolder
FarmIconColor.importCustomLogosFromFolder = function(self, ...)
    log("importCustomLogosFromFolder start dir=%s logos=%d", tostring(self.customLogoDirectory), #(self.logoOrder or {}))
    local result = originalImport(self, ...)
    log("importCustomLogosFromFolder end result=%s logos=%d", tostring(result), #(self.logoOrder or {}))
    return result
end

local originalRegister = FarmIconColor.registerCustomLogoFile
FarmIconColor.registerCustomLogoFile = function(self, filename, ...)
    local result = originalRegister(self, filename, ...)
    log("  .dds %s -> registered=%s", tostring(filename), tostring(result))
    return result
end

local LS = FarmIconColorLogoSync
local originalRead = LS.readPackage
LS.readPackage = function(self, path, filename)
    local entry, info = originalRead(self, path, filename)
    log("  .xml %s -> %s", tostring(filename), entry ~= nil and ("new id=" .. tostring(entry.id) .. " tintable=" .. tostring(entry.tintable)) or tostring(info))
    return entry, info
end

local originalPublish = LS.publishEntry
LS.publishEntry = function(self, entry, decoded)
    log("  publishEntry id=%s server=%s", tostring(entry.id), tostring(g_server ~= nil))
    return originalPublish(self, entry, decoded)
end

log("diagnostic loaded")
