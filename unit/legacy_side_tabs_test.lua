local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
ns.SafeCall=function(_,fn,...) return fn(...) end
local px=1
skin.GetPixelSize=function() return px end
local function Read(path)
    local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local corpus="tests/clients/forever/framexml/Interface/AddOns/"
local shared=Read(corpus.."Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua")
_G.SidePanelTabButtonMixin={}
for name,sep in shared:gmatch("function SidePanelTabButtonMixin([:.])([%w_]+)") do
    local signature="SidePanelTabButtonMixin"..name..sep
    assert(loadstring(assert(shared:match("(function "..signature.."%b().-\nend)"))))()
end
local camelot=Read(corpus.."Blizzard_SharedXML/Camelot/SharedUIPanelTemplates.lua")
assert(loadstring(assert(camelot:match("(function SidePanelTabButtonMixin:GetIconAnchorOffsetsForTabArt%b().-\nend)"))))()
local native=Read(corpus.."Blizzard_LegacySystem/Blizzard_LegacySystem.lua")
_G.LegacySystemFrameTabMixin={};_G.LegacySystemFrameMixin={}
for _,signature in ipairs({"LegacySystemFrameTabMixin:OnLoad","LegacySystemFrameMixin:SelectPage"}) do
    assert(loadstring(assert(native:match("(function "..signature.."%b().-\nend)"))))()
end
_G.C_Texture={GetAtlasInfo=function(atlas) assert(atlas=="common-sidetab");return {width=72,height=65} end}
_G.SOUNDKIT={IG_CHARACTER_INFO_TAB=1}
local sounds,events=0,0
_G.PlaySound=function(id) assert(id==1);sounds=sounds+1 end
local tooltip={}
function tooltip:SetOwner(owner,anchor,x,y) self.owner=owner;assert(anchor=="ANCHOR_RIGHT" and x==-4 and y==-4) end
function tooltip:SetText(text) self.text=text end
function tooltip:Show() self.shown=true end
function tooltip:Hide() self.shown=false end
_G.GetAppropriateTooltip=function() return tooltip end
local root=env.NewFrame("Frame");root.CloseButton=false;root.Pages={};root.Tabs={}
_G.LegacySystemFrame=root
root.SelectPage=_G.LegacySystemFrameMixin.SelectPage
_G.EventRegistry={TriggerEvent=function(_,event,id)
    assert(event=="Legacy.SelectPage");events=events+1;root:SelectPage(id)
end}
for i=1,3 do
    root.Pages[i]=env.NewFrame("Frame",nil,root)
    root.Pages[i].RegisterForWidgetSet=false
    local tab=env.NewFrame("Frame",nil,root);tab.RegisterForWidgetSet=false;root.Tabs[i]=tab
    for name,fn in pairs(_G.SidePanelTabButtonMixin) do tab[name]=fn end
    tab.OnLoad=_G.LegacySystemFrameTabMixin.OnLoad
    function tab:GetID() return i end
    tab.iconTexture="NativeIcon"..i;tab.tooltipText="NativeTab"..i;tab.fillToInterior=true
    for _,key in ipairs({"Background","Icon","SelectedTexture","HighlightTexture","TabGlow","Mask"}) do
        tab[key]=tab:CreateTexture();tab[key]:SetAtlas("Native-"..key)
    end
    tab.TabGlow:SetAlpha(0)
    tab.Icon.masks={[tab.Mask]=true}
    tab.TabGlowAnimation={SetPlaying=function(self,value) self.playing=value end,
        IsPlaying=function(self) return self.playing end}
    tab:OnLoad()
    tab:SetPoint("TOPLEFT",i==1 and root or root.Tabs[i-1],i==1 and "TOPRIGHT" or "BOTTOMLEFT",0,i==1 and -60 or -2)
end
root:SelectPage(1)
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local markers={}
assert(root.Tabs[1].TabGlow:IsShown() and root.Tabs[1].TabGlow:GetAlpha()==0,
    "side-tab glow texture must remain available to its native animation controller")
