-- tests/unit/groupframes_targeted_spells_runtime_test.lua
-- Run: lua tests/unit/groupframes_targeted_spells_runtime_test.lua

local db = {
    enabled = true,
    party = {
        targetedSpells = {
            enabled = true,
            iconSize = 24,
            maxIcons = 3,
            spacing = 2,
            growDirection = "CENTER",
            position = "CENTER",
            offsetX = 0,
            offsetY = 0,
            reverseSwipe = true,
        },
    },
    raid = {
        targetedSpells = {
            enabled = true,
        },
    },
}

local now = 100
local durationObject = {
    IsZero = function()
        return false
    end,
}
local displayGateCalls = 0
local castingDurationCalls = 0
local visiblePlates = {}
local inCombat = false

local function noop() end

local frameMT
local function NewFrame(parent)
    local frame = {
        parent = parent,
        children = {},
        events = {},
        scripts = {},
        shown = true,
        frameLevel = 1,
    }
    if parent and parent.children then
        parent.children[#parent.children + 1] = frame
    end

    frameMT = frameMT or {
        __index = function(_, key)
            if key:sub(1, 1) == "_" then
                return nil
            elseif key == "RegisterEvent" then
                return function(self, event)
                    self.events[event] = true
                end
            elseif key == "UnregisterEvent" then
                return function(self, event)
                    self.events[event] = nil
                end
            elseif key == "SetScript" then
                return function(self, script, handler)
                    self.scripts[script] = handler
                end
            elseif key == "CreateTexture" then
                return function(self)
                    return NewFrame(self)
                end
            elseif key == "SetTexture" then
                return function(self, texture)
                    self.texture = texture
                end
            elseif key == "SetTexCoord" then
                return function(self, ...)
                    self.texCoord = { ... }
                end
            elseif key == "SetAllPoints" then
                return noop
            elseif key == "SetDrawEdge" then
                return noop
            elseif key == "SetDrawSwipe" then
                return function(self, value)
                    self.drawSwipe = value
                end
            elseif key == "SetSwipeColor" then
                return noop
            elseif key == "SetHideCountdownNumbers" then
                return noop
            elseif key == "SetReverse" then
                return function(self, value)
                    self.reverse = value
                end
            elseif key == "SetCooldownFromDurationObject" then
                return function(self, object)
                    self.durationObject = object
                end
            elseif key == "SetAlphaFromBoolean" then
                return function(self, value, falseAlpha, trueAlpha)
                    self.alphaFromBoolean = { value, falseAlpha, trueAlpha }
                end
            elseif key == "SetAlpha" then
                return function(self, value)
                    self.alpha = value
                end
            elseif key == "SetCooldown" then
                return function(self, start, duration)
                    self.cooldown = { start, duration }
                end
            elseif key == "Clear" then
                return function(self)
                    self.cleared = true
                    self.durationObject = nil
                    self.cooldown = nil
                end
            elseif key == "SetBackdrop" then
                return noop
            elseif key == "SetBackdropBorderColor" then
                return noop
            elseif key == "SetSize" then
                return function(self, width, height)
                    self.width = width
                    self.height = height
                end
            elseif key == "GetParent" then
                return function(self)
                    return self.parent
                end
            elseif key == "GetFrameLevel" then
                return function(self)
                    return self.frameLevel
                end
            elseif key == "SetFrameLevel" then
                return function(self, level)
                    self.frameLevel = level
                end
            elseif key == "Hide" then
                return function(self)
                    self.shown = false
                end
            elseif key == "Show" then
                return function(self)
                    self.shown = true
                end
            elseif key == "IsShown" then
                return function(self)
                    return self.shown
                end
            elseif key == "ClearAllPoints" then
                return function(self)
                    self.points = {}
                end
            elseif key == "SetPoint" then
                return function(self, ...)
                    self.points = self.points or {}
                    self.points[#self.points + 1] = { ... }
                end
            end
            return noop
        end,
    }

    return setmetatable(frame, frameMT)
end

local rootFrames = {}
function CreateFrame(_, _, parent)
    local frame = NewFrame(parent)
    if not parent then
        rootFrames[#rootFrames + 1] = frame
    end
    return frame
end

function wipe(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function GetTime()
    return now
end

function InCombatLockdown()
    return inCombat
end

C_Timer = {
    After = function()
        error("incoming casts must not allocate timer closures")
    end,
}

C_NamePlate = {
    GetNamePlates = function()
        return visiblePlates
    end,
}

function UnitExists(unit)
    return unit == "party1"
end

function UnitClass(unit)
    if unit == "party1" or unit == "nameplate1target" then
        return "Paladin", "PALADIN"
    end
    return nil, nil
end

function UnitRace(unit)
    if unit == "party1" or unit == "nameplate1target" then
        return "Human", "Human"
    end
    return nil, nil
end

function UnitSex(unit)
    if unit == "party1" or unit == "nameplate1target" then
        return 2
    end
    return nil
end

function UnitGroupRolesAssigned(unit)
    if unit == "party1" or unit == "nameplate1target" then
        return "DAMAGER"
    end
    return "NONE"
end

local casting = true
function UnitCastingInfo(unit)
    if unit == "nameplate1" and casting then
        return "Targeted Fire", nil, 135807, 100000, 104000
    end
    return nil
end

function UnitChannelInfo()
    return nil
end

function UnitCastingDuration(unit)
    if unit == "nameplate1" then
        castingDurationCalls = castingDurationCalls + 1
        return durationObject
    end
    return nil
end

function UnitChannelDuration()
    return nil
end

function UnitCanAttack(player, unit)
    return player == "player" and unit == "nameplate1"
end

function UnitShouldDisplaySpellTargetName(unit)
    if unit == "nameplate1" then
        displayGateCalls = displayGateCalls + 1
        return true
    end
    return false
end

function IsInGroup()
    return true
end

function IsInRaid()
    return false
end

-- core/safecall.lua stub: silent pcall passthrough matches the pre-SafeCall
-- shape this test was written against (Task 45a: StopCooldown's cooldown.Clear
-- now routes through ns.SafeCall("best-effort-style", ...)).
local function safeCallStub(_policy, fn, ...) return pcall(fn, ...) end
local function safeCallMethodStub(_policy, obj, name, ...)
    return pcall(function(...) return obj[name](obj, ...) end, ...)
end
local safeCallMethodIfPresentStub = function(_policy, obj, name, ...) if obj == nil then return nil end local okP, m = pcall(function() return obj[name] end) if not okP then return false end if m == nil then return nil end return pcall(m, obj, ...) end

local ns = {
    SafeCall = safeCallStub,
    SafeCallMethod = safeCallMethodStub,
    SafeCallMethodIfPresent = safeCallMethodIfPresentStub,
    Helpers = {
        CreateDBGetter = function()
            return function()
                return db
            end
        end,
        IsSecretValue = function()
            return false
        end,
    },
    QUI_GroupFrames = {
        unitFrameMap = {},
    },
}

local groupFrame = NewFrame(nil)
groupFrame.healthBar = NewFrame(groupFrame)
ns.QUI_GroupFrames.unitFrameMap.party1 = { groupFrame }

-- The detection engine is shared (core/incoming_casts.lua); the group module
-- subscribes to it. Load both against the same ns, as the addon does.
assert(loadfile("core/incoming_casts.lua"))("QUI", ns)
assert(ns.IncomingCasts, "incoming casts engine should export its API")
local engineFrame = assert(rootFrames[1], "engine should create an event frame")

assert(loadfile("QUI_GroupFrames/groupframes/groupframes_targeted_spells.lua"))("QUI", ns)
assert(ns.QUI_GroupFrameTargetedSpells, "targeted spells module should export its API")
local moduleFrame = assert(rootFrames[2], "targeted spells module should create an event frame")
assert(moduleFrame.events.PLAYER_LOGIN, "module should listen for login activation")
assert(moduleFrame.events.PLAYER_REGEN_ENABLED, "module should finish deferred pool growth after combat")

moduleFrame.scripts.OnEvent(moduleFrame, "PLAYER_LOGIN")
assert(engineFrame.events.NAME_PLATE_UNIT_ADDED, "active engine should watch nameplate additions")
assert(engineFrame.events.UNIT_TARGET, "active engine should watch nameplate retargets")
assert(engineFrame.events.UNIT_SPELLCAST_START, "active engine should watch cast starts")
assert(#groupFrame.children == 4, "login should preallocate three targeted-spell markers")
local icon = assert(groupFrame.children[2], "preallocated marker should be parented to the group frame")
assert(icon.shown == false, "preallocated marker should remain hidden")

engineFrame.scripts.OnEvent(engineFrame, "NAME_PLATE_UNIT_ADDED", "nameplate1")
local scheduler = assert(engineFrame.scripts.OnUpdate, "nameplate cast should arm the shared resolve scheduler")
now = now + 0.09
scheduler(engineFrame)
assert(not rawget(icon, "_targetedCaster"), "cast must not resolve before the first-read delay")
now = now + 0.01
scheduler(engineFrame)
assert(rawget(icon, "_targetedCaster") == "nameplate1", "icon should be assigned to the hostile caster")
assert(#groupFrame.children == 4, "cast resolution should reuse the preallocated marker pool")
assert(icon.shown == true, "icon should be shown after delayed target resolution")
assert(icon._texture.texture == 135807, "icon should use the casting spell texture")
assert(icon._cooldown.durationObject == durationObject, "icon should use the Blizzard duration object cooldown path")
assert(displayGateCalls > 0, "cast flow should gate through UnitShouldDisplaySpellTargetName")
assert(castingDurationCalls > 0, "cast flow should query UnitCastingDuration")
assert(engineFrame.scripts.OnUpdate == scheduler, "verify pass should reuse the same scheduler callback")
now = now + 0.15
scheduler(engineFrame)
assert(engineFrame.scripts.OnUpdate == nil, "scheduler should disarm after the verify pass")

local resolvesBeforeRetarget = displayGateCalls
engineFrame.scripts.OnEvent(engineFrame, "UNIT_TARGET", "nameplate1")
local retargetScheduler = assert(engineFrame.scripts.OnUpdate, "retarget should rearm the scheduler")
engineFrame.scripts.OnEvent(engineFrame, "UNIT_TARGET", "nameplate1")
assert(engineFrame.scripts.OnUpdate == retargetScheduler, "repeated retargets should reuse one callback")
now = now + 0.05
retargetScheduler(engineFrame)
now = now + 0.15
retargetScheduler(engineFrame)
assert(displayGateCalls == resolvesBeforeRetarget + 2, "repeated retargets should coalesce to two latest resolves")
assert(engineFrame.scripts.OnUpdate == nil, "retarget verify pass should drain the scheduler")

casting = false
engineFrame.scripts.OnEvent(engineFrame, "UNIT_TARGET", "nameplate1")
local cancelledScheduler = assert(engineFrame.scripts.OnUpdate, "retarget should schedule before cancellation")
engineFrame.scripts.OnEvent(engineFrame, "UNIT_SPELLCAST_STOP", "nameplate1")
assert(engineFrame.scripts.OnUpdate == nil, "cast stop should cancel pending resolves immediately")
cancelledScheduler(engineFrame)
assert(not rawget(icon, "_targetedCaster"), "stop event should release the caster assignment")
assert(icon.shown == false, "stop event should hide the targeted spell icon")
assert(icon._cooldown.shown == false, "stop event should hide the cooldown swipe")

casting = true
visiblePlates = { { namePlateUnitToken = "nameplate1" } }
engineFrame.scripts.OnEvent(engineFrame, "PLAYER_REGEN_ENABLED")
local regenScheduler = assert(engineFrame.scripts.OnUpdate, "combat exit should reseed an active visible cast")
now = now + 0.11
regenScheduler(engineFrame)
assert(rawget(icon, "_targetedCaster") == "nameplate1", "combat-exit reseed should restore the caster assignment")
assert(icon.shown == true, "combat-exit reseed should restore the targeted spell icon")
now = now + 0.15
regenScheduler(engineFrame)
assert(engineFrame.scripts.OnUpdate == nil, "combat-exit reseed should drain the scheduler")

db.party.targetedSpells.maxIcons = 4
inCombat = true
ns.QUI_GroupFrameTargetedSpells:ApplySettings()
assert(#groupFrame.children == 4, "combat settings refresh should defer marker-pool growth")
inCombat = false
moduleFrame.scripts.OnEvent(moduleFrame, "PLAYER_REGEN_ENABLED")
assert(#groupFrame.children == 5, "combat exit should finish deferred marker-pool growth")

print("OK: groupframes_targeted_spells_runtime_test")
