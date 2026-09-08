local env = (dofile("tests/helpers/load_minimap_runtime.lua"))()
local module = env.ns.Addon.Minimap
local updateButtons = assert(env.findUpvalue(module.Initialize, "UpdateButtonVisibility"))
local settings = assert(env.findUpvalue(updateButtons, "GetSettings"))()
local native = setmetatable({}, { __index = _G })

function native.CreateFromMixins(...)
    local result = {}
    for i = 1, select("#", ...) do
        for key, value in pairs(select(i, ...)) do result[key] = value end
    end
    return result
end

function native.Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

for _, path in ipairs({
    "Blizzard_SharedXMLBase/FrameUtil.lua",
    "Blizzard_SharedXML/LayoutFrame.lua",
}) do
    setfenv(assert(loadfile("tests/framexml/Interface/AddOns/" .. path)), native)()
end

local function child(name, left, bottom, width, height)
    local frame = env.newFrame(name, "Frame", MinimapCluster)
    frame.left, frame.bottom, frame.width, frame.height = left, bottom, width, height
    function frame:IsShown() return true end
    function frame:GetScaledRect()
        return self.left, self.bottom, self.width, self.height
    end
    return frame
end

local indicator = child("IndicatorFrame", 1235.9733886719, 720.63995361328, 20, 15)
local container = child("MinimapContainer", 1103.3331298828, 512, 215, 226)
local cluster = MinimapCluster
for key, value in pairs(native.ResizeLayoutMixin) do cluster[key] = value end
cluster.children = { indicator, container }
cluster.widthPadding = 20
function cluster:GetRegions() end
function cluster:GetNumPoints() return 1 end
function cluster:GetEffectiveScale() return 1 end
function cluster:GetBottom() return 768 - self:GetHeight() end

local function reset()
    cluster:SetSize(256, 1076.6667480469)
    cluster.dirty = false
end

reset()
updateButtons()
assert(cluster:GetHeight() == 226,
    "QUI must resize the hidden cluster even when dirty=false after arranging buttons")
assert(cluster:GetBottom() - 10 > 10,
    "the reported minimap bounds must leave positive space for Blizzard's right action bars")

InCombatLockdown = function() return true end
reset()
updateButtons()
assert(cluster:GetHeight() == 1076.6667480469,
    "button refresh must not resize the protected cluster during combat")
InCombatLockdown = function() return false end

local function replaceUpvalue(func, wanted, replacement)
    for i = 1, math.huge do
        local name = debug.getupvalue(func, i)
        assert(name, "missing refresh dependency: " .. wanted)
        if name == wanted then
            debug.setupvalue(func, i, replacement)
            return
        end
    end
end

local function noop() end
for _, name in ipairs({
    "StartUpdateTickers", "SetMinimapShape", "UpdateBackdrop", "UpdateMinimapSize",
    "ApplyZoomLevel", "UpdateClock", "UpdateClockTime", "UpdateCoords",
    "UpdateCoordsPosition", "UpdateZoneText", "UpdateDatatextPanel",
    "SetupAddonButtonHiding", "RefreshButtonDrawer", "UpdateDungeonEyePosition",
    "UpdateMiddleClickMenuOverlayState", "SetupAutoZoom",
}) do
    replaceUpvalue(module.Refresh, name, noop)
end
Minimap.SetFrameLevel = noop
Minimap.SetFixedFrameStrata = noop
Minimap.SetFixedFrameLevel = noop
Minimap.ClearAllPoints = noop
function Minimap:SetPoint()
    indicator.bottom = 32
end
settings.position = { "TOPLEFT", "BOTTOMLEFT", 790, 285 }
env.ns.Helpers.GetModuleDB = function() return settings end

reset()
module:Refresh()
assert(cluster:GetHeight() == 706,
    "settings refresh must recalculate cluster bounds after moving the minimap")
assert(cluster:GetBottom() - 10 > 10,
    "the final refreshed minimap bounds must leave positive action-bar space")

print("OK: minimap_cluster_relayout_test")
