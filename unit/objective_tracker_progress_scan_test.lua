local file = assert(io.open(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function StyleExistingProgressBars()", 1, true))
local last = assert(source:find("local function SkinTrackerHeader(", first, true))
local settings
local scenarioBar, scenarioTimer, questBar = {}, {}, {}
local progressBars = { scenarioBar }
local timerBars = { scenarioTimer }
local questBars = { questBar }
local collections = { [progressBars] = true, [timerBars] = true, [questBars] = true }
local moduleScans, collectionScans = 0, 0
local calls = {}
local globals = {
    ScenarioObjectiveTracker = { usedProgressBars = progressBars, usedTimerBars = timerBars },
    QuestObjectiveTracker = { usedProgressBars = questBars },
    AchievementObjectiveTracker = {},
    UIWidgetObjectiveTracker = setmetatable({}, {
        __index = function() error("progress styling must not inspect UIWidget pools") end,
    }),
}
local sandbox = setmetatable({
    _G = globals,
    trackerModules = { "ScenarioObjectiveTracker", "QuestObjectiveTracker",
        "AchievementObjectiveTracker", "UIWidgetObjectiveTracker" },
    GetSettings = function() return settings end,
    ipairs = function(modules)
        assert(settings and settings.skinObjectiveTracker and settings.objectiveTrackerCustomBars,
            "disabled custom bars must not scan tracker modules")
        moduleScans = moduleScans + 1
        return ipairs(modules)
    end,
    pairs = function(collection)
        assert(collections[collection], "progress scan must iterate only native collections")
        collectionScans = collectionScans + 1
        return pairs(collection)
    end,
    StyleTrackerProgressBar = function(bar, preserveColor)
        calls[#calls + 1] = { bar = bar, preserveColor = preserveColor }
    end,
}, { __index = _G })
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleExistingProgressBars"))
setfenv(chunk, sandbox)
local style = chunk()
style()
settings = { skinObjectiveTracker = false, objectiveTrackerCustomBars = true }; style()
settings = { skinObjectiveTracker = true, objectiveTrackerCustomBars = false }; style()
assert(moduleScans == 0 and collectionScans == 0 and #calls == 0)
settings.objectiveTrackerCustomBars = true
style()
assert(moduleScans == 1 and collectionScans == 3 and #calls == 3,
    "enabled styling must scan each existing collection once")
assert(calls[1].bar == scenarioBar and not calls[1].preserveColor
    and calls[2].bar == scenarioTimer and calls[2].preserveColor == true
    and calls[3].bar == questBar and not calls[3].preserveColor,
    "scenario progress and timers must retain their color policies")
style()
assert(collectionScans == 6 and #calls == 6, "repeated styling must reuse native collections")
print("OK: objective_tracker_progress_scan_test")
