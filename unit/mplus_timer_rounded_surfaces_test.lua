local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin = env.SkinBase
env.profile.mplusTimer = {showBorder = true, frameBackgroundOpacity = 0.5, forcesTextColor = {0.3, 0.8, 0.4, 1}}
skin.GetWindowColors = function() return 0.6, 0.7, 0.8, 1, 0.1, 0.2, 0.3, 0.8 end
skin.GetSkinColors = function() return 0.4, 0.5, 0.6 end
skin.GetSkinBarColor = function() return 0.4, 0.5, 0.6 end
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
env.ns.Helpers.ApplyBarStyle = function() end
local function NativeFrame()
    local frame = env.NewFrame("Frame")
    skin.CreateBackdrop(frame, 0.6, 0.7, 0.8, 1, 0.1, 0.2, 0.3, 0.8)
    return frame, skin.GetBackdrop(frame)
end
local root, rootBackdrop = NativeFrame()
local sleek, sleekBackdrop = NativeFrame()
sleek.CreateMaskTexture = sleek.CreateTexture
local attachments = 0
local function Maskable(owner)
    local texture = owner:CreateTexture()
    function texture:AddMaskTexture() attachments = attachments + 1 end
    return texture
end
local bars = {}
local originalBackdrops = {}
for _, key in ipairs({1, 2, 3, "forces"}) do
    local frame, backdrop = NativeFrame()
    local bar = env.NewFrame("StatusBar", nil, frame)
    bar.CreateMaskTexture = bar.CreateTexture
    local fill = Maskable(bar)
    function bar:GetStatusBarTexture() return fill end
    function bar:SetStatusBarColor(...) self.color = {...} end
    bar.value, bar.minValue, bar.maxValue = 17, 0, 100
    bars[key] = {frame = frame, bar = bar, text = frame:CreateFontString()}
    if key == "forces" then bars[key].overlay = Maskable(bar) end
    originalBackdrops[key] = backdrop
end
local segments = {Maskable(sleek), Maskable(sleek), Maskable(sleek)}
_G.QUI_MPlusTimer = {frames = {root = root, sleekBar = sleek}, bars = bars, sleekSegments = segments}
assert(loadfile(os.getenv("QUI_MPLUS_SKIN_SOURCE") or "modules/skinning/gameplay/mplus_timer.lua"))("QUI", env.ns)
_G.QUI_ApplyMPlusTimerSkin()
assert(skin.GetFrameData(root, "backdrop") == rootBackdrop, "timer must reuse its existing root backdrop")
assert(rootBackdrop._quiRoundedSurface and rootBackdrop._quiBgA == 0.4, "root needs rounded chrome and configured opacity")
assert(skin.GetBackdrop(sleek) == sleekBackdrop and sleekBackdrop._quiRoundedSurface.radius == 3, "sleek bar must reuse and round its existing backdrop")
for key, entry in pairs(bars) do
    local backdrop = skin.GetBackdrop(entry.frame)
    assert(backdrop == originalBackdrops[key] and backdrop._quiRoundedSurface.radius == 3,
        "every timer and forces bar must reuse rounded native background")
    assert(entry.bar.value == 17 and entry.bar.minValue == 0 and entry.bar.maxValue == 100,
        "skinning must preserve progress values and ranges")
end
assert(bars[2].bar.color[1] == 0.95 and bars[3].bar.color[2] == 0.85, "timer threshold colors must survive")
assert(bars.forces.text.textColor[1] == 0.3 and bars.forces.text.textColor[2] == 0.8, "custom forces text color must survive")
assert(attachments == 8, "four fills, forces overlay and three sleek segments need owner masks")
env.profile.mplusTimer.showBorder = false
_G.QUI_RefreshMPlusTimerColors()
assert(rootBackdrop._quiBorderA == 0 and sleekBackdrop._quiBorderA == 0, "hidden-border setting must survive refresh")
for _, backdrop in pairs(originalBackdrops) do assert(backdrop._quiBorderA == 0, "all bar borders must honor hidden-border setting") end
assert(attachments == 8, "refresh must not duplicate native mask attachments")
print("OK: mplus_timer_rounded_surfaces_test")
