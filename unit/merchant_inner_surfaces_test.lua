local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinMerchant = true
_G.MERCHANT_ITEMS_PER_PAGE = 18
_G.MerchantFrame = env.NewFrame("Frame")
local frame = _G.MerchantFrame
frame.TitleText = frame:CreateFontString()
frame.GetTitleText = function(self) return self.TitleText end
frame.FilterDropdown = env.NewFrame("Button", nil, frame)
frame.FilterDropdown.DisabledTexture = false
_G.MerchantFrameBottomLeftBorder = frame:CreateTexture()
_G.BuybackBG = frame:CreateTexture()
_G.MerchantMoneyInset = env.NewFrame("Frame", nil, frame)
_G.MerchantMoneyInset.NineSlice = env.NewFrame("Frame", nil, _G.MerchantMoneyInset)
_G.MerchantExtraCurrencyInset = env.NewFrame("Frame", nil, frame)
_G.MerchantMoneyBg = env.NewFrame("Frame", nil, frame)
_G.MerchantMoneyBg.Edge = _G.MerchantMoneyBg:CreateTexture()
_G.MerchantExtraCurrencyBg = env.NewFrame("Frame", nil, frame)
_G.MerchantExtraCurrencyBg.Edge = _G.MerchantExtraCurrencyBg:CreateTexture()
local buy = function() end
local rows = {}
for i = 1, 18 do
    local row = env.NewFrame("Frame", nil, frame)
    _G["MerchantItem" .. i] = row
    rows[i] = row
    row.SlotTexture = row:CreateTexture()
    row.Name = row:CreateFontString()
    row.Name:SetTextColor(.2, .6, 1)
    row.ItemButton = env.NewFrame("Button", nil, row)
    row.ItemButton.Icon = row.ItemButton:CreateTexture()
    row.ItemButton.Icon:SetTexture("native-item-art")
    row.ItemButton.IconBorder = row.ItemButton:CreateTexture()
    function row.ItemButton.IconBorder:GetVertexColor() return unpack(self.vertex or { .2, .6, 1, 1 }) end
    row.ItemButton.Normal = row.ItemButton:CreateTexture()
    row.ItemButton.GetNormalTexture = function(self) return self.Normal end
    row.ItemButton.IconQuestTexture = row.ItemButton:CreateTexture()
    row.ItemButton:SetScript("OnClick", buy)
end
_G.MerchantRepairAllButton = env.NewFrame("Button", nil, frame)
local repair = _G.MerchantRepairAllButton
repair.Icon = repair:CreateTexture()
repair.Icon.GetDrawLayer = function() return "BORDER" end
repair.Slot = repair:CreateTexture()
repair.Slot.GetDrawLayer = function() return "BACKGROUND" end
local repairAction = function() end
repair:SetScript("OnClick", repairAction)
for i = 1, 2 do
    local tab = env.NewFrame("Button", nil, frame)
    _G["MerchantFrameTab" .. i] = tab
    tab.DisabledTexture = false
    tab.Text = tab:CreateFontString()
    tab.Text:SetText(i == 1 and "Merchant" or "Buyback")
end
_G.MerchantFrame_Update = function()
    frame.TitleText:SetTextColor(1, .82, 0)
    rows[18].SlotTexture:SetAlpha(1)
    rows[18].ItemButton.Normal:SetAlpha(1)
end
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_INTERACTION_SOURCE") or "modules/skinning/frames/interaction.lua"))("QUI", env.ns)
_G.MerchantFrame_Update()
assert(select(2, frame.TitleText:GetTextColor()) == 1, "native merchant refresh must retain white title")
assert(rows[18].SlotTexture:GetAlpha() == 0 and rows[18].ItemButton.Normal:GetAlpha() == 0,
    "grid extension rows must not restore ornate native slots")
assert(env.SkinBase.GetBackdrop(rows[18])._quiRoundedSurface, "merchant grid rows must use rounded surfaces")
assert(env.SkinBase.GetFrameData(rows[18].ItemButton.Icon, "iconBorder")._quiRoundedSurface,
    "merchant item icons must use rounded quality borders")
assert(rows[18].ItemButton.Icon.texture == "native-item-art"
    and rows[18].ItemButton.IconQuestTexture:GetAlpha() == 1, "item art and quest indicators stay visible")
local r, g, b = rows[18].Name:GetTextColor()
assert(r == .2 and g == .6 and b == 1, "merchant item-name quality colors stay native")
assert(rows[18].ItemButton:GetScript("OnClick") == buy and repair:GetScript("OnClick") == repairAction,
    "purchase and repair actions stay native")
assert(_G.MerchantFrameBottomLeftBorder:GetAlpha() == 0
    and _G.MerchantMoneyInset.NineSlice:GetAlpha() == 0, "merchant footer must suppress ornate native borders")
assert(repair.Slot:GetAlpha() == 0 and repair.Icon:GetAlpha() == 1,
    "native action slot decoration must disappear while its semantic icon stays visible")
assert(_G.MerchantMoneyBg.Edge:GetAlpha() == 0 and _G.MerchantExtraCurrencyBg.Edge:GetAlpha() == 0,
    "separate native gold currency frames must disappear")
print("OK: merchant_inner_surfaces_test")
