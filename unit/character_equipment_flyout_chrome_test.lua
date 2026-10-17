local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.SetGates(false, true)
env.BuildCharacterFrame()
local flyout = env.NewFrame("Frame")
flyout.buttonFrame = env.NewFrame("Frame", nil, flyout)
flyout.buttonFrame.bg1 = env.NewTexture(flyout.buttonFrame)
flyout.Highlight = env.NewTexture(flyout)
local item = env.NewFrame("Button", nil, flyout.buttonFrame)
item.IconBorder = env.NewTexture(item)
flyout.buttons = { item }
_G.EquipmentFlyoutFrame = flyout
env.Chrome.Initialize()
local skin = env.SkinBase
local backdrop = skin.GetBackdrop(flyout.buttonFrame)
assert(backdrop, "equipment flyout must be skinned with Character enhancement alone")
assert(skin.GetFrameData(backdrop, "chromeRadius") == 5, "equipment flyout must use rounded chrome")
local bottomRight = { backdrop:GetPoint(2) }
assert(bottomRight[1] == "BOTTOMRIGHT" and bottomRight[4] > 0, "flyout border must include padding beyond the rightmost icon")
assert(flyout.buttonFrame.bg1:GetAlpha() == 0, "native flyout framing must be suppressed")
assert(item.IconBorder:GetAlpha() == 0, "item outlines must not double the flyout border")
assert(flyout.Highlight:GetAlpha() == 0, "native source-slot framing must not add a second outline")
print("OK character_equipment_flyout_chrome_test")
