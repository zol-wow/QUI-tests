local Secrets = dofile('tests/helpers/secret_sentinel.lua')
local restore = Secrets.InstallSecretStub()
local env = dofile('tests/helpers/character_chrome_harness.lua').Build()
env.ns.Helpers.IsSecretValue = issecretvalue
assert(Secrets.LoadInstrumented(os.getenv('QUI_SKIN_UIKIT_SOURCE') or 'core/uikit.lua'))('QUI', env.ns)
local frame = env.NewFrame('Frame')
local left, bottom, width, height = 100.2, 200.7, 37.4, 39
frame.GetLeft = function() return left end
frame.GetBottom = function() return bottom end
frame.GetWidth = function() return width end
frame.GetHeight = function() return height end
local surface = env.ns.UIKit.CreateRoundedSurface(frame, { radius = 6 })
local secret = Secrets.MakeSecretSentinel()
local function CheckOffsets(x, y)
    local point = surface.fill.tl.points[#surface.fill.tl.points]
    assert(math.abs(point[4] - x) < 0.00001 and math.abs(point[5] - y) < 0.00001,
        'corners must drop stale snapping while geometry is secret and resnap when readable')
end
CheckOffsets(-0.2, 0.3)
left = secret
frame:Fire('OnUpdate', 0.016)
CheckOffsets(0, 0)
assert(not issecretvalue(surface.left) and not issecretvalue(surface.bottom),
    'movement caches must never retain secret coordinates')
local points = surface.fill.tl.points
frame:Fire('OnUpdate', 0.016)
assert(surface.fill.tl.points == points, 'unreadable stationary geometry must reuse its textures')
left, bottom = 100.4, 200.6
frame:Fire('OnUpdate', 0.016)
CheckOffsets(-0.4, 0.4)
bottom = secret
frame:Fire('OnUpdate', 0.016)
CheckOffsets(0, 0)
left, bottom = secret, secret
surface:Refresh()
CheckOffsets(0, 0)
left, bottom = 100.2, 200.7
width = secret
frame:Fire('OnSizeChanged')
assert(surface.cornerSize == 6 and not issecretvalue(surface.width),
    'secret width must preserve configured corners without arithmetic or unsafe caching')
CheckOffsets(0, 0)
width, height = 8, secret
frame:Fire('OnShow')
assert(surface.cornerSize == 4 and not issecretvalue(surface.height),
    'readable width must still clamp corners when height is secret')
CheckOffsets(0, 0)
width, height = secret, secret
surface:Refresh()
assert(surface.cornerSize == 6, 'fully secret dimensions must retain configured corners')
width, height = 37.4, 4
frame:Fire('OnSizeChanged')
assert(surface.cornerSize == 2, 'readable dimensions must restore the small-frame radius clamp')
CheckOffsets(-0.2, 0.3)
left, bottom, width, height = secret, secret, secret, secret
local initialFrame = env.NewFrame('Frame')
initialFrame.GetLeft, initialFrame.GetBottom = frame.GetLeft, frame.GetBottom
initialFrame.GetWidth, initialFrame.GetHeight = frame.GetWidth, frame.GetHeight
local initial = env.ns.UIKit.CreateRoundedSurface(initialFrame, { radius = 6 })
assert(initial.cornerSize == 6 and initial.fill.tl.shown and initial.border.tl.shown,
    'initial secret geometry must still create visible configured corners and borders')
initialFrame:Fire('OnUpdate', 0.016)
left, bottom, width, height = 100.2, 200.7, 37.4, 4
initialFrame:Fire('OnSizeChanged')
assert(initial.cornerSize == 2, 'initially unreadable frames must recover native radius clamping')
Secrets.RestoreSecretStub(restore)
print('OK rounded_surface_secret_geometry_test')
