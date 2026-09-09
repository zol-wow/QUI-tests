-- Run: luajit tests/unit/assisted_combat_next_poller_test.lua
--
-- The CDM rotation helper overlay and the standalone Rotation Assist icon
-- used to learn about next-cast changes only through hooks on Blizzard's
-- AssistedCombatManager, which only fire while the assistedCombatHighlight
-- CVar is on. QUI.AssistedCombatNext polls C_AssistedCombat.GetNextCastSpell
-- itself so the overlay keeps moving regardless.

local function noop() end

function wipe(tbl) for k in pairs(tbl) do tbl[k] = nil end end
function issecretvalue(v) return type(v) == "table" and v.__secret == true end
function InCombatLockdown() return false end
function GetTime() return 0 end
function GetSpecialization() return nil end
function GetSpecializationInfo() return nil end
function GetInventoryItemID() return nil end
function GetActionInfo() return nil end
function GetActionText() return nil end
function GetBindingKey() return nil end
function GetMacroInfo() return nil end
function GetMacroSpell() return nil end
function hooksecurefunc() end

UIParent = {}
C_Item = { GetItemInfoInstant = noop, GetItemNameByID = noop }
C_Spell = { GetSpellName = noop, GetOverrideSpell = function(id) return id end }
C_Widget = { IsWidget = function() return false end, IsFrameWidget = function() return false end }

-- Timer stub: tickers are recorded, never fire on their own.
local tickers = {}
C_Timer = {
    After = noop,
    NewTimer = function() return { Cancel = noop } end,
    NewTicker = function(rate, fn)
        local t = { rate = rate, fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        tickers[#tickers + 1] = t
        return t
    end,
}

local eventFrames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(_, fn) self.onEvent = fn end
    function f:SetAllPoints() end
    function f:SetFrameLevel() end
    function f:GetFrameLevel() return 1 end
    function f:Show() end
    function f:Hide() end
    function f:IsShown() return false end
    function f:CreateFontString() return { SetText = noop, Show = noop, Hide = noop } end
    eventFrames[#eventFrames + 1] = f
    return f
end

local nextSpell = 100
local isAvailable = true
C_AssistedCombat = {
    GetNextCastSpell = function() return nextSpell end,
    IsAvailable = function() return isAvailable end,
}
AssistedCombatManager = { GetUpdateRate = function() return 0.25 end }

local coreRef = nil
local addon = {
    Helpers = {
        GetCore = function() return coreRef end,
        IsSecretValue = function(v) return issecretvalue(v) end,
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        GetGeneralFont = function() return "" end,
        GetGeneralFontOutline = function() return "" end,
    },
}
_G.QUI = addon

assert(loadfile("core/safecall.lua"))("QUI", addon)
assert(loadfile("modules/utility/keybinds.lua"))("QUI", addon)

local poll = addon.AssistedCombatNext
assert(poll, "keybinds.lua should export QUI.AssistedCombatNext")

local failures = 0
local function check(label, cond)
    if cond then
        print("ok   - " .. label)
    else
        failures = failures + 1
        print("FAIL - " .. label)
    end
end

-- 1. No subscribers: no ticker.
check("no ticker before anyone subscribes", #tickers == 0 and not poll.IsPolling())

-- 2. Subscribing starts a ticker at Blizzard's update rate.
local seenCount, seenLast = 0, nil
poll.Subscribe("test", function(id) seenCount = seenCount + 1; seenLast = id end)
check("subscribing starts the poll", poll.IsPolling())
check("poll uses AssistedCombatManager:GetUpdateRate()", tickers[1] and tickers[1].rate == 0.25)

-- 3. First tick notifies; repeated identical answers are deduped.
poll._Tick()
poll._Tick()
poll._Tick()
check("first tick dispatches the current suggestion", seenLast == 100)
check("unchanged suggestion is not re-dispatched", seenCount == 1)

-- 4. A changed suggestion is dispatched without any Blizzard hook firing.
nextSpell = 200
poll._Tick()
check("changed suggestion dispatches", seenCount == 2 and seenLast == 200)

-- 5. nil (no suggestion) counts as a change, so consumers can clear.
nextSpell = nil
poll._Tick()
check("nil suggestion dispatches once", seenCount == 3 and seenLast == nil)
poll._Tick()
check("repeated nil is deduped", seenCount == 3)

-- 6. Secret values are never compared; dispatched once on transition.
local secret = { __secret = true }
nextSpell = secret
poll._Tick()
poll._Tick()
check("secret suggestion dispatches once on transition", seenCount == 4 and seenLast == secret)
nextSpell = 300
poll._Tick()
check("readable value after secret dispatches", seenCount == 5 and seenLast == 300)

-- 7. A throwing subscriber does not stop other subscribers.
local other = 0
poll.Subscribe("boom", function() error("subscriber exploded") end)
poll.Subscribe("other", function() other = other + 1 end)
nextSpell = 400
poll._Tick()
check("other subscribers still run after one fails", other == 1)
poll.Unsubscribe("boom")
poll.Unsubscribe("other")

-- 8. Reset forces a re-dispatch of the same value (spec change, zone-in).
poll.Reset()
poll._Tick()
check("Reset() makes the next tick dispatch even if unchanged", seenLast == 400 and seenCount == 7)

-- 8b. Reset() followed by a nil answer must still dispatch: nil is a valid
-- "no suggestion" result and must not be confused with the reset marker.
nextSpell = nil
poll.Reset()
poll._Tick()
check("nil right after Reset() dispatches so stale highlights clear", seenCount == 8 and seenLast == nil)
poll._Tick()
check("nil after that is deduped again", seenCount == 8)

-- 8c. Assisted Combat becoming unavailable tells consumers to clear, once.
nextSpell = 500
poll._Tick()
check("sanity: a suggestion is showing again", seenCount == 9 and seenLast == 500)
isAvailable = false
poll.Reset()
check("unavailable spec stops the ticker", not poll.IsPolling())
check("unavailable spec dispatches nil to clear consumers", seenCount == 10 and seenLast == nil)
poll.Reset()
check("repeated unavailable resets do not re-dispatch", seenCount == 10)
isAvailable = true
poll.Reset()
poll._Tick()
check("availability returning dispatches the current suggestion", seenCount == 11 and seenLast == 500)

-- 9. Unsubscribing the last consumer stops the ticker.
poll.Unsubscribe("test")
check("last unsubscribe cancels the ticker", not poll.IsPolling())

-- 10. Unavailable (spec without Assisted Combat): no ticker even with subscribers.
isAvailable = false
poll.Reset()
poll.Subscribe("test2", noop)
check("no ticker when C_AssistedCombat.IsAvailable() is false", not poll.IsPolling())
isAvailable = true
poll.Reset()
check("Reset() after availability returns starts the ticker", poll.IsPolling())
poll.Unsubscribe("test2")

-- 11. The CDM overlay itself subscribes when its setting is on.
local core = {
    db = { profile = { viewers = {
        EssentialCooldownViewer = { showRotationHelper = true },
        UtilityCooldownViewer = { showRotationHelper = false },
    } } },
}
coreRef = core
_G.QUI_RefreshRotationHelper()
check("enabling the rotation helper subscribes the overlay", poll.IsPolling())
core.db.profile.viewers.EssentialCooldownViewer.showRotationHelper = false
_G.QUI_RefreshRotationHelper()
check("disabling the rotation helper unsubscribes the overlay", not poll.IsPolling())

if failures > 0 then
    print(("FAILED: assisted_combat_next_poller_test (%d)"):format(failures))
    os.exit(1)
end
print("OK: assisted_combat_next_poller_test")
