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
    Helpers = { ApplyFontWithFallback = noop },
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
assert(refreshes == 0 and statusRefreshes == 0 and #timers == 0,
    "building options must not refresh unrelated gameplay skins, synchronously or later")
local r, g, b = gui:ResolveThemePreset("Horde")
assert(gui.Colors.accent[1] == r and gui.Colors.accent[2] == g and gui.Colors.accent[3] == b,
    "building options must retain the saved theme")

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
print("PASS options_constructor_refresh_test")
