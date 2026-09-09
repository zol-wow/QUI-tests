-- tests/unit/reminders_bossmods_test.lua
-- Run: lua tests/unit/reminders_bossmods_test.lua
--
-- The boss-mod bus must normalize BigWigs, DBM and the Blizzard encounter
-- timeline into one event shape, reject secret values at the boundary, and
-- only forward events from the one active source.
-- luacheck: globals CreateFrame BigWigsLoader DBM C_EncounterTimeline Enum issecretvalue

local SECRET = { __secret = true }
function issecretvalue(v) return type(v) == "table" and v.__secret == true end

local ns = {
    Helpers = { IsSecretValue = function(v) return issecretvalue(v) end },
}

local frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(name, fn) self[name] = fn end
    frames[#frames + 1] = f
    return f
end

BigWigsLoader = { registered = {} }
function BigWigsLoader.RegisterMessage(owner, message, fn)
    assert(owner ~= BigWigsLoader, "must register with a table of our own, not the loader")
    BigWigsLoader.registered[message] = fn
end

DBM = { registered = {} }
function DBM:RegisterCallback(event, fn) self.registered[event] = fn end

local timelineState = {}
C_EncounterTimeline = {
    IsFeatureAvailable = function() return true end,
    GetEventState = function(id) return timelineState[id] end,
    GetEventTimeRemaining = function() return 4 end,
    GetEventInfo = function(id) return { id = id, source = 0, duration = 9, spellID = SECRET } end,
}
Enum = { EncounterTimelineEventState = { Active = 0, Paused = 1, Finished = 2, Canceled = 3 } }

assert(loadfile("core/safecall.lua"))("QUI", ns)
assert(loadfile("QUI_Reminders/reminders/bossmods.lua"))("QUI_Reminders", ns)
local B = assert(ns.BossMods)

local got = {}
local function record(kind)
    return function(evt) got[#got + 1] = { kind = kind, evt = evt } end
end
assert(B.Subscribe("test", {
    onTimer = record("timer"), onTimerStop = record("stop"), onMessage = record("message"),
    onStage = record("stage"), onReset = record("reset"),
}))
local function last() return got[#got] end
local function count() return #got end

assert(BigWigsLoader.registered.BigWigs_Timer, "BigWigs_Timer hooked")
assert(BigWigsLoader.registered.BigWigs_StopBar and BigWigsLoader.registered.BigWigs_Message, "BigWigs messages hooked")
assert(DBM.registered.DBM_TimerStart and DBM.registered.DBM_TimerStop and DBM.registered.DBM_Announce, "DBM callbacks hooked")
assert(B.ActiveSource() == "bigwigs", "auto picks BigWigs first, got " .. tostring(B.ActiveSource()))

-- BigWigs timer normalizes to the bus shape.
BigWigsLoader.registered.BigWigs_Timer("BigWigs_Timer", {}, 12345, 20, nil, "Tail Thrash (2)", 2, 136041, false, true)
local e = last().evt
assert(last().kind == "timer")
assert(e.source == "bigwigs" and e.spellID == 12345 and e.duration == 20, "timer fields")
assert(e.text == "Tail Thrash (2)" and e.barID == "bigwigs:Tail Thrash (2)", "bar identity is the bar text")
assert(e.icon == 136041 and e.approximate == false)

-- Secret duration: dropped entirely. Secret key: spell id is nil, event still flows.
local before = count()
BigWigsLoader.registered.BigWigs_Timer("BigWigs_Timer", {}, 12345, SECRET, nil, "x", 0, 1, false, true)
assert(count() == before, "secret duration must not reach subscribers")
BigWigsLoader.registered.BigWigs_Timer("BigWigs_Timer", {}, SECRET, 8, nil, "Anon", 0, 1, true, true)
assert(last().evt.spellID == nil and last().evt.key == nil and last().evt.approximate == true, "secret key collapses to nil")

BigWigsLoader.registered.BigWigs_StopBar("BigWigs_StopBar", {}, "Tail Thrash (2)")
assert(last().kind == "stop" and last().evt.barID == "bigwigs:Tail Thrash (2)" and last().evt.reason == "stop")
BigWigsLoader.registered.BigWigs_PauseBar("BigWigs_PauseBar", {}, "Tail Thrash (2)")
assert(last().kind == "stop" and last().evt.reason == "pause")
BigWigsLoader.registered.BigWigs_Message("BigWigs_Message", {}, 12345, "Tail Thrash!", "orange", 136041, true)
assert(last().kind == "message" and last().evt.spellID == 12345 and last().evt.emphasized == true)
BigWigsLoader.registered.BigWigs_SetStage("BigWigs_SetStage", {}, 2)
assert(last().kind == "stage" and last().evt.stage == 2)
BigWigsLoader.registered.BigWigs_OnBossWipe("BigWigs_OnBossWipe", {})
assert(last().kind == "reset" and last().evt.reason == "BigWigs_OnBossWipe")

-- DBM is present but not active: its events are filtered out.
before = count()
DBM.registered.DBM_TimerStart("DBM_TimerStart", "timer555cd", "Bite", 15, 136041, 1, 555)
assert(count() == before, "inactive source must be silent")

B.SetPreferredSource("dbm")
assert(B.ActiveSource() == "dbm")
DBM.registered.DBM_TimerStart("DBM_TimerStart", "timer555cd", "Bite", 15, 136041, 1, 555)
e = last().evt
assert(last().kind == "timer" and e.source == "dbm" and e.spellID == 555 and e.duration == 15, "DBM timer fields")
assert(e.barID == "dbm:timer555cd", "DBM bar identity is the timer id")
DBM.registered.DBM_TimerStop("DBM_TimerStop", "timer555cd")
assert(last().kind == "stop" and last().evt.barID == "dbm:timer555cd" and last().evt.reason == "stop")
DBM.registered.DBM_TimerPause("DBM_TimerPause", "timer555cd")
assert(last().evt.reason == "pause")
DBM.registered.DBM_Announce("DBM_Announce", "Bite incoming", 136041, "spell", 555)
assert(last().kind == "message" and last().evt.spellID == 555 and last().evt.text == "Bite incoming")
DBM.registered.DBM_SetStage("DBM_SetStage", {}, "mod", 3)
assert(last().kind == "stage" and last().evt.stage == 3)
before = count()
DBM.registered.DBM_TimerStart("DBM_TimerStart", SECRET, "Bite", 15, 136041, 1, 555)
assert(count() == before, "secret DBM timer id is dropped")

-- Blizzard timeline: anonymous countdowns keep flowing with secretIdentity.
B.SetPreferredSource("timeline")
assert(B.ActiveSource() == "timeline")
local tlFrame
for _, f in ipairs(frames) do
    if f.events.ENCOUNTER_TIMELINE_EVENT_ADDED then tlFrame = f end
end
assert(tlFrame and tlFrame.OnEvent, "timeline frame registered")
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 7, source = 0, duration = 9, spellID = SECRET, spellName = SECRET })
e = last().evt
assert(last().kind == "timer" and e.source == "timeline" and e.duration == 9, "timeline timer")
assert(e.spellID == nil and e.secretIdentity == true and e.barID == "timeline:7" and e.eventID == 7, "secret identity flagged")
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 8, source = 1, duration = 5, spellID = 4242, spellName = "Scripted" })
assert(last().evt.spellID == 4242 and last().evt.secretIdentity == false and last().evt.text == "Scripted", "script events are readable")
timelineState[7] = Enum.EncounterTimelineEventState.Paused
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 7)
assert(last().kind == "stop" and last().evt.barID == "timeline:7" and last().evt.reason == "pause", "pause stops the bar")
timelineState[7] = Enum.EncounterTimelineEventState.Active
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 7)
assert(last().kind == "timer" and last().evt.duration == 4 and last().evt.barID == "timeline:7", "resume re-arms with remaining time")
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_REMOVED", 7)
assert(last().kind == "stop" and last().evt.reason == "stop", "removal without completion is a cancel")
timelineState[8] = Enum.EncounterTimelineEventState.Finished
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 8)
assert(last().evt.reason == "finished", "finished state reports completion")
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_REMOVED", 8)
assert(last().evt.reason == "finished", "removal after completion still reads as finished")
timelineState[8] = Enum.EncounterTimelineEventState.Canceled
tlFrame.OnEvent(tlFrame, "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 8)
assert(last().evt.reason == "stop", "cancel is never completion")

-- A preferred source that is missing yields no active source at all.
local savedDBM = DBM
DBM = nil
B.SetPreferredSource("dbm")
assert(B.ActiveSource() == nil, "unavailable preference must not fall back silently")
B.SetPreferredSource("auto")
assert(B.ActiveSource() == "bigwigs")
DBM = savedDBM

-- Unsubscribe silences the consumer.
B.Unsubscribe("test")
before = count()
BigWigsLoader.registered.BigWigs_Timer("BigWigs_Timer", {}, 1, 5, nil, "x", 0, 1, false, true)
assert(count() == before)

local sources = B.DescribeSources()
assert(#sources == 3 and sources[1].source == "bigwigs" and sources[1].available == true)

print("OK: reminders_bossmods_test")
