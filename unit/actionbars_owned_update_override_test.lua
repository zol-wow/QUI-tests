-- tests/unit/actionbars_owned_update_override_test.lua
-- Run: lua tests/unit/actionbars_owned_update_override_test.lua
--
-- Owned buttons replace ActionBarActionButtonMixin:Update, because Blizzard's
-- version reaches ActionButton_UpdateCooldown (secret SetCooldown) and
-- UpdatePressAndHoldAction (protected SetAttribute) on a frame QUI created.
-- A replacement is only safe if it still performs the parts of Blizzard's
-- Update that QUI has no equivalent for: UpdateTypeOverlay/ClearTypeOverlay
-- (:574/:590) and UpdateHighlightMark (:577). UpdateSpellAlert and
-- UpdateSpellHighlightMark are deliberately NOT called -- ActionBarsOwned
-- .UpdateOverlayGlow and UpdateSpellHighlight already own those surfaces and
-- would double-render.
--
-- The assisted-rotation swirl frame carries a Lua OnUpdate that calls
-- OnActionBarSlotChanged every tick. QUI must neuter it wherever the frame
-- comes from: ActionBarActionButtonMixin:UpdateAssistedCombatRotationFrame
-- (ActionButton.lua:895) creates the same frame from UpdateAction:542, one
-- line ABOVE the Update() call the override replaces.

local actionBarsDB = {
    enabled = true,
    global = {},
    bars = {},
}

local function noop() end

local pingUpdateCounts = {}

local frameMT
local function NewFrame()
    local frame = {
        attributes = {},
        scripts = {},
        frameRefs = {},
        shown = false,
        frameLevel = 1,
    }
    frameMT = frameMT or {
        __index = function(_, key)
            if key == "SetAttribute" then
                return function(self, name, value) self.attributes[name] = value end
            elseif key == "GetAttribute" then
                return function(self, name) return self.attributes[name] end
            elseif key == "SetScript" then
                return function(self, script, handler) self.scripts[script] = handler end
            elseif key == "GetScript" then
                return function(self, script) return self.scripts[script] end
            elseif key == "HookScript" then
                return function(self, script, handler) self.scripts[script] = handler end
            elseif key == "SetFrameRef" then
                return function(self, name, ref) self.frameRefs[name] = ref end
            elseif key == "GetFrameRef" then
                return function(self, name) return self.frameRefs[name] end
            elseif key == "Show" then
                return function(self) self.shown = true end
            elseif key == "Hide" then
                return function(self) self.shown = false end
            elseif key == "IsShown" then
                return function(self) return self.shown end
            elseif key == "GetFrameLevel" then
                return function(self) return self.frameLevel end
            elseif key == "SetFrameLevel" then
                return function(self, level) self.frameLevel = level end
            elseif key == "GetParent" then
                return function(self) return self.parent end
            elseif key == "SetParent" then
                return function(self, parent) self.parent = parent end
            elseif key == "CreateTexture" or key == "CreateFontString" then
                return function() return NewFrame() end
            elseif key == "UpdatePingAttributes" then
                return function(self) pingUpdateCounts[self] = (pingUpdateCounts[self] or 0) + 1 end
            end
            return noop
        end,
    }
    return setmetatable(frame, frameMT)
end

UIParent = NewFrame()
SlashCmdList = {}
BINDING_HEADER_QUI_ACTIONBARS = ""
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
RANGE_INDICATOR = ""

function GetBuildInfo()
    return "12.0.5", "66562", "May 1 2026", 120005
end

-- Blizzard's virtual templates bind OnUpdate by <OnUpdate method="OnUpdate"/>;
-- the swirl template is virtual, not intrinsic, so the binding is an ordinary
-- script that GetScript reports and SetScript can clear.
local function templateOnUpdate() end

function CreateFrame(_, _, parent, template)
    local frame = NewFrame()
    frame.parent = parent
    if template and template:find("AssistedCombatRotation", 1, true) then
        frame.scripts.OnUpdate = templateOnUpdate
    end
    return frame
