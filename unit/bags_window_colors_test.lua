local env = dofile("tools/_addon_env.lua")
local h = env.LoadHarness(nil, { noSeed = true })
local ns = h.ns
local profile = h.db.profile
profile.general = { visualStyle = "Legacy", skinBorderColorSource = "custom", skinBorderColor = { 0.1, 0.2, 0.3, 0.8 } }
profile.bags = { enabled = false, appearance = {} }
h.QUI.GetSkinBgColor = function() return 0.05, 0.06, 0.07, 0.9 end

local function node()
    local f = { text = "", shown = true, scripts = {} }
    function f:SetVertexColor(...) self.color = { ... } end
    function f:SetBackdropBorderColor(...) self.color = { ... } end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text end
    function f:HasFocus() return false end
    function f:SetShown(shown) self.shown = shown end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:CreateTexture() return node() end
    function f:CreateFontString() return node() end
    return setmetatable(f, { __index = function() return function() end end })
end

_G.CreateFrame = node
_G.UIParent = node()
_G.UISpecialFrames = {}
_G.tContains = function(items, value)
    for _, item in ipairs(items) do if item == value then return true end end
    return false
end
ns.Helpers.ApplyFontWithFallback = function() end
ns.UIKit = {
    DisablePixelSnap = function() end,
    CreateBackdropBorder = node,
    CreateBorderLines = function() end,
    UpdateBorderLines = function() end,
    CreateCloseButton = function() return { text = node() } end,
}
ns.Bags = {}
assert(loadfile("QUI_Bags/bags/views/chassis.lua"))("QUI", ns)
local windows = {
    ns.Bags.Chassis.CreateWindow({ name = "TestBagColors" }),
    ns.Bags.Chassis.CreateWindow({ name = "TestBankColors" }),
}
windows[1]:Show()

local function checkColor(actual, expected, message)
    for i = 1, 4 do assert(actual[i] == expected[i], message .. " component " .. i) end
end
for _, win in ipairs(windows) do
    checkColor(win._bg.color, { 0.05, 0.06, 0.07, 0.9 }, "bags must inherit the global background by default")
    checkColor(win._border.color, { 0.1, 0.2, 0.3, 0.8 }, "bags must inherit the global border by default")
end

ns.WhenLoggedIn = function(fn) fn() end
ns.Storage = { Bus = { Subscribe = function() end } }
_G.SlashCmdList = {}
assert(loadfile("QUI_Bags/bags/bags.lua"))("QUI", ns)
local appearance = profile.bags.appearance
appearance.bgOverride = true
appearance.backgroundColor = { 0.6, 0.4, 0.2, 0.35 }
appearance.borderColorSource = "custom"
appearance.borderColor = { 0.3, 0.5, 0.7, 0.65 }
_G.QUI_RefreshBags()
for _, win in ipairs(windows) do
    checkColor(win._bg.color, appearance.backgroundColor, "editing bag colors must repaint existing shown and hidden windows")
    checkColor(win._border.color, appearance.borderColor, "editing bag borders must repaint existing shown and hidden windows")
end
assert(windows[1].shown and not windows[2].shown, "color refresh must preserve window visibility")

appearance.hideBackground = true
appearance.hideBorder = true
_G.QUI_RefreshBags()
for _, win in ipairs(windows) do
    assert(win._bg.color[4] == 0 and win._border.color[4] == 0, "bag background and border hide controls must clear their fills")
end

profile.bags.appearance = { bgOverride = true, backgroundColor = { 0.2, 0.1, 0.3, 0 } }
_G.QUI_RefreshBags()
for _, win in ipairs(windows) do
    checkColor(win._bg.color, profile.bags.appearance.backgroundColor, "profile replacement must use the new appearance and preserve zero opacity")
end
profile.bags.appearance.bgOverride = false
_G.QUI_RefreshBags()
for _, win in ipairs(windows) do
    checkColor(win._bg.color, { 0.05, 0.06, 0.07, 0.9 }, "disabling override must restore the global background")
end

print("OK: bags_window_colors_test")
