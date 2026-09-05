-- tests/unit/cdm_provider_displaydata_gate_test.lua
-- Cold-boot taint gate: QUI must never be the FIRST caller into Blizzard's
-- CooldownViewerSettings data provider getters. Those getters lazily build
-- the shared displayData cache (CheckBuildDisplayData); building it on QUI's
-- stack taints the cooldownInfo/order tables that the viewer's own secure
-- RefreshData/GetCooldownIDs read at item mint -- every buff item is then
-- born isActive=false for the session (aura reads secret, the
-- DisallowTaintedAccess aura map rejects registration). /reload healed
-- because a SHOWN viewer rebuilds the cache securely before QUI touches it.
--
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

_G.CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end
_G.EventRegistry = {
    RegisterCallback = function() end,
}

_G.C_CooldownViewer = {
    IsCooldownViewerAvailable = function()
        return true
    end,
    GetCooldownViewerCategorySet = function()
        return { 88 }
    end,
    GetCooldownViewerCooldownInfo = function(cooldownID)
        if cooldownID == 88 then
            return {
                spellID = 12345,
                overrideSpellID = nil,
                overrideTooltipSpellID = nil,
            }
        elseif cooldownID >= 89 and cooldownID <= 91 then
            return { spellID = 12345 + cooldownID - 88 }
        end
        return nil
    end,
}

local ns = {}
-- Task 45f: cdm_catalog.lua routes discarded-result pcall guards through
-- ns.SafeCall. Additive stub (T1d/T1e precedent) — bare pcall passthrough.
ns.SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end
ns.SafeCallMethod = function(_policy, obj, name, ...) return pcall(function(...) return obj[name](obj, ...) end, ...) end
ns.SafeCallMethodIfPresent = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")

local indexChunk = loadChunk("QUI_CDM/cdm/cdm_index.lua", "cdm_index.lua")
indexChunk("QUI", ns)
local catalogChunk = loadChunk("QUI_CDM/cdm/cdm_catalog.lua", "cdm_catalog.lua")
catalogChunk("QUI", ns)

ns.CDMSources = {
    QueryBaseSpell = function(spellID)
        return spellID
    end,
    QuerySpellInfo = function()
        return nil
    end,
    QueryOverrideSpell = function(spellID)
        return spellID
    end,
}

local index = assert(ns.CDMIndex, "CDMIndex table was not exported")
local catalog = assert(ns.CDMCatalog, "CDMCatalog table was not exported")

local getterCalls = 0
local providerSourceFile = assert(io.open(
    "tests/framexml/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsDataProvider.lua", "rb"))
local providerSource = providerSourceFile:read("*a"):gsub("\r\n", "\n")
providerSourceFile:close()
local nativeMixin = {
    CheckBuildDisplayData = function() getterCalls = getterCalls + 1 end,
    GetDisplayData = function(self) return self.displayData end,
}
_G.CooldownViewerSettingsDataProviderMixin = nativeMixin
for _, name in ipairs({ "GetOrderedCooldownIDs", "GetOrderedCooldownIDsForCategory", "GetCooldownInfoForID" }) do
    local start = assert(providerSource:find(
        "function CooldownViewerSettingsDataProviderMixin:" .. name .. "(", 1, true))
    local finish = assert(providerSource:find("\nfunction ", start + 1, true))
    assert(loadstring(providerSource:sub(start, finish - 1)))()
end
local providerStub = setmetatable({
    displayDataDirty = true,
    displayData = nil,
    GetLayoutManager = function() return {} end,
}, { __index = nativeMixin })
_G.CooldownViewerSettings = {
    GetDataProvider = function()
        return providerStub
    end,
}

-- 1) dirty cache: index ordered maps must stay empty, getters untouched.
local gated = index.GetOrderedSpellMap()
assert(type(gated) == "table", "gated ordered map should still be a table")
assert(next(gated) == nil, "ordered map must stay empty while provider cache is dirty")
assert(getterCalls == 0, "index must not call provider getters while cache is dirty")

