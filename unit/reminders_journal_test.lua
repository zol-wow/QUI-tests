-- tests/unit/reminders_journal_test.lua
-- Run: lua tests/unit/reminders_journal_test.lua
--
-- The journal reader walks the latest tier's dungeons and raids, every boss,
-- and every section with a spell id, dedupes abilities per boss, labels them
-- with the journal's own icon flags, and leaves the journal's tier selection
-- where it found it.
-- luacheck: globals EJ_GetNumTiers EJ_GetCurrentTier EJ_SelectTier EJ_GetInstanceByIndex EJ_SelectInstance EJ_GetEncounterInfoByIndex C_EncounterJournal C_AddOns Enum EncounterJournal

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }

local selectedTier, selectedInstance = 3, nil
function EJ_GetNumTiers() return 5 end
function EJ_GetCurrentTier() return selectedTier end
function EJ_SelectTier(tier) selectedTier = tier end
local instances = {
    [false] = { { 1001, "Ara-Kara" } },
    [true] = { { 2001, "Nerub-ar Palace" }, { 2002, "Liberation" } },
}
function EJ_GetInstanceByIndex(index, isRaid)
    local row = instances[isRaid][index]
    if not row then return nil end
    return row[1], row[2]
end
function EJ_SelectInstance(id) selectedInstance = id end
local encounters = {
    [1001] = { { "Avanoxx", 3001, 100 }, { "Anub'zekt", 3002, 200 } },
    [2001] = { { "Ulgrax", 3003, 300 } },
    [2002] = {},
}
function EJ_GetEncounterInfoByIndex(index, instanceID)
    local row = encounters[instanceID][index]
    if not row then return nil end
    return row[1], "desc", row[2], row[3]
end
local sections = {
    [100] = { spellID = 0, title = "Overview", headerType = 3, firstChildSectionID = 101, siblingSectionID = 110 },
    [101] = { spellID = 5001, title = "Alerting Shrill", firstChildSectionID = 102 },
    [102] = { spellID = 5002, title = "Voracious Bite", siblingSectionID = 103 },
    [103] = { spellID = 5001, title = "Alerting Shrill (dup)" },
    [110] = { spellID = 5003, title = "Insatiable" },
    [200] = { spellID = 6001, title = "Burrow Charge" },
    [300] = { spellID = 7001, title = "Hulking Crash" },
}
local flags = { [101] = { 2 }, [102] = { 0, 4 }, [110] = { 1 } }
C_EncounterJournal = {
    GetSectionInfo = function(id) return sections[id] end,
    GetSectionIconFlags = function(id) return flags[id] end,
}
Enum = { JournalEncounterIconFlags = { Tank = 1, Dps = 2, Healer = 4, Heroic = 8, Deadly = 16 } }
local loaded = {}
C_AddOns = {
    IsAddOnLoaded = function(name) return loaded[name] == true end,
    LoadAddOn = function(name) loaded[name] = true; return true end,
}

assert(loadfile("QUI_Reminders/reminders/journal.lua"))("QUI_Reminders", ns)
local J = assert(ns.RemindersJournal)

-- Flag index mapping follows the enum's bit positions.
local names = J.FlagIndexNames()
assert(names[0] == "Tank" and names[1] == "Dps" and names[2] == "Healer" and names[4] == "Deadly", "flag indices")

-- Open journal: refuse to move its selection.
EncounterJournal = { IsShown = function() return true end }
assert(J.Get() == nil and not J.IsCached(), "no scrape while the journal is open")
EncounterJournal = nil

local catalog = assert(J.Get())
assert(loaded.Blizzard_EncounterJournal, "journal addon loaded on demand")
assert(catalog.tier == 5 and selectedTier == 3, "walks the latest tier and restores the previous selection")
assert(#catalog.instances == 3, "dungeons then raids")
assert(catalog.instances[1].name == "Ara-Kara" and catalog.instances[1].isRaid == false)
assert(catalog.instances[2].isRaid == true and catalog.instances[3].name == "Liberation")
assert(#catalog.instances[3].encounters == 0, "empty raid tolerated")

local avanoxx = catalog.instances[1].encounters[1]
assert(avanoxx.id == 3001 and avanoxx.name == "Avanoxx")
assert(#avanoxx.abilities == 3, "children before siblings, duplicates dropped, overview skipped; got " .. #avanoxx.abilities)
assert(avanoxx.abilities[1].spellID == 5001 and avanoxx.abilities[1].flags.Healer, "healer flag from index 2")
assert(avanoxx.abilities[2].spellID == 5002 and avanoxx.abilities[2].flags.Tank and avanoxx.abilities[2].flags.Deadly, "tank + deadly")
assert(avanoxx.abilities[3].spellID == 5003 and avanoxx.abilities[3].flags.Dps)
assert(catalog.instances[1].encounters[2].abilities[1].spellID == 6001)
assert(catalog.instances[2].encounters[1].abilities[1].spellID == 7001)

-- Cache + lookups.
assert(J.Get() == catalog, "cached")
local inst, enc, ability = J.FindAbility(7001)
assert(inst.id == 2001 and enc.id == 3003 and ability.name == "Hulking Crash")
assert(J.FindAbility(9999) == nil)
local i2, e2 = J.FindEncounter(3002)
assert(i2.id == 1001 and e2.name == "Anub'zekt")
J.Invalidate()
assert(not J.IsCached())
assert(J.Get(true) ~= catalog, "force rebuild")

-- A section-walk that loops is bounded.
sections[300].siblingSectionID = 300
assert(J.Get(true), "cyclic sibling chain terminates")

print("OK: reminders_journal_test")
