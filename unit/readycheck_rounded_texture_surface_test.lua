local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinReadyCheck = true
_G.ReadyCheckFrame = env.NewFrame("Frame")
_G.ReadyCheckListenerFrame = nil
local clicks = 0
local nativeArt = {}
for _, name in ipairs({ "ReadyCheckFrameYesButton", "ReadyCheckFrameNoButton" }) do
    local button = env.NewFrame("Button", nil, _G.ReadyCheckFrame)
    for _, key in ipairs({ "Left", "Right", "Middle", "LeftSeparator", "RightSeparator", "NineSlice" }) do button[key] = false end
    button.Text = button:CreateFontString()
    for _, layer in ipairs({ "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }) do
        local texture = button:CreateTexture(nil, layer)
        texture:SetTexture(layer == "HIGHLIGHT" and 130826 or "native-button-state")
        nativeArt[#nativeArt + 1] = texture
    end
    button:SetScript("OnClick", function() clicks = clicks + 1 end)
    _G[name] = button
end
_G.ReadyCheckFrameText = _G.ReadyCheckFrame:CreateFontString()
env.ns.WhenLoggedIn = function(callback) callback() end
assert(loadfile(os.getenv("QUI_READY_SOURCE") or "modules/skinning/notifications/readycheck.lua"))("QUI", env.ns)
for _, texture in ipairs(nativeArt) do
    assert(texture:GetAlpha() == 0, "native button art must be hidden on every draw layer")
    texture:SetAlpha(1)
    assert(texture:GetAlpha() == 0, "native state refresh must not revive button art")
end
for _, button in ipairs({ _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton }) do
    for _, regions in ipairs({ button._quiRoundedSurface.fill, button._quiRoundedSurface.border }) do
        for _, texture in pairs(regions) do
            assert(texture:GetAlpha() > 0, "QUI rounded button art must survive native-art suppression")
        end
    end
    button:Fire("OnEnter")
    button:Fire("OnLeave")
end
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
