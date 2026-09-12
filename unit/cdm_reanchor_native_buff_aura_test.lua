local ns = {}
local containers, slots = {}, {}
local apiAccesses = 0
local animationsCreated, pointsCreated, animationPlays = 0, 0, 0
local candidateWrites = 0
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
        GetSize = function(self) return self.width, self.height end,
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
        SetVertexColor = function() end,
        SetTexCoord = function() end,
        SetBlendMode = function() end,
        SetColorTexture = function() end,
        CreateTexture = function(self) return Frame(self.layoutRestricted) end,
        CreateAnimationGroup = function()
            return {
                Stop = function() end,
                RemoveAnimations = function() end,
                SetLooping = function() end,
                Play = function() animationPlays = animationPlays + 1 end,
                CreateAnimation = function(_, kind)
                    assert(kind == "Path")
                    animationsCreated = animationsCreated + 1
                    return {
                        SetTarget = function() end,
                        SetDuration = function() end,
                        SetCurveType = function() end,
                        CreateControlPoint = function()
                            pointsCreated = pointsCreated + 1
                            return { SetOffset = function() end }
                        end,
                    }
                end,
            }
        end,
        RegisterForClicks = function() end,
        SetMouseClickEnabled = function() end,
        SetMouseMotionEnabled = function() end,
    }
end
CreateFrame = function(kind, _, parent, template)
    local frame = Frame(kind == "AuraContainer" or template == "DisableUntrustedLayoutScriptsTemplate"
        or parent and parent.layoutRestricted)
    if kind == "AuraContainer" then
        frame.SetUnit = function(self, unit) self.unit = unit end
        frame.SetEnabled = function(self, enabled) self.enabled = enabled end
        if template ~= "CustomAuraContainerTemplate" then return frame end
        frame.groups = {}
        frame.SetFlowLayoutAxis = function(self, value) self.axis = value end
        frame.SetFlowLayoutAnchorPoint = function(self, value) self.anchor = value end
        frame.SetFlowLayoutGrowthDirection = function(self, horizontal, vertical)
            self.flowHorizontal, self.flowVertical = horizontal, vertical
        end
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
            candidateWrites = candidateWrites + 1
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
ns._OwnedGlows = { ResolveGlowForEntry = function()
    return { glowType = "Pixel Glow", lines = 2, thickness = 3 }
end }
ns.Helpers = {}
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
ns.AuraSkin.WireButton = function() end
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
local preparedAnimations, preparedPoints, preparedPlays = animationsCreated, pointsCreated, animationPlays
assert(preparedAnimations > 0 and preparedPoints == preparedAnimations * 5,
    "real reanchor placement must configure native glow paths")
for _ = 1, 100 do
    assert(env.beginAuraMirrorPass(owner))
    assert(runtime:PositionEntries(owner, { placements = placements }, "buff") == 4)
    env.endAuraMirrorPass(owner)