-- 2) fresh provider (both memo fields nil) is unbuilt too.
providerStub.displayDataDirty = nil
assert(next(index.GetOrderedSpellMap()) == nil,
    "ordered map must stay empty while provider displayData is nil")
assert(getterCalls == 0, "index must not call provider getters while displayData is nil")

-- 3) catalog tracked-set read is gated the same way.
local ids, ready = catalog.GetTrackedCategorySet(0, true)
assert(ids == nil and ready == false,
    "catalog must report not-ready while provider cache is unbuilt")
assert(getterCalls == 0, "catalog must not call provider getters while cache is unbuilt")

-- 4) built cache: the next index call rebuilds WITHOUT a new invalidation
--    (the gate bail must not latch the ordered-map version).
_G.CDM_HIDE_INVISIBLE_ITEMS = true
providerStub.displayDataDirty = false
providerStub.displayData = {
    orderedCooldownIDs = { 88, 89, 90, 91 },
    cooldownInfoByID = {
        [88] = { category = 0, isKnown = true },
        [89] = { category = 0, isKnown = false },
        [90] = { category = 0, isKnown = true, isInvisible = true },
        [91] = { category = 2, isKnown = true },
    },
}
local built = index.GetOrderedSpellMap()
assert(built[12345] and built[12345].cooldownID == 88,
    "ordered map should populate on the first call after the cache is built")
assert(getterCalls == 0, "built provider snapshots must not enter native ordered getters")
assert(built[12346] and built[12346].cooldownID == 89,
    "ordered index must include unknown entries from the displayed category")
assert(built[12347] == nil, "ordered index must exclude invisible entries when native filtering is enabled")

local function IDsEqual(actual, expected)
    assert(#actual == #expected, "filtered snapshot length differs")
    for i, id in ipairs(expected) do assert(actual[i] == id, "filtered snapshot order differs") end
end
_G.CDM_HIDE_INVISIBLE_ITEMS = true
IDsEqual(catalog.GetTrackedCategorySet(0, false), { 88 })
IDsEqual(catalog.GetTrackedCategorySet(0, true), { 88, 89 })
_G.CDM_HIDE_INVISIBLE_ITEMS = false
IDsEqual(catalog.GetTrackedCategorySet(0, false), { 88, 90 })
IDsEqual(catalog.GetTrackedCategorySet(0, true), { 88, 89, 90 })
IDsEqual(catalog.GetTrackedCategorySet(2, true), { 91 })
IDsEqual(catalog.GetTrackedCategorySet(1, true), {})
assert(#providerStub.displayData.orderedCooldownIDs == 4, "snapshot reads must not edit native order")
assert(getterCalls == 0, "category filtering must not enter native ordered getters")

local callsAfterBuild = getterCalls
assert(index.GetOrderedSpellMap() == built, "built ordered map should be cached again")
assert(getterCalls == callsAfterBuild, "cached ordered map should not re-walk the provider")


local builtIds, builtReady = catalog.GetTrackedCategorySet(0, true)
assert(builtReady == true and type(builtIds) == "table" and builtIds[1] == 88,
    "catalog should serve the provider tracked set once the cache is built")

-- 6) re-dirtied cache (SPELLS_CHANGED etc. MarkDirty): index keeps serving
--    the STALE maps rather than rebuilding through a dirty provider.
local callsBeforeRedirty = getterCalls
providerStub.displayDataDirty = true
index.Notify("manual")
local stale = index.GetOrderedSpellMap()
assert(stale[12345] and stale[12345].cooldownID == 88,
    "index should keep serving stale ordered maps while the provider re-dirties")
assert(getterCalls == callsBeforeRedirty,
    "index must not rebuild through a dirty provider after invalidation")

providerStub.displayDataDirty = false
local rebuilt = index.GetOrderedSpellMap()
assert(rebuilt[12347] and rebuilt[12347].cooldownID == 90,
    "ordered index must include invisible entries when native filtering is disabled")
assert(rebuilt[12346] and rebuilt[12346].cooldownID == 89,
    "ordered index must retain unknown entries after rebuilding")
assert(getterCalls == 0, "ordered index recovery must never enter native builders")

print("OK: cdm_provider_displaydata_gate_test")
