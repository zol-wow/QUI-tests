local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function loadFunction(path, name, env)
    local source = readFile(path)
    local body = assert(source:match("(local function " .. name .. "%b().-\nend)"))
    local chunk = assert(loadstring(body .. "\nreturn " .. name, "@" .. path))
    setfenv(chunk, setmetatable(env, { __index = _G }))
    return chunk()
end

local SecretSentinel = dofile("tests/helpers/secret_sentinel.lua")
local restore = SecretSentinel.InstallSecretStub()
local secret = SecretSentinel.MakeSecretSentinel()
local scale = {}

for _, interface in ipairs({ 16001, 120105 }) do
    for _, case in ipairs({
        { "QUI_UnitFrames/unitframes/unitframes.lua", "GetHealthPct", 3 },
        { "QUI_UnitFrames/unitframes/unitframes.lua", "GetPowerPct", 4 },
        { "QUI_ResourceBars/resourcebars/resourcebars.lua", "GetPowerPct", 4 },
    }) do
        local calls = 0
        local function percent(...)
            calls = calls + 1
            assert(select(case[3], ...) == scale, case[2] .. " must request the display scale on interface " .. interface)
            return secret
        end
        local env = {
            tocVersion = interface,
            HAS_UNIT_POWER_PERCENT = true,
            CurveConstants = { ScaleTo100 = scale },
            UnitHealthPercent = percent,
            UnitPowerPercent = percent,
            UnitPower = function() error("modern percent must not read raw power") end,
            UnitPowerMax = function() error("modern percent must not read raw power maximum") end,
            IsSecretValue = issecretvalue,
            Helpers = { IsSecretValue = issecretvalue },
        }
        local fn = loadFunction(case[1], case[2], env)
        assert(fn("player", 0, false) == secret, case[2] .. " must forward the secret result")
        assert(calls == 1, case[2] .. " must use the modern API exactly once")
    end
end

SecretSentinel.RestoreSecretStub(restore)

local resourcePath = "QUI_ResourceBars/resourcebars/resourcebars.lua"
for _, class in ipairs({ "HUNTER", "PRIEST", "SHAMAN", "WARLOCK", "PALADIN", "DRUID" }) do
    local power = class == "DRUID" and 3 or 0
    local env = {
        ns = { Client = { isForever = true } },
        Enum = { PowerType = { Mana = 0 } },
        UnitPowerType = function(unit) assert(unit == "player"); return power end,
        UnitClass = function() return class, class end,
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return 10000 end,
    }
    local primary = loadFunction(resourcePath, "GetPrimaryResource", env)
    local secondary = loadFunction(resourcePath, "GetSecondaryResource", env)
    assert(primary() == power, class .. " must use its actual Forever primary power")
    assert(secondary() == nil, class .. " must not inherit Retail secondary resources")
    power = 1
    assert(primary() == 1, "primary resource must follow form/power changes")
    power = nil
    assert(primary() == 0, "missing player data must retain the mana fallback")
end

do
    local source = readFile(resourcePath)
    local first = assert(source:find("local primaryResources =", 1, true))
    local last = assert(source:find("local function GetResourceColor", first, true))
    local chunk = assert(loadstring(source:sub(first, last - 1) .. "return GetPrimaryResource, GetSecondaryResource"))
    local class, spec = "HUNTER", 255
    local env = {
        ns = { Client = { isForever = false } },
        Enum = { PowerType = setmetatable({}, { __index = function(_, key) return key end }) },
        QUI_POWER = setmetatable({}, { __index = function(_, key) return key end }),
        UnitClass = function() return class, class end,
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return spec end,
    }
    setfenv(chunk, setmetatable(env, { __index = _G }))
    local primary, secondary = chunk()
    assert(primary() == "Focus" and secondary() == "TipOfTheSpear", "Retail hunter resources must remain unchanged")
    class, spec = "PRIEST", 258
    assert(primary() == "Insanity" and secondary() == "Mana", "Retail shadow priest resources must remain unchanged")
end

do
    local source = readFile("QUI_ActionBars/actionbars/actionbars_helpers.lua")
    local name = assert(source:match("function (PatchLibKeyBoundFor%w+)%(%s*%)"))
    local first = assert(source:find("function " .. name, 1, true))
    local last = assert(source:find("function AddKeybindMethods", first, true))
    local bindings, fallbackCalls, combat = {}, 0, false
    local function fallback() fallbackCalls = fallbackCalls + 1 end
    local library = {
        Binder = { GetBindings = fallback, FreeKey = fallback, OnEnter = fallback },
        Set = fallback,
        L = { BoundKey = "%s: %s", ClearedBindings = "%s", CannotBindInCombat = "combat" },
    }
    local owned = {}
    local env = {
        IS_MIDNIGHT = false,
        frameState = { [owned] = { bindingCommand = "ACTIONBUTTON1" } },
        LibStub = function() return library end,
        InCombatLockdown = function() return combat end,
        SetBinding = function(key, command) bindings[key] = command end,
        GetBindingAction = function(key) return bindings[key] end,
        GetBindingKey = function(command)
            for key, value in pairs(bindings) do if value == command then return key end end
        end,
        GetBindingText = function(key) return key end,
        UIErrorsFrame = { AddMessage = function() end },
        format = string.format,
    }
    local chunk = assert(loadstring(source:sub(first, last - 1) .. "return " .. name))
    setfenv(chunk, setmetatable(env, { __index = _G }))
    chunk()()
    library.Binder:SetKey(owned, "1")
    assert(bindings["1"] == "ACTIONBUTTON1", "Forever owned buttons must bind their action command")
    library.Binder:GetBindings({})
    assert(fallbackCalls == 1, "unowned buttons must retain the library path")
    combat = true
    library.Binder:SetKey(owned, "2")
    library.Binder:ClearBindings(owned)
    assert(bindings["2"] == nil and bindings["1"] == "ACTIONBUTTON1", "combat must block binding changes")
    combat = false
    library.Binder:ClearBindings(owned)
    assert(next(bindings) == nil, "owned bindings must clear outside combat")
end

do
    local source = readFile("QUI_ActionBars/actionbars/actionbars_public.lua")
    local first = assert(source:find("function ActionBarsOwned:Initialize()", 1, true))
    local last = assert(source:find("    ownedEventFrame:Show()", first, true))
    for _, valid in ipairs({ true, false }) do
        local events = {}
        local env = {
            IS_MIDNIGHT = false,
            ActionBarsOwned = {},
            PatchLibKeyBoundForOwnedButtons = function() end,
            PatchLibKeyBoundForMidnight = function() end,
            C_EventUtils = { IsEventValid = function(event)
                assert(event == "LEARNED_SPELL_IN_SKILL_LINE")
                return valid
            end },
            ownedEventFrame = {
                RegisterEvent = function(_, event) events[event] = true end,
                RegisterUnitEvent = function() end,
            },
        }
        local chunk = assert(loadstring(source:sub(first, last - 1) .. "end"))
        setfenv(chunk, setmetatable(env, { __index = _G }))
        chunk()
        env.ActionBarsOwned:Initialize()
        assert((events.LEARNED_SPELL_IN_SKILL_LINE == true) == valid, "spell event registration must follow client capability")
    end
end

assert(loadfile("tests/unit/actionbars_cooldown_secret_batch_test.lua"))("forever")
print("OK: forever_modern_api_routing_test")
