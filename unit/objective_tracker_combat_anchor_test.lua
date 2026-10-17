local core = dofile("tools/_addon_env.lua").LoadCore()
local f=assert(io.open("modules/layout/anchoring.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("local managedReparentState = {}",1,true))
local b=assert(source:find("local FRAME_RESOLVERS = {",a,true))
local combat=false
local timers={}
local function frame()
    local t={width=260,height=600,points={},protected=false,restricted=false}
    function t:IsProtected() return self.protected end
    function t:IsAnchoringRestricted() return self.restricted end
    local function check(self)
        assert(not combat or not core.Helpers.FrameMutationRestricted(self), "protected frame mutation attempted in combat")
    end
    function t:GetWidth() return self.width end
    function t:GetHeight() return self.height end
    function t:SetSize(w,h) check(self);self.width,self.height=w,h end
    function t:SetPoint(...) check(self);self.points[#self.points+1]={...} end
    function t:ClearAllPoints() check(self);self.points={} end
    function t:SetParent(p) check(self);self.parent=p end
    function t:GetParent() return self.parent end
    function t:GetFrameStrata() return "MEDIUM" end
    function t:SetFrameStrata() end
    function t:RegisterEvent() end
    function t:SetScript(_,fn) self.event=fn end
    return t
end
local tracker=frame()
local globals={ObjectiveTrackerFrame=tracker}
local parent=frame();tracker.parent=parent
local ns={Helpers=core.Helpers}
function ns.SafeCallMethod(_, t, method, ...) return t[method](t,...) end
function ns.SafeCallMethodIfPresent(_, t, method, ...) if t and t[method] then return t[method](t,...) end end
local sandbox=setmetatable({ns=ns,nsHelpers=core.Helpers,_G=globals,UIParent=parent,
    MANAGED_REPARENT_TARGETS={{key="objectiveTracker",frameName="ObjectiveTrackerFrame",holderName="QUI_ObjectiveTrackerHolder"}},
    QUI_Anchoring={},
    InCombatLockdown=function() return combat end,
    C_Timer={After=function(_,fn)timers[#timers+1]=fn end},
    CreateFrame=function(_,name,p)local t=frame();t.parent=p;if name then globals[name]=t end;return t end,
    hooksecurefunc=function(t,name,fn)local native=t[name];t[name]=function(self,...)native(self,...);fn(self,...)end end,
},{__index=_G})
local chunk=assert(loadstring(source:sub(a,b-1).."\nreturn InstallManagedReparent, ReanchorFrameToHolder, managedReparentState, managedReparentInitFrame"))
setfenv(chunk,sandbox)
local install,repair,states,eventFrame=chunk()
local holder=install({key="objectiveTracker",frameName="ObjectiveTrackerFrame",holderName="QUI_ObjectiveTrackerHolder"})
assert(holder and tracker.points[1][2]==holder)
local function flush()
    local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end
end
combat=true
-- Native UI-panel layout (P opens the Spellbook) changes the tracker point.
for i=1,3 do
    tracker:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-70,-100)
    assert(#tracker.points==1 and tracker.points[1][2]==holder,
        "tracker must retain its QUI anchor before a native panel update returns, without visible jump")
end
assert(#timers==0,"tracker repair must not wait for a render/layout tick")
flush()
assert(#tracker.points==1 and tracker.points[1][2]==holder,
    "unprotected objective tracker must stay on QUI holder when Spellbook opens in combat")
assert(holder.width==tracker.width and holder.height==tracker.height)
-- A native combat height change must not resize a centered configured holder.
ns.GetObjectiveTrackerAnchorSize=function() return 260,600 end
tracker.height=650
repair("objectiveTracker")
assert(holder.height==600,"native combat height changes must not shift the configured holder center/top")
tracker.height=600
ns.GetObjectiveTrackerAnchorSize=nil
-- A genuinely protected or anchoring-restricted frame must still wait.
for _,kind in ipairs({"protected","restricted"})do
    tracker[kind]=true
    repair("objectiveTracker")
    assert(states.objectiveTracker.reanchorAfterCombat,"blocked repair must retain combat-end retry")
    combat=false;eventFrame.event(eventFrame,"PLAYER_REGEN_ENABLED")
    assert(not states.objectiveTracker.reanchorAfterCombat,"successful repair must clear combat retry")
    tracker[kind]=false;combat=true
end
holder.protected=true
tracker.height=650
repair("objectiveTracker")
assert(holder.height==600,"protected holder dimensions must not change in combat")
combat=false;eventFrame.event(eventFrame,"PLAYER_REGEN_ENABLED")
assert(holder.height==650,"holder dimensions must catch up after combat")
-- Exercise the production skin sizing contract, including native/scenario fallback.
local sf=assert(io.open("modules/skinning/gameplay/objectivetracker.lua"))
local skinSource=sf:read("*a");sf:close()
local sa=assert(skinSource:find("ns.GetObjectiveTrackerAnchorSize = function()",1,true))
local sb=assert(skinSource:find("local function UpdateBackdropAnchors()",sa,true))
local settings={skinObjectiveTracker=true,objectiveTrackerWidth=260,objectiveTrackerHeight=600}
local scenario=false
local producerNS={}
local producer=assert(loadstring(skinSource:sub(sa,sb-1)))
setfenv(producer,setmetatable({ns=producerNS,blizzardTrackerHeight=650,
    GetSettings=function()return settings end,IsScenarioActive=function()return scenario end},{__index=_G}))
producer()
local w,h=producerNS.GetObjectiveTrackerAnchorSize()
assert(w==260 and h==600,"anchor extent must use configured size rather than native combat root size")
settings.objectiveTrackerHeight=1000
w,h=producerNS.GetObjectiveTrackerAnchorSize();assert(h==1000,"configured height must expand beyond native maximum")
ns.GetObjectiveTrackerAnchorSize=producerNS.GetObjectiveTrackerAnchorSize
repair("objectiveTracker")
assert(holder.height==1000,"managed holder must reserve the full expanded tracker height")
settings.skinObjectiveTracker=false;assert(producerNS.GetObjectiveTrackerAnchorSize()==nil)
settings.skinObjectiveTracker=true;scenario=true;assert(producerNS.GetObjectiveTrackerAnchorSize()==nil)
print("OK: objective_tracker_combat_anchor_test")
