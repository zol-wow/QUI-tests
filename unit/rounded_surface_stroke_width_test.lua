local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
local frame = env.NewFrame('Frame')
env.SkinBase.ApplyChromeBackdrop(frame, { radius = 4, borderPixels = 2, withBackground = false })
local surface = frame._quiRoundedSurface
assert(surface.border.left.width == 2 and surface.border.right.width == 2,
    'rounded icon outlines must honor two physical pixels on both vertical edges')
assert(surface.border.top.height == 2 and surface.border.bottom.height == 2,
    'rounded icon outlines must honor two physical pixels on both horizontal edges')
assert(surface.border.tl.texCoord[1] == 35 / 64,
    'two-pixel edges must use the matching two-pixel rounded corner stroke')
env.SkinBase.ApplyChromeBackdrop(frame, { radius = 4, borderPixels = 1, withBackground = false })
assert(surface.border.left.width == 1 and surface.border.top.height == 1,
    'ordinary surfaces must retain their requested one-pixel stroke')
assert(surface.border.tl.texCoord[1] == 19 / 64,
    'changing stroke width must update corner artwork without recreating the surface')
print('OK rounded_surface_stroke_width_test')
