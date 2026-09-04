local loadstring = loadstring or load

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source:gsub("\r\n", "\n")
end

local source = readAll("modules/qol/qol.lua")
local start = assert(source:find("local function OnConfirmSummon()", 1, true))
local finish = assert(source:find("\nend", start, true))
local block = source:sub(start, finish + 4)
_G.QUI_TEST_SUMMON_SETTINGS = nil
_G.QUI_TEST_SUMMON_ACCEPTED = 0
local OnConfirmSummon = assert(loadstring(([=[
local GetSettings = function() return QUI_TEST_SUMMON_SETTINGS end
local C_SummonInfo = {
    ConfirmSummon = function() QUI_TEST_SUMMON_ACCEPTED = QUI_TEST_SUMMON_ACCEPTED + 1 end,
}
local UnitAffectingCombat = function() return QUI_TEST_SUMMON_COMBAT end
%s
return OnConfirmSummon
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
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 1, "out-of-combat mode must accept summons outside combat")

QUI_TEST_SUMMON_SETTINGS.autoAcceptSummons = "always"
QUI_TEST_SUMMON_COMBAT = true
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 2, "always mode must attempt to accept summons during combat")

QUI_TEST_SUMMON_SETTINGS.autoAcceptSummons = true
OnConfirmSummon()
assert(_G.QUI_TEST_SUMMON_ACCEPTED == 3, "legacy enabled values must continue accepting summons")
assert(source:find('qolFrame:RegisterEvent("CONFIRM_SUMMON")', 1, true),
    "summon automation must listen for confirmation requests")
assert(source:find('elseif event == "CONFIRM_SUMMON" then\n        OnConfirmSummon()', 1, true),
    "summon confirmation requests must reach the automation handler")

_G.QUI_TEST_SUMMON_SETTINGS = nil
_G.QUI_TEST_SUMMON_ACCEPTED = nil
_G.QUI_TEST_SUMMON_COMBAT = nil

print("qol_auto_accept_summon_test.lua: ok")
