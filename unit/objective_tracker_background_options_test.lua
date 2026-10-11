local file = assert(io.open("modules/skinning/gameplay/objectivetracker.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function ResolveTrackerBackground(", 1, true))
local last = assert(source:find("local function ApplyBackdropColors(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn ResolveTrackerBackground"))
local manager = { backgroundAlpha = 0 }
local globals = { ObjectiveTrackerManager = manager }
setfenv(chunk, setmetatable({ _G = globals }, { __index = _G }))
local resolve = chunk()
local function check(settings, er, eg, eb, ea)
    local r, g, b, a = resolve(settings, .1, .2, .3, .95)
    assert(r == er and g == eg and b == eb and a == ea, "background style must resolve independently")
end
check(nil, .1, .2, .3, .75)
check({ objectiveTrackerBackgroundOpacity = .4 }, .1, .2, .3, .4)
check({ objectiveTrackerBackgroundOpacity = 0 }, .1, .2, .3, 0)
check({ objectiveTrackerBackgroundStyle = "custom", objectiveTrackerBackgroundColor = {.4,.5,.6,1}, objectiveTrackerBackgroundOpacity = .25 }, .4,.5,.6,.25)
check({ objectiveTrackerBackgroundStyle = "transparent", objectiveTrackerBackgroundOpacity = 1 }, .1,.2,.3,0)
check({ objectiveTrackerBackgroundStyle = "blizzard" }, .1,.2,.3,0)
manager.backgroundAlpha = .6
check({ objectiveTrackerBackgroundStyle = "blizzard" }, .1,.2,.3,.6)
globals.ObjectiveTrackerManager = nil
check({ objectiveTrackerBackgroundStyle = "blizzard" }, .1,.2,.3,.95)
assert(manager.backgroundAlpha == .6, "QUI background settings must not modify native opacity")
print("OK: objective_tracker_background_options_test")
