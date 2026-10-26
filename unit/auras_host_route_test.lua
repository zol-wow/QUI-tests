-- The registered Auras providers must retain the real host's route, including
-- when that provider is rendered on a reordered page or a second tile home.
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
local route = {tileId = "alternate_auras", subPageIndex = 19, tabIndex = 91,
    tabName = "Alternate Auras", subTabIndex = 19, subTabName = "Relocated Editor"}
local captured
local function RenderChild(host)
    GUI:SetSearchContext({tileId = "child_default", subPageIndex = 1,
        tabName = "Child Default", subTabName = "Child Editor", surfaceTabKey = "auras", providerKey = "partyFrames"})
    captured = ns.Settings.Util.ShallowCopy(GUI._searchContext)
    host:SetHeight(40)
    return 40
end
local cases = {
    {feature = "aurasGroupPage", module = "QUI_GroupFramesSettingsSchema", methods = {"RenderAurasTab", "RenderDispelTab"}},
    {feature = "aurasUnitPage", module = "QUI_UnitFramesSettingsSchema", methods = {"RenderIconsTab"}},
    {feature = "aurasNameplatePage", module = "QUI_NameplatesSettingsSchema", methods = {"RenderAurasTab"}},
    {feature = "aurasActionBarPage", module = "QUI_BuffDebuffOptions", methods = {"BuildBuffDebuffTab"}},
    {feature = "aurasDisplaysPage", module = "QUI_AuraDisplaysOptions", methods = {"BuildAuraDisplaysContent"}},
}
local failures = {}
for _, case in ipairs(cases) do
    local module = assert(ns[case.module])
    local previous = {}
    for _, method in ipairs(case.methods) do previous[method] = module[method]; module[method] = RenderChild end
    local ok, err = pcall(function()
        captured = nil
        route.featureId = case.feature
        GUI:SetSearchContext(route)
        local feature = assert(ns.Settings.Registry:GetFeature(case.feature))
        local section = feature.sectionsById.settings
        local host = CreateFrame("Frame"); host:SetSize(760, 1)
        ns.Settings.SearchRoute.With(route, section.build, host, {}, section)
        assert(captured, case.feature .. " must render its child editor")
        assert(captured.tileId == route.tileId and captured.subPageIndex == 19
            and captured.featureId == case.feature and captured.subTabName == route.subTabName,
            case.feature .. " must retain the actual host route, got " .. tostring(captured.tileId) .. ":" .. tostring(captured.subPageIndex))
        assert(captured.surfaceTabKey == "auras" and captured.providerKey == "partyFrames",
            "host route must preserve child identity")
    end)
    for _, method in ipairs(case.methods) do module[method] = previous[method] end
    if not ok then failures[#failures + 1] = tostring(err) end
end
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: auras_host_route_test")
