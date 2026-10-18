local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local handle = assert(io.open(OUTPUT_PATH, "w"))', 1, true))
local ns, catalog, capture = assert(loadstring(source:sub(1, cut - 1)
    .. "\nreturn ns, navigation_catalog, capture_search_feature"))()
assert(loadfile("QUI_Options/search_cache.lua"))("QUI", ns)
local GUI = QUI.GUI
local profile = {}
QUI.QUICore.db.profile = profile
local tile = { config = { featureId = "infobar" } }
local create = CreateFrame
CreateFrame = function() error("cold Info Bar navigation must not construct settings frames") end
local guardedCreate = CreateFrame
local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = Copy(item) end
    return copy
end

local function Check(expected)
    local sections = GUI:GetTileNavigationPages(tile)
    assert(#sections == #expected, "cold Info Bar navigation must follow the current widget placement")
    for index, label in ipairs(expected) do
        assert(sections[index].sectionId == label and sections[index].label == label,
            "Info Bar links must preserve rendered heading identifiers and order")
    end
    assert(not tile._subPageBodies, "cold Info Bar navigation must leave the page unbuilt")
    CreateFrame = create
    QUI.QUICore.db.profile = Copy(profile)
    catalog.infobar = nil
    assert(capture(ns.Settings.Registry:GetFeature("infobar")))
    local built = catalog.infobar and catalog.infobar.sections or {}
    assert(#built == #expected, "cold Info Bar links must match actual rendered heading count")
    for index, label in ipairs(expected) do
        assert(built[index].id == label and built[index].label == label,
            "cold Info Bar links must match actual rendered heading order")
    end
    QUI.QUICore.db.profile = profile
    CreateFrame = guardedCreate
end
local base = { "General", "Visibility", "Arrangement", "Widget Overrides", "Micro Menu", "Travel" }
profile.infobar = { zones = { left = { "alts", "currencies", "alts" } } }
Check({ "General", "Visibility", "Arrangement", "Widget Overrides", "Currencies", "Alts Options", "Micro Menu", "Travel" })
assert(not profile.infobar.zones.center and not profile.infobar.widgetSettings,
    "cold Info Bar lookup must not seed missing zones or widget settings")
profile.infobar.zones.left = {}
Check(base)
profile.infobar.zones.right = { "alts" }
Check({ "General", "Visibility", "Arrangement", "Widget Overrides", "Alts Options", "Micro Menu", "Travel" })
profile.infobar.zones.right = { "currencies" }
local currencies = ns.QUI_BuildCurrencyOrderSection
ns.QUI_BuildCurrencyOrderSection = nil
Check(base)
ns.QUI_BuildCurrencyOrderSection = currencies
Check({ "General", "Visibility", "Arrangement", "Widget Overrides", "Currencies", "Micro Menu", "Travel" })
profile.infobar = nil
Check(base)
assert(profile.infobar == nil, "cold Info Bar lookup must not create its profile config")
profile = nil
QUI.QUICore.db.profile = nil
Check({})
CreateFrame = create
print("OK: infobar_navigation_sections_test")
