local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinBank = true
_G.UIPanelWindows, _G.StaticPopupDialogs = {}, {}
_G.CreateFromMixins = function(...) local result = {}; for _, mixin in ipairs({...}) do
    for key, value in pairs(mixin) do result[key] = value end end; return result end
_G.format = string.format
_G.CallbackRegistryMixin = {GenerateCallbackEvents = function() end}
_G.Enum = {BankType={Account=2,Character=1}}
_G.Enum.PlayerInteractionType = {Banker=1,CharacterBanker=2,AccountBanker=3}
_G.Enum.BankLockedReason={BankConversionFailed=1,BankDisabled=2,NoAccountInventoryLock=3}
_G.Enum.BagSlotFlags={ExpansionCurrent=1,ExpansionLegacy=2}
_G.StaticPopupDialogs = {}
_G.RegisterPlayerInteraction = function() end
_G.TextureKitConstants = {IgnoreAtlasSize=false}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua"))()
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
_G.BankFrame = bank
bank.BankPanel = frame(nil,bank)
bank.BankPanel.Prompts = {}
local popup = frame(nil, bank)
bank.BankPanel.TabSettingsMenu = popup
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

local deposit=frame(nil,popup)
popup.DepositSettingsMenu=deposit
deposit.decor=deposit:CreateTexture()
deposit.DepositSettingsCheckboxes={}
local flags={4,8,16,32,64,nil}
for i=1,6 do
 local c=frame("CheckButton",deposit)
 c.Text=c:CreateFontString(); c.Text:SetText("Native setting "..i)
 function c.Text:SetFontObject(font) self:SetFont(font,12,"") end
 c.Init=_G.BankPanelCheckboxMixin.Init
 c.fontObject="native-checkbox-reset"
 c.settingFlag=flags[i]
 function c:SetEnabled(value) self.enabled=value end
 function c:SetChecked(value) self.checked=value end
 function c:GetChecked() return self.checked end
 c:SetScript("OnClick",function() error("audit must not change deposit options") end)
 deposit.DepositSettingsCheckboxes[i]=c
end
local dropdown=frame("DropdownButton",deposit)
deposit.ExpansionFilterDropdown=dropdown
for k,v in pairs(_G.BankPanelTabSettingsExpansionFilterDropdownMixin) do dropdown[k]=v end
function dropdown:SetupMenu(fn) self.nativeMenuBuilder=fn end
_G.FlagsUtil={
 IsSet=function(value,flag) return math.floor(value/flag)%2==1 end,
 Combine=function(value,flag,set) if flag==0 then return value end
  local present=math.floor(value/flag)%2==1
  if set and not present then return value+flag elseif not set and present then return value-flag end
  return value
 end
}
_G.CallbackRegistrantMixin={OnShow=function() end,OnHide=function() end}
_G.IconSelectorPopupFrameTemplateMixin={OnShow=function() end,OnHide=function() end}
_G.IconSelectorPopupFrameIconFilterTypes={All=1}
_G.SOUNDKIT={}; _G.PlaySound=function() end
_G.QUESTION_MARK_ICON="question"
for k,v in pairs(_G.BankPanelTabSettingsMenuMixin) do popup[k]=v end
local writes=0
_G.C_Bank={UpdateBankTabSettings=function() writes=writes+1 end}
popup:SetScript("OnShow",popup.OnShow)
popup:SetScript("OnHide",popup.OnHide)
box.EditBoxHeaderText=box:CreateFontString()
local tabData={ID=1,name="Native bank tab",icon="icon-3",depositFlags=5,bankType=1,tabNameEditBoxHeader="Character faction storage"}
function bank.BankPanel:GetTabData(id) tabData.ID=id; return tabData end
function popup:GetBankPanel() return bank.BankPanel end
_G.IconDataProviderExtraType={None=0}
_G.CreateAndInitFromMixin=function() return provider end
function provider:Release() self.released=true end
popup:Hide()
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_UIPanels_Game" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinBank" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
assert(not popup:IsShown() and skin.GetBackdrop(box.IconSelectorEditBox)
 and skin.GetBackdrop(box.IconSelectorEditBox)._quiRoundedSurface,
 "bank popup must skin its native name field without opening")
assert(skin.GetBackdrop(dropdown) and skin.GetBackdrop(dropdown)._quiRoundedSurface and deposit.decor:GetAlpha()==0,
 "nested deposit dropdown and separator must receive QUI presentation")
for _,c in ipairs(deposit.DepositSettingsCheckboxes) do
 assert(skin.IsStyled(c) and skin.GetBackdrop(c),"all nested deposit checkboxes must receive QUI presentation")
end
popup:SetSelectedTab(1)
popup:Show()
assert(edit:GetText()=="Native bank tab" and edit.focused and edit.highlighted and selector.scrolled==3,
 "native open must retain tab name focus and selected icon")
assert(selected.Icon.texture=="icon-3" and box.EditBoxHeaderText:GetText()==tabData.tabNameEditBoxHeader,
 "native selected icon and bank-specific name prompt must remain")
assert(dropdown:GetFilterValue()==1 and type(dropdown.nativeMenuBuilder)=="function",
 "native expansion filter and menu builder must remain authoritative")
assert(deposit.DepositSettingsCheckboxes[1]:GetChecked() and not deposit.DepositSettingsCheckboxes[2]:GetChecked()
 and not deposit.DepositSettingsCheckboxes[6].enabled,"native flags and invalid-setting eligibility must survive")
for _,c in ipairs(deposit.DepositSettingsCheckboxes) do
 c:Init()
 assert(c.Text:GetFont()~="native-checkbox-reset","native checkbox initialization must retain QUI typography")
end
local count=masks
refresh()
assert(masks==count and count==7 and writes==0 and box.OkayButton:GetScript("OnClick")==okay,
 "refresh must reuse masks and preserve save handler without writing settings")
tabData.name="Reused account tab"; tabData.icon="icon-5"; tabData.depositFlags=10
popup:Update()
assert(edit:GetText()==tabData.name and selected.Icon.texture=="icon-5" and selector.scrolled==5
 and dropdown:GetFilterValue()==2 and deposit.DepositSettingsCheckboxes[2]:GetChecked()
 and not deposit.DepositSettingsCheckboxes[1]:GetChecked(),"native tab reuse must retain updated name icon and flags")
description:SetFontObject("native-reset")
assert(description:GetFont()~="native-reset","selected-icon description must retain QUI font through native resets")
popup:OnHide()
assert(provider.released and popup.selectedTabData==nil and writes==0,
 "native close must release provider and selected tab without a settings write")
print("bank popup surfaces passed")
