local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
local frame = env.NewFrame('Frame')
local left, bottom = 100.2, 200.7
frame.GetLeft = function() return left end
frame.GetBottom = function() return bottom end
env.ns.UIKit.CreateRoundedSurface(frame, { radius = 6 })
local geometryCalls = 0
local function Geometry() geometryCalls = geometryCalls + 1 end
local function Point() end
for _, regions in ipairs({ frame._quiRoundedSurface.fill, frame._quiRoundedSurface.border }) do
    for _, texture in pairs(regions) do
        texture.SetPoint = Point
        texture.ClearAllPoints = Geometry
        texture.SetSize = Geometry
        texture.SetWidth = Geometry
        texture.SetHeight = Geometry
        texture.SetTexCoord = Geometry
    end
end
local update = frame.hooks.OnUpdate[1]
for i = 1, 10 do left, bottom = left + 0.13, bottom + 0.17; update() end
geometryCalls = 0
collectgarbage('collect')
collectgarbage('stop')
local before = collectgarbage('count')
for i = 1, 1000 do
    left, bottom = left + 0.13, bottom + 0.17
    update()
end
local allocated = collectgarbage('count') - before
collectgarbage('restart')
assert(allocated < 16, 'moving rounded surfaces must not allocate tables or closures each frame: ' .. allocated .. ' KB')
assert(geometryCalls == 0, 'movement must update offsets without resetting size, UVs, or anchors')
left, bottom = left + 1, bottom + 1
local points = 0
for _, regions in ipairs({ frame._quiRoundedSurface.fill, frame._quiRoundedSurface.border }) do
    for _, texture in pairs(regions) do texture.SetPoint = function() points = points + 1 end end
end
update()
assert(points == 0, 'whole-pixel movement must reuse unchanged offsets')
frame:SetWidth(120)
frame:Fire('OnSizeChanged')
assert(geometryCalls > 0, 'resizing must still refresh rounded surface geometry')
print('OK rounded_surface_movement_test: ' .. allocated .. ' KB allocated across 1000 moving updates')
