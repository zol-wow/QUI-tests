-- tests/unit/aura_displays_group_pack_test.lua
-- Group-level dynamic layout: a group with dynamicLayout renders its
-- single-list icon displays through ONE shared aura container on the group
-- host (one single-frame Blizzard group per spell, styled per display), so
-- the engine packs the icons that exist. Members that cannot pack keep their
-- reserved positions after the block. Packing pauses in Layout Mode.
-- Run: lua tests/unit/aura_displays_group_pack_test.lua

local function fail(msg)
    print("FAIL: aura_displays_group_pack_test - " .. msg)
    os.exit(1)
end

local profile = {}
local ns = {}
local layoutModeActive = false
ns.Helpers = {
    GetProfile = function() return profile end,
    GetModuleSettings = function(name, defaults)
        if not profile[name] then
            profile[name] = {}
            for k, v in pairs(defaults or {}) do profile[name][k] = v end
        end
        return profile[name]
    end,
    IsLayoutModeActive = function() return layoutModeActive end,
    GetCurrentSpecID = function() return 1 end,
}

local function NewFrame(kind, parent)
    local frame = { kind = kind, parent = parent, width = 1, height = 1, scale = 1, shown = false }
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:GetSize() return self.width, self.height end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetScale(scale) self.scale = scale end
    function frame:GetParent() return self.parent end
    function frame:SetParent(nextParent) self.parent = nextParent end
    function frame:SetClampedToScreen() end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetScript() end
    function frame:SetAllPoints() end
    function frame:SetMovable() end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:GetCenter() return 0, 0 end
    function frame:GetEffectiveScale() return 1 end
    if kind == "AuraContainer" then
        function frame:SetUnit(unit) self.unit = unit end
        function frame:GetUnit() return self.unit end
        function frame:SetEnabled(value) self.enabled = value end
    end
    return frame
end

UIParent = NewFrame("Frame", nil)
InCombatLockdown = function() return false end
CreateFrame = function(kind, _, parent) return NewFrame(kind, parent) end

ns.L = setmetatable({}, { __index = function(_, key) return key end })
local function SpellCount(element)
    local n = 0
    for _, s in ipairs(element.spells or {}) do if type(s) == "number" then n = n + 1 end end
    return n
