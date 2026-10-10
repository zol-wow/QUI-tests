local path = os.getenv("QUI_PREY_SOURCE") or "modules/trackers/settings/prey_tracker_content.lua"
local file = assert(io.open(path, "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("    local colorModeOptions =", 1, true))
local last = assert(source:find("    sBA.AddRow(", first, true))
local chunk = assert((loadstring or load)("return function(GUI, sBA, ns, db, RefreshPreview)\n" .. source:sub(first, last - 1) .. "\nreturn colorModeDropdown\nend"))
for _, mode in ipairs({ "accent", "class", "custom" }) do
    local db = { barUseClassColor = mode == "class", barUseAccentColor = mode == "accent" }
    local calls, selected, callback = 0
    local gui = { CreateFormDropdown = function(_, _, _, options, key, state, change)
        selected, callback = state and state[key], change
        return { GetChildren = function() end }
    end }
    chunk()(gui, { frame = {} }, { L = setmetatable({}, { __index = function(_, k) return k end }) }, db,
        function() calls = calls + 1 end)
    assert(selected == mode and type(callback) == "function", "color mode must initialize the shared dropdown with the current selection and callback")
    for _, nextMode in ipairs({ "class", "accent", "custom" }) do
        callback(nextMode)
        assert(db.barUseClassColor == (nextMode == "class") and db.barUseAccentColor == (nextMode == "accent"), "color selection must update both exclusive flags")
    end
    assert(calls == 3, "each selection must refresh the preview once")
end
print("OK: prey_color_dropdown_test")
