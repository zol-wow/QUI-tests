local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinGuildBank = true
_G.UIPanelWindows = {}
_G.CreateFromMixins = function(...) local result = {}; for _, mixin in ipairs({...}) do
    for key, value in pairs(mixin) do result[key] = value end end; return result end
_G.mod, _G.ceil, _G.format = math.fmod, math.ceil, string.format
_G.MAX_GUILDBANK_TABS, _G.MAX_BUY_GUILDBANK_TABS = 8, 8
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua"))()
local frame = env.NewFrame("Frame", "GuildBankFrame")
_G.GuildBankFrame = frame
frame.Columns, frame.BankTabs, frame.mode = {}, {}, "bank"
frame.MoneyFrameBG = false
local masks = 0
local function button(kind, parent)
    local widget = env.NewFrame(kind or "Button", nil, parent)
    widget.DisabledTexture = false
    widget.Icon, widget.Count = widget:CreateTexture(), widget:CreateFontString()
    widget.IconBorder = widget:CreateTexture()
    function widget.IconBorder:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
    function widget:CreateMaskTexture() local mask = self:CreateTexture(); mask.kind = "MaskTexture"; return mask end
    function widget.Icon:AddMaskTexture() masks = masks + 1 end
    function widget:Enable() self.enabled = true end
    function widget:Disable() self.enabled = false end
    function widget:SetChecked(value) self.checked = value end
    function widget:GetChecked() return self.checked end
    function widget:SetMatchesSearch(value) self.matches = value; self.SearchOverlay:SetShown(not value) end
    widget.SearchOverlay = widget:CreateTexture()
    widget:SetScript("OnClick", _G.GuildBankItemButtonMixin.OnClick)
    widget:SetScript("OnDragStart", _G.GuildBankItemButtonMixin.OnDragStart)
    widget.nativeClick, widget.nativeDrag = widget:GetScript("OnClick"), widget:GetScript("OnDragStart")
    return widget
end
for columnIndex = 1, 7 do
    local column = env.NewFrame("Frame", nil, frame)
    column.Background, column.Buttons = column:CreateTexture(), {}
    function column.Background:SetDesaturation(value) self.nativeDesaturation = value end
    for index = 1, 14 do column.Buttons[index] = button("ItemButton", column) end
    frame.Columns[columnIndex] = column
end
for index = 1, 8 do
    local tab = env.NewFrame("Frame", nil, frame)
    tab.art = tab:CreateTexture()
    tab.Button = button("CheckButton", tab)
    tab.Button.IconTexture = tab.Button.Icon
    frame.BankTabs[index] = tab
end
for _, key in ipairs({"TabTitleBG", "TabTitleBGLeft", "TabTitleBGRight", "TabLimitBG", "TabLimitBGLeft",
    "TabLimitBGRight", "RedMarbleBG", "BlackBG"}) do frame[key] = frame:CreateTexture() end
frame.TabTitle, frame.LimitLabel, frame.ErrorMessage = frame:CreateFontString(), frame:CreateFontString(), frame:CreateFontString()
frame.ErrorMessage:SetTextColor(1, 0.1, 0.1, 1)
frame.BuyInfo, frame.Log, frame.Info = env.NewFrame("Frame", nil, frame), env.NewFrame("Frame", nil, frame), env.NewFrame("Frame", nil, frame)
frame.DepositButton, frame.WithdrawButton = button(nil, frame), button(nil, frame)
frame.BuyInfo.PurchaseButton, frame.Info.SaveButton = button(nil, frame.BuyInfo), button(nil, frame.Info)
frame.Info.ScrollFrame = env.NewFrame("ScrollFrame", nil, frame.Info)
frame.Info.ScrollFrame.ScrollBar = env.NewFrame("Slider", nil, frame.Info.ScrollFrame)
frame.Info.ScrollFrame.ScrollBar.ThumbTexture = frame.Info.ScrollFrame.ScrollBar:CreateTexture()
frame.Log.ScrollBar = false
local current, visible, deposit, withdrawal, canWithdraw, filtered, locked, quality = 1, true, true, 10, true, false, false, 4
_G.GetCurrentGuildBankTab = function() return current end
_G.SetCurrentGuildBankTab = function(value) current = value end
_G.GetNumGuildBankTabs = function() return 2 end
_G.IsGuildLeader = function() return false end
_G.GetGuildBankTabInfo = function(index)
    if index > 2 then return end
    return "Native tab " .. index, "tab-art-" .. index, visible, deposit, withdrawal, withdrawal
end
_G.GetGuildBankItemInfo = function(_, index) return index == 1 and "native-item" or nil, index == 1 and 7 or 0, locked, filtered, quality end
_G.GetGuildBankItemLink = function() return "native-link" end
_G.GetGuildBankMoney = function() return 123456 end
_G.CanWithdrawGuildBankMoney = function() return canWithdraw end
_G.MoneyFrame_Update = function(_, value) frame.nativeMoney = value end
_G.SetItemButtonTexture = function(widget, texture) widget.Icon:SetTexture(texture) end
_G.SetItemButtonCount = function(widget, value) widget.nativeCount = value end
_G.SetItemButtonDesaturated = function(widget, value) widget.locked = value; widget.Icon.nativeLocked = value end
_G.SetItemButtonQuality = function(widget, value)
    widget.nativeQuality = value
    if value then widget.IconBorder:SetVertexColor(value / 5, 0.3, 0.8, 1); widget.IconBorder:Show()
    else widget.IconBorder:Hide() end
