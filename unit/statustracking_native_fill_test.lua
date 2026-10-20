local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
_G.LibStub = function() return nil end
local settings = env.profile.general
settings.skinStatusTrackingBars = true
settings.statusTrackingBarsBarColorMode = "accent"
ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
ns.RunAfterFirstFrame = function(callback) callback() end
skin.IsAddOnFullyLoaded = function() return true end
local container = env.NewFrame("Frame")
container:SetWidth(500)
local bar = env.NewFrame("Frame", nil, container)
local statusBar = env.NewFrame("StatusBar", nil, bar)
bar.StatusBar = statusBar
statusBar:SetSize(400, 12)
local texture = statusBar:CreateTexture()
local masks = 0
function texture:GetAtlas() return self.atlas end
function texture:GetTexture() return self.texture end
function texture:AddMaskTexture() masks = masks + 1 end
statusBar.CreateMaskTexture = statusBar.CreateTexture
function statusBar:GetStatusBarTexture() return texture end
function statusBar:SetStatusBarTexture(path)
    texture.texture = path
    texture.atlas = type(path) == "string" and path:match("^UI%-") and path or nil
end
function statusBar:GetStatusBarColor() return unpack(self.color) end
function statusBar:SetStatusBarColor(...) self.color = {...} end
statusBar:SetStatusBarTexture("UI-HUD-ExperienceBar-Fill-Honor")
statusBar:SetStatusBarColor(1, 1, 1, 1)
statusBar.value, statusBar.low, statusBar.high = 17, 0, 100
function bar:Update()
    self.StatusBar:SetStatusBarTexture("UI-HUD-ExperienceBar-Fill-Reputation-Faction-Blue")
    self.StatusBar:SetStatusBarColor(0.7, 0.8, 0.9, 1)
end
container.bars = {bar}
_G.StatusTrackingBarManager = {barContainers = {container}, UpdateBarsShown = function() end}
assert(loadfile(os.getenv("QUI_STATUS_TRACKING_SOURCE") or "modules/skinning/frames/statustracking.lua"))("QUI", ns)
local function refresh(mode)
    settings.statusTrackingBarsBarColorMode = mode
    _G.QUI_RefreshStatusTrackingBarSkin()
end
assert(statusBar.color[1] == env.colors[1], "accent mode must apply configured tint")
refresh("blizzard")
assert(texture:GetAtlas() == "UI-HUD-ExperienceBar-Fill-Honor"
    and statusBar.color[1] == 1 and statusBar.color[2] == 1,
    "switching to Blizzard default must restore native art and remove stale accent tint")
settings.statusTrackingBarsBarColor = {0.1, 0.2, 0.3, 0.4}
refresh("custom")
assert(statusBar.color[1] == 0.1 and statusBar.color[4] == 0.4 and texture:GetAtlas() == nil,
    "custom mode must use QUI texture and configured RGBA")
bar:Update()
env.RunTimers()
assert(statusBar.color[1] == 0.1 and texture:GetAtlas() == nil,
    "native data updates must retain the selected custom appearance")
refresh("blizzard")
assert(texture:GetAtlas() == "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Blue"
    and statusBar.color[1] == 0.7 and statusBar.color[2] == 0.8 and statusBar.color[3] == 0.9,
    "Blizzard mode must restore the latest native identity, not the first captured faction")
-- Animated bars may update art after the parent Update returns.
refresh("accent")
statusBar:SetStatusBarTexture("UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green")
statusBar:SetStatusBarColor(0.6, 0.7, 0.8, 1)
refresh("blizzard")
assert(texture:GetAtlas() == "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green" and statusBar.color[1] == 0.6,
    "late native art/color updates must remain available after an override")
refresh("custom")
statusBar:SetStatusBarTexture("native-legacy-fill.tga")
refresh("blizzard")
assert(texture:GetTexture() == "native-legacy-fill.tga" and texture:GetAtlas() == nil,
    "non-atlas native textures must also survive override restoration")
assert(statusBar.value == 17 and statusBar.low == 0 and statusBar.high == 100,
    "appearance transitions must not alter native progress or range")
assert(masks == 1, "mode switching and native updates must reuse the existing mask")
local backdrop = skin.GetFrameData(bar, "quiStbBackdrop")
assert(backdrop and backdrop._quiRoundedSurface.radius == 3,
    "native art mode must retain rounded QUI shell")
print("OK: statustracking_native_fill_test")
