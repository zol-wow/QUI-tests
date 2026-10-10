local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
local frame = env.NewFrame('Frame')
local px = 1
env.core.GetPixelSize = function() return px end
local left, bottom = 100.2, 200.7
frame.GetLeft = function() return left end
frame.GetBottom = function() return bottom end
frame:SetSize(37.4, 39.3)
env.SkinBase.ApplyChromeBackdrop(frame, { radius = 3, withBackground = false })
local surface = frame._quiRoundedSurface
for _, regions in ipairs({ surface.fill, surface.border }) do
    for _, texture in pairs(regions) do
        texture.SetPoint = function(self, point, ...)
            for index, existing in ipairs(self.points) do
                if existing[1] == point then self.points[index] = { point, ... }; return end
            end
            self.points[#self.points + 1] = { point, ... }
        end
    end
end
local function Check()
    for _, regions in ipairs({ surface.fill, surface.border }) do
        for _, texture in pairs(regions) do
            for _, point in ipairs(texture.points) do
                local anchor, x, y = point[1], point[4], point[5]
                local absoluteX = left + (anchor:find('RIGHT') and frame:GetWidth() or 0) + x
                local absoluteY = bottom + (anchor:find('TOP') and frame:GetHeight() or 0) + y
                absoluteX, absoluteY = absoluteX / px, absoluteY / px
                assert(math.abs(absoluteX - math.floor(absoluteX + 0.5)) < 0.00001,
                    'rounded border pieces must share integer physical X coordinates')
                assert(math.abs(absoluteY - math.floor(absoluteY + 0.5)) < 0.00001,
                    'rounded border pieces must share integer physical Y coordinates')
            end
        end
    end
    assert(surface.border.left.width == px and surface.border.top.height == px,
        'alignment must retain one physical pixel edges')
end
Check()
for i = 1, 25 do
    left, bottom = 100 + i * 0.13, 200 + i * 0.17
    frame:Fire('OnUpdate', 0.016)
    Check()
end
for _, scalePixel in ipairs({ 0.741659224, 1.25, 2 }) do
    px = scalePixel
    env.SkinBase.ApplyChromeBackdrop(frame, { radius = 3, withBackground = false })
    for i = 1, 25 do
        left, bottom = 100 + i * 0.13, 200 + i * 0.17
        frame:Fire('OnUpdate', 0.016)
        Check()
    end
end
local points = surface.border.left.points
frame:Fire('OnUpdate', 0.016)
assert(surface.border.left.points == points, 'stationary surfaces must not rebuild their geometry each frame')
print('OK rounded_surface_pixel_snap_test')
