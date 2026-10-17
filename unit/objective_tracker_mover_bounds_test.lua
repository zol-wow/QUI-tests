local f=assert(io.open("modules/layout/layoutmode.lua")); local s=f:read("*a");f:close()
local a=assert(s:find("local DISPLAY_ELEMENTS = {",1,true))
local b=assert(s:find("        if _G.BonusRollFrame",a,true))
local holder,tracker,backdrop={},{},{}
local shown=true
function backdrop:IsShown() return shown end
local definitions={}
local globals={QUI_ObjectiveTrackerHolder=holder,ObjectiveTrackerFrame=tracker}
local ns={L=setmetatable({},{__index=function(_,k)return k end}),SkinBase={}}
function ns.SkinBase.GetFrameData(frame,key)
    assert(frame==tracker and key=="backdrop");return backdrop
end
local sandbox=setmetatable({_G=globals,ns=ns,um={RegisterElement=function(_,def)definitions[def.key]=def end}}, {__index=_G})
local chunk=assert(loadstring(s:sub(a,b-1)))
setfenv(chunk,sandbox);chunk()
local def=assert(definitions.objectiveTracker)
assert(def.isOwned,"tracker mover must use a holder overlay instead of reparenting the native tracker")
assert(def.getFrame()==holder,"mover must move the same frame used by gameplay anchoring")
local overlay={}
function overlay:ClearAllPoints() self.target=nil end
function overlay:SetAllPoints(target) self.target=target end
def.setupOverlay(overlay,holder)
assert(overlay.target==backdrop,"mover must outline visible skin bounds, not reserved native height")
shown=false;def.setupOverlay(overlay,holder)
assert(overlay.target==tracker,"hidden background must retain native tracker bounds")
globals.QUI_ObjectiveTrackerHolder=nil
assert(def.getFrame()==tracker,"missing holder must retain native fallback")
ns.SkinBase=nil;def.setupOverlay(overlay,tracker)
assert(overlay.target==tracker,"disabled skinning must retain native fallback")
print("OK: objective_tracker_mover_bounds_test")