end
assert(#slots == 4, "repeated placement passes must retain prepared native frames")
assert(animationsCreated == preparedAnimations and pointsCreated == preparedPoints,
    string.format("unchanged reanchor placement must reuse native animations and control points: %d -> %d animations, %d -> %d points",
        preparedAnimations, animationsCreated, preparedPoints, pointsCreated))
assert(animationPlays == preparedPlays, "unchanged reanchor placement must not restart native animations")
for _, entry in ipairs(entries) do
    local effects = entry.auraMirror.frames[1]._quiCDMNativeProcGlow
    assert(#effects > 0 and entry.frame._quiNativeProcGlows[effects],
        "cached native effects must re-register after placement resets proc ownership")
end
print("OK: repeated realenv placements preserve native glow animations and proc registration")
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
local nativeFlowFile = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua"))
local nativeFlowSource = nativeFlowFile:read("*a")
nativeFlowFile:close()
secretwrap = function(...) return ... end
assert((loadstring or load)(nativeFlowSource:sub((assert(nativeFlowSource:find(
    "CustomAuraContainerFlowLayoutMixin =", 1, true))))))()
local function layoutNative(host, active)
    local flow = CreateFromMixins(_G.CustomAuraContainerFlowLayoutMixin)
    flow:Init()
    flow:SetLayoutAxis(host.axis)
    flow:SetAnchorPoint(host.anchor)
    flow:SetGrowthDirection(host.flowHorizontal, host.flowVertical)
    local groups = {}
    for _, slot in ipairs(slots) do
        if slot.container == host and slot.options.maxFrameCount > 0 then
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
assert(regrouped[1].auraMirror.host ~= regrouped[2].auraMirror.host,
    "a filtered Blizzard entry must preserve the native run boundary")
local leadingHost = regrouped[1].auraMirror.host
combat = true
nativeB.active = true
local expanded = layoutCombatEntries()
assert(expanded[1].auraMirror.host == leadingHost
    and expanded[3].auraMirror.host ~= leadingHost)
assert(leadingHost.point[2] == owner,
    "the leading native host must keep its container anchor when a middle native icon reappears")
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

layoutCombatEntries()
local candidateWritesBefore = candidateWrites
for _ = 1, 100 do layoutCombatEntries() end
assert(candidateWrites == candidateWritesBefore,
    "unchanged native buff layout must not request full aura rebuilds: " .. (candidateWrites - candidateWritesBefore))
auraA.linkedSpellIDs = { 910004 }
local updated = layoutCombatEntries()
local record = updated[1].auraMirror
assert(record.host.groups[record.key].options.candidateFilters.includeSpellIDs[910004],
    "in-place linked-spell changes must update native matching")
auraA.linkedSpellIDs = nil
layoutCombatEntries()
assert(not record.host.groups[record.key].options.candidateFilters.includeSpellIDs[910004],
    "removed linked spells must stop matching")
print("OK: unchanged native buff layouts skip full aura rebuild requests")

assert(loadfile("QUI_CDM/cdm/cdm_layout.lua"))("QUI", ns)
local function anchorFactors(anchor)
    return anchor:find("LEFT") and -.5 or anchor:find("RIGHT") and .5 or 0,
        anchor:find("BOTTOM") and -.5 or anchor:find("TOP") and .5 or 0
end
local function worldCenter(frame)
    if frame == owner then return 0, 0 end
    local point = assert(frame.point)
    local x, y = worldCenter(point[2])
    local ax, ay = anchorFactors(point[1])
    local bx, by = anchorFactors(point[3])
    return x + bx * (point[2].width or 0) + (point[4] or 0) - ax * (frame.width or 0),
        y + by * (point[2].height or 0) + (point[5] or 0) - ay * (frame.height or 0)
end
local function verifyPlannedNativeGeometry(label)
    assert(env.beginAuraMirrorPass(owner))
    local result = runtime:AssembleEntries("buff", {}, settings)
    local plan = ns.CDMLayout.BuildIconLayout(settings, result)
        or ns.CDMLayout.BuildBuffGridLayout(settings, result)
    runtime:PositionEntries(owner, plan, "buff")
    env.endAuraMirrorPass(owner)
    local active = {}
    for _, entry in ipairs(curated) do active[entry.id] = true end
    for _, host in ipairs(containers) do
        if host.enabled then layoutNative(host, active) end
    end
    for _, placement in ipairs(plan.placements) do
        local wrapper = placement.icon
        if wrapper.auraMirror then
            local button = wrapper.auraMirror.frames[1]
            local x, y = worldCenter(button)
            assert(math.abs(x - placement.x) < .001 and math.abs(y - placement.y) < .001,
                string.format("%s: planned (%g,%g), native (%g,%g)", label, placement.x, placement.y, x, y))
            local rc = placement.rowConfig
            assert(button.width == rc.size and button.height == rc.size / rc.aspectRatioCrop,
                label .. ": native size must match planned size")
        end
    end
    return result, plan
end
settings.iconDisplayMode = "active"
curated = { auraA, auraC }
matched, frameless = {}, curated
settings.row1 = { iconCount = 2, iconSize = 32, padding = 2 }
for _, case in ipairs({ { "HORIZONTAL", "UP" }, { "VERTICAL", "CENTERED_HORIZONTAL" } }) do
    settings.layoutDirection, settings.growthDirection = case[1], case[2]
    verifyPlannedNativeGeometry(case[1] .. ":" .. case[2])
end
settings.layoutDirection, settings.growthDirection = "HORIZONTAL", "CENTERED_HORIZONTAL"
curated = { auraA, auraC, { id = 910005, type = "spell", kind = "aura" } }
frameless = curated
for _, alignment in ipairs({ "RIGHT", "LEFT", "CENTER" }) do
    settings.row2 = { iconCount = 1, iconSize = 24, padding = 4, growDirection = alignment, xOffset = 7, yOffset = 3 }
    verifyPlannedNativeGeometry("row alignment " .. alignment)
end
settings.row1, settings.row2, settings.layoutDirection = nil, nil, nil
curated = { auraA, auraC }
frameless = curated
for _, direction in ipairs({ "RIGHT", "LEFT", "UP", "DOWN" }) do
    settings.growthDirection = direction
    verifyPlannedNativeGeometry("grid " .. direction)
end
settings.aspectRatioCrop = .5
local _, aspectPlan = verifyPlannedNativeGeometry("portrait buff grid")
assert(aspectPlan.rows[1].size == 16 and aspectPlan.metrics.iconWidth == 16
    and aspectPlan.metrics.totalHeight == 66, "portrait buff grid must retain planned container bounds")
settings.aspectRatioCrop = nil
settings.growthDirection = "CENTERED_HORIZONTAL"
curated = { auraA, nativeBEntry, auraC }
matched, frameless = { { entry = nativeBEntry, frame = nativeB } }, { auraA, auraC }
nativeB:SetSize(32, 32)
nativeB.active = false
verifyPlannedNativeGeometry("Blizzard entry absent")
combat, nativeB.active = true, true
verifyPlannedNativeGeometry("Blizzard entry reappears in combat")
combat = false
print("OK: native aura world coordinates match planned rows, directions, aspect and combat transitions")

local function configureMixed(count)
    curated, matched, frameless = {}, {}, {}
    local blizzard = {}
    for i = 1, count do
        local entry = { id = 950000 + i, type = "spell", kind = "aura" }
        curated[i] = entry
        if i % 2 == 1 then
            entry.source = "blizzardCDM"
            local frame = Frame()
            frame.active = true
            frame:SetSize(32, 32)
            matched[#matched + 1] = { entry = entry, frame = frame }
            blizzard[#blizzard + 1] = frame
        else
            frameless[#frameless + 1] = entry
        end
    end
    return blizzard
end
local function sparseLayout(active)
    assert(env.beginAuraMirrorPass(owner))
    local result = runtime:AssembleEntries("buff", {}, settings)
    local original = {}
    for i, wrapper in ipairs(result) do original[i] = wrapper end
    local plan = ns.CDMLayout.BuildIconLayout(settings, result)
        or ns.CDMLayout.BuildBuffGridLayout(settings, result)
    for i, wrapper in ipairs(result) do
        assert(wrapper == original[i], "tail partition must not mutate the assembled source list")
    end
    runtime:PositionEntries(owner, plan, "buff")
    env.endAuraMirrorPass(owner)
    for _, host in ipairs(containers) do
        if host.enabled then layoutNative(host, active) end
    end
    local byID = {}
    for _, wrapper in ipairs(result) do byID[wrapper.src.id] = wrapper end
    return byID, plan
end
local function assertCenter(frame, x, y, label)
    local actualX, actualY = worldCenter(frame)
    assert(math.abs(actualX - x) < .001 and math.abs(actualY - y) < .001,
        string.format("%s: expected (%g,%g), got (%g,%g)", label, x, y, actualX, actualY))
end
settings = { iconDisplayMode = "active", iconSize = 32, padding = 2 }
local blizzard = configureMixed(5)
for _, direction in ipairs({ "RIGHT", "LEFT", "UP", "DOWN" }) do
    settings.growthDirection = direction
    local vertical = direction == "UP" or direction == "DOWN"
    local sign = (direction == "LEFT" or direction == "DOWN") and -1 or 1
    local function along(frame, offset, label)
        assertCenter(frame, vertical and 0 or offset * sign, vertical and offset * sign or 0,
            direction .. ": " .. label)
    end
    local wrappers, plan = sparseLayout({})
    assert(plan.metrics.iconWidth == (vertical and 32 or 100)
        and plan.metrics.totalHeight == (vertical and 100 or 32),
        direction .. ": mixed bounds must use the dense Blizzard row")
    for i, frame in ipairs(blizzard) do
        along(frame, (i - 2) * 34, "inactive custom buffs must not reserve Blizzard slots")
        assert(frame.point[2] == owner, "Blizzard frames must retain safe container anchors")
    end
    local first = wrappers[950002].auraMirror
    local second = wrappers[950004].auraMirror
    assert(first.host ~= second.host, "moving custom buffs to the tail must preserve prepared run identity")
    assert(wrappers[950002].auraMirrorOptions.order == 2
        and wrappers[950004].auraMirrorOptions.order == 4, "tail order must retain curated source indices")
    wrappers = sparseLayout({ [950002] = true, [950004] = true })
    along(wrappers[950002].auraMirror.frames[1], 68, "first active custom buff follows Blizzard tail")
    along(wrappers[950004].auraMirror.frames[1], 102, "second active custom buff follows native tail")
    wrappers = sparseLayout({ [950004] = true })
    along(wrappers[950004].auraMirror.frames[1], 68, "inactive custom tail leaves no gap")
    for i, frame in ipairs(blizzard) do along(frame, (i - 2) * 34, "custom presence preserves Blizzard positions") end
end
print("OK: sparse mixed buffs retain 2px gaps and dense safe Blizzard bounds in all grid directions")

settings.growthDirection = "RIGHT"
local preparedMixed = sparseLayout({ [950002] = true, [950004] = true })
local firstPrepared = preparedMixed[950002].auraMirror
local secondPrepared = preparedMixed[950004].auraMirror
combat = true
for _, frame in ipairs(blizzard) do frame.active = false end
local onlyCustom, onlyCustomPlan = sparseLayout({ [950004] = true })
assert(onlyCustom[950002].auraMirror == firstPrepared and onlyCustom[950004].auraMirror == secondPrepared,
    "combat disappearance must reuse both prepared custom records")
assert(onlyCustomPlan.metrics.iconWidth == 66, "custom-only rows retain their configured capacity bounds")
assertCenter(onlyCustom[950004].auraMirror.frames[1], -17, 0,
    "empty leading custom group must collapse after all Blizzard buffs disappear")
for _, frame in ipairs(blizzard) do frame.active = true end
local restoredMixed = sparseLayout({ [950004] = true })
assert(restoredMixed[950002].auraMirror == firstPrepared and restoredMixed[950004].auraMirror == secondPrepared,
    "combat reappearance must reuse both prepared custom records")
for i, frame in ipairs(blizzard) do assertCenter(frame, (i - 2) * 34, 0, "combat reappearance dense Blizzard row") end
assertCenter(restoredMixed[950004].auraMirror.frames[1], 68, 0, "combat reappearance sparse custom tail")
combat = false
print("OK: sparse mixed tails survive all Blizzard buffs disappearing and reappearing in combat")

blizzard = configureMixed(6)
blizzard[3]:SetSize(24, 24)
settings.layoutDirection = "HORIZONTAL"
settings.row1 = { iconCount = 3, iconSize = 32, padding = 2 }
settings.row2 = { iconCount = 3, iconSize = 24, padding = 4, xOffset = 7, yOffset = 3 }
local rowWrappers, rowPlan = sparseLayout({ [950006] = true })
assertCenter(blizzard[1], -17, 13, "first row first Blizzard buff")
assertCenter(blizzard[2], 17, 13, "first row second Blizzard buff")
assertCenter(blizzard[3], 7, -14, "second row Blizzard buff keeps row offsets")
assertCenter(rowWrappers[950006].auraMirror.frames[1], 35, -14, "second row sparse tail keeps 4px padding")
assert(rowPlan.metrics.iconWidth == 66 and rowPlan.metrics.totalHeight == 58,
    "mixed row bounds must retain row heights while excluding custom tail capacity")
local expectedRows = { [950001] = 1, [950002] = 1, [950003] = 1, [950004] = 2, [950005] = 2, [950006] = 2 }
for _, placement in ipairs(rowPlan.placements) do
    local expected = expectedRows[placement.icon.src.id]
    assert(placement.rowConfig.rowNum == expected, "tail partition must preserve original row assignment")
    if placement.icon.auraMirror then
        local button = placement.icon.auraMirror.frames[1]
        assert(button.width == (expected == 1 and 32 or 24), "custom tail must retain row icon size")
    end
end
assert(apiAccesses == 0, "sparse packing must leave native aura presence and geometry opaque")
print("OK: mixed tail partition preserves row assignment, style, offsets, and native ownership")

settings = { iconDisplayMode = "active", iconSize = 32, padding = 2, growthDirection = "RIGHT" }
blizzard = configureMixed(5)
local layoutEnv = ns.CDMReanchorRealEnv.BuildEnv({
    CDMContainers = { GetContainer = function() return owner end },
    getSettings = function() return settings end,
})
runtime._deps.getContainer = layoutEnv.getContainer
runtime._deps.getSettings = layoutEnv.getSettings
runtime._deps.buildLayout = layoutEnv.buildLayout
runtime._deps.buildBuffLayout = layoutEnv.buildBuffLayout
runtime._deps.beginAuraMirrorPass = env.beginAuraMirrorPass
runtime._deps.endAuraMirrorPass = env.endAuraMirrorPass
local refreshMetrics
runtime._deps.applySize = function(_, metrics) refreshMetrics = metrics end
runtime._wiring.GetViewerForKey = function() return owner end
runtime._wiring.BuildFrameMap = function() return {}, {} end
assert(runtime:RefreshContainer("buff") == 5)
assert(refreshMetrics.iconWidth == 100, "realenv grid fallback must apply dense Blizzard metrics during refresh")
for i, frame in ipairs(blizzard) do assertCenter(frame, (i - 2) * 34, 0, "refresh uses compact grid plan") end
settings.row1 = { iconCount = 5, iconSize = 32, padding = 2 }
assert(runtime:RefreshContainer("buff") == 5)
assert(refreshMetrics.iconWidth == 100, "realenv row planner must apply dense Blizzard metrics during refresh")
for i, frame in ipairs(blizzard) do assertCenter(frame, (i - 2) * 34, 0, "refresh uses compact row plan") end
print("OK: real RefreshContainer dispatch uses compact row and grid plans")

for _, mode in ipairs({ "always", "combat", "preview" }) do
    settings.iconDisplayMode = mode == "preview" and "active" or mode
    combat = mode == "combat"
    runtime._deps.isEditMode = function() return mode == "preview" end
    local reserved = runtime:AssembleEntries("buff", {}, settings)
    for _, build in ipairs({ ns.CDMLayout.BuildIconLayout, ns.CDMLayout.BuildBuffGridLayout }) do
        local plan = build(settings, reserved)
        assert(plan.metrics.iconWidth == 168, mode .. ": reserved icons retain configured bounds")
        for i, placement in ipairs(plan.placements) do
            assert(placement.icon.src == curated[i], mode .. ": reserved icons retain configured mixed order")
            assert(not placement.icon.auraMirrorOptions or not placement.icon.auraMirrorOptions.dynamic,
                mode .. ": reserved icons must not opt into dynamic tails")
        end
    end
end
combat = false
runtime._deps.isEditMode = nil
assert(apiAccesses == 0, "refresh and reserved layouts must not query native aura state")
print("OK: always, combat-reserved, and preview layouts preserve configured mixed slots")
