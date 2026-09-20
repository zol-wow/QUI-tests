local file = assert(io.open(arg[1] or "modules/qol/qol.lua", "r"))
local source = file:read("*a")
file:close()
local start = assert(source:find("do\n    local appearanceEffects = {", 1, true))
local chunk = assert(loadstring("local ns, GetSettings = ...\n" .. source:sub(start)))

local selected = {
    "blacksmithing", "jewelcrafting", "tailoring", "engineering", "enchanting",
    "alchemy", "inscription", "leatherworking", "herbalism", "mining", "skinning",
    "cooking", "fishing", "lantern", "hallowed", "noblebunny", "turkey", "aqir",
    "blight", "witch", "spraybots", "pickaxe", "noggenfogger", "prism",
}
local settings = { autoRemoveAppearanceChanges = { enabled = false, atomic = false, atomgoblin = false } }
for _, key in ipairs(selected) do settings.autoRemoveAppearanceChanges[key] = true end
local options = settings.autoRemoveAppearanceChanges
local frames, timers, removed, auras = {}, {}, {}, {}
local combat, affectingCombat, restricted, channel = false, false, false, nil
local scans = 0
local secret = {}
local registry, login
local ns = {
    Registry = { Register = function(_, name, definition)
        assert(name == "appearanceChanges")
        registry = definition
    end },
    WhenLoggedIn = function(callback) login = callback end,
}
local env = setmetatable({
    wipe = function(values) for key in pairs(values) do values[key] = nil end end,
    Enum = { AddOnRestrictionState = { Inactive = 0, Active = 1 } },
    CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:RegisterUnitEvent(event, unit)
            assert(unit == "player", "Appearance events must target the player")
            self.events[event] = unit
        end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:UnregisterAllEvents() self.events = {} end
        function frame:SetScript(script, handler) self[script] = handler end
        frames[#frames + 1] = frame
        return frame
    end,
    C_Timer = { After = function(delay, callback)
        assert(delay == 0, "Aura events should coalesce on the next frame")
        timers[#timers + 1] = callback
    end },
    InCombatLockdown = function() return combat end,
    UnitAffectingCombat = function(unit) assert(unit == "player"); return affectingCombat end,
    UnitChannelInfo = function(unit)
        assert(unit == "player")
        return channel and "Fishing", nil, nil, nil, nil, nil, nil, channel
    end,
    C_Secrets = { ShouldAurasBeSecret = function() return restricted end },
    issecretvalue = function(value) return value == secret end,
    C_UnitAuras = {
        GetUnitAuras = function(unit, filter)
            assert(unit == "player" and filter == "HELPFUL|CANCELABLE")
            assert(not combat and not affectingCombat, "Do not scan during combat")
            assert(not restricted, "Do not scan restricted auras")
            scans = scans + 1
            local snapshot = {}
            for i, aura in ipairs(auras) do snapshot[i] = aura end
            return snapshot
        end,
        CancelAuraByInstanceID = function(unit, id)
            assert(unit == "player" and type(id) == "number")
            assert(not combat and not affectingCombat and not restricted)
            removed[#removed + 1] = id
            for i = #auras, 1, -1 do
                if auras[i].auraInstanceID == id then table.remove(auras, i) end
            end
        end,
    },
}, { __index = _G })
setfenv(chunk, env)
chunk(ns, function() return settings end)
assert(type(login) == "function", "Initialize appearance removal after login")
assert(registry and registry.refresh == ns.RefreshAppearanceChanges,
    "Profile refresh must apply current appearance selections")
assert(registry.group == "qol" and registry.importCategories[1] == "qol")

local function flush()
    local queued = timers
    timers = {}
    for _, callback in ipairs(queued) do callback() end
end
local function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.OnEvent(frame, event, ...) end
    end
end
local function add(spell, id)
    auras[#auras + 1] = { spellId = spell, auraInstanceID = id }
end
local function expectRemoved(expected, reason)
    table.sort(removed)
    table.sort(expected)
    assert(table.concat(removed, ",") == table.concat(expected, ","), reason)
    removed = {}
end
local function expectIdle()
    for _, frame in ipairs(frames) do assert(next(frame.events) == nil, "Disabled removal must unregister all events") end
end

add(388658, 1)
login()
flush()
assert(scans == 0, "Default-disabled feature must not scan existing buffs")
expectIdle()

options.enabled = true
options.blacksmithing = false
ns.RefreshAppearanceChanges()
flush()
expectRemoved({}, "Unchecked individual effects must remain")
options.blacksmithing = true
ns.RefreshAppearanceChanges()
flush()
expectRemoved({ 1 }, "Enabling a selection must remove an already active effect")

for i = 1, 41 do add(900000 + i, 100 + i) end
add(768, 200)
add(16594, 201)
add(16593, 208)
add(1223630, 209)
add(399502, 202)
add(1215363, 203)
add(301892, 204)
add(301893, 205)
add(163267, 206)
add(16595, 207)
local before = scans
fire("UNIT_AURA", "player", secret)
fire("UNIT_AURA", "player", secret)
assert(#timers == 1, "Burst aura events must coalesce into one sweep")
flush()
assert(scans == before + 1)
expectRemoved({ 204, 205, 206, 207 }, "Scan beyond 40 buffs without skipping adjacent matching effects")
assert(#auras == 47, "Ordinary buffs, class forms, slow fall and opt-in toys must remain")
options.atomic = true
ns.RefreshAppearanceChanges()
flush()
expectRemoved({ 202 }, "Recalibrator removal requires its individual opt-in")
options.atomgoblin = true
ns.RefreshAppearanceChanges()
flush()
expectRemoved({ 203 }, "Regoblinator removal requires its individual opt-in")

auras = {}
add(394003, 300)
combat = true
fire("UNIT_AURA", "player")
assert(#timers == 0, "Combat aura events must not schedule appearance callbacks")
flush()
expectRemoved({}, "Combat must defer appearance removal")
combat = false
affectingCombat = true
fire("UNIT_AURA", "player")
assert(#timers == 0, "Unit combat state must prevent appearance callback scheduling")
flush()
expectRemoved({}, "Unit combat state also defers removal")
affectingCombat = false
fire("PLAYER_REGEN_ENABLED")
flush()
expectRemoved({ 300 }, "Combat exit must retry deferred effects")

for key in pairs(options) do options[key] = key == "enabled" or key == "fishing" end
ns.RefreshAppearanceChanges()
flush()
channel = 131476
add(394009, 400)
fire("UNIT_AURA", "player")
flush()
expectRemoved({}, "Fishing appearance must remain during the fishing channel")
channel = nil
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 131476)
flush()
expectRemoved({ 400 }, "Fishing appearance must clear after the channel stops")
add(394009, 401)
combat = true
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 131476)
flush()
expectRemoved({}, "Fishing channel stop during combat must defer removal")
combat = false
fire("PLAYER_REGEN_ENABLED")
flush()
expectRemoved({ 401 }, "Combat recovery must work when only Fishing is selected")

options.prism = true
ns.RefreshAppearanceChanges()
flush()
restricted = true
add(163267, 500)
fire("UNIT_AURA", "player", secret)
assert(#timers == 0, "Restricted aura events must not schedule appearance callbacks")
flush()
expectRemoved({}, "Restricted aura access must defer removal")
restricted = false
fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
flush()
expectRemoved({ 500 }, "Restriction recovery must retry appearance removal")
add(163267, 503)
fire("UNIT_AURA", "player")
combat = true
flush()
expectRemoved({}, "Combat starting after scheduling must still defer removal")
combat = false
fire("PLAYER_REGEN_ENABLED")
flush()
expectRemoved({ 503 }, "Combat exit must recover a previously queued sweep")
add(163267, 504)
fire("UNIT_AURA", "player")
restricted = true
flush()
expectRemoved({}, "Restrictions starting after scheduling must still defer removal")
restricted = false
fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
flush()
expectRemoved({ 504 }, "Restriction recovery must recover a previously queued sweep")
add(secret, 501)
add(163267, secret)
add(163267, 502)
fire("UNIT_AURA", "player", secret)
flush()
expectRemoved({ 502 }, "Secret spell and instance IDs must be skipped individually")

auras = {}
add(163267, 600)
fire("UNIT_AURA", "player")
options.enabled = false
registry.refresh()
before = scans
flush()
assert(scans == before, "Disabling must invalidate a queued sweep")
expectRemoved({}, "A queued sweep must respect the disabled master toggle")
expectIdle()
options.enabled = true
registry.refresh()
flush()
expectRemoved({ 600 }, "Profile refresh must restore active appearance removal")
add(163267, 602)
add(394003, 603)
fire("UNIT_AURA", "player")
settings = { autoRemoveAppearanceChanges = { enabled = true, prism = false, alchemy = true } }
before = scans
flush()
assert(scans == before, "Profile replacement must block stale selections before the delayed registry refresh")
expectRemoved({}, "Pending work must preserve buffs when the profile changes before refresh")
registry.refresh()
flush()
expectRemoved({ 603 }, "Delayed refresh must apply the new profile's selected effects")
assert(#auras == 1 and auras[1].auraInstanceID == 602,
    "The new profile's unchecked Prism must remain after refresh")
settings = { autoRemoveAppearanceChanges = options }
registry.refresh()
flush()
expectRemoved({ 602 }, "Restoring the original profile must restore its selections")
add(163267, 601)
fire("UNIT_AURA", "player")
settings = { autoRemoveAppearanceChanges = { enabled = false } }
registry.refresh()
before = scans
flush()
assert(scans == before, "Profile changes must invalidate old scheduled work")
expectRemoved({}, "Queued work must respect the new profile")
expectIdle()

settings.autoRemoveAppearanceChanges = options
for key in pairs(options) do options[key] = key == "enabled" end
registry.refresh()
flush()
expectIdle()
expectRemoved({}, "All unchecked selections must preserve appearance buffs")

print("OK: qol_appearance_changes_test")
