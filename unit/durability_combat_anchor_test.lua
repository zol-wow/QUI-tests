local core = dofile("tools/_addon_env.lua").LoadCore()
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
local source = read(arg[1] or "modules/layout/anchoring.lua")
local function section(text, first, last)
    local start = assert(text:find(first, 1, true), first)
    local finish = assert(text:find(last, start + #first, true), last)
    return text:sub(start, finish - 1)
end
local combat, layoutMode = false, false
local timers, hooks = {}, {}
local uiParent = {}
local settings = {parent = "screen", point = "TOPLEFT", relative = "TOPLEFT", offsetX = 111, offsetY = -222}
local db = {equipmentDurability = settings}
local frame = {points = {}, protected = false, restricted = false, isManagedFrame = true,
    isRightManagedFrame = true, systemInfo = {isInDefaultPosition = true,
        anchorInfo = {point = "CENTER", relativeTo = uiParent, relativePoint = "CENTER", offsetX = 20, offsetY = 30}}}
function frame:GetObjectType() return "Frame" end
function frame:IsProtected() return self.protected end
function frame:IsAnchoringRestricted() return self.restricted end
function frame:IsShown() return true end
function frame:GetScale() return 1 end
function frame:GetSize() return 60, 75 end
function frame:GetNumPoints() return #self.points end
function frame:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function frame:ClearAllPointsBase() self.points = {} end
function frame:SetPointBase(...) self.points = {{...}} end
function frame:SetParent(parent) self.parent = parent end
function frame:IsInDefaultPosition() return self.systemInfo.isInDefaultPosition end
function frame:SetSnappedToFrame(target) self.snappedToFrame = target end
function frame:ClearFrameSnap() self.snappedToFrame = nil end
local nativeNotifications = 0
local notifiedPoint
local nativeManager = {
    OnEditModeSystemAnchorChanged = function()
        nativeNotifications = nativeNotifications + 1
        notifiedPoint = {frame:GetPoint()}
    end,
    UpdateActionBarLayout = function() end,
}
local anchoring = {claimedAnchorKeys = {}, layoutOwnedFrames = {}}
local ns = {Helpers = core.Helpers}
function ns.SafeCall(_, fn, ...) return true, fn(...) end
function ns.SafeCallMethod(_, object, method, ...) return true, object[method](object, ...) end
local sandbox = setmetatable({
    ns = ns, nsHelpers = core.Helpers, QUI_Anchoring = anchoring,
    QUICore = {db = {profile = {frameAnchoring = db}}}, UIParent = uiParent,
    InCombatLockdown = function() return combat end,
    QUI_IsLayoutModeActive = function() return layoutMode end,
    C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end},
    hooksecurefunc = function(object, name, callback)
        hooks[name] = (hooks[name] or 0) + 1
        local original = object[name]
        object[name] = function(self, ...)
            original(self, ...)
            callback(self, ...)
        end
    end,
    GetSavedFrameAnchorSettings = function(saved, key) return saved and saved[key] end,
    HasFrameResolverForKey = function(key) return key == "equipmentDurability" end,
    ResolveApplyFrameForKey = function() return frame end,
    ResolveParentFrame = function() return uiParent end,
    UNSAFE_BLIZZARD_MANAGED_OVERRIDES = {}, SELF_ANCHORED_FRAMES = {},
    CASTBAR_ANCHOR_KEYS = {}, FORBIDDEN_AURA_KEYS = {},
    IsSizeStableAnchoringEnabled = function() return false end,
    IsDynamicSizeAnchorKey = function() return false end,
    HasCastbarAnchor = function() return false end,
    LiveAuraContainerFor = function() return nil end,
    ApplyAutoSizing = function() end,
    TINY_ANCHOR_THRESHOLD = 4,
    EditModeManagerFrame = nativeManager,
    EditModeSystemMixin = {},
    EditModeUtil = {IsRightAnchoredActionBar = function() return false end,
        IsBottomAnchoredActionBar = function() return false end},
    CreateFrame = function()
        return {RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end}
    end,
    drainPendingCombatConsumerOps = function() end,
    pendingCombatConsumerOps = {},
}, {__index = _G})
sandbox._G = sandbox
local function execute(text)
    local chunk = assert(loadstring(text))
    setfenv(chunk, sandbox)
    return chunk()
end
local nativeRoot = "tests/clients/forever/framexml/Interface/AddOns/"
local native = read(nativeRoot .. "Blizzard_EditMode/Shared/EditModeSystemTemplates.lua")
execute(section(native, "function EditModeSystemMixin:SetPointOverride", "function EditModeSystemMixin:HideOverride"))
execute(section(native, "function EditModeSystemMixin:GetManagedFrameContainer", "function EditModeSystemMixin:UpdateSystem("))
local managed = read(nativeRoot .. "Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua")
execute(section(managed, "function GetBottomManagedFrameContainer()", "local function UpdateManagedFrameContainers()"))
local container = {showingFrames = {}, BottomManagedLayoutContainer = {Layout = function() end}}
for name, method in pairs(sandbox.ManagedFrameContainerMixin) do container[name] = method end
function container:Layout() frame:SetPoint("TOPRIGHT", self, "TOPRIGHT", -10, -100) end
sandbox.RightManagedFrameContainer = container
for name, method in pairs(sandbox.EditModeSystemMixin) do frame[name] = method end
frame.SetPoint = frame.SetPointOverride
frame.ClearAllPoints = frame.ClearAllPointsOverride
local guard = section(source, "local _anchorGuardedFrames = {}", "local function InstallAllAnchorGuards()")
local position = section(source, "local _editModeReapplyGuard = false", "function QUI_Anchoring:SetHelpers")
local apply = section(source, "function QUI_Anchoring:ApplyFrameAnchor", "ComputeAnchorApplyOrder = function")
local override = section(source, "local function SetFrameOverride", "local VALID_BOSS_GROW_DIRECTION")
local combatEvent = section(source, "local anchoredFramesCombatFrame = CreateFrame", "local layoutUpdateFrame = CreateFrame")
local install, eventFrame, guarded = execute("local pendingAnchoredFrameUpdateAfterCombat = false\n"
    .. position .. override .. guard .. "\nlocal AnchorOrPin = function(_, ...) return SmoothSetPoint(...) end\n"
    .. apply .. combatEvent .. "\nreturn InstallAnchorGuard, anchoredFramesCombatFrame, function(fn) _editModeReapplyGuard = true; fn(); _editModeReapplyGuard = false end")
function anchoring:ApplyAllFrameAnchors() self:ApplyFrameAnchor("equipmentDurability", db.equipmentDurability) end
install(frame, "equipmentDurability")
install(frame, "equipmentDurability")
local function anchored(message)
    local point, target, relative, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and target == uiParent and relative == "TOPLEFT" and x == 111 and y == -222, message)
    assert(#frame.points == 1, "repair must leave one configured anchor")
end
local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
for _, inCombat in ipairs({false, true}) do
    combat = inCombat
    for _ = 1, 3 do
        local count = nativeNotifications
        frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -100)
        anchored("native SetPoint must restore durability immediately, including combat")
        assert(nativeNotifications == count + 1, "repair must bypass native Edit Mode anchor notifications")
        assert(notifiedPoint[2] == container and notifiedPoint[4] == -10,
            "Blizzard must finish its own anchor notification before QUI repairs the position")
        assert(frame.snappedToFrame == container, "repair must not overwrite Blizzard's native snap state")
        assert(#timers == 0, "repair must not wait for a render tick")
    end
    frame:ApplySystemAnchor()
    anchored("native default-container refresh must retain configured durability anchor")
    assert(#timers == 0, "native layout refresh repair must not queue a visible jump")
    assert(container.showingFrames[frame] == frame and frame.parent == container,
        "repair must preserve native managed-frame membership and parent")
    assert(frame.ignoreFramePositionManager == nil and frame.systemInfo.isInDefaultPosition,
        "repair must preserve native default-position state")
end
assert(hooks.SetPoint == 1 and hooks.ApplySystemAnchor == 1, "guard installation must be idempotent")
combat = false
frame.systemInfo.isInDefaultPosition = false
frame:ApplySystemAnchor()
anchored("custom native layout must also restore the QUI anchor immediately")
assert(frame.systemInfo.anchorInfo.offsetX == 20 and frame.systemInfo.anchorInfo.offsetY == 30,
    "QUI repair must not save its coordinates into the native layout")
layoutMode = true
frame:SetPoint("CENTER", container, "CENTER", 7, 8)
assert(select(4, frame:GetPoint()) == 7, "QUI layout dragging must be left untouched")
layoutMode = false
guarded(function() frame:SetPoint("CENTER", container, "CENTER", 9, 10) end)
assert(select(4, frame:GetPoint()) == 9, "QUI's own anchor application must not recurse")
for _, restriction in ipairs({"protected", "restricted"}) do
    combat = true
    frame[restriction] = true
    frame:SetPoint("CENTER", container, "CENTER", 17, 18)
    assert(select(4, frame:GetPoint()) == 17, "restricted frames must not be repaired during combat")
    assert(#timers == 0, "restricted repair must await combat end, not poll")
    combat = false
    eventFrame.event()
    flush()
    anchored("deferred protected or restricted repair must run after combat")
    frame[restriction] = false
end
db.equipmentDurability = nil
frame:SetPoint("CENTER", container, "CENTER", 27, 28)
assert(select(4, frame:GetPoint()) == 27, "removed saved anchoring must relinquish control")
assert(settings.offsetX == 111 and settings.offsetY == -222, "repair must preserve saved QUI coordinates")
print("OK: durability_combat_anchor_test")
