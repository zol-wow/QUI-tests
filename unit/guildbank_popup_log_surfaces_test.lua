local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinGuildBank = true
_G.UIPanelWindows = {}
_G.CreateFromMixins = function(...) local result = {}; for _, mixin in ipairs({...}) do
    for key, value in pairs(mixin) do result[key] = value end end; return result end
_G.format = string.format
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua"))()
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
bank.UpdateTabInfo = _G.GuildBankFrameMixin.UpdateTabInfo
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
_G.GuildBankPopupFrame = popup
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
selector.initialized = true
local rows = {}
for index = 1, 6 do
    local row = iconButton(selector, _G.SelectorButtonMixin)
    row.SelectedTexture = row:CreateTexture()
    rows[index] = row
    row:Init(selector)
    row.selectionIndex = index
end
function selector:EnumerateButtons() local index = 0; return function() index = index + 1; return rows[index] end end
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
popup.Update = _G.GuildBankPopupFrameMixin.Update
popup:SetScript("OnShow", _G.GuildBankPopupFrameMixin.OnShow)
_G.GetNumGuildBankTransactions = function() return 1 end
_G.GetGuildBankTransaction = function() return "deposit", "Native player", "|cffaa00ff|Hitem:123|h[Native item]|h|r", 2, 1, 1, 2026, 10, 9, 12 end
_G.NORMAL_FONT_COLOR_CODE, _G.FONT_COLOR_CODE_CLOSE = "|cffffff00", "|r"
_G.GUILDBANK_DEPOSIT_FORMAT, _G.GUILDBANK_LOG_QUANTITY, _G.GUILD_BANK_LOG_TIME = "%s deposited %s", " x%s", " (%s)"
_G.TimeUtil = {GetRecentTimeDate = function() return "Native timestamp" end}
_G.GetNumGuildBankMoneyTransactions = function() return 1 end
_G.GetGuildBankMoneyTransaction = function() return "repair", "Native player", 12345, 2026, 10, 9, 12 end
_G.GetDenominationsFromCopper = function(value) return tostring(value) .. " copper" end
_G.GUILDBANK_REPAIR_MONEY_FORMAT = "%s repaired for %s"
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_GuildBankUI" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinGuildBank" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callback()
assert(skin.GetBackdrop(popup) and skin.GetBackdrop(popup)._quiRoundedSurface,
    "guild bank icon-selector popup must use QUI window chrome")
popup:Hide()
popup:Show()
assert(popup.points[1][1] == "TOPLEFT" and popup.points[1][4] == 38 and edit.focused
    and selector:GetSelectedIndex() == 3 and selected.Icon.texture == "icon-3",
    "native outside anchor, focus and initial icon selection must survive")
assert(skin.IsStyled(box.OkayButton) and skin.IsStyled(box.IconTypeDropdown)
    and box.OkayButton:GetScript("OnClick") == okay, "native popup controls and save ownership must survive")
assert(popup.BG:GetAlpha() == 0 and box.art:GetAlpha() == 0 and selected.Icon:GetAlpha() == 1,
    "popup scenery must be suppressed without hiding normal-texture icon art")
for _, row in ipairs(rows) do
    assert(skin.GetBackdrop(row)._quiRoundedSurface.radius == 4 and row.Icon:GetAlpha() == 1
        and row.art:GetAlpha() == 0 and row.Highlight:GetAlpha() == 0,
        "each selector icon must use rounded chrome while preserving identifying normal texture")
end
local ar = skin.GetSkinColors()
assert(skin.GetBackdrop(rows[3])._quiBorderR == ar and rows[3].SelectedTexture:IsShown(),
    "native selected state must use shared accent without changing selection ownership")
rows[5]:Fire("OnClick")
assert(selector:GetSelectedIndex() == 5 and selected.Icon.texture == "icon-5"
    and box.SelectedIconArea.SelectedIconText.SelectedIconDescription:GetText() == "Native selected",
    "native local selection callback must update the selected icon and description")
assert(description.font and description.font ~= "native-selected-font",
    "native selection font-object reset must retain QUI typography")
rows[2]:Fire("OnEnter")
assert(skin.GetBackdrop(rows[2])._quiBorderR == ar, "unselected icon hover must use shared accent")
rows[2]:Fire("OnLeave")
local sr = skin.GetWindowColors()
assert(skin.GetBackdrop(rows[2])._quiBorderR == sr and skin.GetBackdrop(rows[5])._quiBorderR == ar,
    "leaving a row must restore neutral chrome while selected icon remains accented")
edit:SetText(""); edit:OnTextChanged()
assert(not box.OkayButton.enabled, "native empty-name eligibility must survive")
edit:SetText("Valid name"); edit:OnTextChanged()
assert(box.OkayButton.enabled, "native nonempty-name eligibility must survive")
width = 1000
popup:Hide(); popup:Show()
assert(popup.points[1][1] == "TOPRIGHT" and popup.points[1][4] == -10 and popup.nativeShowCalls == 2,
    "native screen-edge anchoring must remain authoritative")
bank:UpdateTabInfo(1)
assert(bank.Info.ScrollFrame.EditBox.currentText == savedText and bank.Info.ScrollFrame.EditBox.text == savedText,
    "native tab-info text and edit baseline must survive")
_G.GuildBankFrame_UpdateLog()
assert(#messages.messages == 1 and messages.messages[1]:find("|Hitem:123", 1, true)
    and messages.messages[1]:find("|cffffff00", 1, true) and messages.nativeFont,
    "populated item log must retain hyperlinks and inline colors with QUI typography")
_G.GuildBankFrame_UpdateMoneyLog()
assert(messages.messages[1]:find("12345 copper", 1, true)
    and messages:GetScript("OnHyperlinkClick") == hyperlink, "native money log content and hyperlink handler must survive")
refresh()
assert(masks == 7 and selector.ScrollBar.ThumbTexture.color and selected.Icon:GetAlpha() == 1,
    "repeated popup refresh must reuse seven icon masks and retain visible scrollbar and art")
print("OK: guildbank_popup_log_surfaces_test")
