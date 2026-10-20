local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local source = read(arg[1] or "modules/skinning/character_pane/character.lua")
local section = assert(source:match("(local function ShowStatTooltip.-)local function FinalizeStatsPanelLayout"))
local nativeSource = read("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua")
local secure, restricted = false, true
local secrets = setmetatable({}, { __mode = "k" })
local function plain(value)
    if type(value) == "table" and secrets[value] ~= nil then return secrets[value] end
    return value
end
local secretMeta = {}
local function secret(value)
    local object = setmetatable({}, secretMeta)
    secrets[object] = value
    return object
end
for name, operation in pairs({
    __div = function(a, b) return a / b end,
    __mul = function(a, b) return a * b end,
    __add = function(a, b) return a + b end,
    __concat = function(a, b) return a .. b end,
}) do
    secretMeta[name] = function(a, b)
        assert(secure, "attempt to perform arithmetic on local 'runSpeed' (a secret number value, while execution tainted by 'QUI')")
        return secret(operation(plain(a), plain(b)))
    end
end
secretMeta.__tostring = function() error("secret value must reach a supported text sink") end
local function formatted(pattern, ...)
    local values, hasSecret = { ... }, false
    for i = 1, select("#", ...) do
        if type(values[i]) == "table" and secrets[values[i]] ~= nil then hasSecret = true end
        values[i] = plain(values[i])
    end
    local text = string.format(pattern, unpack(values))
    return hasSecret and secret(text) or text
end
local function noOp() end
local function widget()
    local frame = { shown = true }
    function frame:SetText(value) self.text = value end
    function frame:GetText() return self.text end
    function frame:SetFormattedText(pattern, ...) self.text = formatted(pattern, ...) end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetWidth() return self.width or 150 end
    function frame:GetHeight() return self.height end
    function frame:SetScript(event, callback) self[event] = callback end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:CreateFontString() return widget() end
    function frame:CreateTexture() return widget() end
    for _, name in ipairs({ "SetPoint", "SetTextColor", "SetShadowOffset", "EnableMouse", "SetHeight",
        "SetColorTexture", "SetJustifyH", "SetWordWrap" }) do frame[name] = noOp end
    return frame
end
local settings = { showTooltips = true }
local tooltip = { lines = {}, shown = 0 }
function tooltip:SetOwner(owner) self.owner, self.lines = owner, {} end
function tooltip:SetText(value) self.title = plain(value) end
function tooltip:AddLine(value) self.lines[#self.lines + 1] = plain(value) end
function tooltip:Show() self.shown = self.shown + 1 end
function tooltip:Hide() end
local swimming, flying, falling, showFlight = false, false, false, true
local speeds = { 0, 7.56, 22.05, 4.69 }
local addonSpeedCalls, laterRows, hookCount = 0, 0, 0
local env = setmetatable({
    ns = { Client = { isForever = true } }, Helpers = {}, trackedUnderlines = {},
    GetSettings = function() return settings end, GetGlobalFont = function() return "font" end,
    CJKFont = noOp, TrackFontString = noOp, GetPixelSize = function() return 1 end, CreateFrame = widget,
    Enum = { Damageclass = { Arcane = 6, Fire = 2, Frost = 4, Nature = 3, Shadow = 5 } },
    UnitResistance = function() return 0, 0 end, PaperDollFrame_SetResistanceTooltips = noOp,
    STAT_CATEGORY_RESISTANCE = "Resistance", STAT_MOVEMENT_SPEED = "Movement Speed", STAT_FORMAT = "%s",
    BASE_MOVEMENT_SPEED = 7, HIGHLIGHT_FONT_COLOR_CODE = "", FONT_COLOR_CODE_CLOSE = "",
    PAPERDOLLFRAME_TOOLTIP_FORMAT = "%s", STAT_MOVEMENT_GROUND_TOOLTIP = "Ground: %d%%",
    STAT_MOVEMENT_FLIGHT_TOOLTIP = "Flight: %d%%", STAT_MOVEMENT_SWIM_TOOLTIP = "Swim: %d%%",
    CR_SPEED_TOOLTIP = "Rating %s; bonus %.1f%%", CR_SPEED = 14,
    NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 }, GameTooltip = tooltip,
    PaperDollFrame_ShowFlightSpeed = function() return showFlight end,
    IsSwimming = function() return swimming end, IsFlying = function() return flying end,
    IsFalling = function() return falling end,
    GetCombatRating = function() return restricted and secret(123) or 123 end,
    GetCombatRatingBonus = function() return restricted and secret(4.5) or 4.5 end,
    BreakUpLargeNumbers = function(value)
        local text = tostring(plain(value))
        return type(value) == "table" and secret(text) or text
    end,
    C_StringUtil = { RoundToNearestString = function(value)
        local text = tostring(math.floor(plain(value) + 0.5))
        return type(value) == "table" and secret(text) or text
    end },
}, { __index = _G })
env._G = env
env.format = function(pattern, ...)
    if not secure then
        for i = 1, select("#", ...) do assert(type(select(i, ...)) ~= "table", "native format called under QUI") end
    end
    return formatted(pattern, ...)