end
_G.GUILDBANK_TAB_NUMBER, _G.GUILDBANK_REMAINING_MONEY, _G.STACKS = "Tab %s", "%s %s", "%s stacks"
_G.GUILDBANK_TAB_LOCKED, _G.GUILDBANK_TAB_WITHDRAW_ONLY = "Locked", "Withdraw only"
_G.GUILDBANK_TAB_DEPOSIT_ONLY, _G.GUILDBANK_TAB_FULL_ACCESS = "Deposit only", "Full access"
_G.NO_VIEWABLE_GUILDBANK_TABS, _G.NO_GUILDBANK_TABS, _G.NO_VIEWABLE_GUILDBANK_LOGS = "No view", "No tabs", "No logs"
_G.GUILD_BANK_MONEY_LOG, _G.GUILDBANK_LOG_TITLE_FORMAT, _G.GUILDBANK_INFO_TITLE_FORMAT = "Money log", "Log %s", "Info %s"
_G.NONE, _G.UNLIMITED = "None", "Unlimited"
for _, key in ipairs({"Update", "UpdateTabs", "ShowColumns", "HideColumns", "DesaturateColumns"}) do frame[key] = _G.GuildBankFrameMixin[key] end
local withdrawals = 0
function frame:UpdateWithdrawMoney() withdrawals = withdrawals + 1 end
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_GuildBankUI" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinGuildBank" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callback()
local slot = frame.Columns[1].Buttons[1]
assert(skin.GetBackdrop(slot) and skin.GetBackdrop(slot)._quiRoundedSurface.radius == 4,
    "all guild bank item slots must use rounded QUI controls")
frame:UpdateTabs()
frame:Update()
for _, column in ipairs(frame.Columns) do
    for _, widget in ipairs(column.Buttons) do
        assert(skin.IsStyled(widget) and widget:GetScript("OnClick") == widget.nativeClick
            and widget:GetScript("OnDragStart") == widget.nativeDrag, "all 98 slots must preserve native item and drag ownership")
    end
end
assert(slot.Icon.texture == "native-item" and slot.nativeCount == 7 and slot:GetID() == 1,
    "native item art, counts and identities must survive")
local border = skin.GetFrameData(slot.Icon, "iconBorder")
assert(border._quiBorderR == 0.8, "native quality must reach the rounded icon border")
assert(frame.BankTabs[1].Button:GetChecked() and frame.BankTabs[1].Button.enabled
    and not frame.BankTabs[2].Button:GetChecked(), "native tab checked/enabled state must survive")
assert(frame.BankTabs[1].art:GetAlpha() == 0 and frame.BankTabs[1].Button.IconTexture.texture == "tab-art-1",
    "tab scenery must be suppressed while native identifying art survives")
local r, g, b = skin.GetSkinColors()
assert(skin.GetBackdrop(frame.BankTabs[1].Button)._quiBorderR == r, "selected bank tab must use the shared accent")
assert(frame.Info.ScrollFrame.ScrollBar.ThumbTexture.color, "tab info editor must have a visible styled thumb")
filtered, locked, quality, deposit, withdrawal, canWithdraw = true, true, nil, false, 0, false
frame:UpdateTabs()
frame:Update()
assert(slot.locked and slot.SearchOverlay:IsShown() and not slot.matches and not frame.WithdrawButton.enabled,
    "native locks, filtered feedback and withdraw permissions must remain authoritative")
assert(frame.Columns[1].Background.nativeDesaturation == 1 and frame.Columns[1].Background:GetAlpha() == 1,
    "native column permission feedback must remain intact")
refresh()
local sr = skin.GetWindowColors()
assert(border._quiBorderR == sr, "ordinary item reuse must clear stale rarity")
frame.mode = "moneylog"
frame:UpdateTabs()
frame:Update()
assert(not frame.BankTabs[1].Button.enabled and not frame.BankTabs[1].Button:GetChecked()
    and frame.Log:IsShown() and not frame.Columns[1]:IsShown(), "money log must retain native disabled tab and visibility state")
frame.mode, visible = "bank", false
frame:UpdateTabs()
frame:Update()
assert(frame.noViewableTabs and frame.ErrorMessage:IsShown() and not frame.Columns[1]:IsShown(),
    "no-view permissions must remain authoritative")
assert(frame.ErrorMessage.textColor[2] == 0.1, "native warning color must remain semantic")
frame.mode = "tabinfo"
frame:Update()
assert(frame.Info:IsShown() and not frame.Log:IsShown(), "native info mode must retain ownership")
local count = masks
skin.GetBackdrop(slot):SetBackdropColor(0.99, 0.99, 0.99, 1)
skin.GetBackdrop(frame.BankTabs[1].Button):SetBackdropColor(0.99, 0.99, 0.99, 1)
refresh()
assert(skin.GetBackdrop(slot)._quiBgR ~= 0.99 and skin.GetBackdrop(frame.BankTabs[1].Button)._quiBgR ~= 0.99,
    "theme refresh must reach existing item-slot and tab widget backgrounds")
assert(masks == count and count == 106 and withdrawals == 5, "refresh must reuse 98 item and eight tab masks without native updates")
print("OK: guildbank_surfaces_test")
