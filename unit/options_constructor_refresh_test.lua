local function read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local nodes = {}
local function noop() end
local methods = {}
for name in ([[SetPoint ClearAllPoints SetAllPoints SetFrameStrata SetMovable
    SetClampedToScreen SetToplevel EnableMouse RegisterForDrag SetJustifyH
    SetWordWrap SetFont SetAutoFocus SetMaxLetters SetOrientation SetMinMaxValues
    SetValueStep SetObeyStepOnDrag SetThumbTexture SetTexture]]):gmatch("%S+") do
    methods[name] = noop
end
local function node(_, _, parent)
    local object = setmetatable({ parent = parent, scripts = {}, shown = true }, { __index = methods })
    nodes[#nodes + 1] = object
    return object
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:SetParent(parent) self.parent = parent end
function methods:SetText(text) self.text = text end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(scale) self.scale = scale end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetValue(value) self.value = value end
function methods:SetVertexColor(...) self.color = { ... } end
methods.SetTextColor = methods.SetVertexColor
methods.SetColorTexture = methods.SetVertexColor
function methods:CreateTexture() return node(nil, nil, self) end
methods.CreateFontString = methods.CreateTexture
function methods:GetChildren()
    local children = {}
    for _, child in ipairs(nodes) do
        if child.parent == self then children[#children + 1] = child end
    end
    return unpack(children)
end

local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = { ApplyFontWithFallback = noop, AssetPath = "Interface\\AddOns\\QUI\\assets\\" },
}
local env = setmetatable({ QUI = {}, CreateFrame = node }, { __index = _G })
setfenv(assert(loadfile("core/theme.lua")), env)("QUI", ns)
assert(loadfile("core/registry.lua"))("QUI", ns)
local gui = env.QUI.GUI
local refreshes, statusRefreshes = 0, 0
ns.Registry:Register("testSkin", { group = "skinning", refresh = function() refreshes = refreshes + 1 end })
local timers = {}
env.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
env._G = { QUI_RefreshStatusTrackingBarSkin = function() statusRefreshes = statusRefreshes + 1 end }
env.QUI.QUICore = { db = { profile = { general = { themePreset = "Horde" } } } }
env.GUI, env.C, env.ns = gui, gui.Colors, ns
env.UIKit = { CreateBackground = node, CreateBorderLines = noop, UpdateBorderLines = noop, CreateCloseButton = noop }
ns.UIKit = env.UIKit
local roundedRadii = {}
local scaleRefreshes = 0
env.UIKit.QueueScaleRefresh = function(ticks)
    assert(ticks == 2, "panel scale changes use the existing two-frame scale refresh")
    scaleRefreshes = scaleRefreshes + 1
end
env.UIKit.Pixels = function(value) return value end
env.UIKit.CreateRoundedSurface = function(parent, options)
    roundedRadii[#roundedRadii + 1] = options.radius
    local background = node(nil, nil, parent)
    background:SetVertexColor(unpack(options.bgColor or {0, 0, 0, 1}))
    parent.background = background
    return { background = background }
end
env.UIParent, env.UISpecialFrames = node(), {}
env.C_AddOns = { GetAddOnMetadata = function() return "test" end }
env.SetFont, env.GetFontPath = noop, noop
env.GetLocale = function() return "enUS" end
env.UnitClass = function() return "Mage", "MAGE" end
env.UnitFactionGroup = function() return "Horde" end
env.RAID_CLASS_COLORS = { MAGE = { r = 0, g = 0.5, b = 1 } }
env.tContains = function() return false end
env.tinsert = table.insert
gui.PANEL_WIDTH, gui.SIDEBAR_WIDTH = 1000, 190
gui.PANEL_MIN_WIDTH, gui.PANEL_MIN_HEIGHT = 750, 400
gui.MaxPanelWidth = function() return 1200 end
gui.MaxPanelHeight = function() return 1200 end
gui.ClearSearchContext, gui.RefreshAccentColor = noop, noop
gui.CreateButton = node
local source = read("QUI_Options/framework.lua")
local first = assert(source:find("function GUI:CreateMainFrame()", 1, true))
local last = assert(source:find("\nfunction GUI:Show()", first, true))
setfenv(assert(loadstring(source:sub(first, last - 1))), env)()

local frame = gui:CreateMainFrame()
assert(frame.sidebar and frame.contentArea and frame.resizeHandle, "constructor must finish building the window")
assert(#roundedRadii == 8 and roundedRadii[1] == 12 and roundedRadii[2] == 4 and roundedRadii[3] == 6
    and roundedRadii[4] == 4 and roundedRadii[5] == 6 and roundedRadii[6] == 10 and roundedRadii[7] == 10 and roundedRadii[8] == 10, "window and Theme/Language controls use native rounded surfaces")
assert(refreshes == 0 and statusRefreshes == 0 and #timers == 0,
    "building options must not refresh unrelated gameplay skins, synchronously or later")
local r, g, b = gui:ResolveThemePreset("Horde")
assert(gui.Colors.accent[1] == r and gui.Colors.accent[2] == g and gui.Colors.accent[3] == b,
    "building options must retain the saved theme")
for _, object in ipairs(nodes) do
    if object.scripts.OnValueChanged then
        object.scripts.OnValueChanged(object, 1.2)
        assert(frame.scale == 1.2 and scaleRefreshes == 1,
            "the actual panel scale control refreshes scale-sensitive preview geometry")
        break
    end
end
assert(scaleRefreshes == 1, "constructor must expose its real panel scale callback")

local function clickLabel(text)
    for _, object in ipairs(nodes) do
        if object.text == text and object.parent and object.parent.scripts.OnClick then
            object.parent.scripts.OnClick(object.parent)
            return
        end
    end
    error("missing clickable theme label: " .. text)
end
clickLabel("Horde")
clickLabel("Sky Blue")
assert(env.QUI.QUICore.db.profile.general.themePreset == "Sky Blue", "explicit theme selection must still save")
for _, callback in ipairs(timers) do callback() end
assert(refreshes == 1 and statusRefreshes == 1, "explicit theme selection must still refresh gameplay skins once")
local fontFirst = assert(source:find("function GUI:OnFontChanged()", 1, true))
local fontLast = assert(source:find("\nend", fontFirst, true))
setfenv(assert(loadstring(source:sub(fontFirst, fontLast + 3))), env)()
local rebuilds = 0
gui.RefreshAccentColor = function() rebuilds = rebuilds + 1 end
gui:OnFontChanged()
assert(rebuilds == 0 and refreshes == 1, "hidden options must not rebuild during font changes")
frame:Show()
gui:OnFontChanged()
assert(rebuilds == 1 and refreshes == 2 and statusRefreshes == 2,
    "font edits with options open must still update gameplay skins and their private font objects")
local function assertPanelOpacity(panel, expected)
    local base = panel._bg.color[4]
    assert(base == expected, "panel creation must restore saved background opacity")
    local layers = {
        {panel.sidebar.background},
        {panel.contentArea.background, panel.contentArea._accentGlow},
    }
    for _, object in ipairs(nodes) do
        if object.parent == panel.subTabBar and object.color and not object.width and not object.height then
            layers[#layers + 1] = {object}
        end
    end
    assert(#layers == 3, "opacity regression must include the subtab background")
    for _, overlays in ipairs(layers) do
        local opacity = base
        for _, overlay in ipairs(overlays) do
            opacity = 1 - (1 - opacity) * (1 - overlay.color[4])
        end
        assert(math.abs(opacity - expected) < 1e-12,
            "overlapping panel backgrounds must not increase the configured opacity")
    end
    assert(panel.alpha == nil, "background opacity must not fade text and controls")
end
assertPanelOpacity(frame, 0.97)
for _, saved in ipairs({0.3, 0.65, 0.97, 1}) do
    gui.MainFrame = nil
    env.QUI.QUICore.db.profile.configPanelAlpha = saved
    local reloaded = gui:CreateMainFrame()
    assertPanelOpacity(reloaded, saved)
    for _, live in ipairs({0.3, 0.65, 0.97, 1}) do
        reloaded._bg:SetVertexColor(unpack({gui.Colors.optionsWindow[1], gui.Colors.optionsWindow[2], gui.Colors.optionsWindow[3], live}))
        assertPanelOpacity(reloaded, live)
    end
end
print("PASS options_constructor_refresh_test")
