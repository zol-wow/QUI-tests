local nativeLoadfile = loadfile
loadfile = function(path)
    if path == "QUI_ActionBars/actionbars/actionbars_per_bar_builders.lua" then
        path = os.getenv("QUI_PERBAR_BUILDERS_SOURCE") or path
    elseif path == "QUI_ActionBars/actionbars/settings/action_bars_per_bar.lua" then
        path = os.getenv("QUI_PERBAR_FEATURE_SOURCE") or path
    end
    return nativeLoadfile(path)
end
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local handle = assert(io.open(OUTPUT_PATH, "w"))', 1, true))
local ns, profile, catalog, capture = assert(loadstring(source:sub(1, cut - 1)
    .. "\nreturn ns, profile_db, navigation_catalog, capture_search_feature"))()
assert(loadfile("QUI_Options/search_cache.lua"))("QUI", ns)
local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = Copy(item) end
    return copy
end
local function Signature(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for key, item in pairs(value) do parts[#parts + 1] = tostring(key) .. "=" .. Signature(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end
profile.actionBars = Copy(ns.defaults.profile.actionBars)
local feature = ns.Settings.Registry:GetFeature("actionBarsPerBar")
local preview = ns.QUI_ActionBarsOptions
local tile = { config = { featureId = "actionBarsPerBar" } }
local function Check(key, expected)
    preview.SetSelectedBar(key, "navigation-test")
    local before = Signature(profile.actionBars)
    local createFrame = CreateFrame
    CreateFrame = function() error("cold Per Bar navigation must not construct settings frames") end
    local links = QUI.GUI:GetTileNavigationPages(tile)
    CreateFrame = createFrame
    local labels = {}
    for _, link in ipairs(links) do
        assert(link.sectionId == link.label, "section links must target rendered heading IDs")
        labels[#labels + 1] = link.label
    end
    assert(table.concat(labels, "|") == expected, "cold " .. key .. " sections must match its settings: " .. table.concat(labels, "|"))
    assert(not tile._subPageBodies and preview.GetSelectedBar() == key and Signature(profile.actionBars) == before,
        "cold Per Bar lookup must leave settings, selection and profile unchanged")
    catalog.actionBarsPerBar = nil
    assert(capture(feature))
    labels = {}
    for _, section in ipairs(catalog.actionBarsPerBar and catalog.actionBarsPerBar.sections or {}) do
        labels[#labels + 1] = section.label
    end
    assert(table.concat(labels, "|") == expected, "cold links must match actual " .. key .. " rendered headings")
end
local standard = "Layout|Visual|Keybind Text|Macro Names|Stack Count|Cooldown Duration Text|Context Visibility"
Check("bar2", "Bar|" .. standard)
Check("microMenu", "Bar|Layout|Ticket Icon|Context Visibility")
Check("bar1", standard)
for index = 3, 8 do Check("bar" .. index, "Bar|" .. standard) end
Check("petBar", standard)
Check("stanceBar", standard)
profile.actionBars.bars.microbar.ownedLayout = nil
Check("microMenu", "Bar|Ticket Icon|Context Visibility")
profile.actionBars.bars.bar1 = nil
Check("bar1", "")
print("OK: Per Bar cold navigation follows every selectable bar and matches its actual rendered headings")
