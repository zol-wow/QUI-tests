local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert((loadstring or load)(source:sub(1, cut - 1) .. "\nreturn ns", "@gen-preamble"))()
local GUI = QUI.GUI
local cache = dofile("tests/helpers/search_cache.lua")()
local swingTimers = assert(ns.SwingTimers)

local paths = {}
for _, entry in ipairs(cache.settings) do
    if entry.featureId == "swingTimersPage" and entry.label == "Width" then
        local descriptor = assert(entry.widgetDescriptor)
        paths[descriptor.dbPath] = true
        assert(entry.sectionName and entry.tileId == "gameplay" and entry.subPageIndex == 10)
    end
end
for _, entry in ipairs(swingTimers.entries) do
    assert(paths["profile.swingTimers." .. entry.key], "missing searchable width for " .. entry.key)
end

local function CountSwingEntries(entries)
    local count = 0
    for _, entry in ipairs(entries) do
        if entry.subTabName == "Swing Timers" or (entry.featureId and entry.featureId:match("^swingTimer")) then
            count = count + 1
        end
    end
    return count
end

assert(GUI:ApplyGeneratedSearchCache(cache))
local settingCount = #GUI.StaticSettingsRegistry - CountSwingEntries(GUI.StaticSettingsRegistry)
local navigationCount = #GUI.StaticNavigationRegistry - CountSwingEntries(GUI.StaticNavigationRegistry)
ns.SwingTimers = nil
assert(GUI:ApplyGeneratedSearchCache(cache))
assert(CountSwingEntries(GUI.StaticSettingsRegistry) == 0, "Retail must omit swing settings")
assert(CountSwingEntries(GUI.StaticNavigationRegistry) == 0, "Retail must omit swing routes")
assert(#GUI.StaticSettingsRegistry == settingCount, "Retail must retain other settings")
assert(#GUI.StaticNavigationRegistry == navigationCount, "Retail must retain other routes")

ns.SwingTimers = swingTimers
assert(GUI:ApplyGeneratedSearchCache(cache))
assert(CountSwingEntries(GUI.StaticSettingsRegistry) == 22, "Forever must expose one toggle and seven settings per weapon")
assert(CountSwingEntries(GUI.StaticNavigationRegistry) > 0, "Forever must expose swing routes")
local _, navigation = GUI:ExecuteSearch("swing timers")
assert(#navigation > 0, "Forever swing timer search must return navigation")

print("OK: forever_swing_timers_search_test")
