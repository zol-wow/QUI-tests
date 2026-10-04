local source = arg and arg[1] or "modules/dungeon/keystone.lua"

local function scenario(settings)
    local state = {
        settings = settings or {},
        info = { level = 10, practiceRun = false },
        ownedLevel = 10,
        ownedReads = 0,
        frames = {},
        timers = {},
        now = 0,
    }

    _G.UIParent = {}
    _G.STANDARD_TEXT_FONT = "test-font"
    _G.C_AddOns = { IsAddOnLoaded = function() return false end }
    _G.C_ChallengeMode = { GetChallengeCompletionInfo = function() return state.info end }
    _G.C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
            state.ownedReads = state.ownedReads + 1
            return state.ownedLevel
        end,
    }
    _G.C_Timer = {
        After = function(delay, callback)
            state.timers[#state.timers + 1] = { at = state.now + delay, callback = callback }
        end,
    }
    _G.CreateFrame = function()
        local frame = { events = {}, scripts = {}, shown = true, shows = 0 }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:Hide() self.shown = false end
        function frame:Show() self.shown = true; self.shows = self.shows + 1 end
        function frame:SetSize() end
        function frame:SetPoint() end
        function frame:SetFrameStrata() end
        function frame:CreateFontString()
            return {
                SetAllPoints = function() end,
                SetFont = function() end,
                SetTextColor = function() end,
                SetText = function(_, text) frame.text = text end,
            }
        end
        state.frames[#state.frames + 1] = frame
        return frame
    end

    assert(loadfile(source))("QUI", {
        Helpers = { CreateDBGetter = function() return function() return state.settings end end },
    })

    function state:fire(event)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then
                frame.scripts.OnEvent(frame, event)
            end
        end
    end

    function state:advance(seconds)
        local target = self.now + seconds
        while true do
            local nextIndex
            for index, timer in ipairs(self.timers) do
                if timer.at <= target and (not nextIndex or timer.at < self.timers[nextIndex].at) then
                    nextIndex = index
                end
            end
            if not nextIndex then break end
            local timer = table.remove(self.timers, nextIndex)
            self.now = timer.at
            timer.callback()
        end
        self.now = target
    end

    function state:reminder()
        for _, frame in ipairs(self.frames) do
            if frame.text == "Re-roll key?" then return frame end
        end
    end

    function state:visible()
        local frame = self:reminder()
        return frame and frame.shown or false
    end

    return state
end

local delayed = scenario()
delayed.ownedLevel = nil
delayed:fire("CHALLENGE_MODE_COMPLETED")
delayed:advance(1)
assert(not delayed:visible(), "unavailable owned key must not show a reminder")
delayed.ownedLevel = 10
delayed:advance(1)
assert(delayed:visible(), "reminder must recover when the owned key becomes available after one second")
assert(delayed.ownedReads == 2, "delayed key must be checked again")

local zero = scenario({ keystoneRerollReminder = true })
zero.ownedLevel = 0
zero:fire("CHALLENGE_MODE_COMPLETED")
zero:advance(1)
zero.ownedLevel = 8
zero:advance(1)
assert(zero:visible(), "zero owned level must retry and show for a lower owned key")

local equal = scenario()
equal:fire("CHALLENGE_MODE_COMPLETED")
equal:advance(0.9)
assert(not equal:visible(), "reminder must wait one second")
equal:advance(0.1)
assert(equal:visible(), "equal key must show with an unset setting")
local frame = equal:reminder()
frame.scripts.OnUpdate(frame, 14.9)
assert(equal:visible(), "reminder must remain for fifteen seconds")
frame.scripts.OnUpdate(frame, 0.2)
assert(not equal:visible(), "reminder must expire after fifteen seconds")

local higher = scenario()
higher.ownedLevel = 11
higher:fire("CHALLENGE_MODE_COMPLETED")
higher:advance(10)
assert(not higher:visible(), "completed level below owned key must not show")
assert(higher.ownedReads == 1, "available ineligible keys must not retry")

local absent = scenario()
absent.ownedLevel = nil
absent:fire("CHALLENGE_MODE_COMPLETED")
absent:advance(30)
assert(not absent:visible(), "no owned key must not show")
assert(absent.ownedReads == 5 and #absent.timers == 0, "unavailable key retries must stop after five attempts")

for _, info in ipairs({ { level = 10, practiceRun = true }, { level = 0 }, { level = -1 }, {} }) do
    local invalid = scenario()
    invalid.info = info
    invalid:fire("CHALLENGE_MODE_COMPLETED")
    invalid:advance(10)
    assert(not invalid:visible() and invalid.ownedReads == 0, "practice and invalid completions must be ignored")
end

local disabled = scenario({ keystoneRerollReminder = false })
disabled:fire("CHALLENGE_MODE_COMPLETED")
disabled:advance(10)
assert(not disabled:visible() and disabled.ownedReads == 0, "disabled reminder must ignore completion")

local pending = scenario()
pending.ownedLevel = nil
pending:fire("CHALLENGE_MODE_COMPLETED")
pending:advance(1)
pending.settings.keystoneRerollReminder = false
pending.ownedLevel = 10
pending:advance(10)
assert(not pending:visible() and pending.ownedReads == 1, "disabling during retry must stop the pending reminder")

local visible = scenario()
visible:fire("CHALLENGE_MODE_COMPLETED")
visible:advance(1)
visible.settings.keystoneRerollReminder = false
local visibleFrame = visible:reminder()
visibleFrame.scripts.OnUpdate(visibleFrame, 0.01)
assert(not visible:visible(), "disabling must hide an already visible reminder on its next update")

for _, event in ipairs({ "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET", "PLAYER_ENTERING_WORLD" }) do
    local cancelled = scenario()
    cancelled.ownedLevel = nil
    cancelled:fire("CHALLENGE_MODE_COMPLETED")
    cancelled:advance(1)
    cancelled:fire(event)
    cancelled.ownedLevel = 10
    cancelled:advance(10)
    assert(not cancelled:visible() and cancelled.ownedReads == 1, event .. " must cancel pending retries")

    local shown = scenario()
    shown:fire("CHALLENGE_MODE_COMPLETED")
    shown:advance(1)
    shown:fire(event)
    assert(not shown:visible(), event .. " must hide a visible reminder")
end

local duplicate = scenario()
duplicate:fire("CHALLENGE_MODE_COMPLETED")
duplicate:fire("CHALLENGE_MODE_COMPLETED")
duplicate:advance(1)
assert(duplicate:visible() and duplicate:reminder().shows == 1, "duplicate completion must replace the earlier pending reminder")
duplicate:fire("CHALLENGE_MODE_COMPLETED")
assert(not duplicate:visible(), "new completion must hide the previous reminder")
duplicate:advance(1)
assert(duplicate:visible() and duplicate:reminder().shows == 2, "new completion must reuse the reminder frame")

-- Saved choices control visible lifetime; corrupt/old profiles retain 15 seconds.
local function checkDuration(value, expected)
    local state = scenario({ keystoneRerollReminderDuration = value })
    state:fire("CHALLENGE_MODE_COMPLETED")
    state:advance(1)
    local popup = assert(state:reminder())
    popup.scripts.OnUpdate(popup, expected - 0.1)
    assert(state:visible(), "saved " .. tostring(value) .. " must remain visible for " .. expected .. " seconds")
    popup.scripts.OnUpdate(popup, 0.2)
    assert(not state:visible(), "saved " .. tostring(value) .. " must expire after " .. expected .. " seconds")
end
for _, duration in ipairs({ 15, 30, 60 }) do checkDuration(duration, duration) end
checkDuration(nil, 15)
for _, invalid in ipairs({ 0, -1, 16, 120, "30", true, false, {}, math.huge, 0/0 }) do
    checkDuration(invalid, 15)
end

local latest = scenario({ keystoneRerollReminderDuration = 30 })
latest.ownedLevel = nil
latest:fire("CHALLENGE_MODE_COMPLETED")
latest:advance(1)
latest.settings.keystoneRerollReminderDuration = 60
latest.ownedLevel = 10
latest:advance(1)
local latestPopup = assert(latest:reminder())
latestPopup.scripts.OnUpdate(latestPopup, 30)
assert(latest:visible(), "retry must use the latest saved duration when the reminder appears")
latest.settings.keystoneRerollReminderDuration = 15
latestPopup.scripts.OnUpdate(latestPopup, 29.9)
assert(latest:visible(), "a setting change must not shorten an already visible reminder")
latestPopup.scripts.OnUpdate(latestPopup, 0.2)
assert(not latest:visible(), "the current reminder must keep its original countdown")
latest:fire("CHALLENGE_MODE_COMPLETED")
latest:advance(1)
latestPopup.scripts.OnUpdate(latestPopup, 15)
assert(not latest:visible(), "the next reminder must use the newly saved duration")

-- Longer choices must retain the existing cancellation and disable behavior.
for _, duration in ipairs({ 30, 60 }) do
    for _, event in ipairs({ "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET", "PLAYER_ENTERING_WORLD" }) do
        local state = scenario({ keystoneRerollReminderDuration = duration })
        state:fire("CHALLENGE_MODE_COMPLETED")
        state:advance(1)
        state:fire(event)
        assert(not state:visible(), event .. " must hide a longer reminder")
        state.ownedLevel = nil
        state:fire("CHALLENGE_MODE_COMPLETED")
        state:advance(1)
        state:fire(event)
        state.ownedLevel = 10
        state:advance(10)
        assert(not state:visible(), event .. " must cancel a longer pending reminder")
    end
    local state = scenario({ keystoneRerollReminderDuration = duration })
    state:fire("CHALLENGE_MODE_COMPLETED")
    state:advance(1)
    state.settings.keystoneRerollReminder = false
    local popup = assert(state:reminder())
    popup.scripts.OnUpdate(popup, 0.01)
    assert(not state:visible(), "disabling must hide a longer reminder")
end

print("keystone_reroll_reminder_test.lua: ok")
