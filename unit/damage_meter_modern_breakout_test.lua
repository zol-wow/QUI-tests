local function widget(parent)
    local value = {
        shown = true, scripts = {}, parent = parent, width = 300, height = 200,
        RegisterForClicks = false,
    }
    function value:CreateTexture() return widget(self) end
    function value:CreateFontString() return widget(self) end
    function value:SetScript(name, fn) self.scripts[name] = fn end
    function value:GetScript(name) return self.scripts[name] end
    function value:Show() self.shown = true end
    function value:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function value:IsShown() return self.shown end
    function value:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function value:SetSize(width, height) self.width, self.height = width, height end
    function value:SetWidth(width) self.width = width end
    function value:SetHeight(height) self.height = height end
    function value:GetWidth() return rawget(self, "width") or 0 end
    function value:GetHeight() return rawget(self, "height") or 0 end
    function value:SetText(text) self.text = text end
    function value:SetFormattedText(format, ...) self.text = string.format(format, ...) end
    function value:SetVerticalScroll(offset) self.offset = offset end
    function value:GetVerticalScroll() return rawget(self, "offset") or 0 end
    function value:GetEffectiveScale() return 1 end
    function value:GetLeft() return 0 end
    function value:GetBottom() return 0 end
    function value:GetFrameLevel() return 1 end
    function value:GetFrameStrata() return "HIGH" end
    function value:SetScrollChild(child) self.child = child end
    setmetatable(value, { __index = function()
        return function() end
    end })
    return value
end

