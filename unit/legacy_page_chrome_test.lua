local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
ns.Helpers.GetSkinBarColor=function() return .9,.1,.1,1 end
ns.SafeCall=function(_,fn,...) return fn(...) end
local pixel=1
skin.GetPixelSize=function() return pixel end
local f=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyChallenges.lua"))
local native=f:read("*a");f:close()
_G.LegacyChallengePointSummaryMixin={};_G.ChallengePointBarMixin={}
for mixin,methods in pairs({LegacyChallengePointSummaryMixin={"OnLoad","SetCurrencyInfo","RefreshText"},ChallengePointBarMixin={"Update","OnHide"}}) do
    for _,method in ipairs(methods) do
        assert(loadstring(assert(native:match("(function "..mixin..":"..method.."%b().-\nend)"))))()
    end
end
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local pages={}
for _,key in ipairs({"RewardTrackPage","ChallengesPage","TreePage"}) do
    local page=env.NewFrame("Frame",nil,root);page.RegisterForWidgetSet=false;root[key]=page;pages[#pages+1]=page
    page:SetSize(910,560);page.Background=page:CreateTexture();page.Background:SetAtlas("Native-"..key)
    if key~="RewardTrackPage" then
        page.VerticalDivider=env.NewFrame("Frame",nil,page);page.VerticalDivider:SetSize(12,503)
        page.VerticalDivider:SetPoint("TOPLEFT",page,"TOPLEFT",key=="TreePage" and 128 or 328,-72)
        page.VerticalDivider.Decoration=page.VerticalDivider:CreateTexture()
        page.VerticalDivider.Decoration:SetAtlas("Legacy-Tree-Frame-divider-Vertical")
    end
end
local summary=env.NewFrame("Frame",nil,root.ChallengesPage);summary.RegisterForWidgetSet=false
root.ChallengesPage.LegacyChallengePointSummary=summary;summary:SetSize(520,36)
for key,fn in pairs(_G.LegacyChallengePointSummaryMixin) do summary[key]=fn end
summary.ProgressBarBackground=summary:CreateTexture();summary.ProgressBarBackground:SetAtlas("Legacy-Progressbar-BG")
local bar=env.NewFrame("StatusBar",nil,summary);bar.RegisterForWidgetSet=false;summary.PointsBar=bar
bar:SetSize(526,13);bar.range={0,1};bar.value=0
for key,fn in pairs(_G.ChallengePointBarMixin) do bar[key]=fn end
local fill=bar:CreateTexture();fill:SetAtlas("Legacy-Progressbar-Fill");fill.masks={}
function fill:AddMaskTexture(mask) self.masks[mask]=true end
function bar:GetStatusBarTexture() return fill end
function bar:SetValue(value) self.value=value end
function bar:SetStatusBarColor(...) self.color={...} end
function bar:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
bar.ProgressBarFrame=bar:CreateTexture();bar.ProgressBarFrame:SetAtlas("Legacy-Progressbar-Frame")
bar.Text=bar:CreateFontString();bar.Text:SetTextColor(.9,.8,.7,1)
summary.Shield=env.NewFrame("Button",nil,summary);summary.Shield.RegisterForWidgetSet=false
summary.Shield.Icon=summary.Shield:CreateTexture();summary.Shield.Icon:SetAtlas("UI-Legacy-Points-icon-c60")
summary.Shield.Points=summary.Shield:CreateFontString()
local owner,callback
_G.LegacySystem={RegisterCurrencyInfoCallback=function(o,fn) owner=o;callback=fn end}
_G.LEGACY_POINTS_CURR_MAX="%d / %d"
local max=100;local providers=0
_G.C_Traits={GetMaxAvailableTraitCurrency=function(id,limit) assert(id==7 and limit==false);providers=providers+1;return max end}
local created=0;local latest
_G.InterpolatorUtil={InterpolateEaseOut=function() end,InterpolateLinear=function(a,b,t) return a+(b-a)*t end}
_G.CreateInterpolator=function()
    created=created+1
    local job={}
    function job:Cancel() self.cancelled=true end
    function job:Interpolate(a,b,duration,update,complete)
        assert(a==0 and b==1 and duration==.5);self.update=update;self.complete=complete
    end
    latest=job;return job
end
summary:OnLoad()
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
for _,page in ipairs(pages) do
    assert(page.Background:GetAlpha()==0 and page.Background:IsShown() and page:GetWidth()==910,
        "all Legacy page backgrounds must be suppressed without changing native visibility or geometry")
end
local divider=root.ChallengesPage.VerticalDivider
local line=skin.GetFrameData(divider,"qLegacyDividerLine")
assert(line and line:GetAlpha()==1 and line:GetWidth()==1 and divider:GetWidth()==12
    and divider:GetHeight()==503 and divider.Decoration:GetAlpha()==0
    and line.points[1][2]==divider and line.points[2][2]==divider,
    "Legacy decorative divider must become a bounded one-pixel line without changing native frame geometry")
assert(bar._quiRoundedSurface and bar.ProgressBarFrame:GetAlpha()==0 and summary.ProgressBarBackground:GetAlpha()==0
    and next(fill.masks) and bar.color[1]==.9 and bar:GetWidth()==526 and bar.value==0 and bar.range[2]==1,
    "Challenge points bar must receive rounded QUI chrome without changing range, geometry or value")
callback(owner,{traitCurrencyID=7,renownCurrency=60})
assert(bar.ratio==.6 and created==1 and bar.Text:GetText()=="60 / 100" and summary.Shield.Points:GetText()==60,
    "native currency callback must retain points/text and interpolated target ratio")
latest.update(.5);assert(bar.value==.3,"native interpolation callback must own intermediate value")
local firstJob=latest
callback(owner,{traitCurrencyID=7,renownCurrency=60})
assert(created==1 and bar.interpolator==firstJob,"native same-ratio branch must preserve current interpolator")
callback(owner,{traitCurrencyID=7,renownCurrency=200})
assert(firstJob.cancelled and bar.ratio==1 and created==2 and bar.Text:GetText()=="200 / 100",
    "native changed target must cancel old interpolation and clamp ratio to one")
latest.update(1);latest.complete();assert(bar.value==1 and bar.interpolator==nil,"native completion must clear interpolator")
max=0;callback(owner,{traitCurrencyID=7,renownCurrency=20})
assert(bar.ratio==0 and bar.Text:GetText()=="20 / 0","native zero maximum must avoid division and target zero")
local job=latest;bar:OnHide()
assert(job.cancelled and bar.ratio==nil and bar.interpolator==nil,"native hide must cancel animation and reset ratio")
local oldText=bar.Text:GetText();bar:Update(nil)
assert(bar.Text:GetText()==oldText and created==3,"native missing currency must leave retained state unchanged")
local calls=providers
registry.skinLegacySystem.refresh()
assert(line:GetAlpha()==1 and skin.GetFrameData(divider,"qLegacyDividerLine")==line and providers==calls and created==3
    and summary.Shield.Icon.atlas=="UI-Legacy-Points-icon-c60" and bar.Text.textColor[1]==.9,
    "theme must cache line, preserve native shield/text colors and avoid providers/animations")
pixel=2;skin.RefreshScaleBoundWidgets()
assert(line:GetWidth()==2 and line:GetAlpha()==1,"scale callback must keep divider one physical pixel in fixture units")
env.profile.general.skinLegacySystem=false;pixel=.5;skin.RefreshScaleBoundWidgets()
assert(line:GetWidth()==2,"disabled skin must stop scale overrides")
env.profile.general.skinLegacySystem=true;divider.IsForbidden=function() return true end
registry.skinLegacySystem.refresh();assert(line:GetWidth()==2,"forbidden divider must stop line overrides")
bar.IsForbidden=function() return true end;bar.Text:SetFont("Native",12,"")
bar:Update({traitCurrencyID=7,renownCurrency=0});assert(bar.Text.font=="Native","forbidden bar must retain native updates without typography override")
print("Legacy page backgrounds/dividers and native Challenge points animation passed")
