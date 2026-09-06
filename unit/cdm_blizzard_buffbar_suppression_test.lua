-- tests/unit/cdm_blizzard_buffbar_suppression_test.lua
-- Run: lua tests/unit/cdm_blizzard_buffbar_suppression_test.lua
--
-- Reference-style suppression for Blizzard's BuffBarCooldownViewer: keep the
-- viewer alive as the aura data source, alpha-hide it, and park its visual shell
-- offscreen out of combat while QUI mirrors its children.

local unpackValue = table.unpack or unpack
local deferred = {}
local eventFrame

_G.C_Timer = {
    After = function(_, callback)
        deferred[#deferred + 1] = callback
    end,
}
_G.hooksecurefunc = function(target, method, hook)
    local original = assert(target[method], method .. " is missing")
    target[method] = function(...)
        original(...)
        hook(...)
    end
end
_G.CreateFrame = function()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:SetScript(_, script) self.onEvent = script end
    return eventFrame
end

local function FlushDeferred()
    while #deferred > 0 do
        local callbacks = deferred
        deferred = {}
        for i = 1, #callbacks do callbacks[i]() end
    end
end

local function FireEvent(event, ...)
    assert(eventFrame.events[event], event .. " is not registered")
    eventFrame.onEvent(eventFrame, event, ...)
end

local ns = {}
local chunk = assert(loadfile("QUI_CDM/cdm/cdm_blizzard_buffbar_suppression.lua"))

local function MakeFrame()
    local f = {
        alpha = 1,
        points = {
            { "CENTER", "Parent", "CENTER", 12, -8 },
        },
        pointWrites = 0,
        clearCalls = 0,
        mouseWrites = {},
    }
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpackValue(self.points[i]) end
    function f:SetAlpha(a) self.alpha = a end
    function f:ClearAllPoints() self.clearCalls = self.clearCalls + 1; self.points = {} end
    function f:SetPoint(...) self.pointWrites = self.pointWrites + 1; self.points[#self.points + 1] = { ... } end
    function f:SetAllPoints(parent) self.points = { { "TOPLEFT", parent, "TOPLEFT", 0, 0 } } end
    function f:SetParent(parent) self.parent = parent end
    function f:EnableMouse(value) self.mouseWrites.EnableMouse = value end
    function f:EnableMouseMotion(value) self.mouseWrites.EnableMouseMotion = value end
    return f
end

local inCombat = false
_G.InCombatLockdown = function() return inCombat end
_G.UIParent = { name = "UIParent" }

chunk("QUI", ns)
local Suppressor = assert(ns.CDMBlizzardBuffBarSuppressor, "suppression module exported")

do
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end }

    assert(Suppressor:Suppress() == true, "suppression succeeds when the native frame exists")
    assert(frame.alpha == 0, "suppression hides via SetAlpha(0)")
    assert(frame.clearCalls == 1, "suppression clears native viewer points out of combat")
    assert(frame.pointWrites == 1, "suppression moves BuffBarCooldownViewer offscreen out of combat")
    assert(frame.points[1][1] == "TOPLEFT" and frame.points[1][2] == _G.UIParent
        and frame.points[1][3] == "BOTTOMLEFT" and frame.points[1][5] <= -10000,
        "suppression parks BuffBarCooldownViewer below UIParent")
    assert(frame.mouseWrites.EnableMouse == false, "suppression disables mouse")
    assert(frame.mouseWrites.EnableMouseMotion == false, "suppression disables mouse motion")

    frame:SetAlpha(1)
    assert(frame.alpha == 0, "alpha-only drift is repaired while the viewer remains parked")
    frame.alpha = 1
    assert(Suppressor:CheckParkIntegrity() == true and frame.alpha == 0,
        "park integrity repairs alpha even when the anchor has not changed")

    Suppressor:Restore()
    assert(frame.alpha == 1, "restore makes the native bar visible again")
    frame:SetAlpha(1)
    FlushDeferred()
    assert(frame.alpha == 1, "installed repair hooks leave the restored viewer visible")
    assert(frame.points[1][1] == "CENTER" and frame.points[1][4] == 12 and frame.points[1][5] == -8,
        "restore returns the original anchor")
end

do
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end }

    assert(Suppressor:Suppress() == true, "initial suppression succeeds before Blizzard layout drift")
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    frame:SetAlpha(1)
    FlushDeferred()
    assert(frame.alpha == 0 and frame.points[1][1] == "TOPLEFT" and frame.points[1][5] <= -10000,
        "Blizzard SetPoint and alpha drift are repaired on the next frame")

    frame:SetAllPoints(_G.UIParent)
    FlushDeferred()
    assert(frame.points[1][1] == "TOPLEFT" and frame.points[1][5] <= -10000,
        "Blizzard SetAllPoints drift is repaired on the next frame")

    frame.points = { { "CENTER", _G.UIParent, "CENTER", 0, 0 } }
    frame:SetParent(_G.UIParent)
    FlushDeferred()
    assert(frame.points[1][1] == "TOPLEFT" and frame.points[1][5] <= -10000,
        "Blizzard SetParent drift is repaired on the next frame")

    frame.points = { { "CENTER", _G.UIParent, "CENTER", 0, 0 } }
    frame.alpha = 1
    FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
    assert(frame.alpha == 0 and frame.points[1][1] == "TOPLEFT" and frame.points[1][5] <= -10000,
        "Edit Mode layout completion repairs unhooked anchor drift")
