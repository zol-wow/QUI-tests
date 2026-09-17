local function noop() end
local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

for _, globalEnabled in ipairs({ true, false }) do
    local combat, now, geometryWrites = false, 0, 0
    local frames, timers = {}, {}
    local function newFrame()
        local frame = { alpha = 1, scripts = {}, events = {}, state = {} }
        function frame:SetAlpha(value) self.alpha = value end
        function frame:GetAlpha() return self.alpha end
        function frame:IsMouseOver() return self.mouseOver == true end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:HookScript(event, callback)
            local previous = self.scripts[event]
            self.scripts[event] = function(...)
                if previous then previous(...) end
                callback(...)
            end
        end
        frame.Show, frame.Hide = noop, noop
        frames[#frames + 1] = frame
        return frame
    end
    local function schedule(delay, callback)
        local timer = { due = now + delay, callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end
    local function advance(seconds)
        now = now + seconds
        local pending = timers
        timers = {}
        for _, timer in ipairs(pending) do
            if not timer.cancelled then
                if timer.due <= now then timer.callback()
                else timers[#timers + 1] = timer end
            end
        end
        for _, frame in ipairs(frames) do
            if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds) end
        end
    end
    local container, nativeBar, button = newFrame(), newFrame(), newFrame()
    local settings = { fadeOutAlpha = 0.25, fadeEnabled = not globalEnabled or nil }
    local fadeSettings = {
        enabled = globalEnabled, alwaysShowInCombat = true, fadeOutDelay = 0.5,
        fadeInDuration = 0.2, fadeOutDuration = 0.3,
    }
    local owned = {
        useNativeButtons = true, containers = { bar1 = container },
        nativeButtons = { bar1 = { button } }, fadeState = {}, editOverlays = {},
    }
    local env = setmetatable({
        ActionBarsOwned = owned,
        LINKED_OWNED_BAR_KEYS = { "bar1" }, ALL_MANAGED_BAR_KEYS = { "bar1" },
        SKINNABLE_BAR_KEYS = { bar1 = true },
        GetBarSettings = function() return settings end,
        GetFadeSettings = function() return fadeSettings end,
        GetBarFrame = function() return nativeBar end,
        GetCore = function() return nil end,
        GetFrameState = function(frame) return frame.state end,
        GetTime = function() return now end,
        CreateFrame = newFrame,
        InCombatLockdown = function() return combat end,
        C_Timer = { NewTimer = schedule, After = schedule },
        SecureCmdOptionParse = function() return nil end,
        ShouldSuppressMouseoverHideForLevel = function() return false end,
        ShouldForceShowForSpellBook = function() return false end,
        ShouldForceShowForActionBarContext = function() return false end,
        ShouldSuspendMouseoverFade = function() return false end,
        IsSpellFlyoutActiveForBar = function() return false end,
        InvalidateEffectiveSettingsCache = noop,
        BuildBar = noop, SetupBarMouseover = noop,
        SetChunkEnv = function(level, scope) setfenv(level + 1, scope) end,
    }, { __index = _G })
    env._G = env
    local ns = { ActionBarsEnv = env, Helpers = { IsEditModeShown = function() return false end } }
    env.Helpers = ns.Helpers
    local function evaluate(source)
        local chunk = assert(loadstring(source))
        setfenv(chunk, env)
        chunk("QUI_ActionBars", ns)
    end
    evaluate(assert(read("QUI_ActionBars/actionbars/actionbars_helpers.lua"):match(
        "(function CancelBarFadeTimers%b().-\nend)")))
    evaluate(read("QUI_ActionBars/actionbars/actionbars_layout.lua"))
    evaluate(read("QUI_ActionBars/actionbars/actionbars_native.lua"))
    env.GetBarFadeState = env.GetOwnedBarFadeState
    evaluate(assert(read("QUI_ActionBars/actionbars/actionbars_public.lua"):match(
        "(_G%.QUI_RefreshActionBarFade = function%b().-\nend)")))
    env.BuildNativeBar = function()
        assert(not combat, "combat fade refresh must not rebuild native geometry")
        geometryWrites = geometryWrites + 1
    end
    assert(env.QUI_RefreshActionBarsVisibility == nil, "regression must run without CDM")
    owned:InitializeNativeBars()
    assert(container.alpha == 0.25 and nativeBar.alpha == 0.25,
        "saved native mouseover alpha must apply at startup without CDM")
    assert(button.scripts.OnEnter and button.scripts.OnLeave,
        "native buttons must receive mouseover hooks during startup")
    settings.fadeOutAlpha = 0.4
    owned:RefreshNativeBars()
    assert(container.alpha == 0.4 and nativeBar.alpha == 0.4,
        "native refresh must apply changed saved mouseover alpha")
    button.mouseOver = true
    button.scripts.OnEnter(button)
    advance(0.2)
    assert(nativeBar.alpha == 1, "native mouseover must reveal the bar")
    button.mouseOver = false
    button.scripts.OnLeave(button)
    advance(0.1)
    advance(0.5)
    advance(0.4)
    assert(nativeBar.alpha == 0.4, "native mouse leave must restore saved fade alpha")
    env.SetOwnedBarAlpha("bar1", 1)
    button.scripts.OnLeave(button)
    advance(0.1)
    button.scripts.OnLeave(button)
    env.StartOwnedBarFade("bar1", 0)
    local state = env.GetOwnedBarFadeState("bar1")
    local delayTimer, leaveTimer = assert(state.delayTimer), assert(state.leaveCheckTimer)
    assert(state.isFading, "combat regression must begin with an active fade")
    local beforeCombat = geometryWrites
    combat = true
    assert(owned.nativeEventFrame.events.PLAYER_REGEN_DISABLED,
        "native fade handling must subscribe to combat entry")
    owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_DISABLED")
    assert(delayTimer.cancelled and leaveTimer.cancelled and not state.isFading,
        "combat entry must cancel active fades and both pending fade timers")
    assert(container.alpha == 1 and nativeBar.alpha == 1,
        "always-show-in-combat must reveal native bars, including per-bar fade overrides")
    advance(1)
    assert(nativeBar.alpha == 1 and geometryWrites == beforeCombat,
        "cancelled fade work must not hide the bar or rebuild geometry in combat")
    combat = false
    owned.nativeEventFrame.scripts.OnEvent(owned.nativeEventFrame, "PLAYER_REGEN_ENABLED")
    advance(0)
    assert(container.alpha == 0.4 and nativeBar.alpha == 0.4 and geometryWrites > beforeCombat,
        "combat exit must restore saved alpha and resume native refresh")
end

print("OK: standalone native mouseover startup, refresh, hover, and combat fade lifecycle")
