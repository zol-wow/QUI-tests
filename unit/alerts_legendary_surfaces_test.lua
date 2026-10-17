local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
local skin = env.SkinBase
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
local colors = {[3] = {0, 0.44, 0.87}, [5] = {1, 0.5, 0}}
_G.C_Item.GetItemQualityByID = function(link)
    return ({rare = 3, legendary = 5})[link]
end
_G.C_Item.GetItemQualityColor = function(quality) return unpack(colors[quality]) end
local frame = env.NewFrame("Button")
frame.Icon = frame:CreateTexture()
frame.ItemName = frame:CreateFontString()
local label = frame:CreateFontString()
label:SetText("Legendary Item")
for _, key in ipairs({"Background", "Background2", "Background3", "Ring1", "Particles1", "Particles2", "Particles3", "Starglow"}) do
    frame[key] = frame:CreateTexture()
end
local nativeClick, nativeEnter = function() end, function() end
frame:SetScript("OnClick", nativeClick)
frame:SetScript("OnEnter", nativeEnter)
_G.LegendaryItemAlertSystem = {
    alertFramePool = {EnumerateActive = function() return next, {[frame] = true} end},
    setUpFunction = function(owner, link)
        owner.hyperlink = link
        owner.Icon:SetTexture("native-art-" .. link)
        owner.ItemName:SetText("Native item " .. link)
        local quality = _G.C_Item.GetItemQualityByID(link)
        owner.ItemName:SetTextColor(unpack(colors[quality] or {1, 1, 1}))
        label:SetTextColor(1, 0.82, 0, 1)
        for _, key in ipairs({"Background", "Background2", "Background3"}) do
            owner[key]:SetAtlas("LegendaryToast-background")
            owner[key]:SetAlpha(1)
            owner[key]:Show()
        end
    end,
}
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
local firstBorder
for _, link in ipairs({"legendary", "rare", "unknown", "legendary"}) do
    _G.LegendaryItemAlertSystem.setUpFunction(frame, link)
    env.RunTimers()
    local border = skin.GetFrameData(frame, "iconBorder")
    firstBorder = firstBorder or border
    assert(border == firstBorder, "reused alerts must retain one icon border")
    local expected = colors[_G.C_Item.GetItemQualityByID(link)]
    if not expected then
        local r, g, b = skin.GetWindowColors(env.profile.general, "alerts")
        expected = {r, g, b}
    end
    assert(border._quiBorderR == expected[1] and border._quiBorderG == expected[2] and border._quiBorderB == expected[3],
        "item border must follow current quality and clear stale quality")
    assert(label.textColor[3] > 0.9, "legendary caption must use neutral QUI alert text")
    assert(frame.Icon.texture == "native-art-" .. link, "native item artwork must survive")
    assert(frame.ItemName:GetText() == "Native item " .. link, "native item name must survive")
    local native = colors[_G.C_Item.GetItemQualityByID(link)] or {1, 1, 1}
    assert(frame.ItemName.textColor[1] == native[1] and frame.ItemName.textColor[3] == native[3],
        "native item-name quality color must survive")
    for _, key in ipairs({"Background", "Background2", "Background3"}) do
        assert(frame[key]:GetAlpha() == 0 and not frame[key]:IsShown(), "native toast chrome must stay suppressed on reuse")
    end
    assert(frame:GetScript("OnClick") == nativeClick and frame:GetScript("OnEnter") == nativeEnter,
        "native item navigation and tooltip handlers must survive")
    border._quiBorderR, border._quiBorderG, border._quiBorderB = 0.11, 0.22, 0.33
    _G.QUI_RefreshAlertColors()
    assert(border._quiBorderR == expected[1] and border._quiBorderG == expected[2] and border._quiBorderB == expected[3],
        "theme refresh must preserve the current item quality")
end
print("OK: alerts_legendary_surfaces_test")
