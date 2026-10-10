local Setup = dofile("tests/helpers/spell_reminders.lua")

local function Ready(focus)
    local H = Setup()
    H.units.ally = { name = "Friend", guid = "f", role = "DAMAGER" }
    H.units.other = { name = "Other", guid = "o", role = "DAMAGER" }
    H.focus = focus
    local pi = H.R.Add(10060).pi
    pi.party.alert, pi.focus.duration, pi.durationHost = true, true, "alert"
    H.R.Refresh()
    return H
end

local function Point(record)
    local point = record.slot.points[1]
    return point[4], point[5]
end

local cases = {
    { "focus keeps a separate position as the roster changes", function()
        local H = Ready("ally")
        local focus = assert(H.T.focusAlert)
        local x, y = Point(focus)
        local function Separate()
            assert(focus.container.enabled and H.T.alerts[1].container.enabled,
                "outside-group focus and party tracking must both remain active")
            for _, record in ipairs(H.T.alerts) do
                local gx, gy = Point(record)
                assert(gx ~= x or gy ~= y, "focus and group recipient icons must not share an anchor")
            end
            local fx, fy = Point(focus)
            assert(fx == x and fy == y, "roster changes must not move the reserved focus position")
        end
        Separate()
        local member = H.units.party2
        H.units.party2 = nil
        H.emit("GROUP_ROSTER_UPDATE")
        Separate()
        H.units.party2 = member
        H.emit("GROUP_ROSTER_UPDATE")
        Separate()
    end },
    { "an outside-group focus can first appear during combat", function()
        local H = Ready()
        local record = assert(H.T.focusAlert, "a focus slot must exist before a focus is selected")
        assert(not record.container.enabled, "the preallocated slot remains inactive without a valid focus")
        local frames = #H.frames
        H.combat, H.secretAuras, H.focus = true, true, "ally"
        H.emit("PLAYER_FOCUS_CHANGED")
        assert(record.container.enabled and record.container.boundUnit == "focus",
            "the prepared slot must follow a newly selected focus during combat")
        assert(record.durationContainer.enabled and record.durationContainer.boundUnit == "focus")
        assert(record.view.text.text == "Focus", "a stable label must not cache a recipient name")
        assert(#H.frames == frames, "selecting a combat focus must not allocate artwork")
    end },
    { "a prepared focus slot follows replacement focus during restrictions", function()
        local H = Ready("ally")
        local record = assert(H.T.focusAlert)
        local frames = #H.frames
        H.combat, H.secretAuras = true, true
        H.focus = "other"
        H.emit("PLAYER_FOCUS_CHANGED")
        assert(record.container.enabled and record.container.boundUnit == "focus",
            "a different outside-group focus must not be rejected for its new GUID")
        assert(record.durationContainer.enabled)
        H.units.enemy = { name = "Enemy", guid = "e", friendly = false }
        H.units.pet = { name = "Pet", guid = "pet", isPlayer = false }
        for _, focus in ipairs({ "missing", "player", "enemy", "pet", "party1" }) do
            H.focus = focus
            H.emit("PLAYER_FOCUS_CHANGED")
            assert(not record.container.enabled and not record.durationContainer.enabled,
                "outside-group focus slot must disable for an invalid or group focus: " .. focus)
        end
        H.combat, H.encounter, H.focus = false, true, "ally"
        H.emit("PLAYER_FOCUS_CHANGED")
        assert(record.container.enabled and record.durationContainer.enabled,
            "focus tracking must resume while aura artwork remains restricted")
        assert(record.view.text.text == "Focus" and #H.frames == frames,
            "restricted focus changes must preserve the prepared label and artwork")
    end },
}

local failures = 0
for _, case in ipairs(cases) do
    local ok, err = pcall(case[2])
    if not ok then
        failures = failures + 1
        print("FAIL: " .. case[1] .. ": " .. tostring(err))
    end
end
assert(failures == 0, tostring(failures) .. " focus-alert regressions")
print("OK: focus alerts have a reserved position and follow combat focus changes without artwork writes")
