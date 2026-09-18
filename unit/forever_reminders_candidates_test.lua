local known = { [871] = true, [642] = true, [100] = true }
local class = "WARRIOR"
local ns = {
    Client = { isForever = true },
    Helpers = { GetCurrentSpecID = function() return 98765 end },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}
local env = setmetatable({
    C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end },
    C_Spell = {
        GetSpellName = function(id) return "Spell " .. id end,
        GetSpellTexture = function() return 1 end,
    },
    UnitClass = function() return class, class end,
    IsPlayerSpell = false,
    IsSpellKnown = false,
    LibStub = function() error("Forever candidate discovery must not initialize LibOpenRaid") end,
    LIB_OPEN_RAID_COOLDOWNS_INFO = {
        [100] = { class = "WARRIOR", type = 2, specs = { 98765 } },
    },
}, { __index = _G })
env._G = env
local function load(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk("QUI_Reminders", ns)
end
load("core/safecall.lua")
load("QUI_Reminders/reminders/defensive_spell_classes.lua")
load("QUI_Reminders/reminders/defensives.lua")
local D = ns.RemindersDefensives
local candidates = D.SpecCandidates()
assert(#candidates == 1 and candidates[1].spellID == 871 and candidates[1].known,
    "Forever must suggest known Shield Wall despite different spec IDs, excluding unknown, other-class and external dataset entries")
known[12975] = true
candidates = D.SpecCandidates()
assert(#candidates == 2, "newly learned personal defensives must appear")
known[871], known[12975] = nil, nil
assert(#D.SpecCandidates() == 0, "unlearned spells must disappear")
class = "PALADIN"
assert(D.SpecCandidates()[1].spellID == 642, "candidate classes must follow the player")
assert(D.Describe(123456).spellID == 123456, "manual spell entries must remain available")
assert(env.LIB_OPEN_RAID_COOLDOWNS_INFO[100], "isolated catalog must not overwrite a different addon's dataset")

local file = assert(io.open("libs/LibOpenRaid/ThingsToMantain_Midnight.lua", "r"))
local source = file:read("*a")
file:close()
local count = 0
for line in source:gmatch("[^\n]+") do
    local id, sourceClass = line:match('^%s*%[(%d+)%]%s*=.*class%s*=%s*"([A-Z]+)".*type%s*=%s*2[,}]')
    if id then
        assert(ns.RemindersDefensiveSpellClasses[tonumber(id)] == sourceClass,
            "derived catalog must match upstream personal-defensive classifications")
        count = count + 1
    end
end
local catalogCount = 0
for _ in pairs(ns.RemindersDefensiveSpellClasses) do catalogCount = catalogCount + 1 end
assert(count == catalogCount and count > 0, "catalog must contain exactly the upstream classifications")
ns.RemindersDefensiveSpellClasses = nil
assert(#D.SpecCandidates() == 0, "missing isolated catalog must not fall back to a different client's dataset")
ns.Client.isForever = false
load("QUI_Reminders/reminders/defensive_spell_classes.lua")
assert(ns.RemindersDefensiveSpellClasses == nil, "Retail must not allocate the Forever catalog")
class = "WARRIOR"
assert(D.SpecCandidates()[1].spellID == 100, "Retail must retain its existing per-spec dataset")
print("OK: Forever candidates use upstream classification and actual client spell knowledge")
