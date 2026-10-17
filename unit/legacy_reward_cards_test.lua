local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
ns.Helpers.GetSkinBorderColor=function() return .9,.1,.1,1 end
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXML/RewardTrackTemplates.lua"))()
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyRewardTrack.lua"))()
local function color(r,g,b) return {GetRGB=function() return r,g,b end} end
_G.NORMAL_FONT_COLOR=color(1,.8,0);_G.DISABLED_FONT_COLOR=color(.5,.5,.5)
_G.Enum={RenownRewardDisplayType={Item=1,Mount=2,Title=3,Currency=4}}
_G.TextureKitConstants={IgnoreAtlasSize=false,UseAtlasSize=true}
_G.GenerateClosure=function(fn,self) return function(...) return fn(self,...) end end
_G.RenownRewardUtil={GetRenownRewardInfo=function(info) return info.icon,info.name end}
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);page.RegisterForWidgetSet=false;root.RewardTrackPage=page
for key,method in pairs(_G.LegacyRewardTrackPageMixin) do page[key]=method end
page.actualLevel=2;page.displayLevel=2;page.renownLevelsInfo={1,2,3,4,5};page.LegacyRewardProgressBar=false
local details=0;function page:SetupProgressDetails() details=details+1 end
local track=env.NewFrame("Frame",nil,page);track.RegisterForWidgetSet=false;page.LegacyRewardProgressFrame=track
local clip=env.NewFrame("Frame",nil,track);track.ClipFrame=clip;clip.Mask=clip:CreateTexture();clip.clipsChildren=true
local elements={}
function track:GetElements() return elements end
function track:GetCenterIndex() return self.centerIndex end
function track:GetDesiredAlphaForIndex() return .6 end
track.centerIndex=1
local function card(level)
    local b=env.NewFrame("Frame",nil,clip);b.RegisterForWidgetSet=false;b:SetSize(216,241);b.index=#elements+1
    for key,method in pairs(_G.RenownLevelMixin) do b[key]=method end
    b.Textures={}
    b.masksCreated=0
    function b:CreateMaskTexture() self.masksCreated=self.masksCreated+1;return env.NewTexture(self,"MaskTexture") end
    for _,key in ipairs({"RewardCardBG","Icon","LevelSquare","EarnedCheckmark","IconBorder"}) do
        local t=b:CreateTexture();b[key]=t;b.Textures[#b.Textures+1]=t;t.masks={}
        function t:AddMaskTexture(mask) self.masks[mask]=true end
        function t:RemoveMaskTexture(mask) self.masks[mask]=nil end
        function t:GetAtlas() return self.atlas end
    end
    function b.Icon:SetDesaturated(v) self.desaturated=v end
    b.Icon:SetSize(64,64);b.Icon:SetTexCoord(.1,.9,.2,.8)
    b.IconBorder:SetSize(80,80);b.IconBorder:SetPoint("CENTER",b.Icon,"CENTER",0,0)
    b.LevelSquare:SetSize(40,40);b.LevelSquare:SetPoint("TOP",b,"TOP",0,18)
    b.Level=b:CreateFontString();b.RewardName=b:CreateFontString()
    b.lastEarnedBackgroundFrameAtlas="Legacy-Rewards-Tracker-Cards-Green"
    b.earnedBackgroundFrameAtlas="Legacy-Rewards-Tracker-Cards"
    b.backgroundFrameAtlas="Legacy-Rewards-Tracker-Cards-Disable"
    b.lastEarnedLevelSquareFrameAtlas="Legacy-Rewards-Tracker-Diamond"
    b.earnedLevelSquareFrameAtlas="Legacy-Rewards-Tracker-Diamond"
    b.levelSquareFrameAtlas="Legacy-Rewards-Tracker-Diamond-Disable"
    b.selectedIconBorderAtlas="Legacy-Rewards-Tracker-Icons-Frame"
    b.earnedIconBorderAtlas=b.selectedIconBorderAtlas;b.iconBorderAtlas="Legacy-Rewards-Tracker-Icons-Frame-Disable"
    b.earnedLevelColor=color(1,1,1);b.levelColor=_G.DISABLED_FONT_COLOR
    b.earnedRewardNameColor=b.earnedLevelColor;b.rewardNameColor=b.levelColor
    b:SetInfo({level=level,rewardInfo={{icon=100+level,name="Reward "..level,rewardType=1}}})
    b:Refresh(2,2,false);elements[#elements+1]=b;return b
end
local first,latest,future=card(1),card(2),card(3)
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local shell=skin.GetBackdrop(latest)
assert(shell and shell._quiRoundedSurface and latest.RewardCardBG:GetAlpha()==0,
    "legacy reward cards must receive rounded shells instead of native card backgrounds")
assert(shell._quiBorderG==.7 and latest.EarnedCheckmark:IsShown() and latest.Level.textColor[1]==1
    and future.Level.textColor[1]==.5 and future.Icon.desaturated,
    "latest earned green indicator, earned check and native earned/unearned colors must remain")
local iconBorder=skin.GetFrameData(latest.Icon,"iconBorder")
local levelBorder=skin.GetFrameData(latest.LevelSquare,"iconBorder")
assert(iconBorder and iconBorder._quiRoundedSurface and levelBorder and levelBorder._quiRoundedSurface
    and latest.IconBorder:GetAlpha()==0 and latest.LevelSquare.color,
    "reward icons and level badges must receive rounded chrome and suppress native decorative borders")
assert(latest.Icon.texCoord[1]==.1 and latest.Icon.texCoord[4]==.8 and latest.Icon:GetWidth()==64
    and latest.IconBorder:GetWidth()==80 and latest.LevelSquare:GetWidth()==40
    and latest.LevelSquare.points[1][5]==18,
    "native icon UVs and badge/nameplate anchor geometry must remain")
page:OnTrackUpdate(1,2,3,false)
assert(shell._quiBorderR==.9 and latest.RewardName:GetAlpha()==.6 and latest.RewardName:GetText()=="Reward 2"
    and latest.Icon.texture==102 and not latest.Icon.masks[clip.Mask] and details==1,
    "native track update must preserve selected border, alpha/text/art and temporary-mask removal")
assert(iconBorder._quiBorderR==.9 and levelBorder._quiBorderR==.9,
    "native selected refresh must update icon and badge borders")
page:OnTrackUpdate(1,2,3,true)
assert(shell._quiBorderG==.7 and skin.GetBackdrop(latest)==shell,
    "moving track must clear selection while retaining latest earned distinction")
assert(iconBorder._quiBorderG==.7 and levelBorder._quiBorderG==.7,
    "latest earned border must survive movement/deselection on both inner controls")
local maskCount=latest.masksCreated
future:SetInfo({level=4,rewardInfo={{icon=204,name="Reused",rewardType=4}}})
future:Refresh(2,2,false)
assert(future.Icon.texture==204 and future.RewardName:GetText()=="Reused" and future.Icon.desaturated
    and not future.EarnedCheckmark:IsShown() and skin.GetFrameData(future,"qLegacyRewardSelected")==false,
    "native card SetInfo/reuse must update art/name/earned state and clear stale selection")
local identity=latest.Textures[1];registry.skinLegacySystem.refresh()
assert(latest.RewardCardBG==identity and latest.RewardCardBG.atlas=="Legacy-Rewards-Tracker-Cards-Green"
    and latest:GetWidth()==216 and latest:GetHeight()==241 and clip.clipsChildren,
    "theme must preserve native texture registry, atlas, geometry and clip ownership")
assert(latest.masksCreated==maskCount and skin.GetFrameData(latest.Icon,"iconBorder")==iconBorder
    and skin.GetFrameData(latest.LevelSquare,"iconBorder")==levelBorder,
    "theme/reuse must cache inner borders and masks")
latest.IconBorder:SetAlpha(1)
assert(latest.IconBorder:GetAlpha()==0, "native decorative icon-border alpha reuse must remain suppressed")
env.profile.general.skinLegacySystem=false;latest.Level:SetFont("Native",12,"");latest:Refresh(2,2,true)
assert(latest.Level.font=="Native","disabled native reward refresh must stop font overrides")
env.profile.general.skinLegacySystem=true;clip.IsForbidden=function() return true end
latest:Refresh(2,2,false);assert(latest.Level.font=="Native","forbidden clip owner must stop reward overrides")
clip.IsForbidden=function() return false end;latest.parent=_G.UIParent
latest:Refresh(2,2,false);assert(latest.Level.font=="Native","borrowed reward card must retain its presentation")
assert(first.Level:GetText()==1,"native reward level must remain")
print("Legacy native reward card states and clip ownership passed")
