local function setup()
    local state = { calls = {}, timers = {}, combat = false }
    local env = setmetatable({}, { __index = _G })
    local ns = { ActionBarsEnv = env, DebugRegister = function() end, _inInitSafeWindow = false }
    env._G = {}
    env.SetChunkEnv = function(level, target) setfenv(level + 1, target) end
    env.CreateFrame = function()
        return {
            Hide = function(self) self.shown = false end,
            Show = function(self) self.shown = true end,
            SetScript = function(self, name, callback) self[name] = callback end,
        }
    end
    env.ownedEventFrame = env.CreateFrame()
    env.ALL_MANAGED_BAR_KEYS = { "bar1", "bar2" }
    env.InCombatLockdown = function() return state.combat end
    env.GetTime = function() return 1 end
    env.GetDB = function() return nil end
    env.C_Timer = { After = function(delay, callback)
        state.timers[#state.timers + 1] = { delay = delay, callback = callback }
    end }
    local function record(name)
        return function(key)
            state.calls[#state.calls + 1] = name .. (key and ":" .. key or "")
        end
    end
    env.ActionBarsOwned = { initialized = true }
    for _, name in ipairs({ "UpdateAllButtonVisuals", "ForceFullVisualRescan", "UpdateAllCooldowns" }) do
        env.ActionBarsOwned[name] = record(name)
    end
    for _, name in ipairs({ "LayoutNativeButtons", "RestoreContainerPosition", "RefreshAllNativeVisuals",
        "UpdatePetBarVisibility", "UpdateStanceBarLayout", "ApplyAllFlyoutDirections",
        "SyncOwnedFlyoutInfoToHandler", "RefreshActionBarContextVisibility", "ApplyAllBarSpacing" }) do
        env[name] = record(name)
    end
    env._G.QUI_RefreshActionBarFade = record("fade")
    assert(loadfile("QUI_ActionBars/actionbars/actionbars_events.lua"))("QUI_ActionBars", ns)
    function state:enter()
        self.timers = {}
        local previousInitSafeWindow = ns._inInitSafeWindow
        env.ownedEventFrame.OnEvent(nil, "PLAYER_ENTERING_WORLD", true, false)
        assert(#self.timers == 1 and self.timers[1].delay == 0.2,
            "entering the world must retain the 0.2-second settling timer")
        assert(env.inInitSafeWindow == false and ns._inInitSafeWindow == previousInitSafeWindow,
            "the synchronous event must preserve the caller's shared init safe window")
        self.calls = {}
    end
    return state, env, record, ns
end

local expected = table.concat({
    "LayoutNativeButtons:bar1", "RestoreContainerPosition:bar1",
    "LayoutNativeButtons:bar2", "RestoreContainerPosition:bar2",
    "RefreshAllNativeVisuals", "ForceFullVisualRescan", "updatedVisuals", "UpdateAllCooldowns",
    "UpdatePetBarVisibility", "UpdateStanceBarLayout", "ApplyAllFlyoutDirections",
    "updatedSync", "RefreshActionBarContextVisibility", "fade",
}, ",")
do
    local state, env, record, ns = setup()
    state:enter()
    env.ActionBarsOwned.UpdateAllButtonVisuals = record("updatedVisuals")
    env.SyncOwnedFlyoutInfoToHandler = record("updatedSync")
    state.timers[1].callback()
    assert(table.concat(state.calls, ",") == expected,
        "settling must preserve call order and resolve helpers when the timer executes")

    state:enter()
    state.combat = true
    state.timers[1].callback()
    assert(#state.calls == 0, "combat must prevent all settling work")
    assert(env.ActionBarsOwned.pendingRefresh and env.ActionBarsOwned.pendingPetUpdate
        and env.ActionBarsOwned.pendingStanceUpdate, "combat must preserve all deferred flags")

    state.combat = false
    state:enter()
    env.SyncOwnedFlyoutInfoToHandler = nil
    env.RefreshActionBarContextVisibility = nil
    env._G.QUI_RefreshActionBarFade = nil
    state.timers[1].callback()
    assert(#state.calls == 11 and state.calls[11] == "ApplyAllFlyoutDirections",
        "settling must preserve optional visibility helper guards")

    state.calls = {}
    env.ScheduleABVisualUpdate(false, true)
    env.abUpdateFrame.OnUpdate(env.abUpdateFrame)
    assert(table.concat(state.calls, ",") == "updatedVisuals",
        "the visual drain must invoke the current visual helper once")
    assert(not env.abUpdateFrame.shown and not env.abUpdateFrame._dirtyVisuals,
        "the visual drain must retain dirty-flag cleanup")

    state.calls = {}
    env.STANDARD_BAR_KEYS = {}
    env.wipe = function(values) for key in pairs(values) do values[key] = nil end end
    env.UpdateAllAssistedHighlights = record("highlights")
    env.ActionBarsOwned.UpdateAllAssistedCombatRotation = record("assisted")
    env.Helpers = { SafeValue = function(value) return value end }
    env.ScheduleSlotUpdate(1)
    env.abSlotFrame.OnUpdate(env.abSlotFrame)
    assert(table.concat(state.calls, ",") == "highlights,assisted",
        "the slot drain must retain its final highlight updates")
    assert(not env.abSlotFrame.shown and next(env.abDirtySlots) == nil,
        "the slot drain must consume pending slots")

    env.__declared = {}
    assert(loadfile("QUI_ActionBars/actionbars/actionbars_usability.lua"))("QUI_ActionBars", ns)
    local button = { _quiBarKey = "pet" }
    env.usabilityState = {}
    env.GetGlobalSettings = function() return { usabilityIndicator = true } end
    env.ActionBarsOwned._activeStandardButtons = { [button] = true }
    env.UpdateButtonUsability = function(target)
        assert(target == button, "the scan must preserve its active button")
        state.calls[#state.calls + 1] = "usability"
    end
    state.calls = {}
    env.ActionBarsOwned.UpdateAllButtonUsability()
    assert(env.ActionBarsOwned.UpdateAllButtonUsability == env.UpdateAllButtonUsability,
        "public and internal usability callers must share the function")
    assert(table.concat(state.calls, ",") == "usability" and env.usabilityState.lastScanTime == 1,
        "usability work must preserve scan bookkeeping")

    assert(loadfile("QUI_ActionBars/actionbars/actionbars_builder.lua"))("QUI_ActionBars", ns)
    local function noop() end
    button.SetParent, button.UnregisterAllEvents = noop, noop
    button.SetScript, button.Show = noop, noop
    env._G.QUI_PetButton1 = button
    env.GetBarFrame = noop
    local settings = {}
    env.GetEffectiveSettings = function() return settings end
    env.ActionBarsOwned.containers = { pet = {} }
    env.ActionBarsOwned.nativeButtons = {}
    env.ActionBarsOwned.UpdatePetButton = noop
    env.BUTTON_COUNTS, env.BINDING_COMMANDS = { pet = 1 }, {}
    env.SKINNABLE_BAR_KEYS = { pet = true }
    env.layoutHandler = { SetFrameRef = noop }
    env.SetupOwnedBarMouseover, env.ApplyBarOverrideBindings = noop, noop
    env.BuildBar("pet")
    local timer = state.timers[#state.timers]
    assert(timer.delay == 0, "build skinning must retain the next-frame timer")
    state.calls = {}
    local buttonState = { sk_sz = 42 }
    env.GetFrameState = function(target) assert(target == button); return buttonState end
    env.SkinButton = function(target, captured)
        assert(target == button and captured == settings and buttonState.sk_sz == nil,
            "build skinning must preserve the button, settings and full-skin invalidation")
        state.calls[#state.calls + 1] = "skin"
    end
    env.UpdateButtonText = function() state.calls[#state.calls + 1] = "text" end
    env.UpdateEmptySlotVisibility = function() state.calls[#state.calls + 1] = "empty" end
    timer.callback()
    assert(table.concat(state.calls, ",") == "skin,text,empty",
        "build skinning must retain its per-button update order")
end

do
    local state, env, _, ns = setup()
    state.combat = true
    ns._inInitSafeWindow = true
    ns.QUI_Anchoring = { ApplyAllFrameAnchors = function()
        assert(ns._inInitSafeWindow == true, "reload anchors must apply inside the initialization window")
    end }
    state:enter()
    assert(ns._inInitSafeWindow == true,
        "nested actionbar startup must not close the caller's protected-layout window")
    ns._inInitSafeWindow = false
    state:enter()
    assert(ns._inInitSafeWindow == false,
        "actionbar startup must not leave a new protected-layout window open")
    ns._inInitSafeWindow = nil
    state:enter()
    assert(ns._inInitSafeWindow == nil,
        "actionbar startup must preserve an absent caller window")
end

print("actionbars_startup_settle_test: OK")
