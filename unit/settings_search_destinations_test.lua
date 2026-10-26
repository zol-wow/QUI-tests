-- Exercise the actual surface models, not copied tab/context lists.
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }), Settings = {},
    QUI_Nameplates = { PlateType = {
        ORDER = { "petMinion", "friendly", "bossElite", "minorTrivial", "enemyPlayer", "enemyNPC" },
        DEFAULT_KEY = "enemyNPC",
    } },
}
local function Load(path) assert(loadfile(path))("QUI", ns) end
Load("core/settings/model_kit.lua")
Load("QUI_UnitFrames/unitframes/settings/unit_frames_model.lua")
Load("QUI_GroupFrames/groupframes/settings/group_frames_model.lua")
Load("QUI_Nameplates/nameplates/settings/nameplates_model.lua")
local Kit = ns.Settings.ModelKit
assert(type(Kit.EnumerateSearchTabs) == "function", "canonical model search enumeration is required")
local function Check(model, count, field, stateKey, isVariant)
    local rows = Kit.EnumerateSearchTabs(model)
    assert(#rows == count, "real model destination count: " .. tostring(#rows) .. " vs " .. tostring(count))
    for _, row in ipairs(rows) do
        assert(type(row.tab.render) == "function", "enumerated tabs retain their actual renderer")
        assert(row.searchContext.surfaceTabKey == row.tab.key, "surface key derives from real tab")
        assert(row.searchContext.subTabName == row.tab.label, "display label derives from real tab")
        if isVariant(row.tab.key) then
            assert(row.state[stateKey] and row.searchContext[field], "variant context is preserved")
        else
            assert(row.state[stateKey] == nil and row.searchContext[field] == nil, "global tabs render once without a false variant")
        end
    end
    return rows
end
local UF, GF, NP = ns.QUI_UnitFramesSettingsModel, ns.QUI_GroupFramesSettingsModel, ns.QUI_NameplatesSettingsModel
Check(UF, 43, "surfaceUnitKey", "selectedUnit", UF.IsPerUnitTab)
Check(GF, 12, "providerKey", "contextMode", function() return true end)
Check(NP, 38, "surfaceTypeKey", "selectedType", NP.IsPerTypeTab)
for _, row in ipairs(Kit.EnumerateSearchTabs(GF)) do
    assert(row.searchContext.providerKey == (row.state.contextMode == "raid" and "raidFrames" or "partyFrames"))
end
-- A real model tab added at runtime participates immediately, including its
-- visibility rule and renderer; a separate search-owned tab list would fail.
local definitions, renderCalls = UF.GetTabDefinitions(), 0
local probe = { key = "enumeration_probe", label = "Enumeration Probe",
    visible = function(state) return state.selectedUnit == "target" end,
    render = function(_, state) assert(state.selectedUnit == "target"); renderCalls = renderCalls + 1 end }
local originalPerUnit = UF.IsPerUnitTab
UF.IsPerUnitTab = function(key) return key == probe.key or originalPerUnit(key) end
definitions[#definitions + 1] = probe
local rows, found = Kit.EnumerateSearchTabs(UF), 0
for _, row in ipairs(rows) do
    if row.tab == probe then row.tab.render({}, row.state); found = found + 1 end
end
assert(#rows == 44 and found == 1 and renderCalls == 1, "added live tab and visibility must drive search")
table.remove(definitions)
UF.IsPerUnitTab = originalPerUnit
assert(#Kit.EnumerateSearchTabs(UF) == 43, "removing live tab removes search destinations")
-- Selector mutation must propagate to every per-unit tab without editing a
-- generator list; labels must also come from the real selector options.
local originalOptions = UF.GetUnitOptions
UF.GetUnitOptions = function()
    local options = originalOptions()
    options[#options + 1] = { value = "context_probe", text = "Context Probe" }
    return options
end
local probes = 0
for _, row in ipairs(Kit.EnumerateSearchTabs(UF)) do
    if row.state.selectedUnit == "context_probe" then
        probes = probes + 1
        assert(row.searchContext.surfaceUnitKey == "context_probe" and row.label == "Context Probe")
    end
end
assert(probes == 7, "all real per-unit tabs follow selector changes")
UF.GetUnitOptions = originalOptions
print("OK: settings_search_destinations_test")
