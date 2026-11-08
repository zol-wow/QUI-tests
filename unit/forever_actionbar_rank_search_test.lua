local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert(loadstring(source:sub(1, cut - 1) .. "\nreturn ns", "@search-preamble"))()
local GUI = _G.QUI.GUI
local cache = dofile("tests/helpers/search_cache.lua")()
local function Find(entries, key)
    for _, entry in ipairs(entries) do
        if entry.featureId == "actionBarsGeneral" and entry.widgetDescriptor
            and entry.widgetDescriptor.dbKey == key then return entry end
    end
end
local entry = assert(Find(cache.settings, "autoUpgradeSpellRanks"),
    "search must include the Forever spell rank setting")
assert(entry.tileId == "action_bars" and entry.subPageIndex == 1,
    "spell rank search must open Action Bars General")
for _, forever in ipairs({ false, true }) do
    ns.Client = { isForever = forever }
    assert(GUI:ApplyGeneratedSearchCache(cache))
    assert((Find(GUI.StaticSettingsRegistry, "autoUpgradeSpellRanks") ~= nil) == forever,
        "spell rank search must follow the client-specific setting availability")
    assert(Find(GUI.StaticSettingsRegistry, "hideEmptySlots"),
        "both clients must retain shared actionbar settings")
    local sharedCount = 0
    for _, setting in ipairs(GUI.StaticSettingsRegistry) do
        if setting.featureId == "actionBarsGeneral" and setting.widgetDescriptor
            and setting.widgetDescriptor.dbKey == "hideEmptySlots" then sharedCount = sharedCount + 1 end
    end
    assert(sharedCount == 1, "client variant capture must not duplicate shared settings")
end
print("OK: forever_actionbar_rank_search_test")
