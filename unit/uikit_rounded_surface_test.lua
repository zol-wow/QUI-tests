local file = assert(io.open("core/uikit.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("function UIKit.CreateRoundedSurface(", 1, true))
local last = assert(source:find("function UIKit.CreateBackground(", first, true))
local code = source:sub(first, last - 1)
local compile = loadstring or load
local scale = 1
local refreshCallbacks = {}
local kit = {
    DisablePixelSnap = function() end,
    RegisterScaleRefresh = function(_, _, fn) refreshCallbacks[#refreshCallbacks + 1] = fn end,
}
local loader = assert(compile("return function(UIKit, Helpers, GetPixelSize, Round, floor, unpack)\n" .. code .. "\nend"))
loader()(kit, {AssetPath = "Interface\\AddOns\\QUI\\assets\\"}, function() return scale end,
    function(value) return math.floor(value + 0.5) end, math.floor, unpack or table.unpack)
local frame = {width = 800, height = 600, textures = {}, hooks = {}}
function frame:GetWidth() return self.width end
function frame:GetHeight() return self.height end
function frame:HookScript(event, fn) self.hooks[event] = fn end
function frame:CreateTexture(_, layer, _, level)
    local texture = {layer = layer, level = level, alpha = 1, shown = true, points = {}}
    function texture:SetTexture(path) self.path = path end
    function texture:SetColorTexture(...) self.solid = {...} end
    function texture:SetAlpha(value) self.alpha = value end
    function texture:SetVertexColor(...) self.color = {...} end
    function texture:ClearAllPoints() self.points = {} end
    function texture:SetPoint(...) self.points[#self.points + 1] = {...} end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:SetWidth(width) self.width = width end
    function texture:SetHeight(height) self.height = height end
    function texture:SetTexCoord(...) self.coords = {...} end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    function texture:IsShown() return self.shown end
    self.textures[#self.textures + 1] = texture
    return texture
end
local surface = kit.CreateRoundedSurface(frame, {radius = 8, bgColor = {0.1, 0.2, 0.3, 0.9}})
assert(#frame.textures == 15, "rounded fill and true outline must use 15 reusable pieces")
assert(surface.fill.tl.width == 8 and surface.border.top.height == 1, "corner radius and thin border must be native pixel sized")
assert(surface.fill.center.points[1][4] == 8 and surface.fill.center.points[2][4] == -8, "center fill must leave corner tiles uncovered")
assert(surface.border.tl.coords[1] == (8 + 15) / 64, "border must sample the radius-specific arc, not a filled corner")
assert(surface.fill.tr.coords[1] > surface.fill.tr.coords[2], "right corners must reflect the original geometry")
assert(surface.fill.bl.coords[3] > surface.fill.bl.coords[4], "bottom corners must reflect the original geometry")
surface.background:SetAlpha(0.25)
assert(surface.fill.center.alpha == 0.25 and surface.border.top.alpha == 1, "background opacity must not fade the outline")
surface.background:SetVertexColor(0.3, 0.4, 0.5, 0.6)
assert(surface.fill.tl.color[4] == 0.6 and surface.background:GetAlpha() == 0.25, "background proxy must preserve separate tint and opacity")
surface.background:Hide()
assert(not surface.background:IsShown() and not surface.fill.tl.shown and surface.border.tl.shown,
    "legacy hover consumers can hide rounded fill without removing its border")
surface.background:Show()
assert(surface.background:IsShown() and surface.fill.tl.shown, "legacy hover consumers can restore rounded fill")
local reused = kit.CreateRoundedSurface(frame, {radius = 12})
assert(surface == reused and #frame.textures == 15 and #refreshCallbacks == 1, "reapplying surface styling must reuse regions and scale registration")
assert(surface.fill.tl.width == 12, "reapplying radius must update geometry")
scale = 2
refreshCallbacks[1]()
assert(surface.fill.tl.width == 24 and surface.border.top.height == 2, "scale changes must refresh native corner and border geometry")
surface:Hide()
frame.height = 6
frame.hooks.OnSizeChanged()
assert(surface.fill.tl.width == 2, "tiny height must clamp corner radius")
for _, texture in ipairs(frame.textures) do assert(not texture.shown, "resize must not reshow hidden chrome") end
surface:Show()
for _, texture in ipairs(frame.textures) do assert(texture.shown, "surface show must restore all pieces") end
surface:Hide()
frame.height = 100
surface:Show()
assert(surface.fill.tl.width == 24, "surface show must refresh geometry changed while hidden")
local asset = assert(io.open("assets/appearance/RoundedSurface.tga", "rb"))
local data = asset:read("*a")
asset:close()
local function Alpha(x, y) return data:byte(18 + (y * 1024 + x) * 4 + 4) end
assert(#data == 18 + 1024 * 32 * 4, "original atlas must remain a portable 32-bit TGA")
assert(Alpha(0, 0) == 0 and Alpha(31, 31) == 255, "filled corner must have transparent outer corner and opaque interior")
assert(Alpha(8 * 32 + 31, 31) == 0, "border arc must leave its center transparent for the window opacity control")
local antialias = false
for y = 0, 31 do
    for x = 0, 31 do
        local alpha = Alpha(x, y)
        antialias = antialias or (alpha > 0 and alpha < 255)
    end
end
assert(antialias, "corners must include antialiased edge pixels")
print("OK: uikit_rounded_surface_test")
