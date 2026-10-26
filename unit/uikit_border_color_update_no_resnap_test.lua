-- tests/unit/uikit_border_color_update_no_resnap_test.lua
-- Run: lua tests/unit/uikit_border_color_update_no_resnap_test.lua
-- luacheck: globals CreateFrame

local refreshDrivers = {}
local activePixelSize = 0.5
local pixelSizeCalls = 0
local pixelsCalls = 0

function CreateFrame()
    local frame = { scripts = {} }

    function frame:SetScript(scriptName, fn)
        self.scripts[scriptName] = fn
    end

    refreshDrivers[#refreshDrivers + 1] = frame
    return frame
end

local function NewTexture()
    local texture = {
        clearCount = 0,
        pointCount = 0,
    }

    function texture:ClearAllPoints()
        self.clearCount = self.clearCount + 1
    end

    function texture:SetPoint(...)
        self.pointCount = self.pointCount + 1
        self.lastPoint = { ... }
    end

    function texture:SetHeight(height)
        self.height = height
    end

    function texture:SetWidth(width)
        self.width = width
    end

    function texture:SetColorTexture(r, g, b, a)
        self.color = { r, g, b, a }
    end

    function texture:SetSnapToPixelGrid(snap)
        self.snap = snap
    end

    function texture:SetTexelSnappingBias(bias)
        self.bias = bias
    end

    function texture:Show()
        self.visible = true
    end

    function texture:Hide()
        self.visible = false
    end

    return texture
end

local function NewFrame()
    local frame = { textures = {} }

    function frame:CreateTexture()
        local texture = NewTexture()
        self.textures[#self.textures + 1] = texture
        return texture
    end

    return frame
end

local ns = {
    Helpers = {
        CHROME = {
            BORDER_PX = 1,
            BG_FALLBACK = { 0.05, 0.05, 0.05, 0.95 },
            BORDER_FALLBACK = { 0, 0, 0, 1 },
            BUTTON_BOOST = 0.07,
            SCROLLROW_BOOST = 0.03,
            DEPTH = {
                PANEL = { boost = 0, alpha = 0.95 },
                SUBPANEL = { boost = 0.04, alpha = 0.85 },
                ROW = { boost = 0.07, alpha = 0.75 },
            },
        },
        CreateStateTable = function()
            return setmetatable({}, { __mode = "k" })
        end,
    },
}

local core = {}

function core:GetPixelSize()
    pixelSizeCalls = pixelSizeCalls + 1
    return activePixelSize
end

function core:Pixels(value)
    pixelsCalls = pixelsCalls + 1
    return value * activePixelSize
end

function ns.Helpers.GetCore()
    return core
end

assert(loadfile("core/uikit.lua"))("QUI", ns)

local UIKit = ns.UIKit
local frame = NewFrame()
local edges = UIKit.CreateBorderLines(frame)

for _, edge in pairs(edges) do
    edge.clearCount = 0
    edge.pointCount = 0
end
pixelSizeCalls = 0
pixelsCalls = 0

UIKit.UpdateBorderLines(frame, 1, 0.25, 0.5, 0.75, 0.4, false)

assert(pixelSizeCalls == 0,
    "color-only border updates must not recompute pixel size; got " .. tostring(pixelSizeCalls))
assert(pixelsCalls == 0,
    "color-only border updates must not convert pixel units; got " .. tostring(pixelsCalls))

for name, edge in pairs(edges) do
    assert(edge.clearCount == 0,
        "color-only border updates must not clear points for " .. tostring(name))
    assert(edge.pointCount == 0,
        "color-only border updates must not re-anchor " .. tostring(name))
    assert(edge.color[1] == 0.25 and edge.color[2] == 0.5 and edge.color[3] == 0.75 and edge.color[4] == 0.4,
        "color-only border updates must recolor " .. tostring(name))
end

print("OK: uikit_border_color_update_no_resnap_test")

-- A preview can be fitted to a tiny intermediate scale during a panel resize.
-- Repaint only that subtree against its stable pixel reference before measuring.
ns.SafeCall = function(_, fn, ...) return pcall(fn, ...) end
local child, unrelated = NewFrame(), NewFrame()
local childEdges = UIKit.CreateBorderLines(child)
local unrelatedEdges = UIKit.CreateBorderLines(unrelated)
frame.GetChildren = function() return child end
activePixelSize = 2
UIKit.RefreshPixelBorders(frame)
assert(edges.top.height == 2 and childEdges.top.height == 2,
    "scoped border refresh must include preview descendants")
assert(unrelatedEdges.top.height == 0.5,
    "scoped preview refresh must not alter other settings or live plates")
UIKit.RefreshPixelBorders()
assert(unrelatedEdges.top.height == 2, "global scale refresh must remain supported")
print("OK: scoped pixel border refresh")
