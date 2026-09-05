-- tests/unit/cdm_buff_growth_direction_anchor_test.lua
-- Run: lua tests/unit/cdm_buff_growth_direction_anchor_test.lua
--
-- Buff icon containers: horizontal growth direction (LEFT/RIGHT) ordering in
-- the planner, the growth-anchor offset conversion math, and the seams the
-- growth anchor relies on across cdm_containers / layout mode / settings.

local ns = {}
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_containers.lua", "cdm_layout.lua")("QUI", ns)

local Layout = assert(ns.CDMLayout, "CDMLayout should load")

local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return data
end

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 0.001)
end

local function icons(n)
    local out = {}
    for i = 1, n do out[i] = { name = "icon" .. i } end
    return out
end

local function xs(plan)
    local out = {}
    for i, p in ipairs(plan.placements) do out[i] = p.x end
    return out
end

local function ys(plan)
    local out = {}
    for i, p in ipairs(plan.placements) do out[i] = p.y end
    return out
end

-- ---------------------------------------------------------------------------
-- 1. BuildBuffGridLayout ordering per growth direction (3 icons, 40px, pad 4)
-- ---------------------------------------------------------------------------
local base = { iconSize = 40, padding = 4 }

local function plan(dir)
    local s = { iconSize = base.iconSize, padding = base.padding, growthDirection = dir }
    return assert(Layout.BuildBuffGridLayout(s, icons(3), {}), "plan for " .. tostring(dir))
end

local centered = plan("CENTERED_HORIZONTAL")
assert(near(xs(centered)[1], -44) and near(xs(centered)[2], 0) and near(xs(centered)[3], 44),
    "centered: first icon on the left, growing right")
assert(near(centered.metrics.iconWidth, 128) and near(centered.metrics.totalHeight, 40),
    "centered: horizontal bounds")

local right = plan("RIGHT")
assert(near(xs(right)[1], -44) and near(xs(right)[3], 44),
    "RIGHT: same left-to-right order as centered")
assert(near(right.metrics.iconWidth, 128), "RIGHT: horizontal bounds")

local left = plan("LEFT")
assert(near(xs(left)[1], 44) and near(xs(left)[2], 0) and near(xs(left)[3], -44),
    "LEFT: first icon on the right, growing left")
assert(ys(left)[1] == 0 and ys(left)[3] == 0, "LEFT stays on one row")
assert(near(left.metrics.iconWidth, 128) and near(left.metrics.totalHeight, 40),
    "LEFT: bounds match the centered row")

local up = plan("UP")
assert(near(ys(up)[1], -44) and near(ys(up)[3], 44), "UP: first icon at the bottom")
assert(near(up.metrics.iconWidth, 40) and near(up.metrics.totalHeight, 128), "UP: vertical bounds")

local down = plan("DOWN")
assert(near(ys(down)[1], 44) and near(ys(down)[3], -44), "DOWN: first icon at the top")

local unknown = plan("SIDEWAYS")
assert(near(xs(unknown)[1], -44), "unknown direction falls back to the centered row")

-- ---------------------------------------------------------------------------
-- 2. Growth anchor helpers
-- ---------------------------------------------------------------------------
assert(Layout.NormalizeGrowthAnchor("LEFT") == "LEFT")
assert(Layout.NormalizeGrowthAnchor("BOTTOM") == "BOTTOM")
assert(Layout.NormalizeGrowthAnchor(nil) == "CENTER", "nil -> CENTER")
assert(Layout.NormalizeGrowthAnchor("TOPLEFT") == "CENTER", "corners are not growth anchors")
assert(Layout.NormalizeGrowthAnchor(42) == "CENTER", "non-strings -> CENTER")

-- A 128x40 frame centred 100px right / 50px up of screen centre on a
-- 1920x1080 screen. Its left edge is at x = 100 - 64 = 36 from centre, i.e.
-- 996 from the screen's left edge.
local fw, fh, pw, ph = 128, 40, 1920, 1080

local cx, cy = Layout.AnchorOffsetsToCenter("CENTER", "CENTER", 100, 50, fw, fh, pw, ph)
assert(near(cx, 100) and near(cy, 50), "CENTER/CENTER offsets are already centre offsets")

local lx, ly = Layout.ConvertScreenAnchorOffsets("CENTER", "CENTER", 100, 50,
    "LEFT", "LEFT", fw, fh, pw, ph)
assert(near(lx, 996) and near(ly, 50), ("CENTER->LEFT: got %s,%s"):format(lx, ly))

-- Round trip back to CENTER recovers the original offsets.
local bx, by = Layout.ConvertScreenAnchorOffsets("LEFT", "LEFT", lx, ly,
    "CENTER", "CENTER", fw, fh, pw, ph)
assert(near(bx, 100) and near(by, 50), "LEFT->CENTER round trip")

-- LEFT -> RIGHT keeps the rect: right edge is 128px further along.
local rx, ry = Layout.ConvertScreenAnchorOffsets("LEFT", "LEFT", lx, ly,
    "RIGHT", "RIGHT", fw, fh, pw, ph)
assert(near(rx, 996 + fw - pw) and near(ry, 50), ("LEFT->RIGHT: got %s,%s"):format(rx, ry))

