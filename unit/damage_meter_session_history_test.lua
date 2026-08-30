-- tests/unit/damage_meter_session_history_test.lua
-- Run: lua tests/unit/damage_meter_session_history_test.lua
-- luacheck: globals Helpers

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return data:gsub("\r\n", "\n")
end

local src = readAll("QUI_DamageMeter/damage_meter/damage_meter.lua")

local start_pos = src:find("local function SessionKey")
assert(start_pos, "could not locate SessionKey helper")
local end_pos = src:find("QUI_DamageMeter%.SessionKey", start_pos)
assert(end_pos, "could not locate QUI_DamageMeter.SessionKey assignment")
local chunk = src:sub(start_pos, end_pos - 1):match("^(.-)\n%s*$")
local SessionKey = assert(loadstring(chunk .. "\nreturn SessionKey"))()

assert(SessionKey(1, nil) == "type:1", "Current selector key must be type-backed")
assert(SessionKey(0, nil) == "type:0", "Overall selector key must be type-backed")
assert(SessionKey(1, 1) == "id:1", "sessionID must take precedence over sessionType")
assert(SessionKey(0, 42) == "id:42", "historical selector key must use the sessionID")
assert(SessionKey(1, 1) ~= SessionKey(1, nil), "id:1 and type:1 must not collide")

assert(src:find("GetCombatSessionFromID", 1, true),
    "main views must support C_DamageMeter.GetCombatSessionFromID")
assert(src:find("GetCombatSessionSourceFromID", 1, true),
    "breakdowns must support C_DamageMeter.GetCombatSessionSourceFromID")
assert(src:find("GetAvailableCombatSessions", 1, true),
    "menu must use C_DamageMeter.GetAvailableCombatSessions")
assert(src:find("TakeTrailingSessions(sessions, 20)", 1, true),
    "Session menu must cap Blizzard history to the trailing 20 sessions")
assert(src:find('root:CreateRadio(ns.L["Current"]', 1, true),
    "Current session row should keep the normal radio selector")
assert(src:find('root:CreateRadio(ns.L["Overall"]', 1, true),
    "Overall session row should keep the normal radio selector")
assert(not src:find("root:CreateRadio(availableSession.name", 1, true),
    "Historical rows must not pass raw session names directly to menu text")
assert(src:find("local sessionLabel = BuildPreviousSessionLabel(availableSession)", 1, true)
    and src:find("root:CreateRadio(sessionLabel", 1, true),
    "Historical rows must use sanitized session labels")
assert(src:find("self:_SelectSession(nil, sessionID, sessionLabel)", 1, true),
    "Historical selection must pass its display label to the window header")
assert(src:find("function() return self.sessionID == sessionID end", 1, true),
    "Historical rows must identify the active selected segment")
assert(src:find("availableSession.name", 1, true),
    "Historical rows must use Blizzard's session name field")
assert(src:find("self.sessionID = nil", 1, true),
    "Window runtime state must initialize sessionID to nil")

-- FormatDuration delegates its m:ss math to ns.Helpers.FormatMMSS (core/utils.lua).
-- Load the real one into a stub Helpers table so the extracted chunk runs as shipped.
local mmssSrc = readAll("core/utils.lua"):match("(function Helpers%.FormatMMSS.-\nend\n)")
assert(mmssSrc, "could not locate Helpers.FormatMMSS in core/utils.lua")
_G.Helpers = { IsSecretValue = function() return false end }
_G.IsSecretValue = Helpers.IsSecretValue
assert(loadstring(mmssSrc))()

local fmtStart = src:find("local function FormatDuration", 1, true)
assert(fmtStart, "could not locate FormatDuration helper")
local labelAssign = src:find("QUI_DamageMeter.BuildPreviousSessionLabel", fmtStart, true)
assert(labelAssign, "could not locate previous-session label helper")
local labelChunk = src:sub(fmtStart, labelAssign - 1):match("^(.-)\n%s*$")
local BuildPreviousSessionLabel = assert(loadstring(labelChunk .. "\nreturn BuildPreviousSessionLabel"))()

assert(BuildPreviousSessionLabel({ sessionID = 7, name = "(!) Ara-Kara", durationSeconds = 125 }) == "Ara-Kara [2:05]",
    "previous-session labels must strip the literal alert prefix and append duration")
assert(BuildPreviousSessionLabel({ sessionID = 3, name = "(!)", durationSeconds = 0 }) == "Combat 3",
    "empty labels after prefix stripping must fall back to Combat <sessionID>")
assert(BuildPreviousSessionLabel({ sessionID = 4, name = "", durationSeconds = 65 }) == "Combat 4 [1:05]",
    "blank labels must fall back to Combat <sessionID> and keep duration")

local defaults = readAll("core/defaults.lua")
local nativeStart = defaults:find("native = {", 1, true)
assert(nativeStart, "could not locate damageMeter.native defaults")
local nativeEnd = defaults:find("\n%s*alerts%s*=", nativeStart) or #defaults
local nativeBlock = defaults:sub(nativeStart, nativeEnd)
assert(not nativeBlock:find("sessionID", 1, true),
    "sessionID must remain runtime-only and absent from damage meter defaults")

print("OK: damage_meter_session_history_test")
