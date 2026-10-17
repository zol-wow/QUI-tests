local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

for _, path in ipairs({
    "modules/dungeon/map_teleports.lua",
    "modules/dungeon/teleport.lua",
    "modules/infobar/travel.lua",
}) do
    local source = readFile(path)
    assert(source:find("GetSpellCooldownDuration", 1, true), path .. " must fetch duration objects")
    assert(source:find("CanMutateCooldown", 1, true), path .. " must guard protected cooldown writes")
    assert(not source:find("C_Spell.GetSpellCooldown(", 1, true), path .. " must not read secret cooldown fields")
    assert(not source:find("CooldownFrame_Set(", 1, true), path .. " must not compare secret cooldown fields")
end

local function widget()
    local value = { shown = false, events = {}, scripts = {}, hooks = {} }
    local methods = {
        RegisterEvent = function(self, event) self.events[event] = true end,
        UnregisterEvent = function(self, event) self.events[event] = nil end,
        UnregisterAllEvents = function(self) self.events = {} end,
        SetScript = function(self, script, fn) self.scripts[script] = fn end,
        HookScript = function(self, script, fn) self.hooks[script] = fn end,
        IsShown = function(self) return self.shown end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, shown) self.shown = shown end,
        SetCooldownFromDurationObject = function(self, duration)
            self.setCount = (rawget(self, "setCount") or 0) + 1
            self.lastDuration = duration
        end,
        Clear = function(self) self.clearCount = (rawget(self, "clearCount") or 0) + 1 end,
        CreateTexture = function() return widget() end,
        CreateFontString = function() return widget() end,
        GetFrameLevel = function() return 1 end,
        GetHeight = function() return 26 end,
        GetStringWidth = function() return 20 end,
        GetNormalTexture = function(self)
            self.normalTexture = rawget(self, "normalTexture") or widget()
            return self.normalTexture
        end,
        IsMouseOver = function() return false end,
    }
    return setmetatable(value, {
        __index = function(_, key)
            return methods[key] or function() end
        end,
    })
end

local worldMap = widget()
worldMap.shown = true
_G.WorldMapFrame = worldMap
local eventFrame
local mapCooldown
function CreateFrame(frameType, _, parent)
    local value = widget()
    if not parent and not eventFrame then eventFrame = value end
    if frameType == "Cooldown" then mapCooldown = value end
    return value
end
function InCombatLockdown() return false end
function IsSpellKnown() return true end
GameTooltip = widget()
C_ChallengeMode = {
    GetMapTable = function() return { 1 } end,
    GetMapUIInfo = function() return "Test", nil, nil, 1 end,
}
local mapFetchCalls = 0
C_Spell = {
    GetSpellCooldownDuration = function()
        mapFetchCalls = mapFetchCalls + 1
        return {}
    end,
}

local canMutate = true
local mapNS = {
    Helpers = {
        CreateDBGetter = function()
            return function() return { worldMapTeleports = true } end
        end,
        CanMutateCooldown = function() return canMutate end,
    },
    DungeonData = {
        GetTeleportSpellID = function() return 123 end,
        GetShortName = function() return "TEST" end,
    },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    WhenLoggedIn = function(fn) fn() end,
}

assert(loadfile("modules/dungeon/map_teleports.lua"))("QUI", mapNS)
assert(eventFrame.events.SPELL_UPDATE_COOLDOWN and eventFrame.events.PLAYER_REGEN_ENABLED,
    "map teleports must listen for cooldown changes and combat exit")
assert(worldMap.hooks.OnShow, "map teleports must hook the world map")
worldMap.hooks.OnShow()
assert(mapCooldown.setCount == 1, "opening the map must paint teleport cooldowns")
assert(mapCooldown.shown, "map teleports must show their cooldown widgets")
assert(mapFetchCalls == 1, "opening the map must fetch one teleport cooldown")

