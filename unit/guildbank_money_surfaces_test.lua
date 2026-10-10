local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinGuildBank = true
_G.UIPanelWindows, _G.min, _G.format = {}, math.min, string.format
_G.CreateFromMixins = function(...) local result = {}; for _, mixin in ipairs({...}) do
    for key, value in pairs(mixin) do result[key] = value end end; return result end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua"))()
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
bank.Columns, bank.BankTabs, bank.Log, bank.Info = {}, {}, false, false
bank.DepositButton, bank.WithdrawButton = frame("Button", bank), frame("Button", bank)
bank.BuyInfo = frame(nil, bank)
local buy = bank.BuyInfo
buy.PurchaseButton = frame("Button", buy)
buy.TabText, buy.PurchasedText = buy:CreateFontString(), buy:CreateFontString()
local transactions = 0
local purchase = function() transactions = transactions + 1 end
local withdraw = function() transactions = transactions + 1 end
buy.PurchaseButton:SetScript("OnClick", purchase)
bank.WithdrawButton:SetScript("OnClick", withdraw)
bank.MoneyFrameBG = frame(nil, bank)
local footer = bank.MoneyFrameBG
footer:SetFrameLevel(5)
footer.NineSlice = false
footer.decor = footer:CreateTexture()
footer.LimitLabel, footer.UnlimitedLabel = footer:CreateFontString(), footer:CreateFontString()
footer.LimitLabel:SetText("Available money")
footer.UnlimitedLabel:SetText("Unlimited")
for _, name in ipairs({"GuildBankMoneyFrame", "GuildBankWithdrawMoneyFrame", "GuildBankFrameTabCostMoneyFrame"}) do
    local money = frame(nil, bank)
    money.digits = money:CreateFontString()
    money.digits:SetTextColor(1, 1, 1, 1)
    _G[name] = money
end
bank.WithdrawMoneyFrame = _G.GuildBankWithdrawMoneyFrame
_G.GuildBankFrameTabCost = buy:CreateFontString()
local selectedTab, tabSelections = 1, 0
for index = 1, 3 do
    local tab = frame(nil, bank)
    tab.OnClick = function() selectedTab = index; tabSelections = tabSelections + 1 end
    bank.BankTabs[index] = tab
end
local cost, balance, limit, canWithdraw, canRepair = 100, 50, 100, true, false
_G.GetGuildBankTabCost = function() return cost end
_G.GetNumGuildBankTabs = function() return 2 end
_G.GetGuildBankMoney = function() return balance end
_G.GetGuildBankWithdrawMoney = function() return limit end
_G.CanWithdrawGuildBankMoney = function() return canWithdraw end
_G.CanGuildBankRepair = function() return canRepair end
_G.MAX_BUY_GUILDBANK_TABS, _G.NUM_GUILDBANK_TABS_PURCHASED = 8, "%s of %s tabs"
_G.MoneyFrame_Update = function(name, value) _G[name].nativeAmount = value; _G[name].digits:SetText(tostring(value)) end
_G.SetMoneyFrameColor = function(name, color)
    _G[name].nativeColor = color
    _G[name].digits:SetTextColor(1, color == "red" and 0.1 or 1, color == "red" and 0.1 or 1, 1)
end
bank.UpdateTabBuyingInfo = _G.GuildBankFrameMixin.UpdateTabBuyingInfo
bank.UpdateWithdrawMoney = _G.GuildBankFrameMixin.UpdateWithdrawMoney
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_GuildBankUI" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) if key == "skinGuildBank" then refresh = entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callback()
assert(footer:IsShown() and footer:GetAlpha() == 1 and footer.LimitLabel:GetText() == "Available money",
    "money-footer skin must retain the parent containing native limit labels")
assert(footer.decor:GetAlpha() == 0 and skin.GetBackdrop(footer)._quiRoundedSurface
    and skin.GetBackdrop(footer):GetFrameLevel() < footer:GetFrameLevel(),
    "money footer must suppress decoration and use rounded chrome behind its labels")
bank:UpdateTabBuyingInfo()
assert(not buy.PurchaseButton.enabled and _G.GuildBankFrameTabCostMoneyFrame.nativeColor == "red"
    and _G.GuildBankFrameTabCostMoneyFrame.digits.textColor[2] == 0.1 and selectedTab == 3,
    "insufficient purchase balance must retain native disabled action, red money and local tab navigation")
balance = 500
bank:UpdateTabBuyingInfo()
assert(buy.PurchaseButton.enabled and _G.GuildBankFrameTabCostMoneyFrame.nativeColor == "white"
    and _G.GuildBankFrameTabCostMoneyFrame.nativeAmount == 100 and buy.PurchasedText:GetText() == "2 of 8 tabs",
    "sufficient purchase balance must retain native amount, caption and enabled state")
cost = nil
bank:UpdateTabBuyingInfo()
assert(selectedTab == 1 and tabSelections == 3, "maximum-tab state must retain native fallback navigation")
for _, state in ipairs({
    {limit = 100, balance = 50, withdraw = true, repair = false, amount = 50, enabled = true},
    {limit = 100, balance = 500, withdraw = true, repair = false, amount = 100, enabled = true},
    {limit = 0, balance = 500, withdraw = true, repair = false, amount = 0, enabled = false},
    {limit = 100, balance = 500, withdraw = false, repair = false, amount = 0, enabled = false},
    {limit = 100, balance = 500, withdraw = false, repair = true, amount = 0, enabled = false},
}) do
    limit, balance, canWithdraw, canRepair = state.limit, state.balance, state.withdraw, state.repair
    bank:UpdateWithdrawMoney()
    assert(bank.WithdrawMoneyFrame.nativeAmount == state.amount and bank.WithdrawButton.enabled == state.enabled
        and bank.WithdrawMoneyFrame:IsShown() and not footer.UnlimitedLabel:IsShown() and footer:IsShown(),
        "finite withdrawal limit must retain native permission/balance cap and label visibility")
end
limit = -1
bank:UpdateWithdrawMoney()
assert(footer:IsShown() and footer.UnlimitedLabel:IsShown() and not bank.WithdrawMoneyFrame:IsShown()
    and not bank.WithdrawButton.enabled, "unlimited limit must retain native visibility and prior eligibility")
local shell = skin.GetBackdrop(footer)
refresh()
assert(footer:IsShown() and footer.UnlimitedLabel:IsShown() and skin.GetBackdrop(footer) == shell,
    "theme refresh must retain visible unlimited label and reuse footer chrome")
assert(buy.PurchaseButton:GetScript("OnClick") == purchase and bank.WithdrawButton:GetScript("OnClick") == withdraw
    and transactions == 0, "styling must retain transaction ownership without invoking it")
print("OK: guildbank_money_surfaces_test")
