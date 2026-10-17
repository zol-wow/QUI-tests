local f=assert(io.open("modules/layout/layoutmode_settings.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("local function UpdatePanelScroll(",1,true))
local b=assert(source:find("local function CreatePanel(",a,true))
local screen=800
local env=setmetatable({TITLE_HEIGHT=32,CONTENT_PADDING=8,PANEL_HEIGHT=650,
 SafeGetVerticalScroll=function(scroll)return scroll.value end,
 UIParent={GetHeight=function()return screen end}},{__index=_G})
local chunk=assert(loadstring(source:sub(a,b-1).."\nreturn FitPanelToContent"));setfenv(chunk,env)
local fit=chunk()
local height,content,scale=650,220,1
local panel={_content={GetHeight=function()return content end},
 GetScale=function()return scale end,GetHeight=function()return height end,SetHeight=function(_,h)height=h end}
fit(panel);assert(height==268,"short settings should reclaim empty panel space")
content=900;fit(panel);assert(height==650,"long providers should retain bounded scrolling")
content=120;fit(panel);assert(height==180,"collapsed details should shrink the panel to a usable minimum")
content=900;screen=500;fit(panel);assert(height==484,"panel must fit the available screen")
scale=1.25;fit(panel);assert(height==384,"screen bounds must account for configuration scale")
print("OK: layoutmode_settings_content_height_test")

local shown, scrollValue = true, 200
panel._scrollFrame = {
 value = scrollValue,
 GetHeight = function()return height - 48 end,
 SetVerticalScroll = function(self,v) self.value=v end,
 ScrollBar = {SetShown=function(_,v)shown=v end},
}
screen,scale,content = 800,1,220
fit(panel)
assert(not shown and panel._scrollFrame.value == 0, "short panels must hide the scrollbar and reset stale scroll")
content = 900; fit(panel)
assert(shown, "overflow must show the scrollbar")
content = 220; fit(panel)
assert(not shown, "switching from long to short content must hide the scrollbar again")
