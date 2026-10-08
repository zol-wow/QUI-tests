local function noop() end
local methods = {}
for _, key in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetTexture", "SetVertexColor", "EnableMouse",
    "SetOrientation", "SetRotatesTexture", "SetStatusBarTexture", "SetTexCoord", "SetFrameLevel",
    "SetAttribute", "UpdateAction", "Update", "RegisterEvent" }) do methods[key] = noop end
local function widget(parent)
    return setmetatable({ parent = parent, shown = true, alpha = 1, points = {}, scripts = {} }, { __index = methods })
end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:GetAlpha() return self.alpha end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:SetAllPoints() end
function methods:GetParent() return self.parent end
function methods:GetFrameLevel() return 2 end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetNormalTexture() return nil end

local timers, events, data = {}, {}, setmetatable({}, { __mode = "k" })
local state = { vehicle = false, health = false, mana = false, combat = false }
local env = setmetatable({ floor = math.floor }, { __index = _G })
env._G = env
env.CreateFrame = function(_, _, parent)
    local frame = widget(parent)
    events[#events + 1] = frame
    return frame
end
env.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
env.InCombatLockdown = function() return state.combat end
env.UnitVehicleSkin = function() return "vehicle" end
env.UnitFrameHealthBar_Update, env.UnitFrameManaBar_Update = noop, noop
env.GetActionInfo = function() return "spell", 1 end
env.C_ActionBar = {
    HasVehicleActionBar = function() return state.vehicle end,
    ShouldOverrideBarShowHealthBar = function() return state.health end,
    ShouldOverrideBarShowManaBar = function() return state.mana end,
    GetVehicleBarIndex = function() return 12 end,
    GetOverrideBarIndex = function() return 13 end,
    GetOverrideBarSkin = function() return "override" end,
}
env.hooksecurefunc = function(target, method, callback)
    local original = assert(target[method])
    target[method] = function(...) original(...); callback(...) end
end
local function load(path, ns)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk("QUI", ns)
end
load("tests/clients/forever/framexml/Interface/AddOns/Blizzard_OverrideActionBar/OverrideActionBar.lua")
local bar = widget()
for key, value in pairs(env.OverrideActionBarMixin) do bar[key] = value end
bar.SetSkin, bar.UpdateXpBar, bar.UpdateMicroButtons = noop, noop, noop
bar.pitchFrame, bar.leaveFrame = widget(bar), widget(bar)
bar.healthBar, bar.powerBar = widget(bar), widget(bar)
bar.Divider2 = widget(bar)
bar.xpBar = widget(bar)
bar.xpBar.XpMid = widget(bar.xpBar)
function bar.xpBar.XpMid:GetWidth() return 500 end
for index = 1, 19 do bar.xpBar["XpDiv" .. index] = widget(bar.xpBar) end
for index = 1, 6 do bar["SpellButton" .. index] = widget(bar) end
env.OverrideActionBar = bar
env.OverrideActionBarHealthBar, env.OverrideActionBarPowerBar = bar.healthBar, bar.powerBar
local core = { GetPixelSize = function() return 1 end, db = { profile = { general = { skinOverrideActionBar = true } } } }
local ns = {
    Addon = core,
    WhenLoggedIn = function(callback) callback() end,
    Helpers = { ApplyBarStyle = function(bar, path) bar:SetStatusBarTexture(path) end, ApplyIconStyle = function() end, SetFrameBackdropColor = noop, SetFrameBackdropBorderColor = noop },
    SkinBase = {
        GetWindowColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end,
        GetSkinColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end,
        GetFrameData = function(frame, key) return data[frame] and data[frame][key] end,
        SetFrameData = function(frame, key, value) data[frame] = data[frame] or {}; data[frame][key] = value end,
        ApplyPixelBackdrop = noop, SetExpandedPixelPoints = noop, MarkStyled = noop, MarkSkinned = noop,
    },
}
local function flush()
    while #timers > 0 do local batch = timers; timers = {}; for _, callback in ipairs(batch) do callback() end end
end
load(arg[1] or "modules/skinning/frames/overrideactionbar.lua", ns)
for _, vehicle in ipairs({ false, true }) do
    state.vehicle = vehicle
    for _, health in ipairs({ false, true }) do
        state.health = health
        for _, mana in ipairs({ false, true }) do
            state.mana = mana
            for _, pitch in ipairs({ false, true }) do
                bar.HasPitch = pitch
                bar:UpdateSkin()
                flush()
                assert(bar.healthBar:IsShown() == (vehicle or health), "skin must preserve native health visibility")
                assert(bar.powerBar:IsShown() == (vehicle or mana), "skin must preserve native power visibility")
                assert(bar.pitchFrame:IsShown() == pitch, "native pitch availability must be preserved")
                assert(bar.pitchFrame:GetAlpha() == 1, "native aiming buttons must remain visible")
                assert(bar.pitchFrame.points[1][2] == bar, "pitch controls must be anchored to the compact bar")
            end
        end
    end
end
state.combat, state.vehicle, state.health, state.mana = true, false, false, false
bar:UpdateSkin()
flush()
assert(not bar.healthBar:IsShown() and not bar.powerBar:IsShown(), "combat updates must preserve native visibility")
state.combat = false
events[1].scripts.OnEvent(events[1], "PLAYER_REGEN_ENABLED")
flush()
assert(not bar.healthBar:IsShown() and not bar.powerBar:IsShown(), "combat recovery must preserve native visibility")
print("OK: overrideactionbar_native_visibility_test")
