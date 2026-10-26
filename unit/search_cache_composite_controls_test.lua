local cache = dofile("tests/helpers/search_cache.lua")()
local required = { profilesPage = { ["New Profile"] = "editbox" },
    bags = { ["Add Exclusion by ID"] = "editbox" },
    aurasDisplaysPage = { ["Aura Applied"] = "dropdown", ["Stacks Increased"] = "dropdown", ["Aura Removed"] = "dropdown" } }
for feature, labels in pairs(required) do
    for label, kind in pairs(labels) do
        local found
        for _, entry in ipairs(cache.settings) do
            if entry.featureId == feature and entry.label == label then
                assert(entry.widgetType == kind, "composite control retains its actual kind")
                assert(entry.description and #entry.description > 0, "composite control retains its actual description")
                found = true
            end
        end
        assert(found, "actual composite control missing: " .. feature .. "/" .. label)
    end
end
print("OK: composite provider controls retain their row labels, kinds and descriptions")
