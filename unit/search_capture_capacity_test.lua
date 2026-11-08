-- Execute the production sanitation boundary with a growing capture result.
-- Plain Lua arrays must not lose valid destinations when the UI grows.
local path = os.getenv("QUI_CAPTURE_SOURCE") or "tools/generate_search_cache.lua"
local file = assert(io.open(path, "rb"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function clear_non_plain_arrays_before_route_seed()", 1, true))
local last = assert(source:find("\nclear_non_plain_arrays_before_route_seed()", first, true))
local sanitize = assert(loadstring("return function(GUI, frame)\n" .. source:sub(first, last - 1)
    .. "\nclear_non_plain_arrays_before_route_seed()\nend"))()
local gui = { StaticSettingsRegistry = {}, StaticNavigationRegistry = {} }
for index = 1, 6005 do gui.StaticSettingsRegistry[index] = { label = "Setting " .. index, tileId = "test", subPageIndex = 1 } end
for index = 1, 2105 do gui.StaticNavigationRegistry[index] = { label = "Section " .. index, tileId = "test", subPageIndex = 1 } end
local frame = { _tiles = {} }
for index = 1, 40 do
    local config = { name = "Tile " .. index, subPages = {} }
    for page = 1, 35 do config.subPages[page] = { name = "Page " .. page } end
    frame._tiles[index] = { id = "tile" .. index, config = config }
end
sanitize(gui, frame)
assert(#gui.StaticSettingsRegistry == 6005, "valid settings were silently truncated: " .. #gui.StaticSettingsRegistry)
assert(#gui.StaticNavigationRegistry == 2105, "valid navigation destinations were silently truncated")
assert(#frame._tiles == 40 and #frame._tiles[40].config.subPages == 35, "valid tiles/pages were silently truncated")
-- Headless service stubs still must not masquerade as actual captured arrays.
gui.StaticSettingsRegistry = setmetatable({}, { __index = function() return {} end })
gui.StaticNavigationRegistry = { { label = "valid" }, { label = "bad", tileId = {} } }
sanitize(gui, frame)
assert(#gui.StaticSettingsRegistry == 0 and #gui.StaticNavigationRegistry == 1)
print("OK: capture sanitation preserves all settings, sections, tiles, and pages without arbitrary ceilings")
