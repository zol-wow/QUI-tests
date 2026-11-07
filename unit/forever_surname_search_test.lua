local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local cut = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
local ns = assert(loadstring(source:sub(1, cut - 1) .. "\nreturn ns", "@search-preamble"))()
local GUI = _G.QUI.GUI
local cache = dofile("tests/helpers/search_cache.lua")()

local function CountSurnameSettings(entries)
    local count = 0
    for _, entry in ipairs(entries) do
        if (entry.featureId == "unitFramesPage" or entry.featureId == "nameplatesPage")
            and entry.label == "Show Last Name" then
            assert(entry.surfaceTabKey == "text", "surname search must open the Text tab")
            assert(entry.surfaceUnitKey or entry.surfaceTypeKey,
                "surname search must identify its frame or nameplate type")
            count = count + 1
        end
    end
    return count
end

assert(CountSurnameSettings(cache.settings) == 12,
    "surname search must expose all six unit frames and six nameplate types")
for _, forever in ipairs({ false, true }) do
    ns.Client = { isForever = forever }
    assert(GUI:ApplyGeneratedSearchCache(cache))
    assert(CountSurnameSettings(GUI.StaticSettingsRegistry) == (forever and 12 or 0),
        "surname search must be available only on Forever")
end
print("OK: Forever surname search routes and client availability")
