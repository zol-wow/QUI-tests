local env = (dofile("tests/helpers/load_minimap_runtime.lua"))()
local ns = env.ns
local profile = ns.Addon.db.profile
local update = assert(env.findUpvalue(ns.Addon.Minimap.Refresh, "UpdateDatatextPanel"))
local frameMethods = getmetatable(UIParent)
local function noop() end

function frameMethods:GetObjectType() return self.objectType end
function frameMethods:GetScale() return self.scale or 1 end
function frameMethods:GetEffectiveScale() return self:GetScale() end
function frameMethods:GetNumPoints() return self.point and 1 or 0 end
function frameMethods:GetPoint() return unpack(self.point or {}) end
function frameMethods:ClearAllPoints() self.point = nil end
function frameMethods:SetPoint(point, parent, relative, x, y)
    local nextFrame = parent
    local visited = {}
    while nextFrame and not visited[nextFrame] do
        assert(nextFrame ~= self, "Cannot anchor to a region dependent on it: " .. (self.name or "region"))
        visited[nextFrame] = true
        nextFrame = nextFrame.point and nextFrame.point[2]
    end
    self.point = { point, parent, relative, x, y }
end
function frameMethods:CreateTexture() return env.newFrame(nil, "Texture", self) end
function frameMethods:CreateFontString() return env.newFrame(nil, "FontString", self) end
function frameMethods:SetWidth(width) self.width = width end
function frameMethods:SetHeight(height) self.height = height end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:IsShown() return self.shown ~= false end
function frameMethods:SetShown(shown) self.shown = shown end
function frameMethods:GetAlpha() return 1 end
frameMethods.SetFrameLevel = noop
frameMethods.SetAllPoints = noop
frameMethods.SetColorTexture = noop
frameMethods.SetTextColor = noop
frameMethods.SetText = noop
frameMethods.SetJustifyH = noop
frameMethods.SetWordWrap = noop
frameMethods.EnableMouse = noop
frameMethods.RegisterForClicks = noop
frameMethods.HookScript = noop

local createFrame = CreateFrame
_G.CreateFrame = function(kind, name, parent)
    local frame = createFrame(kind, name, parent)
    if name then _G[name] = frame end
    return frame
end
ns.Helpers.BaseClearAllPoints = frameMethods.ClearAllPoints
ns.Helpers.BaseSetPoint = frameMethods.SetPoint
ns.Helpers.FrameMutationRestricted = function() return false end
ns.Helpers.FrameIsProtected = function() return false end
ns.Helpers.FrameIsAnchoringRestricted = function() return false end
ns.Helpers.FrameVisibleSecure = function(frame) return frame and frame:IsShown() or false end
ns.Helpers.GetSkinBorderColor = function() return 1, 1, 1, 1 end
ns.Addon.SafeSetFont = noop
ns.Addon.Datatexts = { AttachToSlot = noop, DetachFromSlot = noop }

local refreshSlots = assert(env.findUpvalue(update, "RefreshDatatextSlots"))
for i = 1, math.huge do
    local name = debug.getupvalue(refreshSlots, i)
    assert(name, "missing font library upvalue")
    if name == "LSM" then
        debug.setupvalue(refreshSlots, i, { Fetch = function() return "font" end })
        break
    end
end

local settings = assert(env.findUpvalue(update, "GetSettings"))()
settings.size, settings.scale, settings.borderSize = 226, 1, 1
profile.datatext = { enabled = true, height = 24, offsetY = 4 }
profile.frameAnchoring = {
    datatextPanel = { point = "CENTER", parent = "disabled", relative = "CENTER", offsetX = 952, offsetY = 560 },
    minimap = { point = "LEFT", parent = "datatextPanel", relative = "LEFT", offsetX = -1, offsetY = -133 },
}
assert(loadfile("modules/layout/anchoring.lua"))("QUI", ns)

update()
local panel = assert(_G.QUI_DatatextPanel)
_G.QUI_ApplyFrameAnchor("datatextPanel")
_G.QUI_ApplyFrameAnchor("minimap")
assert(panel.point[2] == UIParent and Minimap.point[2] == panel,
    "the reported saved profile must produce a valid minimap-to-panel chain")
for _ = 1, 3 do update() end
assert(panel.point[2] == UIParent and panel.point[4] == 952 and panel.point[5] == 560,
    "refresh must preserve the panel's disabled-parent screen position")
assert(Minimap.point[2] == panel, "refresh must preserve the minimap following the panel")
assert(panel:GetWidth() == 226 and panel:GetHeight() == 24 and panel:IsShown(),
    "preserving anchors must still refresh panel dimensions and visibility")

panel:ClearAllPoints()
update()
assert(panel.point and panel.point[2] == UIParent,
    "a newly positioned panel must receive its saved anchor during refresh")
profile.frameAnchoring.datatextPanel.parent = "screen"
update()
assert(panel.point[2] == UIParent and panel.point[4] == 952,
    "explicit screen anchors must retain their saved offsets")

_G.QUI_IsLayoutModeActive = function() return true end
panel:SetPoint("CENTER", UIParent, "CENTER", 100, 200)
update()
assert(panel.point[4] == 100 and panel.point[5] == 200,
    "refresh in Layout Mode must preserve the current unsaved drag position")
_G.QUI_IsLayoutModeActive = function() return false end
update()
assert(panel.point[4] == 952 and panel.point[5] == 560,
    "refresh outside Layout Mode must apply the saved position")

Minimap:ClearAllPoints()
Minimap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
profile.frameAnchoring.datatextPanel = {
    parent = "minimap", point = "TOP", relative = "BOTTOM", offsetY = -9,
    autoWidth = true, widthAdjust = 12, hideWithParent = true,
}
update()
assert(panel.point[2] == Minimap and panel.point[5] == -9,
    "custom panel anchors below the minimap must retain their configured offset")
assert(panel:GetWidth() == Minimap:GetWidth() + 12,
    "saved automatic width must be reapplied after refreshing the panel size")
Minimap:Hide()
update()
assert(not panel:IsShown(), "hide-with-parent must survive the panel refresh")
Minimap:Show()
update()
assert(panel:IsShown(), "the panel must return when its anchor parent returns")

profile.frameAnchoring = setmetatable({}, { __index = {
    datatextPanel = { parent = "screen", offsetX = 100 },
} })
update()
assert(panel.point[1] == "TOP" and panel.point[2] == Minimap and panel.point[3] == "BOTTOM"
    and panel.point[5] == -5, "without a saved anchor the panel must use its native minimap offset")
_G.InCombatLockdown = function() return true end
local point = panel.point
update()
assert(panel.point == point, "combat refresh must defer panel positioning")

print("PASS minimap_datatext_anchor_test")
