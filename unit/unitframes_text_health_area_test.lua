local file = assert(io.open("QUI_UnitFrames/unitframes/unitframes.lua", "rb"))
local source = file:read("*a")
file:close()

local function Slice(first, last, after)
    local start = assert(source:find(first, after or 1, true), first)
    local finish = assert(source:find(last, start + #first, true), last)
    return source:sub(start, finish - 1), start
end

local function NewRegion(parent)
    local region = { parent = parent, points = {}, shown = true, level = 1 }
    function region:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function region:ClearAllPoints() self.points = {} end
    function region:SetAllPoints(target) self.allPoints = target or self.parent end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level end
    function region:CreateFontString() return NewRegion(self) end
    function region:SetJustifyH(value) self.justify = value end
    function region:SetTextColor() end
    function region:SetFont() end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    return region
end

local function Noop() end
local env = setmetatable({
    CreateFrame = function(_, _, parent) return NewRegion(parent) end,
    QUICore = {
        PixelRound = function(_, value) return value end,
        GetPixelSize = function() return 1 end,
    },
    Helpers = { ApplyFontWithFallback = Noop, ApplyBarStyle = Noop },
    CJKFont = Noop,
    GetFontPath = function() return "font" end,
    GetTexturePath = function() return "texture" end,
    ResolveTextFont = function(_, fallback) return fallback end,
}, { __index = _G })

local loader = loadstring or load
local function Compile(body)
    local chunk = assert(loader(body))
    if setfenv then setfenv(chunk, env) else chunk = assert(load(body, nil, "t", env)) end
    return chunk()
end

local helpers = Slice("local TEXT_ANCHOR_MAP = {", "local function ResolveTextFont(")
local nameSettings = Slice("local function GetNameSettings(", "local function IsPlayerFrameEnabled(")
local creationStart = assert(source:find("local function CreateUnitFrame(", 1, true))
local creation = Slice('    local textFrame = CreateFrame("Frame", nil, frame)',
    '    if unitKey == "player" then', creationStart)
local refreshStart = assert(source:find("    local refreshNameSettings = GetNameSettings(settings)", 1, true))
local refresh = Slice("    local refreshNameSettings = GetNameSettings(settings)",
    '    if unitKey == "player" and settings.indicators then', refreshStart)
local barStart = assert(source:find("local function BuildFrameBars(", 1, true))
local barLayout = Slice("    local powerHeight = settings.showPowerBar", "    Helpers.ApplyBarStyle(healthBar", barStart)
local refreshBarStart = assert(source:find("    frame.healthBar:SetAlpha(healthOpacity)", 1, true))
local refreshLayout = Slice("    local powerHeight = settings.showPowerBar", "    CacheHealthBarExtents(frame", refreshBarStart)

local api = Compile(helpers .. nameSettings .. [[
return {
    create = function(frame, settings)
        local general = {}
        local borderSize = settings.borderSize or 1
]] .. barLayout .. [[
        frame.healthBar = healthBar
]] .. creation .. [[
    end,
    refresh = function(frame, settings)
        local fontPath, fontOutline = "font", "OUTLINE"
        local borderSize = settings.borderSize or 1
]] .. refreshLayout .. refresh .. [[
    end,
}
]])

local settings = { borderSize = 2, showName = true, showHealth = true, showLevel = true,
    healthDisplayStyle = "percent", showPowerBar = true, powerBarHeight = 10 }
local fields = {
    { "nameText", "name" }, { "levelText", "level" },
    { "healthText", "health" }, { "powerText", "powerText" },
}

local function Check(frame, anchor, phase)
    for _, entry in ipairs(fields) do
        local text, prefix = frame[entry[1]], entry[2]
        local point = assert(text.points[1])
        assert(point[2] == frame.healthBar, phase .. " " .. entry[1] .. " must anchor to health area above mana")
        assert(point[1] == anchor and point[3] == anchor, phase .. " must preserve chosen anchor")
        assert(point[4] == settings[prefix .. "OffsetX"] and point[5] == settings[prefix .. "OffsetY"],
            phase .. " must preserve custom offsets")
        assert(text.parent == frame.textFrame, phase .. " must preserve overlay ownership")
    end
    local bottom = frame.healthBar.points[2]
    local expected = settings.borderSize + (settings.showPowerBar and settings.powerBarHeight or 0)
        + ((settings.showPowerBar and settings.powerBarBorder ~= false) and 1 or 0)
    assert(bottom[1] == "BOTTOMRIGHT" and bottom[5] == expected,
        phase .. " health area must reserve configured mana height and separator")
end

for _, anchor in ipairs({ "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT", "CENTER", "TOP" }) do
    for index, entry in ipairs(fields) do
        settings[entry[2] .. "Anchor"] = anchor
        settings[entry[2] .. "OffsetX"] = index - 3
        settings[entry[2] .. "OffsetY"] = index + 1
    end
    local frame = NewRegion()
    settings.showPowerBar, settings.powerBarHeight, settings.powerBarBorder = true, 10, true
    api.create(frame, settings)
    Check(frame, anchor, "creation")
    for _, state in ipairs({ { true, 16, false }, { false, 16, true }, { true, 4, true } }) do
        settings.showPowerBar, settings.powerBarHeight, settings.powerBarBorder = unpack(state)
        api.refresh(frame, settings)
        Check(frame, anchor, "refresh")
    end
end

print("OK: unitframes_text_health_area_test")
