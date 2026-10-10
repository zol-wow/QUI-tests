local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, skin = env.ns, env.SkinBase
env.profile.general.skinTrade = true
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/TradeFrame.lua"))()
local frame = env.NewFrame("Frame", "TradeFrame")
_G.TradeFrame = frame
frame.decoration = frame:CreateTexture()
frame.RecipientOverlay = env.NewFrame("Frame", nil, frame)
local overlay = frame.RecipientOverlay
overlay.portrait, overlay.portraitFrame = overlay:CreateTexture(), overlay:CreateTexture()
overlay.CreateMaskTexture = overlay.CreateTexture
function overlay.portrait:AddMaskTexture() end
local maskCount = 0
local items = {Player = {}, Recipient = {}}
for _, side in ipairs({"Player", "Recipient"}) do
    for index = 1, 7 do
        local prefix = "Trade" .. side .. "Item" .. index
        local row = env.NewFrame("Frame", prefix, frame)
        _G[prefix] = row
        row.SlotTexture = row:CreateTexture()
        _G[prefix .. "NameFrame"] = row:CreateTexture()
        row.enchantGlyph = row:CreateTexture()
        local label = row:CreateFontString()
        _G[prefix .. "Name"] = label
        local button = env.NewFrame("ItemButton", prefix .. "ItemButton", row)
        _G[prefix .. "ItemButton"] = button
        button.icon, button.IconBorder, button.normalTexture = button:CreateTexture(), button:CreateTexture(), button:CreateTexture()
        button.CreateMaskTexture = button.CreateTexture
        function button.icon:AddMaskTexture() maskCount = maskCount + 1 end
        local nativeClick, nativeDrag = function() end, function() end
        button:SetScript("OnClick", nativeClick)
        button:SetScript("OnReceiveDrag", nativeDrag)
        button.nativeClick, button.nativeDrag = nativeClick, nativeDrag
        button.Alert = {ItemIconAlertAnim = {Restart = function(self) self.restarted = true end}}
        items[side][index] = {name = side .. index, icon = 100 + index, count = index, quality = 3, usable = true, itemID = index}
    end
end
for _, name in ipairs({"TradePlayerItemsInset", "TradeRecipientItemsInset", "TradePlayerEnchantInset",
    "TradeRecipientEnchantInset", "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset", "TradeRecipientMoneyBg",
    "TradeHighlightPlayer", "TradeHighlightRecipient", "TradeHighlightPlayerEnchant", "TradeHighlightRecipientEnchant"}) do
    local panel = env.NewFrame("Frame", name, frame)
    _G[name] = panel
    panel.art = panel:CreateTexture()
    if name == "TradeRecipientMoneyBg" then panel:SetAlpha(0.6) end
end
for _, name in ipairs({"TradeFramePlayerNameText", "TradeFrameRecipientNameText"}) do _G[name] = frame:CreateFontString() end
_G.TradeRecipientMoneyFrame = env.NewFrame("Frame", nil, frame)
_G.TradeRecipientMoneyFrame.quantity = _G.TradeRecipientMoneyFrame:CreateFontString()
_G.TradeRecipientMoneyFrame.quantity:SetText("Native money")
local forbidden = env.NewFrame("Frame", "TradePlayerInputMoneyFrame", frame)
_G.TradePlayerInputMoneyFrame = forbidden
function forbidden:IsForbidden() return true end
function forbidden:GetChildren() error("forbidden money entry must not be traversed") end
function forbidden:GetRegions() error("forbidden money entry must not be styled") end
local entry = env.NewFrame("EditBox", nil, forbidden)
function entry:SetFont() error("forbidden money edit field must remain untouched") end
for _, name in ipairs({"TradeFrameTradeButton", "TradeFrameCancelButton"}) do
    local button = env.NewFrame("Button", name, frame)
    _G[name] = button
    button.DisabledTexture = false
    button.Text = button:CreateFontString()
    function button:Enable() self.enabled = true end
    function button:Disable() self.enabled = false end
end
local action = _G.TradeFrameTradeButton
action.WarningIcon = action:CreateTexture()
local warning = false
_G.C_TradeInfo = {ShouldShowTradeOfferWarning = function() return warning end}
_G.GetUnitName = function() return "Native partner" end
_G.TRADE_WARNING_CHANGED_OFFER = "%s changed their offer"
_G.GameTooltip = {IsOwned = function() return false end}
_G.StaticPopup_Visible = function() return false end
_G.GREEN_FONT_COLOR_CODE, _G.FONT_COLOR_CODE_CLOSE = "|cff00ff00", "|r"
_G.HIGHLIGHT_FONT_COLOR_CODE, _G.TRADEFRAME_NOT_MODIFIED_TEXT = "|cffffffff", "Not modified"
_G.NORMAL_FONT_COLOR = {r = 1, g = 0.8, b = 0}
_G.C_Item.GetItemQualityColor = function(quality) return quality == 4 and 0.6 or 0, 0.4, 1 end
_G.ColorManager = {GetColorDataForItemQuality = function(quality)
    local r, g, b = _G.C_Item.GetItemQualityColor(quality)
    return {r = r, g = g, b = b}
end}
_G.GetTradePlayerItemInfo = function(index)
    local item = items.Player[index]
    return item.name, item.icon, item.count, item.quality, item.enchantment, false, false, item.itemID
