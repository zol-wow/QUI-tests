-- tests/unit/storage_scan_reputations_test.lua
-- Run: lua tests/unit/storage_scan_reputations_test.lua
local loader = dofile("tests/helpers/load_storage_data.lua")
_G.QUI_StorageDB = nil

-- Simulated rep pane: header (collapsed) → child faction; plus a major
-- faction and a paragon faction at top level.
local pane = {
    { factionID = 1100, name = "Old Expansion", isHeader = true, isCollapsed = true, reaction = 4 },
    { factionID = 2600, name = "Renown Folk", isHeader = false, reaction = 8,
      currentStanding = 0, currentReactionThreshold = 0, nextReactionThreshold = 0 },
    { factionID = 2510, name = "Paragon Pals", isHeader = false, reaction = 8,
      currentStanding = 21000, currentReactionThreshold = 21000, nextReactionThreshold = 21000 },
}
local childRow = { factionID = 1133, name = "Old Friends", isHeader = false, reaction = 5,
    currentStanding = 4500, currentReactionThreshold = 3000, nextReactionThreshold = 9000 }
local expanded = false

_G.C_Reputation = {
    GetNumFactions = function() return expanded and 4 or 3 end,
    GetFactionDataByIndex = function(i)
        if not expanded then return pane[i] end
        if i == 1 then return pane[1] end
        if i == 2 then return childRow end
        return pane[i - 1]
    end,
    GetFactionDataByID = function(id)
        for _, f in ipairs({ pane[1], childRow, pane[2], pane[3] }) do
            if f.factionID == id then return f end
        end
    end,
    ExpandFactionHeader = function(i) assert(i == 1); expanded = true; pane[1].isCollapsed = false end,
    CollapseFactionHeader = function(i) expanded = false; pane[1].isCollapsed = true end,
    IsMajorFaction = function(id) return id == 2600 end,
    IsFactionParagon = function(id) return id == 2510 end,
    GetFactionParagonInfo = function(id)
        if id == 2510 then return 31000, 10000, 90001, true, false end
    end,
}
_G.C_MajorFactions = {
    GetMajorFactionData = function(id)
        if id == 2600 then return { renownLevel = 14, renownReputationEarned = 1500, renownLevelThreshold = 2500 } end
    end,
}
_G.InCombatLockdown = function() return false end

local ns = loader.LoadAll({})
local Storage = ns.Storage
Storage.Store.Initialize()
Storage.Store.EnsureCurrentCharacter()

local published = 0
Storage.Bus.Subscribe("ReputationsChanged", function() published = published + 1 end)

Storage.ScanReputations.MarkFullDirty()
assert(Storage.ScanReputations.Drain() == true)
assert(published == 1, "full walk publishes once")
local reps = Storage.Store.GetCurrentCharacter().reputations

local child = reps[1133]
assert(child, "collapsed-header child captured via expand")
assert(child.value == 4500 and child.standing == 5, "child standing")
assert(child.floor == 3000 and child.ceiling == 9000, "thresholds")
assert(pane[1].isCollapsed == true, "collapse state restored")
assert(reps[1100] == nil, "plain headers not stored")

local renown = reps[2600]
assert(renown.renownLevel == 14 and renown.renownEarned == 1500 and renown.renownThreshold == 2500, "major faction")

local paragon = reps[2510]
assert(paragon.paragonValue == 31000 and paragon.paragonThreshold == 10000 and paragon.paragonPending == true, "paragon raw values")

-- shared name/group maps
assert(Storage.Store.GetFactionNames()[1133] == "Old Friends")
assert(Storage.Store.GetFactionGroups()[1133] == "Old Expansion", "child grouped under its header")

-- in-combat full walk defers (dirty preserved, no publish)
_G.InCombatLockdown = function() return true end
Storage.ScanReputations.MarkFullDirty()
assert(Storage.ScanReputations.Drain() == false, "combat defers the walk")
_G.InCombatLockdown = function() return false end
assert(Storage.ScanReputations.Drain() == true, "deferred walk runs after combat")
assert(published == 2)

-- incremental: single-faction update path (no expand/collapse calls)
local expandCalls = 0
local oldExpand = _G.C_Reputation.ExpandFactionHeader
_G.C_Reputation.ExpandFactionHeader = function(...) expandCalls = expandCalls + 1; return oldExpand(...) end
childRow.currentStanding = 5000
Storage.ScanReputations.OnFactionStandingChanged(1133)
assert(Storage.ScanReputations.Drain() == true)
assert(reps ~= Storage.Store.GetCurrentCharacter().reputations or reps[1133].value == 5000, "incremental update")
assert(Storage.Store.GetCurrentCharacter().reputations[1133].value == 5000, "incremental update value")
assert(expandCalls == 0, "incremental path never touches headers")

