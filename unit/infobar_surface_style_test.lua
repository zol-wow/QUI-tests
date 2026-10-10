local function noop() end
local function region()
    local r = {}
    function r:SetColorTexture(...) self.color = { ... } end
    function r:CreateTexture() return region() end
    return setmetatable(r, { __index = function() return noop end })
end
local bar, refreshSurface
CreateFrame = function(_, name)
    local f = region()
    if name == "QUI_InfoBar" then bar = f end
    return f
end
InCombatLockdown = function() return false end
UnregisterStateDriver = noop
wipe = function(t) for k in pairs(t) do t[k] = nil end; return t end
C_Timer = { After = noop }
UIParent = region()
local satin = true
local settings = { enabled = false, bgOpacity = 37, zonesSeeded = true }
local ns = {
    Addon = { db = { profile = { infobar = settings } } },
    Helpers = {
        IsSatinStyle = function() return satin end,
        GetWindowColors = function() return 0.2, 0.25, 0.3, 0.8, 0.07, 0.10, 0.12, 0.9 end,
    },
    UIKit = { RegisterScaleRefresh = function(_, _, fn) refreshSurface = fn end },
}
assert(loadfile("modules/infobar/infobar.lua"))("QUI", ns)
ns.Addon.InfoBar:ApplyAll()
refreshSurface()
assert(bar.bg.color[1] == 0.07 and bar.bg.color[3] == 0.12, "Satin infobar uses shared window background")
assert(bar.bg.color[4] == 0.37, "Satin infobar preserves saved background opacity")
satin = false
refreshSurface()
assert(bar.bg.color[1] == 0 and bar.bg.color[2] == 0 and bar.bg.color[3] == 0, "Legacy infobar restores its original black background")
assert(bar.bg.color[4] == 0.37, "Legacy infobar preserves saved background opacity")
print("OK: infobar_surface_style_test")
