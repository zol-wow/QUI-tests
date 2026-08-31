-- tests/unit/aura_spell_catalog_test.lua
-- Run: LUA=luajit lua tests/unit/aura_spell_catalog_test.lua
--
-- Headless coverage for the Browse-popup spell catalog: the seen-aura
-- recorder (secret rejection, combat gate, cap eviction), the four section
-- builders in preset shape, and the exact-name fallback.

local function fail(msg)
    print("FAIL: aura_spell_catalog_test - " .. msg)
    os.exit(1)
end

local secretToken = { "secret" }
issecretvalue = function(v) return v == secretToken end

local now = 1000
time = function() return now end
local gameTime = 50
GetTime = function() return gameTime end
local inCombat = false
InCombatLockdown = function() return inCombat end
UnitExists = function(unit) return unit ~= "focus" end

local eventHandler
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, handler) eventHandler = handler end,
    }
end

QUI = { db = { global = {} } }

-- Aura data per unit/filter. One secret entry proves the loop stops safely.
local auras = {
    player = { HELPFUL = {
        { spellId = 774, name = "Rejuvenation", icon = 136081 },
        secretToken,
    }, HARMFUL = {} },
    target = { HELPFUL = {}, HARMFUL = {
        { spellId = 589, name = "Shadow Word: Pain", icon = 136207 },
        { spellId = secretToken, name = "Hidden", icon = 1 },
    } },
    party1 = { HELPFUL = {}, HARMFUL = {} },
    party2 = { HELPFUL = {}, HARMFUL = {} },
    party3 = { HELPFUL = {}, HARMFUL = {} },
    party4 = { HELPFUL = {}, HARMFUL = {} },
}
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index, filter)
        local list = auras[unit] and auras[unit][filter]
        return list and list[index] or nil
    end,
}

Enum = {
    SpellBookSpellBank = { Player = 0 },
    SpellBookItemType = { Spell = 1, Flyout = 2 },
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(index)
        if index == 1 then return { itemIndexOffset = 0, numSpellBookItems = 3 } end
        return { itemIndexOffset = 3, numSpellBookItems = 1 }
    end,
    GetSpellBookItemInfo = function(slot)
        local items = {
            { spellID = 8092, name = "Mind Blast", iconID = 136224, itemType = 1 },
            { spellID = 47540, name = "Penance", iconID = 237545, itemType = 1 },
            { spellID = 999, name = "Portals", iconID = 1, itemType = 2 },
            { spellID = 8092, name = "Mind Blast", iconID = 136224, itemType = 1 },
        }
        return items[slot]
    end,
}

C_ClassTalents = { GetActiveConfigID = function() return 11 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 77 } } end,
    GetTreeNodes = function() return { 1, 2, 3 } end,
    GetNodeInfo = function(_, nodeID)
        if nodeID == 1 then
            return { ranksPurchased = 1, activeEntry = { entryID = 101 } }
        end
        if nodeID == 2 then
            return { ranksPurchased = 0, activeEntry = { entryID = 102 } }
        end
        return {}
    end,
    GetEntryInfo = function(_, entryID)
        if entryID == 101 then return { definitionID = 201 } end
        return nil
    end,
    GetDefinitionInfo = function(definitionID)
        if definitionID == 201 then return { spellID = 373049 } end
        return nil
    end,
}
C_Spell = {
    GetSpellName = function(id)
        if id == 373049 then return "Power of the Dark Side" end
        return nil
    end,
    GetSpellTexture = function() return 12345 end,
    GetSpellInfo = function(identifier)
        if identifier == "Polymorph" then
            return { spellID = 118, name = "Polymorph", iconID = 136071 }
        end
        return nil
    end,
}

local ns = {}
ns.L = setmetatable({}, { __index = function(_, k) return k end })
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("modules/trackers/aura_spell_catalog.lua"))("QUI", ns)
local Catalog = ns.QUI_AuraSpellCatalog
if type(Catalog) ~= "table" then fail("catalog must export ns.QUI_AuraSpellCatalog") end

