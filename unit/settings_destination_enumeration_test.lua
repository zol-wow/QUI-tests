-- The actual UI registrations are also the complete set of outer search homes.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a"); file:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI, ns = QUI.GUI
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
local registry = ns.Settings.Registry
local providerContexts = { { searchContext = { providerKey = "sample" }, label = "Sample" } }
local provider = ns.Settings.ProviderFeatures:Register({
    id = "destinationProviderTest", providerKey = "sample",
    getSearchContexts = function() return providerContexts end,
    getNavigationContext = function() return providerContexts[1].searchContext end,
    searchNavigate = function(context) return context.providerKey == "sample" end,
})
assert(provider.getSearchContexts and provider.getSearchContexts() == providerContexts,
    "provider registrations must preserve their declared canonical selector contexts")
assert(provider.searchNavigate(provider.getNavigationContext()), "provider context selection must remain callable")
if os.getenv("QUI_DESTINATION_REGISTRY") then
    ns.Settings.Registry = nil
    assert(loadfile(os.getenv("QUI_DESTINATION_REGISTRY")))("QUI", ns)
    local original = registry
    registry = ns.Settings.Registry
    for _, feature in original:IterateFeatures() do registry:RegisterFeature(feature) end
end
local mounted, builds = {}, 0
function GUI:AddFeatureTile(_, spec) mounted[#mounted + 1] = spec end
local function Enumerate()
    local destinations = {}
    local iterator = registry.IterateDestinations and registry:IterateDestinations() or function() end
    for destination in iterator do destinations[#destinations + 1] = destination end
    return destinations
end
ns.QUI_Options.RegisterAllFeatureTiles({})
local expected = {}
local function Record(tileId, index, page)
    for _, item in ipairs(page.featureIds or { page.featureId }) do
        local id = type(item) == "table" and item.key or item
        local key = tileId .. ":" .. index .. ":" .. id
        expected[key] = true
    end
end
for _, tile in ipairs(mounted) do
    if tile.subPages then
        for index, page in ipairs(tile.subPages) do Record(tile.id, index, page) end
    else Record(tile.id, 1, tile) end
end
local expectedCount = 0
for _ in pairs(expected) do expectedCount = expectedCount + 1 end
local actual = Enumerate()
assert(#actual == expectedCount, "actual tile homes must be enumerated without rendering: expected " .. expectedCount .. ", got " .. #actual)
for _, destination in ipairs(actual) do
    local key = destination.tileId .. ":" .. destination.subPageIndex .. ":" .. destination.featureId
    assert(expected[key], "unexpected or repeated destination: " .. key)
    expected[key] = nil
    assert(destination.searchContext.tileId == destination.tileId)
    assert(destination.searchContext.featureId == destination.featureId)
    assert(destination.pageId and destination.searchContext.tabName)
end
assert(next(expected) == nil)
-- Mutating a real tile specification must update enumeration with no generator edit.
local feature = registry:GetFeature("unitFramesPage")
local originalRender = feature.render
feature.render = function() builds = builds + 1 end
local spec = {
    id = "destination_test", name = "Destination test", subPages = {
        { id = "first", name = "First", featureId = "unitFramesPage",
          searchContext = { tabIndex = 901, subTabIndex = 2 }, renderOptions = { surface = "full" } },
        { id = "second", name = "Second", featureIds = { { key = "unitFramesPage", label = "Embedded units" }, "groupFramesPage" } },
    },
}
ns.QUI_Options.RegisterFeatureTile({}, spec)
local added = {}
for _, destination in ipairs(Enumerate()) do
    if destination.tileId == spec.id then added[#added + 1] = destination end
end
assert(#added == 3, "one feature must retain every page home, including stacks")
assert(added[1].renderOptions.surface == "full" and added[1].searchContext.tabIndex == 901)
assert(added[2].sectionLabel == "Embedded units" and added[2].pageId == "second")
spec.subPages[2] = nil
ns.QUI_Options.RegisterFeatureTile({}, spec)
local remaining = 0
for _, destination in ipairs(Enumerate()) do if destination.tileId == spec.id then remaining = remaining + 1 end end
assert(remaining == 1, "re-registering a tile replaces its previous destinations")
assert(builds == 0, "enumeration must preserve cold/lazy pages")
feature.render = function()
    GUI:SetSearchContext({ tileId = "unit_frames", subPageIndex = 99, featureId = "unitFramesPage", tabName = "Stale home" })
    return 80
end
local body = CreateFrame("Frame")
body:SetWidth(760)
mounted[#mounted].subPages[1].buildFunc(body)
assert(GUI._searchContext.tileId == "destination_test" and GUI._searchContext.subPageIndex == 1,
    "rendering a feature at another registered home must retain the actual host route")
assert(GUI._searchContext.tabName == "Destination test")
assert(ns.Settings.SearchRoute.Depth() == 0, "render scope must unwind")
GUI.MainFrame = { _tiles = {} }
for _, tile in ipairs(mounted) do GUI.MainFrame._tiles[#GUI.MainFrame._tiles + 1] = { id = tile.id, config = tile } end
GUI._navMap["901:2"] = { tileId = "unit_frames", subPageIndex = 1 }
local route = GUI:ResolveSearchNavigation({ tileId = "destination_test", subPageIndex = 1,
    featureId = "unitFramesPage", tabIndex = 901, subTabIndex = 2 })
assert(route.tileId == "destination_test" and route.subPageIndex == 1,
    "validated registered destination must win over a legacy numeric alias")
feature.render = originalRender
print("outer destination enumeration: " .. expectedCount .. " actual homes, multi-home/stack/re-registration/lazy checks passed")