end
ns.AuraElements = {
    NewFilterStripElement = function() return {} end,
    EnsureSeeded = function() end,
    ActiveElementsForSpec = function(auras) return auras._elements or {} end,
    TrackedSpellCount = SpellCount,
}
local configureCalls = {}
ns.AuraGlue = {
    ElementProfile = function(element)
        local n = element.mode == "tracked" and SpellCount(element) or 1
        return { maxPerRow = 0, maxIcons = math.max(n, 1), iconSize = element.iconSize or 10,
            spacing = element.spacing or 0, grow = "RIGHT", anchor = "TOPLEFT" }
    end,
    AurasAreSecret = function() return false end,
    QueueRegenWork = function() end,
    RunConfigPass = function(container, prof, groups, allowCreate)
        configureCalls[#configureCalls + 1] = {
            container = container, profile = prof, groups = groups, allowCreate = allowCreate,
        }
        container._quiProfile = prof
        return true
    end,
}
ns.AuraSurface = { ApplyElementPass = function() return true end }
ns.Addon = { AuraSkin = { LayoutAnchor = function() return "TOPLEFT" end } }
local polarityMismatch = {}
ns.AuraSlots = {
    DynamicGroups = function(_container, element, prof)
        local groups = {}
        for _, spellID in ipairs(element.spells or {}) do
            if type(spellID) == "number" then
                groups[#groups + 1] = {
                    key = "d" .. tostring(#groups + 1), spellID = spellID,
                    maxFrameCount = 1, elementSpacing = 0, groupSpacing = prof.spacing,
                }
            end
        end
        return groups
    end,
    LivePolarityMismatch = function(unit) return polarityMismatch[unit] == true end,
}
ns.QUI_LayoutMode = { RegisterElement = function() end, UnregisterElement = function() end }
ns.SafeCall = function(_, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then fail("runtime SafeCall failed: " .. tostring(result)) end
    return ok, result
end
ns.SafeCallMethod = function(_, target, method, ...) return target[method](target, ...) end

assert(loadfile("modules/trackers/aura_displays.lua"))("QUI", ns)
local AD = ns.QUI_AuraDisplays

local function Tracked(spells, extra)
    local e = { mode = "tracked", displayType = "icon", spells = spells, auraType = "HELPFUL" }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

local A = AD.NewDisplay("Proc A", "Procs")
A.auras = { enabled = true, _elements = { Tracked({ 101 }) } }
local B = AD.NewDisplay("Proc B", "Procs")
B.auras = { enabled = true, _elements = { Tracked({ 102, 103 }, { spacing = 2 }) } }
local C = AD.NewDisplay("Target Thing", "Procs")
C.unit = "target"
C.auras = { enabled = true, _elements = { Tracked({ 104 }) } }
local D = AD.NewDisplay("Strip", "Procs")
D.auras = { enabled = true, _elements = { { mode = "filterStrip" } } }
local group = AD.GetGroup("Procs", true)
group.spacing = 4
group.dynamicLayout = true
AD.Refresh()

local groupHost = AD.GroupHostFor("Procs")
local container = groupHost and groupHost._quiPackContainer
if not container or container.kind ~= "AuraContainer" or container.parent ~= groupHost then
    fail("a packed group must own one aura container on its host")
end
if container.unit ~= "player" or container.enabled ~= true or not container.shown then
    fail("the pack container must watch the shared unit, be enabled and shown")
end
local call = configureCalls[#configureCalls]
if call.container ~= container or type(call.groups) ~= "table" or #call.groups ~= 3 then
    fail("pack container must be configured with one group per packed spell, got "
        .. tostring(call and call.groups and #call.groups))
end
local g = call.groups
if g[1].spellID ~= 101 or g[2].spellID ~= 102 or g[3].spellID ~= 103 then
    fail("packed groups must follow display order then spell order")
end
if g[1].key == g[2].key or g[2].key == g[3].key or not g[1].key:find("^p" .. A.id) then
    fail("packed group keys must be unique and carry the display id")
end
if g[1].groupSpacing ~= 4 or g[2].groupSpacing ~= 4 or g[3].groupSpacing ~= 2 then
    fail("gap between displays is the group spacing; gaps inside a display keep element spacing")
end
if g[2].profile ~= g[3].profile or g[1].profile == g[2].profile
    or g[1].elementWidth ~= 10 or g[1].elementHeight ~= 10 then
    fail("each packed group must carry its display's own profile and icon size")
end
if call.profile.grow ~= "RIGHT" or call.profile.spacing ~= 4 or call.profile.wrap ~= "DOWN"
    or call.profile.crossEnd ~= nil then
    fail("container profile must follow the group's growth and alignment")
end
if AD.HostFor(A.id).shown or AD.HostFor(B.id).shown then
    fail("packed displays must hide their own hosts")
end
if not AD.HostFor(C.id).shown or AD.HostFor(C.id).parent ~= groupHost then
    fail("a display on another unit must keep its own host in the group")
end
-- Block: A(10) + 4 + B(10+2+10) = 36 wide; then C(10) and D(10) with 4px gaps.
if groupHost.width ~= 64 or groupHost.height ~= 10 then
    fail(("group extent must reserve the full packed block, got %sx%s")
        :format(tostring(groupHost.width), tostring(groupHost.height)))
end
local p = container.point
if not p or p[1] ~= "LEFT" or p[2] ~= groupHost or p[3] ~= "TOPLEFT" or p[4] ~= 0 or p[5] ~= -5 then
    fail("RIGHT growth anchors the container's left edge to the block's left edge")
end
if AD.HostFor(C.id).point[4] ~= 45 or AD.HostFor(D.id).point[4] ~= 59 then
    fail("unpacked members must flow after the packed block")
end

-- Toggle off: hosts return to fixed positions and the container parks.
local configuresBefore = #configureCalls
group.dynamicLayout = false
AD.Refresh()
if not AD.HostFor(A.id).shown or not AD.HostFor(B.id).shown then
    fail("fixed layout must show every member host again")
end
if AD.HostFor(A.id).point[4] ~= 5 or AD.HostFor(B.id).point[4] ~= 25 then
    fail("fixed layout must reserve each display its own position")
end
if container.enabled ~= false or container.shown then
    fail("an unused pack container must be disabled and hidden")
end
local park = configureCalls[configuresBefore + 1]
if not park or park.container ~= container or #park.groups ~= 0 then
    fail("parking must configure the container with no groups")
end
local afterPark = #configureCalls
AD.Refresh()
if #configureCalls ~= afterPark then fail("a parked container must not be re-parked every refresh") end

-- Layout Mode suspends packing so every display is visible and draggable.
group.dynamicLayout = true
layoutModeActive = true
AD.Refresh()
if not AD.HostFor(A.id).shown or container.shown then
    fail("Layout Mode must suspend packing")
end
layoutModeActive = false

-- LEFT growth aligned END: anchor the container's bottom-right to the block.
group.growDirection = "LEFT"
group.alignment = "END"
AD.Refresh()
p = container.point
if not p or p[1] ~= "BOTTOMRIGHT" or p[4] ~= 64 or p[5] ~= -10 then
    fail(("LEFT/END must anchor BOTTOMRIGHT at the block's right edge, got %s %s %s")
        :format(tostring(p and p[1]), tostring(p and p[4]), tostring(p and p[5])))
end
if configureCalls[#configureCalls].profile.wrap ~= "UP" then
    fail("END alignment on a horizontal flow anchors icons to the bottom edge")
end

-- DOWN growth aligned END: vertical flow with the cross axis on the right.
group.growDirection = "DOWN"
AD.Refresh()
p = container.point
local prof = configureCalls[#configureCalls].profile
if not p or p[1] ~= "TOPRIGHT" or prof.grow ~= "DOWN" or prof.crossEnd ~= true then
    fail("DOWN/END must anchor TOPRIGHT with a right-aligned vertical flow")
end
if groupHost.height ~= 64 or groupHost.width ~= 10 then
    fail("vertical packing reserves the block along the vertical axis")
end

-- Centered growth keeps the container centered so icons pack toward the middle.
group.growDirection = "CENTER_H"
group.alignment = "CENTER"
AD.Refresh()
if container.point[1] ~= "CENTER" then fail("CENTER_H growth anchors the container by its center") end

-- A live polarity mismatch keeps those displays out of the pack; the next
-- packable display (here the target one) then defines the pack's unit.
group.growDirection = "RIGHT"
polarityMismatch.player = true
AD.Refresh()
local mismatchCall = configureCalls[#configureCalls]
if not AD.HostFor(A.id).shown or not AD.HostFor(B.id).shown or AD.HostFor(C.id).shown
    or container.unit ~= "target" or #mismatchCall.groups ~= 1 or mismatchCall.groups[1].spellID ~= 104 then
    fail("displays failing the live polarity probe must not pack; others still may")
end
polarityMismatch.player = nil
polarityMismatch.target = true
AD.Refresh()
if not container.shown or container.unit ~= "player" or not AD.HostFor(C.id).shown then
    fail("the first packable display defines the pack unit; mismatched ones stay fixed")
end
polarityMismatch.target = nil

-- Mid-combat refreshes must not resurrect packed hosts: the reflow is
-- deferred in combat, so a per-display refresh showing them would paint a
-- stray copy of the group at their birth spot (screen center).
group.growDirection = "RIGHT"
group.alignment = "CENTER"
AD.Refresh()
if AD.HostFor(A.id).shown or AD.HostFor(B.id).shown then fail("packed hosts start hidden") end
InCombatLockdown = function() return true end
AD.Refresh()
if AD.HostFor(A.id).shown or AD.HostFor(B.id).shown then
    fail("a combat refresh must keep packed display hosts hidden")
end
if not container.shown or not AD.HostFor(C.id).shown then
    fail("a combat refresh must leave the packed container and placed hosts alone")
end
InCombatLockdown = function() return false end

-- A grouped display that activates mid-combat has never been placed by the
-- reflow: it must stay hidden until the deferred reflow runs after combat.
local late = AD.NewDisplay("Late", "Procs")
late.enabled = false
late.unit = "target"   -- not packable (other unit): takes the fixed-placement path
late.auras = { enabled = true, _elements = { Tracked({ 105 }) } }
AD.Refresh()
local lateHost = AD.HostFor(late.id)
if not lateHost or lateHost.shown or lateHost.parent ~= UIParent then
    fail("an inactive grouped display keeps an unplaced, hidden host")
end
late.enabled = true
InCombatLockdown = function() return true end
AD.Refresh()
if lateHost.shown then fail("a display activating in combat must not show before the group places it") end
InCombatLockdown = function() return false end
AD.Refresh()
-- Block 36, then C, D and the late display with 4px gaps: 36+4+10+4+10+4+5.
if not lateHost.shown or lateHost.parent ~= groupHost or lateHost.point[4] ~= 73 then
    fail("after combat the reflow places and shows the activated display")
end
if AD.HostFor(A.id).shown or not container.shown then
    fail("packing must still hold after the late display was placed")
end
late.enabled = false
AD.Refresh()

-- A group with nothing packable never creates a container.
local lone = AD.NewDisplay("Lone Strip", "Strips")
lone.auras = { enabled = true, _elements = { { mode = "filterStrip" } } }
AD.GetGroup("Strips", true).dynamicLayout = true
AD.Refresh()
if AD.GroupHostFor("Strips")._quiPackContainer then
    fail("a group without packable displays must not create a pack container")
end

print("PASS: aura_displays_group_pack_test")
