-- Render the real providers after changing their actual model labels/order.
-- A schema-owned mirror of those labels or indices cannot follow these edits.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a"); file:close()
local marker = assert(source:find("\ninstall_search_capture_overrides()\n", 1, true))
assert(loadstring(source:sub(1, marker) .. "install_search_capture_overrides()"))()
local GUI, ns = QUI.GUI
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
local seen = {}
local original = GUI.SetSearchContext
function GUI:SetSearchContext(context)
    seen[#seen + 1] = context
    return original(self, context)
end
local cases = {
    {name = "Unit Frames", model = ns.QUI_UnitFramesSettingsModel, key = "frame", state = {selectedUnit = "target"}, legacyIndex = 3},
    {name = "Unsupported Unit Portrait", model = ns.QUI_UnitFramesSettingsModel, key = "portrait", state = {selectedUnit = "pet"}, legacyIndex = 5},
    {name = "Group Frames", model = ns.QUI_GroupFramesSettingsModel, key = "appearance", state = {contextMode = "raid"}},
    {name = "Nameplates", model = ns.QUI_NameplatesSettingsModel, key = "frame", state = {selectedType = "bossElite"}},
    {name = "CDM", model = ns.QUI_CooldownManagerSettingsModel, key = "layout", state = {activeContainer = "essential"}, legacyIndex = 0},
}
local failures = {}
for _, case in ipairs(cases) do
    local definitions = case.model.GetTabDefinitions()
    local target
    for _, tab in ipairs(definitions) do if tab.key == case.key then target = tab; break end end
    assert(target)
    local label = target.label
    target.label = "Renamed " .. case.name
    table.insert(definitions, 1, {key = "model_order_probe", label = "Inserted tab", render = function() end})
    local expectedIndex
    for index, tab in ipairs(definitions) do if tab == target then expectedIndex = index end end
    local ok, err = pcall(function()
        seen = {}
        local host = CreateFrame("Frame")
        host:SetSize(760, 1)
        target.render(host, case.state)
        local count = 0
        for _, context in ipairs(seen) do
            if context.surfaceTabKey == case.key then
                count = count + 1
                if case.name == "Group Frames" then
                    assert(context.providerKey == "raidFrames", "actual Raid provider rows retain Raid identity")
                end
                assert(context.subTabName == target.label,
                    case.name .. " rendered context must use model label, got " .. tostring(context.subTabName))
                assert(context.subTabIndex == (case.legacyIndex or expectedIndex),
                    case.name .. " rendered context must follow model order while retaining legacy selector aliases")
            end
        end
        assert(count > 0, case.name .. " must render actual settings contexts")
    end)
    table.remove(definitions, 1)
    target.label = label
    if not ok then failures[#failures + 1] = tostring(err) end
end
GUI.SetSearchContext = original
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: schema_search_context_model_test")
