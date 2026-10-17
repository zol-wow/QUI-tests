do
    local deferred = (dofile("tests/helpers/spell_reminders.lua"))()
    deferred.secretAuras = true
    assert(not deferred.combat)
    assert(deferred.R.Add(10060))
    assert(deferred.R.pending and not deferred.R.hosts[10060] and #deferred.timers == 0,
        "the first reminder must defer its host and timers while auras are secret")
    for _ = 1, 2 do
        deferred.emit("ADDON_RESTRICTION_STATE_CHANGED")
        assert(deferred.R.pending and not deferred.R.hosts[10060] and #deferred.timers == 0,
            "restriction events must preserve deferred initialization while auras remain secret")
    end
    deferred.secretAuras = false
    deferred.emit("ADDON_RESTRICTION_STATE_CHANGED")
    assert(not deferred.R.pending and deferred.R.hosts[10060],
        "lifting aura restrictions must initialize the first reminder without an unrelated event")
    assert(#deferred.timers == 2, "lifting restrictions must start update and maintenance timers")
    for _, timer in ipairs(deferred.timers) do
        assert(not timer.cancelled, "deferred initialization must leave both timers active")
        timer.callback()
    end
    assert(not deferred.R.pending and deferred.R.hosts[10060].shown,
        "the recovered reminder must remain active after its timers run")
end

local H = (dofile("tests/helpers/spell_reminders.lua"))()
local R, T = H.R, H.T
H.profile.frameAnchoring["spellReminder:10060"] = { offsetX = 40, offsetY = 80 }
local piConfig = R.Add(10060)
local host = R.hosts[10060]
assert(host.points[1][4] == 40 and host.points[1][5] == 80, "saved anchors apply on first creation")
host.drag.scripts.OnDragStop()
assert(not H.profile.frameAnchoring["spellReminder:10060"], "dragging clears the saved relative anchor")
local mover = H.ns.QUI_LayoutMode.elements["spellReminder:10060"]
mover.setGameplayHidden(true)
R.Refresh()
assert(not host.shown and not R.previews[10060], "Layout Mode's gameplay hide remains hidden after refresh")
mover.setGameplayHidden(false)
assert(host.shown)
local pi = piConfig.pi
pi.glowStyle = "proc"
H.cell:SetSize(140, 75)
pi.party.alert, pi.party.duration = true, true
pi.whisper.enabled, pi.whisper.sound = true, true
pi.sound = "QUI Reminder Bell"
pi.whisper.names = { "Mage-Realm", "Healer-Realm" }
R.Refresh()
local record = assert(T.cells[H.cell])
-- The flipbook's visible border sits inside transparent margins. Like
-- LibCustomGlow, expand by 20% on each side to put that border at the host edges.
local glowPoints = record.art.proc.points
assert(glowPoints[1] and glowPoints[1][4] == -28 and glowPoints[1][5] == 15,
    "proc glow compensates for transparent margins on a rectangular group frame")
assert(glowPoints[2][4] == 28 and glowPoints[2][5] == -15)
assert(record.container.enabled and record.container.boundUnit == "party1")
assert(record.container.filters.includeSpellIDs[190319])
H.cell:SetSize(200, 90)
T.Discover()
assert(record.art.proc.points[1][4] == -40 and record.art.proc.points[1][5] == 18,
    "frame resizing updates the glow without changing reminder options")
assert(record.durationContainer.enabled)
assert(T.alerts[1].guid == "m" and T.alerts[1].container.enabled)
H.instance = "none"
R.Update()
assert(record.container.enabled, "the dungeon list also covers parties outside instances")
H.instance = nil

H.focus = "party2"
H.emit("PLAYER_FOCUS_CHANGED")
assert(not record.container.enabled, "group focus suppresses unrelated frames")
assert(T.alerts[2].container.enabled, "focus can be a healer")
H.focus = nil
H.emit("PLAYER_FOCUS_CHANGED")
assert(record.container.enabled and record.container.boundUnit == "party1", "re-enabling must rebind the unit")

local sentinel = dofile("tests/helpers/secret_sentinel.lua")
local prev = sentinel.InstallSecretStub()
local secret = sentinel.MakeSecretSentinel()
H.combat, H.secretAuras = true, true
H.emit("CHAT_MSG_WHISPER", secret, secret)
assert(T.request and T.request.guid == "m", "request uses the list without reading the payload")
assert(record.request.shown and R.hosts[10060].request.shown)
assert(#H.sounds == 1)
H.emit("CHAT_MSG_WHISPER", secret, secret)
assert(#H.sounds == 1, "repeated whispers do not replay the sound")
H.emit("UNIT_SPELLCAST_SUCCEEDED", "player", secret, 10060)
assert(T.request == nil and not record.container.enabled and not record.request.shown)
H.cooldowns[10060] = { isActive = true, isEnabled = true, startTime = secret, duration = secret }
H.now = H.now + 5
H.emit("SPELL_UPDATE_COOLDOWN")
H.emit("CHAT_MSG_WHISPER", secret, secret)
assert(T.request == nil, "whispers during cooldown are discarded")
H.cooldowns[10060].isActive = false
H.emit("SPELL_UPDATE_COOLDOWN")
assert(record.container.enabled and T.request == nil, "old whispers are not replayed on readiness")
H.emit("CHAT_MSG_BN_WHISPER", secret, secret)
assert(T.request == nil)

pi.whisper.mode, pi.whisper.rotation = "rotation", { "Missing", "Mage-Realm", "Healer-Realm" }
T.Reset()
H.emit("CHAT_MSG_WHISPER", secret, secret)
assert(T.request.index == 2)
H.emit("UNIT_SPELLCAST_SUCCEEDED", "player", secret, 10060)
assert(T.cursor == 3)
H.now = H.now + 1
H.emit("SPELL_UPDATE_COOLDOWN")
H.emit("CHAT_MSG_WHISPER", secret, secret)
assert(T.request.guid == "h")
H.units.party2 = { name = "Replacement", guid = "r", role = "DAMAGER" }
H.emit("GROUP_ROSTER_UPDATE")
assert(T.request == nil and not T.alerts[2].container.enabled, "roster changes must not label a replacement with a stale name")
H.cell.unit = "party2"
R.Update()
assert(record.container.boundUnit == "party2", "recycled cells must follow their current unit")
H.combat, H.secretAuras = false, false
H.emit("PLAYER_REGEN_ENABLED")
assert(T.alerts[2].guid == "r")

local oldHost = R.hosts[10060]
H.combat, H.secretAuras = true, true
R.Remove(10060)
H.emit("ENCOUNTER_START", 1)
assert(not record.container.enabled, "removing during combat disables tracking immediately")
H.combat, H.secretAuras = false, false
H.emit("PLAYER_REGEN_ENABLED")
R.Remove(10060)
assert(not record.container.enabled and not record.durationContainer.enabled)
R.Add(10060)
assert(R.hosts[10060] == oldHost, "re-adding reuses the host of existing aura slots")
assert(T.alerts[1].parent == oldHost)
T.cursor = 7
H.profileRefresh()
assert(T.cursor == 1, "profile refresh resets request rotation")

local count = #H.frames
for _ = 1, 50 do R.Update() end
assert(#H.frames == count, "the update loop does not allocate frames")
for _, frame in ipairs(H.frames) do
    if frame.auraSubtree then assert(next(frame.scripts) == nil, "aura artwork must remain scriptless") end
end
H.db.enabled = false
R.Refresh()
assert(not record.container.enabled and not R.hosts[10060].icon.shown)
sentinel.RestoreSecretStub(prev)
print("OK: spell reminder lifecycle, protected artwork, focus, whispers and roster changes")