local rows = {
    { factionID = 4100, name = "First", isHeader = true, isCollapsed = true, depth = 0 },
    { factionID = 4110, name = "Nested", isHeader = true, isCollapsed = true, depth = 1 },
    { factionID = 4111, name = "Nested Friends", depth = 2 },
    { factionID = 4120, name = "Header Friends", isHeader = true, isHeaderWithRep = true, isCollapsed = true, depth = 1 },
    { factionID = 4121, name = "Header Children", depth = 2 },
    { factionID = 4130, name = "Already Open", isHeader = true, isCollapsed = false, depth = 1 },
    { factionID = 4131, name = "Open Children", depth = 2 },
    { factionID = 4200, name = "Second", isHeader = true, isCollapsed = true, depth = 0 },
    { factionID = 4201, name = "Second Friends", depth = 1 },
    { factionID = 4300, name = "Third", isHeader = true, isCollapsed = false, depth = 0 },
    { factionID = 4301, name = "Third Friends", depth = 1 },
}
local initialCollapsed = {}
for _, row in ipairs(rows) do
    initialCollapsed[row] = row.isCollapsed
    row.isChild = row.depth > 0
    row.reaction, row.currentStanding = 5, 4500
    row.currentReactionThreshold, row.nextReactionThreshold = 3000, 9000
end
local function VisibleRows()
    local visible, hiddenDepth = {}, nil
    for _, row in ipairs(rows) do
        if hiddenDepth and row.depth <= hiddenDepth then hiddenDepth = nil end
        if not hiddenDepth then
            visible[#visible + 1] = row
            if row.isCollapsed then hiddenDepth = row.depth end
        end
    end
    return visible
end
local rowReads, countReads, expandedHeaders, collapsedHeaders = 0, 0, {}, {}
_G.C_Reputation.GetNumFactions = function()
    countReads = countReads + 1
    return #VisibleRows()
end
_G.C_Reputation.GetFactionDataByIndex = function(i)
    rowReads = rowReads + 1
    return VisibleRows()[i]
end
_G.C_Reputation.ExpandFactionHeader = function(i)
    local row = VisibleRows()[i]
    assert(row.isHeader and row.isCollapsed, "only collapsed headers expanded")
    expandedHeaders[#expandedHeaders + 1] = row.factionID
    row.isCollapsed = false
end
_G.C_Reputation.CollapseFactionHeader = function(i)
    local row = VisibleRows()[i]
    assert(row.isHeader and not row.isCollapsed, "restoration uses the current header index")
    collapsedHeaders[#collapsedHeaders + 1] = row.factionID
    row.isCollapsed = true
end
local beforeNested = published
Storage.ScanReputations.MarkFullDirty()
assert(Storage.ScanReputations.Drain() == true)
assert(published == beforeNested + 1, "nested scan publishes one complete snapshot")
local nestedReps = Storage.Store.GetCurrentCharacter().reputations
assert(nestedReps[1133] == nil, "full scan replaces obsolete snapshot entries")
for _, row in ipairs(rows) do
    assert(row.isCollapsed == initialCollapsed[row], "every header retains its original collapse state")
    local entry = nestedReps[row.factionID]
    if row.isHeader and not row.isHeaderWithRep then
        assert(entry == nil, "plain nested headers are excluded")
    else
        assert(entry and entry.value == 4500 and entry.standing == 5 and entry.floor == 3000 and entry.ceiling == 9000)
        assert(Storage.Store.GetFactionNames()[row.factionID] == row.name)
        local group = row.factionID < 4200 and "First" or row.factionID < 4300 and "Second" or "Third"
        assert(Storage.Store.GetFactionGroups()[row.factionID] == group, "nested headers preserve top-level grouping")
    end
end
assert(table.concat(expandedHeaders, ",") == "4100,4110,4120,4200")
assert(table.concat(collapsedHeaders, ",") == "4200,4120,4110,4100")
assert(rowReads == #rows, "full walk reads every row once, without rereading for collection or restoration")
assert(countReads == #expandedHeaders + 1, "row count refreshed only when expansion changes the list")

print("OK: storage_scan_reputations_test")
