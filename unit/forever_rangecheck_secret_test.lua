local libraryPath = ... or "libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua"
local secret = dofile("tests/helpers/secret_sentinel.lua")
local restore = secret.InstallSecretStub()
local opaque = secret.MakeSecretSentinel()
local function noop() end
local project = {}
for _, path in ipairs({ "ProjectConstants.lua", "Camelot/ProjectConstants.lua" }) do
    local chunk = assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_ProjectConstants/" .. path))
    setfenv(chunk, project)
    chunk()
end

local registered
local seenSpells
_G.GetSpellInfo = function(id) seenSpells[id] = true end
_G.CreateFrame = function()
    return {
        Hide = noop, Show = noop, SetScript = noop, RegisterUnitEvent = noop,
        RegisterEvent = function(_, event) registered[event] = true end,
    }
end
_G.WOW_PROJECT_MAINLINE = project.WOW_PROJECT_MAINLINE
_G.Enum = { SpellBookSpellBank = { Player = 0 } }
_G.C_SpellBook = {}
_G.Item = nil
_G.C_Item = {
    IsItemDataCachedByID = function(item) return item == 1970 or item == 8149 end,
    GetItemInfo = function(item) return "Item " .. item end,
}
_G.C_PaperDollInfo = { GetInventorySlotInfo = function() return 10 end }
_G.C_Timer = { NewTicker = function() return {} end }
local playerClass = "WARRIOR"
_G.UnitClass = function() return playerClass, playerClass end
_G.tinsert, _G.sort = table.insert, table.sort
_G.wipe = function(values)
    for key in pairs(values) do values[key] = nil end
    return values
end
_G.strmatch = string.match
_G.UnitExists = function() return true end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitCanAssist = function() return true end
_G.InCombatLockdown = function() return false end
_G.UnitRace = function() return "Human", "Human" end
_G.GetInventoryItemLink = noop

for _, interface in ipairs({ 16001, 120105 }) do
    _G.WOW_PROJECT_ID = interface == 16001 and project.WOW_PROJECT_CAMELOT or project.WOW_PROJECT_MAINLINE
    _G.GetBuildInfo = function() return interface == 16001 and "1.60.1" or "12.1.5", interface == 16001 and "70205" or "69893", "", interface end
    registered = {}
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

    assert(registered.CVAR_UPDATE == (interface == 16001 and true or nil), "spell rank event must follow client catalog")
    seenSpells = {}
    for _, class in ipairs({ "PRIEST", "WARLOCK" }) do
        playerClass = class
        range:init(true)
        if class == "PRIEST" then
            assert(seenSpells[18807] == (interface == 16001 and true or nil), "Mind Flay must follow the era catalog")
        else
            for _, id in ipairs({ 132, 403677, 426320 }) do
                assert(seenSpells[id] == (interface == 16001 and true or nil), "Warlock spell " .. id .. " must follow the era catalog")
            end
            assert(seenSpells[20707] == (interface ~= 16001 and true or nil), "Soulstone must use the modern catalog")
        end
        if interface == 16001 then
            local function hasItem(checkers, item)
                for _, checker in ipairs(checkers) do
                    if checker.info == "item:" .. item then return true end
                end
            end
            assert(hasItem(range.friendRC, 1970), "Forever must use Restoring Balm from the era friend catalog")
            assert(hasItem(range.harmRC, 8149), "Forever must use Voodoo Charm from the era harm catalog")
        end
        seenSpells = {}
    end
end

secret.RestoreSecretStub(restore)
print("OK: forever_rangecheck_secret_test")
