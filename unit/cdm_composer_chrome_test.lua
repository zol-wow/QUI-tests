local file = assert(io.open(os.getenv("QUI_COMPOSER_SOURCE") or "QUI_CDM/cdm/settings/composer.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function SetSimpleBackdrop(", 1, true))
local last = assert(source:find("local function CreateSmallButton(", first, true))
local build = assert((loadstring or load)("return function(ns)\n" .. source:sub(first,last-1)
    .. "\nreturn SetSimpleBackdrop end"))()
local calls, colors = 0, nil
local background = {color = {0,0,0,1}}
function background:GetVertexColor() return unpack(self.color) end
function background:SetColorTexture(...) self.color = {...} end
local surface = {background = background}
function surface:SetColors(border, bg) colors = border; background.color = bg end
local ns = {UIKit = {CreateRoundedSurface = function(_, opts)
    calls = calls + 1
    assert(opts.radius == 8 and opts.borderColor[4] == 0.45,
        "composer panels must use rounded subdued surfaces")
    return surface
end}}
local frame = {}
function frame:IsObjectType() return false end
function frame:CreateTexture()
    local texture = {}
    for _, method in ipairs({"SetAllPoints","SetPoint","SetHeight","SetWidth","SetColorTexture"}) do
        texture[method] = function() end
    end
    return texture
end
local apply = build(ns)
apply(frame,0.1,0.2,0.3,1,0.4,0.5,0.6,1)
assert(calls == 1 and frame._bg == background,
    "composer chrome must reuse the shared rounded surface")
frame:SetBackdropColor(0.2,0.3,0.4,0.8)
frame:SetBackdropBorderColor(1,0,0,0.9)
assert(colors[1] == 1 and colors[4] == 0.9 and background.color[4] == 0.8,
    "rounded composer surfaces must retain hover and warning color updates")
frame._border[1]:SetColorTexture(0,1,0,0.5)
assert(colors[2] == 1, "composer theme refresh must reach the rounded border")
frame._quiSquareChrome = true
frame._bg, frame._border = nil, nil
apply(frame,0,0,0,0,1,1,1,0.5)
assert(calls == 1, "spell icon cells must retain square borders")
print("OK: composer shared rounded chrome")

local layoutStart = assert(source:find("local function BuildComposerLayout(host)", 1, true))
local frameStart = assert(source:find('    local frame = CreateFrame("Frame", nil, scroll)', layoutStart, true))
local frameEnd = assert(source:find("    host._composerLayout = frame", frameStart, true))
local chrome = assert((loadstring or load)("return function(CreateFrame, scroll, MIN_W, MIN_H, embedded, GetChromeBgPanel, ACCENT_R, ACCENT_G, ACCENT_B)\n"
    .. source:sub(frameStart, frameEnd - 1) .. "\nreturn frame end"))()
local function create()
    local f = {CreateTexture = frame.CreateTexture}
    function f:SetSize() end
    return f
end
local scroll = {SetScrollChild = function() end}
local function bg() return 0.1,0.1,0.1 end
local embedded = chrome(create, scroll, 400,260,true,bg,1,1,1)
assert(embedded._bg == nil and embedded._border == nil,
    "embedded composer must not add a nested window background or border")
local standalone = chrome(create, scroll, 400,260,false,bg,1,1,1)
assert(standalone._bg and standalone._border,
    "standalone composer must retain its window chrome")
print("OK: composer inherits embedded page background")
