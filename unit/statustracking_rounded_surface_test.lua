local f = assert(io.open("modules/skinning/frames/statustracking.lua"))
local source = f:read("*a")
f:close()
local settings = {statusTrackingBarsBorderThickness = 1, statusTrackingBarsBarColorMode = "blizzard"}
local style, masked
local scope = setmetatable({
    GetGeneralSettings = function() return settings end,
    IsModuleEnabled = function() return true end,
    FALLBACK_TEXTURE = "texture",
    SkinBase = {
        ApplyChromeBackdrop = function(_, opts) style = opts end,
        RoundBarTexture = function(owner, texture) masked = {owner, texture} end,
    },
    ns = {Helpers = {ApplyBarStyle = function() end}},
}, {__index = _G})
local function extract(first, last, name)
    local a = assert(source:find(first,1,true))
    local b = assert(source:find(last,a,true))
    local chunk = assert(loadstring(source:sub(a,b-1) .. "\nreturn " .. name))
    setfenv(chunk,scope)
    return chunk()
end
local layout = extract("local function UpdateBackdropLayout(", "local function ApplyBarTextStyle(", "UpdateBackdropLayout")
local fill = extract("local function RefreshBarFillAndTexture(", "local function HookBarUpdate(", "RefreshBarFillAndTexture")
layout({})
assert(style.radius == 3 and style.borderPixels == 1 and style.withBackground,
    "tracking bars use rounded chrome with the configured physical border")
settings.statusTrackingBarsBorderThickness = 2
layout({})
assert(style.borderPixels == 2, "explicit custom border thickness is retained")
local texture = {}
local bar = {StatusBar = {
    SetStatusBarTexture = function() end,
    GetStatusBarTexture = function() return texture end,
    SetStatusBarColor = function() error("native Blizzard fill color must remain intact") end,
}}
fill(bar)
assert(masked[1] == bar.StatusBar and masked[2] == texture,
    "native fill texture is masked without replacing its value or color")
print("OK: statustracking_rounded_surface_test")
