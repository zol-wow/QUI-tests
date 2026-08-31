-- tests/unit/damage_meter_secret_spellid_test.lua
-- Run: lua tests/unit/damage_meter_secret_spellid_test.lua

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return (data:gsub("\r\n", "\n"))
end

local source = readAll("QUI_DamageMeter/damage_meter/damage_meter.lua")
local secretSpellID = setmetatable({}, {
    __tostring = function() error("secret spellID stringified", 2) end,
    __concat = function() error("secret spellID concatenated", 2) end,
    __eq = function() error("secret spellID compared", 2) end,
})

local normalizeStart = assert(source:find("local _spellInfoCache", 1, true))
local normalizeEnd = assert(source:find("Data._NormalizeSpells", normalizeStart, true))
local normalizeChunk = source:sub(normalizeStart, normalizeEnd - 1)
local normalizeEnv = {
    ipairs = ipairs,
    IsSecretValue = function(value) return rawequal(value, secretSpellID) end,
    C_Spell = {
        GetSpellInfo = function(spellID)
            assert(not rawequal(spellID, secretSpellID), "secret spellID must not reach C_Spell.GetSpellInfo")
            return { name = "Spell " .. tostring(spellID), iconID = spellID + 1000 }
        end,
    },
    Helpers = {
        IsSecretValue = function(value) return rawequal(value, secretSpellID) end,
    },
}
local normalizeLoader = assert(loadstring(normalizeChunk .. "\nreturn NormalizeSpells"))
setfenv(normalizeLoader, normalizeEnv)
local NormalizeSpells = normalizeLoader()

local normalized = NormalizeSpells({
    { spellID = secretSpellID, creatureName = "Hidden Spell", totalAmount = 100, amountPerSecond = 10 },
    { spellID = 123, creatureName = "Visible Spell", totalAmount = 50, amountPerSecond = 5 },
})

assert(rawequal(normalized[1].spellID, secretSpellID), "secret spellID should stay on the row by identity")
assert(normalized[1].name == "Hidden Spell", "secret spellID row should use creatureName fallback")
assert(normalized[1].iconID == nil, "secret spellID row should defer icon resolution to the texture sink path")
assert(normalized[2].name == "Spell 123", "non-secret spellID should still resolve spell info")
assert(normalized[2].iconID == 1123, "non-secret spellID should still resolve icon")

local SecretSentinel = dofile("tests/helpers/secret_sentinel.lua")
local Instrument = dofile("tests/helpers/secret_instrument.lua")
local restoreSecretStub = SecretSentinel.InstallSecretStub()
local secretTexture = SecretSentinel.MakeSecretSentinel()
local renderStart = assert(source:find("function Breakdown:_SetSpellRow", 1, true))
local renderEnd = assert(source:find("\nfunction Breakdown:_SetDeathRow", renderStart))
local renderChunk = source:sub(renderStart, renderEnd - 1)
local renderedTexture
local renderEnv = setmetatable({
    type = type,
    string = string,
    Breakdown = {},
    ApplyRowBackgroundVisibility = function() end,
    IsSecretValue = function(value) return rawequal(value, secretSpellID) end,
    C_Spell = {
        GetSpellTexture = function(spellID)
            assert(rawequal(spellID, secretSpellID), "texture lookup must receive the secret spellID unchanged")
            return secretTexture, 5252, 6262
        end,
    },
    Helpers = {
        IsSecretValue = function(value) return rawequal(value, secretSpellID) end,
    },
    ResolveAppearance = function(_, key)
        if key == "numberFormat" then return "compact" end
        if key == "barFillAlpha" then return 1 end
        if key == "barColorAccent" then return true end
    end,
    FormatNumber = function(value) return tostring(value) end,
    ComputeBarFill = function() return 0, 100, 100 end,
    GetAccentColor = function() return 1, 1, 1, 1 end,
}, { __index = _G })
local renderLoader = assert(Instrument.loadString(renderChunk .. "\nreturn Breakdown._SetSpellRow",
    "damage_meter_secret_spell_texture"))
setfenv(renderLoader, renderEnv)
local SetSpellRow = renderLoader()
local row = {
    Icon = {
        SetTexture = function(_, texture, ...)
            assert(select("#", ...) == 0, "texture sink must receive only GetSpellTexture's first return")
            renderedTexture = texture
        end,
        SetTexCoord = function() end,
    },
    Name = { SetFormattedText = function() end, SetText = function() end },
    Value = { SetText = function() end },
    Bar = {
        SetMinMaxValues = function() end,
        SetValue = function() end,
        SetStatusBarColor = function() end,
    },
}
SetSpellRow({ parentWindowID = 1 }, row, normalized[1], 100, 100)
assert(rawequal(renderedTexture, secretTexture),
    "secret spell texture must pass directly from C_Spell.GetSpellTexture to Texture:SetTexture")
SecretSentinel.RestoreSecretStub(restoreSecretStub)

local utilityStart = assert(source:find("local function SortByDescSafe", 1, true))
local utilityEnd = assert(source:find("local Data = {}", utilityStart, true))
local spellHelperStart = assert(source:find("local _spellInfoCache", 1, true))
local spellHelperEnd = assert(source:find("Data._NormalizeSpells", spellHelperStart, true))
local combinedStart = assert(source:find("function Data:GetCombinedHealingBreakdown", 1, true))
local combinedEnd = assert(source:find("local function IsHealingType(meterType)", combinedStart, true))
local combinedChunk = table.concat({
    source:sub(utilityStart, utilityEnd - 1),
    "local Data = {}",
    source:sub(spellHelperStart, spellHelperEnd - 1),
    source:sub(combinedStart, combinedEnd - 1),
    "return Data",
}, "\n")

local combinedEnv = {
    ipairs = ipairs,
    pairs = pairs,
    table = table,
    math = math,
    type = type,
    rawequal = rawequal,
    IsSecretValue = function(value) return rawequal(value, secretSpellID) end,
    QUI_DamageMeter = {},
    Enum = { DamageMeterType = { HealingDone = 2, Absorbs = 8 } },
    Helpers = {
        IsSecretValue = function(value) return rawequal(value, secretSpellID) end,
    },
}
local combinedLoader = assert(loadstring(combinedChunk))
setfenv(combinedLoader, combinedEnv)
local Data = combinedLoader()
function Data:GetBreakdownView(_, meterType)
    if meterType == combinedEnv.Enum.DamageMeterType.HealingDone then
        return {
            totalAmount = 100,
            spells = {
                { spellID = secretSpellID, name = "Heal", totalAmount = 100 },
            },
        }
    end
    return {
        totalAmount = 50,
        spells = {
            { spellID = secretSpellID, name = "Absorb", totalAmount = 50 },
        },
    }
end

local combined = Data:GetCombinedHealingBreakdown("current", "player", nil, nil)
assert(#combined.spells == 2, "secret spellIDs must not be used as merge keys")
assert(combined.spells[1].name == "Heal", "healing row should remain")
assert(combined.spells[2].name == "Absorb", "absorb row should remain separate")

print("OK: damage_meter_secret_spellid_test")
