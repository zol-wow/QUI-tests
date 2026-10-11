local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local f=assert(io.open("modules/skinning/gameplay/objectivetracker.lua"));local s=f:read("*a");f:close()
local a=assert(s:find("local function StyleScenarioTrackerDetails()",1,true))
local b=assert(s:find("local RefreshTrackerContent",a,true))
local stage=env.NewFrame("Frame");stage:SetSize(201,83)
for _,k in ipairs({"NormalBG","FinalBG","ThemeOverlay","GlowTexture"})do stage[k]=stage:CreateTexture()end
for _,k in ipairs({"Stage","Name","CompleteLabel"})do stage[k]=stage:CreateFontString();stage[k]:SetText(k)end
local pool=setmetatable({}, {__index=function()error("scenario visual skin must not access UIWidget pools")end})
stage.WidgetContainer=pool
local line={Text=stage:CreateFontString()};line.Text:SetText("0/1 target slain")
local scenario={StageBlock=stage,ObjectivesBlock={usedLines={line}}}
local settings={skinObjectiveTracker=true,objectiveTrackerModuleFontSize=12,objectiveTrackerTextFontSize=10,
 objectiveTrackerTitleColor={1,1,1,1},objectiveTrackerTextColor={.8,.8,.8,1}}
local styled=0;local icons=0
local sandbox=setmetatable({_G={ScenarioObjectiveTracker=scenario},
 GetSettings=function()return settings end,GetFontPath=function()return "QUIFont.ttf"end,GetFontFlags=function()return ""end,
 CJKFont=function(t,p,z,flags)t:SetFont(p,z,flags)end,
 SafeSetTextColor=function(t,c)t:SetTextColor(unpack(c))end,
 StyleLine=function(l,p,z,c,skipHeight)assert(l==line and skipHeight);styled=styled+1;l.Text:SetFont(p,z,"")end,
 StyleLineIcon=function(l,fixed)assert(l==line and fixed);icons=icons+1 end}, {__index=_G})
local chunk=assert(loadstring(s:sub(a,b-1).."\nreturn StyleScenarioTrackerDetails"));setfenv(chunk,sandbox)
local style=chunk();style()
for _,k in ipairs({"NormalBG","FinalBG","ThemeOverlay","GlowTexture"})do assert(stage[k]:GetAlpha()==0,"native scenario art must yield to QUI")end
assert(stage.Stage:GetText()=="Stage" and line.Text:GetText()=="0/1 target slain","styling must preserve native objective data")
assert(stage.Stage:GetFont()=="QUIFont.ttf" and styled==1 and icons==1,"fixed stage and criteria must use QUI styles")
assert(stage:GetWidth()==201 and stage:GetHeight()==83 and stage.WidgetContainer==pool,"scenario styling must preserve native geometry and pool ownership")
stage.NormalBG:SetAlpha(1);style();assert(stage.NormalBG:GetAlpha()==0,"reused scenario content must be restyled")
settings.skinObjectiveTracker=false;stage.NormalBG:SetAlpha(1);style();assert(stage.NormalBG:GetAlpha()==1)
print("OK: objective_tracker_scenario_details_test")
