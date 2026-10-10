local Setup = dofile("tests/helpers/spell_reminders.lua")

local function Active(H)
    local units = {}
    for _, info in ipairs(H.auraSounds) do
        if not info.removed then units[info.unitToken] = true end
    end
    return units
end

local function Ready()
    local H = Setup()
    local pi = H.R.Add(10060).pi
    pi.sound, pi.partySound, pi.focusSound = "QUI Reminder Bell", true, true
    return H, pi
end

local cases = {
    { "disabled contexts are removed during combat", function()
        local H, pi = Ready()
        H.units.ally = { name = "Friend", guid = "f", role = "DAMAGER" }
        H.focus = "ally"
        H.R.Refresh()
        assert(Active(H).focus and Active(H).party1)
        local count = #H.auraSounds
        H.combat, H.secretAuras = true, true
        pi.focusSound = false
        H.R.Refresh()
        assert(not Active(H).focus and Active(H).party1,
            "disabling focus sounds must remove only focus registrations immediately")
        assert(#H.auraSounds == count, "removing a context must not register sounds in combat")
    end },
    { "focus eligibility matches visual tracking", function()
        local H = Ready()
        H.units.ally = { name = "Friend", guid = "f", role = "DAMAGER" }
        for _, focus in ipairs({ "missing", "player", "enemy", "pet", "party1", "ally" }) do
            H.units.enemy = { name = "Enemy", guid = "e", friendly = false }
            H.units.pet = { name = "Pet", guid = "pet", isPlayer = false }
            H.focus = focus
            H.emit("PLAYER_FOCUS_CHANGED")
            local valid = focus == "party1" or focus == "ally"
            assert((H.R.Focus() ~= nil) == valid, "fixture must exercise actual focus eligibility")
            assert((Active(H).focus == true) == valid,
                "native focus sounds must reject absent, self, hostile and non-player focus: " .. focus)
            assert((Active(H).party1 == true) == (focus ~= "party1"),
                "only a valid group focus suppresses party sounds")
        end
    end },
    { "roster and focus changes remove stale sounds while restricted", function()
        local H, pi = Ready()
        H.R.Refresh()
        assert(Active(H).party1)
        H.combat, H.secretAuras = true, true
        H.units.party1.role = "HEALER"
        H.emit("GROUP_ROSTER_UPDATE")
        assert(not Active(H).party1, "a newly ineligible roster member must lose its registration")
        H.combat = false
        H.units.party1.role, H.focus = "DAMAGER", "party1"
        H.emit("PLAYER_REGEN_ENABLED")
        assert(Active(H).focus and not Active(H).party1)
        local count = #H.auraSounds
        H.encounter, H.focus = true, "player"
        H.emit("PLAYER_FOCUS_CHANGED")
        assert(next(Active(H)) == nil, "invalid focus registrations must be removed during encounters")
        assert(#H.auraSounds == count, "replacement party sounds must wait for restrictions to lift")
        H.encounter = false
        H.emit("ADDON_RESTRICTION_STATE_CHANGED")
        assert(Active(H).party1 and not Active(H).focus, "valid party targets rearm after the encounter")
        pi.spells[190319] = false
        H.combat = true
        H.R.Refresh()
        for _, info in ipairs(H.auraSounds) do
            assert(info.removed or info.spellID ~= 190319, "deselected buffs must stop sounding during combat")
        end
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
assert(failures == 0, tostring(failures) .. " sound-targeting regressions")
print("OK: native sounds remove stale targets under restrictions and validate focus eligibility")
