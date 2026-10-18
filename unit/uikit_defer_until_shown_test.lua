local combat = false
InCombatLockdown = function() return combat end
local frames = {}
CreateFrame = function()
    local frame = { shown = false, hooks = {}, scripts = {}, events = {} }
    function frame:IsShown() return self.shown end
    function frame:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], callback)
    end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:Show()
        if self.shown then return end
        self.shown = true
        for _, callback in ipairs(self.hooks.OnShow or {}) do callback(self) end
    end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end
local function fire(event)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event) end
    end
end
local ns = { Helpers = {
    CHROME = {},
    GetCore = function() end,
    CreateStateTable = function()
        local states = setmetatable({}, { __mode = "k" })
        return states, function(frame)
            if not states[frame] then states[frame] = {} end
            return states[frame]
        end
    end,
} }
assert(loadfile("core/uikit.lua"))("QUI", ns)
local defer = ns.SkinBase.DeferUntilShown

local frame = CreateFrame()
local calls = 0
local callback
callback = function()
    assert(not defer(frame, callback), "a deferred callback must proceed without reentering itself")
    calls = calls + 1
end
local before = #frames
assert(defer(frame, callback))
assert(defer(frame, callback))
assert(calls == 0 and #frames == before, "hidden work must not run or create a combat watcher")
assert(#frame.hooks.OnShow == 1, "repeat loads must share one OnShow hook")
frame:Show()
assert(calls == 1, "repeat hidden loads must coalesce")
frame:Hide()
frame:Show()
assert(calls == 1, "completed work must not rerun on every show")
assert(not defer(frame, callback) and calls == 1, "shown work must be left to the caller")
frame:Hide()
assert(defer(frame, callback))
frame:Show()
assert(calls == 2 and #frame.hooks.OnShow == 1, "later addon loads must rearm the existing hook")

frame:Hide()
local lateCalls = 0
assert(defer(frame, callback))
assert(defer(frame, function() lateCalls = lateCalls + 1 end))
frame:Show()
assert(calls == 3 and lateCalls == 1, "distinct callbacks must each run once")

local enabled, styled = true, 0
frame:Hide()
assert(defer(frame, function() if enabled then styled = styled + 1 end end))
enabled = false
frame:Show()
assert(styled == 0, "deferred callbacks must observe current settings")

frame:Hide()
combat = true
before = #frames
assert(defer(frame, callback))
assert(defer(frame, callback))
assert(#frames == before, "hidden combat work must wait without an event frame")
frame:Show()
assert(calls == 4 and #frames == before,
    "first opening during combat must skin immediately without a combat-end watcher")
assert(not defer(frame, callback), "shown skins must remain callable during combat")
frame:Hide()
assert(defer(frame, callback))
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(calls == 4, "combat ending must not initialize a hidden skin")
combat = true
frame:Show()
assert(calls == 5 and #frames == before, "later hidden work must initialize on reopening during combat")
frame:Hide()
frame:Show()
assert(calls == 5, "reopening a completed combat skin must not repeat initialization")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(calls == 5, "combat end must not repeat completed styling")

local independent = CreateFrame()
local independentCalls = 0
frame:Hide()
assert(defer(frame, callback))
assert(defer(independent, function() independentCalls = independentCalls + 1 end))
independent:Show()
assert(independentCalls == 1 and calls == 5, "different frames must have independent queues")
frame:Show()
assert(calls == 6)

local failure = {}
local attempts = 0
local failed = CreateFrame()
local retry = function()
    attempts = attempts + 1
    if attempts == 1 then error(failure) end
end
assert(defer(failed, retry))
local ok, err = pcall(function() failed:Show() end)
assert(not ok and err == failure and attempts == 1, "callback errors must propagate unchanged")
failed:Hide()
failed:Show()
assert(attempts == 1, "a failed callback must have been removed before execution")
failed:Hide()
assert(defer(failed, retry))
failed:Show()
assert(attempts == 2 and #failed.hooks.OnShow == 1, "errors must not poison a later explicit retry")

local visible = CreateFrame()
visible:Show()
combat = true
before = #frames
assert(not defer(visible, function() error("caller owns immediate styling") end),
    "already-visible reload skins must not wait for combat to end")
assert(#frames == before and not visible.hooks.OnShow,
    "already-visible skinning must not install deferred work")

print("PASS uikit_defer_until_shown_test")
