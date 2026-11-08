-- tests/unit/search_cache_dual_home_aura_routes_test.lua
-- Run: lua tests/unit/search_cache_dual_home_aura_routes_test.lua
--
-- Every aura editor is mounted in TWO places -- its owning module tile and the
-- Auras hub -- and both must be indexed for search. Before the dual-surface
-- work, hub pages re-tagged the search context only AFTER the render returned,
-- so the hub carried the page's own chrome (about 5 rows) and not one editor
-- widget.
--
-- These per-surface counts are NOT liveness proofs -- they only assert that
-- rows matching a tileId/surfaceTabKey/featureId exist in sufficient
-- quantity. Two of the module-side probes below (Group Frames, Nameplates)
-- would have passed unchanged at HEAD, when the Group Frames module rows
-- were dead. Route liveness (whether a cache row's route is actually
-- reachable from a live tab/subtab) is carried entirely by
-- tools/audit_search_cache.lua --strict-routes, exercised by
-- tests/unit/search_cache_live_routes_test.lua -- do not over-trust the
-- module-side numbers here as proof of reachability.

local cache = dofile("tests/helpers/search_cache.lua")()
local settings = assert(cache.settings, "cache must have a settings section")

local failures = 0
local function check(name, ok, detail)
    if ok then
        print("  ok  " .. name)
    else
        failures = failures + 1
        print("FAIL  " .. name .. (detail and (" -- " .. detail) or ""))
    end
end

-- Each surface: a module-route probe and a hub-route probe. minimum is a floor,
-- not an exact count, so ordinary option churn does not redden this test.
--
-- Both homes are captured from registered hosts and actual selector options.
-- Expanded element fixtures may still add controls beyond the collapsed editor.
local SURFACES = {
    {
        name = "Group Frames auras",
        moduleMatch = function(e) return e.tileId == "group_frames" and e.surfaceTabKey == "auras" end,
        hubMatch = function(e) return e.tileId == "auras" and e.featureId == "aurasGroupPage" end,
        minimum = 8,
    },
    {
        name = "Unit Frames auras",
        moduleMatch = function(e) return e.tileId == "unit_frames" and e.surfaceTabKey == "icons" end,
        hubMatch = function(e) return e.tileId == "auras" and e.featureId == "aurasUnitPage" end,
        minimum = 2,
    },
    {
        name = "Nameplates auras",
        moduleMatch = function(e) return e.tileId == "nameplates" and e.surfaceTabKey == "auras" end,
        hubMatch = function(e) return e.tileId == "auras" and e.featureId == "aurasNameplatePage" end,
        minimum = 10,
    },
    {
        name = "Buff/Debuff frames",
        moduleMatch = function(e) return e.tileId == "action_bars" and e.featureId == "actionBarsBuffDebuffPage" end,
        hubMatch = function(e) return e.tileId == "auras" and e.featureId == "aurasActionBarPage" end,
        minimum = 20,
    },
}

for _, surface in ipairs(SURFACES) do
    local moduleRows, hubRows = 0, 0
    for _, entry in ipairs(settings) do
        if surface.moduleMatch(entry) then moduleRows = moduleRows + 1 end
        if surface.hubMatch(entry) then hubRows = hubRows + 1 end
    end
    check(surface.name .. " is indexed on its module tile",
        moduleRows >= surface.minimum,
        "got " .. moduleRows .. ", want >= " .. surface.minimum)
    check(surface.name .. " is indexed on the Auras hub",
        hubRows >= surface.minimum,
        "got " .. hubRows .. ", want >= " .. surface.minimum)
end

for _, featureId in ipairs({ "groupFramesPage", "aurasDisplaysPage", "nameplatesPage", "aurasNameplatePage" }) do
    local labels = {}
    for _, entry in ipairs(settings) do
        if entry.featureId == featureId then labels[entry.label] = true end
    end
    check(featureId .. " indexes native aura display controls",
        labels["Show Caster Name"] and labels["Show Realm Name"]
        and labels["Use Class Colors"] and labels["Pandemic Glow Style"])
end

if failures > 0 then
    print("FAIL: search_cache_dual_home_aura_routes_test (" .. failures .. " failure(s))")
    os.exit(1)
end

print("OK: search_cache_dual_home_aura_routes_test")
