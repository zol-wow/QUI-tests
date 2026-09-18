local function read(path)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    return source
end

local source = read("modules/skinning/character_pane/character.lua")
local section = assert(source:match("(local function ShowStatTooltip.-)local function FinalizeStatsPanelLayout"))
local settings = { showTooltips = true }
local ns = { Client = { isForever = true }, L = setmetatable({}, { __index = function(_, key) return key end }) }
local function noOp() end
local function widget()
    local frame = { shown = true }
    function frame:SetText(text) self.text = text end
    function frame:SetFormattedText(pattern, ...) self.text = string.format(pattern, ...) end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetWidth() return self.width or 150 end
    function frame:GetHeight() return self.height end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetScript(event, callback) self[event] = callback end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:CreateFontString() return widget() end
    function frame:CreateTexture() return widget() end
    for _, method in ipairs({ "SetTextColor", "SetShadowOffset", "EnableMouse", "SetHeight", "SetColorTexture",
        "SetJustifyH", "SetWordWrap" }) do
        frame[method] = noOp
    end
    return frame
end
local shield = false
local enum = { Damageclass = { Arcane = 7, Fire = 3, Frost = 5, Nature = 4, Shadow = 6 } }
local env = setmetatable({
    ns = ns,
    Enum = enum,
    C_PaperDollInfo = { OffhandHasShield = function() return shield end },
    GetSettings = function() return settings end,
    GetGlobalFont = function() return "font" end,
    CJKFont = noOp,
    GetPixelSize = function() return 1 end,
    TrackFontString = noOp,
    trackedUnderlines = {},
    Helpers = {},
    CreateFrame = widget,
    UnitResistance = function(_, school) return 999, school * 10, 888 end,
    BreakUpLargeNumbers = tostring,
    PaperDollFrame_SetResistanceTooltips = function(row, name, value, _, school)
        row.tooltip = name
        row.tooltip2 = tostring(value) .. ":" .. school
    end,
    NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 },
    GameTooltip = { SetOwner = noOp, SetText = noOp, AddLine = noOp, Show = noOp, Hide = noOp },
}, { __index = _G })
env._G = env
for _, key in ipairs({ "GENERAL", "PRIMARY_ATTRIBUTES", "WEAPONS", "MODIFIERS", "DEFENSE", "RESISTANCE" }) do
    env["STAT_CATEGORY_" .. key] = key
end
for i = 1, 7 do env["DAMAGE_SCHOOL" .. i] = "School " .. i end
local native = "tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/"
local catalog = assert(loadfile(native .. "PaperDollFrameConstants.lua"))
setfenv(catalog, env)
catalog()
local infoSource = assert(read(native .. "PaperDollFrame.lua"):match("(PAPERDOLL_STATINFO = {.-)\n%-%- Task"))
local infoChunk = assert(loadstring(infoSource))
setfenv(infoChunk, env)
infoChunk()
local called, values = {}, { OFFHAND_DAMAGE = 0, RANGED_DAMAGE = 0, HITCHANCE = 0 }
local nativeHaste = env.PAPERDOLL_STATINFO.HASTE.updateFunc
local function statUpdater(key)
    return function(row, unit)
        called[key] = (called[key] or 0) + 1
        local value = values[key] or 12
        row.Label:SetText(key)
        row.Value:SetText(value)
        row.numericValue = value
        row.unit = unit
        if key == "CRITCHANCE" then
            row.onEnterFunc = function(self) self.tooltipCalled = true end
        end
        return value
    end
end
for key, data in pairs(env.PAPERDOLL_STATINFO) do data.updateFunc = statUpdater(key) end
env.PAPERDOLL_STATINFO.HASTE.updateFunc = nativeHaste
env.max, env.format, env.STAT_FORMAT, env.STAT_HASTE = math.max, string.format, "%s", "HASTE"
env.GetMeleeHaste = function() return 4 end
env.GetRangedHaste = function() return 2, 5 end
env.UnitSpellHaste = function() return 3 end
env.CharacterHasteFrame_OnEnter = function(row, melee, ranged, spell)
    row.tooltipValues = { melee, ranged, spell }
end
for _, entry in ipairs({
    { "PaperDollFrame_SetLabelAndText", "PaperDollFrame.lua" },
    { "PaperDollFrame_SetHaste", "PaperDollFrameStats.lua" },
}) do
    local body = assert(read(native .. entry[2]):match("(function " .. entry[1] .. "%b().-\nend)"))
    local loadNative = assert(loadstring(body))
    setfenv(loadNative, env)
    loadNative()
end
for _, key in ipairs({ "MASTERY", "VERSATILITY", "LIFESTEAL", "AVOIDANCE", "SPEED" }) do
    env.PAPERDOLL_STATINFO[key].updateFunc = function() error("Retail-only stat must never be read: " .. key) end
