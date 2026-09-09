-- tests/unit/reminders_defensives_secret_test.lua
-- Run: lua tests/unit/reminders_defensives_secret_test.lua
--
-- Readiness, coverage and boss ownership are tri-state. Secret numbers must
-- never be compared; the NeverSecret isActive/isOnGCD booleans decide, and a
-- fully secret answer surfaces as nil, not false.
-- luacheck: globals issecretvalue C_Spell C_Item C_UnitAuras UnitExists UnitThreatSituation IsPlayerSpell UnitClass GetInventoryItemID GetInventoryItemTexture LibStub LIB_OPEN_RAID_COOLDOWNS_INFO

local SECRET = setmetatable({ __secret = true }, {
    __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end,
    __add = function() error("arithmetic on a secret") end,
})
function issecretvalue(v) return type(v) == "table" and rawget(v, "__secret") == true end

local frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(name, fn) self[name] = fn end
    frames[#frames + 1] = f
    return f
end

local ns = {
    Helpers = {
        IsSecretValue = function(v) return issecretvalue(v) end,
        GetCurrentSpecID = function() return 250 end,
    },
    L = setmetatable({}, { __index = function(_, k) return k end }),
    AuraGlue = { AurasAreSecret = function() return false end },
}

local cooldowns, charges = {}, {}
C_Spell = {
    GetSpellCooldown = function(id) return cooldowns[id] end,
    GetSpellCharges = function(id) return charges[id] end,
    GetSpellName = function(id) return "Spell" .. id end,
    GetSpellTexture = function() return 1 end,
}
local itemCooldowns = {}
C_Item = {
    GetItemCooldown = function(itemID) local c = itemCooldowns[itemID]; return c[1], c[2], c[3] end,
    GetItemSpell = function() return "Use", 90001 end,
    GetItemNameByID = function() return "Shiny Trinket" end,
}
function IsPlayerSpell(id) return id ~= 4 and id ~= 9 end
C_SpellBook = {
    IsSpellInSpellBook = function() return true end,      -- true even for unknown overrides
    IsSpellKnown = function(id) return id ~= 4 and id ~= 9 end,
}
function UnitClass() return "Player", "DEATHKNIGHT" end
function GetInventoryItemID(_, slot) if slot == 13 then return 5555 end end
function GetInventoryItemTexture() return 2 end
local auras = {}
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
local bossExists, threat = true, nil
local threatByUnit = {}
function UnitExists(unit) return (unit == "boss1" and bossExists) or threatByUnit[unit] ~= nil end
function UnitThreatSituation(_, unit) if threatByUnit[unit] ~= nil then return threatByUnit[unit] end return threat end
LIB_OPEN_RAID_COOLDOWNS_INFO = {
    [48792] = { class = "DEATHKNIGHT", type = 2, specs = { 250, 251, 252 } },
    [55233] = { class = "DEATHKNIGHT", type = 2, specs = { 250 } },
    [49028] = { class = "DEATHKNIGHT", type = 1, specs = { 250 } },      -- offensive: excluded
    [33206] = { class = "PRIEST", type = 3, specs = { 256 } },            -- other class: excluded
    [4]     = { class = "DEATHKNIGHT", type = 2, specs = {} },            -- not known on this character
}

assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("QUI_Reminders/reminders/defensives.lua"))("QUI_Reminders", ns)
local D = assert(ns.RemindersDefensives)

