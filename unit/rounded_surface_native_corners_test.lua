local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
local frame = env.NewFrame('Frame')
local create = frame.CreateTexture
frame.CreateTexture = function(self, ...)
    local texture = create(self, ...)
    local set = texture.SetTexture
    texture.SetTexture = function(t, path, wrapX, wrapY, filter)
        set(t, path)
        t.filter = filter
    end
    return texture
end
for radius = 1, 16 do
    env.SkinBase.ApplyChromeBackdrop(frame, { radius = radius, withBackground = false })
    local surface = frame._quiRoundedSurface
    for _, regions in ipairs({ surface.fill, surface.border }) do
        for _, name in ipairs({ 'tl', 'tr', 'bl', 'br' }) do
            local texture = regions[name]
            local uv = texture.texCoord
            assert(texture.filter == "NEAREST", "native-size corners must not blur across adjacent atlas texels")
            assert(math.abs(uv[2] - uv[1]) * 2048 == texture.width,
                'rounded corners must sample native-size texels instead of shrinking a 32px tile')
            assert(math.abs(uv[4] - uv[3]) * 32 == texture.height,
                'corner vertical texels must also match physical pixel height')
        end
    end
    assert(surface.border.left.color[4] == 1, 'straight border edges must use opaque solid textures')
end
local file = assert(io.open('assets/appearance/RoundedSurfaceStrokes.tga', 'rb'))
local data = file:read('*a')
file:close()
local function Alpha(tile, x, y)
    return data:byte(18 + (y * 2048 + tile * 32 + x) * 4 + 4)
end
for radius = 3, 16 do
    local tile = radius + 15
    assert(Alpha(tile, 0, 0) <= 20, 'rounded outer corners must leave the square corner transparent')
    assert(Alpha(tile, radius - 1, 0) >= 230, 'rounded outlines must join the top edge without a faded gap')
    assert(Alpha(tile, 0, radius - 1) >= 230, 'rounded outlines must join the side edge without a faded gap')
    assert(Alpha(tile, radius - 1, radius - 1) == 0, 'rounded outlines must not create inner corner dots')
end
env.SkinBase.ApplyChromeBackdrop(frame, { radius = 4, borderPixels = 2, withBackground = false })
assert(frame._quiRoundedSurface.border.left.width == 2 and frame._quiRoundedSurface.border.top.height == 2,
    'two-pixel icon outlines must use matching edge thickness')
assert(Alpha(35, 3, 0) >= 230 and Alpha(35, 3, 1) == 255,
    'two-pixel corner arcs must meet both rows of the straight edge')
print('OK rounded_surface_native_corners_test')