end
_G.GetTradeTargetItemInfo = function(index)
    local item = items.Recipient[index]
    return item.name, item.icon, item.count, item.quality, item.usable, item.enchantment, item.itemID
end
_G.GetTradePlayerItemLink, _G.GetTradeTargetItemLink = function() return "native-link" end, function() return "native-link" end
_G.SetItemButtonTexture = function(button, texture) button.icon:SetTexture(texture) end
_G.SetItemButtonCount = function(button, count) button.count = count end
_G.SetItemButtonQuality = function(button, quality) button.nativeQuality = quality; button.IconBorder:SetAlpha(1) end
_G.SetItemButtonTextureVertexColor = function(button, ...) button.icon:SetVertexColor(...) end
_G.SetItemButtonNameFrameVertexColor, _G.SetItemButtonSlotVertexColor = function() end, function() end
_G.tCompare = function(a, b) return a.id == b.id and a.quantity == b.quantity and a.name == b.name end
local callback, refresh
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_UIPanels_Game" then callback = fn end end
ns.Registry = {Register = function(_, key, definition) if key == "skinTrade" then refresh = definition.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callback()
assert(_G.TradeRecipientMoneyBg:GetAlpha() == 1 and _G.TradeRecipientMoneyBg.art:GetAlpha() == 0 and skin.GetBackdrop(_G.TradeRecipientMoneyBg)._quiRoundedSurface.radius == 4,
    "native gold money inset must be replaced with rounded chrome")
for _, side in ipairs({"Player", "Recipient"}) do
    for index = 1, 7 do
        if side == "Player" then _G.TradeFrame_UpdatePlayerItem(index) else _G.TradeFrame_UpdateTargetItem(index) end
        local prefix = "Trade" .. side .. "Item" .. index
        local row, button = _G[prefix], _G[prefix .. "ItemButton"]
        assert(row.SlotTexture:GetAlpha() == 0 and row.enchantGlyph:GetAlpha() == 1, "decorative row art must be suppressed while semantic glyphs survive")
        assert(skin.GetBackdrop(button)._quiRoundedSurface.radius == 4 and button.icon.texture == 100 + index
            and button.count == index and button.nativeQuality == 3, "all fourteen item slots must retain native item art/count/quality")
        assert(button:GetScript("OnClick") == button.nativeClick and button:GetScript("OnReceiveDrag") == button.nativeDrag,
            "native item interactions must survive")
    end
end
local target = _G.TradeRecipientItem1ItemButton
items.Recipient[1].usable, items.Recipient[1].quality = false, 4
_G.TradeFrame_UpdateTargetItem(1)
assert(skin.GetBackdrop(_G.TradeRecipientItem1)._quiBorderR == 0.9 and target.icon.vertex[2] == 0
    and skin.GetBackdrop(target)._quiBorderR == 0.6, "native unusable feedback and current item quality must survive")
items.Player[7].enchantment = "Native enchantment"
_G.TradeFrame_UpdatePlayerItem(7)
assert(_G.TradePlayerItem7Name:GetText() == "|cff00ff00Native enchantment|r", "native enchantment markup must survive")
for _, states in ipairs({{1, 0}, {0, 1}, {1, 1}, {0, 0}}) do
    _G.TradeFrame_SetAcceptState(states[1], states[2])
    assert(_G.TradeHighlightPlayer:IsShown() == (states[1] == 1)
        and _G.TradeHighlightRecipient:IsShown() == (states[2] == 1)
        and action:IsEnabled() == (states[1] == 0), "native acceptance and action state must survive")
end
warning = true
_G.TradeFrame_UpdateWarnings()
assert(action.WarningIcon:IsShown() and action.WarningIcon:GetAlpha() == 1 and action.warningTooltip,
    "functional offer-change warning must remain visible after button skinning")
warning = false
_G.TradeFrame_UpdateWarnings()
assert(not action.WarningIcon:IsShown() and action.warningTooltip == nil, "native warning dismissal must survive")
assert(_G.TradeRecipientMoneyFrame.quantity:GetText() == "Native money", "native recipient money formatting must survive")
local border = skin.GetBackdrop(target)
border._quiBorderR = -1
refresh()
assert(border._quiBorderR == 0.6 and skin.GetBackdrop(target) == border and maskCount == 14,
    "theme refresh must retain quality and reuse every icon mask")
print("OK: trade_surfaces_test")