-- Candidates come from the dataset filtered to class/spec/personal.
local cands = D.SpecCandidates()
local ids = {}
for _, c in ipairs(cands) do ids[c.spellID] = c end
assert(ids[48792] and ids[55233] and ids[4], "personal defensives for the class listed")
assert(not ids[49028] and not ids[33206], "offensive and other-class entries excluded")
assert(ids[4].known == false and ids[48792].known == true, "known flag follows the spellbook")
assert(cands[#cands].spellID == 4, "unknown spells sort last")
local trinkets = D.TrinketCandidates()
assert(#trinkets == 1 and trinkets[1].id == "slot:13" and trinkets[1].spellID == 90001 and trinkets[1].kind == "item")

-- Readiness: booleans decide; secret numbers are never touched. isOnGCD is
-- only believed from the SPELL_UPDATE_COOLDOWN snapshot.
cooldowns[1] = { isActive = false, startTime = SECRET, duration = SECRET }
assert(D.IsReady(D.Describe(1)) == true, "inactive cooldown is ready even with secret numbers")
cooldowns[2] = { isActive = true, isOnGCD = true, startTime = SECRET, duration = SECRET }
cooldowns[61304] = { isActive = true }
assert(D.IsReady(D.Describe(2)) == nil, "live isOnGCD is not trusted: unknowable while the GCD runs")
cooldowns[61304] = { isActive = false }
assert(D.IsReady(D.Describe(2)) == false, "no global cooldown running: the active cooldown is real")
D.SetWatchedSpells({ 2, 3 })
assert(#frames == 1 and frames[1].events.SPELL_UPDATE_COOLDOWN, "watcher listens for SPELL_UPDATE_COOLDOWN")
cooldowns[61304] = { isActive = true }
assert(D.IsReady(D.Describe(2)) == nil, "watching alone takes no snapshot: still unknowable")
frames[1].OnEvent(frames[1], "SPELL_UPDATE_COOLDOWN")
assert(D.IsReady(D.Describe(2)) == true, "snapshot from the event: GCD-only counts as ready")
cooldowns[2].isOnGCD = false
assert(D.IsReady(D.Describe(2)) == true, "stale live flag ignored until the next cooldown event")
frames[1].OnEvent(frames[1], "SPELL_UPDATE_COOLDOWN")
assert(D.IsReady(D.Describe(2)) == false, "snapshot refreshed: real cooldown")
D.SetWatchedSpells({ 3 })
assert(D.IsReady(D.Describe(2)) == nil, "unwatching clears the stale snapshot")
D.SetWatchedSpells({})
assert(not D.IsWatching() and not frames[1].events.SPELL_UPDATE_COOLDOWN, "empty watch list unregisters the cooldown event")
D.SetWatchedSpells({ 2, 3 })
assert(D.IsWatching() and frames[1].events.SPELL_UPDATE_COOLDOWN, "watching again re-registers")
D.SetWatchedSpells({ 2, 3 })
cooldowns[8] = { isActive = false, isEnabled = false }
assert(D.IsReady(D.Describe(8)) == false, "a cooldown on hold is not ready")
cooldowns[3] = { isActive = true, isOnGCD = false, startTime = SECRET, duration = SECRET }
charges[3] = { currentCharges = SECRET, maxCharges = 2, isActive = true }
frames[1].OnEvent(frames[1], "SPELL_UPDATE_COOLDOWN")
assert(D.IsReady(D.Describe(3)) == false, "active, not GCD, charges unreadable: on cooldown")
charges[3] = { currentCharges = 1, maxCharges = 2, isActive = true }
assert(D.IsReady(D.Describe(3)) == true, "a readable spare charge is ready")
cooldowns[61304] = { isActive = SECRET }
cooldowns[5] = { isActive = SECRET, startTime = SECRET, duration = SECRET }
assert(D.IsReady(D.Describe(5)) == nil, "nothing readable: unknowable, not false")
cooldowns[6] = { isActive = true, isOnGCD = false, startTime = 100, duration = 1.5 }
assert(D.IsReady(D.Describe(6)) == true, "short readable duration is the GCD")
cooldowns[7] = nil
assert(D.IsReady(D.Describe(7)) == nil, "no cooldown info: unknowable")
assert(D.IsReady(D.Describe(4)) == false, "unknown spell is never ready")
assert(D.SpellKnown(9) == false, "spellbook membership alone does not make a spell known")

itemCooldowns[5555] = { 0, 0, 1 }
assert(D.IsReady(D.Describe("slot:13")) == true, "trinket off cooldown")
itemCooldowns[5555] = { 100, 90, 1 }
assert(D.IsReady(D.Describe("slot:13")) == false, "trinket on cooldown")
itemCooldowns[5555] = { SECRET, SECRET, 1 }
assert(D.IsReady(D.Describe("slot:13")) == nil, "secret trinket cooldown is unknowable")
itemCooldowns[5555] = { 0, 0, false }
assert(D.IsReady(D.Describe("slot:13")) == false, "trinket cooldown on hold is not ready")
itemCooldowns[5555] = { 0, 0, 0 }
assert(D.IsReady(D.Describe("slot:13")) == false, "numeric on-hold flag is honoured too")
assert(D.Describe("slot:14") == nil, "empty slot resolves to nothing")

-- Pick: first ready wins; unknowns are a fallback, never preferred over ready.
local entry, confirmed = D.Pick({ 3, 5, 1 })
charges[3] = { currentCharges = 0, maxCharges = 2, isActive = true }
entry, confirmed = D.Pick({ 3, 5, 1 })
assert(entry.spellID == 1 and confirmed == true, "first confirmed-ready entry wins over an earlier unknown")
entry, confirmed = D.Pick({ 3, 5 })
assert(entry.spellID == 5 and confirmed == false, "unknown is the fallback when nothing is confirmed")
assert(D.Pick({ 3 }) == nil, "all on cooldown: nothing")

-- Coverage.
assert(D.IsCovered({ 1, 2 }) == false, "no auras: not covered")
auras[2] = { spellId = 2 }
assert(D.IsCovered({ 1, 2 }) == true, "listed defensive active: covered")
auras[2] = SECRET
assert(D.IsCovered({ 1, 2 }) == nil, "secret aura answer: unknowable")
auras[2] = nil
ns.AuraGlue.AurasAreSecret = function() return true end
assert(D.IsCovered({ 1, 2 }) == nil, "aura restriction: unknowable without touching the API")
ns.AuraGlue.AurasAreSecret = function() return false end

-- Boss ownership.
bossExists = false
assert(D.IsTankingBoss() == nil, "no boss unit: unknowable")
bossExists = true
threat = SECRET
assert(D.IsTankingBoss() == nil, "secret threat: unknowable")
threat = 3
assert(D.IsTankingBoss() == true)
threat = 0
assert(D.IsTankingBoss() == false)
threatByUnit.boss2 = SECRET
assert(D.IsTankingBoss() == nil, "one readable non-tanking boss plus one unknown boss: unknowable")
threatByUnit.boss2 = 3
assert(D.IsTankingBoss() == true, "tanking the second boss counts")
threatByUnit.boss2 = 1
assert(D.IsTankingBoss() == false, "every boss readably elsewhere: not tanking")
threatByUnit.boss2 = nil

assert(D.PlayerClass() == "DEATHKNIGHT" and D.PlayerSpecID() == 250)

print("OK: reminders_defensives_secret_test")
