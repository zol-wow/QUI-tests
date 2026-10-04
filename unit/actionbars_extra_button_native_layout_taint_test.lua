local function noop() end

local native = setmetatable({
    EventRegistry = { RegisterCallback = noop },
    UIParent = { IsShown = function() return true end },
    CreateFromMixins = function(...)
        local result = {}
        for i = 1, select("#", ...) do
            for key, value in pairs(select(i, ...)) do result[key] = value end
        end
        return result
    end,
}, { __index = _G })
for _, path in ipairs({
    "Blizzard_SharedXML/LayoutFrame.lua",
    "Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua",
}) do
    setfenv(assert(loadfile("tests/framexml/Interface/AddOns/" .. path)), native)()
end

local function harness(extraEnabled, zoneEnabled)
    local scheduled, frames = {}, {}
    local combat, scanning = false, false
    local flaggedReads, parentWrites, anchorCalls = 0, 0, 0
    local function frame()
        local ignored
        local f = setmetatable({ scripts = {}, layoutIndex = #frames + 1 }, {
            __index = function(_, key)
                if key == "ignoreInLayout" then
                    if scanning and ignored then flaggedReads = flaggedReads + 1 end
                    return ignored
                end
            end,
            __newindex = function(self, key, value)
                if key == "ignoreInLayout" then ignored = value else rawset(self, key, value) end
            end,
        })
        frames[#frames + 1] = f
        function f:GetParent() return self.parent end
        function f:SetParent(parent)
            parentWrites = parentWrites + 1
            self.parent = parent
        end
        function f:GetChildren()
            local children = {}
            for _, child in ipairs(frames) do
                if child.parent == self then children[#children + 1] = child end
            end
            return unpack(children)
        end
        function f:SetScale(value) self.scale = value end
        function f:SetAlpha(value) self.alpha = value end
        function f:SetSize(width, height) self.width, self.height = width, height end
        function f:GetWidth() return self.width or 128 end
        function f:GetHeight() return self.height or 64 end
        function f:SetPoint(...) self.point = { ... } end
        function f:ClearAllPoints() self.point = nil end
        function f:SetScript(event, handler) self.scripts[event] = handler end
        function f:GetScript(event) return self.scripts[event] end
        function f:IsShown() return true end
        function f:IsMouseEnabled() return false end
        f.GetRegions, f.GetAdditionalRegions, f.Show = noop, noop, noop
        f.SetIsLayoutFrame, f.MarkDirty, f.AddFrame = noop, noop, noop
        return f
    end

    local manager, bottom, container, viewer = frame(), frame(), frame(), frame()
    local extra, holder = frame(), frame()
    extra.button = { style = frame() }
    manager.BottomManagedLayoutContainer = bottom
    manager.showingFrames = { [container] = container, [viewer] = viewer }
    for _, layout in ipairs({ manager, bottom }) do
        layout.AddLayoutChildren = native.BaseLayoutMixin.AddLayoutChildren
        layout.GetLayoutChildren = native.BaseLayoutMixin.GetLayoutChildren
        layout.IgnoreLayoutIndex = native.BaseLayoutMixin.IgnoreLayoutIndex
        function layout:Layout()
            scanning = true
            self.lastChildren = self:GetLayoutChildren()
            scanning = false
        end
    end
    container:SetParent(manager)
    viewer:SetParent(manager)
    extra:SetParent(container)

    local ns = {
        SafeCallMethodIfPresent = function(_, object, method, ...)
            if object[method] then return pcall(object[method], object, ...) end
        end,
    }
    assert(loadfile("QUI_ActionBars/actionbars/actionbars_env.lua"))("QUI_ActionBars", ns)
    local env = ns.ActionBarsEnv
    local settings = { enabled = extraEnabled, scale = 1.5, offsetX = 7, offsetY = 9, hideArtwork = true }
    env.GetCore = function()
        return { db = { profile = { actionBars = { bars = {
            extraActionButton = settings,
            zoneAbility = { enabled = zoneEnabled },
        } } } } }
    end
    env._G = {
        QUI_HasFrameAnchor = function() return true end,
        QUI_ApplyFrameAnchor = function() anchorCalls = anchorCalls + 1 end,
    }
    env.UIParent = frame()
    env.InCombatLockdown = function() return combat end
    env.ActionBarsOwned = {}
    env.ExtraAbilityContainer, env.ExtraActionBarFrame = container, extra
    env.Helpers = { SafeToNumber = function(value, fallback) return tonumber(value) or fallback end }
    env.C_Timer = { After = function(_, callback) scheduled[#scheduled + 1] = callback end }
    env.hooksecurefunc = function(object, method, callback)
        local original = assert(object[method])
        object[method] = function(...)
            original(...)
            callback(...)
        end
    end
    assert(loadfile(arg[1] or "QUI_ActionBars/actionbars/actionbars_extra_buttons.lua"))("QUI_ActionBars", ns)
    env.extraBtnState.extraActionHolder = holder
    env.ApplyExtraButtonSettings("extraActionButton")
    env.HookExtraButtonPositioning()

    return {
        env = env, manager = manager, bottom = bottom, container = container, viewer = viewer,
        extra = extra, holder = holder, settings = settings,
        combat = function(value) combat = value end,
        reads = function() return flaggedReads end,
        writes = function() return parentWrites end,
        anchors = function() return anchorCalls end,
        pending = function() return #scheduled end,
        flush = function()
            local iterations = 0
            while #scheduled > 0 do
                iterations = iterations + 1
                assert(iterations < 10, "reclaim hooks must not schedule recursively")
                local batch = scheduled
                scheduled = {}
                for _, callback in ipairs(batch) do callback() end
            end
        end,
        update = function(target) native.ManagedFrameContainerMixin.UpdateFrame(manager, target) end,
    }
end

for _, ownership in ipairs({ { true, false }, { false, true } }) do
    local h = harness(unpack(ownership))
    for _, layoutOnBottom in ipairs({ false, true }) do
        h.container.layoutOnBottom = layoutOnBottom
        local writes = h.writes()
        h.update(h.container)
        h.update(h.viewer)
        assert(h.reads() == 0,
            "native AddLayoutChildren must never read QUI-owned ignoreInLayout before deferred reanchor")
        assert(h.container:GetParent() == h.holder,
            "owned container must leave native layout synchronously")
        assert(h.writes() == writes + 3, "each native container reparent must reclaim exactly once")
        assert(#h.manager.lastChildren == 1 and h.manager.lastChildren[1] == h.viewer,
            "native cooldown viewer must retain its normal layout membership")
        local anchors = h.anchors()
        h.flush()
        assert(h.anchors() > anchors, "saved frame anchor must still apply after deferred refresh")
        assert(h.container.point and h.container.point[2] == h.holder,
            "deferred refresh must restore holder-relative positioning")
        assert(h.extra.scale == (ownership[1] and 1.5 or 1), "extra button scale must survive reclaim")
        assert(h.extra.button.style.alpha == (ownership[1] and 0 or 1),
            "artwork preference must survive reclaim")
    end
    h.settings.enabled = false
    h.update(h.container)
    assert(h.container:GetParent() == h.holder, "session ownership must survive toggling extra styling off")
end

local h = harness(false, false)
h.update(h.container)
h.flush()
assert(h.container:GetParent() == h.manager and h.container.ignoreInLayout == nil,
    "disabled unowned container must remain in Blizzard layout without addon flags")
assert(h.anchors() == 0, "disabled unowned container must not apply addon anchors")

h = harness(true, false)
h.combat(true)
local writes = h.writes()
h.container:SetParent(h.manager)
assert(h.container:GetParent() == h.manager and h.writes() == writes + 1,
    "combat hook must not mutate the protected container parent")
h.flush()
assert(h.env.ActionBarsOwned.pendingExtraButtonRefresh,
    "combat reclaim must remain pending for regen")
h.combat(false)
h.env.ApplyExtraButtonSettings("extraActionButton")
assert(h.container:GetParent() == h.holder, "regen reconciliation must recover ownership")

local pending = h.pending()
h.env.extraBtnState.hookingSetParent = true
h.container:SetParent(h.manager)
h.env.extraBtnState.hookingSetParent = false
assert(h.container:GetParent() == h.manager and h.pending() == pending,
    "reentry guard must prevent recursive reclaim and scheduling")

print("OK: actionbars_extra_button_native_layout_taint_test")
