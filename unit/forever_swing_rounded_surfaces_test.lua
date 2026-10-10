local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, skin = env.ns, env.SkinBase
ns.Client = {isForever = true}
ns.L = setmetatable({}, {__index = function(_, key) return key end})
ns.LSM = {Fetch = function() return "QUI-flat" end}
ns.Helpers.GetSkinBarColor = function() return 0.2, 0.4, 0.6, 1 end
ns.Helpers.BaseClearAllPoints = function(frame) frame:ClearAllPoints() end
ns.Helpers.BaseSetPoint = function(frame, ...) frame:SetPoint(...) end
ns.QUI_LayoutMode = {isActive = true, RegisterElement = function() end}
ns.Registry = {Register = function() end}
ns.WhenLoggedIn = function() end
_G.QUI_RegisterFrameResolver = function() end
_G.CVarCallbackRegistry = {SetCVarCachable = function() end}
_G.RED_FONT_COLOR = {GetRGB = function() return 1, 0, 0 end}
_G.HIGHLIGHT_FONT_COLOR = {GetRGB = function() return 1, 1, 1 end}
_G.OverrideActionBar = nil
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SwingTimer/Blizzard_SwingTimer.lua"))()
env.profile.swingTimers = {}
local maskAttachments = 0
for _, name in ipairs({"MainHand", "OffHand", "Ranged"}) do
    local key = "swingTimer" .. name
    env.profile.swingTimers[key] = {
        width = 250, height = 20, fontSize = 11, texture = "Flat",
        showTitle = true, showTime = true, visibility = 0,
    }
    local frame = env.NewFrame("Frame", "SwingTimer" .. name .. "Frame")
    _G["SwingTimer" .. name .. "Frame"] = frame
    for method, fn in pairs(_G.SwingTimerMixin) do frame[method] = fn end
    frame:SetFrameLevel(10)
    frame.ignoreFramePositionManager = true
    frame.SetScaleBase = function() end
    frame.ApplySystemAnchor = function() end
    frame.UpdateSystemSetting = function() end
    frame.UpdateShownStateAndRegistration = function() end
    frame.UpdateShownState = function() end
    frame.barTexture, frame.typeText = "native-" .. name, name
    frame.Background, frame.Border = frame:CreateTexture(), frame:CreateTexture()
    frame.Background:SetTexture("native-background")
    frame.Border:SetTexture("native-border")
    local bar = env.NewFrame("StatusBar", nil, frame)
    frame.StatusBar = bar
    bar:SetFrameLevel(11)
    bar.CreateMaskTexture = bar.CreateTexture
    local fill = bar:CreateTexture()
    function bar:GetStatusBarTexture() return fill end
    function bar:SetStatusBarTexture(path) fill:SetTexture(path) end
    function fill:AddMaskTexture() maskAttachments = maskAttachments + 1 end
    bar.Pip, bar.TypeLabelShadow = bar:CreateTexture(), bar:CreateTexture()
    function bar.Pip:AddMaskTexture() maskAttachments = maskAttachments + 1 end
    bar.TypeLabel, bar.TimeLabel = bar:CreateFontString(), bar:CreateFontString()
    bar.value, frame.swingEndTime = 0.5, 102
end
assert(loadfile(arg[1] or "modules/skinning/gameplay/swing_timers.lua"))("QUI", ns)
ns.SwingTimers.Refresh()
for _, entry in ipairs(ns.SwingTimers.entries) do
    local frame, chrome = entry.frame, assert(entry.chrome)
    local bar = frame.StatusBar
    assert(chrome._quiRoundedSurface.radius == 3 and chrome._quiRoundedSurface.borderPixels == 1,
        "all three timers must use real rounded one-pixel chrome")
    assert(chrome:GetFrameLevel() < bar:GetFrameLevel(), "chrome must stay behind the fill")
    assert(frame.Border.texture == nil and frame.Background.texture == nil, "square native art must be removed")
    frame:SetOutOfRange(true)
    assert(chrome:GetAlpha() == 0.4 and bar:GetAlpha() == 0.4, "rounded chrome must follow native range dimming")
    frame:SetIsInEditMode(true)
    assert(chrome:GetAlpha() == 1 and bar:GetAlpha() == 1, "native edit mode must suppress dimming")
    frame:SetIsInEditMode(false)
    assert(chrome:GetAlpha() == 0.4, "leaving edit mode must restore native range dimming")
    frame:SetOutOfRange(false)
    frame:InitializeBarPresentation()
    assert(bar:GetStatusBarTexture().texture == "QUI-flat", "native presentation resets must regain QUI texture")
    assert(bar.value == 0.5 and frame.swingEndTime == 102, "styling must retain active timer progress")
    chrome._quiBorderR = -1
    ns.SwingTimers.Refresh()
    assert(chrome._quiBorderR ~= -1 and entry.chrome == chrome, "refresh must reuse and recolor the same shell")
end
assert(maskAttachments == 6, "refresh must attach one owner mask to each fill and pip")
print("OK: forever_swing_rounded_surfaces_test")
