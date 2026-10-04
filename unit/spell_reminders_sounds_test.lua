local H = (dofile("tests/helpers/spell_reminders.lua"))()
local R, S = H.R, H.ns.SpellReminderSounds
local config = R.Add(10060)
config.combatOnly, config.pi.focusSound = true, true
config.pi.sound = "QUI Reminder Bell"
H.focus = "party1"
R.Refresh()
assert(H.T.cells[H.cell], "combat-only tracking prepares frames before combat")
assert(not H.T.cells[H.cell].container.enabled)
local count = #H.auraSounds
assert(count > 0, "native focus sounds are registered before combat")
S.Reconcile(config.pi, true)
assert(#H.auraSounds == count, "unchanged registrations are reused")
config.pi.soundChannel = "Dialog"
H.blockSound = true
S.Reconcile(config.pi, true)
assert(#H.auraSounds == count and H.auraSounds[1].removed and next(S.registrations) == nil,
    "failed replacement must not retain the old sound configuration")
H.blockSound = false
S.Reconcile(config.pi, true)
assert(#H.auraSounds == count * 2, "retry installs the new sound configuration")
H.combat, H.secretAuras = true, true
H.emit("PLAYER_REGEN_DISABLED")
assert(H.T.cells[H.cell].container.enabled, "combat-only tracking activates its prepared slots")
config.pi.soundChannel = "Master"
S.Reconcile(config.pi, true)
assert(#H.auraSounds == count * 2, "restricted refresh does not try to register new sounds")
H.combat = false
H.emit("PLAYER_REGEN_ENABLED")
assert(#H.auraSounds == count * 3, "native sound changes apply between M+ pulls while auras remain secret")
H.combat = true
H.db.enabled = false
R.Refresh()
assert(next(S.registrations) == nil, "disabling in combat removes sounds immediately through the runtime")
local originalAdd = C_UnitAuras.AddAuraSound
H.combat, H.secretAuras = false, false
local calls = 0
C_UnitAuras.AddAuraSound = function(...)
    calls = calls + 1
    if calls == 2 then return nil end
    return originalAdd(...)
end
S.Reconcile(config.pi, true)
assert(next(S.registrations) == nil and H.auraSounds[#H.auraSounds].removed,
    "partial registration rolls back without leaving duplicate sounds")
C_UnitAuras.AddAuraSound = originalAdd
H.db.enabled = true
H.secretAuras, H.encounter = true, true
H.emit("PLAYER_REGEN_ENABLED")
assert(next(S.registrations) == nil, "an encounter still blocks registration after leaving combat")
H.encounter = false
H.emit("ADDON_RESTRICTION_STATE_CHANGED")
assert(next(S.registrations), "restriction changes retry sounds without modifying secret aura artwork")

local function Active()
    local units, total = {}, 0
    for _, info in ipairs(H.auraSounds) do
        if not info.removed then
            units[info.unitToken] = (units[info.unitToken] or 0) + 1
            total = total + 1
        end
    end
    return units, total
end
local pi = config.pi
pi.focusSound, pi.partySound = false, true
H.focus = nil
R.roster = {}
H.emit("PLAYER_ENTERING_WORLD")
local units = Active()
assert(units.party1 and not units.focus and not units.player and not units.party2,
    "refreshing inside a key rebuilds sound recipients, excluding self and unlisted healers")
pi.party.mode, pi.names = "listed", { "Healer-Realm" }
S.Refresh()
units = Active()
assert(units.party2 and not units.party1, "sound targets respect the configured player list")
pi.focusSound = true
H.focus = "party2"
H.emit("PLAYER_FOCUS_CHANGED")
units = Active()
assert(units.focus and not units.party1 and not units.party2, "group focus priority avoids duplicate audio")
H.focus = nil
H.emit("PLAYER_FOCUS_CHANGED")
pi.raidSound, H.raid = true, true
H.units.raid1, H.units.raid2, H.units.raid3 = H.units.player, H.units.party1, H.units.party2
H.emit("GROUP_ROSTER_UPDATE")
units = Active()
assert(units.raid2 and units.raid3 and not units.raid1 and not units.party2,
    "raid sounds follow raid recipients and retire party registrations")

local beforeMedia = #H.auraSounds
pi.sound = "Shared Alert"
H.ns.LSM = { Fetch = function(_, kind, name)
    assert(kind == "sound" and name == "Shared Alert")
    return "Interface\\AddOns\\SharedMedia\\sound\\alert.ogg"
end }
S.Refresh()
local info = H.auraSounds[beforeMedia + 1]
assert(info.soundFileName == "Interface\\AddOns\\SharedMedia\\sound\\alert.ogg" and info.soundFileID == nil,
    "shared-media files use the native filename field")
S.Play(pi.sound, pi.soundChannel)
assert(H.sounds[#H.sounds] == info.soundFileName, "preview and native registration resolve the same selected sound")
local _, total = Active()
local prior = #H.auraSounds
S.Refresh()
assert(#H.auraSounds == prior and total > 0, "maintenance reuses unchanged registrations")
pi.focusSound, pi.partySound, pi.raidSound = false, false, false
H.combat = true
S.Refresh()
assert(next(S.registrations) == nil, "turning off every sound context clears registrations immediately")

-- Exercise the real cast/cooldown event path. Registered native sounds must
-- close with the PI readiness gate, even while adding them is restricted.
H = (dofile("tests/helpers/spell_reminders.lua"))()
R, S = H.R, H.ns.SpellReminderSounds
config = R.Add(10060)
pi = config.pi
pi.partySound, pi.raidSound, pi.focusSound = true, true, true
pi.sound = "QUI Reminder Bell"
R.Refresh()
assert(next(S.registrations), "ready PI arms native ally cooldown sounds")
H.combat, H.secretAuras = true, true
H.emit("PLAYER_REGEN_DISABLED")
H.emit("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 10060)
assert(R.states[10060].cooldown.ready == false, "the cast gates the stale cooldown API immediately")
assert(not H.T.cells[H.cell].container.enabled, "casting PI disables the frame glow")
assert(next(S.registrations) == nil, "casting PI immediately removes all native ally cooldown sounds")

H.cooldowns[10060] = { isActive = true, isEnabled = true, startTime = H.now, duration = 120 }
H.now = H.now + 1
H.emit("SPELL_UPDATE_COOLDOWN")
S.Refresh()
assert(next(S.registrations) == nil, "maintenance cannot rearm sounds while PI is unavailable")
H.combat = false
H.emit("PLAYER_REGEN_ENABLED")
assert(next(S.registrations) == nil, "leaving combat does not rearm a cooling-down PI")

pi.onlyWhenReady, pi.grace = false, 15
H.now = H.now + 110
R.Refresh()
assert(next(S.registrations) == nil, "always-on visuals and the early window never arm unavailable-PI sounds")
H.now = H.now + 20
config.useEstimate = true
H.cooldowns[10060] = { isActive = true, isEnabled = true }
R.Update()
assert(next(S.registrations) == nil, "an expired estimate cannot arm native sounds")
H.cooldowns[10060] = { isEnabled = true }
R.Update()
assert(next(S.registrations) == nil, "unknown readiness stays silent")

H.combat, H.encounter = true, true
H.cooldowns[10060] = { isActive = false, isEnabled = true, startTime = 0, duration = 0 }
H.emit("SPELL_UPDATE_COOLDOWN")
assert(next(S.registrations) == nil, "PI becoming ready in combat cannot re-register native sounds")
H.combat = false
H.emit("PLAYER_REGEN_ENABLED")
assert(next(S.registrations) == nil, "encounter restrictions still defer rearming after combat ends")
H.encounter = false
H.emit("ADDON_RESTRICTION_STATE_CHANGED")
assert(next(S.registrations), "ready PI rearms once restrictions lift, including between M+ pulls")

H.cooldowns[10060] = { isActive = true, isEnabled = true, startTime = H.now, duration = 1.5, isOnGCD = true }
H.emit("SPELL_UPDATE_COOLDOWN")
assert(next(S.registrations), "an unrelated global cooldown does not remove the armed sounds")
H.combat = true
H.cooldowns[10060] = { isActive = true, isEnabled = true, startTime = H.now, duration = 120 }
H.emit("SPELL_UPDATE_COOLDOWN")
assert(next(S.registrations) == nil, "a real cooldown update closes audio even without a cast event")
H.combat = false
H.emit("PLAYER_REGEN_ENABLED")
H.cooldowns[10060] = { isActive = false, isEnabled = true, startTime = 0, duration = 0 }
R.Update()
assert(next(S.registrations), "PI becoming ready out of combat rearms without a settings change")
print("OK: native sound lifecycle, M+ retries, recipient scopes and shared media")
