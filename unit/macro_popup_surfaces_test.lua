local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinMacro = true
_G.UIPanelWindows, _G.StaticPopupDialogs = {}, {}
_G.CreateFromMixins = function(...) local result = {}; for _, mixin in ipairs({...}) do
    for key, value in pairs(mixin) do result[key] = value end end; return result end
_G.format = string.format
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroUI.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/Selector/Blizzard_SelectorUI.lua"))()
local file = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua"))
local source = file:read("*a"); file:close()
local native = assert(source:match("(SelectedIconButtonMixin = {};.-)SearchBoxListElementMixin"))
assert(loadstring(native, "@native-icon-selector-button-and-editbox"))()
local function frame(kind, parent)
    local widget = env.NewFrame(kind or "Frame", nil, parent)
    widget.RegisterForWidgetSet = false
    widget.DisabledTexture = false
    function widget:Enable() self.enabled = true end
    function widget:Disable() self.enabled = false end
    return widget
end
local bank = frame()
_G.GuildBankFrame = bank
bank.Columns, bank.BankTabs = {}, {}
bank.MoneyFrameBG, bank.DepositButton, bank.WithdrawButton, bank.BuyInfo = false, false, false, false
function bank:GetRight() return 1000 end
bank.Info = frame(nil, bank)
bank.Info.SaveButton = false
bank.Info.ScrollFrame = frame("ScrollFrame", bank.Info)
bank.Info.ScrollFrame.EditBox = frame("EditBox", bank.Info.ScrollFrame)
function bank.Info.ScrollFrame.EditBox:SetText(text) self.currentText = text end

