local profile = {}
local movers = {}
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    AuraSurface = { ApplyElementPass = function() end },
    QUI_LayoutMode = {
        RegisterElement = function(_, def) movers[def.key] = def end,
        UnregisterElement = function(_, key) movers[key] = nil end,
    },
}
ns.Helpers = {
    GetProfile = function() return profile end,
    GetModuleSettings = function(key)
        profile[key] = profile[key] or {}
        return profile[key]
    end,
    IsLayoutModeActive = function() return true end,
}
local function frame(parent)
    local f = { parent = parent, scale = 1 }
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:SetScale(value) self.scale = value end
    function f:SetClampedToScreen() end
    function f:ClearAllPoints() end
    function f:SetPoint(point, relativeTo, relativePoint, x, y)
        self.point = { point, relativeTo, relativePoint, x, y }
    end
    function f:SetAlpha() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:CreateTexture()
        return {
            SetAllPoints = function() end, SetTexture = function() end,
            SetTexCoord = function() end, Show = function() end,
        }
    end
    return f
end
UIParent = frame()
CreateFrame = function(_, _, parent) return frame(parent) end
InCombatLockdown = function() return false end
UnitExists = function() return true end
assert(loadfile("core/aura_elements.lua"))("QUI", ns)
assert(loadfile("core/aura_glue.lua"))("QUI", ns)
assert(loadfile("core/aura_theme.lua"))("QUI", ns)
assert(loadfile("core/aura_skin.lua"))("QUI", ns)
ns.AuraSkin = {}
assert(loadfile("core/aura_preview.lua"))("QUI", ns)
assert(loadfile("modules/trackers/aura_displays.lua"))("QUI", ns)
local AD = ns.QUI_AuraDisplays
local display = assert(AD.NewDisplay("Preview bounds"))
AD.RegisterLayoutElement(display)

local function check(elements, width, height)
    display.auras = { elements = { ["*"] = elements } }
    AD.ShowPreviewFor(display.id)
    local host = assert(AD.HostFor(display.id))
    assert(host.w == width and host.h == height, "display must reserve the configured grid dimensions")
    local moverW, moverH = movers[AD.ANCHOR_PREFIX .. display.id].getSize()
    assert(moverW == width and moverH == height, "mover must follow the preview host bounds")
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    local count = 0
    for _, icon in ipairs(host._quiAuraPreview) do
        if icon.shown then
            local point, relativeTo, relativePoint, x, y = unpack(icon.point)
            assert(relativeTo == host and relativePoint == "TOPLEFT", "icons must use the reserved host origin")
            local left = x - (point:find("RIGHT", 1, true) and icon.w or 0)
            local top = y + (point:find("BOTTOM", 1, true) and icon.h or 0)
            minX, maxX = math.min(minX, left), math.max(maxX, left + icon.w)
            minY, maxY = math.min(minY, top - icon.h), math.max(maxY, top)
            count = count + 1
        end
    end
    assert(count == #elements * 5, "preview must show every configured icon")
    assert(minX == 0 and maxX == width and minY == -height and maxY == 0,
        string.format("%s preview escapes mover: expected 0..%d, -%d..0; got %g..%g, %g..%g",
            elements[1].growDirection, width, height, minX, maxX, minY, maxY))
end

for _, grow in ipairs({ "DOWN", "UP", "RIGHT", "LEFT", "CENTER" }) do
    for _, anchor in ipairs({ "TOPLEFT", "BOTTOMRIGHT" }) do
        for _, rowGap in ipairs({ 0, 7 }) do
            for _, perRow in ipairs({ 0, 3, 8 }) do
                local element = {
                    mode = "filterStrip", maxIcons = 5, iconSize = 20,
                    spacing = 3, rowSpacing = rowGap, iconsPerRow = perRow,
                    growDirection = grow, anchor = anchor,
                }
                local width = (perRow == 3) and 66 or 112
                local height = (perRow == 3) and ((rowGap == 7) and 47 or 43) or 20
                if grow == "UP" or grow == "DOWN" then width, height = height, width end
                check({ element }, width, height)
                display.layout = { direction = "DOWN", alignment = "END", spacing = 4 }
                local sibling = {}
                for key, value in pairs(element) do sibling[key] = value end
                sibling.id = nil
                check({ element, sibling }, width, height * 2 + 4)
                display.layout = { direction = "RIGHT", alignment = "CENTER", spacing = 2 }
            end
        end
    end
end
local crossHost = frame()
ns.AuraPreview.Show(crossHost, { {
    mode = "filterStrip", maxIcons = 5, iconSize = 20, spacing = 3,
    rowSpacing = 7, iconsPerRow = 3, growDirection = "DOWN",
} }, {
    resolve = function(element)
        return ns.AuraGlue.ElementProfile(element, { crossEnd = true }), "TOPRIGHT", 0, 0
    end,
})
local crossPool = crossHost._quiAuraPreview
assert(crossPool[1].point[1] == "TOPRIGHT" and crossPool[2].point[5] == -23
    and crossPool[4].point[4] == -27 and crossPool[4].point[5] == 0,
    "vertical previews must honor right-aligned cross-axis wrapping and row spacing")
print("PASS: aura_displays_preview_bounds_test")