end
env.GetUnitSpeed = function()
    if not secure then addonSpeedCalls = addonSpeedCalls + 1 end
    local result = {}
    for i, speed in ipairs(speeds) do result[i] = restricted and secret(speed) or speed end
    return unpack(result)
end
for _, name in ipairs({ "PaperDollFrame_SetLabelAndText", "MovementSpeed_OnEnter", "MovementSpeed_OnUpdate", "PaperDollFrame_SetMovementSpeed" }) do
    local body = assert(nativeSource:match("(function " .. name .. "%b().-\nend)"))
    local chunk = assert(loadstring(body, "@native/" .. name))
    setfenv(chunk, env)
    chunk()
end
env.hooksecurefunc = function(name, callback)
    hookCount = hookCount + 1
    local original = assert(env[name])
    env[name] = function(...)
        local result = { original(...) }
        local wasSecure = secure
        secure = false
        callback(...)
        secure = wasSecure
        return unpack(result)
    end
end
env.PAPERDOLL_STATCATEGORIES = { { categoryName = "General", stats = { { stat = "MOVESPEED" }, { stat = "AFTER" } } } }
env.PAPERDOLL_STATINFO = {
    MOVESPEED = { updateFunc = function(row, unit) return env.PaperDollFrame_SetMovementSpeed(row, unit) end },
    AFTER = { updateFunc = function(row)
        laterRows = laterRows + 1
        row.Label:SetText("After movement")
        row.Value:SetText("still rendered")
        return 1
    end },
}
local chunk = assert(loadstring(section .. "\nreturn UpdateForeverStatsPanel, ShowStatTooltip, HookForeverMovementSpeed"))
setfenv(chunk, env)
local render, showTooltip, install = chunk()
local nativeRow = widget()
nativeRow.Label, nativeRow.Value = widget(), widget()
local function updateNative(unit, preserveSwimming)
    secure = true
    local ok, err
    if preserveSwimming then
        nativeRow.unit, nativeRow.wasSwimming = unit, true
        ok, err = pcall(env.MovementSpeed_OnUpdate, nativeRow)
    else
        ok, err = pcall(env.PaperDollFrame_SetMovementSpeed, nativeRow, unit)
    end
    secure = false
    assert(ok, err)
end
local function renderRows(unit)
    local parent = widget()
    local before = laterRows
    render(parent, unit, -5)
    assert(laterRows == before + 1, "rows after movement must survive restricted speed")
    assert(addonSpeedCalls == 0, "QUI must not call GetUnitSpeed or the native movement calculator")
    return parent.statRowPool[1]
