local ns = {}
local containers, slots = {}, {}
local apiAccesses = 0
local combat = false
AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
    FlowDirection = { Right = 1, Left = -1, Up = 1, Down = -1 } }
C_UnitAuras = setmetatable({}, { __index = function(_, key)
    apiAccesses = apiAccesses + 1
    error("unexpected aura API: " .. key)
end })
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
local function Frame(layoutRestricted)
    return {
        layoutRestricted = layoutRestricted,
        shown = false,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        ClearAllPoints = function(self) self.point = nil end,
        SetPoint = function(self, point, relative, ...)
            assert(not relative.layoutRestricted or self.layoutRestricted,
                "Anchoring disallowed: dependent would inherit UntrustedLayoutScriptExecution")
            self.point = { point, relative, ... }
        end,
        SetAllPoints = function() end,
        SetFrameLevel = function() end,
        GetFrameLevel = function() return 1 end,
        EnableMouse = function() end,
        SetAttribute = function() end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        RegisterForClicks = function() end,
        SetMouseClickEnabled = function() end,
        SetMouseMotionEnabled = function() end,
    }
end
CreateFrame = function(kind, _, _, template)
    local frame = Frame(kind == "AuraContainer" or template == "DisableUntrustedLayoutScriptsTemplate")
    if kind == "AuraContainer" then
        frame.SetUnit = function(self, unit) self.unit = unit end
        frame.SetEnabled = function(self, enabled) self.enabled = enabled end
        if template ~= "CustomAuraContainerTemplate" then return frame end
        frame.groups = {}
        frame.SetFlowLayoutAxis = function(self, value) self.axis = value end
        frame.SetFlowLayoutAnchorPoint = function(self, value) self.anchor = value end
        frame.SetFlowLayoutGrowthDirection = function() end
        frame.SetFlowLayoutMaximumLineSize = function() end
        frame.SetAuraGroupLayout = function(self, key, layout) self.groups[key].options.layout = layout end
        frame.GetWidth = function() error("native width is secret") end
        frame.GetHeight = function() error("native height is secret") end
        frame.AddAuraSlot = function(self, key, filter, opts)
            local button = Frame(true)
            button.IsShown = function() error("native presence must remain opaque") end
            button.GetAuraData = function() error("native aura data must remain opaque") end
            button.SetScript = function() error("native scripts belong to Blizzard") end
            opts.initializeFrame(button)
            slots[#slots + 1] = { container = self, key = key, filter = filter, options = opts, button = button }
            self.groups[key] = slots[#slots]
            return button
        end
        frame.AddAuraGroup = frame.AddAuraSlot
        frame.SetAuraGroupFilterString = function(self, key, filter)
            assert(not combat, "native aura filters must not change in combat")
            self.groups[key].filter = filter
        end
        frame.SetAuraGroupCandidateFilters = function(self, key, filters)
            assert(not combat, "native aura candidates must not change in combat")
            self.groups[key].options.candidateFilters = filters
        end
        frame.SetAuraGroupMaxFrameCount = function(self, key, count) self.groups[key].options.maxFrameCount = count end
        frame.SetAuraSlotFilterString = function() end
        frame.SetAuraSlotCandidateFilters = function(self, _, filter) self.lastFilter = filter end
        containers[#containers + 1] = frame
    end
    return frame
end
ns._OwnedSwipe = { GetSettings = function() return { showCooldownIconAuraPhase = false } end }
ns.Helpers = {}
ns.AuraSkin = { WireButton = function() end }
ns.CDMSpellData = { GetCapturedAuraForLookup = function() error("captured aura state is removed") end }
for _, name in ipairs({ "cdm_managed_aura_mirrors", "cdm_custom_aura_runs", "cdm_reanchor_realenv", "cdm_reanchor", "cdm_reanchor_runtime", "cdm_placement_planner" }) do
    assert(loadfile("QUI_CDM/cdm/" .. name .. ".lua"))("QUI", ns)
end
local owner = Frame()
local settings = { iconDisplayMode = "active", iconSize = 32, padding = 2 }
local env = ns.CDMReanchorRealEnv.BuildEnv({
    CDMContainers = { GetContainer = function() return owner end },
    getSettings = function() return settings end,
})
local curated, matched, frameless = {}, {}, {}
local runtime = ns.CDMReanchorRuntime.New({
    wiring = { MatchCuratedToFrames = function() return matched, frameless, {} end },
    getCurated = function() return curated end,
    inCombat = function() return combat end,
    getAdditional = function() return {} end,
    frameIsActive = function(frame) return frame.active end,
    mintOwned = function() return Frame(true) end,
    releaseOwned = function() end,
    acquireAuraMirror = env.acquireAuraMirror,
    positionAuraMirror = env.positionAuraMirror,
    positionOwned = function() error("native mirror must position the owned placeholder") end,
})
curated = {
    { id = 1307927, type = "spell", kind = "aura" },
    { id = 1237205, type = "spell", kind = "aura" },
    { id = 900003, type = "spell", kind = "aura", auraUnit = "target", auraFilter = "HARMFUL|PLAYER" },
    { id = 900004, type = "spell", kind = "aura", auraUnit = "pet" },
}
local stale = { active = false }
matched = { { entry = curated[2], frame = stale } }
frameless = { curated[1], curated[3], curated[4] }
assert(env.beginAuraMirrorPass(owner))
local entries = runtime:AssembleEntries("buff", {}, { iconDisplayMode = "active" })
assert(#entries == 4, "every non-CDM buff must allocate before native aura presence is known")
local placements = {}
for i, entry in ipairs(entries) do
    placements[i] = { icon = entry, x = i * 32, y = 0, w = 32, h = 32, rowConfig = { size = 32, padding = 2 } }
end
assert(runtime:PositionEntries(owner, { placements = placements }, "buff") == 4)
assert(#containers == 3, "player, target, and pet sources must have independent native containers")
assert(#slots == 4, "arbitrary spell IDs must reach native slots")
for i = 1, #curated do
    assert(entries[i].auraMirror, "missing native mirror")
    assert(slots[i].options.candidateFilters.includeSpellIDs[curated[i].id], "native slot lost configured spell ID")
end
assert(slots[3].container.unit == "target" and slots[3].filter == "HARMFUL|PLAYER")
assert(slots[4].container.unit == "pet")
for _, entry in ipairs(entries) do
    assert(not entry.frame.shown, "active-only must suppress the placeholder without querying native visibility")
    assert(entry.auraMirror.host.shown, "hiding the placeholder must leave native aura host enabled")
end
env.endAuraMirrorPass(owner)
assert(entries[1].auraMirror.dynamic and entries[1].auraMirror.host == entries[2].auraMirror.host)
assert(entries[3].auraMirror.host.point[2] == entries[1].auraMirror.host)
assert(entries[3].auraMirror.host.point[4] == -1)
assert(entries[4].auraMirror.host.point[2] == entries[3].auraMirror.host)
local flowFile = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_SharedXMLBase/AnchorUtil.lua"))
local flowSource = flowFile:read("*a")
flowFile:close()
function CreateFromMixins(mixin)
    local result = {}
    for key, value in pairs(mixin) do result[key] = value end
    return result
end
function GetValueOrCallFunction(owner, key) return owner[key] end
assert((loadstring or load)(flowSource:sub((assert(flowSource:find("AnchorUtil.FlowLayoutAxis =", 1, true))))))()
local function layoutNative(host, active)
    local flow = AnchorUtil.CreateFlowLayout()
    flow:SetLayoutAxis(host.axis)
    flow:SetAnchorPoint(host.anchor)
    function flow:GetElementSize(_, _, group) return group.elementWidth, group.elementHeight end
    local groups = {}
    for _, slot in ipairs(slots) do
        if slot.container == host then
            local group = {}
            for key, value in pairs(slot.options.layout) do group[key] = value end
            local include = slot.options.candidateFilters.includeSpellIDs
            local shown = false
            for id in pairs(include) do if active[id] then shown = true end end
            group.elements = shown and { slot.button } or {}
            groups[#groups + 1] = group
        end
    end
    flow:Apply(host, groups)
end
for _, host in ipairs(containers) do layoutNative(host, {}) end
assert(containers[1].width == 1 and containers[2].width == 1)
layoutNative(containers[1], { [1237205] = true })
assert(containers[1].width == 35, "only active native aura contributes to flow bounds")
assert(slots[2].button.point[4] == 0, "inactive preceding aura must leave no gap")
curated = { curated[1], curated[2] }
matched, frameless = {}, curated
assert(env.beginAuraMirrorPass(owner))
entries = runtime:AssembleEntries("buff", {}, settings)
placements = {}
for i, entry in ipairs(entries) do
    placements[i] = { icon = entry, x = i * 32, y = 0, w = 32, h = 32, rowConfig = { size = 32, padding = 2 } }
end
runtime:PositionEntries(owner, { placements = placements }, "buff")
env.endAuraMirrorPass(owner)
assert(containers[1].point[1] == "CENTER" and containers[1].point[2] == owner)
assert(containers[1].point[4] == 1.5, "native row must remain centered after trailing layout padding")
assert(not containers[2].enabled and not containers[3].enabled)
combat = true
assert(env.beginAuraMirrorPass(owner))
entries = runtime:AssembleEntries("buff", {}, settings)
for i, entry in ipairs(entries) do placements[i].icon = entry end
runtime:PositionEntries(owner, { placements = placements }, "buff")
env.endAuraMirrorPass(owner)
assert(#containers == 3)
combat = false
settings.iconDisplayMode = "combat"
assert(env.beginAuraMirrorPass(owner))
entries = runtime:AssembleEntries("buff", {}, settings)
for i, entry in ipairs(entries) do placements[i].icon = entry end
runtime:PositionEntries(owner, { placements = placements }, "buff")
env.endAuraMirrorPass(owner)
assert(entries[1].auraMirror.host ~= entries[2].auraMirror.host)
assert(not entries[1].frame.shown)
local prepared = #containers
combat = true
assert(env.beginAuraMirrorPass(owner))
entries = runtime:AssembleEntries("buff", {}, settings)
for i, entry in ipairs(entries) do placements[i].icon = entry end
runtime:PositionEntries(owner, { placements = placements }, "buff")
env.endAuraMirrorPass(owner)
assert(#containers == prepared, "combat-mode transition reuses prepared native groups")
for _, entry in ipairs(entries) do
    assert(entry.frame.shown and entry.auraMirror.reserved)
    assert(entry.auraMirror.host.point[2] == entry.frame)
end
combat = false
local native = { active = true }
curated = { { id = 48707, source = "blizzardCDM", kind = "aura" } }
matched = { { entry = curated[1], frame = native } }
frameless = {}
local nativeEntries = runtime:AssembleEntries("buff", {}, { iconDisplayMode = "active" })
assert(#nativeEntries == 1 and nativeEntries[1].frame == native and nativeEntries[1].reanchored,
    "ordinary paired Blizzard icons must remain native")
assert(apiAccesses == 0, "CDM must never touch addon aura APIs")
print("OK: cdm_reanchor_native_buff_aura_test")

settings.iconDisplayMode = "active"
curated = {
    { id = 1307927, type = "spell", kind = "aura" },
    { id = 1237205, type = "spell", kind = "aura" },
    { id = 900003, type = "spell", kind = "aura", auraUnit = "target", auraFilter = "HARMFUL|PLAYER" },
}
matched, frameless = {}, curated
assert(env.beginAuraMirrorPass(owner))
entries = runtime:AssembleEntries("buff", {}, settings)
placements = {
    { icon = entries[1], x = 7, y = 12, w = 32, h = 32,
        rowConfig = { rowNum = 1, size = 32, padding = 2, xOffset = 7 } },
    { icon = entries[2], x = -14, y = -40, w = 24, h = 24,
        rowConfig = { rowNum = 2, size = 24, padding = 4 } },
    { icon = entries[3], x = 14, y = -40, w = 24, h = 24,
        rowConfig = { rowNum = 2, size = 24, padding = 4 } },
}
runtime:PositionEntries(owner, { placements = placements }, "buff")
env.endAuraMirrorPass(owner)
local firstRow = entries[1].auraMirror.host
local secondRow = entries[2].auraMirror.host
assert(firstRow ~= secondRow, "different layout rows must use independent native flow hosts")
assert(firstRow.point[2] == owner and firstRow.point[4] == 8.5 and firstRow.point[5] == 12,
    "a centered native row must retain configured offsets")
assert(secondRow.point[2] == owner and secondRow.point[5] == -40,
    "a second native row must retain its layout position")
assert(entries[3].auraMirror.host.point[2] == secondRow,
    "mixed native routes must pack within their own row")
assert(firstRow.groups.a1.options.layout.elementWidth == 35
    and secondRow.groups.a1.options.layout.elementWidth == 29,
    "each row must retain its icon size and padding")
print("OK: native buff layout preserves rows and offsets")
for _, slot in ipairs(slots) do
    for _, template in ipairs(slot.options.templateNames or {}) do
        assert(template ~= "SecureActionButtonTemplate",
            "Buff Icon native frames have no click actions and must allow combat reanchoring")
    end
end
print("OK: native Buff Icons retain combat reanchoring without secure click templates")
settings.iconDisplayMode = "active"
local auraA = { id = 910001, type = "spell", kind = "aura" }
local nativeBEntry = { id = 910002, type = "spell", kind = "aura", source = "blizzardCDM" }
local auraC = { id = 910003, type = "spell", kind = "aura" }
local nativeB = Frame()
nativeB.active = true
runtime._bridge = ns.CDMReanchor.New({
    hooksecurefunc = function(frame, method, hook)
        local original = frame[method]
        frame[method] = function(self, ...)
            original(self, ...)
            hook(self, ...)
        end
    end,
})
curated = { auraA, nativeBEntry, auraC }
matched = { { entry = nativeBEntry, frame = nativeB } }
frameless = { auraA, auraC }
local function layoutCombatEntries()
    assert(env.beginAuraMirrorPass(owner))
    local result = runtime:AssembleEntries("buff", {}, settings)
    local positions = {}
    for i, wrapper in ipairs(result) do
        positions[i] = { icon = wrapper, x = (i - 2) * 34, y = 0, w = 32, h = 32,
            rowConfig = { rowNum = 1, size = 32, padding = 2 } }
    end
    runtime:PositionEntries(owner, { placements = positions }, "buff")
    env.endAuraMirrorPass(owner)
    return result
end
local beforeCombat = layoutCombatEntries()
local preparedA, preparedC = beforeCombat[1].auraMirror, beforeCombat[3].auraMirror
assert(preparedA.host ~= preparedC.host, "native middle icon must separate prepared runs")
assert(nativeB.point[2] == owner and runtime._bridge:GetData(nativeB).overlayRect.relativeTo == owner,
    "Blizzard buff icons must retain their container rect outside restricted aura dependencies")
assert(preparedC.host.point[2] == nativeB and preparedC.host.point[4] == 2,
    "custom aura runs after a Blizzard icon must retain their padding and follow its safe anchor")
combat = true
nativeB.active = false
local collapsed = layoutCombatEntries()
assert(#collapsed == 2 and collapsed[1].auraMirror == preparedA and collapsed[2].auraMirror == preparedC,
    "combat disappearance must preserve both prepared native aura records")
assert(preparedA.host.alpha == 1 and preparedC.host.alpha == 1,
    "combat disappearance must keep both prepared aura runs visible")
assert(preparedC.host.groups[preparedC.key].options.candidateFilters.includeSpellIDs[auraC.id],
    "combat reuse must retain the entry's prepared candidate filter")
combat = false
local regrouped = layoutCombatEntries()
assert(regrouped[1].auraMirror.host == regrouped[2].auraMirror.host,
    "out-of-combat layout may regroup adjacent native auras")
local sharedHost = regrouped[1].auraMirror.host
combat = true
nativeB.active = true
local expanded = layoutCombatEntries()
assert(expanded[1].auraMirror.host == sharedHost and expanded[3].auraMirror.host == sharedHost)
assert(sharedHost.point[2] == owner,
    "a prepared native host must be positioned once when a middle native icon reappears")
combat = false
print("OK: combat native aura records retain identity across native icon visibility changes")

for _, case in ipairs({
    { "RIGHT", "LEFT", "RIGHT", 2, 0 },
    { "LEFT", "RIGHT", "LEFT", -2, 0 },
    { "UP", "BOTTOM", "TOP", 0, 2 },
    { "DOWN", "TOP", "BOTTOM", 0, -2 },
}) do
    settings.growthDirection = case[1]
    local result = layoutCombatEntries()
    local rect = runtime._bridge:GetData(nativeB).overlayRect
    assert(rect.relativeTo == owner and rect.tlX == -16 and rect.tlY == 16
        and rect.brX == 16 and rect.brY == -16,
        case[1] .. ": Blizzard icon must retain its planned position and size")
    local point = result[3].auraMirror.host.point
    assert(point[1] == case[2] and point[2] == nativeB and point[3] == case[3]
        and point[4] == case[4] and point[5] == case[5],
        case[1] .. ": following native aura must retain growth direction and padding")
    nativeB:SetPoint("CENTER", Frame(), "CENTER", 0, 0)
    assert(nativeB.point[2] == owner,
        "Blizzard layout repairs must reassert the safe container anchor")
end
print("OK: mixed buff rows preserve safe anchors in all growth directions")