local savedText = "Native multiline\nsecond line"
_G.GetGuildBankText = function() return savedText end
bank.Log = frame(nil, bank)
bank.Log.ScrollBar = false
local messages = frame("ScrollingMessageFrame", bank.Log)
bank.Log.MessageFrame, _G.GuildBankMessageFrame = messages, messages
function messages:SetFont(path, size, flags) self.nativeFont = {path, size, flags} end
function messages:GetFont() return "native-font", 12, "" end
function messages:Clear() self.messages = {} end
function messages:AddMessage(text) self.messages[#self.messages + 1] = text end
local hyperlink = function() end
messages:SetScript("OnHyperlinkClick", hyperlink)
local popup = frame(nil, bank)
_G.MacroPopupFrame = popup
popup:SetSize(525, 495)
popup:SetFrameLevel(50)
popup.BG = popup:CreateTexture()
local box = frame(nil, popup)
popup.BorderBox = box
box.art = box:CreateTexture()
box.OkayButton, box.CancelButton = frame("Button", box), frame("Button", box)
local okay = function() error("styling must not edit a guild tab") end
box.OkayButton:SetScript("OnClick", okay)
box.CancelButton:SetScript("OnClick", function() end)
box.IconSelectorEditBox = frame("EditBox", box)
local edit = box.IconSelectorEditBox
function edit:SetText(value) self.value = value end
function edit:GetText() return self.value or "" end
function edit:SetFocus() self.focused = true end
function edit:HighlightText() self.highlighted = true end
for key, value in pairs(_G.IconSelectorEditBoxMixin) do edit[key] = value end
edit:SetIconSelector(popup)
box.IconTypeDropdown = frame("DropdownButton", box)
box.SelectedIconArea = frame(nil, box)
box.SelectedIconArea.SelectedIconText = frame(nil, box.SelectedIconArea)
box.SelectedIconArea.SelectedIconText.SelectedIconDescription = box.SelectedIconArea.SelectedIconText:CreateFontString()
local description = box.SelectedIconArea.SelectedIconText.SelectedIconDescription
_G.GameFontHighlightSmall = "native-selected-font"
function description:SetFontObject(font) self:SetFont(font, 12, "") end
local masks = 0
local function iconButton(parent, mixin)
    local widget = frame("Button", parent)
    widget.Icon, widget.Highlight = widget:CreateTexture(), widget:CreateTexture()
    widget.normalTexture = widget.Icon
    widget.art = widget:CreateTexture()
    function widget.Icon:GetTexture() return self.texture end
    function widget:CreateMaskTexture() local mask = self:CreateTexture(); mask.kind = "MaskTexture"; return mask end
    function widget.Icon:AddMaskTexture() masks = masks + 1 end
    for key, value in pairs(mixin) do widget[key] = value end
    widget:SetScript("OnClick", mixin.OnClick)
    return widget
end
local selected = iconButton(box.SelectedIconArea, _G.SelectedIconButtonMixin)
box.SelectedIconArea.SelectedIconButton = selected
selected:SetIconSelector(popup)
local selector = frame(nil, popup)
popup.IconSelector = selector
for key, value in pairs(_G.SelectorMixin) do selector[key] = value end
selector.initialized = false
local rows = {}
for index = 1, 6 do
    local row = iconButton(selector, _G.SelectorButtonMixin)
    row.SelectedTexture = row:CreateTexture()
    rows[index] = row
    row:Init(selector)
    row.selectionIndex = index
end
local popupView = dofile("tests/helpers/selector_scrollbox_harness.lua")(selector, rows)
function selector:UpdateSelections() for index, row in ipairs(rows) do self:RunSetup(row, index) end end
function selector:ScrollToSelectedIndex() self.scrolled = self:GetSelectedIndex() end
selector:SetSetupCallback(function(button, index, icon) button:SetIconTexture(icon) end)
selector.ScrollBar = frame("Slider", selector)
selector.ScrollBar.ThumbTexture = selector.ScrollBar:CreateTexture()
local icons = {"icon-1", "icon-2", "icon-3", "icon-4", "icon-5", "icon-6"}
local provider = {GetIconByIndex = function(_, index) return icons[index] end, GetNumIcons = function() return #icons end}
function bank:RefreshIconList() return provider end
popup.iconDataProvider = provider
function popup:GetIndexOfIcon(icon) for index, value in ipairs(icons) do if value == icon then return index end end end
function popup:GetIconByIndex(index) return icons[index] end
function popup:SetIconFilter(filter) self.filter = filter end
function popup:SetSelectedIconText() self.descriptionUpdated = true end
_G.GenerateClosure = function(fn, context) return function(...) return fn(context, ...) end end
local width = 1600
_G.GetScreenWidth = function() return width end
_G.GetCurrentGuildBankTab = function() return 1 end
_G.GetGuildBankTabInfo = function() return "Native tab", "icon-3" end
_G.IconSelectorPopupFrameTemplateMixin = {OnShow = function(self) self.nativeShowCalls = (self.nativeShowCalls or 0) + 1 end}
_G.IconSelectorPopupFrameIconFilterTypes = {All = 1}
_G.ICON_SELECTION_CLICK = "Native selected"
_G.SOUNDKIT, _G.PlaySound = {}, function() end



assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroIconSelector.lua"))()
local macro = bank
macro:SetWidth(338)
macro.Inset = false
_G.MacroFrame = macro
macro.macroBase, macro.macroMax = 0, 3
_G.MacroFrameText = frame("EditBox", macro)
function _G.MacroFrameText:SetFocus() self.focused = true end
_G.MacroFrameTextBackground = frame(nil, macro)
_G.MacroFrameSelectedMacroBackground = macro:CreateTexture()
_G.MacroFrameSelectedMacroName, _G.MacroFrameEnterMacroText, _G.MacroFrameCharLimitText =
    macro:CreateFontString(), macro:CreateFontString(), macro:CreateFontString()
local writes = 0
_G.CreateMacro, _G.EditMacro, _G.DeleteMacro = function() writes = writes + 1 end, function() writes = writes + 1 end, function() writes = writes + 1 end
local mainActions = {}
for _, name in ipairs({"MacroEditButton", "MacroCancelButton", "MacroSaveButton", "MacroDeleteButton", "MacroNewButton", "MacroExitButton",
    "MacroFrameTab1", "MacroFrameTab2"}) do
    local widget = frame("Button", macro)
    widget.Text = widget:CreateFontString()
    widget.Text:SetText(name)
    function widget:SetEnabled(value) self.enabled = value and true or false end
    widget:SetScript("OnClick", function() error("styling must not edit macros or switch native tabs") end)
    _G[name] = widget
    mainActions[widget] = widget:GetScript("OnClick")
end
_G.PanelTemplates_UpdateTabs = function() _G.MacroFrameTab1:Enable(); _G.MacroFrameTab2:Enable() end
_G.IconSelectorPopupFrameTemplateMixin.OnHide = function(self) self.nativeHideCalls = (self.nativeHideCalls or 0) + 1 end
_G.IconSelectorPopupFrameModes = {New = 1, Edit = 2}
local accountCount, characterCount = 1, 1
_G.GetNumMacros = function() return accountCount, characterCount end
_G.InClickBindingMode = function() return false end
local macroSelector = frame(nil, macro)
macro.MacroSelector = macroSelector
for key, value in pairs(_G.SelectorMixin) do macroSelector[key] = value end
macroSelector.initialized, macroSelector.numMacros = false, 1
local macroRows = {}
for index = 1, 4 do
    local row = iconButton(macroSelector, _G.SelectorButtonMixin)
    row.SelectedTexture, row.Name = row:CreateTexture(), row:CreateFontString()
    row.Name:SetText("Native macro " .. index)
    row:Init(macroSelector); row.selectionIndex = index
    row:SetIconTexture("macro-art-" .. index)
    row:SetScript("OnDragStart", _G.MacroButtonMixin.OnDragStart)
    macroRows[index] = row
end
local macroView = dofile("tests/helpers/selector_scrollbox_harness.lua")(macroSelector, macroRows)
macroSelector.ScrollBar = false
macroSelector:SetSelectedIndex(2)
macro.GetSelectedIndex = _G.MacroFrameMixin.GetSelectedIndex
macro.GetMacroDataIndex = _G.MacroFrameMixin.GetMacroDataIndex
function macro:ShowDetails() self.details = true end
function macro:HideDetails() self.details = false end
macro.UpdateButtons = _G.MacroFrameMixin.UpdateButtons
macro.SelectedMacroButton = iconButton(macro, _G.SelectorButtonMixin)
macro.SelectedMacroButton.SelectedTexture = macro.SelectedMacroButton:CreateTexture()
macro.SelectedMacroButton:SetIconTexture("native-selected-macro")
function macro:RefreshIconDataProvider() return provider end
_G.C_Macro = {GetMacroName = function() return "Existing macro" end, GetSelectedMacroIcon = function() return "icon-4" end}
popup.Update = _G.MacroPopupFrameMixin.Update
popup.GetMacroFrame = _G.MacroPopupFrameMixin.GetMacroFrame
popup.UpdateMacroFramePanelWidth = _G.MacroPopupFrameMixin.UpdateMacroFramePanelWidth
function popup:GetNumIcons() return #icons end
function popup:GetPointByName() return unpack(self.points[1]) end
popup:ClearAllPoints()
popup:SetPoint("TOPLEFT", macro, "TOPRIGHT", 0, 5)
popup:SetScript("OnShow", _G.MacroPopupFrameMixin.OnShow)
popup:SetScript("OnHide", _G.MacroPopupFrameMixin.OnHide)
popup.shown, popup.mode = false, _G.IconSelectorPopupFrameModes.New
local panelUpdates = 0
_G.SetUIPanelAttribute = function(target, key, width) assert(key == "width"); target.panelWidth = width end
_G.UpdateUIPanelPositions = function() panelUpdates = panelUpdates + 1 end
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_MacroUI" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinMacro" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callback()
assert(skin.GetBackdrop(popup) and skin.GetBackdrop(popup)._quiRoundedSurface,
    "Macro New/Edit popup must use QUI chrome independently of guild bank setting")
assert(not popup:IsShown(), "skinning must not open the native macro popup")
assert(not skin.GetBackdrop(rows[1]) and not skin.GetBackdrop(macroRows[1]),
    "uninitialized macro selectors must leave rows for native setup")
selector.ScrollBox.view = popupView
macroSelector.ScrollBox.view = macroView
selector.initialized, macroSelector.initialized = true, true
for index, row in ipairs(macroRows) do macroSelector:RunSetup(row, index) end
assert(skin.GetBackdrop(macroRows[1]) and macroRows[1].Name:GetFont(),
    "native main selector setup must style icons and names after initialization")
popup:Show()
assert(not _G.MacroFrameText:IsShown() and not _G.MacroEditButton.enabled and not _G.MacroDeleteButton.enabled
    and not _G.MacroNewButton.enabled and not _G.MacroFrameTab1.enabled and not _G.MacroFrameTab2.enabled,
    "native New popup must retain editor hiding and disabled main controls/tabs")
assert(macro.panelWidth == 863 and selector:GetSelectedIndex() == 1 and edit:GetText() == ""
    and not box.OkayButton.enabled, "native New mode must retain width, initial icon and empty-name eligibility")
rows[5]:Fire("OnClick")
assert(selector:GetSelectedIndex() == 5 and selected.Icon.texture == "icon-5" and selected.Icon:GetAlpha() == 1,
    "native popup selection must preserve normal-texture icon art")
popup:Hide()
assert(_G.MacroFrameText:IsShown() and _G.MacroFrameText.focused and _G.MacroEditButton.enabled
    and _G.MacroFrameTab1.enabled and macro.panelWidth == 338, "native New close must restore editor, focus, tabs and panel width")
popup.mode = _G.IconSelectorPopupFrameModes.Edit
popup:Show()
assert(edit:GetText() == "Existing macro" and selector:GetSelectedIndex() == 4
    and selected.Icon.texture == "icon-4" and box.OkayButton.enabled and _G.MacroFrameText:IsShown(),
    "native Edit mode must retain selected macro name/icon and visible editor")
popup:Hide()
accountCount = 3
macroSelector.numMacros = accountCount
macro:UpdateButtons()
assert(not _G.MacroNewButton.enabled, "account macro limit must remain native")
macro.macroBase, macro.macroMax, macroSelector.numMacros = 50, 2, 2
macro:UpdateButtons()
assert(not _G.MacroNewButton.enabled, "character macro limit must remain native")
macroSelector.numMacros = 1
macro:UpdateButtons()
assert(_G.MacroNewButton.enabled, "below-limit state must remain native")
for _, row in ipairs(macroRows) do
    assert(skin.GetBackdrop(row)._quiRoundedSurface.radius == 4 and row.Icon:GetAlpha() == 1
        and row.Name:GetText():find("Native macro", 1, true) and row:GetScript("OnDragStart") == _G.MacroButtonMixin.OnDragStart,
        "main macro grid must preserve native icon/name/drag ownership with rounded controls")
end
assert(macro.SelectedMacroButton.Icon.texture == "native-selected-macro" and macro.SelectedMacroButton.Icon:GetAlpha() == 1,
    "selected macro preview must retain identifying art")
local previous = masks
skin.SetBackdropColors(skin.GetBackdrop(macroRows[1]), { 0, 0, 0, 0 }, nil)
refresh()
assert(skin.GetBackdrop(macroRows[1])._quiBorderR == skin.GetWindowColors(),
    "theme refresh must restyle existing main macro rows after initialization")
assert(masks == previous and previous == 12 and writes == 0 and panelUpdates == 4,
    "theme refresh must reuse all 12 masks without macro writes or native panel updates")
for widget, script in pairs(mainActions) do assert(widget:GetScript("OnClick") == script, "main action/tab click ownership must survive") end
env.profile.general.skinMacro, env.profile.general.skinGuildBank = false, true
local foreign = iconButton(macroSelector, _G.SelectorButtonMixin)
foreign.SelectedTexture = foreign:CreateTexture()
macroSelector:RunSetup(foreign, 1)
assert(not skin.GetBackdrop(foreign), "disabled Macro setting must prevent new main-grid styling even when guild bank is enabled")
print("OK: macro_popup_surfaces_test")
