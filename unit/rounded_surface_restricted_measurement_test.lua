local Secrets = dofile('tests/helpers/secret_sentinel.lua')
local restore = Secrets.InstallSecretStub()
local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
env.ns.Helpers.IsSecretValue = issecretvalue
assert(Secrets.LoadInstrumented(os.getenv('QUI_SKIN_UIKIT_SOURCE') or 'core/uikit.lua'))('QUI', env.ns)
local frame = env.NewFrame('Frame')
frame:SetSize(37.4, 39)
local restricted = true
local measurements = 0
function frame:IsAnchoringRestricted() return restricted end
local function Measure(value)
    measurements = measurements + 1
    assert(restricted == false, 'rounded surfaces must never attempt restricted coordinate measurements')
    return value
end
function frame:GetLeft() return Measure(100.2) end
function frame:GetBottom() return Measure(200.7) end
local surface = env.ns.UIKit.CreateRoundedSurface(frame, { radius = 6 })
local function CheckOffsets(x, y)
    local point = surface.fill.tl.points[#surface.fill.tl.points]
    assert(point[2] == frame, 'restricted surfaces must retain native relative anchors')
    assert(math.abs(point[4] - x) < 0.00001 and math.abs(point[5] - y) < 0.00001,
        'restricted surfaces must clear stale snapping and recover it when measurable')
end
CheckOffsets(0, 0)
assert(surface.cornerSize == 6 and surface.fill.tl.shown and surface.border.tl.shown,
    'initially restricted tooltips must retain visible rounded fill and borders')
assert(measurements == 0, 'initial surface creation must avoid restricted measurements')
restricted = false
frame:Fire('OnUpdate', 0.016)
CheckOffsets(-0.2, 0.3)
for _, restriction in ipairs({ true, Secrets.MakeSecretSentinel() }) do
    restricted = restriction
    measurements = 0
    frame:Fire('OnUpdate', 0.016)
    CheckOffsets(0, 0)
    assert(surface.left == nil and surface.bottom == nil,
        'restricted coordinates must not retain readable movement caches')
    local points = surface.fill.tl.points
    frame:Fire('OnUpdate', 0.016)
    assert(surface.fill.tl.points == points, 'stationary restricted surfaces must reuse their geometry')
    frame:Fire('OnShow')
    frame:SetHeight(4)
    frame:Fire('OnSizeChanged')
    surface:Refresh()
    surface:Hide()
    surface:Show()
    CheckOffsets(0, 0)
    assert(surface.cornerSize == 2 and surface.fill.tl.shown and surface.border.tl.shown,
        'restricted positions must preserve readable size clamping and visible chrome')
    assert(measurements == 0, 'refresh and movement hooks must avoid every restricted measurement')
    restricted = false
    frame:Fire('OnUpdate', 0.016)
    CheckOffsets(-0.2, 0.3)
    assert(measurements > 0, 'unrestricted tooltips must resume coordinate measurement')
    frame:SetHeight(39)
    frame:Fire('OnSizeChanged')
    assert(surface.cornerSize == 6, 'unrestricted resize must restore the configured radius')
end
Secrets.RestoreSecretStub(restore)
print('OK rounded_surface_restricted_measurement_test')
