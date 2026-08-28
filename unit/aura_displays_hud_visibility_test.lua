local function fail(message)
    print("FAIL: aura_displays_hud_visibility_test - " .. message)
    os.exit(1)
end

local frames = {}
local function NewFrame()
    local frame = { alpha = 1, mouseOver = false, scripts = {}, shown = true }
    function frame:EnableMouse() end
    function frame:GetAlpha() return self.alpha end
    function frame:Hide() self.shown = false end
    function frame:IsMouseOver() return self.mouseOver end
    function frame:IsShown() return self.shown end
    function frame:RegisterEvent() end
    function frame:RegisterUnitEvent() end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:Show() self.shown = true end
    function frame:UnregisterEvent() end
    frames[#frames + 1] = frame
    return frame
end

local now = 0
local inCombat = false
local mounted = false
local auraAlpha = 1
local auraFramesActive = false
local auraHost = NewFrame()
auraHost.alpha = 0

UIParent = NewFrame()
CreateFrame = function() return NewFrame() end
C_Timer = {
    After = function() end,
    NewTimer = function() return { Cancel = function() end } end,
}
GetInstanceInfo = function() return nil, "none" end
GetTime = function() return now end
InCombatLockdown = function() return false end
IsInGroup = function() return false end
IsInRaid = function() return false end
NUM_CHAT_WINDOWS = 0
UnitAffectingCombat = function() return inCombat end
UnitExists = function() return false end
wipe = function(value) for key in pairs(value) do value[key] = nil end end

local profile = {
    auraDisplays = {
        hudVisibility = {
            showAlways = false,
            showInCombat = true,
            showOnMouseover = false,
            fadeDuration = 0.1,
            fadeOutAlpha = 0,
        },
    },
}

local registryRefresh
local ns = {
    Addon = { db = { profile = profile } },
    Helpers = {
        CreateStateTable = function() return {} end,
        GetCore = function() return nil end,
        IsEditModeActive = function() return false end,
        IsLayoutModeActive = function() return false end,
        IsPlayerFlying = function() return false end,
        IsPlayerInDungeonOrRaid = function() return false end,
        IsPlayerInVehicle = function() return false end,
        IsPlayerMounted = function() return mounted end,
        IsPlayerSkyriding = function() return false end,
    },
    QUI_AuraDisplays = {
        GetVisibilityAlpha = function() return auraAlpha end,
        GetVisibilityFrames = function() return auraFramesActive and { auraHost } or {} end,
        IsVisibilityFrameMouseOver = function() return auraHost.mouseOver end,
        SetVisibilityAlpha = function(alpha)
            auraAlpha = alpha
            auraHost:SetAlpha(alpha)
        end,
    },
    Registry = {
        Register = function(_, _, entry)
            registryRefresh = entry.refresh
        end,
    },
    SafeCall = function(_, callback, ...) return pcall(callback, ...) end,
    SafeCallMethodIfPresent = function(_, owner, method, ...)
        if type(owner[method]) ~= "function" then return false end
        owner[method](owner, ...)
        return true
    end,
}

assert(loadfile("QUI_CDM/cdm/hud_visibility.lua"))("QUI_CDM", ns)

local fadeFrame
local function TickFade(targetTime)
    fadeFrame = fadeFrame or frames[#frames]
    now = targetTime
    local callback = fadeFrame and fadeFrame.scripts.OnUpdate
    if not callback then fail("visibility change must schedule a fade") end
    callback(fadeFrame, 0.1)
end

ns.RefreshAuraDisplaysVisibility()
if auraAlpha ~= 0 then fail("autohide alpha must stay current without active Aura Displays") end

auraFramesActive = true
inCombat = true
ns.RefreshAuraDisplaysVisibility()
local interruptedFadeFrame = frames[#frames]
auraFramesActive = false
inCombat = false
ns.RefreshAuraDisplaysVisibility()
if interruptedFadeFrame.scripts.OnUpdate ~= nil then
    fail("empty Aura Displays must cancel an in-progress fade")
end
if auraAlpha ~= 0 then fail("cancelled visibility fades must preserve the empty-state target") end

auraFramesActive = true
inCombat = true
ns.RefreshAuraDisplaysVisibility()
TickFade(0.2)
if auraAlpha ~= 1 then fail("combat visibility must reveal Aura Displays") end

mounted = true
profile.auraDisplays.hudVisibility.showWhenMounted = true
profile.auraDisplays.hudVisibility.hideWhenMounted = true
ns.RefreshAuraDisplaysVisibility()
TickFade(0.4)
if auraAlpha ~= 0 then fail("location hide rules must override conditional show rules") end

mounted = false
profile.auraDisplays.hudVisibility.showWhenMounted = false
profile.auraDisplays.hudVisibility.hideWhenMounted = false
ns.RefreshAuraDisplaysVisibility()
TickFade(0.6)
if auraAlpha ~= 1 then fail("clearing a location hide rule must restore the active show rule") end

inCombat = false
ns.RefreshAuraDisplaysVisibility()
TickFade(0.8)
if auraAlpha ~= 0 then fail("leaving combat must autohide Aura Displays") end

profile.auraDisplays.hudVisibility.showInCombat = false
profile.auraDisplays.hudVisibility.showOnMouseover = true
local detectorStart = #frames
registryRefresh()
local detector = frames[detectorStart + 1]
if not detector or type(detector.scripts.OnUpdate) ~= "function" then
    fail("profile refresh must install a mouseover detector")
end

auraHost.mouseOver = true
detector.scripts.OnUpdate(detector, 0.1)
TickFade(1.0)
if auraAlpha ~= 1 then fail("mouseover must reveal Aura Displays") end

auraHost.mouseOver = false
detector.scripts.OnUpdate(detector, 0.1)
TickFade(1.2)
if auraAlpha ~= 0 then fail("leaving the Aura Display must restore autohide") end

print("PASS: aura_displays_hud_visibility_test")
