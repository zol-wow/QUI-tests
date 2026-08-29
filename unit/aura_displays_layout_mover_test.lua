local function fail(message)
    print("FAIL: aura_displays_layout_mover_test - " .. message)
    os.exit(1)
end

local function newFrame(parent)
    local frame = {
        _alpha = 1,
        _height = 30,
        _mouseOver = false,
        _parent = parent,
        _shown = true,
        _width = 100,
        _x = 960,
        _y = 540,
    }

    function frame:ClearAllPoints() end
    function frame:CreateFontString() return newFrame(self) end
    function frame:CreateTexture() return newFrame(self) end
    function frame:EnableKeyboard() end
    function frame:EnableMouse() end
    function frame:GetAlpha() return self._alpha end
    function frame:GetCenter() return self._x, self._y end
    function frame:GetEffectiveScale() return 1 end
    function frame:GetFont() return nil end
    function frame:GetFrameStrata() return "MEDIUM" end
    function frame:GetHeight() return self._height end
    function frame:GetObjectType() return "Frame" end
    function frame:GetParent() return self._parent end
    function frame:GetScale() return 1 end
    function frame:GetSize() return self._width, self._height end
    function frame:GetWidth() return self._width end
    function frame:Hide() self._shown = false end
    function frame:IsShown() return self._shown end
    function frame:IsMouseOver() return self._mouseOver end
    function frame:RegisterForDrag() end
    function frame:SetAllPoints() end
    function frame:SetAlpha(alpha) self._alpha = alpha end
    function frame:SetClampedToScreen() end
    function frame:SetFrameLevel() end
    function frame:SetFrameStrata() end
    function frame:SetHeight(height) self._height = height end
    function frame:SetMovable() end
    function frame:SetParent(value) self._parent = value end
    function frame:SetPoint(_, relativeTo, _, offsetX, offsetY)
        local x, y = 960, 540
        if type(relativeTo) == "table" and relativeTo.GetCenter then
            x, y = relativeTo:GetCenter()
        end
        self._x = (x or 960) + (offsetX or 0)
        self._y = (y or 540) + (offsetY or 0)
    end
    function frame:SetScript() end
    function frame:SetSize(width, height)
        self._width = width
        self._height = height
    end
    function frame:SetWidth(width) self._width = width end
    function frame:Show() self._shown = true end

    return setmetatable(frame, {
        __index = function()
            return function() end
        end,
    })
end

local profile = {}
local layoutActive = true
local ns = {
    Addon = { AuraSkin = {} },
    AuraElements = {
        ActiveElementsForSpec = function() return {} end,
        EnsureSeeded = function() end,
    },
    AuraGlue = {},
    AuraSurface = { ApplyElementPass = function() end },
    L = setmetatable({}, { __index = function(_, key) return key end }),
    UIKit = { GetPixelSize = function() return 1 end },
}

ns.Helpers = {
    GetCore = function() return { db = { profile = profile } } end,
    GetCurrentSpecID = function() return nil end,
    GetModuleSettings = function(name, defaults)
        if not profile[name] then
            profile[name] = {}
            for key, value in pairs(defaults or {}) do
                profile[name][key] = value
            end
        end
        return profile[name]
    end,
    GetProfile = function() return profile end,
    IsLayoutModeActive = function() return layoutActive end,
}

ns.SafeCall = function(_, callback, ...)
    return pcall(callback, ...)
end
ns.SafeCallMethod = function(_, owner, method, ...)
    return pcall(owner[method], owner, ...)
end

UIParent = newFrame()
UIParent:SetSize(1920, 1080)
CreateFrame = function(_, _, parent) return newFrame(parent or UIParent) end
C_Timer = { After = function() end, NewTicker = function() return newFrame() end }
GetInstanceInfo = function() return nil, "none" end
InCombatLockdown = function() return false end
LibStub = function() return nil end
wipe = function(value) for key in pairs(value) do value[key] = nil end end
local secretMouseOver = {}
issecretvalue = function(value) return value == secretMouseOver end

assert(loadfile("modules/layout/layoutmode.lua"))("QUI", ns)
assert(loadfile("modules/trackers/aura_displays.lua"))("QUI", ns)

local AD = ns.QUI_AuraDisplays
local LM = ns.QUI_LayoutMode
local display = assert(AD.NewDisplay("External"))
display.visibility = "instance"
display.load.roles.HEALER = true
ns.QUI_AuraWizard = { PlayerRole = function() return "TANK" end }

LM.isActive = true
AD.Refresh()

local key = AD.ANCHOR_PREFIX .. display.id
local host = AD.HostFor(display.id)
if not host or host:GetAlpha() ~= 0 then
    fail("setup must produce an alpha-zero Aura Display host")
end
local visibilityFrames = AD.GetVisibilityFrames()
if #visibilityFrames ~= 0 then
    fail("inactive Aura Displays must not enter the visibility frame list")
end
local reusesVisibilityFrames = AD.GetVisibilityFrames() == visibilityFrames

local mover = LM._handles[key]
if not mover then fail("an inactive Aura Display must retain a Layout Mode mover") end
if mover._isChildOverlay ~= false then
    fail("an inactive Aura Display must use a visibility-independent proxy mover")
end
if not mover:IsShown() then fail("the Aura Display proxy mover must remain shown") end

AD.SetVisibilityAlpha(0.35)
if host:GetAlpha() ~= 0 then
    fail("HUD visibility alpha must not reveal an inactive Aura Display")
end

layoutActive = false
LM.isActive = false
ns.QUI_AuraWizard.PlayerRole = function() return "HEALER" end
AD.Refresh()
if host:GetAlpha() ~= 0.35 then
    fail("an active Aura Display must compose its gameplay alpha with HUD visibility")
end
local activeVisibilityFrames = AD.GetVisibilityFrames()
if #activeVisibilityFrames ~= 1 or activeVisibilityFrames[1] ~= host then
    fail("active Aura Displays must enter the visibility frame list")
end
if reusesVisibilityFrames and activeVisibilityFrames ~= visibilityFrames then
    fail("Aura Display visibility must keep reusing its active-host list")
end

host._mouseOver = true
if not AD.IsVisibilityFrameMouseOver() then
    fail("an active hovered Aura Display must satisfy mouseover visibility")
end
host._mouseOver = secretMouseOver
if AD.IsVisibilityFrameMouseOver() then
    fail("secret Aura Display mouseover state must fail closed")
end
host._mouseOver = false

AD.SetVisibilityAlpha(0)
if host:GetAlpha() ~= 0 then
    fail("HUD autohide must fade an active Aura Display to zero")
end

ns.QUI_AuraWizard.PlayerRole = function() return "TANK" end
AD.Refresh()
local inactiveVisibilityFrames = AD.GetVisibilityFrames()
if #inactiveVisibilityFrames ~= 0 then
    fail("Aura Display visibility lists must clear stale hosts")
end
if reusesVisibilityFrames and inactiveVisibilityFrames ~= visibilityFrames then
    fail("Aura Display visibility must keep reusing its cleared host list")
end

print("PASS: aura_displays_layout_mover_test")