canMutate = false
eventFrame.scripts.OnEvent(eventFrame, "SPELL_UPDATE_COOLDOWN")
assert(mapCooldown.setCount == 1, "blocked map cooldown updates must not mutate the widget")
assert(mapFetchCalls == 1, "blocked map cooldown updates must not allocate duration objects")
canMutate = true
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(mapCooldown.setCount == 2, "combat exit must repaint a deferred teleport cooldown")
assert(mapFetchCalls == 2, "combat exit must fetch the deferred map cooldown")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(mapCooldown.setCount == 2, "combat exit must not repaint without deferred work")
assert(mapFetchCalls == 2, "combat exit must not fetch without deferred work")

local dungeonEventFrame
local dungeonHook
local dungeonCooldown
function CreateFrame(frameType, _, parent)
    local value = widget()
    if frameType == "Frame" and not parent then dungeonEventFrame = value end
    if frameType == "Cooldown" then dungeonCooldown = value end
    return value
end
function hooksecurefunc(_, _, fn) dungeonHook = fn end
C_Timer = { After = function(_, fn) fn() end }
C_AddOns = { IsAddOnLoaded = function() return true end }
local dungeonIcon = widget()
dungeonIcon.mapID = 7
ChallengesFrame = { DungeonIcons = { dungeonIcon } }
_G.QUI_DungeonData = { GetTeleportSpellID = function() return 321 end }

local dungeonDuration = {}
local dungeonDurationResult = dungeonDuration
local dungeonSpellID
local dungeonIgnoreGCD
local dungeonFetchCalls = 0
C_Spell = {
    GetSpellCooldownDuration = function(spellID, ignoreGCD)
        dungeonFetchCalls = dungeonFetchCalls + 1
        dungeonSpellID, dungeonIgnoreGCD = spellID, ignoreGCD
        return dungeonDurationResult
    end,
}
local dungeonCanMutate = true
local dungeonNS = {
    Helpers = {
        GetCore = function()
            return { db = { profile = { general = { mplusTeleportEnabled = true } } } }
        end,
        CreateStateTable = function() return {} end,
        CanMutateCooldown = function() return dungeonCanMutate end,
    },
}

assert(loadfile("modules/dungeon/teleport.lua"))("QUI", dungeonNS)
assert(dungeonEventFrame.events.SPELL_UPDATE_COOLDOWN and dungeonEventFrame.events.PLAYER_REGEN_ENABLED,
    "instance teleports must listen for cooldown changes and combat exit")
assert(dungeonHook, "instance teleports must hook challenge-frame updates")
dungeonHook()
assert(dungeonCooldown.setCount == 1 and dungeonCooldown.lastDuration == dungeonDuration,
    "instance teleports must forward the opaque duration object on initial paint")
assert(dungeonSpellID == 321 and dungeonIgnoreGCD == true,
    "instance teleports must query their spell while ignoring the global cooldown")
assert(dungeonCooldown and dungeonCooldown.shown,
    "instance teleports must create and show a cooldown widget")
assert(dungeonFetchCalls == 1, "initial instance paint must fetch one duration object")

dungeonCanMutate = false
dungeonEventFrame.scripts.OnEvent(dungeonEventFrame, "SPELL_UPDATE_COOLDOWN")
assert(dungeonCooldown.setCount == 1, "blocked instance cooldown updates must not mutate the widget")
assert(dungeonFetchCalls == 1, "blocked instance cooldown updates must not allocate duration objects")
dungeonCanMutate = true
dungeonEventFrame.scripts.OnEvent(dungeonEventFrame, "PLAYER_REGEN_ENABLED")
assert(dungeonCooldown.setCount == 2, "instance teleports must repaint after a blocked mutation")
assert(dungeonFetchCalls == 2, "instance combat exit must fetch the deferred cooldown")
dungeonEventFrame.scripts.OnEvent(dungeonEventFrame, "PLAYER_REGEN_ENABLED")
assert(dungeonCooldown.setCount == 2, "instance teleports must not repaint without deferred work")
assert(dungeonFetchCalls == 2, "instance combat exit must not fetch without deferred work")
dungeonDurationResult = nil
dungeonEventFrame.scripts.OnEvent(dungeonEventFrame, "SPELL_UPDATE_COOLDOWN")
assert(dungeonCooldown.clearCount == 1, "instance teleports must clear missing cooldowns through the guard")

