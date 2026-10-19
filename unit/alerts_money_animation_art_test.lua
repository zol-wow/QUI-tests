-- Live money-toast animation restores texture alpha without a Lua SetAlpha call.
-- Exercise the real deferred setup, then model that observed engine-side reset.
local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(f, ...) f:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(f, ...) f:SetBackdropColor(...) end
local frame = env.NewFrame("Frame")
for _, key in ipairs({"Background", "IconBorder", "Icon"}) do
    frame[key] = frame:CreateTexture()
    frame[key]:SetTexture(key == "Icon" and "native-coins" or "native-gold-art")
    frame[key]:Show()
end
frame.Label = frame:CreateFontString()
frame.Amount = frame:CreateFontString()
_G.MoneyWonAlertSystem = {setUpFunction = function(owner, amount)
    owner.Amount:SetText(amount)
end}
assert(loadfile("modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
for _, amount in ipairs({"497918 gold 76 silver 59 copper", "1 copper"}) do
    _G.MoneyWonAlertSystem.setUpFunction(frame, amount)
    env.RunTimers()
    for _, key in ipairs({"Background", "IconBorder"}) do
        frame[key]:SetAlpha(1)
        assert(not frame[key]:IsShown() or frame[key].texture == nil,
            "native money art must remain suppressed when animation restores alpha")
    end
    assert(frame.Icon.texture == "native-coins" and frame.Icon:IsShown(), "coin icon must survive")
    assert(frame.Amount:GetText() == amount, "native formatted money must survive pooled reuse")
end
print("money alert animation artwork: ok")
