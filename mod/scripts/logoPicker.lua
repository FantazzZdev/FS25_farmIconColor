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
P.DELETE_ACTION_NAME = "FARMICONCOLOR_DELETE_LOGO"
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

    -- Show the mod keys (INSERT / DELETE) on the native buttons.
    for button, action in pairs({[self.importButton or false] = FarmIconColor.CUSTOM_LOGO_IMPORT_ACTION_NAME,
                                 [self.deleteButton or false] = P.DELETE_ACTION_NAME}) do
        if button and button.setInputAction ~= nil then
            pcall(button.setInputAction, button, action)
        end
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

    self.deleteArmedLogo = nil
    self:updateAdminButtons()

    if self.logoList == nil then
        return
    end

    self:reloadAndSelect(self.selectedIndex)

    if FocusManager ~= nil and FocusManager.setFocus ~= nil then
        pcall(function()
            FocusManager:setFocus(self.logoList)
        end)
    end
end

function D:reloadAndSelect(index)
    self.logoList:reloadData()

    if #self.logos == 0 then
        return
    end

    index = math.max(1, math.min(#self.logos, index or 1))
    self.selectedIndex = index
    pcall(function()
        if self.logoList.setSelectedItem ~= nil then
            self.logoList:setSelectedItem(1, index, true, true)
        elseif self.logoList.setSelectedIndex ~= nil then
            self.logoList:setSelectedIndex(index, true)
        end
    end)

    self:updateDeleteButton()
end

-- Import / Delete are admin only (they are hidden for other players).
function D:updateAdminButtons()
    local isAdmin = FarmIconColor:isCurrentUserFarmIconAdmin()

    for _, element in ipairs({self.importButton, self.importSeparator, self.deleteButton, self.deleteSeparator}) do
        if element ~= nil and element.setVisible ~= nil then
            element:setVisible(isAdmin)
        end
    end

    if self.buttonBox ~= nil and self.buttonBox.invalidateLayout ~= nil then
        self.buttonBox:invalidateLayout()
    end
end

-- Delete is only enabled on custom logos; the first press asks for confirmation.
function D:updateDeleteButton()
    if self.deleteButton == nil then
        return
    end

    local logoName = self.logos[self.selectedIndex]
    local deletable = FarmIconColorLogoSync ~= nil and FarmIconColorLogoSync:getDeletableKind(logoName) ~= nil

    if self.deleteArmedLogo ~= logoName then
        self.deleteArmedLogo = nil
    end

    local text = self.deleteArmedLogo ~= nil
        and FarmIconColor:getTranslatedText("farmIconColor_pickerDeleteConfirm", "Confirm delete")
        or FarmIconColor:getTranslatedText("input_" .. P.DELETE_ACTION_NAME, "Delete")

    if self.deleteButton.setText ~= nil then
        self.deleteButton:setText(text)
    end

    if self.deleteButton.setDisabled ~= nil then
        self.deleteButton:setDisabled(not deletable)
    end

    if self.buttonBox ~= nil and self.buttonBox.invalidateLayout ~= nil then
        self.buttonBox:invalidateLayout()
    end
end

-- Rebuilds the list (after an import, a deletion, or a logo received from the server).
function D:refresh()
    local current = self.logos[self.selectedIndex]
    local logos, selectedIndex = P:collectLogos(current)

    if current ~= nil and logos[selectedIndex] ~= current then
        selectedIndex = math.min(self.selectedIndex, #logos)
    end

    self.logos = logos

    if self.logoList ~= nil then
        self:reloadAndSelect(selectedIndex)
    end
end

function D:onClickImport()
    if not FarmIconColor:isCurrentUserFarmIconAdmin() then
        return false
    end

    FarmIconColor:importCustomLogosFromFolder()
    self:refresh()
    return false
end

function D:onClickDelete()
    local logoName = self.logos[self.selectedIndex]

    if logoName == nil or FarmIconColorLogoSync == nil or FarmIconColorLogoSync:getDeletableKind(logoName) == nil then
        return false
    end

    if self.deleteArmedLogo ~= logoName then
        self.deleteArmedLogo = logoName
        self:updateDeleteButton()
        return false
    end

    self.deleteArmedLogo = nil
    FarmIconColorLogoSync:deleteLogo(logoName)
    self:refresh()
    return false
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

        -- The mod multiplies logos by the farm colour: show them the same way
        -- (coloured logos keep their own colours).
        local tint = fic:isLogoTintable(logoName) and self.tint or {1, 1, 1, 1}

        if icon.setImageColor ~= nil then
            icon:setImageColor(nil, tint[1], tint[2], tint[3], 1)

            if GuiOverlay ~= nil then
                for _, state in pairs({GuiOverlay.STATE_SELECTED, GuiOverlay.STATE_FOCUSED, GuiOverlay.STATE_HIGHLIGHTED, GuiOverlay.STATE_PRESSED}) do
                    if state ~= nil then
                        icon:setImageColor(state, tint[1], tint[2], tint[3], 1)
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

    self:updateDeleteButton()
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

function P:collectLogos(current)
    local fic = FarmIconColor
    local logos = {}
    local selectedIndex = 1

    fic:ensureSelectableLogos()

    local sync = FarmIconColorLogoSync

    for _, logoName in ipairs(fic.logoOrder or {}) do
        -- On a multiplayer client, hide logos the server does not know yet:
        -- choosing one would be refused and the farm would keep its old logo.
        local usable = sync == nil or sync.isLogoUsableInMultiplayer == nil
            or sync:isLogoUsableInMultiplayer(logoName)
            or logoName == current

        if fic.logos[logoName] ~= nil and usable then
            table.insert(logos, logoName)

            if logoName == current then
                selectedIndex = #logos
            end
        end
    end

    return logos, selectedIndex
end

-- Called by FarmIconColorLogoSync when logos are added or removed.
function P:onLogosChanged()
    if self:isDialogOpen() and self.dialog ~= nil then
        self.dialog:refresh()
    end
end

function P:open()
    local fic = FarmIconColor

    if self:isDialogOpen() or not self:loadDialog() then
        return false
    end

    local logos, selectedIndex = self:collectLogos(fic:getActiveFarmDialogLogoName())

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

local function isFooterSeparator(element)
    if type(element) ~= "table" then
        return false
    end

    local profile = string.lower(tostring(element.profile or ""))

    return string.find(profile, "separator", 1, true) ~= nil
end

local function indexOfElement(elements, element)
    for index, candidate in ipairs(elements) do
        if candidate == element then
            return index
        end
    end

    return nil
end

local function detachElement(elements, element)
    local index = indexOfElement(elements, element)

    if index ~= nil then
        table.remove(elements, index)
    end
end

-- Puts the Logos button (and a cloned native separator) just before the Color
-- button inside the native button BoxLayout, so the game keeps the original
-- right-aligned footer. Returns false when the footer is not a layout.
function P:placeInFooterLayout(button, colorButton)
    local fic = FarmIconColor
    local box = colorButton.parent

    if type(box) ~= "table" or type(box.elements) ~= "table" or box.invalidateLayout == nil then
        return false
    end

    local elements = box.elements
    local changed = false
    local separator = button.farmIconColorFooterSeparator

    -- Clone a native separator only once one is actually shown (same pattern as
    -- other FS25 mods); a copy of a hidden separator is laid out but not drawn.
    if separator == nil then
        for _, element in ipairs(elements) do
            if isFooterSeparator(element) and element.clone ~= nil
                and element.farmIconColorFooterSeparator ~= true
                and element.visible ~= false
                and (element.getIsVisible == nil or element:getIsVisible()) then
                local ok, cloned = pcall(function()
                    return element:clone(box, false, true)
                end)

                if ok and type(cloned) == "table" then
                    separator = cloned
                    cloned.farmIconColorFooterSeparator = true
                    button.farmIconColorFooterSeparator = cloned

                    if cloned.setVisible ~= nil then
                        pcall(function()
                            cloned:setVisible(true)
                        end)
                    end
                end

                break
            end
        end
    end

    local colorIndex = indexOfElement(elements, colorButton)

    if colorIndex == nil then
        return false
    end

    local inOrder

    if separator ~= nil then
        inOrder = elements[colorIndex - 1] == separator and elements[colorIndex - 2] == button
    else
        inOrder = elements[colorIndex - 1] == button
    end

    if not inOrder then
        detachElement(elements, button)

        if separator ~= nil then
            detachElement(elements, separator)
        end

        colorIndex = indexOfElement(elements, colorButton) or (#elements + 1)

        if separator ~= nil then
            table.insert(elements, colorIndex, separator)
            separator.parent = box
        end

        table.insert(elements, colorIndex, button)
        button.parent = box
        changed = true
    end

    if button.layoutIgnore == true then
        button.layoutIgnore = false
        changed = true
    end

    if button.farmIconColorFooterSized ~= true then
        button.farmIconColorFooterSized = true
        local width, height = fic:getFittedFooterButtonSize(button, colorButton)

        if button.setSize ~= nil and height ~= nil then
            pcall(function()
                button:setSize(width, height)
            end)
        elseif type(button.size) == "table" then
            button.size[1] = width
        end

        changed = true
    end

    -- A separator is shown only between two visible buttons (native look).
    for index, element in ipairs(elements) do
        if isFooterSeparator(element) then
            local hasLeft, hasRight = false, false

            for i = index - 1, 1, -1 do
                local other = elements[i]

                if not isFooterSeparator(other) and type(other) == "table" and other.visible ~= false then
                    hasLeft = true
                    break
                end
            end

            for i = index + 1, #elements do
                local other = elements[i]

                if not isFooterSeparator(other) and type(other) == "table" and other.visible ~= false then
                    hasRight = true
                    break
                end
            end

            local wanted = hasLeft and hasRight

            -- Same look as a native separator: never drawn in a disabled state.
            if wanted and element.disabled == true then
                element.disabled = false

                if element.setDisabled ~= nil then
                    pcall(function()
                        element:setDisabled(false)
                    end)
                end
            end

            if (element.visible ~= false) ~= wanted then
                element.visible = wanted

                if element.setVisible ~= nil then
                    pcall(function()
                        element:setVisible(wanted)
                    end)
                end

                changed = true
            end
        end
    end

    if changed then
        pcall(function()
            box:invalidateLayout()
        end)
    end

    return true
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

    -- Native footer row: Logos | Color | Back | Confirm, laid out by the game.
    if not self:placeInFooterLayout(button, colorButton) then
        fic:positionFarmDialogImportButton(button, colorButton)
    end
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

-- INSERT / DELETE inside the dialog (mod actions are not menu actions, so the
-- native buttons only display their key; the key itself is read here).
function P:pollDialogKeys()
    if Input == nil or Input.isKeyPressed == nil or self.dialog == nil
        or not FarmIconColor:isCurrentUserFarmIconAdmin() then
        return
    end

    self.dialogKeyStates = self.dialogKeyStates or {}

    for keyCode, callback in pairs({
        [Input.KEY_insert or false] = function() self.dialog:onClickImport() end,
        [Input.KEY_delete or false] = function() self.dialog:onClickDelete() end
    }) do
        if keyCode then
            local ok, pressed = pcall(Input.isKeyPressed, keyCode)
            pressed = ok and pressed == true

            if pressed and not self.dialogKeyStates[keyCode] then
                FarmIconColor:safeCall("logo picker key", callback)
            end

            self.dialogKeyStates[keyCode] = pressed
        end
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
        self:pollDialogKeys()
        return
    end

    self.dialogKeyStates = {}

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
