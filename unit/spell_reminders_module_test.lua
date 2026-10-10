local H = (dofile("tests/helpers/spell_reminders.lua"))({ deferRuntime = true })
assert(not H.ns.SpellReminders and #H.timers == 0, "an unloaded module has no reminder runtime")

-- Existing profiles keep their original keys, including PI settings and anchors.
local saved = { spellID = 10060, label = "My PI", pi = { partySound = true, sound = "QUI Reminder Bell" } }
H.db.reminders[10060] = saved
H.profile.frameAnchoring["spellReminder:10060"] = { offsetX = 35, offsetY = 65 }
H.loggedIn = true
H.LoadRuntime()

assert(H.R.Get(10060) == saved and saved.label == "My PI", "loading keeps the existing reminder configuration")
local host = assert(H.R.hosts[10060], "a module loaded after login initializes immediately")
assert(host.points[1][4] == 35 and host.points[1][5] == 65, "existing frame anchors survive the move")
assert(host.request and host.focusReminder and host.sample,
    "tracking loads before the initial refresh creates the PI presentation")
assert(H.T.cells[H.cell].container.enabled, "group-frame tracking is configured on the first refresh")
assert(#H.auraSounds > 0 and #H.timers == 2, "initialization installs audio and maintenance once")
H.profileRefresh()
assert(H.R.Get(10060) == saved and H.T.cells[H.cell].container.enabled, "profile refresh reaches the loaded module")
print("OK: spell reminders load after login through QUI_Reminders and preserve profile settings")
