local ns = {}
local sentinel = dofile("tests/helpers/secret_sentinel.lua")
local restore = sentinel.InstallSecretStub()
local M = assert(sentinel.LoadInstrumented("QUI_Reminders/spell_reminders/model.lua"))("QUI", ns)
assert(loadfile("QUI_Reminders/spell_reminders/catalog.lua"))("QUI", ns)
local secret = sentinel.MakeSecretSentinel()

local config = M.New(29166)
assert(config.useEstimate == false and config.estimatedCooldown == 180)
assert(config.classID == 11 and config.pi == nil)
local piConfig = M.New(10060)
assert(piConfig.pi.enabled and not piConfig.pi.whisper.enabled)
local other = M.New(10060)
piConfig.pi.names[1] = "Test"
assert(#other.pi.names == 0, "presets must not share mutable lists")

local info = { isActive = true, isEnabled = true, startTime = secret, duration = secret, modRate = secret }
local cd = M.Cooldown(info, 177, true, nil, 0, config)
assert(cd.ready == false and cd.remaining == nil, "secret durations cannot become estimates by default")
config.useEstimate = true
cd = M.Cooldown(info, 177, true, nil, 0, config)
assert(cd.ready == false and cd.estimated and cd.remaining == 3)
cd = M.Cooldown(info, 190, true, nil, 0, config)
assert(cd.ready == false and cd.remaining == 0, "expired estimate is not proof of readiness")
assert(not M.PIReady({ onlyWhenReady = true, grace = 3 }, cd), "expired estimates cannot open PI requests")
info.isActive = false
cd = M.Cooldown(info, 100, true, nil, 0, config)
assert(cd.ready == true, "a public cooldown reset takes precedence over the estimate")
info.isEnabled = false
assert(M.Cooldown(info, 100, true, nil, 0, config).ready == false, "on-hold cooldowns are not ready")
info.isEnabled, info.isActive, info.isOnGCD = true, true, true
assert(M.Cooldown(info, 100, true, nil, nil, config).ready, "GCD alone must not trigger a spell cooldown")
assert(not M.Cooldown(info, 100, false, nil, nil, config).ready, "isOnGCD is only trustworthy on cooldown events")
info.isOnGCD = nil
local chargeInfo = { currentCharges = 1, cooldownStartTime = secret, cooldownDuration = secret }
assert(M.Cooldown(info, 100, true, nil, nil, config, chargeInfo).ready, "one charge is sufficient")
chargeInfo.currentCharges = secret
assert(M.Cooldown(info, 100, true, nil, nil, config, chargeInfo).ready == false)
info = { isActive = true, isEnabled = true, startTime = 20, duration = 180, modRate = 1 }
assert(M.Cooldown(info, 180, true, nil, nil, config).remaining == 20)
assert(M.Cooldown(info, 180, true, nil, nil, config, nil, 8).remaining == 8,
    "readable duration objects account for cooldown time modifiers")
assert(M.Cooldown(info, 180, true, nil, nil, config, nil, secret).remaining == 20)

config.showBeforeReady, config.ttsCountdown = true, true
local state = {}
local output = M.Step(config, state, { ready = true }, 0, true)
assert(output.show and not output.readyNotice, "login can show a ready icon without speaking")
assert(not M.Step(config, state, { ready = true }, 6, true).show, "finite ready window expires")
M.Step(config, state, { ready = false, remaining = 120 }, 10, true)
output = M.Step(config, state, { ready = false, remaining = 3, estimated = true }, 127, true)
assert(output.show and output.earlyNotice and output.countdown == 3)
output = M.Step(config, state, { ready = false, remaining = 2.9 }, 127.1, true)
assert(not output.earlyNotice and not output.countdown, "sounds must not repeat each update")
assert(M.Step(config, state, { ready = true }, 130, true).readyNotice)
assert(not M.Step(config, state, { ready = true }, 131, true).readyNotice)
assert(not M.Step(config, state, { ready = true }, 132, false).show)
state.encounterAt = 200
assert(M.Step(config, state, { ready = false }, 201, true).show)
assert(not M.Step(config, state, { ready = false }, 206, true).show)
state.encounterAt = 210
assert(M.Step(config, state, { ready = true }, 210, true).readyNotice)
assert(not M.Step(config, state, { ready = true }, 210.1, true).readyNotice,
    "an encounter-start announcement is spoken once")

local roster = {
    { unit = "party1", guid = "a", name = "Same", realm = "RealmOne", role = "DAMAGER" },
    { unit = "party2", guid = "b", name = "Same", realm = "RealmTwo", role = "HEALER" },
    { unit = "party3", guid = "c", name = "Tank", realm = "RealmTwo", role = "TANK" },
}
local names = M.ParseNames(" Same-RealmTwo, Same-RealmTwo ; Missing \n Tank ")
assert(#names == 3)
assert(M.SelectRecipient(names, roster, 1, false).guid == "b")
assert(M.SelectRecipient({ "Same-MissingRealm" }, roster) == nil, "qualified names cannot match another realm")
local member, index = M.SelectRecipient(names, roster, 2, false)
assert(member.guid == "c" and index == 3, "skip absent names in a rotation")
assert(M.SelectRecipient(names, roster, 4, false) == nil, "noncycling rotation can be exhausted")
assert(M.SelectRecipient(names, roster, 4, true).guid == "b")
local pi = other.pi
assert(M.WatchScope(pi, roster[1], "party") == "party")
assert(M.WatchScope(pi, roster[2], "party") == nil)
pi.names = { "Same-RealmTwo" }
assert(M.WatchScope(pi, roster[2], "party") == "party", "listed healers are allowed")
assert(M.WatchScope(pi, roster[1], "party", "b") == nil, "focus is exclusive")
assert(M.WatchScope(pi, roster[2], "party", "b") == "focus")
pi.focus.enabled = false
assert(M.WatchScope(pi, roster[1], "party", "b") == "party")
pi.party.mode = "listed"
assert(M.WatchScope(pi, roster[1], "party") == nil)
roster[2].self = true
assert(M.WatchScope(pi, roster[2], "party") == nil, "never suggest self")

local ids = M.BuffIDs(pi, "raid")
assert(ids[190319] and not ids[1236994], "major cooldowns default on, potions off")
pi.separateBuffs, pi.spellScopes[1236994] = true, { raid = true }
assert(M.BuffIDs(pi, "raid")[1236994] and not M.BuffIDs(pi, "party")[1236994])
pi.customSpells = { 123 }
assert(M.BuffIDs(pi, "focus")[123])
config.specs = { [105] = true }
local context = { known = true, classID = 11, specID = 105, instance = "party", combat = true }
assert(M.Allowed(config, context))
context.specID = 102
assert(not M.Allowed(config, context))
sentinel.RestoreSecretStub(restore)
print("OK: spell reminder timing, secrecy, recipients and context policies")
