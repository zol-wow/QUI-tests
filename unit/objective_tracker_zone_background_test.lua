local f=assert(io.open("modules/skinning/gameplay/objectivetracker.lua"));local s=f:read("*a");f:close()
local a=assert(s:find("local function UpdateBackdropAnchors()",1,true))
local b=assert(s:find("local function HidePOIButtonGlows()",a,true))
local function frame(bottom,height)
 local t={shown=true,bottom=bottom,height=height or 30,points={}}
 function t:IsShown()return self.shown end
 function t:GetBottom()return self.bottom end
 function t:GetHeight()return self.height end
 function t:GetContentsHeight()return self.height end
 function t:GetTop()return 1000 end
 function t:ClearAllPoints()self.points={} end
 function t:SetPoint(...)self.points[#self.points+1]={...}end
 function t:SetHeight(h)self.height=h;self.heightWrite=h end
 function t:Show()self.shown=true end
 function t:Hide()self.shown=false end
 return t
end
local root=frame(400,600);root.Header=frame(975,25)
local backdrop=frame(0)
local scenario=frame(650,300)
local quest=frame(200,350)
local globals={ObjectiveTrackerFrame=root,ScenarioObjectiveTracker=scenario,QuestObjectiveTracker=quest}
local env=setmetatable({_G=globals,trackerModules={"ScenarioObjectiveTracker","QuestObjectiveTracker"},
 WIDGET_POOL_TRACKER_NAMES={ScenarioObjectiveTracker=true},
 SkinBase={GetFrameData=function()return backdrop end},
 Helpers={SafeNumberOrNil=function(x)return type(x)=="number" and x or nil end},
 GetSettings=function()return {objectiveTrackerHeight=600}end}, {__index=_G})
local chunk=assert(loadstring(s:sub(a,b-1).."\nreturn UpdateBackdropAnchors"));setfenv(chunk,env)
local update=chunk()
update()
local point=backdrop.points[#backdrop.points]
assert(not backdrop.heightWrite and point[2]==quest,
 "background must cover actual visible objectives beyond configured native height in a scenario")
quest.shown=false;update()
point=backdrop.points[#backdrop.points]
assert(point[2]==scenario,"scenario-only objectives must contribute to background bounds")
scenario.shown=false;update()
point=backdrop.points[#backdrop.points]
assert(backdrop.shown and point[2]==root.Header,
 "fully collapsed tracker must retain a background around its visible master header")
assert(root.height==600 and scenario.height==300,"backdrop resizing must not resize native trackers")
print("OK: objective_tracker_zone_background_test")
