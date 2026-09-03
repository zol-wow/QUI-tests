-- tests/unit/map_teleports_cooldown_secret_safe_test.lua
-- Run: lua tests/unit/map_teleports_cooldown_secret_safe_test.lua
--
-- C_Spell.GetSpellCooldown is SecretWhenCooldownsRestricted
-- (SpellDocumentation.lua:252) and CooldownFrame_Set compares its fields
-- (start > 0, Cooldown.lua:2) — that path throws when the map is refreshed
-- under cooldown restriction. The teleport panel must use the duration-object
-- carrier instead: GetSpellCooldownDuration → SetCooldownFromDurationObject
-- (repo policy: preferredSecretSafeSetter, cdm_blizzard_reference.lua:63).

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local source = readFile("modules/dungeon/map_teleports.lua")

assert(source:find("GetSpellCooldownDuration", 1, true),
    "map teleports must fetch cooldowns as duration objects")
assert(source:find("ApplyCooldownFromStart", 1, true),
    "map teleports must sink duration objects through the guarded cooldown helper")
assert(not source:find("CooldownFrame_Set(", 1, true),
    "CooldownFrame_Set compares secret-capable fields and must not be used here")
assert(not source:find("C_Spell.GetSpellCooldown(", 1, true),
    "raw GetSpellCooldown fields must not be read here")

local function widget()
    local value = { shown = true, events = {}, scripts = {}, hooks = {} }
    local methods = {
        RegisterEvent = function(self, event) self.events[event] = true end,
        SetScript = function(self, script, fn) self.scripts[script] = fn end,
        HookScript = function(self, script, fn) self.hooks[script] = fn end,
        IsShown = function(self) return self.shown end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, shown) self.shown = shown end,
        CreateTexture = function() return widget() end,
        CreateFontString = function() return widget() end,
    }
    return setmetatable(value, {
        __index = function(_, key)
            return methods[key] or function() end
        end,
    })
end

local worldMap = widget()
_G.WorldMapFrame = worldMap
local eventFrame
function CreateFrame(_, _, parent)
    local value = widget()
    if not parent and not eventFrame then eventFrame = value end
    return value
end
function InCombatLockdown() return false end
function IsSpellKnown() return true end
GameTooltip = widget()
C_ChallengeMode = {
    GetMapTable = function() return { 1 } end,
    GetMapUIInfo = function() return "Test", nil, nil, 1 end,
}
C_Spell = { GetSpellCooldownDuration = function() return {} end }

local canMutate = true
local applyCalls = 0
local ns = {
    Helpers = {
        CreateDBGetter = function()
            return function() return { worldMapTeleports = true } end
        end,
        ApplyCooldownFromStart = function()
            applyCalls = applyCalls + 1
            return canMutate
        end,
        ClearCooldown = function() return canMutate end,
    },
    DungeonData = {
        GetTeleportSpellID = function() return 123 end,
        GetShortName = function() return "TEST" end,
    },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    WhenLoggedIn = function(fn) fn() end,
}

assert(loadfile("modules/dungeon/map_teleports.lua"))("QUI", ns)
assert(eventFrame.events.SPELL_UPDATE_COOLDOWN and eventFrame.events.PLAYER_REGEN_ENABLED,
    "map teleports must listen for cooldown changes and combat exit")
assert(worldMap.hooks.OnShow, "map teleports must hook the world map")
worldMap.hooks.OnShow()
assert(applyCalls == 2, "opening the map must paint teleport cooldowns")

canMutate = false
eventFrame.scripts.OnEvent(eventFrame, "SPELL_UPDATE_COOLDOWN")
assert(applyCalls == 3, "combat cooldown updates must be attempted once")
canMutate = true
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(applyCalls == 4, "combat exit must repaint a deferred teleport cooldown")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(applyCalls == 4, "combat exit must not repaint without deferred work")

print("PASS map_teleports_cooldown_secret_safe_test")