end
local emptyRow = renderRows("player")
assert(not emptyRow:IsShown(), "an unavailable native snapshot must not trigger addon calculation or fabricate zero speed")
updateNative("player")
local row = renderRows("player")
assert(plain(row.Value:GetText()) == "108%", "captured native percentage remains visible")
assert(hookCount == 1, "native hook installs once")
install()
assert(hookCount == 1, "native hook installation is idempotent")
for _, isRestricted in ipairs({ false, true }) do
    restricted = isRestricted
    for _, case in ipairs({
        { false, false, false, "108%" }, { false, true, false, "315%" },
        { true, false, false, "67%" }, { false, false, true, "67%" },
    }) do
        swimming, flying, falling = case[1], case[2], case[3]
        updateNative("player", falling)
        row = renderRows("player")
        assert(plain(row.Value:GetText()) == case[4], "movement modes retain native display")
    end
end
swimming, flying, falling = false, false, false
updateNative("player")
row = renderRows("player")
showTooltip(row)
assert(tooltip.title == "Movement Speed 108%", "tooltip title uses rounded native percentage")
assert(table.concat(tooltip.lines, "|") == "Ground: 108%|Flight: 315%|Swim: 67%| |Rating 123; bonus 4.5%",
    "secret tooltip preserves ground, flight, swim, and speed-rating details")
showFlight = false
row:UpdateTooltip()
assert(#tooltip.lines == 4 and tooltip.lines[2] == "Swim: 67%", "native flight predicate is respected")
showFlight = true
settings.showTooltips = false
local shown = tooltip.shown
showTooltip(row)
assert(tooltip.shown == shown, "disabled tooltips remain disabled")
settings.showTooltips = true
speeds[2] = 14
updateNative("pet")
local petRow = renderRows("pet")
assert(plain(petRow.Value:GetText()) == "200%", "pet uses its own movement cache")
showTooltip(petRow)
assert(#tooltip.lines == 4 and tooltip.lines[2] == "Swim: 200%", "pet uses ground speed for swimming and omits flight")
nativeRow.Value:SetText("pooled row reused")
nativeRow.speed, nativeRow.runSpeed, nativeRow.flightSpeed, nativeRow.swimSpeed = 999, 999, 999, 999
assert(plain(renderRows("player").Value:GetText()) == "108%", "pet and pooled native frames cannot overwrite player snapshot")
assert(plain(renderRows("pet").Value:GetText()) == "200%", "snapshot does not retain the pooled native frame")
speeds[2] = 10.5
updateNative("player")
assert(plain(renderRows("player").Value:GetText()) == "150%", "next native update replaces stale display")
row:UpdateTooltip()
assert(tooltip.title == "Movement Speed 150%", "already-open tooltip reads the newest native snapshot")
assert(addonSpeedCalls == 0, "all custom renders avoid native arithmetic")
local movementUpdate = env.MovementSpeed_OnUpdate
env.MovementSpeed_OnUpdate = nil
local lateRender, _, lateInstall = chunk()
env.MovementSpeed_OnUpdate = movementUpdate
env.HookCharacterFrame = lateInstall
local eventFrame = widget()
eventFrame.RegisterEvent, eventFrame.RegisterUnitEvent = noOp, noOp
env.CreateFrame = function() return eventFrame end
local eventSource = assert(source:match('(local eventFrame = CreateFrame%("Frame"%)\neventFrame:RegisterEvent%("ADDON_LOADED"%).-)\nif ns.WhenLoggedIn'))
local events = assert(loadstring(eventSource))
setfenv(events, env)
events()
eventFrame:OnEvent("ADDON_LOADED", "Blizzard_UIPanels_Game")
env.CreateFrame = widget
assert(hookCount == 2, "late UIPanels loading must install the previously unavailable capture hook")
updateNative("player")
local lateParent = widget()
lateRender(lateParent, "player", -5)
assert(plain(lateParent.statRowPool[1].Value:GetText()) == "150%",
    "late-loaded native movement must populate the custom row")
print("OK: Forever movement preserves native values and tooltips without addon secret arithmetic")
