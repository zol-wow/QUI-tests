local f=assert(io.open(os.getenv("QUI_NAV_SOURCE") or "QUI_Options/navigation.lua"));local s=f:read("*a");f:close()
local a=assert(s:find("local function SelectPage(",1,true));local b=assert(s:find("local function CreateFlyout",a,true))
local timers,offsets,drivers={},{},{}
local ready=false
local scroll={GetScrollChild=function()return {GetHeight=function()return 2600 end,GetTop=function()return ready and 1000 or nil end}end,
 GetVerticalScrollRange=function()return ready and 2000 or 0 end,GetHeight=function()return 600 end,
 SetVerticalScroll=function(_,v)offsets[#offsets+1]=v end}
local first={IsShown=function()return true end,GetTop=function()return ready and 990 or nil end}
local target={IsShown=function()return true end,GetTop=function()return ready and 200 or nil end}
local sections={{id="general",frame=first},{id="objectiveTracker",frame=target}}
local tile={index=1,_isActive=true,_activeSubPageIndex=1,_subPageBodies={[4]={GetWidth=function()return 800 end,GetHeight=function()return 600 end,_scrollFrame=scroll,_contentBody={GetHeight=function()return 2600 end,GetTop=function()return ready and 1000 or nil end,_sections=sections}}}}
local gui={CloseNavigationFlyout=function()end,SelectFeatureTile=function(_,_,_,opts)tile._activeSubPageIndex=opts.subPageIndex end,
 RefreshNavigationSectionHighlight=function()end,UpdateTileNavigationTitle=function()end,AnimateOptionsPage=function()end}
local function Driver()
 local d={scripts={}}
 function d:SetScript(k,v)self.scripts[k]=v end
 function d:Show()self.shown=true end
 function d:Hide()self.shown=false end
 drivers[#drivers+1]=d;return d
end
local sandbox=setmetatable({CreateFrame=Driver,GUI=gui,UIKit={},C_Timer={After=function(_,fn)timers[#timers+1]=fn end}},{__index=_G})
local helperStart=assert(s:find("function GUI:RunWhenSettingsLayoutReady",1,true))
local helperEnd=assert(s:find("function GUI:GetTileNavigationPages",helperStart,true))
local helper=assert(loadstring(s:sub(helperStart,helperEnd-1).."\nreturn NavigationPage, VisibleNavigationSections"));setfenv(helper,sandbox);sandbox.NavigationPage,sandbox.VisibleNavigationSections=helper()
local chunk=assert(loadstring(s:sub(a,b-1).."\nreturn SelectPage"));setfenv(chunk,sandbox);local selectPage=chunk()
local frame={};local page={pageIndex=4,section=target,sectionId="objectiveTracker"}
local function Tick()local batch=timers;timers={};for _,fn in ipairs(batch)do fn()end;for _,d in ipairs(drivers)do if d.shown and d.scripts.OnUpdate then d.scripts.OnUpdate(d,0.1)end end end
selectPage(frame,tile,page);Tick();assert(#offsets==0)
ready=true;Tick();Tick();Tick();Tick();assert(offsets[1]==800,"first Objective Tracker click must survive initially unresolved layout")
-- A newer click on the same outer page supersedes the pending section jump.
offsets={};ready=false;selectPage(frame,tile,page);Tick()
selectPage(frame,tile,{pageIndex=4,section=first,sectionId="general"});ready=true;Tick();Tick();Tick()
assert(#offsets==1 and offsets[1]==0,"stale request must not override a newer section selection")
offsets={};ready=false;selectPage(frame,tile,page);Tick();tile._activeSubPageIndex=2;ready=true;Tick()
assert(#offsets==0,"deferred section jump must not affect a different page")
-- An unavailable section must stop retrying after a bounded number of frames.
tile._activeSubPageIndex=4;ready=false;selectPage(frame,tile,page)
for _=1,30 do Tick()end
assert(#timers==0 and #offsets==0 and not drivers[1].scripts.OnUpdate,"layout retry must be bounded")
local innerOwner=tile._subPageBodies[4]
tile._subPageBodies[4]={_contentBody={_sections={}},_scrollFrame={SetVerticalScroll=function()error("wrong outer scroll")end}}
local activeKey="general"
tile._surfacePagesByPage={[4]={
 getActiveTab=function()return activeKey end,
 selectTab=function(key)activeKey=key end,
 getPage=function(key)if key==activeKey then return innerOwner end end,
}}
offsets={};ready=false
selectPage(frame,tile,{pageIndex=4,key="text",sectionId="objectiveTracker"});Tick()
assert(activeKey=="text" and #offsets==0,"a cold section click must select its surface tab before waiting for geometry")
ready=true;Tick();Tick();Tick()
assert(offsets[1]==800,"surface shortcuts must scroll the inner page instead of its outer settings container")
offsets={}
selectPage(frame,tile,{pageIndex=4,key="text",sectionId="general"});Tick();Tick();Tick()
assert(offsets[1]==10,"an embedded tab's first section must retain its offset inside the outer scroll")
offsets={};ready=false
selectPage(frame,tile,{pageIndex=4,key="text",sectionId="objectiveTracker"});Tick()
activeKey="general";ready=true;Tick();Tick();Tick()
assert(#offsets==0,"switching surface tabs must cancel the earlier tab's pending section jump")
offsets={};ready=false
selectPage(frame,tile,{pageIndex=4,key="text",sectionId="objectiveTracker"});Tick()
innerOwner={_contentBody=innerOwner._contentBody,_scrollFrame=scroll,GetWidth=function()return 800 end,GetHeight=function()return 600 end}
ready=true;Tick();Tick();Tick()
assert(#offsets==0,"switching the Party/Raid or unit variant must cancel the earlier body's pending jump")

gui.SelectFeatureTile=function()end
tile._activeSubPageIndex=nil
tile._surfacePagesByPage[1]=tile._surfacePagesByPage[4]
offsets={};ready=false
selectPage(frame,tile,{pageIndex=1,key="text",sectionId="objectiveTracker"});Tick()
ready=true;Tick();Tick();Tick()
assert(offsets[1]==800,"a single-page surface with an implicit first page must complete its deferred section jump")
offsets={};ready=false
selectPage(frame,tile,{pageIndex=1,key="text",sectionId="objectiveTracker"});Tick()
tile._isActive=false;ready=true;Tick();Tick();Tick()
assert(#offsets==0,"leaving a single-page tile must still cancel its pending jump")

print("OK: options_initial_section_navigation_test")
