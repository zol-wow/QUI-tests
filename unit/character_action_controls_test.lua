local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(arg[1] or "modules/skinning/frames/character_chrome.lua"))
local source = file:read("*a")
file:close()
assert(loadstring(source))("QUI", env.ns)
local chrome = env.ns.CharacterChrome
assert(chrome.StyleActionButton, "character actions must expose the shared rounded button style")
local slot = env.NewFrame("Frame")
local button = env.NewFrame("Button", nil, slot)
setmetatable(button, { __index = function(_, key)
    if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
end })
local clicks = 0
button:SetScript("OnClick", function() clicks = clicks + 1 end)
chrome.StyleSlotFlyoutButton(button)
assert(button:GetFrameLevel() > slot:GetFrameLevel() + 10, "slot controls must draw above item text and border overlays")
local skin = env.SkinBase
local backdrop = skin.GetBackdrop(button)
assert(backdrop and skin.GetFrameData(backdrop, "chromeRadius") == 4, "slot flyouts must use rounded QUI chrome")
assert(backdrop._quiBgA == 1 and backdrop._quiBgR == 0.12, "slot controls must have an opaque contrasting fill")
local carets = skin.GetFrameData(button, "slotFlyoutCarets")
assert(carets and carets[1]:IsShown() and not carets[2]:IsShown(), "closed horizontal slot flyouts must show the forward caret")
button.flyoutLocked = true
chrome.StyleSlotFlyoutButton(button)
assert(not carets[1]:IsShown() and carets[2]:IsShown(), "slot caret must follow the native locked state")
slot.verticalFlyout = true
chrome.StyleSlotFlyoutButton(button)
assert(carets[1]:IsShown() and not carets[2]:IsShown() and button.width == 20 and button.height == 14, "vertical slot controls must match their orientation")
button:Fire("OnClick")
assert(clicks == 1, "restyling must preserve the native slot action")
print("OK: character_action_controls_test")