for i,tab in ipairs(root.Tabs) do
    assert(tab.Icon:GetAlpha()==1 and tab.Icon.texture=="NativeIcon"..i,
        "Legacy side-tab icons must remain visible through tab styling")
    assert(tab:GetWidth()==72 and tab:GetHeight()==60 and tab.Icon:GetWidth()==50
        and tab.Icon.texCoord[1]==.03125 and tab.Icon.masks[tab.Mask],
        "native tab size, icon interior coordinates and mask must survive")
    assert(tab.points[1][2]==(i==1 and root or root.Tabs[i-1]) and tab.points[1][5]==(i==1 and -60 or -2),
        "native vertical stacking anchors must survive")
    assert(tab.Background:GetAlpha()==0 and tab.SelectedTexture:GetAlpha()==0
        and tab.SelectedTexture:IsShown()==(i==1),"native checked visibility must remain authoritative")
    local chrome=skin.GetBackdrop(tab)
    assert(chrome and chrome:GetFrameLevel()<tab:GetFrameLevel(),"tab chrome must sit behind native icon controls")
    local marker=skin.GetFrameData(tab,"qLegacySideTabMarker");markers[i]=marker
    assert(marker and marker:IsShown()==(i==1) and marker:GetWidth()==1,"only the selected tab needs an accent line")
end
local second=root.Tabs[2]
local handler=second.customMouseUpHandler
second:OnMouseDown("LeftButton")
local point=second.Icon.points[#second.Icon.points]
assert(point[2]==-3 and point[3]==-1,"native Camelot pressed icon offset must survive")
second:OnMouseUp("LeftButton",true)
point=second.Icon.points[#second.Icon.points]
assert(point[2]==-4 and point[3]==0 and events==1 and sounds==1
    and root.currentPage==2 and root.Pages[2]:IsShown() and not root.Pages[1]:IsShown(),
    "native left release must select the page and restore the icon offset")
for i,marker in ipairs(markers) do assert(marker:IsShown()==(i==2),"selection marker must track native SetChecked") end
second:OnMouseUp("RightButton",true);second:OnMouseUp("LeftButton",false)
assert(events==1 and second.customMouseUpHandler==handler,"right or outside release must retain native hit behavior")
second:OnEnter();assert(tooltip.owner==second and tooltip.text=="NativeTab2" and tooltip.shown)
second:OnLeave();assert(not tooltip.shown,"native tooltip leave must hide the tooltip")
local glow=second.TabGlow
glow:SetAlpha(.4)
assert(glow:GetAlpha()==.4, "native glow animation alpha must not be clamped by tab skinning")
second:SetTabGlowAnimationPlaying(true)
assert(second:IsTabGlowAnimationPlaying() and second.TabGlow==glow and glow.color[4]==.08,
    "glow texture and native animation controller must remain connected")
registry.skinLegacySystem.refresh()
assert(events==1 and skin.GetFrameData(second,"qLegacySideTabMarker")==markers[2]
    and second.Icon:GetAlpha()==1,"theme refresh must retain artwork and reuse the marker without changing pages")
px=2;registry.skinLegacySystem.refresh()
assert(markers[2]:GetWidth()==2,"selection line must follow pixel scale")
env.profile.general.skinLegacySystem=false
second:SetChecked(false);assert(markers[2]:IsShown(),"disabled skin callbacks must leave existing chrome alone")
env.profile.general.skinLegacySystem=true
second.IsForbidden=function() return true end
second:SetChecked(false);assert(markers[2]:IsShown(),"forbidden tab must not be restyled")
second.IsForbidden=function() return false end
second:SetParent(env.NewFrame("Frame"))
second:SetChecked(false);assert(markers[2]:IsShown(),"borrowed tab must not be restyled outside its Legacy owner")
print("OK: legacy_side_tabs_test")
