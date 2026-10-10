local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.SetGates(true, true)
env.BuildCharacterFrame()
_G.CharacterModelScene = env.NewFrame("Frame")
local controls = env.NewFrame("Frame", nil, _G.CharacterModelScene)
_G.CharacterModelScene.ControlFrame = controls
local keys = { "zoomInButton", "zoomOutButton", "rotateLeftButton", "rotateRightButton", "resetButton" }
local callbacks = {}
for _, key in ipairs(keys) do
    local button = env.NewFrame("Button", nil, controls)
    controls[key] = button
    button.Icon = button:CreateTexture()
    button.Icon:SetAtlas("native-gold-model-control")
    for _, field in ipairs({ "Left", "Right", "Middle", "Center", "NormalTexture", "HighlightTexture", "PushedTexture", "DisabledTexture" }) do
        button[field] = false
    end
    callbacks[key] = function() end
    button:SetScript("OnClick", callbacks[key])
end
env.Chrome.Initialize()
for _, key in ipairs(keys) do
    local button = controls[key]
    assert(env.SkinBase.GetBackdrop(button), "each Character model control needs a QUI surface")
    assert(button.Icon:GetAlpha() == 0, "native gold toolbar artwork must be suppressed")
    assert(env.SkinBase.GetFrameData(button, "qCharacterModelGlyph"):GetText() ~= "", "model controls retain visible meaning")
    assert(button:GetScript("OnClick") == callbacks[key], "native model interaction must be preserved")
end
controls.zoomInButton.Icon:SetAlpha(1)
controls:Fire("OnShow")
assert(controls.zoomInButton.Icon:GetAlpha() == 0, "native control initialization cannot restore gold artwork")
print("OK: character_model_controls_test")

assert(controls.buttonHorizontalPadding == 4, "full QUI controls must not retain native negative spacing")
assert(env.SkinBase.GetFrameData(controls.resetButton, "qCharacterModelGlyph"):GetText() == "Reset",
    "reset action needs a glyph supported by the current UI font")
