local function noop() end
_G.InCombatLockdown = function() return false end
_G.GetTime = function() return 100 end
_G.UnitRace = function() return "Test", "Test" end
_G.UnitClass = function() return "Test", "Test" end
_G.CreateFrame = function()
    return { RegisterEvent = noop, RegisterUnitEvent = noop, SetScript = noop,
        UnregisterEvent = noop, UnregisterAllEvents = noop }
end

_G.GENERAL = "General"
_G.Enum = { SpellBookSpellBank = { Player = 0 } }
local entries = {
    { spellID = 100 },
    { spellID = 200, isPassive = true },
    { spellID = 101, lowRank = true },
    { spellID = 102 },
    { spellID = 103 },
    { spellID = 104 },
    { spellID = 102 },
    { spellID = 105, isOffSpec = true },
    { spellID = 201, isPassive = true, lowRank = true },
    { spellID = 202, isPassive = true },
    { spellID = 203, isPassive = true },
    { spellID = 204, isPassive = true },
    { spellID = 202, isPassive = true },
    { spellID = 205, isPassive = true, isOffSpec = true },
    {},
}
_G.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(tab)
        if tab == 1 then
            return { name = GENERAL, itemIndexOffset = 0, numSpellBookItems = 2 }
        end
        return { name = "Class", itemIndexOffset = 2, numSpellBookItems = #entries - 2 }
    end,
    GetSpellBookItemInfo = function(slot, bank)
        assert(bank == Enum.SpellBookSpellBank.Player)
        return entries[slot]
    end,
}

local function loadSpellData()
    local ns = {
        Helpers = {},
        CDMSources = {
            QuerySpellInfo = function(id)
                return { name = "Same name", iconID = id }
            end,
            QuerySpellBaseCooldown = function() return 3000 end,
        },
    }
    dofile("tests/helpers/load_cdm_spelldata_runtime.lua")(ns)
    assert(loadfile("QUI_CDM/cdm/cdm_spelldata.lua"))("QUI", ns)
    return ns.CDMSpellData
end

local function assertIDs(actual, expected, label)
    assert(#actual == #expected, label .. ": expected " .. #expected .. " entries, got " .. #actual)
    for i, id in ipairs(expected) do
        assert(actual[i].spellID == id, label .. ": unexpected spell at position " .. i)
        assert(actual[i].name == "Same name" and actual[i].icon == id,
            label .. ": spell display data must survive filtering")
    end
end

local retail = loadSpellData()
assertIDs(retail:GetAllLearnedCooldowns(), { 101, 102, 103, 104 }, "no rank API: active")
assertIDs(retail:GetPassiveAuras(), { 201, 202, 203, 204 }, "no rank API: passive")

C_SpellBook.IsSpellBookItemLowRank = function(slot, bank)
    assert(entries[slot], "rank lookup must receive a spellbook slot, not a spell ID")
    assert(bank == Enum.SpellBookSpellBank.Player, "rank lookup must use the player bank")
    return entries[slot].lowRank or false
end
local ranked = loadSpellData()
assertIDs(ranked:GetAllLearnedCooldowns(), { 102, 103, 104 }, "rank API: active")
assertIDs(ranked:GetPassiveAuras(), { 202, 203, 204 }, "rank API: passive")

entries[3].lowRank, entries[9].lowRank = false, false
for _, slot in ipairs({ 4, 7, 10, 13 }) do
    entries[slot].isOffSpec = true
end
ranked:InvalidateLearnedCache()
assertIDs(ranked:GetAllLearnedCooldowns(), { 101, 103, 104 }, "changed highest known rank: active")
assertIDs(ranked:GetPassiveAuras(), { 201, 203, 204 }, "changed highest known rank: passive")
print("OK: cdm_spelldata_spellbook_rank_test")
