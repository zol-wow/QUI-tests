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
local availableSessions = {}
local historicalSources = {}
local Data = { _inCombat = false }
function Data:GetView(_, _, sessionID)
    return { sources = sessionID and historicalSources or sources, maxAmount = 100 }
end
function Data:GetCombinedHealingView() return self:GetView() end
function Data:GetBreakdownView() return { spells = spells, maxAmount = 100, totalAmount = 100 } end
function Data:GetCombinedHealingBreakdown() return self:GetBreakdownView() end
function Data:GetPlayerTargets() return { { name = "Target", totalAmount = 100, amountPerSecond = 10 } } end
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

local Breakdown = {}
Breakdown.__index = Breakdown
function Breakdown:_SetSpellRow(row, spell) row._spellID = spell.spellID end
function Breakdown:_SetTargetRow(row) row._spellID = nil end
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
    BuildPreviousSessionLabel = function(value) return value.name end,
    FormatDuration = function() return "" end,
    FormatNumber = function(value) return tostring(value) end,
    ShortenName = function(value) return value end,
    LabelForSession = function(value) return value == 1 and "Current" or "Overall" end,
    LabelForType = function() return "Damage Done" end,
    MeterTypes = { 1, 2 },
    GetDeathRecapRows = function() return {}, 1 end,
}

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
    C_DamageMeter = { GetAvailableCombatSessions = function() return availableSessions end },
    InCombatLockdown = function() return false end,
    GameTooltip = widget(),
}
setmetatable(env, { __index = _G })
local loader = assert(loadfile("QUI_DamageMeter/damage_meter/breakout.lua"))
setfenv(loader, env)
loader("QUI_DamageMeter", ns)

local ownerOne = { windowID = 1, sessionType = 1, damageMeterType = 1 }
local ownerTwo = { windowID = 2, sessionType = 1, damageMeterType = 1 }
WindowManager.windows[1] = ownerOne
WindowManager.windows[2] = ownerTwo

assert(WindowManager:OpenBreakout(ownerOne, sources[1], "Player-One", nil, false))
local breakout = WindowManager.breakout
assert(breakout and breakout.frame.name == "QUI_DamageMeterBreakout")
assert(breakout.sections.players.rows[1]._source == sources[1])
assert(breakout.sections.spells.rows[1]._spellID == 11)
assert(breakout.sections.targets.rows[1].shown)
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
local newLayout = { leftWidth = 230, middleWidth = 510, playersHeight = 350, spellsHeight = 380 }
env._G.QUI.db.profile.damageMeter.native.breakoutLayout = newLayout
breakout:Refresh()
assert(breakout.layout == newLayout)
availableSessions[1] = { sessionID = 77, name = "Prior Segment" }
sources[2].specIconID = 0
historicalSources[1] = { name = "Unrelated", sourceGUID = "Player-Unrelated", specIconID = 303,
    totalAmount = 10, amountPerSecond = 1 }
breakout:Refresh()
assert(breakout.sections.comparison.title.text == "Comparison: Current")
WindowManager:CloseBreakoutForOwner(ownerOne)
assert(breakout:IsShown())
WindowManager:CloseBreakoutForOwner(ownerTwo)
assert(not breakout:IsShown() and breakout.ownerWindow == nil)

print("OK: damage_meter_modern_breakout_test")
