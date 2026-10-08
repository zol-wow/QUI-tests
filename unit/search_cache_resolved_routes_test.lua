local generatorPath = "tools/generate_search_cache.lua"
local handle = assert(io.open(generatorPath, "rb"))
local source = handle:read("*a")
handle:close()

local marker = 'local frame = create_stub_node("Frame", nil, false)'
local cut = assert(source:find(marker, 1, true), "generator preamble marker not found")
assert((loadstring or load)(source:sub(1, cut - 1), "@search-cache-generator-preamble"))()

local GUI = assert(_G.QUI and _G.QUI.GUI, "framework did not initialize QUI.GUI")
local ns
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then
        ns = value
        break
    end
end
assert(type(ns) == "table", "could not recover the framework namespace")

assert(loadfile("core/pack.lua"))("QUI", ns)
assert(loadfile("QUI_Options/search_cache.lua"))("QUI_Options", ns)
GUI:EnsureSearchCacheLoaded()

GUI._navMap = {}
local frame = { _tiles = {} }
GUI.AddFeatureTile = function(_, tileFrame, config)
    tileFrame._tiles[#tileFrame._tiles + 1] = { id = config.id, config = config }
end
ns.QUI_Options.RegisterFeatureTile(frame, {
    id = "welcome",
    name = ns.L["Welcome"],
    featureId = "welcomePage",
    noScroll = false,
})

local tileOrder = {
    "QUI_GlobalTile",
    "QUI_UnitFramesTile",
    "QUI_GroupFramesTile",
    "QUI_NameplatesTile",
    "QUI_ActionBarsTile",
    "QUI_AurasTile",
    "QUI_CooldownManagerTile",
    "QUI_ResourceBarsTile",
    "QUI_MinimapTile",
    "QUI_InfoBarTile",
    "QUI_AppearanceTile",
    "QUI_ChatTooltipsTile",
    "QUI_GameplayTile",
    "QUI_QoLTile",
    "QUI_BagsTile",
    "QUI_AltsTile",
    "QUI_HelpTile",
}

for _, key in ipairs(tileOrder) do
    local tile = ns[key]
    if tile and type(tile.Register) == "function" then
        tile.Register(frame)
    end
end

GUI.MainFrame = frame

local generalTile
for _, tile in ipairs(frame._tiles) do
    if tile.id == "global" then generalTile = tile end
end
assert(generalTile, "General tile is registered")
for featureId, pageIndex in pairs({ modulesPage = 3, importExportPage = 4, thirdPartyAnchoring = 5, clickCastPage = 6 }) do
    local feature = assert(ns.Settings.Registry:GetFeature(featureId))
    assert(feature.nav.tileId == "global" and feature.nav.subPageIndex == pageIndex,
        "registered feature navigation must target its real General page: " .. featureId)
    local page = assert(generalTile.config.subPages[pageIndex])
    assert(page.featureId == featureId, "feature navigation must agree with the actual mounted editor: " .. featureId)
    local aliases = 0
    for _, entry in ipairs(GUI.StaticNavigationRegistry) do
        if entry.featureId == featureId and (entry.navType == "tab" or entry.navType == "subtab") then
            local route = assert(GUI:ResolveSearchNavigation(entry))
            assert(route.tileId == "global" and route.subPageIndex == pageIndex,
                "generated feature alias must open its mounted editor: " .. featureId .. " / " .. tostring(entry.label))
            aliases = aliases + 1
        end
    end
    assert(aliases > 0, "generated cache contains native feature aliases: " .. featureId)
end

local legacyThirdParty = assert(GUI:ResolveV2Navigation(3, 7))
assert(legacyThirdParty.tileId == "global" and legacyThirdParty.subPageIndex == 5
    and generalTile.config.subPages[legacyThirdParty.subPageIndex].featureId == "thirdPartyAnchoring",
    "legacy third-party navigation opens the actual integration editor")
for _, entry in ipairs(GUI.StaticNavigationRegistry) do
    if entry.tabIndex == 3 and entry.subTabIndex == 7 then
        local route = assert(GUI:ResolveSearchNavigation(entry), "legacy Frame Positioning aliases remain reachable")
        assert(route.tileId == "global" and route.subPageIndex == 5, "legacy third-party aliases open General Third-party")
    end
end

local checked = 0
local failures = {}
local counts = {}
local groupTintAnimation = false
local cdmPressedProviders = {}
for _, registry in ipairs({ GUI.StaticSettingsRegistry, GUI.StaticNavigationRegistry }) do
    for _, entry in ipairs(registry or {}) do
        if entry.label == "Tint Animation" then
            assert(entry.featureId ~= "nameplatesPage" and entry.featureId ~= "aurasNameplatePage",
                "nameplate health tints must not advertise unsupported animations")
            if entry.featureId == "groupFramesPage" then groupTintAnimation = true end
        end
        if entry.featureId == "cooldownManagerContainersPage"
            and entry.label == "Pressed Effect" then
            cdmPressedProviders[entry.providerKey] = true
        end
        if type(entry.tileId) == "string" and entry.tileId ~= "" then
            checked = checked + 1
            local route = GUI:ResolveSearchNavigation(entry)
            if not route
                or route.tileId ~= entry.tileId
                or route.subPageIndex ~= entry.subPageIndex then
                local key = ("%s/%s -> %s/%s"):format(
                    tostring(entry.tileId),
                    tostring(entry.subPageIndex),
                    tostring(route and route.tileId),
                    tostring(route and route.subPageIndex))
                counts[key] = (counts[key] or 0) + 1
                failures[#failures + 1] = ("%s: %s/%s -> %s/%s (tab %s:%s)"):format(
                    tostring(entry.label),
                    tostring(entry.tileId),
                    tostring(entry.subPageIndex),
                    tostring(route and route.tileId),
                    tostring(route and route.subPageIndex),
                    tostring(entry.tabIndex),
                    tostring(entry.subTabIndex))
            end
        end
    end
end

assert(checked > 0, "no direct search routes were checked")
assert(groupTintAnimation, "group-frame health tints must keep their supported animation control")
assert(cdmPressedProviders.essential and cdmPressedProviders.utility,
    "built-in cooldown icon containers must expose the Pressed Effect control")
assert(not cdmPressedProviders.buff and not cdmPressedProviders.trackedBar,
    "aura containers must not expose the cooldown-only Pressed Effect control")
if #failures > 0 then
    local summary = {}
    for route, count in pairs(counts) do
        summary[#summary + 1] = ("%d %s"):format(count, route)
    end
    table.sort(summary)
    error(("%d of %d direct search routes resolve to a different destination:\n%s\nExamples:\n%s")
        :format(#failures, checked, table.concat(summary, "\n"),
            table.concat(failures, "\n", 1, math.min(10, #failures))), 0)
end

print(("OK: %d direct search routes preserve their destination"):format(checked))
