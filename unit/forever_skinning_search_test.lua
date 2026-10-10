local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert(loadstring(source:sub(1, cut - 1) .. "\nreturn ns", "@search-preamble"))()
local GUI = _G.QUI.GUI
local cache = dofile("tests/helpers/search_cache.lua")(os.getenv("QUI_SKIN_SEARCH_TEST_CACHE"))
local function Find(entries, key)
    for _, entry in ipairs(entries) do
        if entry.featureId == "skinningPage" and entry.widgetDescriptor
            and entry.widgetDescriptor.dbKey == key then return entry end
    end
end
for _, key in ipairs({ "skinLegacySystem", "skinStable", "skinKeystoneFrame" }) do
    local entry = assert(Find(cache.settings, key), "shared search cache must include " .. key)
    assert(entry.tileId == "appearance" and entry.subPageIndex == 4,
        "native skin searches must route to Appearance > Skinning")
end
for _, forever in ipairs({ false, true }) do
    ns.Client = { isForever = forever }
    assert(GUI:ApplyGeneratedSearchCache(cache))
    assert((Find(GUI.StaticSettingsRegistry, "skinLegacySystem") ~= nil) == forever,
        "Legacy skin search must follow client availability")
    assert((Find(GUI.StaticSettingsRegistry, "skinStable") ~= nil) == forever,
        "pet stable skin search must follow client availability")
    assert((Find(GUI.StaticSettingsRegistry, "skinKeystoneFrame") ~= nil) == not forever,
        "Keystone skin search must remain available only on Retail")
    assert(Find(GUI.StaticSettingsRegistry, "skinProfessions"),
        "client filtering must preserve shared profession skin settings")
end
print("OK: native skin search exposes the controls available on each client")
