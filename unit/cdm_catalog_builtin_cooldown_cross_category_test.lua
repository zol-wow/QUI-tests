-- tests/unit/cdm_catalog_builtin_cooldown_cross_category_test.lua
-- Built-in QUI cooldown containers can add Blizzard-CDM cooldowns from either
-- Blizzard Essential or Utility; runtime will claim the live frame from either
-- viewer. Run: lua tests/unit/cdm_catalog_builtin_cooldown_cross_category_test.lua

_G.issecretvalue = function() return false end
_G.C_CooldownViewer = nil

local ns = {}
-- Task 45f: cdm_catalog.lua routes discarded-result pcall guards through
-- ns.SafeCall. Additive stub (T1d/T1e precedent) — bare pcall passthrough.
ns.SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end
ns.SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end
ns.SafeCallMethodIfPresent = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_catalog.lua", "cdm_catalog.lua")("QUI", ns)

ns.CDMSources = {
    QuerySpellInfo = function(spellID)
        if spellID == 111 then return { name = "Essential Spell", iconID = 1110 } end
        if spellID == 222 then return { name = "Utility Spell", iconID = 2220 } end
        return nil
    end,
    QueryOverrideSpell = function(spellID) return spellID end,
}

_G.C_CooldownViewer = {
    GetCooldownViewerCategorySet = function()
        error("built-in picker must use the ordered provider categories")
    end,
    GetCooldownViewerCooldownInfo = function(cooldownID)
        if cooldownID == 10 then return { spellID = 111, isKnown = true } end
        if cooldownID == 20 then return { spellID = 222, isKnown = true } end
        error("unexpected cooldownID " .. tostring(cooldownID))
    end,
}

local requestedCategories = {}
_G.CooldownViewerSettings = {
    GetDataProvider = function()
        return {
            -- memo fields present = cache already built by a secure consumer
            -- (cold-boot taint gate reads these raw; see cdm_index/cdm_catalog)
            displayDataDirty = false,
            displayData = {
                orderedCooldownIDs = { 10, 20 },
                cooldownInfoByID = {
                    [10] = { category = 0, isKnown = true },
                    [20] = { category = 1, isKnown = true },
                },
            },
            GetLayoutManager = function() return {} end,
            GetOrderedCooldownIDsForCategory = function()
                error("native ordered getters must remain untouched")
            end,
        }
    end,
}

local catalog = assert(ns.CDMCatalog, "CDMCatalog not exported")
local getTrackedCategorySet = catalog.GetTrackedCategorySet
catalog.GetTrackedCategorySet = function(category, allowUnlearned)
    requestedCategories[#requestedCategories + 1] = category
    return getTrackedCategorySet(category, allowUnlearned)
end
local available = catalog.GetAvailableSpellsForContainer("essential", "cooldown", {}, {})

local bySpellID = {}
for _, entry in ipairs(available) do
    bySpellID[entry.spellID] = entry
end

assert(requestedCategories[1] == 0 and requestedCategories[2] == 1,
    "essential picker should query Essential then Utility ordered categories")
assert(bySpellID[111], "essential-category cooldown missing")
assert(bySpellID[222], "utility-category cooldown should still be addable to QUI Essential")

requestedCategories = {}
available = catalog.GetAvailableSpellsForContainer("utility", "cooldown", { [222] = true }, {})
bySpellID = {}
for _, entry in ipairs(available) do
    bySpellID[entry.spellID] = entry
end

assert(requestedCategories[1] == 1 and requestedCategories[2] == 0,
    "utility picker should query Utility then Essential ordered categories")
assert(not bySpellID[222], "owned utility spell should remain filtered")
assert(bySpellID[111], "essential-category cooldown should still be addable to QUI Utility")

print("OK cdm_catalog_builtin_cooldown_cross_category_test")