-- Recorder basics -------------------------------------------------------------

if Catalog.RecordAura(secretToken, "X") ~= false then
    fail("secret spell ids must be rejected")
end
if Catalog.RecordAura(101, secretToken) ~= false then
    fail("secret names must be rejected")
end
if Catalog.RecordAura(101, "Test Aura", 5555, true) ~= true then
    fail("valid auras must record")
end
local db = Catalog.SeenDB()
if not db[101] or db[101].name ~= "Test Aura" or db[101].harmful ~= true
    or db[101].icon ~= 5555 then
    fail("recorded entries must carry name/icon/harmful")
end

-- Event-driven recording with combat gate -------------------------------------

Catalog.Init()
if type(eventHandler) ~= "function" then fail("Init must install an event handler") end

inCombat = true
eventHandler(nil, "UNIT_AURA", "player")
if db[774] then fail("recording must be gated off in combat") end

inCombat = false
gameTime = gameTime + 10
eventHandler(nil, "UNIT_AURA", "player")
if not db[774] or db[774].harmful ~= false then
    fail("out of combat, unit auras must record with the buff flag")
end
eventHandler(nil, "UNIT_AURA", secretToken)
eventHandler(nil, "PLAYER_TARGET_CHANGED")
if not db[589] or db[589].harmful ~= true then
    fail("target debuffs must record with the debuff flag")
end

-- Cap eviction ----------------------------------------------------------------

for i = 1, 460 do
    now = now + 1
    Catalog.RecordAura(10000 + i, "Filler " .. i)
end
local count = 0
for _ in pairs(db) do count = count + 1 end
-- Pruning runs with slack (sorts only every ~40 inserts), so the store may
-- sit up to cap+slack between prunes but never beyond.
if count > 440 then fail("seen store must stay capped, got " .. count) end
if not db[10460] then fail("newest entries must survive the prune") end
if db[101] then fail("oldest entries must be evicted first") end

-- Sections --------------------------------------------------------------------

Catalog.InvalidateCache()
local sections = Catalog.BuildSections()
local byName = {}
for i = 1, #sections do byName[sections[i].name] = { section = sections[i], order = i } end

local active = byName["Active Auras"]
if not active or active.order ~= 1 then fail("Active Auras must lead the sections") end
local sawRejuv, sawSWP = false, false
for _, s in ipairs(active.section.spells) do
    if s.id == 774 and s.harmful == false then sawRejuv = true end
    if s.id == 589 and s.harmful == true then sawSWP = true end
end
if not (sawRejuv and sawSWP) then fail("active section must carry live auras with flags") end

local book = byName["My Spellbook"]
if not book then fail("spellbook section must build") end
if #book.section.spells ~= 2 then
    fail("spellbook must dedupe and skip flyouts, got " .. #book.section.spells)
end
if book.section.spells[1].name ~= "Mind Blast" then
    fail("spellbook entries must sort alphabetically")
end

local talents = byName["Talents"]
if not talents or #talents.section.spells ~= 1
    or talents.section.spells[1].id ~= 373049 then
    fail("talents must resolve selected entries to spells")
end

local seenSection = byName["Recently Seen"]
if not seenSection then fail("seen section must build from the store") end

if Catalog.BuildSections() ~= sections then
    fail("sections must cache within the TTL")
end
Catalog.InvalidateCache()
if Catalog.BuildSections() == sections then
    fail("InvalidateCache must force a rebuild")
end

-- Exact-name fallback ---------------------------------------------------------

if Catalog.ExactNameMatch("118") ~= nil then fail("numeric input must not name-match") end
if Catalog.ExactNameMatch("Po") ~= nil then fail("short input must not name-match") end
local match = Catalog.ExactNameMatch("Polymorph")
if not match or match.id ~= 118 or match.name ~= "Polymorph" then
    fail("exact names of loaded spells must resolve")
end

print("OK: aura_spell_catalog_test")
