local helpers = dofile("tools/_addon_env.lua").LoadCore().Helpers

local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local source = read(os.getenv("QUI_ANCHOR_SOURCE") or "modules/layout/anchoring.lua")
local first = assert(source:find("local managedReparentState = {}", 1, true))
local last = assert(source:find("local FRAME_RESOLVERS = {", first, true))

for _, corpus in ipairs({ "tests/framexml", "tests/clients/forever/framexml" }) do
    local combat, nativeMutation, hookDepth = false, false, 0
    local timers, globals = {}, {}
    local function frame(parent)
        local object = { parent = parent, width = 260, height = 600, points = {} }
        function object:IsProtected() return self.protected or false end
        function object:IsAnchoringRestricted() return self.restricted or false end
        local function check(self)
            assert(nativeMutation or not combat or not helpers.FrameMutationRestricted(self),
                "QUI must not mutate a restricted tracker during combat")
        end
        function object:GetParent() return self.parent end
        function object:SetParent(value) check(self); self.parent = value end
        function object:ClearAllPoints() check(self); self.points = {} end
        function object:SetPoint(...) check(self); self.points[#self.points + 1] = { ... } end
        object.ClearAllPointsBase, object.SetPointBase = object.ClearAllPoints, object.SetPoint
        function object:SetAllPoints(target)
            check(self)
            self.points = { { "TOPLEFT", target, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0 } }
        end
        function object:StartMoving()
            check(self)
            self.moving, self.points = true, { { "CENTER", parent, "CENTER", 90, 90 } }
        end
        function object:StopMovingOrSizing() check(self); self.moving = false end
        function object:SetSize(width, height) check(self); self.width, self.height = width, height end
        function object:GetWidth() return self.width end
        function object:GetHeight() return self.height end
        function object:GetScale() return 1 end
        function object:GetFrameStrata() return "MEDIUM" end
        function object:SetFrameStrata() end
        function object:IsShown() return self.shown ~= false end
        function object:RegisterEvent() end
        function object:SetScript(_, callback) self.callback = callback end
        return object
    end
    local parent = frame()
    local tracker = frame(parent)
    globals.ObjectiveTrackerFrame = tracker
    local ns = { Helpers = helpers }
    function ns.SafeCallMethod(_, object, method, ...) return object[method](object, ...) end
    function ns.SafeCallMethodIfPresent(_, object, method, ...)
        if object and object[method] then return object[method](object, ...) end
    end
    local definition = { key = "objectiveTracker", frameName = "ObjectiveTrackerFrame", holderName = "QUI_ObjectiveTrackerHolder" }
    local env = setmetatable({
        ns = ns, nsHelpers = helpers, _G = globals, UIParent = parent,
        ObjectiveTrackerFrame = tracker, MANAGED_REPARENT_TARGETS = { definition },
        QUI_Anchoring = {}, QUICore = { db = { profile = { general = {
            skinObjectiveTracker = false, objectiveTrackerWidth = 260, objectiveTrackerHeight = 600,
        } } } },
        EditModeSystemMixin = {}, EditModeManagerFrame = {
            UpdateActionBarLayout = function() end, SetSnapPreviewFrame = function() end,
            OnEditModeSystemAnchorChanged = function() end,
        },
        InCombatLockdown = function() return combat end,
        C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end },
        CreateFrame = function(_, name, owner)
            local object = frame(owner)
            if name then globals[name] = object end
            return object
        end,
        hooksecurefunc = function(object, method, callback)
            local original = assert(object[method])
            object[method] = function(self, ...)
                hookDepth = hookDepth + 1
                assert(hookDepth < 12, "native wrapper and base hooks must not recurse through QUI repairs")
                original(self, ...)
                local privileged = nativeMutation
                nativeMutation = false
                callback(self, ...)
                nativeMutation = privileged
                hookDepth = hookDepth - 1
            end
        end,
    }, { __index = _G })
    local function execute(code)
        local chunk = assert(loadstring(code))
        setfenv(chunk, env)
        return chunk()
    end
    local managed = read(corpus .. "/Interface/AddOns/Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua")
    execute(managed:sub(1, assert(managed:find("local function UpdateManagedFrameContainers()", 1, true)) - 1))
    local native = read(corpus .. "/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua")
    for _, method in ipairs({ "ApplySystemAnchor", "BreakFromFrameManager", "OnDragStart", "SetPointOverride", "ClearAllPointsOverride" }) do
        execute(assert(native:match("function EditModeSystemMixin:" .. method .. "%(.-%).-\nend")))
        tracker[method] = env.EditModeSystemMixin[method]
    end
    tracker.SetPoint, tracker.ClearAllPoints = tracker.SetPointOverride, tracker.ClearAllPointsOverride
    local container = frame(parent)
    for key, value in pairs(env.ManagedFrameContainerMixin) do container[key] = value end
    container:OnLoad()
    local remove = container.RemoveManagedFrame
    function container:RemoveManagedFrame(target)
        assert(not combat or nativeMutation, "QUI must defer native manager cleanup and sibling relayout until combat ends")
        return remove(self, target)
    end
    container.BottomManagedLayoutContainer = { Layout = function() end }
    function container:Layout()
        assert(not combat or nativeMutation, "QUI must not relayout native manager siblings during combat")
        if self.showingFrames[tracker] then tracker:SetPoint("TOPRIGHT", self, "TOPRIGHT", -70, -100) end
    end
    function tracker:GetManagedFrameContainer() return container end
    function tracker:IsInDefaultPosition() return self.defaultPosition or false end
    function tracker:UpdateHeight() self.height = 800 end
    function tracker:CanBeMoved() return true end
    function tracker:ClearFrameSnap() end
    function tracker:SetSnappedToFrame() end
    tracker.layoutParent, tracker.isRightManagedFrame, tracker.isManagedFrame = container, true, true
    tracker.systemInfo = { anchorInfo = {
        point = "TOPRIGHT", relativeTo = parent, relativePoint = "TOPRIGHT", offsetX = -70, offsetY = -100,
    } }
    local install, states, eventFrame = execute(source:sub(first, last - 1)
        .. "\nreturn InstallManagedReparent, managedReparentState, managedReparentInitFrame")
    local holder = install(definition)
    local function assertOwned(reason, pendingCleanup)
        assert(tracker:GetParent() == holder, corpus .. ": " .. reason .. " must restore the QUI parent synchronously")
        assert(#tracker.points == 1 and tracker.points[1][1] == "TOPLEFT" and tracker.points[1][2] == holder,
            corpus .. ": " .. reason .. " must retain the QUI top-left anchor")
        assert(tracker.ignoreFramePositionManager and (pendingCleanup or not container.showingFrames[tracker]),
            corpus .. ": " .. reason .. " must exclude the tracker from native managed layout")
        assert(#timers == 0, "objective tracker ownership repair must not wait for a render tick")
    end
    tracker:ApplySystemAnchor()
    assertOwned("native custom layout")
    tracker.defaultPosition = true
    tracker:ApplySystemAnchor()
    assertOwned("native default layout")
    tracker.shown = false
    tracker:ApplySystemAnchor()
    assertOwned("hidden native default layout")
    tracker.shown = true
    assert(holder.width == 260 and holder.height == 600 and tracker.height == 800,
        "native content sizing must not move a holder when tracker skinning is disabled")
    for _, method in ipairs({ "SetPointBase", "SetAllPoints", "ClearAllPointsBase", "ClearAllPoints" }) do
        if method == "SetPointBase" then tracker[method](tracker, "TOPRIGHT", parent, "TOPRIGHT", -40, -50)
        else tracker[method](tracker, parent) end
        assertOwned(method)
    end
    tracker:OnDragStart()
    assert(not tracker.moving, "Blizzard Edit Mode dragging must stop before moving the QUI-owned tracker")
    assertOwned("native drag start")
    combat = true
    nativeMutation = true
    tracker:BreakFromFrameManager()
    nativeMutation = false
    assertOwned("unrestricted combat reparent")
    nativeMutation = true
    tracker:ApplySystemAnchor()
    nativeMutation = false
    assertOwned("combat native default layout", true)
    assert(container.showingFrames[tracker] and states.objectiveTracker.reanchorAfterCombat,
        "combat manager reclamation must preserve pending cleanup while restoring the tracker immediately")
    for _ = 1, 3 do
        tracker:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -50)
        assertOwned("repeated combat point repair", true)
        assert(states.objectiveTracker.reanchorAfterCombat, "point repair must not discard deferred native manager cleanup")
    end
    combat = false
    eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
    assertOwned("deferred native manager cleanup")
    combat = true
    for _, restriction in ipairs({ "protected", "restricted" }) do
        tracker[restriction] = true
        nativeMutation = true
        tracker:SetParent(container)
        nativeMutation = false
        assert(tracker:GetParent() == container and states.objectiveTracker.reanchorAfterCombat,
            "restricted native reparent must retain a combat-end retry")
        combat = false
        eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
        assertOwned("combat-end recovery")
        assert(not states.objectiveTracker.reanchorAfterCombat, "successful combat-end recovery must clear its retry")
        tracker[restriction], combat = false, true
    end
    holder.protected = true
    nativeMutation = true
    tracker:SetParent(container)
    nativeMutation = false
    assert(tracker:GetParent() == container and states.objectiveTracker.reanchorAfterCombat,
        "reparenting into a restricted holder must wait until combat ends")
    combat = false
    eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
    assertOwned("restricted holder recovery")
end

print("OK: objective_tracker_native_anchor_test")
