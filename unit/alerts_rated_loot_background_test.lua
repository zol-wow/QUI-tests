-- Exercise the real deferred loot setup hook on first acquire and pooled reuse.
local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
_G.C_Item.GetItemQualityByID = function() return 4 end
_G.C_Item.GetItemQualityColor = function() return 0.64, 0.21, 0.93 end
local frame = env.NewFrame("Button")
frame.hyperlink = "item:123"
frame.Icon = frame:CreateTexture()
frame.Icon:SetTexture("native-weapon")
frame.Label = frame:CreateFontString()
frame.Name = frame:CreateFontString()
local nativeClick = function() end
frame:SetScript("OnClick", nativeClick)
for _, key in ipairs({"Background", "BGAtlas", "PvPBackground", "RatedPvPBackground"}) do
    frame[key] = frame:CreateTexture()
end
_G.LootAlertSystem = {setUpFunction = function(owner, rated)
    owner.RatedPvPBackground:SetAtlas("pvprated-loottoast-bg-horde")
    owner.RatedPvPBackground:SetAlpha(1)
    owner.RatedPvPBackground:SetShown(rated)
    owner.Name:SetText("Native weapon")
    owner.Name:SetTextColor(0.64, 0.21, 0.93, 1)
end}
assert(loadfile("modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
for _, rated in ipairs({true, false, true}) do
    _G.LootAlertSystem.setUpFunction(frame, rated)
    env.RunTimers()
    assert(frame.RatedPvPBackground:GetAlpha() == 0,
        "rated loot ornamental background must stay suppressed on first setup and reuse")
    assert(frame.Icon:GetAlpha() == 1 and frame.Icon.texture == "native-weapon",
        "native reward icon must survive")
    assert(frame.Name:GetText() == "Native weapon" and frame.Name.textColor[1] == 0.64,
        "native reward name and quality color must survive")
    assert(frame:GetScript("OnClick") == nativeClick, "native loot navigation must survive")
end
print("rated loot alert background reuse: ok")
