local Secret = dofile("tests/helpers/secret_sentinel.lua")
local Instrument = dofile("tests/helpers/secret_instrument.lua")
local restore = Secret.InstallSecretStub()
local token = Secret.MakeSecretSentinel()
local restricted = {
    r = Secret.MakeSecretSentinel(),
    g = Secret.MakeSecretSentinel(),
    b = Secret.MakeSecretSentinel(),
}
local ordinary = { r = 0.2, g = 0.58, b = 0.5 }
local state
local env = setmetatable({
    type = function(value)
        if rawequal(value, token) then return "string" end
        return type(value)
    end,
    UnitExists = function() return state.exists end,
    UnitIsPlayer = function() return state.player end,
    UnitClass = function() return "Evoker", state.class end,
    UnitReaction = function() return 2 end,
    UnitHealth = function() return 70 end,
    UnitHealthMax = function() return 100 end,
    GetGeneralSettings = function() return state.general end,
    GetUnitSettings = function() return state.settings end,
    QUI_UF = { GetFrameUnit = function(frame) return frame.unitKey end },
    ApplyHealthFillDirection = function() end,
    Helpers = { SafeToNumber = function(value) return value end },
    RAID_CLASS_COLORS = { EVOKER = ordinary },
    C_ClassColor = { GetClassColor = function(class)
        state.lookups = state.lookups + 1
        if rawequal(class, token) then return restricted end
        if class == "EVOKER" then return ordinary end
    end },
}, { __index = _G })

local file = assert(io.open("QUI_UnitFrames/unitframes/unitframes.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local body = assert(source:match("(local function GetHealthBarColor%(.+)\nlocal function ApplyAbsorbVisAlphas"))
local chunk = assert(Instrument.loadString(body .. "\nreturn UpdateHealth", "health class colors"))
setfenv(chunk, env)
local update = chunk()
local painted
local frame = {
    unitKey = "target",
    healthBar = {
        SetMinMaxValues = function() end,
        SetValue = function() end,
        SetStatusBarColor = function(_, r, g, b, a) painted = { r, g, b, a } end,
    },
}

local function reset(class)
    state = {
        class = class, exists = true, player = true, lookups = 0,
        general = { defaultUseClassColor = true },
        settings = { useHostilityColor = true },
    }
end

local function check(expected, label)
    painted = nil
    update(frame)
    assert(painted, label .. ": health bar was not painted")
    for i = 1, 4 do
        assert(rawequal(painted[i], expected[i]), label .. ": incorrect health bar channel " .. i)
    end
end

reset(token)
check({ restricted.r, restricted.g, restricted.b, 1 }, "restricted player must keep class color over hostility")
assert(state.lookups == 1, "restricted token must reach native class lookup")
reset("EVOKER")
check({ ordinary.r, ordinary.g, ordinary.b, 1 }, "ordinary player class color")
reset(token)
state.settings.useClassColor = false
check({ 0.8, 0.2, 0.2, 1 }, "explicit class-color disable overrides global setting")
assert(state.lookups == 0, "disabled class coloring must skip class lookup")
reset(token)
state.general.defaultUseClassColor = false
state.settings.useClassColor = true
check({ restricted.r, restricted.g, restricted.b, 1 }, "explicit class color overrides global disable")
reset("WARRIOR")
state.player = false
check({ 0.8, 0.2, 0.2, 1 }, "NPC must retain hostile color")
assert(state.lookups == 0, "NPC must not use class lookup")
reset(nil)
check({ 0.8, 0.2, 0.2, 1 }, "missing class retains hostility fallback")
assert(state.lookups == 0, "missing class must not reach native lookup")
reset("UNKNOWN")
state.settings = { customHealthColor = { 0.3, 0.4, 0.5, 0.7 } }
check({ 0.3, 0.4, 0.5, 0.7 }, "unresolved class retains custom fallback")
reset(token)
state.general.darkMode = true
state.general.darkModeHealthColor = { 0.1, 0.2, 0.3, 0.4 }
check({ 0.1, 0.2, 0.3, 0.4 }, "dark mode retains priority")
assert(state.lookups == 0, "dark mode must bypass class lookup")

Secret.RestoreSecretStub(restore)
print("OK unitframes_class_color_secret_probe_test")
