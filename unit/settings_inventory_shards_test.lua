local inventory = dofile("tests/helpers/settings_inventory.lua")
local function Reject(fn, message)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(message, 1, true), "expected rejection: " .. message)
end
local baseline = {
    ["control|tile|1|heavy|a"] = "slider",
    ["control|tile|1|heavy|b"] = "slider",
    ["control|tile|2|light|a"] = "checkbox",
}
local assignments = inventory.Partition({"light", "heavy", "new", "alias"}, baseline, 2)
assert(assignments.heavy ~= assignments.light, "large providers must be spread across workers")
local reordered = inventory.Partition({"alias", "new", "heavy", "light"}, baseline, 2)
for _, feature in ipairs({"light", "heavy", "new", "alias"}) do
    assert(assignments[feature] == reordered[feature], "feature ownership must not depend on registry iteration")
    assert(assignments[feature] == 1 or assignments[feature] == 2, "new and non-search features must have an owner")
end
Reject(function() inventory.Partition({"x"}, {}, 0) end, "positive integer")
local sharedPreview = inventory.Partition({"groupFramesPage", "aurasGroupPage", "other"}, {}, 4)
assert(sharedPreview.groupFramesPage == sharedPreview.aurasGroupPage,
    "group frames and their aura page must retain the same singleton preview initialization order")
local function Report(shard, feature)
    local id = "tile|1|" .. feature .. "|label||"
    return {
        shard = shard, shards = 2, destinations = 1, contexts = 2, failures = {},
        expected = {[id] = {kind = "checkbox", kinds = {checkbox = true}, constructor = "CreateCheckbox"}},
        sourceRows = {["feature|" .. feature] = "registered"},
        sourceKeysBySearchID = {[id] = {["feature|" .. feature] = true}},
    }
end
local first, second = Report(1, "alpha"), Report(2, "beta")
local merged = inventory.Merge({second, first}, 2)
assert(merged.destinations == 2 and merged.contexts == 4, "merged counts must include every worker")
assert(merged.sourceRows["feature|alpha"] and merged.sourceRows["feature|beta"], "merged baseline must include all features")
assert(#inventory.Differences({["feature|alpha"] = "registered", ["feature|beta"] = "registered"}, merged.sourceRows) == 0)
Reject(function() inventory.Merge({first}, 2) end, "missing shard")
Reject(function() inventory.Merge({first, first}, 2) end, "duplicate shard")
Reject(function() inventory.Merge({first, Report(2, "alpha")}, 2) end, "overlapping")
second.shards = 3
Reject(function() inventory.Merge({first, second}, 2) end, "shard count")
second.shards = 2
second.failures = {"provider render failed"}
assert(inventory.Merge({first, second}, 2).failures[1] == "provider render failed", "merging must retain render errors")
second.failures = {}
merged = inventory.Merge({first, second}, 2)
local cache = {settings = {
    {tileId = "tile", subPageIndex = 1, featureId = "alpha", label = "label", widgetType = "checkbox"},
    {tileId = "tile", subPageIndex = 1, featureId = "beta", label = "label", widgetType = "checkbox"},
}}
local reviewed = {["feature|alpha"] = "registered", ["feature|beta"] = "registered"}
local originalPrint = print
print = function() end
inventory.Verify(merged, cache, reviewed)
local removed = table.remove(cache.settings)
Reject(function() inventory.Verify(merged, cache, reviewed) end, "actual provider inventory differs")
cache.settings[2] = removed
cache.settings[3] = {tileId = "tile", subPageIndex = 1, featureId = "deleted", label = "stale", widgetType = "checkbox"}
Reject(function() inventory.Verify(merged, cache, reviewed) end, "controls not observed")
cache.settings[3] = nil
cache.settings[1].widgetType = "slider"
Reject(function() inventory.Verify(merged, cache, reviewed) end, "actual provider inventory differs")
cache.settings[1].widgetType = "checkbox"
merged.failures[1] = "render failure"
Reject(function() inventory.Verify(merged, cache, reviewed) end, "actual provider inventory differs")
merged.failures[1] = nil
reviewed["feature|non-search alias"] = "non-search alias"
Reject(function() inventory.Verify(merged, cache, reviewed) end, "reviewed control baseline changed")
reviewed["feature|non-search alias"] = nil
merged.sourceRows["feature|beta"] = nil
merged.expected["tile|1|beta|label||"] = nil
cache.settings[2] = nil
Reject(function() inventory.Verify(merged, cache, reviewed) end, "reviewed control baseline changed")
print = originalPrint
print("OK: inventory shard ownership and complete report merging")
