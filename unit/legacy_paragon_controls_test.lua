local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXML/RewardTrackTemplates.lua"))()
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyRewardTrack.lua"))()
_G.tinsert=table.insert
_G.InputUtil={IsGamepadUIEnabled=function() return false end,IsMKBUIEnabled=function() return true end}
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);page.RegisterForWidgetSet=false;root.RewardTrackPage=page
for key,fn in pairs(_G.LegacyRewardTrackPageMixin) do page[key]=fn end
page.LegacyRewardProgressBar=false
local track=env.NewFrame("Frame",nil,page);track.RegisterForWidgetSet=false;page.LegacyRewardProgressFrame=track
for _,key in ipairs({"Init","GetElements","SetCenteringEnabled"}) do track[key]=_G.RewardTrackFrameMixin[key] end
track.elementSpacing=-2
for _,key in ipairs({"LeftButton","RightButton","JumpLeftButton","JumpRightButton"}) do
    track[key]=env.NewFrame("Button",nil,track);track[key].RegisterForWidgetSet=false;track[key].DisabledTexture=false
end
local clip=env.NewFrame("Frame",nil,track);track.ClipFrame=clip;clip.Mask=false;clip.clipsChildren=true
local paragon=env.NewFrame("Frame",nil,clip);paragon.RegisterForWidgetSet=false;clip.ParagonLevelFrame=paragon
paragon:SetSize(200,50);paragon:Hide()
for _,key in ipairs({"Divider","LabelBackground","Icon","IconBorder","LevelFrame","HighlightTexture"}) do
    local tex=paragon:CreateTexture();paragon[key]=tex;tex.masks={}
    function tex:AddMaskTexture(mask) self.masks[mask]=true end
