local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua"))
local source = file:read("*a")
file:close()
local start = source:find("-- <<< QUI_TEST_EXTRACT scenario_stage_spacing", 1, true)
    or assert(source:find("local SCENARIO_STAGE_TEXTURE_KEYS", 1, true))
local finish = assert(source:find("local protectedLayoutEventFrame", start, true))
local refreshStart = assert(source:find("RefreshTrackerContent = function()", finish, true))
local refreshFinish = assert(source:find("local RefreshObjectiveTracker", refreshStart, true))
local code = source:sub(start, finish - 1) .. source:sub(refreshStart, refreshFinish - 1)
    .. "\nreturn RefreshTrackerContent, DeferObjectiveTrackerPostLayoutUpdate"
local failures = {}

local function run(path, combat)
    local attempts, data, timers = {}, {}, {}
    local stageFrame = env.NewFrame("Frame")
    stageFrame:SetSize(201, 83)
    local stage = setmetatable({}, {
        __index = stageFrame,
        __newindex = function(_, key, value)
            if key == "height" then attempts["stage.height"] = true
            else stageFrame[key] = value end
        end,
    })
    for _, key in ipairs({ "Stage", "Name", "CompleteLabel" }) do
        stage[key] = stageFrame:CreateFontString()
        stage[key]:SetSize(180, 36)
    end
    stage.Stage:SetText("Clear the Cursed Depths")
    stage.Stage:SetPoint("TOPLEFT", stage, "TOPLEFT", 15, -18)
    stage.Stage.GetStringHeight = function() return 12 end
    stage.Stage.GetJustifyV = function() return "MIDDLE" end
    stage.Name:SetText("")
    stage.CompleteLabel:Hide()
    stage.NormalBG = stageFrame:CreateTexture()
    local header = stageFrame:CreateFontString()
    header:SetText("")
    header:SetHeight(20)
    local native = {
        lineSpacing = 12, StageBlock = stage,
        ObjectivesBlock = { HeaderText = header },
        MarkDirty = function() attempts.MarkDirty = true end,
    }
    local scenario = setmetatable({}, {
        __index = native,
        __newindex = function(_, key, value)
            if key == "lineSpacing" then attempts["scenario.lineSpacing"] = true
            else native[key] = value end
        end,
    })
    local sandbox = setmetatable({
        _G = { ScenarioObjectiveTracker = scenario }, ns = {}, trackerModules = {},
        pendingBackdropUpdate = false,
        GetSettings = function() return { skinObjectiveTracker = true, objectiveTrackerTitleColor = { 1, 1, 1, 1 } } end,
        GetFontPath = function() return "QUIFont.ttf" end,
        GetFontFlags = function() return "" end,
        CJKFont = function(text, font, size, flags) text:SetFont(font, size, flags) end,
        SafeSetTextColor = function(text, color) text:SetTextColor(unpack(color)) end,
        SkinBase = {
            GetFrameData = function(frame, key) return data[frame] and data[frame][key] end,
            SetFrameData = function(frame, key, value)
                data[frame] = data[frame] or {}
                data[frame][key] = value
            end,
        },
        InCombatLockdown = function() return combat end,
        IsScenarioActive = function() return true end,
        RestoreBlizzardTrackerHeight = function() return true end,
        RestoreBlizzardTrackerWidths = function() return true end,
        ApplyFontStyles = function() end,
        StyleScenarioHeaderWidgets = function() end,
        StyleScenarioStatusWidgets = function() end,
        UpdateBackdropAnchors = function() end,
        HidePOIButtonGlows = function() end,
        StyleExistingProgressBars = function() end,
        C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end },
    }, { __index = _G })
    local chunk = assert(loadstring(code))
    setfenv(chunk, sandbox)
    local refresh, defer = chunk()
    if path == "refresh" then refresh()
    else
        defer()
        defer()
        assert(#timers == 1, "post-layout updates must stay deferred and coalesced")
        timers[1]()
    end
    for _, key in ipairs({ "scenario.lineSpacing", "stage.height", "MarkDirty" }) do
        assert(not attempts[key], path .. " must not write native scenario state: " .. key)
    end
    assert(scenario.lineSpacing == 12 and stage.height == 83 and stage:GetWidth() == 201)
    assert(stage.Stage:GetHeight() == 36 and header:GetHeight() == 20, "native text geometry must survive styling")
    assert(stage.Stage:GetText() == "Clear the Cursed Depths", "native stage text must survive styling")
    assert(stage.Stage:GetFont() == "QUIFont.ttf" and stage.NormalBG:GetAlpha() == 0,
        path .. " must retain scenario cosmetics in and out of combat")
end

for _, path in ipairs({ "refresh", "post-layout" }) do
    for _, combat in ipairs({ false, true }) do
        local ok, message = pcall(run, path, combat)
        if not ok then failures[#failures + 1] = message end
    end
end
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: objective_tracker_stage_spacing_test")
