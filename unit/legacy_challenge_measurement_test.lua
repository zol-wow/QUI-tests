local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local corpus="tests/clients/forever/framexml/Interface/AddOns/"
_G.CreateFromMixins=function(...) local t={} for _,m in ipairs({...}) do for k,v in pairs(m) do t[k]=v end end return t end
_G.AchievementTemplateMixin={GetMaxCollapsedLines=function() return 2 end}
_G.ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT=122;_G.ACHIEVEMENTBUTTON_DESCRIPTIONHEIGHT=20
assert(loadfile(corpus.."Blizzard_LegacySystem/Blizzard_LegacyChallengeButton.lua"))()
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);root.ChallengesPage=page
local detail=env.NewFrame("Frame",nil,page);page.DetailPane=detail;detail.RegisterForWidgetSet=false
detail.buttonMixin=_G.LegacyChallengeTemplateMixin;detail.collapsedHeight=122
local box=env.NewFrame("Frame",nil,detail);detail.ScrollBox=box;box.RegisterForWidgetSet=false
local placeholder=root:CreateFontString()
local originalFont={name="Original",size=12}
function placeholder:SetFontObject(font)
    self.fontObject=font
    if type(font)=="string" then self:SetFont("NativeLegacy",12,"")
    else self:SetFont(font.name,font.size,"") end
end
function placeholder:GetFontObject() return self.fontObject end
function placeholder:GetHeight()
    local height=({["QUIFont.ttf"]=48,["AlternateQUI.ttf"]=60})[self.font]
    if height then return self:GetWidth()==400 and height or height+36 end
    return 24
end
placeholder:SetWidth(330)
placeholder:SetFontObject(originalFont)
_G.AchievementFrame={PlaceholderHiddenDescription=placeholder}
local criteria=0
_G.GetAchievementInfo=function(category,index) return index,"Name",10,false,10,9,26,"Long description" end
_G.GetAchievementNumCriteria=function() return criteria end
_G.LegacyChallengeObjectives={CalculateHeight=_G.LegacyChallengeObjectivesMixin.CalculateHeight}
_G.SelectionBehaviorMixin={IsElementDataIntrusiveSelected=function(data) return data.selected end}
_G.qLegacyTestDetail=detail
local achievement=read(corpus.."Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua")
local nativeCalculator=assert(loadstring("local self=_G.qLegacyTestDetail\nlocal buttonMixin=self.buttonMixin\nreturn "..
    assert(achievement:match("view:SetElementExtentCalculator%((function%b().-\n\tend)%)"))))()
local view={dataProvider={id=1},clears=0}
local linear=read(corpus.."Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua")
_G.ScrollBoxListLinearViewMixin={}
for _,method in ipairs({"SetElementExtentCalculator","GetElementExtentCalculator"}) do
    assert(loadstring(assert(linear:match("(function ScrollBoxListLinearViewMixin:"..method.."%b().-\nend)"))))()
    view[method]=_G.ScrollBoxListLinearViewMixin[method]
end
function view:ClearElementExtentData() self.clears=self.clears+1 end
function view:GetDataProvider() return self.dataProvider end
view:SetElementExtentCalculator(nativeCalculator)
function box:GetView() return view end
local scroll=read(corpus.."Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua")
_G.ScrollBoxListMixin={}
assert(loadstring(assert(scroll:match("(function ScrollBoxListMixin:Rebuild%b().-\nend)"))))()
box.Rebuild=_G.ScrollBoxListMixin.Rebuild
local rebuilds=0
function box:SetDataProvider(provider,retain) rebuilds=rebuilds+1;self.provider=provider;self.retained=retain end
assert(nativeCalculator(1,{category=99,index=1,selected=true})==122,
    "bounded native font metrics must expose unstyled extent mismatch")
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local wrapper=view:GetElementExtentCalculator()
assert(wrapper~=nativeCalculator and wrapper(1,{category=99,index=1,selected=true})==150,
    "Legacy extent measurement must use QUI typography inside the native calculation")
assert(placeholder.font=="Original" and placeholder.fontObject==originalFont and placeholder:GetWidth()==330
    and skin.GetFrameData(placeholder,"qLegacyMeasurementContext")==nil,
    "shared placeholder font and measurement context must be restored")
assert(rebuilds==1 and box.provider==view.dataProvider and box.retained,
    "native rebuild must preserve data-provider identity and scroll position")
assert(wrapper(1,{category=99,index=1,selected=false})==122,
    "native collapsed row extent must remain")
criteria=3
assert(wrapper(1,{category=99,index=1,selected=true})==215,
    "native criteria height and expanded description adjustment must remain")
placeholder:SetFontObject("SystemFont_Shadow_Med1")
assert(placeholder.font=="NativeLegacy","unrelated shared placeholder setters must remain native")
placeholder:SetFontObject(originalFont)
registry.skinLegacySystem.refresh()
assert(view:GetElementExtentCalculator()==wrapper and rebuilds==2 and view.clears==3,
    "theme must reuse wrapper, invalidate native extent cache and rebuild with retained position")
criteria=0;ns.Helpers.GetGeneralFont=function() return "AlternateQUI.ttf" end
registry.skinLegacySystem.refresh()
assert(view:GetElementExtentCalculator()==wrapper and wrapper(1,{category=99,index=1,selected=true})==162
    and placeholder.font=="Original" and placeholder:GetWidth()==330 and box.retained,
    "theme font changes must invalidate extents and use current QUI font without leaking placeholder changes")
ns.Helpers.GetGeneralFont=function() return "QUIFont.ttf" end
env.profile.general.skinLegacySystem=false;criteria=0
assert(wrapper(1,{category=99,index=1,selected=true})==122 and placeholder.font=="Original",
    "disabled skin must delegate to native typography and restore placeholder")
env.profile.general.skinLegacySystem=true;detail.IsForbidden=function() return true end
assert(wrapper(1,{category=99,index=1,selected=true})==122,"forbidden owner must bypass font override")
detail.IsForbidden=function() return false end
view:SetElementExtentCalculator(function()
    placeholder:SetFontObject("SystemFont_Shadow_Med1");error("native measurement failure",0)
end)
registry.skinLegacySystem.refresh()
local ok,err=pcall(view:GetElementExtentCalculator(),1,{selected=true})
assert(not ok and err=="native measurement failure" and placeholder.font=="Original"
    and placeholder.fontObject==originalFont and placeholder:GetWidth()==330
    and skin.GetFrameData(placeholder,"qLegacyMeasurementContext")==nil,
    "native error must propagate with shared font/context restored")
print("Legacy native long-description extent typography and restoration passed")
