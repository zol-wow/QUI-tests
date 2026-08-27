local loadstring = loadstring or load

local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a"); f:close()
    return (data:gsub("\r\n", "\n"))
end

local src = readAll("modules/skinning/gameplay/objectivetracker.lua")
local mplusSrc = readAll("modules/dungeon/mplus_timer.lua")
local anchoringSrc = readAll("modules/layout/anchoring.lua")
local layoutModeSrc = readAll("modules/layout/layoutmode.lua")
local coreMainSrc = readAll("core/main.lua")
local settingsSrc = readAll("modules/skinning/settings/skinning_content.lua")

local function extract(name)
    local sentinel = "-- <<< QUI_TEST_EXTRACT " .. name
    local first = assert(src:find(sentinel, 1, true), "start sentinel must exist: " .. name)
    local second = assert(src:find(sentinel, first + #sentinel, true), "end sentinel must exist: " .. name)
    return src:sub(first + #sentinel, second - 1)
end

assert(not src:find("editModeHeight", 1, true),
    "objectivetracker.lua must not write ObjectiveTrackerFrame.editModeHeight")
assert(not src:find("ScenarioTrackerProgressBarMixin", 1, true),
    "objectivetracker.lua must not hook the scenario progress bar mixin")
assert(not src:find("StageBlock", 1, true),
    "objectivetracker.lua must not touch ScenarioObjectiveTracker.StageBlock")
assert(src:find("local function IsWidgetPoolBlock", 1, true),
    "objectivetracker.lua must gate block styling on the widget-pool trackers")
assert(src:find("ScenarioObjectiveTracker = true", 1, true)
    and src:find("UIWidgetObjectiveTracker = true", 1, true),
    "objectivetracker.lua must list both widget-pool trackers")
assert(not src:find('hooksecurefunc(tracker, "LayoutContents"', 1, true),
    "objectivetracker.lua must not hook Blizzard module LayoutContents")
assert(not src:find('hooksecurefunc(TrackerFrame, "Update",', 1, true),
    "QUI must not hook ObjectiveTrackerFrame.Update")
assert(not src:find('TrackerFrame:HookScript("OnSizeChanged",', 1, true),
    "QUI must not attach addon code to ObjectiveTrackerFrame OnSizeChanged")
assert(src:find('hooksecurefunc(TrackerFrame, "UpdateHeight"', 1, true),
    "Max Height must retain Blizzard-height capture without forcing owner Update")
assert(not src:find("HookAnimLineState", 1, true)
    and not src:find("HookProgressBarMixins", 1, true)
    and not src:find("HookLineCreation", 1, true),
    "QUI must restyle non-widget content from events instead of global Blizzard mixin hooks")

local fakeHelpers = {
    SafeNumberOrNil = function(value)
        return type(value) == "number" and value or nil
    end,
}
local scenarioActive = false

local heightChunk = table.concat({
    "local _G, Helpers, IsScenarioActive = ...",
    extract("tracker_max_height"),
    "return ApplyTrackerMaxHeight, CaptureBlizzardTrackerHeight",
}, "\n")

local tracker = { height = 800, setHeightCalls = 0, topModulePadding = 38 }
function tracker:SetHeight(height)
    self.height = height
    self.setHeightCalls = self.setHeightCalls + 1
end
function tracker:GetHeight()
    return self.height
end

local fakeGlobals = { ObjectiveTrackerFrame = tracker }
local applyHeight, captureBlizzardHeight = assert(loadstring(heightChunk, "tracker_max_height"))(
    fakeGlobals, fakeHelpers, function() return scenarioActive end)

local containerSrc = readAll(
    "tests/framexml/Interface/AddOns/Blizzard_ObjectiveTracker/" ..
    "Blizzard_ObjectiveTrackerContainer.lua")
local getAvailableHeightSrc = assert(containerSrc:match(
    "function ObjectiveTrackerContainerMixin:GetAvailableHeight%(%)\n.-\nend"),
    "local FrameXML must expose the objective tracker available-height calculation")
local getAvailableHeight = assert(loadstring(table.concat({
    "local ObjectiveTrackerContainerMixin = {}",
    getAvailableHeightSrc,
    "return ObjectiveTrackerContainerMixin.GetAvailableHeight",
}, "\n"), "objective_tracker_available_height"))()

assert(containerSrc:find("function ObjectiveTrackerContainerMixin:OnSizeChanged()", 1, true)
    and containerSrc:find("self:MarkDirty();", 1, true),
    "FrameXML must retain the owner resize-to-dirty boundary guarded by this regression")

assert(applyHeight({ objectiveTrackerHeight = 420 }) == true)
assert(tracker.height == 420,
    "configured max height must constrain ObjectiveTrackerFrame outside scenarios")
assert(getAvailableHeight(tracker) == 382,
    "Blizzard modules must receive the constrained height as their available layout space")
assert(tracker.editModeHeight == nil,
    "height enforcement must not mutate Blizzard's Edit Mode height state")

local heightCalls = tracker.setHeightCalls
applyHeight({ objectiveTrackerHeight = 420 })
assert(tracker.setHeightCalls == heightCalls,
    "unchanged max height must not trigger Blizzard's dirty resize path again")

tracker.height = 800
captureBlizzardHeight(tracker)
scenarioActive = true
assert(applyHeight({ objectiveTrackerHeight = 400 }) == false)
assert(tracker.height == 800 and tracker.setHeightCalls == heightCalls,
    "active Scenario layouts must not receive addon-owned height writes")

scenarioActive = false
applyHeight({ objectiveTrackerHeight = 400 })
assert(tracker.height == 400,
    "configured max height must resume after the Scenario layout ends")

local shortTracker = { height = 300 }
function shortTracker:SetHeight(height) self.height = height end
function shortTracker:GetHeight() return self.height end
local applyShortHeight = assert(loadstring(heightChunk, "tracker_short_height"))(
    { ObjectiveTrackerFrame = shortTracker }, fakeHelpers, function() return false end)
applyShortHeight({ objectiveTrackerHeight = 600 })
assert(shortTracker.height == 300,
    "configured max height must not enlarge a tracker beyond Blizzard's available height")

fakeGlobals.ObjectiveTrackerFrame = nil
assert(pcall(applyHeight, { objectiveTrackerHeight = 300 }),
    "height enforcement must tolerate the tracker not being loaded yet")

local function newWidthFrame(width)
    local frame = { width = width, setWidthCalls = 0 }
    function frame:GetWidth() return self.width end
    function frame:SetWidth(value)
        self.width = value
        self.setWidthCalls = self.setWidthCalls + 1
    end
    return frame
end

local owner = newWidthFrame(260)
owner.Header = newWidthFrame(260)
local quest = newWidthFrame(260)
quest.Header = newWidthFrame(260)
local scenario = newWidthFrame(260)
local widthGlobals = {
    ObjectiveTrackerFrame = owner,
    QuestObjectiveTracker = quest,
    ScenarioObjectiveTracker = scenario,
}
local widthChunk = table.concat({
    "local _G, Helpers, IsScenarioActive, trackerModules, WIDGET_POOL_TRACKER_NAMES = ...",
    extract("tracker_max_width"),
    "return ApplyMaxWidth",
}, "\n")
local applyWidth = assert(loadstring(widthChunk, "tracker_max_width"))(
    widthGlobals, fakeHelpers, function() return scenarioActive end,
    { "ScenarioObjectiveTracker", "QuestObjectiveTracker" },
    { ScenarioObjectiveTracker = true, UIWidgetObjectiveTracker = true })

applyWidth({ objectiveTrackerWidth = 320 })
assert(owner.width == 320 and owner.Header.width == 320
    and quest.width == 320 and quest.Header.width == 320,
    "Max Width must remain active for the owner and non-widget modules")
assert(scenario.width == 260,
    "Max Width must not write into the Scenario widget-pool tracker")

local ownerWidthCalls = owner.setWidthCalls
applyWidth({ objectiveTrackerWidth = 320 })
assert(owner.setWidthCalls == ownerWidthCalls,
    "unchanged max width must not trigger Blizzard's dirty resize path again")

scenarioActive = true
assert(applyWidth({ objectiveTrackerWidth = 240 }) == false)
assert(owner.width == 320 and owner.setWidthCalls == ownerWidthCalls,
    "active Scenario layouts must not receive addon-owned width writes")

local postLayout = assert(src:match(
    "local function RunObjectiveTrackerPostLayoutUpdate%(%)" ..
    ".-local function DeferObjectiveTrackerPostLayoutUpdate%(%)"),
    "post-layout objective tracker block must exist")
assert(postLayout:find("EnforceSize()", 1, true),
    "post-layout updates must retain configured dimensions outside Scenario layouts")
assert(postLayout:find('ns.SyncManagedHolderSize("objectiveTracker")', 1, true),
    "deferred tracker updates must keep the managed holder geometry current")
assert(postLayout:find("RefreshTrackerContent and not inCombat", 1, true),
    "tracker events must defer full content rescans until combat ends")
assert(src:find('"PLAYER_ENTERING_WORLD"', 1, true)
    and src:find('"ZONE_CHANGED_NEW_AREA"', 1, true),
    "Scenario-deferred dimensions must retry when the player leaves the Scenario zone")
local masterHeader = assert(src:match(
    "local function SkinMasterHeader%(trackerFrame%)(.-)" ..
    "%-%- <<< QUI_TEST_EXTRACT tracker_max_height"),
    "master tracker header block must exist")
assert(masterHeader:find("ScheduleBackdropUpdate()", 1, true),
    "master collapse must refresh QUI's backdrop after Blizzard updates visibility")

local moduleHookSection = assert(src:match(
    "local DeferredScheduleBackdropUpdate = DeferObjectiveTrackerPostLayoutUpdate(.-)" ..
    "local manager = _G.ObjectiveTrackerManager"),
    "module-hook section must exist")
assert(moduleHookSection:find(
    "local tracker = not WIDGET_POOL_TRACKER_NAMES[trackerName] and _G[trackerName] or nil",
    1, true),
    "Scenario/UIWidget trackers must remain header-only and skip module lifecycle hooks")

assert(not mplusSrc:find("ObjectiveTrackerFrame:Update()", 1, true),
    "M+ timer must not directly update ObjectiveTrackerFrame")
assert(mplusSrc:find("HideScenarioObjectiveTracker", 1, true),
    "M+ timer must retain QUI's existing Scenario tracker visibility behavior")

assert(anchoringSrc:find(
    '{ key = "objectiveTracker",    frameName = "ObjectiveTrackerFrame"', 1, true),
    "QUI anchoring must retain the Objective Tracker mover")
assert(anchoringSrc:find(
    'if def.key ~= "objectiveTracker" and frame.HookScript and not state.sizeHooked then', 1, true),
    "the Objective Tracker mover must not hook the owner's OnSizeChanged script")
assert(anchoringSrc:find("ns.SyncManagedHolderSize = MirrorHolderSize", 1, true),
    "anchoring must expose its existing holder mirror for safe deferred synchronization")
local objectiveResolver = assert(anchoringSrc:match(
    "objectiveTracker = function%(%)" ..
    "(.-)topCenterWidgets = function%(%)"),
    "Objective Tracker resolver block must exist")
assert(objectiveResolver:find('MirrorHolderSize("objectiveTracker")', 1, true),
    "the always-loaded resolver must refresh holder geometry without master skinning")
assert(layoutModeSrc:find(
    '{ key = "objectiveTracker", label = ns.L["Objective Tracker"], frame = "ObjectiveTrackerFrame"',
    1, true),
    "QUI Layout Mode must retain its Objective Tracker mover")
assert(coreMainSrc:find('"ObjectiveTrackerFrame"', 1, true),
    "QUI must keep Blizzard Edit Mode selection suppressed for its managed mover")
assert(settingsSrc:find("objectiveTrackerHeight", 1, true)
    and settingsSrc:find("objectiveTrackerWidth", 1, true)
    and settingsSrc:find('ns.L["Max Height"]', 1, true)
    and settingsSrc:find('ns.L["Max Width"]', 1, true),
    "Objective Tracker Max Height and Max Width controls must remain visible")

print("OK: objectivetracker_widget_pool_retreat_test")
