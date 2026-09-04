local loadstring = loadstring or load

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source:gsub("\r\n", "\n")
end

local source = readAll("modules/qol/qol.lua")
local start = assert(source:find("local summonAcceptPending = false", 1, true))
local finish = assert(source:find("\nlocal function OnDuelRequested", start, true))
local block = source:sub(start, finish - 1)
_G.QUI_TEST_SUMMON_SETTINGS = nil
_G.QUI_TEST_SUMMON_ACCEPTED = 0
_G.QUI_TEST_SUMMON_ACTIVE = true
_G.QUI_TEST_SUMMON_COMBAT = false
_G.QUI_TEST_SUMMON_TELEPORTABLE = true
_G.QUI_TEST_SUMMON_TIMERS = {}
_G.PlayerCanTeleport = function() return _G.QUI_TEST_SUMMON_TELEPORTABLE end
local OnConfirmSummon, TryAcceptPendingSummon = assert(loadstring(([=[
local GetSettings = function() return QUI_TEST_SUMMON_SETTINGS end
local C_SummonInfo = {
    ConfirmSummon = function() QUI_TEST_SUMMON_ACCEPTED = QUI_TEST_SUMMON_ACCEPTED + 1 end,
    GetSummonConfirmTimeLeft = function()
        return QUI_TEST_SUMMON_ACTIVE and 30 or 0
    end,
}
local UnitAffectingCombat = function() return QUI_TEST_SUMMON_COMBAT end
local C_Timer = {
    After = function(_, callback)
        QUI_TEST_SUMMON_TIMERS[#QUI_TEST_SUMMON_TIMERS + 1] = callback
    end,
}
%s
return OnConfirmSummon, TryAcceptPendingSummon
]=]):format(block), "qol_auto_accept_summon"))()

OnConfirmSummon()
QUI_TEST_SUMMON_SETTINGS = { autoAcceptSummons = "off" }
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 0, "off summon automation must not accept summons")

QUI_TEST_SUMMON_SETTINGS.autoAcceptSummons = "outOfCombat"
QUI_TEST_SUMMON_COMBAT = true
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 0, "out-of-combat mode must not accept summons during combat")
QUI_TEST_SUMMON_COMBAT = false
TryAcceptPendingSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 0, "out-of-combat mode must not defer combat summons")

OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 1, "out-of-combat mode must accept summons outside combat")

QUI_TEST_SUMMON_SETTINGS.autoAcceptSummons = "always"
QUI_TEST_SUMMON_COMBAT = true
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 1, "always mode must not attempt summon acceptance during combat")
QUI_TEST_SUMMON_COMBAT = false
TryAcceptPendingSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 2, "always mode must accept a pending summon after combat")

QUI_TEST_SUMMON_COMBAT = true
OnConfirmSummon()
QUI_TEST_SUMMON_ACTIVE = false
QUI_TEST_SUMMON_COMBAT = false
TryAcceptPendingSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 2, "expired pending summons must not be accepted")

QUI_TEST_SUMMON_ACTIVE = true
QUI_TEST_SUMMON_TELEPORTABLE = false
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 2 and #_G.QUI_TEST_SUMMON_TIMERS == 1,
    "non-teleportable summons must wait and schedule one retry")
QUI_TEST_SUMMON_TELEPORTABLE = true
table.remove(_G.QUI_TEST_SUMMON_TIMERS, 1)()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 3, "pending summons must accept once teleporting is allowed")

QUI_TEST_SUMMON_SETTINGS.autoAcceptSummons = true
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 4, "legacy enabled values must continue accepting summons")
assert(source:find('qolFrame:RegisterEvent("CONFIRM_SUMMON")', 1, true),
    "summon automation must listen for confirmation requests")
assert(source:find('qolFrame:RegisterEvent("PLAYER_REGEN_ENABLED")', 1, true),
    "pending summon automation must listen for combat exit")
assert(source:find('elseif event == "CONFIRM_SUMMON" then\n        OnConfirmSummon()', 1, true),
    "summon confirmation requests must reach the automation handler")
assert(source:find('elseif event == "PLAYER_REGEN_ENABLED" then\n        TryAcceptPendingSummon()', 1, true),
    "combat exit must retry a pending summon")

_G.QUI_TEST_SUMMON_SETTINGS = nil
_G.QUI_TEST_SUMMON_ACCEPTED = nil
_G.QUI_TEST_SUMMON_ACTIVE = nil
_G.QUI_TEST_SUMMON_COMBAT = nil
_G.QUI_TEST_SUMMON_TELEPORTABLE = nil
_G.QUI_TEST_SUMMON_TIMERS = nil
_G.PlayerCanTeleport = nil

print("qol_auto_accept_summon_test.lua: ok")
