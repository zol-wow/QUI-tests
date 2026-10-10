for _, legacy in ipairs({false, true}) do
    local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
    env.profile.general.skinMirrorTimers = true
    _G.MirrorTimerMixin, _G.MirrorTimer_Show = nil, nil
    _G.EventRegistry = {RegisterForOnUpdate = function() end}
    local secureHook = _G.hooksecurefunc
    _G.hooksecurefunc = function(owner, method, callback)
        if type(owner) ~= "string" then return secureHook(owner, method, callback) end
        local nativeFunction = _G[owner]
        _G[owner] = function(...)
            local result = nativeFunction(...)
            method(...)
            return result
        end
    end
    local native = legacy and "Classic" or "Mainline"
    assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_MirrorTimer/" .. native .. "/MirrorTimer.lua"))()
    env.ns.Helpers.GetSkinBarColor = function() return 0.2, 0.4, 0.6, 1 end
    local skin = env.SkinBase
    env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
    env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
    local frame = env.NewFrame("Frame", legacy and "MirrorTimer1" or nil)
    frame:SetFrameLevel(4)
    frame.Text = frame:CreateFontString()
    frame.Border = frame:CreateTexture()
    frame.TextBorder = frame:CreateTexture()
    local background = frame:CreateTexture()
    background:SetAtlas("ui-castingbar-background")
    function background:GetAtlas() return self.atlas end
    local bar = env.NewFrame("StatusBar", nil, frame)
    bar:SetFrameLevel(3)
    frame.StatusBar = bar
    bar.CreateMaskTexture = bar.CreateTexture
    local fill = bar:CreateTexture()
    local maskCount = 0
    function fill:AddMaskTexture() maskCount = maskCount + 1 end
    function bar:GetStatusBarTexture() return fill end
    function bar:SetStatusBarTexture(path) self.texturePath = path end
    function bar:SetMinMaxValues(low, high) self.low, self.high = low, high end
    function bar:SetValue(value) self.value = value end
    function bar:SetStatusBarColor(...) self.color = {...} end
    env.ns.Helpers.ApplyBarStyle = function(owner, path) owner:SetStatusBarTexture(path) end
    if legacy then
        _G.MIRRORTIMER_NUMTIMERS = 1
        _G.MirrorTimer1, _G.MirrorTimer1Text, _G.MirrorTimer1StatusBar = frame, frame.Text, bar
        frame:Hide()
    else
        for key, value in pairs(_G.MirrorTimerMixin) do frame[key] = value end
        _G.MirrorTimerContainer = env.NewFrame("Frame")
        for key, value in pairs(_G.MirrorTimerContainerMixin) do _G.MirrorTimerContainer[key] = value end
        _G.MirrorTimerContainer.mirrorTimers = {frame}
        _G.MirrorTimerContainer.activeTimers = {}
        _G.MirrorTimerContainer.Layout = function() end
    end
    local callback, refresh
    skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_MirrorTimer" then callback = fn end end
    env.ns.Registry = {Register = function(_, key, entry) if key == "skinMirrorTimers" then refresh = entry.refresh end end}
    assert(loadfile(os.getenv("QUI_MISC_SOURCE") or "modules/skinning/frames/misc_frames.lua"))("QUI", env.ns)
    callback()
    callback()
    assert(bar.value == nil and bar.low == nil, "initial styling must not start or advance a timer")
    for _, timer in ipairs({"BREATH", "EXHAUSTION", "BREATH"}) do
        if legacy then
            if frame:IsShown() then _G.MirrorTimerFrame_OnEvent(frame, "MIRROR_TIMER_STOP", frame.timer) end
            assert(_G.MirrorTimer_Show(timer, 17000, 60000, -1, 1, timer .. " native") == frame)
        else
            if frame.timer then _G.MirrorTimerContainer:ClearTimer(frame.timer) end
            _G.MirrorTimerContainer:SetupTimer(timer, 17000, 60000, true, timer .. " native")
            assert(_G.MirrorTimerContainer:GetActiveTimer(timer) == frame, "native container selection must survive")
        end
        assert(bar.texturePath == "Interface\\Buttons\\WHITE8x8", "reused timer must retain QUI fill texture")
        assert(bar.value == 17 and bar.low == 0 and bar.high == 60, "native progress and ranges must survive")
        assert(frame.timer == timer and frame.Text:GetText() == timer .. " native", "native timer identity and label must survive")
        assert(frame:IsShown(), "native timer visibility must survive")
        assert(frame.Border:GetAlpha() == 0 and background:GetAlpha() == 0, "native decorative borders/background must be suppressed")
        local backdrop = skin.GetFrameData(frame, "backdrop")
        assert(backdrop and backdrop._quiRoundedSurface.radius == 4 and backdrop:GetFrameLevel() < bar:GetFrameLevel(),
            "timer shell must be rounded and behind the native fill")
        if legacy then
            local color = _G.MirrorTimerColors[timer]
            assert(bar.color[1] == color.r and bar.color[3] == color.b and frame.paused == 1,
                "classic type colors and pause state must survive")
        else
            assert(frame:GetScript("OnUpdate") == nil, "native paused update lifecycle must survive")
        end
    end
    if legacy then
        _G.MirrorTimer_Show(frame.timer, 20000, 70000, -1, 0, "running")
        assert(frame.paused == nil and bar.value == 20 and bar.high == 70, "native classic running state must survive")
    else
        _G.MirrorTimerContainer:SetupTimer(frame.timer, 20000, 70000, false, "running")
        assert(frame:GetScript("OnUpdate") == frame.OnUpdate and bar.value == 20 and bar.high == 70,
            "native running update lifecycle must survive")
    end
    local backdrop = skin.GetFrameData(frame, "backdrop")
    backdrop._quiBorderR = -1
    refresh()
    assert(backdrop._quiBorderR ~= -1 and maskCount == 1, "theme refresh must restore chrome without duplicate masks")
end
print("OK: mirror_timer_surfaces_test")
