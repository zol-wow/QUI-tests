local function noop() end
local inCombat = false
local auraContainers = {}
local aurasSecret = false
C_Secrets = { ShouldAurasBeSecret = function() return aurasSecret end }
local methods = {}
local function object(kind, parent)
    return setmetatable({ kind = kind, parent = parent, scripts = {} }, {
        __index = function(self, key)
            if self.kind == "AuraContainer" and rawget(self, "template") ~= "CustomAuraContainerTemplate"
                and (key == "AddAuraGroup" or key == "SetAuraGroupLayout" or key:match("^SetFlowLayout")) then
                return nil
            end
            if methods[key] then return methods[key] end
            if key:match("^Set") or key:match("^Clear") or key:match("^Enable") then return noop end
        end,
    })
end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:GetFrameLevel() return 1 end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:ClearAllPoints() self.point = nil end
function methods:SetPoint(...) self.point = { ... } end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetText(text) self.text = text end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetStatusBarColor(...) self.color = { ... } end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown()
    assert(not self.native, "addon must not observe native aura visibility")
    return self.shown
end
function methods:GetWidth() assert(not self.native); return self.width end
function methods:GetHeight() assert(not self.native); return self.height end
function methods:SetScript(key, callback)
    assert(not self.native, "native aura bars must not install addon scripts")
    self.scripts[key] = callback
end
function methods:CreateTexture() return object("Texture", self) end
function methods:CreateFontString() return object("FontString", self) end
function methods:CreateAnimationGroup() return object("AnimationGroup", self) end
function methods:CreateAnimation() return object("Animation", self) end
function methods:IsPlaying() return self.playing end
function methods:Play() self.playing = true end
function methods:Stop() self.playing = false end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetUnit(unit) self.unit = unit end
function methods:SetFlowLayoutAxis(axis) self.axis = axis end
function methods:SetFlowLayoutAnchorPoint(anchor) self.anchor = anchor end
function methods:SetIcon(texture)
    assert(not self.native or (not inCombat and not aurasSecret))
    self.boundIcon = texture
end
function methods:SetSpellName(text) self.boundName = text end
function methods:SetApplicationCount(text) self.boundCount = text end
function methods:SetDurationBar(bar, options) self.boundBar, self.barOptions = bar, options end
function methods:SetDurationText(text) self.boundDuration = text end
function methods:ClearDurationText() self.boundDuration = nil end
function methods:AddAuraGroup(key, filter, options)
    assert(not inCombat and not aurasSecret, "group configuration must happen outside combat and aura secrecy")
    local button = object("Button", self)
    button.native = true
    self.groups[key] = { filter = filter, options = options, button = button }
    options.initializeFrame(button)
end
function methods:AddAuraSlot(key, filter, options)
    self:AddAuraGroup(key, filter, options)
    self.groups[key].slot = true
end
function methods:SetAuraGroupMaxFrameCount(key, count) self.groups[key].options.maxFrameCount = count end
function methods:SetAuraGroupCandidateFilters(key, filters)
    self.groups[key].options.candidateFilters = filters
