local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinFlightMap=true
local function frame(parent) return env.NewFrame("Frame",nil,parent) end
local map=frame();_G.FlightMapFrame=map
map.BorderFrame=frame(map);local border=map.BorderFrame;border:SetFrameLevel(10)
border.TitleContainer=frame(border);border.TitleContainer.TitleText=border.TitleContainer:CreateFontString()
local title=border.TitleContainer.TitleText;title:SetFont("Native title",12,"");title:SetTextColor(1,.82,0,1)
border.Bg=border:CreateTexture();border.TopTileStreaks=border:CreateTexture()
border.TopBorder=border:CreateTexture();border.TopBorder:SetAtlas("AdventureMap_TopBorder")
border.CloseButton=env.NewFrame("Button",nil,border);border.CloseButton.RegisterForWidgetSet=false;border.CloseButton.DisabledTexture=false
map.ScrollContainer=frame(map);local canvas=map.ScrollContainer:CreateTexture();canvas:SetTexture("native-map")
local pin=frame(map.ScrollContainer);pin.Icon=pin:CreateTexture();pin.Icon:SetAtlas("native-flight-node")
local close=function() error("native close action invoked") end;border.CloseButton:SetScript("OnClick",close)
function border:SetTitle(text) title:SetText(text) end
function border:SetPortraitToAsset(asset) self.portraitAsset=asset end
_G.FLIGHT_MAP="Native Flight Map";_G.UIPanelWindows={}
_G.FlightMapMixin={}
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_FlightMap/Blizzard_FlightMap.lua"));local native=f:read("*a");f:close()
for _,key in ipairs({"SetupTitle","ResetTitleAndPortraitIcon","UpdateTitleAndPortraitIcon","OnShow","OnHide","OnEvent"}) do
 assert(loadstring(assert(native:match("(function FlightMapMixin:"..key.."%b().-\nend)"))))()
 map[key]=_G.FlightMapMixin[key]
end
local shown,hidden,events,closed,sounds,zoom=0,0,0,0,0,0
_G.MapCanvasMixin={OnShow=function() shown=shown+1 end,OnHide=function() hidden=hidden+1 end,OnEvent=function() events=events+1 end}
_G.GetTaxiMapID=function() return 123 end
_G.CloseTaxiMap=function() closed=closed+1 end
_G.C_Map={GetPlayerMapPosition=function() return nil end}
_G.SOUNDKIT={IG_MAINMENU_OPEN=1,IG_MAINMENU_CLOSE=2};_G.PlaySound=function() sounds=sounds+1 end
_G.HideUIPanel=function(owner) assert(owner==map);owner:Hide() end
function map:SetMapID(id) self.mapID=id end
function map:ResetZoom() zoom=zoom+1 end
map:SetupTitle()
local callbacks={};local refresh
skin.OnAddOnLoaded=function(name,fn) callbacks[name]=fn end
ns.Registry={Register=function(_,key,spec) if key=="skinFlightMap" then refresh=spec.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/worldmap.lua"))("QUI",ns)
callbacks.Blizzard_FlightMap()
assert(title:GetFont()==ns.Helpers.GetGeneralFont(),"flight map title must match QUI typography")
local _,size=title:GetFont()
assert(size==13 and title.textColor[1]==.92 and title:GetText()=="Native Flight Map","flight title must match World Map chrome without changing text")
map:OnShow()
assert(map.mapID==123 and zoom==1 and shown==1 and sounds==1,"native show must retain map ID and reset zoom branch")
local pans=0
_G.C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .4,.6 end} end
_G.C_Map.GetMapInfoAtPosition=function() return {mapID=456,flags=7} end
_G.FlagsUtil={IsSet=function(flags,flag) assert(flags==7 and flag==7);return true end}
_G.Enum={UIMapFlag={FlightMapAutoZoom=7}}
_G.MapUtil={GetMapCenterOnMap=function(child,parent) assert(child==456 and parent==123);return .3,.7 end}
function map:GetScaleForMaxZoom() return 2 end
function map:InstantPanAndZoom(scale,x,y,ignore) assert(scale==2 and x==.3 and y==.7 and ignore);pans=pans+1 end
map:OnShow()
assert(pans==1 and zoom==1 and shown==2,"native autozoom branch must retain child-map center and maximum scale")
map:UpdateTitleAndPortraitIcon("Native zone","native-portrait")
title:SetFontObject("Native rebound")
assert(title:GetFont()==ns.Helpers.GetGeneralFont() and title:GetText()=="Native zone"
 and border.portraitAsset=="native-portrait","native title/portrait updates must remain with durable typography")
refresh()
assert(canvas.texture=="native-map" and canvas:GetAlpha()==1 and pin.Icon.atlas=="native-flight-node"
 and border.CloseButton:GetScript("OnClick")==close and shown==2 and zoom==1 and pans==1,
 "theme must preserve canvas art, pin art and close ownership without map navigation")
map:OnEvent("TAXIMAP_CLOSED")
assert(not map:IsShown() and events==1,"native taxi-close event must retain panel hide and canvas event dispatch")
map:OnHide()
assert(closed==1 and hidden==1 and sounds==3,"native hide must retain taxi cleanup and sound once")
refresh()
assert(not map:IsShown() and closed==1 and hidden==1,"theme must leave native hidden state and taxi cleanup unchanged")
border.TitleContainer.IsForbidden=function() return true end
title:SetFont("Forbidden title",12,"");refresh()
assert(title:GetFont()=="Forbidden title","forbidden title container must stop title styling")
print("flight map title lifecycle passed")
