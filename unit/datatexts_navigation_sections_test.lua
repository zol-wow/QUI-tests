local nativeLoadfile = loadfile
loadfile = function(path)
    if path == "modules/datatexts/settings/datatexts_providers.lua" then
        path = os.getenv("QUI_DATATEXT_NAV_SOURCE") or path
    elseif path == "core/settings/provider_features.lua" then
        path = os.getenv("QUI_PROVIDER_FEATURES_SOURCE") or path
    end
    return nativeLoadfile(path)
end
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local handle = assert(io.open(OUTPUT_PATH, "w"))', 1, true))
local ns, profile, catalog, capture = assert(loadstring(source:sub(1, cut - 1)
    .. "\nreturn ns, profile_db, navigation_catalog, capture_search_feature"))()
local feature = assert(ns.Settings.Registry:GetFeature("datatextPanel"))
assert(loadfile("QUI_Options/search_cache.lua"))("QUI", ns)
local tile = { config = { featureId = "datatextPanel" } }
local function Signature(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for key, item in pairs(value) do parts[#parts + 1] = tostring(key) .. "=" .. Signature(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end
local function Labels(sections)
    local labels = {}
    for _, section in ipairs(sections) do
        assert(section.id == section.label, "section IDs must match rendered heading IDs")
        labels[#labels + 1] = section.label
    end
    return table.concat(labels, "|")
end
local function Check(expected)
    local before = Signature({ profile.datatext, profile.quiDatatexts })
    local createFrame = CreateFrame
    CreateFrame = function() error("reading navigation must not create a settings frame") end
    local links = QUI.GUI:GetTileNavigationPages(tile)
    local labels = {}
    for _, link in ipairs(links) do
        assert(link.sectionId == link.label, "cold menu links must target actual heading IDs")
        labels[#labels + 1] = link.label
    end
    assert(table.concat(labels, "|") == expected,
        "unopened Datatext menu must expose current section links: " .. table.concat(labels, "|"))
    assert(not tile._subPageBodies, "reading Datatext navigation must leave the settings body unbuilt")
    local sections = assert(feature.getNavigationSections(), "provider feature must expose its current headings before rendering")
    CreateFrame = createFrame
    assert(Signature({ profile.datatext, profile.quiDatatexts }) == before,
        "reading navigation must not seed or change the profile")
    assert(Labels(sections) == expected, "cold headings must match the selected panel and configured slots: " .. Labels(sections))
    catalog.datatextPanel = nil
    assert(capture(feature))
    assert(Labels(catalog.datatextPanel.sections) == expected,
        "cold headings must match real rendered headings in order: " .. Labels(catalog.datatextPanel.sections))
end

local prefix = "Panel Selector|Panel Settings|Slot 1 (Left)|Slot 2 (Center)|Slot 3 (Right)|Text Styling"
profile.datatext = { slots = { "fps", "durability", "time" } }
profile.quiDatatexts = { panels = {} }
Check(prefix .. "|Time Options")
profile.datatext.slots = { "playerspec", "alts", "currencies" }
Check(prefix .. "|Spec Display|Alts Options|Currencies")
profile.datatext.slots = { "fps", "guild", "time", "alts" }
Check(prefix .. "|Time Options")
profile.datatext.slots = { "fps", "guild", "" }
Check(prefix)

local custom = { id = "navigation-test", numSlots = 4, slots = { "time", "playerspec", "alts", "currencies" } }
profile.quiDatatexts.panels[1] = custom
ns.QUI_DatatextPanelSelection.setActivePanel("datapanel_navigation-test", profile)
custom.width, custom.slotSettings = nil, nil
local beforeCustom = Signature(custom)
assert(#feature.getNavigationSections() == 11 and Signature(custom) == beforeCustom,
    "cold custom panel lookup must not initialize missing geometry or slot settings")
assert(ns.QUI_DatatextPanelSelection.getActivePanel(profile) == custom.id,
    "reading custom panel headings must preserve the selected panel")
Check("Panel Selector|Panel Settings|Slot 1|Slot 2|Slot 3|Slot 4|Text Styling|Spec Display|Time Options|Alts Options|Currencies")
custom.numSlots = 1
Check("Panel Selector|Panel Settings|Slot 1|Text Styling|Time Options")
profile.quiDatatexts.panels = {}
Check(prefix)

local providers = ns.Settings.Providers
local provider = providers:Get("datatextPanel")
providers:Unregister("datatextPanel")
assert(feature.getNavigationSections() == nil, "an unavailable provider retains static navigation fallback")
providers:Register("datatextPanel", provider)
assert(#feature.getNavigationSections() == 6, "late provider registration must restore current navigation")
print("OK: datatext cold headings follow selected panels and slots without constructing settings or mutating profiles")
