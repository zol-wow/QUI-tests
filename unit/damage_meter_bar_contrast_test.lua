local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local theme = read("core/theme.lua")
local GUI = {}
local themeLoader = assert(loadstring(
    assert(theme:match("(local function LinearChannel.-\nend)")) .. "\n"
    .. assert(theme:match("(function GUI:GetRelativeLuminance.-\nend)"))))
setfenv(themeLoader, setmetatable({ GUI = GUI }, { __index = _G }))
themeLoader()

local src = read("QUI_DamageMeter/damage_meter/damage_meter.lua")
local chunk = assert(src:match("(local function SetRowBarColor.-\nend)"))
local loader = assert(loadstring(chunk .. "\nreturn SetRowBarColor"))
setfenv(loader, setmetatable({ _G = { QUI = { GUI = GUI } } }, { __index = _G }))
local SetRowBarColor = loader()

local function font(color, outline)
    return {
        GetFont = function() return "test.ttf", 11, outline end,
        GetTextColor = function() return unpack(color) end,
    }
end

local row = { Bar = {} }
local result
function row.Bar:SetStatusBarColor(...) result = { ... } end
local white = { 1, 1, 1, 1 }
local gray = { 0.75, 0.75, 0.78, 1 }
local priest = { 1, 1, 1, 1 }
local rogue = { 1, 0.96, 0.41, 1 }
local dark = { 0.08, 0.08, 0.08, 1 }

local function apply(fill, nameColor, valueColor, nameOutline, valueOutline)
    row.Name = font(nameColor, nameOutline)
    row.Value = font(valueColor, valueOutline)
    SetRowBarColor(row, unpack(fill))
end

local function unchanged(fill)
    for i = 1, 4 do assert(result[i] == fill[i], "existing readable styling must be preserved") end
end

local function readable(fill, nameColor, valueColor)
    local background = GUI:GetRelativeLuminance(unpack(result))
    for _, color in ipairs({ nameColor, valueColor }) do
        assert((GUI:GetRelativeLuminance(unpack(color)) + 0.05) / (background + 0.05) >= 4.5,
            "bright fills need readable contrast for both text slots")
    end
    assert(result[1] < fill[1], "bright fill must visibly darken")
    assert(math.abs(result[1] / fill[1] - result[2] / fill[2]) < 0.000001
        and math.abs(result[1] / fill[1] - result[3] / fill[3]) < 0.000001,
        "darkening must preserve the class hue")
    assert(result[4] == fill[4], "configured fill alpha must be preserved")
end

for _, fill in ipairs({ priest, rogue }) do
    apply(fill, white, gray, "", "")
    readable(fill, white, gray)
    apply(fill, fill, gray, "", "OUTLINE")
    readable(fill, fill, gray)
    apply(fill, white, gray, "THICKOUTLINE", "")
    readable(fill, white, gray)
    apply(fill, white, gray, "OUTLINE", "THICKOUTLINE")
    unchanged(fill)
    apply(fill, dark, dark, "", "")
    unchanged(fill)
    apply(fill, dark, white, "", "")
    unchanged(fill)
end

apply(dark, white, gray, "", "")
unchanged(dark)
apply({ 1, 1, 1, 0.6 }, white, gray, nil, nil)
readable({ 1, 1, 1, 0.6 }, white, gray)
local first = result[1]
SetRowBarColor(row, 1, 1, 1, 0.6)
assert(result[1] == first, "pooled row refresh must not accumulate darkening")

local _, directWrites = src:gsub("row%.Bar:SetStatusBarColor%(", "")
assert(directWrites == 1, "row color writes must route through the contrast helper")
for _, method in ipairs({ "Window:_SetRowSource", "Breakdown:_SetSpellRow", "Breakdown:_SetTargetRow" }) do
    local body = assert(src:match("function " .. method .. "%b()(.-)\nend"))
    assert(body:find("SetRowBarColor(row,", 1, true), method .. " must apply contrast")
end

print("OK: damage_meter_bar_contrast_test")
