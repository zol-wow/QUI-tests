local Secret = dofile("tests/helpers/secret_sentinel.lua")
local Instrument = dofile("tests/helpers/secret_instrument.lua")
local restore = Secret.InstallSecretStub()
local secretLevel = Secret.MakeSecretSentinel()
local state = { level = 63, effectiveLevel = 63, exists = true, calls = 0 }
local settings = { showLevel = true, levelTextColor = { 0.2, 0.4, 0.6, 0.7 } }
local ns = {}
local env = setmetatable({
    LibStub = function() end,
    UnitLevel = function() return state.level end,
    UnitEffectiveLevel = function() return state.effectiveLevel end,
    UnitExists = function() return state.exists end,
    GetUnitSettings = function() return settings end,
    QUI_UF = { GetFrameUnit = function(frame) return frame.unitKey end },
}, { __index = _G })

local function NativeColor(level)
    state.calls = state.calls + 1
    assert(not issecretvalue(level), "restricted levels must never enter the native color lookup")
    state.queriedLevel = level
    if state.colorError then error("player effective level is restricted") end
    return state.nativeColor or { r = 1, g = 0.5, b = 0 }
end
env.GetCreatureDifficultyColor = NativeColor

local utils = assert(Instrument.loadFile("core/utils.lua"))
setfenv(utils, env)
utils("QUI", ns)
env.Helpers = ns.Helpers
env.IsSecretValue = ns.Helpers.IsSecretValue
env.SafeValue = ns.Helpers.SafeValue

local file = assert(io.open("QUI_UnitFrames/unitframes/unitframes.lua", "rb"))
local source = file:read("*a")
file:close()
local function Slice(first, last)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(last, start + #first, true), last)
    return source:sub(start, finish - 1)
end
local body = Slice("local function FormatUnitLevelText(", "local TruncateName =")
    .. Slice("local function UpdateLevelText(", "local function UpdateFrame(")
local chunk = assert(Instrument.loadString(body .. "\nreturn UpdateLevelText", "unit frame level colors"))
setfenv(chunk, env)
local update = chunk()
local text = {}
function text:SetText(value) self.value = value end
function text:SetTextColor(...) self.color = { ... } end
function text:Show() self.shown = true end
function text:Hide() self.shown = false end
local frame = { unitKey = "target", levelText = text }

local function CheckColor(expected, label)
    for i = 1, 4 do
        assert(rawequal(text.color[i], expected[i]), label .. ": wrong color channel " .. i)
    end
end
local custom = { 0.2, 0.4, 0.6, 0.7 }
update(frame)
CheckColor(custom, "existing settings retain custom color")
assert(state.calls == 0, "disabled difficulty color must avoid native lookup")

settings.levelDifficultyColor = true
update(frame)
CheckColor({ 1, 0.5, 0, 0.7 }, "enabled difficulty color must paint native RGB and preserve opacity")
assert(state.queriedLevel == 63 and text.value == "63" and text.shown)

state.level, state.effectiveLevel = 90, 63
update(frame)
assert(state.queriedLevel == 63 and text.value == "63",
    "scaled mobs must display and color their effective level")

state.level, state.effectiveLevel = -1, -1
update(frame)
assert(text.value == "??" and text.shown, "unknown boss level must keep its label")
CheckColor({ 1, 0.1, 0.1, 0.7 }, "unknown boss level uses danger red")

state.level, state.effectiveLevel = 63, 63
state.colorError = true
update(frame)
CheckColor(custom, "native color failure falls back to custom color")
state.colorError = false
env.GetCreatureDifficultyColor = nil
update(frame)
CheckColor(custom, "unavailable native color lookup falls back to custom color")
env.GetCreatureDifficultyColor = NativeColor

settings.levelDifficultyColor = false
update(frame)
CheckColor(custom, "disabling difficulty color restores custom color")
settings.levelDifficultyColor = true

for _, level in ipairs({ secretLevel, 0, false }) do
    state.level, state.effectiveLevel = level, level
    local before = state.calls
    update(frame)
    assert(not text.shown, "unavailable levels must not show stale text")
    assert(state.calls == before, "unavailable levels must avoid native difficulty arithmetic")
end
state.level, state.effectiveLevel = nil, nil
update(frame)
assert(not text.shown, "missing levels must hide stale text")

for _, level in ipairs({ secretLevel, 0, false }) do
    text.color = { ns.Helpers.GetLevelTextColor(settings, level) }
    CheckColor(custom, "invalid color input keeps custom fallback")
end
text.color = { ns.Helpers.GetLevelTextColor(settings, nil) }
CheckColor(custom, "missing color input keeps custom fallback")

state.level, state.effectiveLevel = 63, 63
state.exists = false
update(frame)
assert(not text.shown and text.value == "", "lost target clears its level")
state.exists = true
settings.showLevel = false
update(frame)
assert(not text.shown, "show-level setting still owns visibility")

settings.showLevel = true
update(frame)
local eventFrame = { events = {} }
function eventFrame:RegisterEvent(event) self.events[event] = true end
function eventFrame:SetScript(_, callback) self.callback = callback end
env.CreateFrame = function() return eventFrame end
env.UpdateLevelText = update
env.QUI_UF.frames = { target = frame }
env.QUI_UF.previewMode = {}
local events = assert(Instrument.loadString(Slice('local initFrame = CreateFrame("Frame")',
    "_G.QUI_RefreshUnitFrames = function"), "unit frame player level event"))
setfenv(events, env)
events()
state.nativeColor = { r = 0.2, g = 0.8, b = 0.2 }
eventFrame.callback(eventFrame, "PLAYER_LEVEL_CHANGED", 60, 61, true)
CheckColor({ 0.2, 0.8, 0.2, 0.7 }, "player level change must recolor the current target")
assert(eventFrame.events.PLAYER_LEVEL_CHANGED, "player-level refresh must be registered")

env.QUI_UF.previewMode.target = true
state.nativeColor = { r = 1, g = 0.1, b = 0.1 }
eventFrame.callback(eventFrame, "PLAYER_LEVEL_CHANGED", 61, 62, true)
CheckColor({ 0.2, 0.8, 0.2, 0.7 }, "player level change must preserve preview samples")

local noop = function() end
local boss = {
    unitKey = "boss",
    levelText = text,
    healthBar = { SetMinMaxValues = noop, SetValue = noop, SetStatusBarColor = noop },
    Show = noop,
}
env.QUI_UF.frames = { boss1 = boss }
env.QUI_UF.previewMode = {}
env.QUI_UF.auraPreviewMode = {}
env.QUI_UF.RefreshFrame = function() update(boss) end
env.GetGeneralSettings = function() return {} end
env.InCombatLockdown = function() return false end
env.UnregisterStateDriver = noop
local preview = assert(Instrument.loadString(Slice("function QUI_UF:ShowPreview(",
    "function QUI_UF:HidePreview("), "unit frame initial boss preview"))
setfenv(preview, env)
preview()
state.exists = false
env.QUI_UF:ShowPreview("boss")
assert(text.shown and text.value == "??", "first boss preview must show level without a live boss")
CheckColor({ 1, 0.1, 0.1, 0.7 }, "first boss preview must use difficulty color")
settings.levelDifficultyColor = false
env.QUI_UF:ShowPreview("boss")
CheckColor(custom, "boss preview must restore custom color when disabled")
settings.showLevel = false
env.QUI_UF:ShowPreview("boss")
assert(not text.shown, "boss preview must respect hidden level text")

Secret.RestoreSecretStub(restore)
print("OK unitframes_level_difficulty_color_test")
