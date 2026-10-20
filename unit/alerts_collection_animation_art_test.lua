local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(f, ...) f:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(f, ...) f:SetBackdropColor(...) end
local frame = env.NewFrame("Button")
for _, key in ipairs({"Icon", "IconBorder", "glow", "shine"}) do
    frame[key] = frame:CreateTexture()
end
frame.Label = frame:CreateFontString()
frame.Name = frame:CreateFontString()
local nativeClick = function() end
frame:SetScript("OnClick", nativeClick)
_G.NewPetAlertSystem = {setUpFunction = function(owner, name)
    owner.Name:SetText(name)
    owner.Icon:SetTexture("native-pet")
end}
assert(loadfile("modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
for _, name in ipairs({"Gryphon Hatchling", "Benax"}) do
    _G.NewPetAlertSystem.setUpFunction(frame, name)
    -- AlertFrame_ShowNewAlert shows and animates these after native setup.
    for _, key in ipairs({"glow", "shine"}) do
        frame[key]:SetTexture("native-loottoast-effect")
        frame[key]:Show()
    end
    env.RunTimers()
    for _, key in ipairs({"glow", "shine"}) do
        assert(not frame[key]:IsShown() and frame[key].texture == nil,
            "collection toast must suppress animated Blizzard glow and shine on first acquire and reuse")
    end
    assert(frame.Name:GetText() == name and frame.Icon.texture == "native-pet", "collection data must survive")
    assert(frame:GetScript("OnClick") == nativeClick, "native collection navigation must survive")
end
print("collection alert animated artwork: ok")
