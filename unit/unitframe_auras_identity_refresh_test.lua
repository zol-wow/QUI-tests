local function noop() end
local combat = false
_G.InCombatLockdown = function() return combat end
_G.UnitExists = function() return true end
_G.C_Timer = { After = noop }
_G.CreateFromMixins = function(...)
    local result = {}
    for i = 1, select("#", ...) do
        for k, v in pairs(select(i, ...) or {}) do result[k] = v end
    end
    return result
end
_G.bit = { lshift = function(value, shift) return value * 2 ^ shift end }
_G.Flags_CreateMask = function(...)
    local result = 0
    for i = 1, select("#", ...) do result = result + select(i, ...) end
    return result
end
_G.Flags_CreateMaskFromTable = function(t)
    local result = 0
    for _, v in pairs(t) do result = result + v end
    return result
end
_G.MergeTable = function(dest, source)
    for k, v in pairs(source or {}) do dest[k] = v end
end
_G.securecopy = function(t) return t end
_G.assertf = assert
_G.EnumUtil = { IsValid = function() return true end }
_G.AuraUtil = { IsValidFilterString = function() return true end }
_G.AuraContainerUtil = { GetAuraSortComparator = noop }
_G.AuraContainerSortMethod = { Default = 0, AuraInstanceIDOnly = 8 }
_G.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
_G.AnchorUtil = {
    FlowLayoutMixin = {}, FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
    FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 },
}
local native = "tests/framexml/Interface/AddOns/Blizzard_AuraContainer/"
assert(loadfile(native .. "Blizzard_AuraContainer.lua"))()
assert(loadfile(native .. "Blizzard_ManagedAuraContainer.lua"))()
assert(loadfile(native .. "Blizzard_CustomAuraContainer.lua"))()

local ns = { SafeCall = function(_, fn, ...) return pcall(fn, ...) end }
for _, file in ipairs({ "aura_theme", "aura_elements", "aura_skin", "aura_glue", "aura_surface" }) do
    assert(loadfile("core/" .. file .. ".lua"))("QUI", ns)
end
ns.AuraSlots = { Park = noop }
local element = ns.AuraElements.NewFilterStripElement("HARMFUL")
local auras = { elementsSeeded = true, elements = { ["*"] = { element } } }
ns.QUI_UnitFrames = {
    GetFrameUnit = function(frame) return frame.unitKey end,
    _GetUnitSettings = function() return { auras = auras } end,
}
assert(loadfile("QUI_UnitFrames/unitframes/unitframe_auras.lua"))("QUI", ns)

local liveAuras = {}
local source = {
    GetAllAuraInstanceIDs = function(_, unit) return liveAuras[unit], true end,
    GetAuraDataByAuraInstanceID = function(_, _, id) return { auraInstanceID = id } end,
}
local function NewContainer(unit)
    local c = _G.CreateFromMixins(_G.ManagedAuraContainerPrivateMixin, _G.CustomAuraContainerSharedMixin)
    c.unitToken, c.enabled, c.aurasByInstanceID = unit, true, {}
    local group = {
        GetFilterString = function() return "HARMFUL" end,
        GetMaxFrameCount = function() return element.maxIcons end,
        SetCandidateFilters = noop, SetAuraComparator = noop,
    }
    local manager = {
        ClearAllAuras = noop,
        ProcessParsedAura = noop,
    }
    c.auraGroupManager, c.auraSlotManager = manager, { ClearAuraSlotCandidates = noop }
    c.auraParseFilters = { { filterString = "HARMFUL", registrants = { { manager = manager, consumer = group } } } }
    c.layoutOptionsByAuraGroup = {}
    c.GetAuraGroup = function() return group end
    c.HasAuraGroup = function() return true end
    c.GetAuraGroupFrameCount = function() return 0 end
    c.EnumerateAuraSources = function() return ipairs({ source }) end
    c.PrepareAuraData = noop
    c.RefreshItemEnchantments = noop
    c.UpdateEventRegistrations = noop
    c.MarkDirty = function(self, flags)
        if flags % 2 == 1 then self.needsParse = true end
    end
    c.ClearAllPoints, c.SetPoint, c.Show, c.Hide = noop, noop, noop, noop
    c.SetFlowLayoutAxis, c.SetFlowLayoutAnchorPoint = noop, noop
    c.SetFlowLayoutGrowthDirection, c.SetFlowLayoutPadding = noop, noop
    c.SetFlowLayoutMaximumLineSize = noop
    function c:Flush()
        if self.needsParse then
            self:ProcessParseAuras()
            self.needsParse = false
        end
    end
    return c
end

local function CheckIdentityChange(unit, event, arg)
    liveAuras[unit] = { 101 }
    local c = NewContainer(unit)
    local frame = { unitKey = unit, _quiAuraContainers = { c }, scripts = {} }
    frame.RegisterEvent, frame.RegisterUnitEvent = noop, noop
    frame.SetScript = function(self, name, fn) self.scripts[name] = fn end
    frame.GetScript = function(self, name) return self.scripts[name] end
    ns.QUI_UnitFrames.SetupAuraTracking(frame)
    c:Flush()
    assert(c.aurasByInstanceID[101], "initial unit must supply its aura to the native cache")
    ns.QUI_UnitFrames.ApplyContainerConfig(frame)
    assert(not c.needsParse, "unchanged styling must preserve candidate-filter refresh deduplication")
    liveAuras[unit] = { 202 }
    frame.scripts.OnEvent(frame, event, arg)
    c:Flush()
    assert(c.aurasByInstanceID[202] and not c.aurasByInstanceID[101],
        unit .. " identity change must replace the old unit's aura without a UNIT_AURA event")
    liveAuras[unit] = {}
    frame.scripts.OnEvent(frame, event, arg)
    c:Flush()
    assert(next(c.aurasByInstanceID) == nil, unit .. " replacement without auras must clear the old aura cache")
end

for _, restricted in ipairs({ false, true }) do
    combat = restricted
    CheckIdentityChange("focus", "PLAYER_FOCUS_CHANGED")
    CheckIdentityChange("target", "PLAYER_TARGET_CHANGED")
    CheckIdentityChange("targettarget", "UNIT_TARGET", "target")
    CheckIdentityChange("pet", "UNIT_PET", "player")
end
print("OK: unitframe_auras_identity_refresh_test")