end
paragon.LabelBackground:SetAtlas("ui-journeys-paragon-level-bar");paragon.LabelBackground:SetSize(200,50)
paragon.LabelBackground:SetPoint("LEFT",paragon.Divider,"RIGHT",0,0)
paragon.Divider:SetAtlas("ui-journeys-paragon-level-divider")
paragon.Icon:SetSize(40,40);paragon.Icon:SetTexCoord(.1,.9,.2,.8)
paragon.IconBorder:SetSize(55,55);paragon.IconBorder:SetAtlas("ui-journeys-delve-rewardicon-square-frame")
paragon.LevelFrame:SetSize(36,36);paragon.LevelFrame:SetAtlas("ui-journeys-paragon-level-frame")
paragon.HighlightTexture:SetSize(40,40)
function paragon:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
paragon.Label=paragon:CreateFontString();paragon.Label:SetText("Max renown");paragon.Label:SetSize(105,35)
paragon.Level=paragon:CreateFontString();paragon.Level:SetTextColor(1,.8,0,1)
local active,free,made={},{},0
track.elementPool={}
function track.elementPool:ReleaseAll()
    for _,b in ipairs(active) do b:Hide();b:ClearAllPoints();free[#free+1]=b end;active={}
end
function track.elementPool:Acquire()
    local b=table.remove(free)
    if not b then
        made=made+1;b=env.NewFrame("Frame",nil,clip);b.RegisterForWidgetSet=false
        function b:SetInfo(info) self.info=info end
        function b:SetMouseClickEnabled(v) self.clickEnabled=v end
    end
    active[#active+1]=b;return b
end
local locked=false
local levels={{level=1,locked=false},{level=2,locked=false}}
local providerCalls=0
_G.C_MajorFactions={
    GetRenownLevels=function() providerCalls=providerCalls+1;levels[2].locked=locked;return levels end,
    GetRenownRewardsForLevel=function(_,level) return {{icon=100+level,name="Regular "..level}} end,
}
local reward={icon=999,name="Paragon reward",description="Native reward description",isWarbandItem=true}
page.majorFactionData={factionID=1,maxLevel=2,paragonInfo={level=7,rewardInfo=reward}}
_G.RENOWN_REWARD_ACCOUNT_UNLOCK_LABEL="Warband";_G.ACCOUNT_WIDE_FONT_COLOR={}
_G.GameTooltip={SetOwner=function(self,owner,anchor) self.owner=owner;self.anchor=anchor;self.lines={} end,
    GetOwner=function(self) return self.owner end,Show=function(self) self.shown=true end}
_G.GameTooltip_SetTitle=function(tooltip,text) tooltip.title=text end
_G.GameTooltip_AddColoredLine=function(tooltip,text) tooltip.lines[#tooltip.lines+1]=text end
_G.GameTooltip_AddBlankLineToTooltip=function(tooltip) tooltip.lines[#tooltip.lines+1]="" end
_G.GameTooltip_AddNormalLine=function(tooltip,text) tooltip.lines[#tooltip.lines+1]=text end
_G.GameTooltip_Hide=function() _G.GameTooltip.shown=false end
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
page:SetupRewardTrack()
local chrome=skin.GetBackdrop(paragon)
local iconBorder=skin.GetFrameData(paragon.Icon,"iconBorder")
local levelBorder=skin.GetFrameData(paragon.LevelFrame,"iconBorder")
assert(chrome and chrome._quiRoundedSurface and iconBorder and iconBorder._quiRoundedSurface
    and levelBorder and levelBorder._quiRoundedSurface and paragon.LabelBackground:GetAlpha()==0
    and paragon.IconBorder:GetAlpha()==0 and paragon.Divider:GetAlpha()==0,
    "Legacy paragon label, reward icon and level badge must receive rounded QUI chrome")
assert(paragon:IsShown() and paragon.info==reward and paragon.Level:GetText()==9 and paragon.Icon.texture==999
    and paragon:GetWidth()==200 and paragon:GetHeight()==50 and paragon.Icon:GetWidth()==40
    and paragon.Icon.texCoord[1]==.1 and paragon.Level.textColor[2]==.8
    and chrome.points[1][2]==paragon.LabelBackground and chrome.points[2][2]==paragon.LabelBackground
    and paragon.points[#paragon.points][2]==track.Elements[2] and paragon.points[#paragon.points][4]==15,
    "native paragon eligibility/data/level/icon/geometry/last-card anchor must remain")
assert(track.disableCentering and not track.LeftButton:IsShown() and not track.Elements[1].clickEnabled,
    "native static track layout and card click exclusion must remain")
paragon:Fire("OnEnter")
assert(GameTooltip.shown and GameTooltip.owner==paragon and GameTooltip.anchor=="ANCHOR_RIGHT"
    and GameTooltip.title=="Paragon reward" and GameTooltip.lines[1]=="Warband"
    and GameTooltip.lines[3]=="Native reward description","native reward/warband tooltip must remain")
GameTooltip.owner=root;paragon:Fire("OnLeave");assert(GameTooltip.shown,"native leave must retain a foreign-owned tooltip")
GameTooltip.owner=paragon;paragon:Fire("OnLeave");assert(not GameTooltip.shown,"native owned tooltip must hide")
locked=true;page:SetupRewardTrack()
assert(not paragon:IsShown() and #paragon.points==0 and made==2,
    "native locked final level must hide/unanchor paragon while reusing card pool")
locked=nil;page:SetupRewardTrack();assert(not paragon:IsShown(),"native nil lock must not satisfy explicit false eligibility")
locked=false;page.majorFactionData.paragonInfo=nil;page:SetupRewardTrack()
assert(not paragon:IsShown(),"missing paragon provider must hide variant")
page.majorFactionData.paragonInfo={level=3,rewardInfo={icon=777,name="Reused reward",description="Reused",isWarbandItem=false}}
track:Init(levels,page.majorFactionData.paragonInfo)
assert(paragon:IsShown() and paragon.Level:GetText()==5 and paragon.Icon.texture==777
    and paragon.HighlightTexture.color[4]==.08 and next(paragon.HighlightTexture.masks)
    and skin.GetBackdrop(paragon)==chrome and made==2,
    "native direct Init reuse must reapply bounded hover chrome and update art/level without allocation")
paragon:Fire("OnEnter");assert(GameTooltip.title=="Reused reward" and #GameTooltip.lines==2,
    "reused native tooltip must drop warband line")
local before=providerCalls
registry.skinLegacySystem.refresh()
assert(providerCalls==before and skin.GetBackdrop(paragon)==chrome
    and skin.GetFrameData(paragon.Icon,"iconBorder")==iconBorder,"theme must cache chrome without provider calls")
env.profile.general.skinLegacySystem=false;paragon.Label:SetFont("Native",12,"")
track:Init(levels,page.majorFactionData.paragonInfo)
assert(paragon.Label.font=="Native" and paragon:IsShown(),"disabled variant must retain native updates without font override")
env.profile.general.skinLegacySystem=true;paragon.IsForbidden=function() return true end
track:Init(levels,page.majorFactionData.paragonInfo);assert(paragon.Label.font=="Native","forbidden paragon must be excluded")
print("Legacy native paragon eligibility, pooled rebuild and tooltip passed")
