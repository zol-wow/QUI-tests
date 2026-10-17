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
local background = frame.regions[1]
local edges = {}
for _, texture in ipairs(frame.regions) do
    if texture.layer == 'BORDER' then edges[#edges + 1] = texture end
end
assert(#edges == 4, 'square fallback must reuse the four existing manual edges')
for _, thickness in ipairs({ 4, 8, 10, 0 }) do
    env.SkinBase.ApplyChromeBackdrop(frame, { radius = 4, borderPixels = thickness, withBackground = true })
    assert(not surface.shown and not surface.background:IsShown(), 'unsupported stroke widths must hide previous rounded art')
    for _, texture in pairs(surface.border) do assert(not texture:IsShown(), 'square fallback must hide every rounded edge') end
    assert(background:IsShown(), 'square fallback must retain its background')
    for _, edge in ipairs(edges) do
        assert(edge:IsShown() == (thickness > 0), 'border zero must hide all edges; thicker borders must remain visible')
        if thickness > 0 then
            assert((edge.width or edge.height) == thickness, 'square fallback must honor the requested physical stroke width')
        end
    end
    env.SkinBase.ApplyChromeBackdrop(frame, { radius = 4, borderPixels = 2, withBackground = true })
    assert(frame._quiRoundedSurface == surface and surface.shown and surface.background:IsShown(),
        'supported widths must restore the existing rounded surface')
    assert(not background:IsShown(), 'rounded restoration must hide the square background')
    for _, edge in ipairs(edges) do assert(not edge:IsShown(), 'rounded restoration must hide square edges') end
end
env.SkinBase.ApplyChromeBackdrop(frame, { radius = 4, borderPixels = 10, withBackground = true })
local refreshCalls = 0
local refresh = surface.Refresh
surface.Refresh = function(self) refreshCalls = refreshCalls + 1; return refresh(self) end
frame.GetLeft = function() return 100.5 end
frame:Fire('OnUpdate', 0.016)
assert(refreshCalls == 0, 'hidden rounded geometry must not refresh while its square fallback moves')
local square = env.NewFrame('Frame')
env.SkinBase.ApplyChromeBackdrop(square, { radius = 4, borderPixels = 10, withBackground = true })
assert(not square._quiRoundedSurface, 'unsupported widths must not allocate rounded geometry')
print('OK rounded_surface_stroke_width_test')