-- TOP anchor: top edge is 50 + 20 = 70 above centre = 610 above the screen bottom,
-- expressed against the screen's TOP edge (540 above centre): 70 - 540.
local tx, ty = Layout.ConvertScreenAnchorOffsets("CENTER", "CENTER", 100, 50,
    "TOP", "TOP", fw, fh, pw, ph)
assert(near(tx, 100) and near(ty, 70 - 540), ("CENTER->TOP: got %s,%s"):format(tx, ty))

-- The edge pin is what keeps the anchor in place when width changes: the
-- LEFT offset for the same left edge is independent of the frame width.
local lx2 = Layout.ConvertScreenAnchorOffsets("CENTER", "CENTER", 100 + 20, 50,
    "LEFT", "LEFT", fw + 40, fh, pw, ph)
assert(near(lx2, lx), "wider frame with the same left edge yields the same LEFT offset")

-- ---------------------------------------------------------------------------
-- 3. Seams (source-level)
-- ---------------------------------------------------------------------------
local containers = readAll("QUI_CDM/cdm/cdm_containers.lua")
local restoreAt = assert(containers:find("RestoreContainerPosition = function(container, trackerKey)", 1, true))
local restoreBody = containers:sub(restoreAt, restoreAt + 2600)
assert(restoreBody:find("GetGrowthAnchor(trackerKey)", 1, true),
    "RestoreContainerPosition must consult the growth anchor")
assert(restoreBody:find("ConvertScreenAnchorEntry(container, settings, want)", 1, true),
    "RestoreContainerPosition must heal a mismatched screen entry to the growth anchor")
assert(restoreBody:find("ApplyScreenAnchor(container, point, relative,", 1, true),
    "RestoreContainerPosition must pin screen entries by their own point, not CENTER")
assert(not restoreBody:find('container:SetPoint("CENTER", UIParent, "CENTER"', 1, true),
    "RestoreContainerPosition must no longer hard-code a CENTER pin")
assert(restoreBody:find("if point ~= want or relative ~= want then", 1, true)
    and not restoreBody:find('want ~= "CENTER" and (point', 1, true),
    "RestoreContainerPosition must normalize screen entries to the growth anchor, CENTER included")
assert(containers:find("function CDMContainers_API:SetGrowthAnchor(trackerKey, point)", 1, true),
    "SetGrowthAnchor API must exist")
assert(containers:find("SetGrowthAnchor = function(key, point) return CDMContainers_API:SetGrowthAnchor(key, point) end", 1, true),
    "SetGrowthAnchor must be exported on ns.CDMContainers")
assert(containers:find("HealGrowthAnchorIfPending(viewer)", 1, true)
    and containers:find("HealGrowthAnchorIfPending(container)", 1, true),
    "deferred growth-anchor healing must run after both bounds paths")
assert(containers:find("getGrowAnchor = function()", 1, true),
    "custom container layout-mode element must expose getGrowAnchor")
assert(containers:find('growthAnchor = "CENTER",', 1, true),
    "custom aura containers default growthAnchor to CENTER")

local layoutMode = readAll("QUI_CDM/cdm/cdm_layout_mode.lua")
assert(layoutMode:find("getGrowAnchor = function()", 1, true),
    "built-in CDM layout-mode elements must expose getGrowAnchor")

local lm = readAll("modules/layout/layoutmode.lua")
local saveAt = assert(lm:find("local function SavePendingPosition(", 1, true))
local saveBody = lm:sub(saveAt, saveAt + 9000)
assert(saveBody:find("if def and def.getGrowAnchor then", 1, true),
    "layout mode free-placement save must consult def.getGrowAnchor")
assert(lm:find("GROW_ANCHOR_FRAC_X = {", 1, true) and lm:find("LEFT = 0, CENTER = 0.5, RIGHT = 1,", 1, true),
    "layout mode growth-anchor fractions must cover edge points")

local buffLayout = readAll("QUI_CDM/cdm/cdm_buff_layout.lua")
assert(buffLayout:find('local growLeft = (growthDirection == "LEFT")', 1, true)
    and buffLayout:find("local stepX = growLeft and -(iconWidth + padding) or (iconWidth + padding)", 1, true),
    "live buff icon layout must order LEFT right-to-left")

local page = readAll("QUI_CDM/cdm/settings/containers_page.lua")
assert(page:find('{ value = "RIGHT", text = ns.L["Grow Right"] },', 1, true)
    and page:find('{ value = "LEFT", text = ns.L["Grow Left"] },', 1, true),
    "growth direction dropdown offers LEFT and RIGHT")
assert(page:find('AURA_GROWTH_ANCHOR_OPTIONS, "growthAnchor", tracker,', 1, true)
    and page:find("ns.CDMContainers.SetGrowthAnchor(containerKey, tracker.growthAnchor)", 1, true),
    "growth anchor dropdown routes through SetGrowthAnchor")

local composer = readAll("QUI_CDM/cdm/settings/composer.lua")
assert(composer:find("local function LayoutAuraPreviewIcons(", 1, true)
    and composer:find('if containerType == "aura" and rows[1] then', 1, true),
    "composer preview lays aura containers out per growth direction")

local defaults = readAll("core/defaults.lua")
local _, buffDefaults = defaults:find('growthDirection = "CENTERED_HORIZONTAL",\n                growthAnchor = "CENTER",', 1, true)
assert(buffDefaults, "profile defaults ship growthAnchor for the buff container")

print("OK: cdm_buff_growth_direction_anchor_test")
