local libraryPath = ... or "libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua"
local secret = dofile("tests/helpers/secret_sentinel.lua")
local restore = secret.InstallSecretStub()
local opaque = secret.MakeSecretSentinel()
local function noop() end

_G.CreateFrame = function()
    return { Hide = noop, Show = noop, SetScript = noop, RegisterEvent = noop, RegisterUnitEvent = noop }
end
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
_G.Enum = { SpellBookSpellBank = { Player = 0 } }
_G.C_SpellBook = {}
_G.C_Item = {}
_G.C_PaperDollInfo = { GetInventorySlotInfo = function() return 10 end }
_G.C_Timer = { NewTicker = function() return {} end }
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.tinsert, _G.sort = table.insert, table.sort
_G.strmatch = string.match
_G.UnitExists = function() return true end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitCanAssist = function() return true end
_G.InCombatLockdown = function() return false end

for _, interface in ipairs({ 16001, 120105 }) do
    _G.GetBuildInfo = function() return interface == 16001 and "1.60.1" or "12.1.5", "69893", "", interface end
    local now, hostile, pet, guid = 10, true, false, opaque
    _G.GetTime = function() return now end
    _G.UnitCanAttack = function() return hostile end
    _G.UnitIsUnit = function() return pet end
    _G.UnitGUID = function() return guid end
    _G.LibStub = nil
    dofile("libs/LibStub/LibStub.lua")
    assert(secret.LoadInstrumented(libraryPath))()
    local range = _G.LibStub("LibRangeCheck-3.0")
    local checks = 0
    range.harmRC = { { range = 30, checker = function(unit)
        checks = checks + 1
        return unit == "target"
    end } }
    range.friendRC = { { range = 40, checker = function() return true end } }

    local min, max = range:GetRange("target")
    assert(min == 0 and max == 30, "secret GUID must permit a range result on interface " .. interface)
    min, max = range:GetRange("focus")
    assert(min == 30 and max == nil, "secret GUID cache must distinguish unit tokens")
    range:GetRange("target")
    assert(checks == 2, "repeated unit query must reuse its cache entry")

    now, hostile, pet, guid = now + 1, false, opaque, "Creature-public"
    min, max = range:GetRange("target")
    assert(min == nil and max == nil, "secret pet comparison must stop before selecting a checker")

    now, pet = now + 1, true
    min, max = range:GetRange("target")
    assert(min == 0 and max == 40, "ordinary pet comparison must retain friendly range checks")
    now, pet = now + 1, false
    min, max = range:GetRange("target")
    assert(min == 0 and max == 40, "ordinary friendly unit must retain range checks")
end

secret.RestoreSecretStub(restore)
print("OK: forever_rangecheck_secret_test")