local travelDefinition
local travelCombat = false
local travelCooldown
function InCombatLockdown() return travelCombat end
function CreateFrame(frameType)
    local value = widget()
    if frameType == "Cooldown" then travelCooldown = value end
    return value
end
function RegisterStateDriver() end
function UnregisterStateDriver() end
PlayerHasToy = function() return false end
C_Item = {
    GetItemIconByID = function() return 1 end,
    GetItemNameByID = function() return "Hearthstone" end,
}
C_ToyBox = { GetToyInfo = function() end }
C_ChallengeMode = {
    GetMapTable = function() return { 2 } end,
    GetMapUIInfo = function() return "Travel Test" end,
}

local travelDuration = {}
local travelDurationResult = travelDuration
local travelSpellID
local travelIgnoreGCD
local travelFetchCalls = 0
C_Spell = {
    GetSpellName = function() return "Travel Spell" end,
    GetSpellCooldownDuration = function(spellID, ignoreGCD)
        travelFetchCalls = travelFetchCalls + 1
        travelSpellID, travelIgnoreGCD = spellID, ignoreGCD
        return travelDurationResult
    end,
}
local travelNS = {
    Addon = {
        db = { profile = { infobar = { travel = { useRandomHearth = false } } } },
        Datatexts = {
            Register = function(_, name, definition)
                assert(name == "travel")
                travelDefinition = definition
            end,
        },
    },
    Helpers = {
        CanMutateCooldown = function() return not travelCombat end,
    },
    DungeonData = {
        GetTeleportSpellID = function() return 654 end,
    },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}

assert(loadfile("modules/infobar/travel.lua"))("QUI", travelNS)
assert(travelDefinition, "travel datatext must register")
local travelSlot = widget()
travelSlot.text = false
travelSlot.noLabel = false
travelSlot.hideText = false
travelSlot._quiFixedWidth = false
travelSlot._quiOnWidthDirty = false
local travelFrame = travelDefinition.OnEnable(travelSlot, {})
assert(travelFrame.events.SPELL_UPDATE_COOLDOWN,
    "travel flyouts must listen for cooldown changes")
travelFrame._hearth.scripts.OnEnter(travelFrame._hearth)
assert(travelCooldown.setCount == 1 and travelCooldown.lastDuration == travelDuration,
    "opening the travel flyout must forward the opaque duration object")
assert(travelSpellID == 654 and travelIgnoreGCD == true,
    "travel flyouts must query their spell while ignoring the global cooldown")
assert(travelCooldown.shown, "travel flyouts must show their cooldown widgets")
assert(travelFetchCalls == 1, "opening the travel flyout must fetch one duration object")

travelFrame.scripts.OnEvent(travelFrame, "SPELL_UPDATE_COOLDOWN")
assert(travelCooldown.setCount == 2, "visible travel flyouts must repaint on cooldown events")
assert(travelFetchCalls == 2, "visible travel flyouts must fetch refreshed cooldowns")
travelCombat = true
travelFrame.scripts.OnEvent(travelFrame, "SPELL_UPDATE_COOLDOWN")
assert(travelCooldown.setCount == 2, "travel flyouts must not mutate cooldowns during combat")
assert(travelFetchCalls == 2, "travel flyouts must not allocate duration objects during combat")
travelCombat = false
travelDurationResult = nil
travelFrame.scripts.OnEvent(travelFrame, "SPELL_UPDATE_COOLDOWN")
assert(travelCooldown.clearCount == 1, "travel flyouts must clear missing cooldowns through the guard")

print("PASS map_teleports_cooldown_secret_safe_test")
