-- Expanded-content fixtures must follow their actual registered outer homes.
local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a"); file:close()
local marker = assert(source:find("\ninstall_search_capture_overrides()\n", 1, true))
local ns, capture = assert(loadstring(source:sub(1, marker) .. [[
install_search_capture_overrides()
return ns, function()
    capture_all_search_features()
    capture_aura_displays_elements()
    capture_expanded_aura_editors()
    capture_spell_reminder_fixture()
end
]]))()
local registry, GUI = ns.Settings.Registry, QUI.GUI
local features = { "groupFramesPage", "nameplatesPage", "aurasNameplatePage", "aurasDisplaysPage", "spellRemindersPage" }
local pages, expected = {}, {}
for index, featureId in ipairs(features) do
    pages[index] = { id = featureId, name = "Relocated " .. index, featureId = featureId,
        searchContext = { tabIndex = 901, subTabIndex = index } }
    expected[featureId] = index
end
registry:RegisterTileDestinations({ id = "relocated_fixture_host", name = "Relocated fixtures", subPages = pages })
registry:RegisterTileDestinations({ id = "second_fixture_host", name = "Second fixtures", featureId = "aurasDisplaysPage" })
GUI:ResetStaticSearchIndex()
capture()
local counts, secondHome, failures = {}, 0, {}
for _, entry in ipairs(GUI.StaticSettingsRegistry) do
    local index = expected[entry.featureId]
    if index then
        if entry.tileId == "second_fixture_host" and entry.featureId == "aurasDisplaysPage" then
            secondHome = secondHome + 1
        else
            counts[entry.featureId] = (counts[entry.featureId] or 0) + 1
            local label = "Relocated " .. index
            local feature = registry:GetFeature(entry.featureId)
            if feature.model and entry.surfaceTabKey then
                local model = type(feature.model) == "function" and feature.model() or feature.model
                label = assert(ns.Settings.ModelKit.GetTabDefinition(model, entry.surfaceTabKey)).label
            end
            if entry.tileId ~= "relocated_fixture_host" or entry.subPageIndex ~= index
                or entry.tabIndex ~= 901 or entry.subTabIndex ~= index
                or entry.tabName ~= "Relocated fixtures" or entry.subTabName ~= label then
                failures[#failures + 1] = entry.featureId .. ": " .. entry.label .. " retained stale fixture route "
                    .. tostring(entry.tileId) .. "/" .. tostring(entry.subPageIndex)
            end
        end
    end
end
for _, featureId in ipairs(features) do assert(counts[featureId] and counts[featureId] > 0, featureId .. " must capture expanded content") end
if secondHome == 0 then failures[#failures + 1] = "expanded fixtures must include every registered home" end
assert(#failures == 0, table.concat(failures, "\n"))
assert(ns.Settings.SearchRoute.Depth() == 0, "fixture scopes must unwind")
print("OK: expanded aura and reminder fixtures follow all registered destinations")
