-- ============================================================================
-- FS25_farmIconColor - Logo picker (native FS25 dialog)
-- ============================================================================
-- gui/logoPickerDialog.xml + gui/logoPickerProfiles.xml: a real FS25 dialog
-- built from native profiles (same look as the game's dialogs). It opens on
-- top of the farm create/edit dialog, like the game's colour picker:
--   - "Logos" footer button (key L), or a click on the big logo preview.
--   - Grid of 4 logos per row (native SmoothList), mouse wheel + slider.
--   - Click = select, double-click / Enter (Confirm) = apply, Esc (Back) = close.
-- The left/right arrows of the farm dialog keep working.
-- ============================================================================

FarmIconColorLogoPicker = {}
local P = FarmIconColorLogoPicker

P.DIALOG_NAME = "FarmIconColorLogoPickerDialog"
P.ACTION_NAME = "FARMICONCOLOR_OPEN_LOGO_PICKER"
P.MOD_DIRECTORY = g_currentModDirectory or ""

-- ================================================================ dialog ===

FarmIconColorLogoPickerDialog = {}
local D = FarmIconColorLogoPickerDialog
local DialogBase = MessageDialog or DialogElement
local D_mt = Class(D, DialogBase)

function D.new(target, custom_mt)
    local self = DialogBase.new(target, custom_mt or D_mt)
    self.logos = {}
    self.selectedIndex = 1
    self.tint = {1, 1, 1, 1}
    return self
end

function D:onCreate()
    if D:superClass().onCreate ~= nil then
        D:superClass().onCreate(self)
    end

    if self.logoList ~= nil then
        self.logoList:setDataSource(self)
        self.logoList:setDelegate(self)
    end
end

-- Called by P.open() before showDialog.
function D:setData(logos, selectedIndex, tint)
    self.logos = logos or {}
    self.selectedIndex = math.max(1, math.min(#self.logos, selectedIndex or 1))
    self.tint = tint or {1, 1, 1, 1}
end

function D:onOpen()
    D:superClass().onOpen(self)

    if self.logoList == nil then
        return
    end

    self.logoList:reloadData()

    local index = self.selectedIndex
    pcall(function()
        if self.logoList.setSelectedItem ~= nil then
            self.logoList:setSelectedItem(1, index, true, true)
        elseif self.logoList.setSelectedIndex ~= nil then
            self.logoList:setSelectedIndex(index, true)
        end
    end)

    if FocusManager ~= nil and FocusManager.setFocus ~= nil then
        pcall(function()
            FocusManager:setFocus(self.logoList)
        end)
    end
end

function D:getNumberOfItemsInSection(list, section)
    return #self.logos
end

local function getCellChild(cell, name)
    if cell.getAttribute ~= nil then
        local ok, element = pcall(cell.getAttribute, cell, name)
        if ok and element ~= nil then
            return element
        end
    end

    return cell.attributes ~= nil and cell.attributes[name] or nil
end

function D:populateCellForItemInSection(list, section, index, cell)
    local fic = FarmIconColor
    local logoName = self.logos[index]

    if logoName == nil then
        return
    end

    local icon = getCellChild(cell, "icon")
    local texture = fic.logos[logoName]
    local filename = texture ~= nil and fic:resolveModTextureFilename(texture) or nil

    if icon ~= nil and filename ~= nil then
        if icon.setImageFilename ~= nil then
            icon:setImageFilename(filename)
        end

        -- The mod multiplies logos by the farm colour: show them the same way.
        if icon.setImageColor ~= nil then
            icon:setImageColor(nil, self.tint[1], self.tint[2], self.tint[3], 1)

            if GuiOverlay ~= nil then
                for _, state in pairs({GuiOverlay.STATE_SELECTED, GuiOverlay.STATE_FOCUSED, GuiOverlay.STATE_HIGHLIGHTED, GuiOverlay.STATE_PRESSED}) do
                    if state ~= nil then
                        icon:setImageColor(state, self.tint[1], self.tint[2], self.tint[3], 1)
                    end
                end
            end
        end
    end

    local title = getCellChild(cell, "title")

    if title ~= nil and title.setText ~= nil then
        title:setText(fic:getLogoDisplayName(logoName))
    end
end

function D:onListSelectionChanged(list, section, index)
    if index ~= nil and index > 0 then
        self.selectedIndex = index
    end
end

function D:getSelectedLogo()
    if self.logoList ~= nil and self.logoList.getSelectedIndexInSection ~= nil then
        local ok, index = pcall(self.logoList.getSelectedIndexInSection, self.logoList)

        if ok and index ~= nil and index > 0 then
            self.selectedIndex = index
        end
    end

    return self.logos[self.selectedIndex]
end

function D:onDoubleClickLogo(list, section, index)
    self:applyAndClose(index ~= nil and self.logos[index] or self:getSelectedLogo())
end

function D:onClickOk()
    self:applyAndClose(self:getSelectedLogo())
    return false
end

function D:applyAndClose(logoName)
    self:close()

    if logoName ~= nil then
        FarmIconColor:safeCall("apply logo from picker", function()
            FarmIconColor:setLogoInActiveFarmDialogByName(logoName)
        end)
    end
end

function D:onClickBack(forceBack, usedMenuButton)
    self:close()
    return false
end

-- ================================================================ opener ===

function P:loadDialog()
    if g_gui == nil or self.dialog ~= nil then
        return self.dialog ~= nil
    end

    if g_gui.guis ~= nil and g_gui.guis[self.DIALOG_NAME] ~= nil and D.INSTANCE ~= nil then
        self.dialog = D.INSTANCE
        return true
    end

    local ok, result = pcall(function()
        g_gui:loadProfiles(self.MOD_DIRECTORY .. "gui/logoPickerProfiles.xml")
        local instance = D.new()
        local gui = g_gui:loadGui(self.MOD_DIRECTORY .. "gui/logoPickerDialog.xml", self.DIALOG_NAME, instance)
        return gui ~= nil and instance or nil
    end)

    if ok and result ~= nil then
        D.INSTANCE = result
        self.dialog = result
        return true
    end

    if not self.loadErrorLogged and Logging ~= nil and Logging.warning ~= nil then
        self.loadErrorLogged = true
        Logging.warning("[FS25_farmIconColor] Logo picker dialog could not be loaded: %s", tostring(result))
    end

    return false
end

function P:isDialogOpen()
    local gui = g_gui ~= nil and g_gui.guis ~= nil and g_gui.guis[self.DIALOG_NAME] or nil

    if gui == nil or type(g_gui.dialogs) ~= "table" then
        return false
    end

    for _, dialog in ipairs(g_gui.dialogs) do
        if dialog == gui then
            return true
        end
    end

    return false
end

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

function P:open()
    local fic = FarmIconColor

    if self:isDialogOpen() or not self:loadDialog() then
        return false
    end

    fic:ensureSelectableLogos()

    local logos = {}
    local current = fic:getActiveFarmDialogLogoName()
    local selectedIndex = 1

    for _, logoName in ipairs(fic.logoOrder or {}) do
        if fic.logos[logoName] ~= nil then
            table.insert(logos, logoName)

            if logoName == current then
                selectedIndex = #logos
            end
        end
    end

    if #logos == 0 then
        return false
    end

    self.dialog:setData(logos, selectedIndex, self:getFarmDisplayColor())
    g_gui:showDialog(self.DIALOG_NAME)

    return true
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

-- Places the "Logos" button left of its anchor, a bit narrower than the native
-- buttons so that it stays inside the dialog footer.
function P:positionFooterButton(button, anchor)
    if type(anchor.position) ~= "table" or type(anchor.size) ~= "table" then
        return
    end

    local anchorWidth = tonumber(anchor.size[1]) or 0.1
    local height = tonumber(anchor.size[2])
    local width = anchorWidth * 0.62
    local x = (tonumber(anchor.position[1]) or 0) - width - 0.004
    local y = tonumber(anchor.position[2]) or 0

    button.layoutIgnore = true

    if button.setSize ~= nil and height ~= nil then
        pcall(function()
            button:setSize(width, height)
        end)
    end

    if button.setPosition ~= nil then
        pcall(function()
            button:setPosition(x, y)
        end)
    end

    if button.updateAbsolutePosition ~= nil then
        pcall(function()
            button:updateAbsolutePosition()
        end)
    end
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
            P:open()
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

    self:positionFooterButton(button, anchor)
    fic:ensureFarmDialogImportButtonMouseRegistration(button)
    fic:showGuiElementWithParents(button)

    return button
end

local function isInside(element, posX, posY)
    return type(element) == "table" and element.visible ~= false
        and type(element.absPosition) == "table" and type(element.size) == "table"
        and posX >= element.absPosition[1] and posX <= element.absPosition[1] + element.size[1]
        and posY >= element.absPosition[2] and posY <= element.absPosition[2] + element.size[2]
end

-- Persistent mouse hook on the farm dialog: opens the picker from the "Logos"
-- button or a click on the big logo preview.
function P:hookFarmDialogMouse(dialog)
    if dialog.farmIconColorLogoPickerMouseHooked == true or type(dialog.mouseEvent) ~= "function" then
        return
    end

    dialog.farmIconColorLogoPickerMouseHooked = true
    local previous = dialog.mouseEvent

    dialog.mouseEvent = function(guiSelf, posX, posY, isDown, isUp, button, eventUsed)
        if Input ~= nil and button == Input.MOUSE_BUTTON_LEFT and (isDown or isUp) and not P:isDialogOpen() then
            local hit = isInside(guiSelf.farmIconColorLogoPickerButtonElement, posX, posY)
                or isInside(FarmIconColor:getVisibleDialogPreviewLogoElement(), posX, posY)

            if hit and isDown then
                guiSelf.farmIconColorLogoPickerPressed = true
                return true
            end

            if isUp then
                local wasPressed = guiSelf.farmIconColorLogoPickerPressed == true
                guiSelf.farmIconColorLogoPickerPressed = false

                if hit and wasPressed then
                    P:open()
                    return true
                end
            end
        end

        return previous(guiSelf, posX, posY, isDown, isUp, button, eventUsed)
    end
end

-- -------------------------------------------------- mod listener callbacks ---
-- (only loadMap / deleteMap / update: names like mouseEvent or draw would be
-- called by the game for every mod listener)

function P:loadMap()
    self.dialog = nil
    self.openKeyDown = false
    self:loadDialog()
end

function P:deleteMap()
    if self:isDialogOpen() then
        pcall(function()
            g_gui:closeDialogByName(self.DIALOG_NAME)
        end)
    end
end

function P:update(dt)
    local fic = FarmIconColor

    if self:isDialogOpen() then
        self.openKeyDown = true -- L must be released before it can reopen
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

    dialog.farmIconColorLogoPickerButtonElement = self:ensureFooterButton(dialog)
    self:hookFarmDialogMouse(dialog)

    -- Keyboard shortcut (L), ignored while typing in a text field.
    local keyCode = Input ~= nil and Input.KEY_l or nil

    if keyCode ~= nil and Input.isKeyPressed ~= nil then
        local ok, pressed = pcall(Input.isKeyPressed, keyCode)
        pressed = ok and pressed == true

        if pressed and not self.openKeyDown and not fic:isTextInputActive() then
            self:open()
        end

        self.openKeyDown = pressed
    end
end

addModEventListener(FarmIconColorLogoPicker)
