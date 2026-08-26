-- Run: lua tests/unit/keybind_global_sweep_skips_nonwidgets_test.lua

local function noop() end

function wipe(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local secretValue = {}
function issecretvalue(value) return value == secretValue end
local inCombat = false
function InCombatLockdown() return inCombat end
local now = 2
function GetTime() return now end
function GetSpecialization() return nil end
function GetSpecializationInfo() return nil end
function GetInventoryItemID() return nil end
function GetMacroInfo() return nil end
function GetMacroSpell() return nil end
function GetActionText() return nil end
local actionInfoCalls = 0
function GetActionInfo(action)
    actionInfoCalls = actionInfoCalls + 1
    if action == 7 then return "spell", 4242 end
    if action == 8 then return "spell", 5252 end
    return nil
end

UIParent = {}
C_Item = { GetItemInfo = function() return nil end }
C_Spell = { GetSpellInfo = function(id) return { name = "Spell " .. tostring(id) } end }
local timers = {}
C_Timer = {
    After = noop,
    NewTimer = function(delay, callback)
        local timer = { delay = delay, callback = callback, cancelled = false }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}
C_Widget = {
    IsFrameWidget = function(object)
        return type(object) == "table" and rawget(object, "isFrameWidget") == true
    end,
}

local frames = {}
local methodHooks = setmetatable({}, { __mode = "k" })
function hooksecurefunc(target, method, callback)
    methodHooks[target] = methodHooks[target] or {}
    methodHooks[target][method] = callback
end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:SetAllPoints() end
    function frame:CreateFontString() return { SetFont = noop, SetText = noop, Hide = noop, Show = noop } end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:Hide() end
    function frame:Show() end
    frames[#frames + 1] = frame
    return frame
end

local hostileTouches = 0
local hostileMeta = {}
hostileMeta.__index = function(_, key)
    if type(key) ~= "string" then return nil end
    return function()
        hostileTouches = hostileTouches + 1
        error("attempt to index field 'label' (a nil value)", 2)
    end
end

_G.ForeignWidgetWrapper = setmetatable({ type = "label", dframework = true }, hostileMeta)

local opieEditorGetActionCalls = 0
_G.ABE_MacroInput = {
    isFrameWidget = true,
    GetObjectType = function() return "EditBox" end,
    GetAction = function(_, into)
        opieEditorGetActionCalls = opieEditorGetActionCalls + 1
        into[1], into[2] = "imptext", ""
    end,
}

local actionButton = {
    isFrameWidget = true,
    action = 7,
    HotKey = { GetText = function() return "F" end },
    GetName = function() return "QUI_Bar1Button1" end,
    GetObjectType = function() return "CheckButton" end,
    SetButtonState = noop,
    HookScript = function(self, script, callback)
        self.hooks = self.hooks or {}
        self.hooks[script] = callback
    end,
}
_G.QUI_Bar1Button1 = actionButton

local reportedErrors = {}

local core = {
    db = {
        profile = {
            keybindOverridesEnabledCDM = true,
            viewers = { EssentialCooldownViewer = { showKeybinds = false } },
            ncdm = {
                enabled = true,
                essential = { enabled = false, pressedEffect = "qui" },
                utility = { enabled = false, pressedEffect = "off" },
                buff = { enabled = true, pressedEffect = "qui" },
                containers = {},
            },
        },
        char = { keybindOverrides = { [0] = {} } },
    },
}

local addon = {
    QUICore = core,
    SafeCall = function(_policy, fn, ...)
        local ok, a, b = pcall(fn, ...)
        if not ok then reportedErrors[#reportedErrors + 1] = a end
        return ok, a, b
    end,
    SafeCallMethod = function(_policy, obj, name, ...) return pcall(obj[name], obj, ...) end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...)
        if obj == nil then return nil end
        local m = obj[name]
        if m == nil then return nil end
        return pcall(m, obj, ...)
    end,
    Helpers = {
        GetCore = function() return core end,
        GetCurrentSpecID = function() return nil end,
        CanAccessTable = function() return true end,
        CanAccessValue = function() return true end,
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
        GetGeneralFont = function() return "Fonts\\FRIZQT__.TTF" end,
        GetGeneralFontOutline = function() return "OUTLINE" end,
    },
    FormatKeybind = function(binding) return binding end,
}

local pressedEvents = {}
local preparedButtons = {}
addon._OwnedHighlighter = {
    OnActionButtonState = function(button, candidates, down)
        pressedEvents[#pressedEvents + 1] = {
            button = button,
            candidates = candidates,
            down = down,
        }
    end,
    PrepareActionButton = function(button) preparedButtons[button] = true end,
}

_G.QUI = addon

assert(loadfile("modules/utility/keybinds.lua"))("QUI", addon)

addon.Keybinds.RebuildCache()

assert(not actionButton.hooks and not methodHooks[actionButton] and not preparedButtons[actionButton],
    "stale Buff Icon pressed-effect settings must not activate action-button hooks")

core.db.profile.ncdm.essential.enabled = true
addon.Keybinds.RebuildCache()

assert(actionButton.hooks and actionButton.hooks.OnClick,
    "cooldown-icon pressed effects must hook action-button click state when keybind text is disabled")
assert(methodHooks[actionButton] and methodHooks[actionButton].SetButtonState,
    "cooldown-icon pressed effects must hook action-button pushed state when keybind text is disabled")
assert(preparedButtons[actionButton] == true,
    "action-button rebuilds must prepare reusable pressed-effect state out of combat")

methodHooks[actionButton].SetButtonState(actionButton, "PUSHED")
methodHooks[actionButton].SetButtonState(actionButton, "NORMAL")
actionButton.hooks.OnClick(actionButton, "LeftButton", true)
actionButton.hooks.OnClick(actionButton, "LeftButton", false)

assert(#pressedEvents == 4 and pressedEvents[1].down == true and pressedEvents[2].down == false,
    "pushed and normal states must dispatch held-state transitions")
assert(pressedEvents[1].button == actionButton and pressedEvents[1].candidates[4242] == true,
    "pressed-state dispatch must use the out-of-combat spell candidate cache")

assert(hostileTouches == 0,
    "the pairs(_G) sweep must not call methods on non-widget globals (ran foreign code " ..
    hostileTouches .. " time(s))")
assert(opieEditorGetActionCalls == 0,
    "the pairs(_G) sweep must not call OPie editor GetAction methods")
assert(#reportedErrors == 0,
    "the sweep must not surface third-party errors: " .. tostring(reportedErrors[1]))
assert(addon.Keybinds.GetKeybindForSpell(4242) == "F",
    "the sweep must still collect real action-button widgets from _G")

local eventFrame
for _, frame in ipairs(frames) do
    if frame.events.ACTIONBAR_SLOT_CHANGED then
        eventFrame = frame
        break
    end
end
assert(eventFrame and eventFrame.scripts.OnEvent,
    "the keybind cache must listen for action-slot changes")
for _, event in ipairs({
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_STEALTH",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_POSSESS_BAR",
    "UPDATE_MACROS",
}) do
    assert(eventFrame.events[event], event .. " must invalidate pressed spell identities")
end

methodHooks[actionButton].SetButtonState(actionButton, "PUSHED")
actionButton.action = 8
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "ACTIONBAR_PAGE_CHANGED")
assert(pressedEvents[#pressedEvents].down == false,
    "combat action remaps must release the old pressed mapping")
methodHooks[actionButton].SetButtonState(actionButton, "PUSHED")
assert(pressedEvents[#pressedEvents].candidates[5252] == true,
    "combat action remaps must use the precomputed destination-slot identity")
actionButton.action = secretValue
eventFrame.scripts.OnEvent(eventFrame, "ACTIONBAR_PAGE_CHANGED")
assert(pressedEvents[#pressedEvents].down == false,
    "secret combat remaps must release the last readable pressed mapping")
methodHooks[actionButton].SetButtonState(actionButton, "PUSHED")
assert(pressedEvents[#pressedEvents].candidates == nil,
    "secret combat remaps must fail closed instead of reusing a stale identity")
methodHooks[actionButton].SetButtonState(actionButton, "NORMAL")
inCombat = false
actionButton.action = 7

local callsBeforeRefresh = actionInfoCalls
eventFrame.scripts.OnEvent(eventFrame, "ACTIONBAR_SLOT_CHANGED")
now = 2.4
eventFrame.scripts.OnEvent(eventFrame, "ACTIONBAR_SLOT_CHANGED")
assert(#timers == 1 and not timers[1].cancelled,
    "action-slot bursts must retain one pending timer")
now = 2.5
timers[1].callback()
assert(#timers == 2 and actionInfoCalls == callsBeforeRefresh
    and timers[2].delay > 0.39 and timers[2].delay < 0.41,
    "an early timer must wait out the remaining quiet period without rebuilding")
now = 3
timers[2].callback()
assert(actionInfoCalls > callsBeforeRefresh,
    "the debounced action-slot refresh must rebuild the keybind cache")

methodHooks[actionButton].SetButtonState(actionButton, "PUSHED")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
assert(pressedEvents[#pressedEvents].down == false,
    "entering-world invalidation must release a held pressed effect before its delayed rebuild")
methodHooks[actionButton].SetButtonState(actionButton, "PUSHED")
assert(pressedEvents[#pressedEvents].candidates == nil,
    "entering-world invalidation must suppress stale candidates during its delay")

print("OK: keybind_global_sweep_skips_nonwidgets_test")
