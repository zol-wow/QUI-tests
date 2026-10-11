local f=assert(io.open("modules/skinning/gameplay/objectivetracker.lua"));local s=f:read("*a");f:close()
local marker="-- <<< QUI_TEST_EXTRACT scenario_stage_spacing"
local a=assert(s:find(marker,1,true));local b=assert(s:find(marker,a+#marker,true))
local combat,dirty=false,0
local stage={height=83,widgetSetID=nil,IsShown=function()return true end,GetTop=function()return 500 end,
 CompleteLabel={IsShown=function()return false end},
 Stage={IsShown=function()return true end,GetText=function()return "Clear the Cursed Depths"end,
 _height=36,_top=482,GetHeight=function(self)return self._height end,
 SetHeight=function(self,h)self._height=h end,GetJustifyV=function()return "MIDDLE"end,
 SetJustifyV=function(self,v)self.justify=v end,GetPoint=function()return "TOPLEFT",{},"TOPLEFT",15,-18 end,
 SetPoint=function(self,_,_,_,_,y)self._top=500+y end,
 GetTop=function(self)return self._top end,GetStringHeight=function()return 12 end},
 Name={IsShown=function()return true end,GetText=function()return ""end}}
local header={height=20,GetText=function()return ""end,GetHeight=function(self)return self.height end,
 SetHeight=function(self,h)self.height=h end}
local scenario={lineSpacing=12,ObjectivesBlock={HeaderText=header},StageBlock=stage,MarkDirty=function()dirty=dirty+1 end}
local data={}
local env=setmetatable({SkinBase={GetFrameData=function(_,k)return data[k] end,SetFrameData=function(_,k,v)data[k]=v end},_G={ScenarioObjectiveTracker=scenario},GetSettings=function()return {skinObjectiveTracker=true}end,
 InCombatLockdown=function()return combat end},{__index=_G})
local chunk=assert(loadstring(s:sub(a+#marker,b-1).."\nreturn CompactScenarioStageSpacing"));setfenv(chunk,env)
local compact=chunk();compact();assert(stage.height==18 and dirty==1 and header.height==1 and scenario.lineSpacing==4,"empty native header must not reserve a text row")
compact();assert(dirty==1,"stable height must not trigger another layout")
stage.widgetSetID=42;compact();assert(stage.height==83 and scenario.lineSpacing==12 and stage.Stage._height==36 and stage.Stage.justify=="MIDDLE","native widget stages restore text geometry")
stage.widgetSetID=nil;combat=true;compact();assert(stage.height==83,"combat must not change native layout")
combat=false;stage.CompleteLabel.IsShown=function()return true end;compact();assert(stage.height==83,"completion animations keep native dimensions")
print("OK: objective_tracker_stage_spacing_test")
