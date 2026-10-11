local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local f=assert(io.open(os.getenv("QUI_OBJECTIVE_SOURCE") or "modules/skinning/gameplay/objectivetracker.lua"));local s=f:read("*a");f:close()
local marker="-- <<< QUI_TEST_EXTRACT scenario_header_widget"
local a=assert(s:find(marker,1,true),"stage UIWidget skin missing")
local b=assert(s:find(marker,a+#marker,true))
local container=env.NewFrame("Frame")
local w=env.NewFrame("Frame");w:SetParent(container);w:SetSize(240,70);w:Show()
for _,k in ipairs({"Frame","ThemeOverlay","DecorationBottomLeft"})do w[k]=w:CreateTexture()end
w.HeaderText=w:CreateFontString();w.HeaderText:SetText("Deliver Sacrificial Offerings")
w.Timer=env.NewFrame("Frame");w.Timer.Text=w:CreateFontString();w.Timer.Text:SetText("05:00")
w.TimerBar=env.NewFrame("StatusBar");w.TimerBar:SetSize(240,9);w.TimerBar.value=300
w.Setup=function()end
container.widgetFrames={[7]=w};container.widgetPools=setmetatable({}, {__index=function()error("must not mutate widget pool")end})
local settings={skinObjectiveTracker=true,objectiveTrackerCustomBars=true,objectiveTrackerModuleFontSize=12,
 objectiveTrackerTitleColor={1,1,1,1},objectiveTrackerTextColor={.8,.8,.8,1}}
local timers,hooks,data={},{},{}
local sandbox=setmetatable({ns={SafeCall=function(_,fn,...)return pcall(fn,...)end},_G={ScenarioObjectiveTracker={StageBlock={WidgetContainer=container}}},
 CUSTOM_BAR_FILL_TEXTURE="Interface\\Buttons\\WHITE8x8",
 StyleTrackerProgressBar=function(pb)assert(pb.Bar==w.TimerBar);pb.Bar.quiBorder=true end,
 GetSettings=function()return settings end,GetFontPath=function()return "QUIFont.ttf"end,GetFontFlags=function()return ""end,
 CJKFont=function(t,p,z,flags)t:SetFont(p,z,flags)end,SafeSetTextColor=function(t,c)t:SetTextColor(unpack(c))end,
 Helpers={IsSecretValue=function()return false end,ApplyBarStyle=function(bar,path)bar.texture=path end},
 SkinBase={GetFrameData=function(fr,k)return data[fr] and data[fr][k]end,
 SetFrameData=function(fr,k,v)data[fr]=data[fr]or{};data[fr][k]=v end},
 hooksecurefunc=function(fr,method,fn)assert(method=="Setup");hooks[fr]=fn end,
 CreateDeferredStyleQueue=function(handler)return function(fr)timers[#timers+1]=function()handler(fr)end end end}, {__index=_G})
local chunk=assert(loadstring(s:sub(a+#marker,b-1).."\nreturn StyleScenarioHeaderWidgets"));setfenv(chunk,sandbox)
local style=chunk();style()
assert(w.Frame:GetAlpha()==0 and w.ThemeOverlay:GetAlpha()==0 and w.DecorationBottomLeft:GetAlpha()==0)
assert(w.HeaderText:GetFont()=="QUIFont.ttf" and w.Timer.Text:GetFont()=="QUIFont.ttf")
assert(w.HeaderText:GetText()=="Deliver Sacrificial Offerings" and w.Timer.Text:GetText()=="05:00")
assert(w:GetWidth()==240 and w:GetHeight()==70 and w.TimerBar:GetHeight()==9 and w.TimerBar.value==300)
assert(w.TimerBar.quiBorder and w.TimerBar.texture=="Interface\\Buttons\\WHITE8x8" and hooks[w])
-- Native Setup restores the header font and bar atlas on every timer tick.
-- They must be restored before this same frame renders, without a timer queue.
for remaining=299,290,-1 do
 w.HeaderText:SetFont("BlizzardFont.ttf",16,"")
 w.TimerBar.texture="midnight-scenario-barfill"
 w.TimerBar.value=remaining;w.Timer.Text:SetText(tostring(remaining))
 hooks[w](w)
 assert(w.HeaderText:GetFont()=="QUIFont.ttf","timer tick must not expose the native font for one frame")
 assert(w.TimerBar.texture=="Interface\\Buttons\\WHITE8x8","timer tick must not expose native bar art for one frame")
 assert(w.TimerBar.value==remaining and w.Timer.Text:GetText()==tostring(remaining),"native countdown must continue")
 assert(#timers==0,"timer appearance must not wait until the next frame")
end
local managerFile=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_UIWidgets/Blizzard_UIWidgetManager.lua"));local managerSource=managerFile:read("*a");managerFile:close()
local addChild=assert(managerSource:match("function UIWidgetHorizontalWidgetContainerMixin:AddChildWidget%(widgetFrame%)(.-)\nend"))
local add=assert(loadstring("return function(self,widgetFrame)"..addChild.."\nend"))()
local row=env.NewFrame("Frame");row:SetParent(container);row.parentWidgetContainer=container;row.childWidgets={}
add(row,w)
w.HeaderText:SetFont("BlizzardFont.ttf",16,"")
w.TimerBar.texture="midnight-scenario-barfill"
hooks[w](w)
assert(w.HeaderText:GetFont()=="QUIFont.ttf","active native horizontal stage widget must retain configured font after Setup")
assert(w.TimerBar.texture=="Interface\\Buttons\\WHITE8x8","active native horizontal stage widget must retain configured bar after Setup")
w:SetParent(container)
-- A skinning error must not abort the surrounding native widget update.
local applyBarStyle=sandbox.Helpers.ApplyBarStyle
sandbox.Helpers.ApplyBarStyle=function()error("appearance failure")end
assert(pcall(hooks[w],w),"post-hook must isolate appearance errors")
sandbox.Helpers.ApplyBarStyle=applyBarStyle
w.Frame:SetAlpha(1);container.widgetFrames={};hooks[w](w);assert(w.Frame:GetAlpha()==1,"released widget must remain untouched")
container.widgetFrames={[7]=w};w:SetParent(env.NewFrame("Frame"));style();assert(w.Frame:GetAlpha()==1,"reused widget in another container must remain untouched")
w:SetParent(container);settings.skinObjectiveTracker=false;style();assert(w.Frame:GetAlpha()==1)
print("OK: objective_tracker_scenario_widget_test")
