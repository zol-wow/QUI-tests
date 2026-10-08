local function noop() end
local function region()
    local r = {}
    return setmetatable(r, { __index = function(_, key)
        if key == "GetFrameLevel" then return function() return 2 end end
        if key == "GetWidth" then return function(self) return self.width or 250 end end
        if key == "GetHeight" then return function(self) return self.height or 20 end end
        return noop
    end })
end
CreateFrame = function()
    local f = region()
    function f:CreateTexture() return region() end
    function f:CreateFontString() return region() end
    function f:SetStatusBarTexture(path) self.material = path end
    function f:SetStatusBarColor(...) self.fillColor = { ... } end
    function f:SetSize(w, h) self.width, self.height = w, h end
    return f
end
GetTime = function() return 0 end
InCombatLockdown = function() return false end
C_Timer = { After = noop }
SOUNDKIT = {}
STANDARD_TEXT_FONT = "font"
UIParent = region()
local settings = { enabled = true, barColor = { 0.3, 0.7, 0.2, 0.8 } }
local general = { visualStyle = "Satin" }
local function stateTable()
    local t = {}
    return t, function(key) t[key] = t[key] or {}; return t[key] end
end
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = {
        AssetPath = "Interface\\AddOns\\QUI\\assets\\",
        CreateStateTable = stateTable,
        CreateDBGetter = function() return function() return settings end end,
        GetProfile = function() return { general = general } end,
        GetCore = function() return {} end,
        GetSkinColors = function() return 0.2, 0.8, 0.6, 1, 0.05, 0.05, 0.05, 0.9 end,
        GetSkinBorderColor = function() return 0.2, 0.8, 0.6, 1 end,
    },
    UIKit = { GetPixelSize = function() return 1 end, DisablePixelSnap = noop },
    LSM = { Fetch = function(_, _, name)
        if name == "Custom" then return "Interface\\OtherAddon\\Custom.tga" end
        return "Interface\\AddOns\\QUI\\assets\\Quazii.tga"
    end },
}
assert(loadfile("core/appearance.lua"))("QUI", ns)
assert(loadfile("modules/trackers/preytracker.lua"))("QUI", ns)
ns.QUI_PreyTracker.Refresh()
local bar = ns.QUI_PreyTracker.GetState().frame
assert(bar.material == "Interface\\AddOns\\QUI\\assets\\appearance\\Satin.tga", "Prey creation and refresh use Satin material")
assert(bar.fillColor[1] == 0.3 and bar.fillColor[4] == 0.8, "Prey semantic fill color and alpha survive")
settings.texture = "Custom"
ns.QUI_PreyTracker.Refresh()
assert(bar.material == "Interface\\OtherAddon\\Custom.tga", "Prey refresh preserves custom media")
settings.texture = nil
general.visualStyle = "Legacy"
ns.QUI_PreyTracker.Refresh()
assert(bar.material == "Interface\\Buttons\\WHITE8x8", "Prey Legacy restores original default material")
print("OK: preytracker_bar_material_test")
