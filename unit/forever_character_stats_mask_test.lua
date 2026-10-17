local Harness = dofile("tests/helpers/character_chrome_harness.lua")

for _, gates in ipairs({ { false, false }, { false, true }, { true, false }, { true, true } }) do
    local env = Harness.Build()
    env.SetGates(gates[1], gates[2])
    local character = env.BuildCharacterFrame()
    local legacy = _G.CharacterStatsPane
    local native = _G.CreateFrame("Frame", nil, character)
    native.ClassBackground = native:CreateTexture(nil, "BACKGROUND")
    native:EnableMouse(true)
    function character:GetStatsPane() return native end

    env.Chrome.Initialize()
    env.Chrome.EnsureShell({ extended = gates[2] })
    assert(native:GetAlpha() == (gates[2] and 0 or 1),
        "the active Forever stats pane must be masked only for the enhancement")
    assert(native.mouse == not gates[2], "native mouse ownership follows the enhancement")
    assert(legacy:GetAlpha() == 1 and legacy.ClassBackground:GetAlpha() == 1,
        "the inactive legacy stats pane must remain untouched")

    if gates[2] then
        env.Chrome.RestoreNativeStatsPane()
        assert(native:GetAlpha() == 1 and native.mouse == true,
            "native fallback restores visible interactive stats")
        assert(native.ClassBackground:GetAlpha() == 1, "native fallback restores class art")
        env.SetGates(gates[1], false)
        env.Chrome.EnsureShell({ extended = false })
        assert(native:GetAlpha() == 1 and native.mouse == true,
            "disabling enhancement preserves native fallback")
    end
end

local env = Harness.Build()
local character = env.BuildCharacterFrame()
character.GetStatsPane = false
assert(env.Chrome.GetNativeStatsPane() == _G.CharacterStatsPane, "legacy client keeps its native pane")
function character:GetStatsPane() return nil end
assert(env.Chrome.GetNativeStatsPane() == _G.CharacterStatsPane, "unavailable native pane uses legacy fallback")
env.Chrome.MaskNativeStatsPane()
assert(_G.CharacterStatsPane:GetAlpha() == 0 and _G.CharacterStatsPane.mouse == false,
    "legacy pane remains masked for enhancement")
env.Chrome.RestoreNativeStatsPane()
assert(_G.CharacterStatsPane:GetAlpha() == 1 and _G.CharacterStatsPane.mouse == true,
    "legacy fallback remains visible and interactive")

print("OK: forever_character_stats_mask_test")
