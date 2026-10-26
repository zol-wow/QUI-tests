-- tests/unit/search_seed_moduletoggle_label_test.lua
-- Regression: GUI:SeedStaticSearchRoutesFromTiles must NOT rewrite a
-- moduleToggle entry's label/keywords from its route breadcrumb.
--
-- The generated cache stores feature-toggle entries with the feature's own
-- display name ("Damage Meter"). At panel-build time SeedStaticSearchRoutesFromTiles
-- backfills route-derived breadcrumb labels onto tab/subtab/section entries.
-- It used to do this for moduleToggle entries too, clobbering "Damage Meter"
-- into the breadcrumb "General > Feature Toggles" — which made the feature
-- toggle unfindable by its own name even though the cache was correct.
--
-- This test loads the REAL framework + generated cache (via the headless
-- environment the cache generator already establishes), runs the seed pass,
-- and asserts the moduleToggle keeps its name and stays searchable.
--
-- Run: lua tests/unit/search_seed_moduletoggle_label_test.lua

-- Reuse the generator's WoW-API stub preamble (everything up to the point where
-- it starts building its own capture frame) to load framework.lua headlessly.
local GEN_PATH = "tools/generate_search_cache.lua"
local CUT_MARKER = 'local frame = create_stub_node("Frame", nil, false)'
local fh = assert(io.open(GEN_PATH, "rb"), "cannot open " .. GEN_PATH)
local src = fh:read("*a"); fh:close()
local cut = assert(src:find(CUT_MARKER, 1, true),
    "generator preamble cut marker not found — update CUT_MARKER")
assert((loadstring or load)(src:sub(1, cut - 1), "@gen-preamble"))()

local GUI = assert(_G.QUI and _G.QUI.GUI, "framework did not initialize QUI.GUI")

-- Apply the generated cache exactly as the runtime does, through the real
-- GUI:EnsureSearchCacheLoaded: search_cache.lua parks a packed STRING on the
-- shared namespace, and the first search compiles it via ns.Unpack and applies
-- it with the field-order schema. This is the only standing coverage of that
-- wiring; drop the schema argument there and every positional row registers
-- with no label, so search silently falls back to tile routes only.
--
-- The generator preamble loads framework.lua with a private namespace table we
-- cannot name from here, so borrow it from the loader's own upvalues -- it is
-- the same table search_cache.lua writes into in game (the sub-addon bootstrap
-- proxies both onto the core namespace).
local frameworkNS
do
    local index = 1
    while true do
        local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
        if not name then break end
        if name == "ns" then frameworkNS = value break end
        index = index + 1
    end
end
assert(type(frameworkNS) == "table",
    "GUI:EnsureSearchCacheLoaded no longer closes over `ns` -- update this harness")

assert(loadfile("core/pack.lua"))("QUI", frameworkNS)
assert(loadfile("QUI_Options/search_cache.lua"))("QUI_Options", frameworkNS)
assert(type(frameworkNS.QUI_SearchCachePacked) == "string",
    "search_cache.lua must park the payload as a packed string")

GUI:EnsureSearchCacheLoaded()

assert(GUI:HasGeneratedSearchCache(),
    "EnsureSearchCacheLoaded did not apply the packed cache")
assert(frameworkNS.QUI_SearchCachePacked == nil,
    "EnsureSearchCacheLoaded must drop the packed string once it has compiled it")

-- The legacy damageMeterNativePage master row was retired with the toggle
-- consolidation; the Module Addons row is the damage meter switch now.
local FEATURE_ID = "moduleAddon_QUI_DamageMeter"

local function moduleToggleLabel()
    for _, e in ipairs(GUI.StaticNavigationRegistry or {}) do
        if e.navType == "moduleToggle" and e.featureId == FEATURE_ID then
            return e.label
        end
    end
    return nil
end

-- Sanity: the cache itself carries the feature name (guards against this test
-- silently passing if the cache regresses).
assert(moduleToggleLabel() == "Damage Meter",
    ("expected cache moduleToggle label 'Damage Meter', got %q")
        :format(tostring(moduleToggleLabel())))

-- Minimal tile tree so the seed pass can resolve the "global" feature-toggles
-- page and the "gameplay" damage-meter sub-page.
local frame = { _tiles = {
    { id = "global",   config = { name = "General",  subPages = { [3] = { name = "Feature Toggles" } } } },
    { id = "gameplay", config = { name = "Gameplay", subPages = { [7] = { name = "Damage Meter" } } } },
} }

GUI:SeedStaticSearchRoutesFromTiles(frame)

assert(moduleToggleLabel() == "Damage Meter",
    ("SeedStaticSearchRoutesFromTiles clobbered the moduleToggle label; got %q "
        .. "(route breadcrumb instead of the feature name)")
        :format(tostring(moduleToggleLabel())))

-- End-to-end: the toggle must be returned when searching the feature name.
local _, navResults = GUI:ExecuteSearch("damage meter")
local found = false
for _, r in ipairs(navResults or {}) do
    if r.data and r.data.navType == "moduleToggle" and r.data.featureId == FEATURE_ID then
        found = true
        break
    end
end
assert(found, "searching 'damage meter' did not return the feature-toggle entry after the seed pass")

print("OK: search_seed_moduletoggle_label_test")

-- Inner tabs use the same generated catalog as the navigation tree. They must
-- be searchable before their page exists, including tabs with no named section.
frame._tiles = {
    { id = "reminders", config = { name = "Reminders", subPages = {
        {name = "Defensive Reminders", featureId = "buffs"},
        {name = "Spell Reminders", featureId = "spellRemindersPage"},
    }}},
    { id = "unitframes", config = {name = "Unit Frames", featureId = "unitFramesPage"}},
}
GUI.MainFrame = frame
GUI:SeedStaticSearchRoutesFromTiles(frame)
local count = #GUI.StaticNavigationRegistry
GUI:SeedStaticSearchRoutesFromTiles(frame)
assert(#GUI.StaticNavigationRegistry == count, "repeated catalog seeding must not duplicate inner tabs")
local _, tabs = GUI:ExecuteSearch("Tracked Buffs")
local tracked
for _, hit in ipairs(tabs) do
    if hit.data.featureId == "spellRemindersPage" and hit.data.surfaceTabKey == "buffs" then tracked = hit.data end
end
assert(tracked and tracked.label == "Reminders > Spell Reminders > Tracked Buffs",
    "the actual Tracked Buffs tab must be searchable by its displayed name")
assert(tracked.tileId == "reminders" and tracked.subPageIndex == 2 and not tracked.sectionName,
    "inner-tab search must preserve its outer page and distinct tab key")
for featureId, record in pairs(frameworkNS.QUI_OptionsNavigationCatalog) do
    if featureId == "spellRemindersPage" or featureId == "unitFramesPage" then
        for _, tab in ipairs(record.tabs) do
            local found
            for _, entry in ipairs(GUI.StaticNavigationRegistry) do
                if entry.featureId == featureId and entry.surfaceTabKey == tab.key and entry.navType == "subtab"
                    and entry.contextLabel == tab.label then
                    found = entry; break
                end
            end
            assert(found and found.label:find(tab.label, 1, true), "missing inner-tab destination " .. tab.label)
        end
    end
end
assert(not frame._tiles[1]._built and not frame._tiles[2]._built,
    "search discovery must not build hidden settings pages")
print("OK: inner tabs are searchable from their shared navigation catalog")
