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
_G.MerchantBuyBackItem = env.NewFrame("Frame", nil, frame)
local buyback = _G.MerchantBuyBackItem
buyback.Name = buyback:CreateFontString()
buyback.Name.GetText = function(self) return self.nativeText end
buyback.ItemButton = env.NewFrame("Button", nil, buyback)
buyback.ItemButton.Icon = buyback.ItemButton:CreateTexture()
_G.StackSplitFrame = env.NewFrame("Frame")
local split = _G.StackSplitFrame
split.SingleItemSplitBackground = split:CreateTexture()
split.MultiItemSplitBackground = split:CreateTexture()
split.StackSplitText = split:CreateFontString()
split.StackItemCountText = split:CreateFontString()
for _, key in ipairs({ "OkayButton", "CancelButton", "LeftButton", "RightButton" }) do
    split[key] = env.NewFrame("Button", nil, split)
    split[key].DisabledTexture = false
end
local purchased = 0
local purchase = function() purchased = purchased + 1 end
local cancel = function() split:Hide() end
split.OkayButton:SetScript("OnClick", purchase)
split.CancelButton:SetScript("OnClick", cancel)
local increment = function() split.split = split.split + split.minSplit end
split.RightButton:SetScript("OnClick", increment)
function split:ChooseFrameType(amount)
    self.isMultiStack = amount > 1
    self.minSplit = amount
    self.split = amount
    self:SetSize(172, amount == 1 and 96 or 120)
    self.SingleItemSplitBackground:SetAlpha(1)
    self.MultiItemSplitBackground:SetAlpha(1)
    self.StackSplitText:SetText(amount == 1 and "1" or "1 Stack")
    self.StackItemCountText:SetText(amount .. " Total")
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
assert(not env.SkinBase.GetBackdrop(_G.MerchantExtraCurrencyInset), "unused native currency inset must not add a detached empty card")
rows[18].ItemButton:Hide()
_G.MerchantFrame_Update()
assert(not env.SkinBase.GetBackdrop(rows[18]):IsShown(), "empty native vendor slot must not leave a blank QUI card")
rows[18].ItemButton:Show()
_G.MerchantFrame_Update()
assert(env.SkinBase.GetBackdrop(rows[18]):IsShown(), "reused populated slot must restore its card")
assert(rows[18].ItemButton:GetScript("OnClick") == buy, "slot visibility must preserve native purchase handler")
assert(not env.SkinBase.GetBackdrop(buyback):IsShown(), "nil buyback name must not leave a blank footer card")
buyback.Name.nativeText = ""
_G.MerchantFrame_Update()
assert(not env.SkinBase.GetBackdrop(buyback):IsShown(), "empty buyback name must not leave a blank footer card")
buyback.Name.nativeText = "Native item"
_G.MerchantFrame_Update()
assert(env.SkinBase.GetBackdrop(buyback):IsShown(), "populated buyback must restore its card")
split.owner = env.NewFrame("Button")
split:ChooseFrameType(1)
assert(not env.SkinBase.GetBackdrop(split), "unrelated quantity owners must not be styled by merchant skin")
split.owner = rows[1].ItemButton
env.profile.general.skinMerchant = false
split:ChooseFrameType(1)
assert(not env.SkinBase.GetBackdrop(split), "disabled merchant skin must not style the quantity popup")
env.profile.general.skinMerchant = true
split:Show()
split:ChooseFrameType(20)
assert(env.SkinBase.GetBackdrop(split) and env.SkinBase.GetBackdrop(split)._quiRoundedSurface,
    "merchant quantity popup must use QUI chrome")
assert(env.SkinBase.GetBackdrop(split)._quiBgA == 1, "quantity popup must have an opaque background")
local quantityField = env.SkinBase.GetFrameData(split, "qMerchantStackSplitField")
assert(quantityField and quantityField.mouse == false and quantityField.points[1][5] == 30,
    "stack quantity must have a visible field without intercepting native input")
assert(env.SkinBase.GetBackdrop(quantityField)._quiRoundedSurface,
    "quantity field must use QUI rounded chrome")
assert(split.SingleItemSplitBackground:GetAlpha() == 0 and split.MultiItemSplitBackground:GetAlpha() == 0,
    "native quantity popup decoration must stay hidden after choose-type rebuild")
assert(split.width == 172 and split.height == 120 and split.split == 20 and split.minSplit == 20,
    "native stack quantity and popup dimensions must be retained")
assert(split.StackSplitText:GetText() == "1 Stack" and split.StackItemCountText:GetText() == "20 Total",
    "native stack labels must be retained")
assert(split.OkayButton:GetScript("OnClick") == purchase and split.CancelButton:GetScript("OnClick") == cancel
    and split.RightButton:GetScript("OnClick") == increment, "native quantity controls must retain callbacks")
split.RightButton:GetScript("OnClick")()
assert(split.split == 40 and purchased == 0, "quantity preview must not purchase")
split.CancelButton:GetScript("OnClick")()
assert(not split:IsShown() and purchased == 0, "Cancel must dismiss without purchase")
split:ChooseFrameType(1)
assert(split.height == 96 and split.split == 1, "single-item quantity state must retain native sizing")
assert(env.SkinBase.GetFrameData(split, "qMerchantStackSplitField") == quantityField
    and quantityField.points[1][5] == 18, "reused single-item field must follow native quantity position")
print("OK: merchant_inner_surfaces_test")
