-- tests/unit/cdm_index_test.lua
-- Headless verification of CDM index late-bound Blizzard API access.
-- Run: lua tests/unit/cdm_index_test.lua

_G.wipe = function(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

_G.issecretvalue = function()
    return false
end

_G.Enum = {
    CooldownViewerCategory = {
        TrackedBuff = 2,
        TrackedBar = 3,
        Essential = 0,
        Utility = 1,
        HiddenSpell = 4,
        HiddenAura = 5,
    },
}

_G.C_CooldownViewer = nil
_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end
_G.EventRegistry = {
    RegisterCallback = function() end,
}

local ns = {}
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")

local chunk = loadChunk("QUI_CDM/cdm/cdm_index.lua", "cdm_index.lua")
chunk("QUI", ns)

ns.CDMSources = {
    QueryBaseSpell = function(spellID)
        if spellID == 12346 then
            return 12345
        end
        return spellID
    end,
}

_G.C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(category, includeHidden)
        assert(includeHidden == true, "index should request hidden entries")
        if category == 0 then
            return { 88 }
        end
        return {}
    end,
    GetCooldownViewerCooldownInfo = function(cooldownID)
        if cooldownID == 88 then
            return {
                spellID = 12345,
                overrideSpellID = 12346,
                overrideTooltipSpellID = nil,
                linkedSpellIDs = { 12347 },
            }
        elseif cooldownID == 22 then
            return {
                spellID = 12345,
                overrideSpellID = nil,
                overrideTooltipSpellID = nil,
            }
        end
        error("unexpected cooldownID " .. tostring(cooldownID))
    end,
}

local index = assert(ns.CDMIndex, "CDMIndex table was not exported")
index.Rebuild()

local entry = index.Get(12346)
assert(entry, "late-bound C_CooldownViewer should populate index aliases")
assert(entry.cooldownID == 88, "wrong cooldownID")
assert(entry.primarySpellID == 12345, "late-bound CDMSources should normalize primary spellID")
assert(index.Get(12347) == entry, "linked aliases should share the same index entry")

local orderedCalls = 0
_G.CooldownViewerSettings = {
    GetDataProvider = function()
        orderedCalls = orderedCalls + 1
        return {
            -- memo fields present = cache already built by a secure consumer
            -- (cold-boot taint gate reads these raw; see cdm_index/cdm_catalog)
            displayDataDirty = false,
            displayData = {
                orderedCooldownIDs = { 88, 22 },
                cooldownInfoByID = {
                    [88] = { category = 0, isKnown = true },
                    [22] = { category = 2, isKnown = true },
                },
            },
            GetOrderedCooldownIDsForCategory = function()
                error("native ordered getters must remain untouched")
            end,
        }
    end,
}

local firstOrdered = index.GetOrderedSpellMap()
local callsAfterFirst = orderedCalls
local secondOrdered = index.GetOrderedSpellMap()

assert(secondOrdered == firstOrdered, "ordered spell map should be cached by index version")
assert(orderedCalls == callsAfterFirst, "cached ordered spell map should not re-walk provider")
assert(firstOrdered[12345] and firstOrdered[12345].cooldownID == 22,
    "generic ordered spell map keeps the first visible duplicate")
assert(index.GetOrderedForContainer("essential", 12345).cooldownID == 88,
    "container ordered lookup should return the Essential cooldownID, not a duplicate from another viewer")
assert(index.GetOrderedForContainer("buff", 12345).cooldownID == 22,
    "container ordered lookup should return the Buff cooldownID for the same spell")

index.Notify("manual")
local thirdOrdered = index.GetOrderedSpellMap()

assert(thirdOrdered ~= firstOrdered, "ordered spell map should rebuild after index invalidation")
assert(orderedCalls > callsAfterFirst, "ordered map rebuild should re-walk provider after invalidation")

local aliasSlot, directSlot = 170469, 170470
local sourceID, auraID, linkedOnlyID = 433901, 433925, 433926
local orderedIDs = { aliasSlot, directSlot }
local slotInfo = {
    [aliasSlot] = {
        category = 2,
        spellID = sourceID,
        overrideSpellID = sourceID,
        overrideTooltipSpellID = auraID,
        linkedSpellIDs = { auraID, linkedOnlyID },
    },
    [directSlot] = { category = 2, spellID = auraID },
}
_G.C_CooldownViewer.GetCooldownViewerCooldownInfo = function(id)
    return slotInfo[id]
end
_G.CooldownViewerSettings.GetDataProvider = function()
    return {
        displayData = { orderedCooldownIDs = orderedIDs, cooldownInfoByID = slotInfo },
    }
end

for _, order in ipairs({ { aliasSlot, directSlot }, { directSlot, aliasSlot } }) do
    orderedIDs = order
    index.Notify("manual")
    assert(index.GetOrderedForContainer("buff", auraID).cooldownID == directSlot,
        "an aura's own native slot must win over another slot's tooltip or linked alias in either order")
    assert(index.GetOrderedForContainer("buff", sourceID).cooldownID == aliasSlot,
        "the source ability must retain its own native slot")
    assert(index.GetOrderedForContainer("buff", linkedOnlyID).cooldownID == aliasSlot,
        "a linked variant without its own slot must retain alias fallback")
    assert(index.GetOrdered(auraID).cooldownID == order[1],
        "generic ordered lookups must retain their existing first-alias contract")
end

orderedIDs = { aliasSlot }
index.Notify("manual")
assert(index.GetOrderedForContainer("buff", sourceID).cooldownID
        == index.GetOrderedForContainer("buff", auraID).cooldownID,
    "Essence source and tooltip must resolve to one slot when Blizzard exposes only one")

local strikeSlot, essenceSlot = 157116, 170469
slotInfo = {
    [strikeSlot] = {
        category = 2, cooldownID = strikeSlot, spellID = sourceID,
        overrideSpellID = sourceID, linkedSpellIDs = { 433899 },
        charges = false, hasAura = false, selfAura = true, buffSlot = 1,
        flags = 2, isKnown = true, isInvisible = false,
    },
    [essenceSlot] = {
        category = 2, cooldownID = essenceSlot, spellID = sourceID,
        overrideSpellID = sourceID, overrideTooltipSpellID = auraID,
        linkedSpellIDs = { auraID },
        charges = false, hasAura = false, selfAura = true, buffSlot = 1,
        flags = 2, isKnown = true, isInvisible = false,
    },
}
for _, order in ipairs({ { essenceSlot, strikeSlot }, { strikeSlot, essenceSlot } }) do
    orderedIDs = order
    index.Notify("manual")
    assert(index.GetOrderedForContainer("buff", sourceID).cooldownID == strikeSlot,
        "live Vampiric Strike identity must prefer its own displayed slot in either order")
    assert(index.GetOrderedForContainer("buff", auraID).cooldownID == essenceSlot,
        "live Essence identity must retain its tooltip slot in either order")
    assert(index.GetOrderedForContainer("buff", sourceID).cooldownInfo == slotInfo[strikeSlot],
        "ordered records must retain their own cached slot metadata")
    assert(index.GetOrderedForContainer("buff", 433899).cooldownID == strikeSlot,
        "live Strike linked identity must retain its own slot")
    assert(index.GetOrdered(sourceID).cooldownID == order[1],
        "live shared source must preserve generic first-alias lookup")
end

print("OK: cdm_index_test")
