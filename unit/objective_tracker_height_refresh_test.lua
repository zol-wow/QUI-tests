local helpers = dofile("tools/_addon_env.lua").LoadCore().Helpers

local function read(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return text
end

local source = read(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua")
local function section(first, last)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start + #first, true)) - 1)
end

for _, corpus in ipairs({ "tests/framexml", "tests/clients/forever/framexml" }) do
    local nativeSource = read(corpus .. "/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua")
    local native = {}
    local nativeEnv = setmetatable({ ObjectiveTrackerContainerMixin = native }, { __index = _G })
    for _, name in ipairs({ "UpdateHeight", "GetAvailableHeight" }) do
        local method = assert(nativeSource:match("function ObjectiveTrackerContainerMixin:" .. name .. "%(%).-\nend"))
        local chunk = assert(loadstring(method))
        setfenv(chunk, nativeEnv)
        chunk()
    end

    local settings = { skinObjectiveTracker = true, objectiveTrackerHeight = 420 }
    local combat, scenario = false, false
    local frame = { height = 420, modules = {}, topModulePadding = 38 }
    function frame:GetHeight() return self.height end
    function frame:SetHeight(height) self.height = height end
    function frame:IsInDefaultPosition() return false end
    function frame:IsProtected() return self.protected or false end
    function frame:IsAnchoringRestricted() return self.restricted or false end
    frame.UpdateHeight = native.UpdateHeight
    local deferred = 0
    local widthCalls = 0
    local eventFrame = {}
    function eventFrame:RegisterEvent(event) assert(event == "PLAYER_REGEN_ENABLED") end
    function eventFrame:SetScript(_, callback) self.callback = callback end
    local frameData = {}
    local env = setmetatable({
        _G = { ObjectiveTrackerFrame = frame },
        TrackerFrame = frame,
        Helpers = helpers,
        GetSettings = function() return settings end,
        InCombatLockdown = function() return combat end,
        IsScenarioActive = function() return scenario end,
        RestoreBlizzardTrackerWidths = function() widthCalls = widthCalls + 1; return true end,
        ApplyMaxWidth = function() widthCalls = widthCalls + 1; return true end,
        DeferObjectiveTrackerPostLayoutUpdate = function() deferred = deferred + 1 end,
        ScheduleBackdropUpdate = function() deferred = deferred + 1 end,
        CreateFrame = function() return eventFrame end,
        SkinBase = {
            GetFrameData = function(_, key) return frameData[key] end,
            SetFrameData = function(_, key, value) frameData[key] = value end,
        },
        ns = { SafeCall = function(_, fn, ...) return assert(pcall(fn, ...)) end },
        hooksecurefunc = function(object, key, callback)
            local original = object[key]
            object[key] = function(self, ...)
                original(self, ...)
                callback(self, ...)
            end
        end,
    }, { __index = _G })
    local chunk = assert(loadstring(table.concat({
        "local pendingProtectedLayoutUpdate = false",
        section("local blizzardTrackerHeight = nil", "-- <<< QUI_TEST_EXTRACT tracker_max_height"),
        section("local scenarioDimensionsRestored = false", "local function RunObjectiveTrackerPostLayoutUpdate()"),
        section('    if TrackerFrame.UpdateHeight and not SkinBase.GetFrameData', '\n    ApplyLayoutSettingsSafely(settings)'),
        section('local protectedLayoutEventFrame = CreateFrame("Frame")', 'local function SetupDebugInstrumentation()'),
        "return function() return pendingProtectedLayoutUpdate end, EnforceSize",
    }, "\n")))
    setfenv(chunk, env)
    local pending, enforce = chunk()

    frame:UpdateHeight()
    assert(frame.height == 420 and native.GetAvailableHeight(frame) == 382,
        corpus .. ": native refresh must restore QUI's height before returning, without a visible oversized frame")
    assert(deferred == 1, "background refresh must still be scheduled")
    settings.objectiveTrackerHeight = 1000
    frame:UpdateHeight()
    assert(frame.height == 1000, "expanded QUI height must also be restored synchronously")
    scenario = true
    frame:UpdateHeight()
    assert(frame.height == 800, "scenario must retain native height")
    scenario = false
    combat = true
    local beforeCombatWidths = widthCalls
    frame:UpdateHeight()
    assert(frame.height == 1000 and pending(), "unrestricted tracker height must be corrected before combat refresh returns")
    settings.objectiveTrackerHeight = 420
    frame:UpdateHeight()
    assert(frame.height == 420 and native.GetAvailableHeight(frame) == 382,
        "combat refresh must constrain native available space to the configured maximum")
    for _, field in ipairs({ "protected", "restricted" }) do
        frame[field] = true
        frame:UpdateHeight()
        assert(frame.height == 800 and pending(), "restricted tracker must retain native height and retry after combat")
        frame[field] = false
    end
    local isProtected = frame.IsProtected
    frame.IsProtected = function() error("security state unavailable") end
    frame:UpdateHeight()
    assert(frame.height == 800, "unreadable protection must defer height correction")
    frame.IsProtected = isProtected
    scenario = true
    frame:UpdateHeight()
    assert(frame.height == 800, "combat correction must preserve scenario-owned dimensions")
    scenario = false
    assert(widthCalls == beforeCombatWidths, "combat height repair must not mutate module/header widths")
    combat = false
    eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
    assert(frame.height == 420 and not pending() and widthCalls == beforeCombatWidths + 1,
        "combat-end event must finish deferred dimensions and clear the retry")
    scenario = true
    enforce()
    assert(frame.height == 800, "scenario entry must restore the captured native height")
    combat = true
    scenario = false
    enforce()
    assert(frame.height == 420, "leaving a scenario in combat must allow unrestricted height correction")
    scenario = true
    enforce()
    assert(frame.height == 420 and pending(), "scenario reentry must defer restoration while in combat")
    combat = false
    eventFrame.callback(eventFrame, "PLAYER_REGEN_ENABLED")
    assert(frame.height == 800, "scenario reentry must restore native height even after an earlier scenario restoration")
    settings.skinObjectiveTracker = false
    frame:UpdateHeight()
    assert(frame.height == 800, "disabled skin must leave native height intact")
end

print("OK: objective_tracker_height_refresh_test")
