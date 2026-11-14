-- ============================================================================
-- FS25_farmIconColor - Visual logo picker (grid of thumbnails)
-- ============================================================================
-- Opened from the farm create/edit dialog:
--   - "Logos" footer button (key L), or a click on the big logo preview.
-- One long page, 4 logos per row, mouse wheel / arrows to scroll, click to
-- select, double-click / Enter / "Confirm" to apply, Esc / "Cancel" to close.
--
-- Drawn on top of the farm dialog by wrapping that dialog's draw(), so no GUI
-- XML/profile is needed. While open, the dialog's mouse and menu input are
-- consumed by the picker. The left/right arrows of the dialog keep working.
-- ============================================================================

FarmIconColorLogoPicker = {}
local P = FarmIconColorLogoPicker

P.ACTION_NAME = "FARMICONCOLOR_OPEN_LOGO_PICKER"
P.COLUMNS = 4
P.PANEL_W = 0.40
P.PANEL_H = 0.72
P.HEADER_H = 0.065
P.FOOTER_H = 0.075
P.PAD_X = 0.014
P.SCROLLBAR_W = 0.005
P.LABEL_H = 0.026
P.ROW_GAP = 0.008
P.TEXT_SIZE = 0.0125
P.TITLE_SIZE = 0.020
P.BUTTON_W = 0.085
P.BUTTON_H = 0.040
P.DOUBLE_CLICK_MS = 400
P.ACCENT = {0.56, 0.78, 0.10, 1}

-- ----------------------------------------------------------------- helpers ---

