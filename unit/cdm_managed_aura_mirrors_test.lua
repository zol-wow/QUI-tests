-- tests/unit/cdm_managed_aura_mirrors_test.lua
-- Run: lua tests/unit/cdm_managed_aura_mirrors_test.lua
local ns = {}
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_managed_aura_mirrors.lua", "cdm_managed_aura_mirrors.lua")("QUI", ns)
local M = assert(ns.CDMManagedAuraMirrors)

local createdAuraContainers, createdHosts, styled = {}, {}, {}
local function frameBase()
    return {
        shown = false,
        points = {},
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetSize = function(self, w, h) self.size = { w, h } end,
        ClearAllPoints = function(self) self.points = {} end,
        SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
        SetAllPoints = function(self, target) self.allPoints = target end,
        GetFrameLevel = function() return 10 end,
        SetFrameLevel = function(self, level) self.level = level end,
        EnableMouse = function(self, value) self.mouse = value end,
        SetMouseClickEnabled = function(self, value) self.click = value end,
        SetMouseMotionEnabled = function(self, value) self.motion = value end,
    }
end

local function createFrame(kind, _, parent)
    if kind == "AuraContainer" then
        local c = frameBase()
        c.filters = {}
        c.added = {}
        c.refreshes = 0
        c.SetUnit = function(self, unit) self.unit = unit end
        c.SetEnabled = function(self, enabled) self.enabled = enabled end
        c.UpdateAllAuras = function(self) self.refreshes = self.refreshes + 1 end
        c.AddAuraSlot = function(self, key, filter, options)
            local button = frameBase()
            options.initializeFrame(button)
            self.added[#self.added + 1] = { key = key, filter = filter, options = options, frame = button }
            self.filters[key] = options.candidateFilters
            return button
        end
        c.SetAuraSlotFilterString = function(self, key, filter) self.lastFilter = { key, filter } end
        c.SetAuraSlotCandidateFilters = function(self, key, filters)
            self.filters[key] = filters
            self.candidateWrites = (self.candidateWrites or 0) + 1
        end
        createdAuraContainers[#createdAuraContainers + 1] = c
        return c
    end
    local host = frameBase()
    host.parent = parent
    createdHosts[#createdHosts + 1] = host
    return host
end

local manager = M.New({
    createFrame = createFrame,
    canCreate = function() return true end,
    canMutate = function() return true end,
    styleFrame = function(frame, profile) styled[#styled + 1] = { frame, profile } end,
    positionBase = function(icon, host, rowConfig)
        icon.host, icon.rowConfig = host, rowConfig
    end,
})
local owner = {}
assert(manager:BeginPass(owner) == true, "first pass creates the managed container")
local entry = { type = "spell", id = 100, overrideSpellID = 101, linkedSpellIDs = { 102, 100 } }
local record = manager:Acquire(owner, "essential:1:spell:100", entry, { iconSize = 32 })
assert(record and #record.slots == 3, "one exact managed slot is created per unique priority ID")
assert(#createdAuraContainers == 1 and #createdHosts == 1, "container and stable placement host are pooled")
assert(createdAuraContainers[1].unit == "player" and createdAuraContainers[1].enabled == true,
    "managed aura source is the enabled player unit")
local petManager = M.New({ createFrame = createFrame, unit = "pet" })
local petOwner = {}
assert(petManager:BeginPass(petOwner) == true
    and createdAuraContainers[2].unit == "pet",
    "managed aura sources must support pet-unit overlays")
petManager:EndPass(petOwner)
assert(record.slots[1].spellID == 101 and record.slots[2].spellID == 100
    and record.slots[3].spellID == 102, "candidate priority is override, primary, linked")
assert(record.slots[1].frame.allPoints == record.host and record.slots[1].frame.mouse == false,
    "restricted aura child anchors at birth and leaves interaction to the base icon")

local base = {}
assert(manager:Position(record, base, owner, 4, -5, 30, 20, { size = 30 }) == true,
    "placement moves the stable host and positions the owned base")
assert(record.host.points[1][2] == owner and record.host.size[1] == 30 and record.host.size[2] == 20,
    "host receives the layout rect")
assert(base.host == record.host, "owned base follows the stable host")

local overlayBase = frameBase()
assert(manager:PositionOverlay(record, overlayBase, owner, 0, 0, 30, 20, { size = 30 }) == true,
    "overlay placement must position the native aura host without moving the base icon")
assert(record.host.points[1][2] == overlayBase and record.host.size[1] == 30
    and record.host.size[2] == 20 and record.host.level == 30,
    "overlay placement must anchor and layer the native aura host above the base icon")
assert(overlayBase.host == nil, "overlay placement must leave the owned cooldown icon untouched")

manager:Refresh()
assert(createdAuraContainers[1].refreshes == 1,
    "aura overlay refresh should forward UNIT_AURA changes to the native container")

manager:EndPass(owner)
assert(record.parked == false, "used record remains live at pass end")
manager:BeginPass(owner)
manager:EndPass(owner)
assert(record.parked == true and record.host.shown == false,
    "unused record is filter-parked and its host hidden")
for i = 1, #record.slots do
    assert(createdAuraContainers[1].filters[record.slots[i].key].maxDuration == 0,
        "every retired exact slot receives the impossible park filter")
end

-- Placement keys embed the container ordinal, so every Composer reorder,
-- add, or removal retires the old keys. Frames and managed aura slots are
-- permanent in-game, so churn must recycle rather than mint.
-- A record only retires at EndPass, so a churned key recycles one pass later:
-- the pool settles on a recycled pair instead of one host frame per pass.
local hostCount = #createdHosts
local slotCount = #createdAuraContainers[1].added
local pool = manager._pools[owner]
local churnEntry = { type = "spell", id = 100, overrideSpellID = 101, linkedSpellIDs = { 102 } }
for i = 2, 60 do
    manager:BeginPass(owner)
    local churned = manager:Acquire(owner, "essential:" .. i .. ":spell:100", churnEntry, {})
    assert(churned and churned.free == false and churned.parked == false,
        "each churned placement resolves to a live record")
    manager:EndPass(owner)
end
assert(#createdHosts == hostCount + 1,
    "sustained configuration churn settles on a recycled pair, not one host per pass")
assert(#createdAuraContainers[1].added == slotCount * 2,
    "recycled records reuse their permanent managed aura slots")

local liveKeys = 0
for _ in pairs(pool.records) do liveKeys = liveKeys + 1 end
assert(liveKeys == 2, "retired placement keys are released instead of accumulating")
assert(createdAuraContainers[1].filters[record.slots[1].key].includeSpellIDs[101] == true,
    "recycled slots re-point at the current candidate IDs")

-- Two live placements in one pass must never be handed the same record.
manager:BeginPass(owner)
local first = manager:Acquire(owner, "concurrent:a", churnEntry, {})
local second = manager:Acquire(owner, "concurrent:b", churnEntry, {})
manager:EndPass(owner)
assert(first and second and first ~= second, "concurrent placements get distinct records")
assert(#createdHosts <= hostCount + 2,
    "concurrent demand mints at most one host beyond the recycled pair")

-- Reclaiming a key whose record still sits in the free list must not leave a
-- stale entry that later hands the same live record to a second placement.
manager:BeginPass(owner)
manager:EndPass(owner)
manager:BeginPass(owner)
local revived = manager:Acquire(owner, "concurrent:a", churnEntry, {})
local other = manager:Acquire(owner, "concurrent:z", churnEntry, {})
manager:EndPass(owner)
assert(revived == first, "a retired record is reclaimed by its own placement key")
assert(other ~= revived, "a record is never handed to two placements at once")

-- Reclaiming by key must remove that record's free entry, not leave it behind:
-- a skipped-stale-entry list would grow by one on every retire/reclaim cycle.
local recordCount = 0
for _ in pairs(pool.records) do recordCount = recordCount + 1 end
local settledHosts = #createdHosts
for _ = 1, 40 do
    manager:BeginPass(owner)
    manager:EndPass(owner)
    manager:BeginPass(owner)
    assert(manager:Acquire(owner, "concurrent:a", churnEntry, {}) == first,
        "a reclaimed key keeps resolving to its own record")
    manager:EndPass(owner)
    assert(#pool.free <= recordCount,
        "the free list stays bounded by the record count, not the cycle count")
end
assert(#createdHosts == settledHosts, "retire/reclaim cycles mint no hosts")
local settledKeys = 0
for _ in pairs(pool.records) do settledKeys = settledKeys + 1 end
assert(settledKeys == recordCount, "retire/reclaim cycles leak no placement keys")

local blocked = M.New({ createFrame = createFrame, canCreate = function() return false end })
assert(blocked:BeginPass({}) == false, "first-time container creation fails closed when forbidden")

local restricted = false
local guarded = M.New({
    createFrame = createFrame,
    canCreate = function() return not restricted end,
    canMutate = function() return not restricted end,
    aurasAreSecret = function() return restricted end,
})
local guardedOwner = {}
assert(guarded:BeginPass(guardedOwner))
local guardedEntry = { id = 1307927, kind = "aura" }
local prepared = guarded:Acquire(guardedOwner, "prepared", guardedEntry, {})
assert(prepared)
local guardedContainer = guarded._pools[guardedOwner].auraContainer
local function restrictedMutation() error("native slots cannot be reconfigured through a rejected pass") end
guardedContainer.SetAuraSlotFilterString = restrictedMutation
guardedContainer.SetAuraSlotCandidateFilters = restrictedMutation
guardedContainer.AddAuraSlot = restrictedMutation
restricted = true
assert(not guarded:BeginPass(guardedOwner))
assert(guarded:Acquire(guardedOwner, "prepared", guardedEntry, {}) == prepared)
assert(guarded:Acquire(guardedOwner, "new", guardedEntry, {}) == nil)
assert(guarded:Acquire(guardedOwner, "prepared", { id = 1237205, kind = "aura" }, {}) == nil)
assert(not guarded:EndPass(guardedOwner))
assert(not prepared.free and not prepared.parked)

local stable = M.New({ createFrame = createFrame })
local stableOwner = {}
local stableEntry = { id = 100, linkedSpellIDs = { 101, 102 } }
stable:BeginPass(stableOwner)
local stableRecord = stable:Acquire(stableOwner, "stable", stableEntry, {})
stable:EndPass(stableOwner)
local stableContainer = stable._pools[stableOwner].auraContainer
local function acquireStable(candidate, key)
    stable:BeginPass(stableOwner)
    local acquired = stable:Acquire(stableOwner, key or "stable", candidate, {})
    stable:EndPass(stableOwner)
    return acquired
end
for _ = 1, 100 do acquireStable(stableEntry) end
assert((stableContainer.candidateWrites or 0) == 0,
    "unchanged layout passes must not reset native slot candidates and force full aura rebuilds")
acquireStable({ id = 100 })
assert(stableContainer.candidateWrites == 2,
    "shrinking candidates must park only the two removed slots")
for _ = 1, 100 do acquireStable({ id = 100 }) end
assert(stableContainer.candidateWrites == 2,
    "already parked surplus slots must not force rebuilds on later layouts")
acquireStable(stableEntry)
assert(stableContainer.candidateWrites == 4,
    "restoring candidates must reactivate both parked slots even with their previous spell IDs")
for i, id in ipairs({ 100, 101, 102 }) do
    assert(stableContainer.filters[stableRecord.slots[i].key].includeSpellIDs[id],
        "restored slots must match the current aura candidates")
end
acquireStable({ id = 100, linkedSpellIDs = { 101, 103 } })
assert(stableContainer.candidateWrites == 5
    and stableContainer.filters[stableRecord.slots[3].key].includeSpellIDs[103],
    "an in-place candidate edit must update only the changed native slot")
stable:BeginPass(stableOwner)
stable:EndPass(stableOwner)
assert(stableContainer.candidateWrites == 8, "retiring a record must park all three active slots")
assert(acquireStable(stableEntry, "recycled") == stableRecord,
    "retired records must remain reusable under another placement key")
assert(stableContainer.candidateWrites == 11,
    "recycled records must restore every parked candidate, including unchanged spell IDs")
for i, id in ipairs({ 100, 101, 102 }) do
    assert(stableContainer.filters[stableRecord.slots[i].key].includeSpellIDs[id],
        "recycled native slots must display the new placement's candidates")
end

print("OK: cdm_managed_aura_mirrors_test")
