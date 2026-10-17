local file = assert(io.open("QUI_ResourceBars/resourcebars/resourcebars.lua", "rb"))
local source = file:read("*a")
file:close()
local function extract(first, last, result)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a, true))
    return assert(loadstring(source:sub(a, b - 1) .. "\nreturn " .. result))()
end
Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4 } }
ns = { Client = { isForever = true } }
local class, primary, current, maximum = "ROGUE", 3, 2, 5
local secret = {}
Helpers = { IsSecretValue = function(value) return value == secret end }
UnitClass = function() return class, class end
UnitPowerType = function() return primary end
GetSpecialization = function() error("Forever must not use Retail specializations") end
UnitPower = function(_, resource) return resource == 0 and 120 or 99 end
UnitPowerMax = function(_, resource) return resource == 0 and 300 or maximum end
GetComboPoints = function(unit, target)
    assert(unit == "player" and target == "target")
    return current
end
local secondary = extract("local function GetSecondaryResource()", "local function GetResourceColor", "GetSecondaryResource")
assert(secondary() == 4, "Forever rogue combo points must be available")
class = "DRUID"
assert(secondary() == 4, "cat energy must select target combo points without a spec ID")
primary = 1
assert(secondary() == 0, "bear rage must retain the druid mana pool")
primary = 0
assert(secondary() == nil, "caster mana must not be duplicated")
for _, name in ipairs({ "HUNTER", "WARLOCK", "PALADIN", "MAGE", "SHAMAN", "PRIEST", "WARRIOR" }) do
    class = name
    assert(secondary() == nil, "Forever must not invent Retail resources for " .. name)
end
local read = extract("local function ReadPlayerPowerPair", "local function GetSpellChargesCompat", "ReadPlayerPowerPair")
local value, max, restricted = read(4)
assert(value == 2 and max == 5 and not restricted, "target combo points must replace generic UnitPower")
current = 0
assert(read(4) == 0, "changing to an empty target must clear combo points")
current = secret
value, max, restricted = read(4)
assert(value == secret and restricted, "secret combo points must stay on the existing secret sink path")
value, max = read(0)
assert(value == 120 and max == 300, "druid mana must use its actual mana pool")
ns.Client.isForever = false
assert(read(4) == 99, "Retail combo points must keep UnitPower")
print("OK: Forever combo points and druid secondary mana")