end
methods.SetAuraSlotCandidateFilters = methods.SetAuraGroupCandidateFilters
function methods:SetAuraGroupFilterString(key, filter) self.groups[key].filter = filter end
methods.SetAuraSlotFilterString = methods.SetAuraGroupFilterString
function methods:SetAuraGroupLayout(key, layout) self.groups[key].options.layout = layout end
function CreateFrame(kind, _, parent, template)
    local frame = object(kind, parent)
    frame.template = template
    if kind == "AuraContainer" then
        frame.native = true
        frame.groups = {}
        auraContainers[#auraContainers + 1] = frame
    end
    return frame
end
function InCombatLockdown() return inCombat end
function GetTime() return 100 end
C_Timer = { After = noop }
C_UnitAuras = setmetatable({}, { __index = function() error("C_UnitAuras is forbidden") end })
AnchorUtil = {
    FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
    FlowDirection = { Right = 0, Left = 1, Up = 2, Down = 3 },
}
local lists = {}
local resolveCalls = 0
local activeCooldownIDs = {}
local hiddenIDs = {}
local ns = {
    SafeCallMethodIfPresent = function(_, owner, name, ...)
        if owner and owner[name] then owner[name](owner, ...) end
    end,
    Helpers = {
        GetGeneralFont = function() return "font" end,
        GetGeneralFontOutline = function() return "" end,
        GetSkinBorderColor = function() return 0, 0, 0, 1 end,
        IsEditModeActive = function() return false end,
        IsLayoutModeActive = function() return false end,
    },
    Addon = { PixelRound = function(_, value) return value end },
    LSM = { Fetch = function() return "texture" end },
    CDMShared = {
        GetContainerDB = function(key)
            return { ownedSpells = {}, containerType = key == "custom1" and "customBar" or "auraBar" }
        end,
        IsCustomBarContainer = function(db) return db and db.containerType == "customBar" end,
    },
    CDMSources = {
        GetItemAuraSpellIDs = function(itemID)
            assert(itemID == 5001)
            return { 1307927 }
        end,
    },
    CDMSpellData = {
        GetSpellList = function(_, key) return lists[key] end,
        GetSpellOverride = function(_, _, id) return hiddenIDs[id] and { hidden = true } or nil end,
        ResolveDisplayName = function(_, entry) return entry.name end,
    },
    CDMResolvers = {
        BuildCooldownStateContext = function(_, entry) return entry end,
        ResolveCooldownState = function(entry)
            assert(entry.kind == "cooldown", "native aura bars must never enter the Lua resolver")
            resolveCalls = resolveCalls + 1
            return { isActive = activeCooldownIDs[entry.id] == true, isOnCooldown = activeCooldownIDs[entry.id] == true,
                mode = "item-cooldown", numericCooldownActive = true, start = 90, duration = 60 }
        end,
    },
}
assert(loadfile("QUI_CDM/cdm/cdm_managed_aura_mirrors.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_custom_aura_runs.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_bar_renderer.lua"))("QUI", ns)
local bars = ns.CDMBars
local settings = { enabled = true, barWidth = 215, barHeight = 25, spacing = 2, borderSize = 0 }
local function aura(id, key)
    return { id = id, spellID = id, type = "spell", kind = "aura", viewerType = key, name = tostring(id) }
end
local tracked = CreateFrame("Frame")
lists.trackedBar = { aura(1307927, "trackedBar"), aura(1237205, "trackedBar") }
bars:Refresh(tracked, settings, nil, "trackedBar", {})
assert(#bars:GetActiveBars() == 2 and #auraContainers == 2)
local native = auraContainers[1]
assert(native.unit == "player" and native.axis == AnchorUtil.FlowLayoutAxis.Vertical)
for i, id in ipairs({ 1307927, 1237205 }) do
    local group = auraContainers[i].groups.bar1
    assert(group.filter == "HELPFUL" and group.options.candidateFilters.includeSpellIDs[id])
    assert(group.options.maxFrameCount == 1)
    assert(group.options.layout.elementHeight == 28)
    local button = group.button
    assert(button.boundBar == button.StatusBar and button.boundDuration == button.DurationText)
    assert(button.boundIcon == button.IconTexture and button.boundName == button.NameText)
    assert(button.boundCount == button.CountText and button.width == 215 and button.height == 25)
    assert(button.barOptions.direction == 1 and button.barOptions.interpolation == 0)
    assert(next(button.scripts) == nil and button.mouseEnabled == false)
end
assert(not bars:GetActiveBars()[1].shown and not bars:GetActiveBars()[2].shown)
assert(resolveCalls == 0)

local custom = CreateFrame("Frame")
local customEntries = { aura(1237205, "custom1") }
bars:Refresh(custom, settings, nil, "custom1", nil, customEntries)
assert(#bars:GetActiveBars("custom1") == 1 and #bars:GetActiveBars() == 2)
assert(auraContainers[3].parent == custom and native.enabled)
assert(bars:GetCacheStats().activeBars == 3)
inCombat = true
bars:Refresh(custom, settings, nil, "custom1", nil, customEntries)
bars:UpdateOwnedBars()
inCombat = false
aurasSecret = true
bars:Refresh(custom, settings, nil, "custom1", nil, customEntries)
bars:RefreshSkinColors()
aurasSecret = false
assert(#auraContainers == 3 and resolveCalls == 0)

customEntries[1] = aura(1307927, "custom1")
bars:Refresh(custom, settings, nil, "custom1", nil, customEntries)
assert(auraContainers[3].groups.bar1.options.candidateFilters.includeSpellIDs[1307927])
assert(not auraContainers[3].groups.bar1.options.candidateFilters.includeSpellIDs[1237205])

local cooldown = { id = 42, spellID = 42, kind = "cooldown", type = "spell", name = "Cooldown", viewerType = "custom1" }
bars:Refresh(custom, settings, nil, "custom1", nil, { aura(1237205, "custom1"), cooldown })
assert(resolveCalls > 0 and #bars:GetActiveBars("custom1") == 2)
local reserved = { enabled = true, barWidth = 200, barHeight = 20, borderSize = 0, inactiveMode = "fade" }
bars:Refresh(custom, reserved, nil, "custom1", nil, { aura(1237205, "custom1") })
assert(not auraContainers[3].groups.bar1.slot and auraContainers[3].enabled)
assert(bars:GetActiveBars("custom1")[1].shown)
assert(bars:GetActiveBars("custom1")[1].alpha == 0.3)
local combatSettings = { enabled = true, barWidth = 200, barHeight = 20, borderSize = 0,
    inactiveMode = "fade", iconDisplayMode = "combat" }
bars:Refresh(custom, combatSettings, nil, "custom1", nil, { aura(1237205, "custom1") })
assert(not bars:GetActiveBars("custom1")[1].shown, "combat display packs inactive auras outside combat")
local preparedContainers = #auraContainers
inCombat = true
bars:Refresh(custom, combatSettings, nil, "custom1", nil, { aura(1237205, "custom1") })
local combatBar = bars:GetActiveBars("custom1")[1]
assert(combatBar.shown and combatBar.alpha == 0.3)
assert(auraContainers[3].point[2] == combatBar, "native aura overlays reserved combat placeholder")
assert(#auraContainers == preparedContainers, "combat transition must reuse native groups")
inCombat = false
bars:Refresh(custom, combatSettings, nil, "custom1", nil, { aura(1237205, "custom1") })
assert(not bars:GetActiveBars("custom1")[1].shown)
local itemEntry = { id = 5001, type = "item", kind = "cooldown", displayMode = "auraOnly", viewerType = "custom1" }
local beforeItemResolve = resolveCalls
bars:Refresh(custom, reserved, nil, "custom1", nil, { itemEntry })
assert(auraContainers[3].groups.bar1.options.candidateFilters.includeSpellIDs[1307927])
assert(not auraContainers[3].groups.bar1.options.candidateFilters.includeSpellIDs[5001])
assert(resolveCalls == beforeItemResolve)
local ignoredMode = { id = 42, spellID = 42, type = "spell", kind = "cooldown", displayMode = "auraOnly", viewerType = "custom1" }
bars:Refresh(custom, settings, nil, "custom1", nil, { ignoredMode })
assert(resolveCalls > beforeItemResolve and auraContainers[3].enabled == false)
local automaticItem = { id = 5001, type = "item", kind = "cooldown", viewerType = "custom1" }
local beforeAutomatic = resolveCalls
bars:Refresh(custom, settings, nil, "custom1", nil, { automaticItem })
assert(resolveCalls > beforeAutomatic)
local itemOverlay = auraContainers[#auraContainers]
assert(not itemOverlay.groups.aura.slot)
assert(itemOverlay.groups.aura.options.candidateFilters.includeSpellIDs[1307927])
assert(itemOverlay.point[2] == custom)
assert(itemOverlay.parent == custom, "hidden cooldown art must not parent-hide its native aura overlay")
local flowSource = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_SharedXMLBase/AnchorUtil.lua")):read("*a")
function CreateFromMixins(mixin)
    local result = {}
    for key, value in pairs(mixin) do result[key] = value end
    return result
end
function GetValueOrCallFunction(owner, key)
    local value = owner[key]
    return type(value) == "function" and value(owner) or value
end
assert((loadstring or load)(flowSource:sub((assert(flowSource:find("AnchorUtil.FlowLayoutAxis =", 1, true))))))()
local function nativeLayout(container, active)
    local flow = AnchorUtil.CreateFlowLayout()
    flow:SetLayoutAxis(container.axis)
    flow:SetAnchorPoint(container.anchor)
    flow:SetGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    function flow:GetElementSize(_, _, group) return group.elementWidth, group.elementHeight end
    local group = container.groups.aura or container.groups.bar1
    local layout = {}
    for key, value in pairs(group.options.layout) do layout[key] = value end
    layout.elements = active and { group.button } or {}
    flow:Apply(container, { layout })
end
for _, orientation in ipairs({ "horizontal", "vertical" }) do
    local boundsOwner = CreateFrame("Frame")
    local key = "bounds_" .. orientation
    local boundsSettings = { enabled = true, barWidth = 215, barHeight = 25, spacing = 2,
        borderSize = 0, orientation = orientation }
    local boundsCooldown = { id = 42, spellID = 42, kind = "cooldown", type = "spell", viewerType = key }
    activeCooldownIDs[42] = true
    bars:Refresh(boundsOwner, boundsSettings, nil, key, nil,
        { aura(1307927, key), aura(1237205, key), boundsCooldown })
    local boundsBars = bars:GetActiveBars(key)
    local firstRun = boundsBars[1]._nativeAuraRun.container
    local secondRun = boundsBars[2]._nativeAuraRun.container
    nativeLayout(firstRun, true)
    nativeLayout(secondRun, true)
    local axis = orientation == "vertical" and "width" or "height"
    local occupied = firstRun[axis] + secondRun[axis] + boundsBars[3][axis] - 2
    assert(boundsOwner[axis] >= occupied,
        "owner bounds must contain active native runs and cooldown bars in " .. orientation .. " layout")
    local capacity = boundsOwner[axis]
    nativeLayout(firstRun, false)
    bars:LayoutBars(boundsOwner, boundsSettings)
    assert(boundsOwner[axis] == capacity, "native holes must retain configured outer bounds")
    bars:DeleteContainer(key)
end
activeCooldownIDs[42] = nil

local function bottom(frame)
    if frame == custom then return 0 end
    local point = assert(frame.point)
    assert(point[1] == "BOTTOM")
    return bottom(point[2]) + (point[3] == "TOP" and point[2].height or 0) + point[5]
end
activeCooldownIDs[42] = true
bars:Refresh(custom, settings, nil, "custom1", nil, { automaticItem, cooldown })
local unionBars = bars:GetActiveBars("custom1")
nativeLayout(itemOverlay, false)
assert(bottom(unionBars[2]) == 0, "inactive item without an aura must consume no row")
nativeLayout(itemOverlay, true)
assert(bottom(unionBars[2]) == 27, "native item aura alone must consume exactly one row")
activeCooldownIDs[5001] = true
inCombat = true
bars:UpdateOwnedBars()
assert(itemOverlay.point[2] == unionBars[1], "native aura must overlay the active cooldown")
nativeLayout(itemOverlay, true)
assert(bottom(unionBars[2]) == 27, "aura plus cooldown must consume one row")
nativeLayout(itemOverlay, false)
assert(bottom(unionBars[2]) == 27, "cooldown alone must retain one row")
activeCooldownIDs[5001] = false
bars:UpdateOwnedBars()
nativeLayout(itemOverlay, false)
assert(bottom(unionBars[2]) == 0, "native empty group must collapse in combat")
inCombat = false
bars:ClearPool("custom1")
assert(itemOverlay.enabled == false)
assert(#bars:GetActiveBars("custom1") == 0 and #bars:GetActiveBars() == 2)
assert(auraContainers[3].enabled == false and native.enabled)
hiddenIDs[1307927], hiddenIDs[1237205] = true, true
bars:Refresh(tracked, settings, nil, "trackedBar", {})
assert(native.enabled == false)
assert(not bars:GetActiveBars()[1].shown and not bars:GetActiveBars()[2].shown)
hiddenIDs[1237205] = nil
bars:Refresh(tracked, settings, nil, "trackedBar", {})
assert(native.enabled and native.groups.bar1.options.candidateFilters.includeSpellIDs[1237205])
assert(auraContainers[2].enabled == false)

bars:Refresh(custom, settings, nil, "custom1", nil, { automaticItem })
bars:DeleteContainer("custom1")
assert(#bars:GetActiveBars("custom1") == 0 and itemOverlay.enabled == false)
custom.SetSize = function() error("deleted custom container must not receive relayouts") end
cooldown.viewerType = "trackedBar"
lists.trackedBar = { cooldown }
bars:Refresh(tracked, settings, nil, "trackedBar", {})
ns.CDMResolvers.ResolveCooldownState = function() return { isActive = true } end
bars:UpdateOwnedBars()
assert(bars:GetActiveBars()[1]._active)
print("OK: cdm_bars_native_aura_test")
local enumerateBars
for i = 1, 30 do
    local name, value = debug.getupvalue(bars.UpdateOwnedBars, i)
    if name == "EnumerateBars" then enumerateBars = value; break end
end
assert(enumerateBars, "bar updates must expose their shared pool iterator")
local firstIterator = enumerateBars()
assert(firstIterator == enumerateBars(), "bar enumeration must reuse its iterator without allocating a closure")

assert(loadfile("QUI_CDM/cdm/cdm_icon_runtime_refresh.lua"))("QUI", ns)
local eventContainer = CreateFrame("Frame")
local eventEntry = { id = 42, spellID = 42, kind = "cooldown", type = "spell", viewerType = "custom2" }
local cooldownActive = false
local eventResolves = 0
ns.CDMResolvers.ResolveCooldownState = function(entry)
    assert(entry.kind == "cooldown", "cooldown events must leave native aura state to Blizzard")
    eventResolves = eventResolves + 1
    return { isActive = cooldownActive, isOnCooldown = cooldownActive }
end
bars:Refresh(eventContainer, settings, nil, "custom2", nil, { aura(1307927, "custom2"), eventEntry })
local eventBar = bars:GetActiveBars("custom2")[2]
local dirty = false
local opaqueRecovery = {}
Constants = { SpellCooldownConsts = { GLOBAL_RECOVERY_CATEGORY = 133 } }
local refresh = ns.CDMIconRuntimeRefresh.Create({
    isRuntimeEnabled = function() return true end,
    getIconPools = function() return {} end,
    updateCooldownOnly = noop,
    isSecretValue = function(value) return value == opaqueRecovery end,
    setBarsDirty = function(value) dirty = value end,
    runDirtyBarUpdate = function()
        if dirty then dirty = false; bars:UpdateOwnedBars() end
    end,
})
local events = {
    function() refresh:HandleCooldownChanged(nil, 42, nil, "refresh") end,
    function() refresh:HandleChargesChanged(nil, 42) end,
    function() refresh:HandleCooldownChanged(nil, 42, nil, "cast_start") end,
    function() refresh:HandleCooldownChanged(nil, 42, nil, "cast_succeeded") end,
    function() refresh:HandleFrameEvent("UNIT_SPELLCAST_STOP", "player", nil, 42) end,
    function() refresh:HandleFrameEvent("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 42) end,
    function() refresh:HandleFrameEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 42) end,
    function() refresh:HandleFrameEvent("BAG_UPDATE_COOLDOWN") end,
    function() refresh:HandleFrameEvent("PLAYER_EQUIPMENT_CHANGED", 13) end,
    function() refresh:HandleFrameEvent("PLAYER_TOTEM_UPDATE") end,
}
for _, combatState in ipairs({ false, true }) do
    inCombat = combatState
    for i, event in ipairs(events) do
        cooldownActive = true
        event()
        assert(eventBar._active and eventBar.shown, "custom bar must activate without an icon pool for event " .. i)
        cooldownActive = false
        event()
        assert(not eventBar._active and not eventBar.shown, "custom bar must expire without an icon pool for event " .. i)
    end
end
inCombat = false
local resolvesBeforeGCD = eventResolves
refresh:HandleCooldownChanged(nil, 42, nil, "refresh", nil, 133)
refresh:HandleCooldownChanged(nil, 42, nil, "refresh", nil, opaqueRecovery)
assert(eventResolves == resolvesBeforeGCD, "global and opaque recovery skips must not re-resolve bars")
print("OK: pooled bar iteration and cooldown event refresh")

local combatContainer = CreateFrame("Frame")
bars:Refresh(combatContainer, combatSettings, nil, "custom3", nil, { aura(1237205, "custom3") })
local combatPlaceholder = bars:GetActiveBars("custom3")[1]
assert(not combatPlaceholder.shown)
local combatNative = combatPlaceholder._nativeAuraRun.container
local preparedGroup = combatNative.groups.bar1
local preparedCount = #auraContainers
for _ = 1, 2 do
    inCombat = true
    refresh:HandleFrameEvent("PLAYER_REGEN_DISABLED")
    assert(combatPlaceholder.shown and combatPlaceholder.alpha == 0.3,
        "combat entry must reveal prepared inactive bar placeholders without a full container refresh")
    assert(combatNative.point[2] == combatPlaceholder,
        "native aura must remain anchored over its prepared combat placeholder")
    assert(#auraContainers == preparedCount and combatNative.groups.bar1 == preparedGroup,
        "combat visibility refresh must reuse prepared native groups")
    inCombat = false
    refresh:HandleFrameEvent("PLAYER_REGEN_ENABLED")
    assert(not combatPlaceholder.shown, "combat exit must hide inactive combat-only placeholders")
end
print("OK: native bar combat transition visibility")