end

local testInCombat = false
function InCombatLockdown() return testInCombat end
function GetTime() return 1 end
function HasAction(action) return action ~= nil and action > 0 end
function RegisterStateDriver() end
function UnregisterStateDriver() end
function LibStub() return nil end
function GetCVar() return "0" end
function hooksecurefunc() end

local tickers = {}
C_Timer = {
    After = function(_, callback) if callback then callback() end end,
    NewTicker = function(seconds, callback)
        local ticker = { seconds = seconds, callback = callback, cancelled = false }
        ticker.Cancel = function(self) self.cancelled = true end
        tickers[#tickers + 1] = ticker
        return ticker
    end,
}

ActionBarButtonEventsFrame = { frames = {} }
ActionBarActionEventsFrame = { frames = {} }
function ActionBarActionEventsFrame:RegisterFrame(frame) self.frames[frame] = frame end
function ActionBarActionEventsFrame:UnregisterFrame(frame) self.frames[frame] = nil end

local assistedSlots = {}
AssistedCombatManager = { updateRate = 0.25 }
function AssistedCombatManager:GetUpdateRate() return self.updateRate or 0 end

local actionInfoBySlot = {}
local overlayedSpells = {}
local overrideSpells = {}
local flyoutSpells = {}
local flyoutSlots = {}
local spellSlots = {}
local nextCastSpell
local physicalGlows = {}
local glowOpts = {}

function GetActionInfo(slot)
    local info = actionInfoBySlot[slot]
    if info then return unpack(info) end
end

function FlyoutHasSpell(flyoutID, spellID)
    return flyoutSpells[flyoutID] and flyoutSpells[flyoutID][spellID] == true
end

function GetFlyoutInfo(flyoutID)
    local slots = flyoutSlots[flyoutID]
    if slots then return nil, nil, #slots, true end
end

function GetFlyoutSlotInfo(flyoutID, slot)
    local info = flyoutSlots[flyoutID] and flyoutSlots[flyoutID][slot]
    if info then return info[1], info[2], true end
end

C_Spell = {
    GetOverrideSpell = function(spellID) return overrideSpells[spellID] or spellID end,
}

C_SpellActivationOverlay = {
    IsSpellOverlayed = function(spellID) return overlayedSpells[spellID] == true end,
}

local ns = {
    SafeCall = function(_policy, fn, ...) return pcall(fn, ...) end,
    SafeCallMethod = function(_policy, obj, name, ...)
        return pcall(function(...) return obj[name](obj, ...) end, ...)
    end,
    SafeCallMethodIfPresent = function(_policy, obj, name, ...)
        if obj == nil then return nil end
        local okP, m = pcall(function() return obj[name] end)
        if not okP then return false end
        if m == nil then return nil end
        return pcall(m, obj, ...)
    end,
    Helpers = {
        GetCore = function() return {} end,
        CreateDBGetter = function() return function() return actionBarsDB end end,
        CreateStateTable = function()
            local state = setmetatable({}, { __mode = "k" })
            local function get(frame)
                local entry = state[frame]
                if not entry then entry = {} state[frame] = entry end
                return entry
            end
            return state, get
        end,
        SafeToNumber = function(value, fallback)
            return type(value) == "number" and value or fallback
        end,
        SafeValue = function(value, fallback)
            return value == nil and fallback or value
        end,
        IsSecretValue = function() return false end,
        IsEditModeShown = function() return false end,
    },
    LSM = { Fetch = function() return nil end },
    IconGlow = {
        Start = function(button, opts)
            physicalGlows[button] = true
            glowOpts[button] = { color = opts.color }
        end,
        Stop = function(button)
            physicalGlows[button] = nil
            glowOpts[button] = nil
        end,
    },
}

setmetatable(_G, {
    __index = function(_, key)
        if key:match("^QUI_Bar%d") then return nil end
        local cTable = key:match("^C_[A-Z].*")
        if cTable then
            local tbl = setmetatable({}, { __index = function() return noop end })
            rawset(_G, key, tbl)
            return tbl
        end
        return noop
    end,
})

assert(loadfile("QUI_ActionBars/actionbars/actionbars_env.lua"))("QUI", ns)
assert(loadfile("QUI_ActionBars/actionbars/actionbars.lua"))("QUI", ns)
assert(loadfile("QUI_ActionBars/actionbars/actionbars_helpers.lua"))("QUI", ns)
assert(loadfile("QUI_ActionBars/actionbars/actionbars_layout.lua"))("QUI", ns)
assert(loadfile("QUI_ActionBars/actionbars/actionbars_builder.lua"))("QUI", ns)
assert(loadfile("QUI_ActionBars/actionbars/actionbars_glow.lua"))("QUI", ns)

rawset(_G, "C_ActionBar", setmetatable({
    IsAssistedCombatAction = function(action) return assistedSlots[action] == true end,
    ForceUpdateAction = noop,
    FindSpellActionButtons = function(spellID) return spellSlots[spellID] end,
}, { __index = function() return noop end }))

rawset(_G, "C_AssistedCombat", {
    GetNextCastSpell = function() return nextCastSpell end,
})

local env = ns.ActionBarsEnv
local actionBars = ns.ActionBarsOwned
local container = NewFrame()

local fails = 0
local function check(name, ok, detail)
    if ok then
        print("  ok  " .. name)
    else
        fails = fails + 1
        print("FAIL  " .. name .. (detail and ("\n        " .. detail) or ""))
    end
end

local btn = env.EnsureOwnedActionButton(container, "bar5", "QUI_Bar5Button1", 1)
assert(btn ~= nil, "sanity: create branch must return a button")

local calls = {}
local realSafeUpdate = actionBars.SafeUpdate
actionBars.SafeUpdate = function() calls.safeUpdate = (calls.safeUpdate or 0) + 1 end
btn.UpdateTypeOverlay = function() calls.typeOverlay = (calls.typeOverlay or 0) + 1 end
btn.ClearTypeOverlay = function() calls.clearType = (calls.clearType or 0) + 1 end
btn.UpdateHighlightMark = function() calls.highlight = (calls.highlight or 0) + 1 end
btn.UpdateSpellAlert = function() calls.spellAlert = (calls.spellAlert or 0) + 1 end
btn.UpdateSpellHighlightMark = function() calls.spellHighlight = (calls.spellHighlight or 0) + 1 end

btn.attributes.action = 7
btn:Update()

check("the Update override paints through QUI's own pipeline",
    calls.safeUpdate == 1)
check("a button holding an action still gets Blizzard's UpdateTypeOverlay (ActionButton.lua:574)",
    calls.typeOverlay == 1 and calls.clearType == nil,
    "typeOverlay=" .. tostring(calls.typeOverlay) .. " clearType=" .. tostring(calls.clearType))
check("a button holding an action still gets UpdateHighlightMark (:577) for NewActionTexture",
    calls.highlight == 1)
check("UpdateSpellAlert and UpdateSpellHighlightMark stay UNCALLED — QUI owns those surfaces",
    calls.spellAlert == nil and calls.spellHighlight == nil,
    "calling them double-renders against UpdateOverlayGlow / UpdateSpellHighlight")

calls = {}
btn.attributes.action = nil
btn:Update()

check("an empty slot clears the type overlay instead of updating it (:590)",
    calls.clearType == 1 and calls.typeOverlay == nil and calls.highlight == nil,
    "clearType=" .. tostring(calls.clearType) .. " typeOverlay=" .. tostring(calls.typeOverlay))

actionBars.SafeUpdate = realSafeUpdate

-- Blizzard's own create path: the frame already exists, carrying the template
-- OnUpdate, before QUI's updater ever runs.
local assistBtn = env.EnsureOwnedActionButton(container, "bar5", "QUI_Bar5Button2", 2)
assistBtn.attributes.action = 11
assistedSlots[11] = true
actionBars._assistedCombatEverActive = true

local blizzardMade = CreateFrame("Frame", nil, assistBtn, "ActionBarButtonAssistedCombatRotationTemplate")
assert(blizzardMade.scripts.OnUpdate == templateOnUpdate,
    "sanity: the swirl template must arrive with its OnUpdate bound")
assistBtn.AssistedCombatRotationFrame = blizzardMade

env.UpdateAssistedCombatRotationFrame(assistBtn)

check("a swirl frame QUI did not create still gets its OnUpdate neutered",
    blizzardMade.scripts.OnUpdate == nil,
    "Blizzard creates the identical frame at ActionButton.lua:895 from UpdateAction:542")

local armed = tickers[#tickers]
check("an active assist action arms the repaint ticker at the manager's rate",
    armed ~= nil and armed.cancelled == false and armed.seconds == 0.25,
    "seconds=" .. tostring(armed and armed.seconds))

AssistedCombatManager.updateRate = 0.5
env.UpdateAssistedCombatRotationFrame(assistBtn)
local rearmed = tickers[#tickers]
check("a changed update rate re-arms the ticker instead of latching the old one",
    rearmed ~= armed and armed.cancelled == true and rearmed.seconds == 0.5,
    "seconds=" .. tostring(rearmed and rearmed.seconds))

assistedSlots[11] = nil
env.UpdateAssistedCombatRotationFrame(assistBtn)

check("losing the assist action stops the ticker",
    rearmed.cancelled == true)
check("losing the assist action clears the tracked button so the next search can find a new one",
    rawget(env, "_assistRotationButton") == nil)

local pingBtn = env.EnsureOwnedActionButton(container, "bar5", "QUI_Bar5Button3", 3)
pingBtn.attributes.action = 13

local blizzardSwirl = CreateFrame("Frame", nil, pingBtn, "ActionBarButtonAssistedCombatRotationTemplate")
assert(blizzardSwirl.scripts.OnUpdate == templateOnUpdate,
    "sanity: the swirl template must arrive with its OnUpdate bound")
pingBtn.AssistedCombatRotationFrame = blizzardSwirl

actionBars.SafeUpdate = noop
pingBtn:Update()
actionBars.SafeUpdate = realSafeUpdate

check("the Update override neuters a swirl OnUpdate that Blizzard's UpdateAction created",
    blizzardSwirl.scripts.OnUpdate == nil,
    "UpdateAction:540 creates it one line above the Update() the override replaces")

testInCombat = true
pingBtn:UpdatePingAttributes()

check("UpdatePingAttributes defers in combat instead of firing a protected SetAttribute",
    pingUpdateCounts[pingBtn] == nil,
    "pingUpdates=" .. tostring(pingUpdateCounts[pingBtn]))

testInCombat = false
env.FlushPendingPingAttributes()

check("the deferred ping attribute update is flushed when combat ends",
    pingUpdateCounts[pingBtn] == 1,
    "pingUpdates=" .. tostring(pingUpdateCounts[pingBtn]))

pingBtn:UpdatePingAttributes()

check("out of combat the ping attribute update passes straight through to Blizzard",
    pingUpdateCounts[pingBtn] == 2,
    "pingUpdates=" .. tostring(pingUpdateCounts[pingBtn]))

local originalLayout = noop
local layoutWrites = 0
local microMenu = NewFrame()
local baseFrameMT = getmetatable(microMenu)
setmetatable(microMenu, {
    __index = function(self, key)
        if key == "Layout" then return originalLayout end
        return baseFrameMT.__index(self, key)
    end,
    __newindex = function(self, key, value)
        if key == "Layout" then layoutWrites = layoutWrites + 1 end
        rawset(self, key, value)
    end,
})
local oldGridSettings = {}
microMenu.oldGridSettings = oldGridSettings
rawset(_G, "MicroMenu", microMenu)
local microMenuContainer = NewFrame()
microMenuContainer.system = false
rawset(_G, "MicroMenuContainer", microMenuContainer)
rawset(_G, "HelpOpenWebTicketButton", false)
microMenu.parent = microMenuContainer
local layoutCalls = 0
microMenuContainer.Layout = function()
    layoutCalls = layoutCalls + 1
    assert(microMenu:GetParent() ~= microMenuContainer,
        "MicroMenu must be detached before native child layout re-enters")
end
local function NewMicroButton()
    local button = NewFrame()
    button.parent = microMenu
    button.SetParent = function(self, parent)
        self.parent = parent
        microMenuContainer:Layout()
    end
    return button
end
for _, name in ipairs(env.MICRO_BUTTON_NAMES) do
    rawset(_G, name, NewMicroButton())
end
rawset(_G, "HelpMicroButton", NewMicroButton())

local externalMicroMenuOwner = NewFrame()
microMenu.parent = externalMicroMenuOwner
env.BuildBar("microbar")

if actionBars.pendingMicroBuild then
    check("microbar cold start defers while Blizzard owns the menu",
        microMenu:GetParent() == externalMicroMenuOwner
            and actionBars.nativeButtons.microbar == nil)

    microMenu.parent = microMenuContainer
    env.ReclaimBarButtons("microbar")

    local coldStartButtonsOwned = actionBars.nativeButtons.microbar
        and #actionBars.nativeButtons.microbar == #env.MICRO_BUTTON_NAMES
    for _, name in ipairs(env.MICRO_BUTTON_NAMES) do
        coldStartButtonsOwned = coldStartButtonsOwned
            and _G[name]:GetParent() == actionBars.containers.microbar
    end
    check("microbar reclaim completes a deferred cold-start build",
        coldStartButtonsOwned and not actionBars.pendingMicroBuild)
else
    microMenu.parent = microMenuContainer
    env.BuildBar("microbar")
end

check("microbar build detaches Blizzard's layout owner before moving its children",
    microMenu:GetParent() == UIParent and layoutCalls > 0,
    "layoutCalls=" .. tostring(layoutCalls))
check("microbar build leaves Blizzard's secure Layout method untouched",
    layoutWrites == 0 and microMenu.Layout == originalLayout,
    "writes=" .. tostring(layoutWrites))
check("microbar reclaim leaves Blizzard's secure layout cache untouched",
    microMenu.oldGridSettings == oldGridSettings)

microMenu.parent = externalMicroMenuOwner
for _, name in ipairs(env.MICRO_BUTTON_NAMES) do
    _G[name].parent = microMenu
end
_G.HelpMicroButton.parent = microMenu
env.BuildBar("microbar")

check("microbar refresh preserves Blizzard's temporary external owner",
    microMenu:GetParent() == externalMicroMenuOwner)
local externalChildrenPreserved = _G.HelpMicroButton:GetParent() == microMenu
for _, name in ipairs(env.MICRO_BUTTON_NAMES) do
    externalChildrenPreserved = externalChildrenPreserved and _G[name]:GetParent() == microMenu
end
check("microbar refresh preserves Blizzard-owned micro button children",
    externalChildrenPreserved)

local baseProc = NewFrame()
baseProc.attributes.action = 21
baseProc._quiBarKey = "bar1"
baseProc._quiButtonIndex = 1
local overrideProc = NewFrame()
overrideProc.attributes.action = 22
overrideProc._quiBarKey = "bar1"
overrideProc._quiButtonIndex = 2
actionInfoBySlot[21] = { "spell", 100 }
actionInfoBySlot[22] = { "spell", 101 }
overrideSpells[100] = 101
actionBars.nativeButtons.bar1 = { baseProc, overrideProc }
overlayedSpells[101] = true

actionBars.UpdateAllOverlayGlows()

check("proc snapshots match only the button's current spell ID",
    not physicalGlows[baseProc] and physicalGlows[overrideProc])

actionBars.HideActionButtonGlow(baseProc)
actionBars.HideActionButtonGlow(overrideProc)
actionBars.OnSpellActivationGlowShow(101)

check("proc SHOW does not cross-paint a base spell for its override",
    not physicalGlows[baseProc] and physicalGlows[overrideProc])

overlayedSpells[100] = true
actionBars.OnSpellActivationGlowShow(100)
overlayedSpells[101] = nil
actionBars.OnSpellActivationGlowHide(101)

check("proc HIDE leaves a different current spell active",
    physicalGlows[baseProc] and not physicalGlows[overrideProc])

actionInfoBySlot[21] = { "spell", 200 }
actionBars.OnSpellActivationGlowHide(100)
check("proc HIDE clears a stale latch after the button identity changes",
    not physicalGlows[baseProc] and not env.GetFrameState(baseProc).quiProcGlow)

local flyoutProc = NewFrame()
flyoutProc.attributes.action = 23
flyoutProc._quiBarKey = "bar1"
flyoutProc._quiButtonIndex = 3
actionInfoBySlot[23] = { "flyout", 77 }
flyoutSpells[77] = { [777] = true, [778] = true }
flyoutSlots[77] = { { 777 }, { 778 } }
actionBars.nativeButtons.bar1[#actionBars.nativeButtons.bar1 + 1] = flyoutProc

overlayedSpells[777] = true
actionBars.UpdateOverlayGlow(flyoutProc)
check("proc snapshots recover an active base spell inside a flyout",
    physicalGlows[flyoutProc])
overlayedSpells[777] = nil
actionBars.OnSpellActivationGlowHide(777)
actionBars.OnSpellActivationGlowShow(777)
check("proc SHOW finds a flyout added after the old reverse-map snapshot",
    physicalGlows[flyoutProc])
overlayedSpells[778] = true
actionBars.OnSpellActivationGlowHide(777)
check("proc HIDE preserves another active spell in the same flyout",
    physicalGlows[flyoutProc])
overlayedSpells[778] = nil
actionBars.OnSpellActivationGlowHide(778)
check("proc HIDE clears a flyout after its last active member ends",
    not physicalGlows[flyoutProc])

flyoutSlots[77] = { { 777, 778 } }
overlayedSpells[778] = true
actionBars.UpdateOverlayGlow(flyoutProc)
actionBars.OnSpellActivationGlowHide(777)
check("proc HIDE for a flyout base preserves its active current override",
    physicalGlows[flyoutProc])
overlayedSpells[778] = nil
actionBars.OnSpellActivationGlowHide(778)
check("proc HIDE for a flyout's current override clears the glow",
    not physicalGlows[flyoutProc])

local sharedProc = NewFrame()
sharedProc.attributes.action = 30
sharedProc._quiBarKey = "bar1"
sharedProc._quiButtonIndex = 4
actionInfoBySlot[30] = { "spell", 900 }
actionBars.nativeButtons.bar1 = { sharedProc }
actionBarsDB.global.assistedHighlight = true
spellSlots[900] = { 30 }
nextCastSpell = 900
overlayedSpells[900] = true

actionBars.UpdateOverlayGlow(sharedProc)
actionBars.UpdateAllAssistedHighlights()
overlayedSpells[900] = nil
actionBars.OnSpellActivationGlowHide(900)
local sharedState = env.GetFrameState(sharedProc)

check("releasing proc ownership preserves an assisted highlight",
    physicalGlows[sharedProc] and not sharedState.quiProcGlow and sharedState.quiAssistedHighlight
        and glowOpts[sharedProc] and glowOpts[sharedProc].color == env.ASSISTED_HIGHLIGHT_COLOR)

overlayedSpells[900] = true
actionBars.OnSpellActivationGlowShow(900)
nextCastSpell = nil
actionBars.UpdateAllAssistedHighlights()

check("releasing assisted ownership restores an active proc glow",
    physicalGlows[sharedProc] and sharedState.quiProcGlow and not sharedState.quiAssistedHighlight
        and glowOpts[sharedProc] and glowOpts[sharedProc].color == nil)

print(string.format("actionbars_owned_update_override_test: checks complete, %d failed", fails))
if fails > 0 then os.exit(1) end
print("OK: actionbars_owned_update_override_test")
