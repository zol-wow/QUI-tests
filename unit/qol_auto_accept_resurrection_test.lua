local function noop() end
local frames, timers, settings, state = {}, {}, {}, {}
local secret = setmetatable({}, {
    __concat = function() error("secret identity concatenated") end,
    __tostring = function() error("secret identity stringified") end,
})

function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(name, callback) self.scripts[name] = callback end
    frames[#frames + 1] = frame
    return frame
end

hooksecurefunc = noop
C_AddOns = { IsAddOnLoaded = function() return false end }
C_Timer = {
    After = function(delay, callback) timers[#timers + 1] = { delay, callback } end,
    NewTimer = function(delay, callback)
        local timer = { delay, callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}
Enum = { GameRule = { ReleaseSpiritGhostDisabled = 1 } }
C_GameRules = { IsGameRuleActive = function() return false end }
C_InstanceEncounter = { IsEncounterInProgress = function() return state.encounter end }
local GameEvent = { HandlePlayerEnteringWorld = noop }
_G.GameEvent = GameEvent
SetGhostFrameShown = noop

function issecretvalue(value) return rawequal(value, secret) end
function IsInInstance() return state.instance ~= "none", state.instance end
function GetInstanceInfo() return "Instance", state.instance, state.difficulty or 1 end
function LoggingCombat() return false end
function IsShiftKeyDown() return state.shift end
function InCombatLockdown() return state.lockdown end
function IsInRaid() return state.raid end
function IsInGroup() return state.groupSize > 0 end
function GetNumGroupMembers() return state.groupSize end
function GetNumSubgroupMembers() return state.groupSize end
function UnitExists(unit)
    assert(not issecretvalue(unit), "secret offerer must not be used as a unit token")
    return state.units[unit] ~= nil
end
function UnitFullName(unit)
    local entry = state.units[unit]
    if entry then return entry.name, entry.realm end
end
function UnitAffectingCombat(unit)
    local entry = state.units[unit]
    return entry and entry.combat or false
end
function UnitIsConnected(unit)
    local entry = state.units[unit]
    return entry ~= nil and entry.connected ~= false
end
function UnitIsDeadOrGhost(unit)
    if unit == "player" then return state.dead or state.ghost end
    local entry = state.units[unit]
    return entry and entry.dead or false
end
function UnitIsDead(unit) return unit == "player" and state.dead end
function UnitIsGhost(unit) return unit == "player" and state.ghost end
function ResurrectHasSickness() return state.sickness end
function ResurrectHasTimer() return state.recovery end
function StaticPopup_Show(which) state.popup = which end
function StaticPopup_Hide(which)
    state.hides = state.hides + 1
    if state.popup == which then state.popup = nil end
end
function StaticPopup_Visible(which) return state.popup == which end
function AcceptResurrect()
    state.accepts = state.accepts + 1
end
function RepopMe() state.releases = state.releases + 1 end

assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_Game/Mainline/EventImplementation.lua"))()
assert(loadfile("modules/qol/qol.lua"))("QUI", {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = {
        CreateDBGetter = function() return function() return settings end end,
        IsSecretValue = issecretvalue,
    },
})
local frame = frames[1]
local function emit(event, ...) frame.scripts.OnEvent(frame, event, ...) end
local function flush(maxDelay)
    local pending = timers
    timers = {}
    table.sort(pending, function(a, b) return a[1] < b[1] end)
    for _, timer in ipairs(pending) do
        if not timer.cancelled and timer[1] <= (maxDelay or math.huge) then timer[2]() end
    end
end
local function reset(instance, key, mode)
    timers = {}
    settings = { autoAcceptResurrection = {}, autoRelease = "off" }
    if key then settings.autoAcceptResurrection[key] = mode end
    state = {
        instance = instance or "party", dead = true, ghost = false,
        shift = false, sickness = false, recovery = false, lockdown = false,
        encounter = false, raid = false, groupSize = 1,
        accepts = 0, hides = 0, releases = 0,
        units = { player = {}, party1 = { name = "Healer", realm = "Realm" } },
    }
    if instance == "raid" then
        state.raid, state.groupSize = true, 2
        state.units.raid1, state.units.party1 = state.units.party1, nil
        state.units.raid2 = state.units.player
    end
end
local function offer(inviter)
    inviter = inviter or "Healer-Realm"
    emit("RESURRECT_REQUEST", inviter)
    GameEvent.HandleResurrectRequest(nil, nil, inviter)
end
local count = 0
local function check(label, expected)
    flush()
    assert(state.accepts == expected, label .. ": expected " .. expected .. ", got " .. state.accepts)
    count = count + 1
end

reset("raid", "raid", "outOfCombat")
emit("RESURRECT_REQUEST", "Healer")
assert(state.accepts == 1, "post-wipe raid resurrection must be accepted on the event without waiting for a popup")
assert(state.popup == nil and #timers == 0, "resurrection acceptance must not depend on popup creation or deferred work")
count = count + 1

for _, location in ipairs({
    { "party", "dungeon" }, { "raid", "raid" }, { "pvp", "pvp" },
    { "arena", "pvp" }, { "none", "world" }, { "scenario", "world" },
}) do
    for _, mode in ipairs({ "off", "outOfCombat", "always", "invalid" }) do
        reset(location[1], location[2], mode)
        offer()
        local enabled = mode == "outOfCombat" or mode == "always"
        check(location[1] .. "/" .. mode, enabled and location[1] ~= "scenario" and 1 or 0)
    end
end

for _, mode in ipairs({ "outOfCombat", "always" }) do
    for _, guard in ipairs({ "shift", "sickness", "recovery", "alive" }) do
        reset("party", "dungeon", mode)
        if guard == "alive" then state.dead = false else state[guard] = true end
        offer()
        check(mode .. "/" .. guard, 0)
    end
end

for _, modes in ipairs({ false, "always", {} }) do
    reset("party")
    settings.autoAcceptResurrection = modes
    offer()
    check("missing or malformed configuration", 0)
end

reset("party", "dungeon", "outOfCombat")
state.difficulty = 8
offer()
check("Mythic+ uses dungeon setting", 1)

reset("party", "dungeon", "always")
state.dead, state.ghost = false, true
offer()
check("ghost can accept an incoming resurrection", 1)

for _, scenario in ipairs({
    { "lockdown", function() state.lockdown = true end },
    { "player combat", function() state.units.player.combat = true end },
    { "encounter", function() state.encounter = true end },
    { "other member combat", function()
        state.groupSize = 2
        state.units.party2 = { name = "Tank", realm = "Realm", combat = true }
    end },
    { "dead offerer", function() state.units.party1.dead = true end },
    { "offline offerer", function() state.units.party1.connected = false end },
    { "unknown offerer", function() state.units.party1.name = "SomeoneElse" end },
    { "secret name", function() state.units.party1.name = secret end },
    { "secret realm", function() state.units.party1.realm = secret end },
}) do
    for _, mode in ipairs({ "outOfCombat", "always" }) do
        reset("party", "dungeon", mode)
        scenario[2]()
        offer()
        check(scenario[1] .. "/" .. mode, 1)
    end
end

for _, mode in ipairs({ "outOfCombat", "always" }) do
    reset("pvp", "pvp", mode)
    offer(secret)
    check("secret inviter/" .. mode, 1)
    for _, inviter in ipairs({ "Healer", "Healer-Realm", "party1" }) do
        reset("party", "dungeon", mode)
        state.units.party1.combat = true
        offer(inviter)
        check("combat offerer/" .. inviter .. "/" .. mode, mode == "always" and 1 or 0)
    end
end

reset("raid", "raid", "outOfCombat")
state.units.raid2.combat = true
offer("Healer")
check("post-wipe raid offer ignores unrelated member combat", 1)

reset("raid", "raid", "outOfCombat")
state.units.raid1.name = secret
state.groupSize = 3
state.units.raid3 = { name = "Healer", realm = "Realm", combat = true }
offer()
check("secret unrelated member does not hide a resolved combat resurrector", 0)

reset("party", "dungeon", "outOfCombat")
state.units["Healer-Realm"] = { combat = true }
offer()
check("direct offerer unit resolution precedes roster fallback", 0)

reset("none", "world", "outOfCombat")
state.groupSize = 0
state.units.target, state.units.party1 = state.units.party1, nil
state.units.target.combat = true
offer()
check("target fallback checks nongroup offerer combat", 0)

reset("party", "dungeon", "outOfCombat")
state.groupSize = 2
state.units.party2 = { name = "Healer", realm = "AnotherRealm", combat = true }
offer("Healer")
check("bare inviter follows first resolved roster match", 1)
offer("Healer-AnotherRealm")
check("qualified inviter checks the matching realm", 1)

reset("party", "dungeon", "outOfCombat")
state.units.party1.combat = true
offer()
check("combat offer stays manual", 0)
state.units.party1.combat = false
emit("PLAYER_REGEN_ENABLED")
check("combat ending does not retry old offer", 0)

reset("party", "dungeon", "always")
offer()
check("failed acceptance attempted once", 1)
assert(state.popup == "RESURRECT_NO_TIMER" and state.hides == 0, "failed acceptance must preserve native popup")
emit("PLAYER_REGEN_ENABLED")
check("failed acceptance is not retried", 1)

reset("pvp", "pvp", "always")
settings.autoRelease = "pvp"
emit("PLAYER_DEAD")
offer()
assert(state.accepts == 1, "incoming resurrection must be accepted before delayed auto-release")
state.dead, state.ghost = false, false
GameEvent.HandlePlayerAlive()
check("resurrection before delayed auto-release", 1)
assert(state.popup == nil, "native PLAYER_ALIVE handler must clear successful resurrection popup")
assert(state.releases == 0, "auto-release must not release a resurrected player")

assert(frame.events.RESURRECT_REQUEST, "RESURRECT_REQUEST must be registered")
print("OK: qol_auto_accept_resurrection_test (" .. count .. " scenarios)")
