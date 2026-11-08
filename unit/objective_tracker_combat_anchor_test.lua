local core = dofile("tools/_addon_env.lua").LoadCore()
local f=assert(io.open("modules/layout/anchoring.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("local managedReparentState = {}",1,true))
local b=assert(source:find("local FRAME_RESOLVERS = {",a,true))
local combat=false
local timers={}
local settings={skinObjectiveTracker=true,objectiveTrackerWidth=260,objectiveTrackerHeight=600}
local function frame()
    local t={width=260,height=600,points={},protected=false,restricted=false}
    function t:IsProtected() return self.protected end
    function t:IsAnchoringRestricted() return self.restricted end
    local function check(self)
        assert(not combat or not core.Helpers.FrameMutationRestricted(self), "protected frame mutation attempted in combat")
    end
    function t:GetWidth() return self.width end
    function t:GetHeight() return self.height end
    function t:GetLeft()
        local p = self.points[1]
        if not p then return 0 end
        if p[1] == "TOPLEFT" then return p[2]:GetLeft() + p[4] end
        assert(p[1] == "CENTER" and p[3] == "CENTER")
        return p[2]:GetLeft() + p[2]:GetWidth() / 2 + p[4] - self.width / 2
    end
    function t:GetTop()
        local p = self.points[1]
        if not p then return self.height end
        if p[1] == "TOPLEFT" then return p[2]:GetTop() + p[5] end
        assert(p[1] == "CENTER" and p[3] == "CENTER")
        return p[2]:GetTop() - p[2]:GetHeight() / 2 + p[5] + self.height / 2
    end
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
    QUICore={db={profile={general=settings}}},
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
tracker.height=650
repair("objectiveTracker")
assert(holder.height==600,"native combat height changes must not shift the configured holder center/top")
tracker.height=600
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
settings.objectiveTrackerHeight=650
repair("objectiveTracker")
assert(holder.height==600,"protected holder dimensions must not change in combat")
combat=false;eventFrame.event(eventFrame,"PLAYER_REGEN_ENABLED")
assert(holder.height==650,"holder dimensions must catch up after combat")
holder.protected=false
settings.objectiveTrackerHeight=1000
repair("objectiveTracker")
assert(holder.height==1000,"managed holder must reserve the full expanded tracker height")
holder:ClearAllPoints()
holder:SetPoint("CENTER",parent,"CENTER",-400,100)
ns.SyncManagedHolderSize("objectiveTracker")
local savedLeft,savedTop=tracker:GetLeft(),tracker:GetTop()
for _,skinned in ipairs({false,true}) do
    settings.skinObjectiveTracker=skinned
    for _,inCombat in ipairs({false,true}) do
        combat=inCombat
        for _,inScenario in ipairs({true,false,true,false}) do
            tracker.width,tracker.height=inScenario and 235 or 260,inScenario and 800 or 1000
            ns.SyncManagedHolderSize("objectiveTracker")
            assert(tracker:GetLeft()==savedLeft and tracker:GetTop()==savedTop,
                "scenario changes must preserve the saved tracker top-left, with skinning on/off and in combat")
            assert(tracker.width==(inScenario and 235 or 260) and tracker.height==(inScenario and 800 or 1000),
                "stable positioning must preserve native scenario content dimensions")
        end
    end
end
print("OK: objective_tracker_combat_anchor_test")
