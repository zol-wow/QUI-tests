-- tests/unit/aura_skin_group_profile_test.lua
-- Per-group style profiles: a group descriptor may carry `profile`, used for
-- its buttons instead of the container profile (packed aura-display groups
-- mix displays with different icon sizes in one container). The lookup is by
-- key at style time, so a later Configure swaps styling without rebirth.
-- Also pins the elementHeight passthrough and the crossEnd flow anchor.
-- Run: lua tests/unit/aura_skin_group_profile_test.lua

local fails = 0
local function check(name, ok, detail)
    if ok then print("  ok  " .. name)
    else fails = fails + 1; print("FAIL  " .. name .. (detail and ("  " .. detail) or "")) end
end

_G.InCombatLockdown = function() return false end
_G.AuraContainerSortMethod = { Default = 1 }
_G.AuraContainerSortDirection = { Normal = 1 }
_G.AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 }, FlowLayoutAxis = { Horizontal = 0, Vertical = 1 } }

local function Stub()
    local t = {}
    function t:SetAllPoints() end
    function t:SetPoint() end
    function t:ClearAllPoints() end
    function t:SetColorTexture() end
    function t:SetTexCoord() end
    function t:DisablePixelSnap() end
    function t:SetTextColor() end
    function t:SetAlpha() end
    function t:SetFont() end
    function t:SetHideCountdownNumbers() end
    function t:SetDrawSwipe() end
    function t:SetReverse() end
    function t:SetText() end
    function t:SetStatusBarTexture() end
    function t:SetOrientation() end
    function t:SetStatusBarColor() end
    function t:Show() end
    function t:Hide() end
    function t:CreateTexture() return Stub() end
    function t:CreateFontString() return Stub() end
    return t
end
_G.CreateFrame = function() return Stub() end

local function MakeButton(name)
    local b = Stub()
    b._name = name
    function b:SetCancelAuraButtons() end
    function b:SetSize(w, h) self._w, self._h = w, h end
    function b:SetIcon() end
    function b:AddDispelTypeTexture() end
    function b:SetDispelTypeText() end
    function b:SetDurationCooldown() end
    function b:SetDurationText() end
    function b:SetApplicationCount() end
    return b
end

local function MakeContainer()
    local c = { _addCalls = {}, _layoutCalls = {}, _registeredKeys = {}, _groupFrames = {} }
    function c:HasAuraGroup(key) return self._registeredKeys[key] == true end
    function c:AddAuraGroup(key, filter, opts)
        c._addCalls[#c._addCalls + 1] = { key = key, filter = filter, opts = opts }
        c._registeredKeys[key] = true
        local b = MakeButton(key)
        opts.initializeFrame(b)
        c._groupFrames[key] = { b }
    end
    function c:SetAuraGroupFilterString() end
    function c:SetAuraGroupMaxFrameCount() end
    function c:SetAuraGroupSortMethod() end
    function c:SetAuraGroupCandidateFilters() end
    function c:SetAuraGroupLayout(key, layout) c._layoutCalls[key] = layout end
    function c:SetFlowLayoutAnchorPoint(anchor) c._flowAnchor = anchor end
    function c:SetFlowLayoutGrowthDirection(h, v) c._flowH, c._flowV = h, v end
    function c:SetFlowLayoutPadding() end
    function c:SetFlowLayoutAxis(axis) c._flowAxis = axis end
    function c:SetFlowLayoutMaximumLineSize() end
    function c:GetAuraGroupFrameCount(key)
        local frames = self._groupFrames[key]
        return frames and #frames or 0
    end
    function c:GetAuraGroupFrame(key, i)
        local frames = self._groupFrames[key]
        return frames and frames[i]
    end
    return c
end

local ns = {}
assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("core/aura_theme.lua"))("QUI", ns)
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
assert(loadfile("core/aura_elements.lua"))("QUI", ns)
local AuraSkin = ns.Addon.AuraSkin

local c = MakeContainer()
local big = { iconSize = 30 }
local small = { iconSize = 12 }
AuraSkin.Configure(c, { iconSize = 20, grow = "RIGHT" }, {
    { key = "p1", filter = "HELPFUL", maxFrameCount = 1, profile = big, elementWidth = 30, elementHeight = 30 },
    { key = "p2", filter = "HELPFUL", maxFrameCount = 1, profile = small, elementWidth = 12, elementHeight = 12 },
    { key = "s1", filter = "HARMFUL", maxFrameCount = 3 },
})
local b1, b2, b3 = c._groupFrames.p1[1], c._groupFrames.p2[1], c._groupFrames.s1[1]
check("birth: group profile sizes its own buttons", b1._w == 30 and b2._w == 12)
check("birth: groups without a profile use the container profile", b3._w == 20)
check("layout: elementHeight passes through to the group layout",
    c._addCalls[1].opts.layout.elementHeight == 30 and c._addCalls[2].opts.layout.elementHeight == 12)
check("layout: default element height stays the container icon size",
    c._addCalls[3].opts.layout.elementHeight == 20)

AuraSkin.Restyle(c, { iconSize = 25 })
check("restyle: per-group profiles survive a container restyle", b1._w == 30 and b2._w == 12)
check("restyle: unprofiled groups follow the new container profile", b3._w == 25)

AuraSkin.Configure(c, { iconSize = 25, grow = "RIGHT" }, {
    { key = "p1", filter = "HELPFUL", maxFrameCount = 1, profile = { iconSize = 40 }, elementWidth = 40, elementHeight = 40 },
    { key = "p2", filter = "HELPFUL", maxFrameCount = 1 },
    { key = "s1", filter = "HARMFUL", maxFrameCount = 3 },
})
check("reconfigure: a swapped group profile restyles existing buttons", b1._w == 40)
check("reconfigure: dropping a group profile falls back to the container", b2._w == 25)
check("reconfigure: layout update carries the new element height", c._layoutCalls.p1.elementHeight == 40)

local v = MakeContainer()
AuraSkin.Configure(v, { iconSize = 20, grow = "DOWN", crossEnd = true }, {
    { key = "p1", filter = "HELPFUL", maxFrameCount = 1 },
})
check("flow: vertical growth with crossEnd anchors TOPRIGHT and grows left",
    v._flowAnchor == "TOPRIGHT" and v._flowH == AnchorUtil.FlowDirection.Left
    and v._flowAxis == AnchorUtil.FlowLayoutAxis.Vertical)
local v2 = MakeContainer()
AuraSkin.Configure(v2, { iconSize = 20, grow = "DOWN" }, {
    { key = "p1", filter = "HELPFUL", maxFrameCount = 1 },
})
check("flow: vertical growth without crossEnd keeps the TOPLEFT anchor",
    v2._flowAnchor == "TOPLEFT" and v2._flowH == AnchorUtil.FlowDirection.Right)
local h = MakeContainer()
AuraSkin.Configure(h, { iconSize = 20, grow = "RIGHT", wrap = "UP", crossEnd = true }, {
    { key = "p1", filter = "HELPFUL", maxFrameCount = 1 },
})
check("flow: crossEnd does not disturb horizontal flows", h._flowAnchor == "BOTTOMLEFT")

if fails > 0 then error(fails .. " failure(s) in aura_skin_group_profile_test") end
print("OK: aura_skin_group_profile_test (all checks passed)")
