local env = dofile("tools/_addon_env.lua")
local ns = env.LoadCore()
local Helpers = ns.Helpers
local profile = {general = {skinObjectiveTracker = true, skinBorderColorSource = "custom",
    skinBorderColor = {.2,.3,.4,1}, objectiveTrackerBackgroundOpacity = .75}}
Helpers.GetProfile = function() return profile end
_G.QUI.GetSkinColor = function() return .8,.1,.2,1 end
_G.RAID_CLASS_COLORS = {MAGE = {r=.4,g=.8,b=.9}}
_G.CUSTOM_CLASS_COLORS = nil
local f = assert(io.open("modules/skinning/gameplay/objectivetracker.lua"))
local source = f:read("*a"); f:close()
local function extract(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a, true))
    return source:sub(a, b-1)
end
local globals = {ObjectiveTrackerFrame = {}, ObjectiveTrackerManager = {backgroundAlpha = .6}}
function globals.ObjectiveTrackerFrame:EnableMouse(v) self.mouse = v end
local backdrop = {}
local paint
local hooks, timers = {}, {}
local function noop() end
local skin = {
    GetWindowColors = function(settings, prefix)
        assert(settings == profile.general and prefix == "objectiveTracker", "tracker must resolve its registered border override")
        local r,g,b,a = Helpers.GetSkinBorderColor(settings, prefix)
        return r,g,b,a,.05,.06,.07,1
    end,
    GetFrameData = function(_, key) if key == "backdrop" then return backdrop end end,
    SetFrameData = noop,
}
local sandbox = setmetatable({ns=ns, Helpers=Helpers, SkinBase=skin, _G=globals,
    GetSettings=function() return profile.general end,
    ApplyLayoutSettingsSafely=noop, UpdateBackdropAnchors=noop,
    RefreshTrackerContent=noop, StyleExistingProgressBars=noop,
    ApplyBackdropColors=function(_, hidden, r,g,b,a, br,bg,bb,ba)
        paint={hidden=hidden,r=r,g=g,b=b,a=a,br=br,bg=bg,bb=bb,ba=ba}
    end,
    C_Timer={After=function(_, fn) timers[#timers+1]=fn end},
    hooksecurefunc=function(_, _, fn) hooks[#hooks+1]=fn end,
}, {__index=_G})
local body = extract("local function ResolveTrackerBackground(", "local function ApplyBackdropColors(")
    .. "\nlocal RefreshObjectiveTracker\n"
    .. extract("RefreshObjectiveTracker = function()", "if ns.Registry then")
    .. "\nreturn RefreshObjectiveTracker"
local chunk = assert(loadstring(body)); setfenv(chunk,sandbox)
local refresh = chunk()
local entry = assert(Helpers.BorderRegistry.byKey.objectiveTracker)
assert(entry.db(profile)==profile.general and entry.prefix=="objectiveTracker" and entry.category=="Skinning")
local function check(sourceName, expected)
    profile.general.objectiveTrackerBorderColorSource=sourceName
    entry.refresh()
    assert(paint.r==expected[1] and paint.g==expected[2] and paint.b==expected[3] and paint.a==expected[4], sourceName)
end
check("inherit", {.2,.3,.4,1})
check("theme", {.8,.1,.2,1})
check("class", {.4,.8,.9,1})
profile.general.objectiveTrackerBorderColor={.9,.7,.2,.5}
check("custom", {.9,.7,.2,.5})
profile.general.hideSkinBorders=true
check("inherit", {.2,.3,.4,0})
check("custom", {.9,.7,.2,.5})
profile.general.hideObjectiveTrackerBorder=true
refresh(); assert(paint.hidden==true, "existing local hide setting must remain authoritative")
-- Exercise the actual native opacity hook. A custom fill must survive its callback.
sandbox.RefreshObjectiveTracker=refresh
globals.ObjectiveTrackerManager.SetOpacity=noop
local hookChunk=assert(loadstring(extract("    local manager = _G.ObjectiveTrackerManager\n    if manager and manager.SetOpacity", "    C_Timer.After(0.5, HidePOIButtonGlows)")))
setfenv(hookChunk, sandbox); hookChunk()
assert(#hooks==1)
profile.general.objectiveTrackerBackgroundStyle="custom"
profile.general.objectiveTrackerBackgroundColor={.1,.4,.8,1}
hooks[1](globals.ObjectiveTrackerManager,10)
assert(#timers==1); timers[1]()
assert(paint.br==.1 and paint.bg==.4 and paint.bb==.8 and paint.ba==.75, "native opacity callback must preserve custom fill and opacity")
profile.general.objectiveTrackerBackgroundStyle="blizzard"
hooks[1](globals.ObjectiveTrackerManager,60); timers[2]()
assert(paint.ba==.6, "Blizzard mode must follow the native opacity")
print("OK: objective_tracker_border_controls_test")
