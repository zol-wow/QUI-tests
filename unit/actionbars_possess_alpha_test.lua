local frames, now, possess, mainFirst = {}, 0, false, false
local function newFrame()
    local frame = { alpha = 1, shown = true, scripts = {}, events = {} }
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    frames[#frames + 1] = frame
    return frame
end

local main, sibling = newFrame(), newFrame()
local owned = { containers = { bar1 = main, bar2 = sibling }, nativeButtons = {} }
local action, empty = newFrame(), newFrame()
action.state = { fadeHidden = true }
empty.state = { fadeHidden = true, hiddenEmpty = true }
owned.nativeButtons.bar1 = { action, empty }
local fadeState = {}
owned.fadeState = fadeState
local env = setmetatable({
    ActionBarsOwned = owned,
    GetFrameState = function(button) return button.state end,
    FadeHideTextures = function(state) state.fadeHidden = true end,
    FadeShowTextures = function(state) state.fadeHidden = false end,
    fadeState = fadeState,
    CreateFrame = newFrame,
    GetTime = function() return now end,
    GetOwnedBarFadeState = function(key)
        fadeState[key] = fadeState[key] or { currentAlpha = 1 }
        return fadeState[key]
    end,
    IsInEditMode = function() return false end,
    ShouldSuspendMouseoverFade = function() return false end,
    GetFadeSettings = function() return {} end,
    SecureCmdOptionParse = function() return possess and "show" or nil end,
    C_Timer = { After = function() end },
    NUM_CHAT_WINDOWS = 0,
    UnitExists = function() return false end,
    UnitAffectingCombat = function() return false end,
    IsInGroup = function() return false end,
    IsInRaid = function() return false end,
    InCombatLockdown = function() return false end,
    wipe = function(t) for key in pairs(t) do t[key] = nil end end,
}, { __index = _G })
env._G = env
env.pairs = function(t)
    if t ~= owned.containers then return pairs(t) end
    local keys, i = mainFirst and { "bar1", "bar2" } or { "bar2", "bar1" }, 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then return key, t[key] end
    end
end
local function extract(name, path)
    local file = assert(io.open(path or "QUI_ActionBars/actionbars/actionbars_layout.lua", "rb"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("function " .. name .. "(", 1, true))
    local last = assert(source:find("\nend", first, true))
    local chunk = assert(loadstring(source:sub(first, last + 3)))
    setfenv(chunk, env)()
end
extract("SetOwnedBarAlpha")
extract("StartOwnedBarFade")
owned.SetBarAlpha = env.SetOwnedBarAlpha

local ns = {
    ActionBarsOwned = owned,
    Addon = { db = { profile = { actionBarsVisibility = {
        showAlways = true, hideWhenMounted = true, fadeDuration = 0.1, fadeOutAlpha = 0,
    } } } },
    Helpers = {
        CreateStateTable = function() return {} end,
        IsEditModeActive = function() return false end,
        IsLayoutModeActive = function() return false end,
        IsPlayerMounted = function() return true end,
    },
    SafeCall = function(_, callback, ...) return pcall(callback, ...) end,
    SafeCallMethodIfPresent = function(_, owner, method, ...)
        if type(owner[method]) ~= "function" then return false end
        owner[method](owner, ...)
        return true
    end,
}
local hud = assert(loadfile("QUI_CDM/cdm/hud_visibility.lua"))
setfenv(hud, env)("QUI_CDM", ns)
local function tick(elapsed)
    elapsed = elapsed or 1
    now = now + elapsed
    for _, frame in ipairs(frames) do
        if frame.shown and frame.scripts.OnUpdate then
            frame.scripts.OnUpdate(frame, elapsed)
        end
    end
end

env.QUI_RefreshActionBarsVisibility()
possess = true
tick()
assert(main:IsShown() and main.alpha == 1, "ongoing mounted HUD fade must preserve possession bar")
assert(not action.state.fadeHidden and action.alpha == 1, "possession must restore faded action textures")
assert(empty.state.fadeHidden, "possession must keep empty-slot textures hidden")
assert(sibling.alpha == 0, "possession must not reveal sibling bars")

possess = false
main.alpha, sibling.alpha = 1, 1
env.GetOwnedBarFadeState("bar1").currentAlpha = 1
env.StartOwnedBarFade("bar1", 0)
possess = true
tick()
assert(main.alpha == 1, "ongoing local fade must preserve possession bar")

main.alpha, sibling.alpha = 0, 0
env.QUI_RefreshActionBarsVisibility()
tick()
assert(main.alpha == 1, "entering possession while fully faded must restore bar1")
assert(sibling.alpha == 0, "fully faded sibling must stay hidden")

mainFirst = true
env.QUI_RefreshActionBarsVisibility()
tick(0.05)
assert(main.alpha == 1 and sibling.alpha == 0, "repeated mounted refresh must not flash siblings when bar1 is first")
tick()
mainFirst = false

possess = false
env.QUI_RefreshActionBarsVisibility()
tick()
assert(main.alpha == 0 and sibling.alpha == 0, "exiting possession must restore mounted hiding")

local events
for _, frame in ipairs(frames) do
    if frame.events.PLAYER_MOUNT_DISPLAY_CHANGED then events = frame.events end
end
assert(events and events.UPDATE_POSSESS_BAR and events.UPDATE_VEHICLE_ACTIONBAR,
    "HUD must refresh for possession and vehicle action changes")

local function noOp() end
env.GlobalVisibilityHidingBars = function() return false end
env.GetBarSettings = function() return { fadeEnabled = true, fadeOutAlpha = 0 } end
env.ShouldSuppressMouseoverHideForLevel = function() return false end
env.ShouldForceShowForSpellBook = function() return false end
env.ShouldForceShowForActionBarContext = function() return false end
env.IsMouseOverOwnedBar = function() return false end
env.HookOwnedFrameForMouseover = noOp
env.CancelOwnedBarFadeTimers = noOp
env.ScheduleSlotUpdate = noOp
env.GetEffectiveSettings = function() return nil end
env.ScheduleABVisualUpdate = noOp
env.UpdateStanceBarLayout = noOp
env.ApplyBar1OverrideBindings = noOp
owned.UpdateCooldown = noOp
owned.UpdateOverlayGlow = noOp
owned.initialized = true
extract("SetupOwnedBarMouseover")
extract("OnOwnedEvent", "QUI_ActionBars/actionbars/actionbars_events.lua")
for _, event in ipairs({ "UPDATE_POSSESS_BAR", "UPDATE_VEHICLE_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED" }) do
    possess = true
    env.OnOwnedEvent(nil, event)
    assert(main.alpha == 1, event .. ": standalone action bars must restore possession alpha")
    possess = false
    env.OnOwnedEvent(nil, event)
    assert(main.alpha == 0, event .. ": standalone action bars must restore mouseover hiding on exit")
end
print("OK: actionbars_possess_alpha_test")
