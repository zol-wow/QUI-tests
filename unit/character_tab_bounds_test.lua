local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(arg[1] or "modules/skinning/frames/character_chrome.lua"))
local source = file:read("*a")
file:close()
assert(loadstring(source))("QUI", env.ns)
local chrome = env.ns.CharacterChrome
local frame = env.BuildCharacterFrame()
env.profile.general.skinCharacterFrame = true
env.profile.character.enabled = true
local shell = chrome.SetExtended(true)
local before = { shell:GetPoint(2) }
assert(before[5] == -82, "shared shell must enclose the tab footer")
frame:SetWidth(400)
ReputationFrame.ScrollBox = env.NewFrame("Frame", nil, ReputationFrame)
TokenFrame.ScrollBox = env.NewFrame("Frame", nil, TokenFrame)
chrome.SetExtended(false)
local after = { shell:GetPoint(2) }
assert(after[3] == "BOTTOMLEFT" and after[4] == 595, "non-character tabs must retain the full Character shell width")
assert(after[5] == before[5], "non-character tabs must retain the Character shell height")
for _, pane in ipairs({ ReputationFrame, TokenFrame }) do
    assert(pane.allPoints == shell, "Reputation and Currency must fill the shared shell")
    local bottom = { pane.ScrollBox:GetPoint(1) }
    assert(bottom[2] == shell and bottom[4] == -28 and bottom[5] == 42, "lists must stop above the integrated tab footer")
end
print("OK: character_tab_bounds_test")
