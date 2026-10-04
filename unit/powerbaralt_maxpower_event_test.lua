local function noop() end
local methods = {}
for _, key in ipairs({ "SetSize", "SetPoint", "SetFrameLevel", "SetStatusBarTexture", "SetStatusBarColor",
    "SetMovable", "SetClampedToScreen", "EnableMouse", "SetJustifyH", "SetTextColor" }) do methods[key] = noop end
local function widget()
    return setmetatable({ events = {}, scripts = {} }, { __index = methods })
end
function methods:CreateFontString() return widget() end
function methods:GetFrameLevel() return 2 end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:RegisterUnitEvent(event, unit) self.events[event] = unit end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetValue(value) self.value = value end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetText(value) self.text = value end
function methods:IsShown() return self.shown end
function methods:SetAlpha(value) self.alpha = value end
local state = { maximum = 100, time = 100, timers = {} }
local env = setmetatable({}, { __index = _G })
env._G = env
env.Enum = { PowerType = { Alternate = 10 } }
env.UIParent = widget()
env.C_Timer = { After = function(_, callback) callback() end }
env.GetUnitPowerBarInfo = function(unit) return { minPower = 0, barType = unit == 4 and 4 or 0 } end
env.GetUnitPowerBarStrings = function() return "Power", "Description" end
env.UnitPower = function() return 25 end
env.UnitPowerMax = function() return state.maximum end
env.GetTime = function() return state.time end
env.floor = math.floor
env.UnitPowerBarTimerInfo = function(_, index)
    local timer = state.timers[index]
    if timer then return timer.duration, timer.expiration, timer.barID, timer.auraID end
end
env.CreateFrame = function(_, name, _, template)
    local frame = widget()
    if template == "UnitPowerBarAltTemplate" then
        frame.frame, frame.background, frame.fill = widget(), widget(), widget()
        frame.statusFrame = { text = widget() }
    elseif template == "UnitPowerBarAltCounterTemplate" then
        frame.BG, frame.BGL, frame.BGR, frame.artTop, frame.artBottom = widget(), widget(), widget(), widget(), widget()
    end
    if name then env[name] = frame end
    return frame
end
local nativeChunk = assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitPowerBarAlt.lua"))
setfenv(nativeChunk, env)
nativeChunk()
env.UnitPowerBarAlt_SetUp, env.UnitPowerBarAlt_TearDown, env.CounterBar_SetStyleForUnit = noop, noop, noop
env.UnitPowerBarAlt_SetMinMaxPower = function(frame, _, maximum) frame.maximum = maximum end
env.UnitPowerBarAlt_SetPower = function(frame, value) frame.nativeValue = value end
env.CounterBar_UpdateCount = function(frame, value) frame.nativeValue = value end
env.hooksecurefunc = function(name, callback)
    local original = assert(env[name])
    env[name] = function(...) original(...); callback(...) end
end
local core = { db = { profile = { general = { skinPowerBarAlt = true } } } }
local ns = {
    WhenLoggedIn = function(callback) callback() end,
    RunAfterFirstFrame = function(callback) callback() end,
    Helpers = { GetCore = function() return core end, IsSecretValue = function() return false end,
        SetFrameBackdropColor = function(frame, ...) frame.skinBackground = { ... } end,
        SetFrameBackdropBorderColor = function(frame, ...) frame.skinBorder = { ... } end },
    SkinBase = { GetSkinColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end,
        SetExpandedPixelPoints = noop, ApplyPixelBackdrop = function(frame) frame.skinBackdrop = true end,
        SkinFontString = function(frame) frame.skinFont = true end,
        SetFrameData = noop, MarkSkinned = noop },
}
local chunk = assert(loadfile(arg[1] or "modules/skinning/gameplay/powerbaralt.lua"))
setfenv(chunk, env)
chunk("QUI", ns)
local bar = assert(env.QUI_AltPowerBar)
assert(bar.events.UNIT_MAXPOWER == "player", "replacement must register native alternate-power maximum changes")
assert(bar.maximum == 100 and bar.text.text == "Power: 25%")
state.maximum = 50
bar.scripts.OnEvent(bar, "UNIT_MAXPOWER", "party1", "ALTERNATE")
assert(bar.maximum == 100, "foreign unit maximum changes must be ignored")
bar.scripts.OnEvent(bar, "UNIT_MAXPOWER", "player", "MANA")
assert(bar.maximum == 100, "ordinary power maximum changes must be ignored")
bar.scripts.OnEvent(bar, "UNIT_MAXPOWER", "player", "ALTERNATE")
assert(bar.maximum == 50 and bar.text.text == "Power: 50%", "native alternate maximum event must update range and percentage")
state.timers = {
    { duration = 60, expiration = 160, barID = 1, auraID = 1 },
    { duration = 30, expiration = 130, barID = 4, auraID = 2 },
}
env.PlayerBuffTimerManager_UpdateTimers({})
local ordinary, counter = assert(env.BuffTimer1), assert(env.BuffTimer2)
assert(ordinary.skinBackdrop and counter.skinBackdrop and ordinary.statusFrame.text.skinFont,
    "new native ordinary and counter buff timers must receive QUI skins")
assert(ordinary.frame.alpha == 0 and counter.BG.alpha == 0 and ordinary.fill.alpha == nil,
    "skin must hide native timer chrome while preserving native fill and counter digits")
assert(ordinary.scripts.OnUpdate == env.PlayerBuffTimer_OnUpdate and counter.scripts.OnUpdate == env.PlayerBuffTimer_OnUpdate,
    "skin must preserve the native timer engine")
state.time = 115
ordinary.scripts.OnUpdate(ordinary, 0.01)
counter.scripts.OnUpdate(counter, 0.01)
assert(ordinary.nativeValue == 45 and counter.nativeValue == 15, "native countdowns must remain operational after skinning")
state.timers = {}
env.PlayerBuffTimerManager_UpdateTimers({})
assert(not ordinary:IsShown() and not counter:IsShown(), "native manager must still hide expired timer objects")
state.timers = { { duration = 10, expiration = 125, barID = 1, auraID = 3 } }
env.PlayerBuffTimerManager_UpdateTimers({})
assert(env.BuffTimer1 == ordinary and ordinary:IsShown() and ordinary.skinBackdrop, "reused native timer must retain skin and lifecycle")
print("OK: powerbaralt_maxpower_event_test")
