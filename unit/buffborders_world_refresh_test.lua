local frames, timers = {}, {}
local inCombat = false
local function noop() end

QUI = {}
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
    end,
}
InCombatLockdown = function() return inCombat end
CreateFrame = function(_, name)
    local frame = {
        events = {},
        scripts = {},
        SetSize = noop,
        SetClampedToScreen = noop,
        RegisterEvent = function(self, event) self.events[event] = true end,
        SetScript = function(self, script, callback) self.scripts[script] = callback end,
    }
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

local function fire(event)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event) end
    end
end

local function nextFrame()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do timer.callback() end
end

local ns = {
    Helpers = {
        CreateStateTable = function() return {} end,
        GetModuleSettings = function() return {} end,
        IsLayoutModeActive = function() return false end,
    },
}
assert(loadfile("QUI_ActionBars/actionbars/buffborders.lua"))("QUI", ns)

timers = {}
fire("PLAYER_ENTERING_WORLD")
nextFrame()
assert(_G.QUI_BuffIconContainer == nil, "entering world must not create buff frames before initialization")

QUI.BuffBorders.Init()
timers = {}
local refreshes = 0
local native = {
    UpdateAllAuras = function() refreshes = refreshes + 1 end,
}
QUI_BuffIconContainer._quiLiveContainer = native
QUI_DebuffIconContainer._quiLiveContainer = {
    UpdateAllAuras = function() error("weapon enchant recovery must not refresh the debuff bar") end,
}

fire("PLAYER_ENTERING_WORLD")
assert(refreshes == 0, "world-entry refresh must wait until entry event handlers finish")
nextFrame()
assert(refreshes == 1, "zoning must request the native refresh that restores weapon enchant durations")

inCombat = true
fire("PLAYER_ENTERING_WORLD")
nextFrame()
assert(refreshes == 2, "the native secure refresh must remain available when zoning during combat")
inCombat = false

fire("PLAYER_REGEN_ENABLED")
nextFrame()
assert(refreshes == 2, "ordinary combat end must not trigger an extra world-entry refresh")

fire("PLAYER_ENTERING_WORLD")
QUI_BuffIconContainer._quiLiveContainer = nil
nextFrame()
assert(refreshes == 2, "a buff bar disabled before the callback must not refresh its retired container")

fire("PLAYER_ENTERING_WORLD")
QUI_BuffIconContainer._quiLiveContainer = native
nextFrame()
assert(refreshes == 3, "the callback must resolve the current live container when it runs")

print("OK: buffborders_world_refresh_test")
