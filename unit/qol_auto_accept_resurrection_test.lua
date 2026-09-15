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
function UnitExists(unit) return state.units[unit] ~= nil end
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
    if state.succeeds then
        state.dead, state.ghost = false, false
        GameEvent.HandlePlayerAlive()
    end
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

for _, location in ipairs({
    { "party", "dungeon" }, { "raid", "raid" }, { "pvp", "pvp" },
    { "arena", "pvp" }, { "none", "world" }, { "scenario", "world" },
}) do
    for _, mode in ipairs({ "off", "outOfCombat", "always", "invalid" }) do
        reset(location[1], location[2], mode)
        offer()
        assert(state.accepts == 0, "acceptance must wait until native popup creation")
        local enabled = mode == "outOfCombat" or mode == "always"
        check(location[1] .. "/" .. mode, enabled and location[1] ~= "scenario" and 1 or 0)
    end
end

for _, mode in ipairs({ "outOfCombat", "always" }) do
    for _, guard in ipairs({ "shift", "sickness", "recovery", "alive", "popup" }) do
        for _, deferred in ipairs({ false, true }) do
            reset("party", "dungeon", mode)
            local function block()
                if guard == "alive" then state.dead = false
                elseif guard == "popup" then state.popup = nil
                else state[guard] = true end
            end
            if not deferred and guard ~= "popup" then block() end
            offer()
            if deferred or guard == "popup" then block() end
            check(mode .. "/" .. guard .. "/" .. tostring(deferred), 0)
        end
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
    { "offerer combat", function() state.units.party1.combat = true end },
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
        check(scenario[1] .. "/" .. mode, mode == "always" and 1 or 0)
    end
end

for _, mode in ipairs({ "outOfCombat", "always" }) do
    reset("pvp", "pvp", mode)
    offer(secret)
    check("secret inviter/" .. mode, mode == "always" and 1 or 0)
end

reset("raid", "raid", "outOfCombat")
state.raid = true
state.units.raid1, state.units.party1 = state.units.party1, nil
offer()
check("raid roster resolves offerer", 1)

reset("none", "world", "outOfCombat")
state.groupSize = 0
state.units.target, state.units.party1 = state.units.party1, nil
offer()
check("target resolves nongroup offerer", 1)

reset("party", "dungeon", "outOfCombat")
state.groupSize = 2
state.units.party2 = { name = "Healer", realm = "AnotherRealm" }
offer("Healer")
check("ambiguous bare inviter", 0)

reset("party", "dungeon", "outOfCombat")
offer("Healer")
check("unique bare inviter", 1)

for _, mutation in ipairs({ "shifted offer", "disabled setting", "new offer", "combat", "location" }) do
    reset("party", "dungeon", "outOfCombat")
    offer()
    if mutation == "shifted offer" then
        state.shift = true
        offer()
        state.shift = false
    elseif mutation == "disabled setting" then
        settings.autoAcceptResurrection.dungeon = "off"
    elseif mutation == "new offer" then offer()
    elseif mutation == "combat" then state.units.party1.combat = true
    elseif mutation == "location" then
        state.instance = "raid"
        settings.autoAcceptResurrection.raid = "always"
    end
    check(mutation .. " before callback", mutation == "new offer" and 1 or 0)
end

for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    reset("party", "dungeon", "always")
    offer()
    emit(event)
    flush(0)
    assert(state.accepts == 0, event .. " must invalidate the pending offer")
    count = count + 1
end

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
state.succeeds = true
emit("PLAYER_DEAD")
offer()
check("resurrection before delayed auto-release", 1)
assert(state.popup == nil, "native PLAYER_ALIVE handler must clear successful resurrection popup")
assert(state.releases == 0, "auto-release must not release a resurrected player")

assert(frame.events.RESURRECT_REQUEST, "RESURRECT_REQUEST must be registered")
print("OK: qol_auto_accept_resurrection_test (" .. count .. " scenarios)")