local function inside(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local function rect(x, y, w, h, color)
    drawFilledRect(x, y, w, h, color[1], color[2], color[3], color[4] or 1)
end

local function text(x, y, size, value, color, align, bold)
    setTextAlignment(align or RenderText.ALIGN_LEFT)
    setTextColor(color[1], color[2], color[3], color[4] or 1)
    if setTextBold ~= nil then
        setTextBold(bold == true)
    end
    renderText(x, y, size, value)
    if setTextBold ~= nil then
        setTextBold(false)
    end
end

local function fitText(value, size, maxWidth)
    value = tostring(value or "")

    if getTextWidth == nil or getTextWidth(size, value) <= maxWidth then
        return value
    end

    while #value > 1 and getTextWidth(size, value .. "...") > maxWidth do
        value = string.sub(value, 1, -2)
    end

    return value .. "..."
end

function P:getTime()
    if g_time ~= nil then
        return g_time
    end

    return (self.clock or 0)
end

-- ------------------------------------------------------------------ layout ---

function P:computeLayout()
    local aspect = g_screenAspectRatio or (16 / 9)
    local L = {}

    L.x = 0.5 - self.PANEL_W / 2
    L.y = 0.5 - self.PANEL_H / 2
    L.w = self.PANEL_W
    L.h = self.PANEL_H
    L.gridX = L.x + self.PAD_X
    L.gridW = L.w - 2 * self.PAD_X - self.SCROLLBAR_W - 0.006
    L.gridTop = L.y + L.h - self.HEADER_H
    L.gridBottom = L.y + self.FOOTER_H
    L.cellW = L.gridW / self.COLUMNS
    L.tileW = L.cellW * 0.66
    L.tileH = L.tileW * aspect               -- square in pixels
    L.rowH = L.tileH + self.LABEL_H + self.ROW_GAP
    L.visibleRows = math.max(1, math.floor((L.gridTop - L.gridBottom) / L.rowH))
    L.rows = math.max(1, math.ceil(#self.logos / self.COLUMNS))
    L.maxScroll = math.max(0, L.rows - L.visibleRows)

    -- vertically centre the visible rows in the grid area
    L.gridTop = L.gridTop - ((L.gridTop - L.gridBottom) - L.visibleRows * L.rowH) / 2

    L.confirmX = L.x + L.w - self.PAD_X - self.BUTTON_W
    L.cancelX = L.confirmX - 0.008 - self.BUTTON_W
    L.buttonY = L.y + (self.FOOTER_H - self.BUTTON_H) / 2
    L.scrollX = L.x + L.w - self.PAD_X - self.SCROLLBAR_W

    self.layout = L
    return L
end

-- Cell rectangle of logo index (1-based), or nil when scrolled out of view.
function P:getCell(index)
    local L = self.layout
    local row = math.floor((index - 1) / self.COLUMNS) - self.scrollRow
    local col = (index - 1) % self.COLUMNS

    if row < 0 or row >= L.visibleRows then
        return nil
    end

    local cellX = L.gridX + col * L.cellW
    local cellTop = L.gridTop - row * L.rowH
    local cell = {x = cellX, y = cellTop - L.rowH, w = L.cellW, h = L.rowH}
    cell.tileX = cellX + (L.cellW - L.tileW) / 2
    cell.tileY = cellTop - 0.004 - L.tileH
    cell.labelY = cell.tileY - self.LABEL_H * 0.75

    return cell
end

function P:getIndexAt(posX, posY)
    for index = 1, #self.logos do
        local cell = self:getCell(index)

        if cell ~= nil and inside(posX, posY, cell.x, cell.y, cell.w, cell.h) then
            return index
        end
    end

    return nil
end

function P:scrollTo(index)
    if index == nil then
        return
    end

    local row = math.floor((index - 1) / self.COLUMNS)
    local L = self.layout

    if row < self.scrollRow then
        self.scrollRow = row
    elseif row >= self.scrollRow + L.visibleRows then
        self.scrollRow = row - L.visibleRows + 1
    end

    self.scrollRow = math.max(0, math.min(L.maxScroll, self.scrollRow))
end

function P:scrollBy(rows)
    self.scrollRow = math.max(0, math.min(self.layout.maxScroll, self.scrollRow + rows))
end

-- -------------------------------------------------------------- open/close ---

function P:getFarmDisplayColor()
    local fic = FarmIconColor
    local farmId = fic:getActiveFarmDialogFarmId()
    local color = nil

    if fic:isValidFarmId(farmId) then
        color = fic:getRuntimeFarmColor(farmId) or fic:getCurrentColorForFarmId(farmId)
    else
        color = fic.pendingFarmCreationColor
    end

    return fic:toGuiDisplayColor(color or {1, 1, 1, 1}) or {1, 1, 1, 1}
end

function P:open(dialog)
    local fic = FarmIconColor

    if self.isOpen or type(dialog) ~= "table" or createImageOverlay == nil or drawFilledRect == nil then
        return false
    end

    fic:ensureSelectableLogos()
    self.logos = {}
    self.overlays = {}

    for _, logoName in ipairs(fic.logoOrder or {}) do
        local texture = fic.logos[logoName]
        local filename = texture ~= nil and fic:resolveModTextureFilename(texture) or nil

        if filename ~= nil then
            local ok, overlayId = pcall(createImageOverlay, filename)

            if ok and overlayId ~= nil and overlayId ~= 0 then
                table.insert(self.logos, logoName)
                self.overlays[logoName] = overlayId
            end
        end
    end

    if #self.logos == 0 then
        return false
    end

    self.isOpen = true
    self.dialog = dialog
    self.scrollRow = 0
    self.hoverIndex = nil
    self.pressedTarget = nil
    self.lastClickIndex = nil
    self.lastClickTime = -10000
    self.tint = self:getFarmDisplayColor()
    self.keyStates = {}

    local current = fic:getActiveFarmDialogLogoName()
    self.selectedIndex = 1

    for index, logoName in ipairs(self.logos) do
        if logoName == current then
            self.selectedIndex = index
        end
    end

    self:computeLayout()
    self:scrollTo(self.selectedIndex)
    self:installInputAndDrawHooks(dialog)

    return true
end

function P:close(apply)
    if not self.isOpen then
        return
    end

    local logoName = self.logos[self.selectedIndex]

    self:removeInputAndDrawHooks()

    for _, overlayId in pairs(self.overlays or {}) do
        pcall(delete, overlayId)
    end

    self.overlays = {}
    self.isOpen = false
    self.dialog = nil

    if apply and logoName ~= nil then
        FarmIconColor:safeCall("apply logo from picker", function()
            FarmIconColor:setLogoInActiveFarmDialogByName(logoName)
        end)
    end
end

-- Draw on top of the farm dialog, and swallow its menu input while open.
function P:installInputAndDrawHooks(dialog)
    self.hooks = {}

    local function hook(object, field, wrapper)
        if type(object) ~= "table" or type(object[field]) ~= "function" then
            return
        end

        table.insert(self.hooks, {object = object, field = field, own = rawget(object, field)})
        local base = object[field]
        object[field] = function(...)
            return wrapper(base, ...)
        end
    end

    hook(dialog, "draw", function(base, ...)
        local result = base(...)
        FarmIconColor:safeCall("draw logo picker", function()
            P:render()
        end)
        return result
    end)

    local listeners = {}
    -- pairs (not ipairs): currentListener or target can be nil.
    local candidates = {g_gui ~= nil and g_gui.currentListener or nil, dialog.target, dialog}

    for _, candidate in pairs(candidates) do
        if type(candidate) == "table" and not listeners[candidate] then
            listeners[candidate] = true
            hook(candidate, "inputEvent", function(base, object, action, value, eventUsed)
                if P.isOpen then
                    P:onMenuAction(action, value)
                    return true
                end
                return base(object, action, value, eventUsed)
            end)
        end
    end
end

function P:removeInputAndDrawHooks()
    for index = #(self.hooks or {}), 1, -1 do
        local h = self.hooks[index]
        rawset(h.object, h.field, h.own) -- nil restores the class method
    end

    self.hooks = {}
end

-- ------------------------------------------------------------------- input ---

function P:moveSelection(delta)
    local index = math.max(1, math.min(#self.logos, (self.selectedIndex or 1) + delta))
    self.selectedIndex = index
    self:scrollTo(index)
end

function P:onMenuAction(action, value)
    if InputAction == nil then
        return
    end

    if action == InputAction.MENU_ACCEPT then
        self:close(true)
    elseif action == InputAction.MENU_BACK then
        self:close(false)
    end
    -- Other menu actions (axes...) are swallowed: arrows are read in pollKeys().
end

function P:mouseEvent(posX, posY, isDown, isUp, button)
    local L = self.layout
    self.hoverIndex = self:getIndexAt(posX, posY)
    self.hoverButton = nil

    if inside(posX, posY, L.confirmX, L.buttonY, self.BUTTON_W, self.BUTTON_H) then
        self.hoverButton = "confirm"
    elseif inside(posX, posY, L.cancelX, L.buttonY, self.BUTTON_W, self.BUTTON_H) then
        self.hoverButton = "cancel"
    end

    if Input ~= nil and isDown then
        if button == Input.MOUSE_BUTTON_WHEEL_UP then
            self:scrollBy(-1)
            return
        elseif button == Input.MOUSE_BUTTON_WHEEL_DOWN then
            self:scrollBy(1)
            return
        end
    end

    if Input == nil or button ~= Input.MOUSE_BUTTON_LEFT then
        return
    end

    local target = self.hoverButton or self.hoverIndex

    if isDown then
        self.pressedTarget = target
        return
    end

    if not isUp or target == nil or target ~= self.pressedTarget then
        self.pressedTarget = nil
        return
    end

    self.pressedTarget = nil

    if target == "confirm" then
        self:close(true)
    elseif target == "cancel" then
        self:close(false)
    else
        local now = self:getTime()

        if self.lastClickIndex == target and now - self.lastClickTime <= self.DOUBLE_CLICK_MS then
            self.selectedIndex = target
            self:close(true)
            return
        end

        self.selectedIndex = target
        self.lastClickIndex = target
        self.lastClickTime = now
    end
end

-- Raw keys (same approach as the rest of the mod): arrows, Enter, Esc.
function P:pollKeys()
    if Input == nil or Input.isKeyPressed == nil then
        return
    end

    local keys = {
        {Input.KEY_left, function() self:moveSelection(-1) end},
        {Input.KEY_right, function() self:moveSelection(1) end},
        {Input.KEY_up, function() self:moveSelection(-self.COLUMNS) end},
        {Input.KEY_down, function() self:moveSelection(self.COLUMNS) end},
        {Input.KEY_pageup, function() self:scrollBy(-self.layout.visibleRows) end},
        {Input.KEY_pagedown, function() self:scrollBy(self.layout.visibleRows) end}
    }

    for _, entry in ipairs(keys) do
        local keyCode = entry[1]

        if keyCode ~= nil then
            local ok, pressed = pcall(Input.isKeyPressed, keyCode)
            pressed = ok and pressed == true

            if pressed and not self.keyStates[keyCode] then
                entry[2]()
            end

            self.keyStates[keyCode] = pressed
        end
    end
end

-- -------------------------------------------------------------------- draw ---

function P:render()
    if not self.isOpen then
        return
    end

    local fic = FarmIconColor
    local L = self:computeLayout()
    self.scrollRow = math.max(0, math.min(L.maxScroll, self.scrollRow))

    -- dim the dialog behind + panel
    rect(0, 0, 1, 1, {0, 0, 0, 0.55})
    rect(L.x, L.y, L.w, L.h, {0.07, 0.07, 0.07, 0.97})
    rect(L.x, L.y + L.h - 0.003, L.w, 0.003, self.ACCENT)

    text(L.x + self.PAD_X, L.y + L.h - self.HEADER_H * 0.62, self.TITLE_SIZE,
        fic:getTranslatedText("farmIconColor_pickerTitle", "Select a logo"), {1, 1, 1, 1}, RenderText.ALIGN_LEFT, true)
    text(L.x + L.w - self.PAD_X, L.y + L.h - self.HEADER_H * 0.60, self.TEXT_SIZE,
        string.format("%d / %d", self.selectedIndex or 0, #self.logos), {0.7, 0.7, 0.7, 1}, RenderText.ALIGN_RIGHT)

    for index, logoName in ipairs(self.logos) do
        local cell = self:getCell(index)

        if cell ~= nil then
            local selected = index == self.selectedIndex
            local hovered = index == self.hoverIndex

            if selected then
                rect(cell.x + 0.002, cell.y + 0.002, cell.w - 0.004, cell.h - 0.004, {0.56, 0.78, 0.10, 0.22})
                local bx, by = 0.0015, 0.0015 * (g_screenAspectRatio or 1.78)
                rect(cell.x + 0.002, cell.y + 0.002, cell.w - 0.004, by, self.ACCENT)
                rect(cell.x + 0.002, cell.y + cell.h - 0.002 - by, cell.w - 0.004, by, self.ACCENT)
                rect(cell.x + 0.002, cell.y + 0.002, bx, cell.h - 0.004, self.ACCENT)
                rect(cell.x + cell.w - 0.002 - bx, cell.y + 0.002, bx, cell.h - 0.004, self.ACCENT)
            elseif hovered then
                rect(cell.x + 0.002, cell.y + 0.002, cell.w - 0.004, cell.h - 0.004, {1, 1, 1, 0.08})
            end

            local overlayId = self.overlays[logoName]
            if overlayId ~= nil then
                setOverlayColor(overlayId, self.tint[1], self.tint[2], self.tint[3], 1)
                renderOverlay(overlayId, cell.tileX, cell.tileY, L.tileW, L.tileH)
            end

            local label = fitText(fic:getLogoDisplayName(logoName), self.TEXT_SIZE, cell.w - 0.006)
            text(cell.x + cell.w / 2, cell.labelY, self.TEXT_SIZE, label,
                selected and self.ACCENT or {0.85, 0.85, 0.85, 1}, RenderText.ALIGN_CENTER, selected)
        end
    end

    -- scrollbar
    if L.maxScroll > 0 then
        local trackH = L.gridTop - L.gridBottom
        local thumbH = math.max(0.03, trackH * L.visibleRows / L.rows)
        local thumbY = L.gridTop - thumbH - (trackH - thumbH) * (self.scrollRow / L.maxScroll)
        rect(L.scrollX, L.gridBottom, self.SCROLLBAR_W, trackH, {1, 1, 1, 0.08})
        rect(L.scrollX, thumbY, self.SCROLLBAR_W, thumbH, {1, 1, 1, 0.45})
    end

    -- footer
    rect(L.x, L.y + self.FOOTER_H, L.w, 0.0015, {1, 1, 1, 0.10})
    text(L.x + self.PAD_X, L.y + self.FOOTER_H / 2 - self.TEXT_SIZE * 0.35, self.TEXT_SIZE * 0.95,
        fic:getTranslatedText("farmIconColor_pickerHint", "Wheel: scroll - Double-click: confirm"), {0.65, 0.65, 0.65, 1})

    for _, button in ipairs({
        {id = "cancel", x = L.cancelX, key = "farmIconColor_pickerCancel", fallback = "Cancel"},
        {id = "confirm", x = L.confirmX, key = "farmIconColor_pickerConfirm", fallback = "Confirm"}
    }) do
        local isConfirm = button.id == "confirm"
        local background = isConfirm and self.ACCENT or {0.22, 0.22, 0.22, 1}

        if self.hoverButton == button.id then
            background = isConfirm and {0.66, 0.88, 0.20, 1} or {0.32, 0.32, 0.32, 1}
        end

        rect(button.x, L.buttonY, self.BUTTON_W, self.BUTTON_H, background)
        text(button.x + self.BUTTON_W / 2, L.buttonY + self.BUTTON_H / 2 - self.TEXT_SIZE * 0.35, self.TEXT_SIZE,
            fic:getTranslatedText(button.key, button.fallback), isConfirm and {0.05, 0.05, 0.05, 1} or {1, 1, 1, 1},
            RenderText.ALIGN_CENTER, true)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

-- -------------------------------------------- farm dialog: button + clicks ---

function P:getVisibleFarmDialog()
    local fic = FarmIconColor

    if g_gui == nil or type(g_gui.dialogs) ~= "table" then
        return nil
    end

    for _, dialog in pairs(g_gui.dialogs) do
        if fic:isDialogVisible(dialog) and fic:isFarmEditDialogCandidate(dialog) then
            return dialog
        end
    end

    return nil
end

-- "Logos" footer button, cloned from the Color button like the Import button.
function P:ensureFooterButton(dialog)
    local fic = FarmIconColor
    local colorButton = fic:findFarmDialogModifyButton(dialog, 0, 8, 300, {})

    if colorButton == nil and type(dialog.target) == "table" then
        colorButton = fic:findFarmDialogModifyButton(dialog.target, 0, 8, 300, {})
    end

    if colorButton == nil or type(colorButton.parent) ~= "table" then
        return nil
    end

    local button = colorButton.farmIconColorLogoPickerButtonElement

    if type(button) ~= "table" then
        if colorButton.clone == nil then
            return nil
        end

        local ok, cloned = pcall(function()
            return colorButton:clone(colorButton.parent, false, true)
        end)

        if not ok or type(cloned) ~= "table" then
            return nil
        end

        button = cloned
        colorButton.farmIconColorLogoPickerButtonElement = button
        button.farmIconColorLogoPickerButton = true
        button.farmIconColorImportButton = false
        button.farmIconColorColorPickerHooked = false
        button.name = "farmIconColorLogoPickerButton"
        button.isTriggerableByGlobalAction = false
        button.onClickCallback = function()
            P:open(P:getVisibleFarmDialog())
        end

        fic:setGuiElementText(button, fic:getTranslatedText("input_" .. self.ACTION_NAME, "Logos"))

        if button.setInputAction ~= nil then
            pcall(function()
                button:setInputAction(self.ACTION_NAME)
            end)
        else
            button.inputActionName = self.ACTION_NAME
        end
    end

    -- Left of the Import button when it is shown (admin), else left of Color.
    local anchor = colorButton
    local importButton = colorButton.farmIconColorImportButtonElement

    if type(importButton) == "table" and importButton.visible ~= false then
        anchor = importButton
    end

    fic:positionFarmDialogImportButton(button, anchor)
    fic:ensureFarmDialogImportButtonMouseRegistration(button)
    fic:showGuiElementWithParents(button)

    return button
end

-- Persistent mouse hook on the farm dialog: feeds the picker while open, and
-- opens it from the "Logos" button or a click on the big logo preview.
function P:hookDialogMouse(dialog)
    if dialog.farmIconColorLogoPickerMouseHooked == true or type(dialog.mouseEvent) ~= "function" then
        return
    end

    dialog.farmIconColorLogoPickerMouseHooked = true
    local previous = dialog.mouseEvent

    dialog.mouseEvent = function(guiSelf, posX, posY, isDown, isUp, button, eventUsed)
        if P.isOpen and P.dialog == guiSelf then
            FarmIconColor:safeCall("logo picker mouse", function()
                P:mouseEvent(posX, posY, isDown, isUp, button)
            end)
            return true
        end

        if Input ~= nil and button == Input.MOUSE_BUTTON_LEFT and (isDown or isUp) then
            local hit = false

            -- pairs (not ipairs): the first element can be nil.
            local targets = {guiSelf.farmIconColorLogoPickerButtonElement, FarmIconColor:getVisibleDialogPreviewLogoElement()}

            for _, element in pairs(targets) do
                if type(element) == "table" and element.visible ~= false and type(element.absPosition) == "table"
                    and type(element.size) == "table"
                    and inside(posX, posY, element.absPosition[1], element.absPosition[2], element.size[1], element.size[2]) then
                    hit = true
                end
            end

            if hit and isDown then
                guiSelf.farmIconColorLogoPickerPressed = true
                return true
            end

            if isUp then
                local wasPressed = guiSelf.farmIconColorLogoPickerPressed == true
                guiSelf.farmIconColorLogoPickerPressed = false

                if hit and wasPressed then
                    P:open(guiSelf)
                    return true
                end
            end
        end

        return previous(guiSelf, posX, posY, isDown, isUp, button, eventUsed)
    end
end

-- ----------------------------------------------------------------- update ---

function P:loadMap()
    self.isOpen = false
    self.keyStates = {}
    self.openKeyDown = false
    self.clock = 0
end

function P:deleteMap()
    self:close(false)
end

function P:update(dt)
    local fic = FarmIconColor
    self.clock = (self.clock or 0) + (dt or 0)

    if self.isOpen then
        if self.dialog == nil or not fic:isDialogVisible(self.dialog) then
            self:close(false)
            return
        end

        self:pollKeys()

        -- Keep tracking L so the key must be released before it can reopen.
        if Input ~= nil and Input.KEY_l ~= nil and Input.isKeyPressed ~= nil then
            local ok, pressed = pcall(Input.isKeyPressed, Input.KEY_l)
            self.openKeyDown = ok and pressed == true
        end

        return
    end

    if fic.applyToFarmMenuLogo ~= true or not fic:hasVisibleFarmEditDialog() then
        self.openKeyDown = false
        return
    end

    local dialog = self:getVisibleFarmDialog()

    if dialog == nil or (g_gui ~= nil and g_gui.currentListener == ColorPickerDialog) then
        return
    end

    local footerButton = self:ensureFooterButton(dialog)
    dialog.farmIconColorLogoPickerButtonElement = footerButton
    self:hookDialogMouse(dialog)

    -- Keyboard shortcut (L), ignored while typing in a text field.
    local keyCode = Input ~= nil and Input.KEY_l or nil

    if keyCode ~= nil and Input.isKeyPressed ~= nil then
        local ok, pressed = pcall(Input.isKeyPressed, keyCode)
        pressed = ok and pressed == true

        if pressed and not self.openKeyDown and not fic:isTextInputActive() then
            self:open(dialog)
        end

        self.openKeyDown = pressed
    end
end

addModEventListener(FarmIconColorLogoPicker)
