local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinReadyCheck = true
_G.ReadyCheckFrame = env.NewFrame("Frame")
_G.ReadyCheckListenerFrame = nil
local clicks = 0
for _, name in ipairs({ "ReadyCheckFrameYesButton", "ReadyCheckFrameNoButton" }) do
    local button = env.NewFrame("Button", nil, _G.ReadyCheckFrame)
    for _, key in ipairs({ "Left", "Right", "Middle", "LeftSeparator", "RightSeparator", "NineSlice" }) do button[key] = false end
    button.Text = button:CreateFontString()
    button:SetScript("OnClick", function() clicks = clicks + 1 end)
    _G[name] = button
end
_G.ReadyCheckFrameText = _G.ReadyCheckFrame:CreateFontString()
env.ns.WhenLoggedIn = function(callback) callback() end
assert(loadfile(os.getenv("QUI_READY_SOURCE") or "modules/skinning/notifications/readycheck.lua"))("QUI", env.ns)
local surface = _G.ReadyCheckFrame._quiRoundedSurface
assert(surface and surface.radius == 8, "ready-check shell must use rounded parent-owned textures")
assert(_G.ReadyCheckFrameYesButton._quiRoundedSurface.radius == 5, "ready-check actions must use rounded parent-owned textures")
for _, regions in ipairs({ surface.fill, surface.border }) do
    for _, texture in pairs(regions) do
        assert(env.SkinBase.GetFrameData(texture, "readyCheckOwnedTexture"), "rounded textures must survive native decoration suppression")
        assert(texture:GetParent() == _G.ReadyCheckFrame, "ready-check chrome must not cover text with a child frame")
    end
end
_G.ReadyCheckFrameYesButton:Fire("OnClick")
assert(clicks == 1, "ready-check actions must preserve native ownership")
print("OK: readycheck_rounded_texture_surface_test")
