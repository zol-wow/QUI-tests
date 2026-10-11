local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local f=assert(io.open("modules/skinning/gameplay/objectivetracker.lua"));local s=f:read("*a");f:close()
local marker="-- <<< QUI_TEST_EXTRACT scenario_status_widget"
local a=assert(s:find(marker,1,true));local b=assert(s:find(marker,a+#marker,true))
local container=env.NewFrame("Frame")
local widget=env.NewFrame("Frame");widget:SetParent(container);widget:Show()
widget.Bar=env.NewFrame("StatusBar");widget.Bar.GetStatusBarTexture=function()return {}end
widget.Bar:SetSize(215,15);widget.Bar.value=82;widget.Bar.color="green"
widget.Label=widget:CreateFontString();widget.Label:SetText("Supply Wagon Health:")
widget.Bar.Label=widget:CreateFontString();widget.Bar.Label:SetText("82%")
widget.Bar.BorderLeft=widget.Bar:CreateTexture();widget.LabelBG=widget:CreateTexture()
widget.Setup=function()end;container.widgetFrames={[7997]=widget}
local hooks,data={},{}
local settings={skinObjectiveTracker=true,objectiveTrackerCustomBars=true,objectiveTrackerTextColor={.8,.8,.8,1}}
local wrapper
local sandbox=setmetatable({_G={ScenarioObjectiveTracker={BottomWidgetContainerBlock={WidgetContainer=container}}},
 ns={SafeCall=function(_,fn,...)return pcall(fn,...)end},GetSettings=function()return settings end,
 GetFontPath=function()return "QUIFont.ttf"end,GetFontFlags=function()return ""end,
 CJKFont=function(t,p,z,flags)t:SetFont(p,z,flags)end,SafeSetTextColor=function(t,c)t:SetTextColor(unpack(c))end,
 CUSTOM_BAR_FILL_TEXTURE="plain",Helpers={IsSecretValue=function()return false end,ApplyBarStyle=function(bar,path)bar.texture=path end},
 SkinBase={GetFrameData=function(fr,k)return data[fr]and data[fr][k]end,SetFrameData=function(fr,k,v)data[fr]=data[fr]or{};data[fr][k]=v end},
 StyleTrackerProgressBar=function(pb,preserve)assert(preserve and pb.Bar==widget.Bar);assert(not wrapper or wrapper==pb);wrapper=pb;pb.Bar.quiBorder=true end,
 hooksecurefunc=function(fr,method,fn)assert(method=="Setup");assert(not hooks[fr]);hooks[fr]=fn end}, {__index=_G})
local chunk=assert(loadstring(s:sub(a+#marker,b-1).."\nreturn StyleScenarioStatusWidgets"));setfenv(chunk,sandbox)
local style=chunk();style();style()
assert(widget.Bar.quiBorder and widget.Bar.texture=="plain" and hooks[widget])
for health=81,70,-1 do
 widget.Bar.value=health;widget.Bar.Label:SetText(health.."%");widget.Bar.texture="native"
 widget.Bar.BorderLeft:SetAlpha(1);widget.LabelBG:SetAlpha(1);widget.Label:SetFont("native",16,"")
 hooks[widget](widget)
 assert(widget.Bar.texture=="plain" and widget.Bar.BorderLeft:GetAlpha()==0 and widget.LabelBG:GetAlpha()==0)
 assert(widget.Label:GetFont()=="QUIFont.ttf" and widget.Bar.Label:GetFont()=="QUIFont.ttf")
 assert(widget.Bar.value==health and widget.Bar.Label:GetText()==health.."%" and widget.Bar.color=="green")
 assert(widget.Bar:GetWidth()==215 and widget.Bar:GetHeight()==15)
end
container.widgetFrames={};widget.Bar.BorderLeft:SetAlpha(1);hooks[widget](widget)
assert(widget.Bar.BorderLeft:GetAlpha()==1,"released widget must remain untouched")
container.widgetFrames={[7997]=widget};widget:SetParent(env.NewFrame("Frame"));hooks[widget](widget)
assert(widget.Bar.BorderLeft:GetAlpha()==1,"widgets reused elsewhere must remain untouched")
widget:SetParent(container);settings.objectiveTrackerCustomBars=false;style()
assert(widget.Bar.BorderLeft:GetAlpha()==1,"custom bar switch must be respected")
print("OK: objective_tracker_status_widget_test")
