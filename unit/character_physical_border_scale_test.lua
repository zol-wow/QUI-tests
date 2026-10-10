local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
local skin = env.SkinBase
assert(skin.UsePhysicalPixelScale, 'character borders need a reusable physical pixel scale helper')
local frame = env.NewFrame('Frame')
local physicalHeight = 1321
frame.SetIgnoreParentScale = function(self, value) self.ignoreParentScale = value end
env.core.GetPixelPerfectScale = function() return 768 / physicalHeight end
skin.UsePhysicalPixelScale(frame)
assert(frame.ignoreParentScale == true, 'native one-pixel outlines must not inherit fractional panel scaling')
assert(frame.scale == 768 / physicalHeight, 'one border-local unit must project to one physical pixel')
physicalHeight = 2160
env.UIKit.RefreshScaleBoundWidgets()
assert(frame.scale == 768 / physicalHeight, 'resolution refresh must update the physical border scale')
print('OK character_physical_border_scale_test')