local UIParent = widget()
local created = {}
local function CreateFrame(_, name, parent)
    local frame = widget(parent)
    frame.name = name
    created[#created + 1] = frame
    return frame
end

local sources = {
    { name = "One", sourceGUID = "Player-One", specIconID = 101, totalAmount = 100, amountPerSecond = 10 },
    { name = "Two", sourceGUID = "Player-Two", specIconID = 202, totalAmount = 50, amountPerSecond = 5 },
}
local spells = {
    { spellID = 11, name = "Spell", totalAmount = 100, amountPerSecond = 10, rank = 1 },
}
local targetSpells = {
    { spellID = 22, name = "Target Spell", totalAmount = 60, amountPerSecond = 6, rank = 1 },
}
local targets = {
    { name = "Target", sourceGUID = "Creature-Target", sourceCreatureID = 42,
        totalAmount = 60, amountPerSecond = 6 },
}
local availableSessions = {}
local historicalSources = {}
local breakdownFetches = 0
local breakdownLimit
local combinedBreakdownLimit
local sessionFetches = 0
local segmentLabelBuilds = 0
local segmentDurationBuilds = 0
local comparisonFormats = 0
local Data = { _inCombat = false }
function Data:GetView(_, _, sessionID)
    return { sources = sessionID and historicalSources or sources, maxAmount = 100 }
end
function Data:GetCombinedHealingView() return self:GetView() end
function Data:GetBreakdownView(_, _, _, _, _, reuse, limit)
    breakdownFetches = breakdownFetches + 1
    breakdownLimit = limit
    reuse = reuse or {}
    reuse.spells = spells
    reuse.maxAmount = 100
    reuse.totalAmount = 100
    return reuse
end
function Data:GetCombinedHealingBreakdown(_, _, _, _, reuse, limit)
    combinedBreakdownLimit = limit
    return self:GetBreakdownView(nil, nil, nil, nil, nil, reuse, limit)
end
function Data:GetPlayerTargets() return targets end
function Data:GetPlayerTargetBreakdown(_, playerName, sourceGUID, sourceCreatureID, _, reuse, limit)
    assert(playerName == "One" and sourceGUID == "Creature-Target" and sourceCreatureID == 42)
    assert(limit == 40)
    reuse = reuse or {}
    reuse.spells = targetSpells
    reuse.maxAmount = 60
    reuse.totalAmount = 60
    return reuse
end
function Data:GetEnemyAttackers() return {} end
function Data:ResolveSourceSelector(source)
    return source and source.sourceGUID, source and source.sourceCreatureID, "direct"
end

local Window = {}
Window.__index = Window
function Window:_SetRowSource(row, source)
    row._source = source
    row.Icon:Show()
end
local hoveredPlayerRow
function Window:_ShowPlayerRowHover(row, withPreview)
    hoveredPlayerRow = row
    assert(withPreview == false)
end
function Window:_HidePlayerRowHover(row, withPreview)
    assert(row == hoveredPlayerRow and withPreview == false)
    hoveredPlayerRow = nil
end

local Breakdown = {}
Breakdown.__index = Breakdown
function Breakdown:_SetSpellRow(row, spell)
    row._spellID = spell.spellID
    row.Value:SetText("rendered " .. tostring(spell.totalAmount))
end
function Breakdown:_SetTargetRow(row, target)
    row._spellID = nil
    row._target = target
end
function Breakdown:_SetDeathRow(row) row._spellID = nil end

local WindowManager = { windows = {} }
local L = setmetatable({}, { __index = function(_, key) return key end })
local ns = {
    L = L,
    Helpers = { IsSecretValue = function() return false end },
    SafeCall = function(_, fn, ...) return true, fn(...) end,
    UIKit = {
        CreateBackdropBorder = function() return widget() end,
        CreateCloseButton = function(parent, options)
            local button = widget(parent)
            button:SetScript("OnClick", options.onClick)
            return button
        end,
    },
    SkinBase = {
        CreateButton = function(parent, options)
            local button = widget(parent)
            button:SetText(options.text)
            button:SetScript("OnClick", options.onClick)
            return button
        end,
    },
}
ns.QUI_DamageMeter = {
    Data = Data,
    WindowManager = WindowManager,
    Window = Window,
    Breakdown = Breakdown,
    ResolveAppearance = function(windowID, key)
        if key == "barSpacing" then return 2 end
        if key == "barHeight" then return windowID == 2 and 24 or 18 end
    end,
    AttachRowVisuals = function(row)
        row.Icon, row.Bar, row.BarBg = widget(row), widget(row), widget(row)
        row.Name, row.Value = widget(row), widget(row)
    end,
    GetAccentColor = function() return 0.3, 0.6, 1, 1 end,
    ApplyRowBackgroundVisibility = function() end,
    TakeTrailingSessions = function(value) return value end,
    BuildPreviousSessionLabel = function(value, separateDuration)
        if separateDuration then
            segmentLabelBuilds = segmentLabelBuilds + 1
            segmentDurationBuilds = segmentDurationBuilds + 1
            return value.name, value.durationSeconds == 120 and "2:00" or "1:00"
        end
        return value.name .. " [1:00]"
    end,
    FormatDuration = function() return "1:00" end,
    FormatNumber = function(value)
        comparisonFormats = comparisonFormats + 1
        return tostring(value)
    end,
    ShortenName = function(value) return value end,
    LabelForSession = function(value) return value == 1 and "Current" or "Overall" end,
    LabelForType = function() return "Damage Done" end,
    MeterTypes = { 1, 2 },
    GetDeathRecapRows = function() return {}, 1 end,
}

local combatLockdown = false
local tableConcats = 0
local tableLibrary = {}
for key, value in pairs(table) do tableLibrary[key] = value end
tableLibrary.concat = function(...)
    tableConcats = tableConcats + 1
    return table.concat(...)
end
local env = {
    _G = { QUI = { db = { profile = { damageMeter = { native = {} } } } }, UISpecialFrames = {} },
    CreateFrame = CreateFrame,
    UIParent = UIParent,
    Enum = {
        DamageMeterType = {
            DamageDone = 1, Dps = 2, HealingDone = 3, Hps = 4,
            EnemyDamageTaken = 5, Deaths = 6,
        },
        DamageMeterSessionType = { Overall = 0, Current = 1 },
    },
    C_DamageMeter = { GetAvailableCombatSessions = function()
        sessionFetches = sessionFetches + 1
        return availableSessions
    end },
    InCombatLockdown = function() return combatLockdown end,
    GameTooltip = widget(),
    table = tableLibrary,
}
setmetatable(env, { __index = _G })
local loader = assert(loadfile("QUI_DamageMeter/damage_meter/breakout.lua"))
setfenv(loader, env)
loader("QUI_DamageMeter", ns)

local ownerOne = { windowID = 1, sessionType = 1, damageMeterType = 1 }
local ownerTwo = { windowID = 2, sessionType = 1, damageMeterType = 1 }
WindowManager.windows[1] = ownerOne
WindowManager.windows[2] = ownerTwo

local preallocated = WindowManager.breakout
assert(preallocated and preallocated.frame.name == "QUI_DamageMeterBreakout")
WindowManager.breakout = nil
combatLockdown = true
local framesBeforeBlockedOpen = #created
assert(not WindowManager:OpenBreakout(ownerOne, sources[1], "Player-One", nil, false))
assert(WindowManager.breakout == nil and #created == framesBeforeBlockedOpen)
WindowManager.breakout = preallocated
combatLockdown = false
assert(WindowManager:OpenBreakout(ownerOne, sources[1], "Player-One", nil, false))
local breakout = WindowManager.breakout
assert(breakout and breakout.frame.name == "QUI_DamageMeterBreakout")
assert(breakout.sections.players.rows[1]._source == sources[1])
assert(breakout.sections.spells.rows[1]._spellID == 11)
assert(breakdownLimit == 40)
local playerRow = breakout.sections.players.rows[1]
playerRow.scripts.OnEnter(playerRow)
assert(hoveredPlayerRow == playerRow)
playerRow.scripts.OnLeave(playerRow)
assert(hoveredPlayerRow == nil)
local firstSpellView = breakout.currentSpellView
local firstSegmentEntry = breakout.sections.segments.rows[1]._segment
breakout:Refresh()
assert(breakout.currentSpellView == firstSpellView)
assert(breakout.sections.segments.rows[1]._segment == firstSegmentEntry)
assert(breakout.sections.targets.rows[1].shown)
local targetRow = breakout.sections.targets.rows[1]
targetRow.scripts.OnClick(targetRow, "LeftButton")
assert(breakout.selectedTarget == targets[1])
assert(breakout.sections.spells.rows[1]._spellID == 22)
assert(breakout.sections.spells.title.text == "Spells: Target")
targetRow.scripts.OnClick(targetRow, "LeftButton")
assert(breakout.selectedTarget == nil and breakout.sections.spells.rows[1]._spellID == 11)
targetRow.scripts.OnClick(targetRow, "LeftButton")
local selectedTarget = targets[1]
for i = 1, 20 do
    targets[i] = {
        name = "Higher Target " .. i,
        sourceGUID = "Creature-Higher-" .. i,
        sourceCreatureID = 100 + i,
        totalAmount = 1000 - i,
        amountPerSecond = 100 - i,
    }
end
targets[21] = selectedTarget
breakout:Refresh()
assert(breakout.selectedTarget == nil and breakout.sections.spells.rows[1]._spellID == 11,
    "target filtering should clear when the selected target leaves the visible rows")
targets = { selectedTarget }
breakout:Refresh()
breakout.frame:SetSize(980, 540)
breakout.frame.scripts.OnSizeChanged(breakout.frame, 980, 540)
local savedLayout = env._G.QUI.db.profile.damageMeter.native.breakoutLayout
assert(savedLayout.width == 980 and savedLayout.height == 540)
breakout:Close()
assert(WindowManager:OpenBreakout(ownerOne, sources[1], "Player-One", nil, false))
assert(breakout.frame.width == 980 and breakout.frame.height == 540)
assert(#env._G.UISpecialFrames == 1 and env._G.UISpecialFrames[1] == "QUI_DamageMeterBreakout")

assert(WindowManager:OpenBreakout(ownerTwo, sources[2], "Player-Two", nil, false))
assert(WindowManager.breakout == breakout and breakout.ownerWindow == ownerTwo)
assert(breakout.sections.players.rows[1].height == 24)
local secretGUID = {}
ns.Helpers.IsSecretValue = function(value) return value == secretGUID end
sources[1].sourceGUID = secretGUID
sources[2].sourceGUID = secretGUID
sources[3] = { name = "Same Spec", sourceGUID = secretGUID, specIconID = 202,
    totalAmount = 25, amountPerSecond = 2.5 }
breakout.source = sources[2]
breakout:Refresh()
assert(breakout.source == sources[2])
local newLayout = {
    width = 1000, height = 560,
    leftWidth = 230, middleWidth = 510, playersHeight = 350, spellsHeight = 380,
}
env._G.QUI.db.profile.damageMeter.native.breakoutLayout = newLayout
breakout:Refresh()
assert(breakout.layout == newLayout)
assert(breakout.frame.width == 1000 and breakout.frame.height == 560)
availableSessions[1] = { sessionID = 77, name = "Prior Segment", durationSeconds = 60 }
sources[2].specIconID = 0
historicalSources[1] = { name = "Unrelated", sourceGUID = "Player-Unrelated", specIconID = 303,
    totalAmount = 10, amountPerSecond = 1 }
breakout:Refresh()
local historicalSegmentEntry = breakout.sections.segments.rows[3]._segment
breakout:Refresh()
assert(breakout.sections.segments.rows[3]._segment == historicalSegmentEntry)
assert(breakout.sections.segments.rows[3].Name.text == "Prior Segment"
    and breakout.sections.segments.rows[3].Value.text == "1:00")
assert(breakout.sections.comparison.title.text == "Comparison: Current")
breakout.sessionType = 0
breakout.sessionID = nil
breakout.sessionLabel = nil
breakout:Refresh()
assert(breakout.sections.comparison.title.text == "Comparison: Overall")
breakout.sessionID = 77
breakout.sessionLabel = "Prior Segment"
breakout:Refresh()
assert(breakout.sections.comparison.title.text == "Comparison: Prior Segment")
breakout.sessionType = 1
breakout.sessionID = nil
breakout.sessionLabel = nil
breakout.source = sources[2]
local beforeBreakdownFetches = breakdownFetches
local beforeSessionFetches = sessionFetches
local beforeSegmentLabelBuilds = segmentLabelBuilds
local beforeSegmentDurationBuilds = segmentDurationBuilds
local beforeComparisonFormats = comparisonFormats
local beforeTableConcats = tableConcats
Data._inCombat = true
breakout:Refresh()
assert(sessionFetches == beforeSessionFetches)
assert(breakdownFetches == beforeBreakdownFetches + 1)
assert(segmentLabelBuilds == beforeSegmentLabelBuilds
    and segmentDurationBuilds == beforeSegmentDurationBuilds)
assert(comparisonFormats == beforeComparisonFormats and tableConcats == beforeTableConcats)
assert(breakout.sections.comparison.title.text == "Comparison: Current"
    and breakout.sections.comparison.rows[1].Value.text == "rendered 100")
local cachedHistoricalEntry = breakout.sections.segments.rows[3]._segment
WindowManager:CloseBreakoutForOwner(ownerTwo)
assert(not breakout:IsShown())
assert(WindowManager:OpenBreakout(ownerTwo, sources[2], "Player-Two", nil, false))
assert(breakout.sections.segments.rows[3].shown
    and breakout.sections.segments.rows[3]._segment == cachedHistoricalEntry
    and breakout.sections.segments.rows[3].Name.text == "Prior Segment"
    and breakout.sections.segments.rows[3].Value.text == "1:00")
assert(sessionFetches == beforeSessionFetches
    and segmentLabelBuilds == beforeSegmentLabelBuilds
    and segmentDurationBuilds == beforeSegmentDurationBuilds)
breakout.sessionType = 0
breakout:Refresh()
assert(comparisonFormats == beforeComparisonFormats and tableConcats == beforeTableConcats)
assert(breakout.sections.comparison.title.text == "Comparison: Overall")
breakout.sessionType = 1
Data._inCombat = false
local beforeChangedSegmentBuilds = segmentLabelBuilds
availableSessions[1].name = "Renamed Segment"
availableSessions[1].durationSeconds = 120
breakout:Refresh()
assert(segmentLabelBuilds == beforeChangedSegmentBuilds + 1
    and breakout.sections.segments.rows[3].Name.text == "Renamed Segment"
    and breakout.sections.segments.rows[3].Value.text == "2:00")
env._G.QUI.db.profile.damageMeter.native.combineAbsorbsIntoHealing = true
breakout.damageMeterType = env.Enum.DamageMeterType.HealingDone
breakout:Refresh()
assert(combinedBreakdownLimit == 40)
WindowManager:CloseBreakoutForOwner(ownerOne)
assert(breakout:IsShown())
WindowManager:CloseBreakoutForOwner(ownerTwo)
assert(not breakout:IsShown() and breakout.ownerWindow == nil)

print("OK: damage_meter_modern_breakout_test")