end
local chunk = assert(loadstring(section .. "\nreturn UpdateForeverStatsPanel, CreateStatRow, ShowStatTooltip"))
setfenv(chunk, env)
local render, createRow, tooltip = chunk()
local parent = widget()
local y = render(parent, "player", -5)
assert(y < -100, "native rows must contribute to scroll content height")
local labels = {}
for _, row in ipairs(parent.statRowPool) do
    if row:IsShown() then labels[row.label.text] = row end
end
assert(labels.SPIRIT and labels.DEFENSE and labels.EXPERTISE and labels.SPELLHEALING,
    "Forever must include its native attributes, defense skill, and modifiers")
assert(not labels.BLOCK and not called.BLOCK, "block must follow the native equipped-shield predicate")
assert(not labels.OFFHAND_DAMAGE and not labels.RANGED_DAMAGE and not labels.HITCHANCE,
    "zero-value rows must follow native hideAt rules")
assert(called.HEALTH == 1, "player view must not also render pet categories")
assert(labels.HASTE.value.text == "7.0%", "native haste must combine ranged ammo haste and choose the highest haste school")
labels.HASTE:OnEnter()
assert(labels.HASTE.tooltipValues[2] == 7, "native haste tooltip must receive the native melee/ranged/spell breakdown")
assert(labels["School 7"].value.text == "70" and labels["School 3"].tooltip2 == "30:3",
    "resistances must use native effective values and native tooltip formulas")
local crit = labels.CRITCHANCE
crit:OnEnter()
assert(crit.tooltipCalled, "native tooltip handlers must run even without generic tooltip text")
local oldFirst = parent.statRowPool[1]
oldFirst.onEnterFunc, oldFirst.UpdateTooltip = function() error("stale tooltip") end, noOp
oldFirst.tooltip4, oldFirst.tooltipLabel = "stale", "old weapon"
parent.statRowUsed = 0
local reused = createRow(parent, 0)
assert(reused == oldFirst and reused.onEnterFunc == nil and reused.UpdateTooltip == nil
    and reused.tooltip4 == nil and reused.tooltipLabel == nil,
    "pooled rows must clear native tooltip handlers and weapon metadata")
shield = true
parent.statRowUsed, parent.sectionHeaderUsed = 0, 0
render(parent, "player", -5)
assert(called.BLOCK == 1, "equipping a shield must reveal native block stats")
settings.showTooltips = false
crit.tooltipCalled = false
tooltip(crit)
assert(not crit.tooltipCalled, "native tooltips must respect the character-panel tooltip setting")

local updateSection = assert(source:match("(local function UpdateStatsPanel.-)\n%-%- Item%-level colour"))
local finalY
ns.SafeCall = function(_, callback) callback(); return true end
env.InCombatLockdown = function() return false end
env.MaskNativeStatsPane = noOp
env.GetChrome = function()
    return { GetNativeStatsPane = function() return { IsShown = function() return true end } end }
end
env.trackedFontStrings = {}
env.wipe = function(table) for key in pairs(table) do table[key] = nil end end
env.FinalizeStatsPanelLayout = function(_, _, offset) finalY = offset end
env.GetSkinBase = function() error("Forever update must bypass the Retail stat renderer") end
env.EQUIPMENT_SLOTS = { { id = 1 }, { id = 2 } }
env.GEM_COLORS = {}
env.GetGemInfo = function(_, slot)
    if slot == 1 then return { { filled = true, type = "Red" }, { filled = false } } end
    return { { filled = true, type = "Blue" } }
end
local integrated = assert(loadstring(section .. "\n" .. updateSection .. "\nreturn UpdateStatsPanel"))
setfenv(integrated, env)
local update = integrated()
settings.showGemSummary, settings.statsTextSize = true, 40
local panel = widget()
panel.scrollChild = widget()
local healthCalls = called.HEALTH
update(panel, "player")
assert(called.HEALTH == healthCalls + 1,
    "UpdateStatsPanel must execute the Forever native renderer exactly once")
local visible, integratedLabels = {}, {}
for _, row in ipairs(panel.scrollChild.statRowPool) do
    if row:IsShown() then
        visible[#visible + 1] = row
        integratedLabels[row.label.text] = row
        assert(row:GetHeight() == 43, "native and gem rows must grow to contain the configured stat font")
    end
end
assert(integratedLabels.SPIRIT and integratedLabels.Red and integratedLabels.Blue
    and integratedLabels["Empty Sockets"],
    "the actual panel update must preserve the shared Gems section after native Forever stats")
table.sort(visible, function(a, b) return a.point[3] > b.point[3] end)
for index = 2, #visible do
    local previous, current = visible[index - 1], visible[index]
    assert(current.point[3] <= previous.point[3] - previous:GetHeight(),
        "large-font stat and gem rows must not overlap: " .. previous.label.text .. " / " .. current.label.text)
end
local last = visible[#visible]
assert(finalY <= last.point[3] - last:GetHeight(), "scroll height must contain the final large-font gem row")
print("OK: Forever character stats use the native catalog, visibility, resistance values, and tooltips")
