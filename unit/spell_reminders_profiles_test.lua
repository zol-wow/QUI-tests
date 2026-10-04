local env = dofile("tools/_addon_env.lua")
local h = env.BuildHarness({ noSeed = true })
local M = assert(loadfile("QUI_Reminders/spell_reminders/model.lua"))("QUI", {})
local core, profile = h.QUICore, h.db.profile
local pi, innervate = M.New(10060), M.New(29166)
pi.pi.whisper.enabled = true
pi.pi.whisper.rotation = { "Mage-Realm", "Warrior-Realm" }
pi.pi.customSpells = { 123456 }
innervate.label, innervate.x, innervate.ttsCountdown = "Innervate now", 245, true
profile.spellReminders = { enabled = true, reminders = { [10060] = pi, [29166] = innervate } }
profile.frameAnchoring = { ["spellReminder:10060"] = { parent = "UIParent", point = "CENTER", relative = "CENTER", offsetX = 40, offsetY = 80 } }
local settings = assert(core:ExportProfileSelectionToString({ "trackersTimers" }))
local withLayout = assert(core:ExportProfileSelectionToString({ "trackersTimers", "layout" }))
profile.spellReminders = { enabled = false, reminders = {} }
profile.frameAnchoring["spellReminder:10060"].offsetX = 900
local ok, err = core:ImportProfileSelectionFromString(settings, { "trackersTimers" })
assert(ok, tostring(err))
profile = h.db.profile
local imported = profile.spellReminders
assert(imported.enabled and imported.reminders[10060].pi.whisper.rotation[2] == "Warrior-Realm")
assert(imported.reminders[10060].pi.customSpells[1] == 123456)
assert(imported.reminders[29166].label == "Innervate now" and imported.reminders[29166].x == 245)
assert(imported.reminders[29166].ttsCountdown and not imported.reminders[29166].useEstimate)
assert(profile.frameAnchoring["spellReminder:10060"].offsetX == 900,
    "settings-only import preserves the current relative anchors")
ok, err = core:ImportProfileSelectionFromString(withLayout, { "trackersTimers", "layout" })
assert(ok, tostring(err))
assert(h.db.profile.frameAnchoring["spellReminder:10060"].offsetX == 40,
    "including Layout restores relative reminder anchors")
print("OK: spell reminder selective export/import preserves nested settings and layout selection")
