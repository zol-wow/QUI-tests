local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function ApplyBackdropColors(", 1, true))
local last = assert(source:find("local function ApplyQUIBackdrop(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn ApplyBackdropColors"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase }, { __index = _G }))
local apply = chunk()
local frame = env.NewFrame("Frame")
apply(frame, false, .2, .3, .4, 1, .05, .06, .07, .45)
local surface = frame._quiRoundedSurface
assert(surface and surface.radius == 8, "tracker background must match the rounded window shell")
assert(surface.background.color[4] == .45, "tracker must preserve configured background opacity")
apply(frame, true, .2, .3, .4, 1, .05, .06, .07, .25)
assert(surface.shown, "borderless tracker must retain its rounded fill")
for _, texture in pairs(surface.border) do
    assert(texture.vertex[4] == 0, "hide-border option must make rounded border transparent")
end
local background = frame.regions[1]
assert(not background:IsShown() and surface.background.color[4] == .25,
    "borderless tracker must preserve configured background opacity")
for _, texture in ipairs(frame.regions) do
    if texture.layer == "BORDER" then assert(not texture:IsShown(), "hide-border option must hide physical border edges") end
end
apply(frame, false, .2, .3, .4, 1, .05, .06, .07, .45)
assert(surface.shown and not background:IsShown(), "restoring tracker border must restore rounded chrome")
print("OK: objectivetracker_rounded_background_test")