end

do
    _G.BuffBarCooldownViewer = nil
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end }

    assert(Suppressor:Suppress() == false, "missing native viewer queues suppression")
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    FireEvent("ADDON_LOADED", "Blizzard_CooldownViewer")
    assert(frame.alpha == 0, "late-created BuffBarCooldownViewer is hidden immediately")
    assert(frame.clearCalls == 0 and frame.pointWrites == 0,
        "late-created BuffBarCooldownViewer is not parked inside ADDON_LOADED")
    FlushDeferred()
    assert(frame.points[1][1] == "TOPLEFT" and frame.points[1][5] <= -10000,
        "late-created BuffBarCooldownViewer is parked after ADDON_LOADED returns")
end

do
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end }
    inCombat = true

    assert(Suppressor:Suppress() == true, "combat suppression still succeeds")
    assert(frame.alpha == 0, "combat suppression may still alpha-hide")
    assert(frame.clearCalls == 0, "combat suppression must not clear protected points")
    assert(frame.pointWrites == 0, "combat suppression must not move the native viewer")

    frame:SetAlpha(1)
    assert(frame.alpha == 0, "alpha-only drift is repaired before combat parking is allowed")
    assert(frame.clearCalls == 0 and frame.pointWrites == 0,
        "combat alpha repair does not mutate native anchors")

    inCombat = false
    Suppressor:FlushPendingRestore()
    assert(frame.clearCalls == 1 and frame.pointWrites == 1,
        "combat suppression parks the native viewer when combat ends")
end

do
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return true end }
    inCombat = false

    assert(Suppressor:Apply({ enabled = false }) == false,
        "disabled tracked-bar settings restore instead of suppress")
    assert(frame.alpha == 1, "disabled tracked-bar settings leave Blizzard visible")
end

do
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return false end }

    assert(Suppressor:Suppress() == false,
        "suppression waits until CooldownViewer data is available")
    assert(frame.alpha == 0, "not-ready suppression hides the native viewer immediately")
    assert(frame.clearCalls == 0 and frame.pointWrites == 0,
        "not-ready suppression must not move the native viewer")

    frame:SetAlpha(1)
    assert(frame.alpha == 0, "alpha-only drift is repaired before data readiness")
    assert(frame.clearCalls == 0 and frame.pointWrites == 0,
        "not-ready alpha repair does not mutate native anchors")

    _G.C_CooldownViewer.IsCooldownViewerAvailable = function() return true end
    FireEvent("COOLDOWN_VIEWER_DATA_LOADED")
    assert(frame.clearCalls == 0 and frame.pointWrites == 0,
        "data-ready callback does not park the native viewer synchronously")
    FlushDeferred()
    assert(frame.points[1][1] == "TOPLEFT" and frame.points[1][5] <= -10000,
        "data-ready suppression parks the native viewer after the callback returns")
end

do
    local frame = MakeFrame()
    _G.BuffBarCooldownViewer = frame
    _G.C_CooldownViewer = { IsCooldownViewerAvailable = function() return false end }

    Suppressor:Suppress()
    assert(frame.alpha == 0, "not-ready suppression precondition hides the native viewer")
    Suppressor:Apply({ enabled = false })
    assert(frame.alpha == 1, "disabling suppression restores alpha before data readiness")
end

print("OK: cdm_blizzard_buffbar_suppression_test")
