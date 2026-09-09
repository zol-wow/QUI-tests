-- tests/unit/reminders_engine_test.lua
-- Run: lua tests/unit/reminders_engine_test.lua
--
-- The engine arms a fire at duration - leadTime for opted-in abilities only,
-- disarms on bar stop, gates on tank ownership and coverage, dedupes within the
-- linger window, and fans the pick out to every enabled output.
-- luacheck: globals CreateFrame C_Timer GetTime GetInstanceInfo QUI issecretvalue time

local SECRET = { __secret = true }
function issecretvalue(v) return type(v) == "table" and v.__secret == true end

local now = 1000
function GetTime() return now end
function time() return 1700000000 end
local instanceType = "party"
function GetInstanceInfo() return "Ara-Kara", instanceType end

local timers = {}
C_Timer = {}
function C_Timer.NewTimer(delay, fn)
    local t = { delay = delay, fn = fn, cancelled = false }
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
end
local function fireTimers()
    local list = timers
    timers = {}
    for _, t in ipairs(list) do
        if not t.cancelled then t.fn() end
    end
end

local frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(name, fn) self[name] = fn end
    frames[#frames + 1] = f
    return f
end

local db = {
    enabled = true, source = "auto", inDungeons = true, inRaids = true, elsewhere = false,
    leadTime = 3, linger = 4, onlyWhenTanking = true, skipWhenCovered = true,
    fireOnMessages = true, timelineAllEvents = true, cdmGlow = true,
    display = {}, sound = { mode = "sound", sound = "Alarm" }, chat = { enabled = false, channel = "PARTY" },
    priorities = { [250] = { 48792, 55233, "slot:13" } },
    abilities = { [2001] = { [777] = true }, [2002] = { [888] = true } },
}
QUI = { db = { profile = { reminders = db }, global = { reminders = { seen = {} } } } }

local ns = {
    Helpers = {
        IsSecretValue = function(v) return issecretvalue(v) end,
        CreateDBGetter = function(key) return function() return QUI.db.profile[key] end end,
    },
    L = setmetatable({}, { __index = function(_, k) return k end }),
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
    WhenLoggedIn = function(fn) fn() end,
}

-- Collaborator stubs -------------------------------------------------------
local ready = { [48792] = false, [55233] = true, ["slot:13"] = true }
local tanking, covered = true, false
ns.RemindersDefensives = {
    PlayerSpecID = function() return 250 end,
    PlayerRole = function() return "TANK" end,
    IsTankingBoss = function() return tanking end,
    IsCovered = function() return covered end,
    Describe = function(id) return { id = id, spellID = type(id) == "number" and id or 999, name = "S" .. tostring(id), icon = 1 } end,
    Pick = function(list)
        for _, id in ipairs(list) do
            if ready[id] == true then return ns.RemindersDefensives.Describe(id), true end
        end
        return nil, false
    end,
}
local shown = {}
ns.RemindersCallout = {
    Show = function(entry, opts) shown[#shown + 1] = { entry = entry, opts = opts }; return true end,
    Hide = function() end, Refresh = function() end, GetFrame = function() return {} end,
    IsPreviewActive = function() return false end,
}
local sounds, spoken, chat = {}, {}, {}
ns.Announce = {
    PlaySound = function(key) sounds[#sounds + 1] = key; return true end,
    Speak = function(text) spoken[#spoken + 1] = text; return true end,
    Chat = function(msg, channel) chat[#chat + 1] = { msg = msg, channel = channel }; return true end,
}
local glows = {}
local cdmIcon = { name = "icon" }
ns._OwnedGlows = {
    FindIconBySpellID = function(id) if id == 55233 then return cdmIcon end end,
    GetViewerType = function() return "essential" end,
    GetViewerSettings = function() return { glowType = "Pixel Glow" } end,
    ApplyGlowWithKey = function(icon, settings, key) glows[#glows + 1] = { icon = icon, key = key, settings = settings }; return true end,
    StopGlowWithKey = function(icon, key) glows[#glows + 1] = { stop = true, icon = icon, key = key } end,
}
local bus = { subs = {}, preferred = nil }
ns.BossMods = {
    Subscribe = function(key, handlers) bus.subs[key] = handlers; return true end,
    Unsubscribe = function(key) bus.subs[key] = nil end,
    SetPreferredSource = function(s) bus.preferred = s end,
}

assert(loadfile("QUI_Reminders/reminders/engine.lua"))("QUI_Reminders", ns)
local R = assert(ns.Reminders)

-- Login refresh subscribes when enabled.
assert(R.IsSubscribed() and bus.subs.QUI_Reminders == R.Handlers, "enabled profile subscribes to the bus")
assert(bus.preferred == "auto")
local H = R.Handlers

-- Not opted in: nothing armed. Opted in: armed at duration - lead.
H.onTimer({ source = "bigwigs", spellID = 111, duration = 10, barID = "bigwigs:A" })
assert(R.PendingCount() == 0 and #timers == 0, "unknown ability must not arm")
H.onTimer({ source = "bigwigs", spellID = 777, duration = 10, barID = "bigwigs:B", text = "B" })
assert(R.PendingCount() == 1 and #timers == 1 and timers[1].delay == 7, "armed at duration - leadTime")
assert(QUI.db.global.reminders.seen[777].count == 1 and QUI.db.global.reminders.seen[111].count == 1, "every broadcast is catalogued")

-- Re-arming the same bar replaces the old timer; stopping it disarms.
H.onTimer({ source = "bigwigs", spellID = 777, duration = 12, barID = "bigwigs:B" })
assert(timers[1].cancelled and timers[2].delay == 9, "re-armed bar cancels the previous timer")
H.onTimerStop({ source = "bigwigs", barID = "bigwigs:B" })
assert(timers[2].cancelled and R.PendingCount() == 0, "stop disarms")

-- Fire: tank on boss, not covered -> first ready entry (55233) with all outputs.
timers = {}
H.onTimer({ source = "bigwigs", spellID = 777, duration = 10, barID = "bigwigs:B" })
fireTimers()
assert(#shown == 1 and shown[1].entry.spellID == 55233 and shown[1].opts.duration == 4, "callout shows the first ready defensive for the linger time")
assert(#sounds == 1 and sounds[1] == "Alarm", "sound plays")
assert(#glows == 1 and glows[1].icon == cdmIcon and glows[1].key == "_QUIReminders", "CDM icon glows under a private key")
assert(#chat == 0, "chat off by default")
assert(#timers == 1 and timers[1].delay == 4, "glow timer scheduled for the linger")

-- Dedupe: the message for the same cast inside the linger window is silent.
H.onMessage({ source = "bigwigs", spellID = 777, text = "B" })
assert(#shown == 1, "duplicate within linger window suppressed")
now = now + 10
H.onMessage({ source = "bigwigs", spellID = 777, text = "B" })
assert(#shown == 2, "message after the window fires again")

-- Chat + TTS outputs.
db.chat.enabled = true
db.sound.mode = "tts"
now = now + 10
H.onMessage({ source = "dbm", spellID = 888, text = "Bite" })
assert(#chat == 1 and chat[1].channel == "PARTY" and chat[1].msg:find("S55233", 1, true), "chat names the defensive: " .. tostring(chat[1] and chat[1].msg))
assert(#spoken == 1 and spoken[1] == "S55233", "TTS speaks the defensive name")
db.sound.ttsMode = "custom"
db.sound.ttsText = "  "
assert(R.SpokenText({ name = "Barkskin" }, db.sound) == "Barkskin", "blank custom phrase falls back to the name")
db.sound.ttsText = "defensive"
assert(R.SpokenText({ name = "Barkskin" }, db.sound) == "defensive", "custom phrase replaces the name")
assert(R.SpokenText({ name = "Barkskin" }, { ttsMode = "name", ttsText = "defensive" }) == "Barkskin", "name mode ignores the phrase")
db.sound.ttsMode = "name"

-- Tank gate: readable "not tanking" blocks; unknown fails open.
now = now + 10
tanking = false
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 3, "boss on the other tank: no callout")
tanking = nil
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 4, "unknown threat fails open")
tanking = true

-- Coverage: an active listed defensive silences the call; unknown fails open.
now = now + 10
covered = true
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 4, "covered: no callout")
covered = nil
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 5, "unknown coverage fails open")
covered = false

-- Nothing ready: no callout, and the dedupe window is not consumed.
now = now + 10
ready[55233] = false
ready["slot:13"] = false
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 5, "nothing ready: silent")
ready[55233] = true
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 6, "a silent decision does not start the dedupe window")

-- Lead time longer than the bar fires at once. Negative lead fires after landing.
now = now + 10
timers = {}
H.onTimer({ source = "bigwigs", spellID = 777, duration = 2, barID = "bigwigs:C" })
assert(#shown == 7 and #timers == 1, "duration under the lead time fires immediately (only the glow timer remains)")
db.leadTime = -2
now = now + 10
timers = {}
H.onTimer({ source = "bigwigs", spellID = 777, duration = 5, barID = "bigwigs:D" })
assert(timers[1].delay == 7, "negative lead time arms after the landing")
H.onTimerStop({ source = "bigwigs", barID = "bigwigs:D" })
assert(R.PendingCount() == 0, "stop disarms the delayed call")
db.leadTime = 3

-- Blizzard timeline: anonymous events count only when the option says so.
now = now + 10
H.onTimer({ source = "timeline", secretIdentity = true, duration = 1, barID = "timeline:9" })
assert(#shown == 8, "timeline event with unknown identity fires under timelineAllEvents")
db.timelineAllEvents = false
now = now + 10
H.onTimer({ source = "timeline", secretIdentity = true, duration = 1, barID = "timeline:10" })
assert(#shown == 8, "timelineAllEvents off: anonymous events ignored")
db.timelineAllEvents = true

-- Context gates.
instanceType = "none"
now = now + 10
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 8, "outside instances: silent by default")
db.elsewhere = true
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 9, "elsewhere on: fires")
instanceType = "raid"
db.inRaids = false
now = now + 10
H.onMessage({ source = "bigwigs", spellID = 777 })
assert(#shown == 9, "raids off: silent")
db.inRaids = true
instanceType = "party"

-- Encounter end cancels everything armed.
timers = {}
H.onTimer({ source = "bigwigs", spellID = 777, duration = 30, barID = "bigwigs:E" })
assert(R.PendingCount() == 1)
local eventFrame
for _, f in ipairs(frames) do if f.events.ENCOUNTER_END then eventFrame = f end end
assert(eventFrame, "engine listens for ENCOUNTER_END")
eventFrame.OnEvent(eventFrame, "ENCOUNTER_START", 3001)
assert(R.ActiveEncounter() == 3001)
eventFrame.OnEvent(eventFrame, "ENCOUNTER_START", SECRET)
assert(R.ActiveEncounter() == nil, "secret encounter id collapses to nil")
eventFrame.OnEvent(eventFrame, "ENCOUNTER_END")
assert(R.PendingCount() == 0 and timers[1].cancelled, "encounter end disarms")

-- Opted-in set is cached and invalidated on demand.
assert(R.OptedSpells()[777] and R.OptedSpells()[888] and not R.OptedSpells()[111])
db.abilities[2003] = { [111] = true }
assert(not R.OptedSpells()[111], "cache holds until marked dirty")
R.MarkAbilitiesDirty()
assert(R.OptedSpells()[111], "dirty mark rebuilds the union")

-- Disabling unsubscribes and disarms.
db.enabled = false
R.Refresh()
assert(not R.IsSubscribed() and bus.subs.QUI_Reminders == nil, "disabled profile unsubscribes")

-- Test command reports the pick without gates.
db.enabled = true
R.Refresh()
local pick = R.Test()
assert(pick and pick.spellID == 55233)

-- Seen catalogue stays bounded.
for i = 1, 450 do R.RecordSeen({ spellID = 10000 + i, source = "bigwigs" }) end
local n = 0
for _ in pairs(QUI.db.global.reminders.seen) do n = n + 1 end
assert(n <= 400, "seen catalogue capped, got " .. n)

print("OK: reminders_engine_test")
