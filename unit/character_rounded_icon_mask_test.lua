local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
assert(skin.RoundIconTexture, "Character icons must expose a shared rounded mask helper")
local slot = env.NewFrame("Button")
slot.CreateMaskTexture = slot.CreateTexture
local icon = slot:CreateTexture()
local attached, calls
calls = 0
icon.AddMaskTexture = function(_, mask) attached = mask; calls = calls + 1 end
skin.RoundIconTexture(slot, icon)
assert(attached and attached.texture:find("RoundedIconMask.tga", 1, true), "icons must use the soft square mask")
skin.RoundIconTexture(slot, icon)
assert(calls == 1, "repeated slot updates must reuse the existing mask")
local second = slot:CreateTexture()
second.AddMaskTexture = function(_, mask) assert(mask ~= attached, "hover and icon textures require independent masks") end
skin.RoundIconTexture(slot, second)
local border = env.NewFrame("Frame")
border._quiBgR, border._quiBgG, border._quiBgB, border._quiBgA = 1, 1, 1, 1
skin.ApplyChromeBackdrop(border, { radius = 3, withBackground = false })
assert(border._quiRoundedSurface.background.color[4] == 0, "rounded icon borders must never cover icons with a fill")
print("OK character_rounded_icon_mask_test")
