local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinLegacySystem = true
ns.Helpers.GetSkinBorderColor = function() return .9,.1,.1,1 end
_G.CreateFromMixins = function(...)
    local result = {}
    for _, mixin in ipairs({...}) do for key, value in pairs(mixin) do result[key] = value end end
    return result
end
_G.AchievementTemplateMixin = {
    Init = function(self, data)
        self.id, self.completed, self.accountWide, self.collapsed = data.id, data.completed, data.accountWide, data.collapsed
    end,
    UpdatePlusMinusTexture = function(self) self:UpdatePlusMinusArt() end,
}
local af=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua"))
local achievement=af:read("*a");af:close()
_G.AchievementButtonCheckMixin={}
for _,method in ipairs({"OnLoad","Init","Collapse","Expand","GetCollapsedHeight","SetAsTracked","OnCheckClicked","OnShieldClicked"}) do
    assert(loadstring(assert(achievement:match("(function AchievementTemplateMixin:"..method.."%b().-\nend)"))))()
end
for _,method in ipairs({"ApplyChecked","OnEnter","OnLeave"}) do
    assert(loadstring(assert(achievement:match("(function AchievementButtonCheckMixin:"..method.."%b().-\nend)"))))()
end
for _,method in ipairs({"AchievementFrame_ShowDateCompleted","AchievementFrame_SetDateCompleted","AchievementFrame_ShowAsComplete","AchievementShield_SetPoints","AchievementShield_OnEnter","AchievementShield_OnLeave"}) do
    assert(loadstring(assert(achievement:match("(function "..method.."%b().-\nend)"))))()
end
_G.AchievementTemplateMixin.GetMaxCollapsedLines=function() return 2 end
_G.AchievementButton_Localize=function() end
_G.ACHIEVEMENTUI_MAX_LINES_COLLAPSED=2;_G.ACHIEVEMENTUI_MAXCONTENTWIDTH=400
local trackingDisabled=false
_G.C_GameRules={IsGameRuleActive=function() return trackingDisabled end}
_G.Enum={GameRule={TrackAchievementsDisabled=1},ContentTrackingType={Achievement=1},ContentTrackingStopType={Manual=1}}
_G.SelectionBehaviorMixin={IsIntrusiveSelected=function(self) return self.selected end}
_G.ACHIEVEMENTBUTTON_LABELWIDTH=300;_G.ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT=122
_G.ACHIEVEMENTBUTTON_DESCRIPTIONHEIGHT=20;_G.ACHIEVEMENT_FLAGS_ACCOUNT=1
_G.AchievementPointsFont={name="NativePoints",size=20};_G.AchievementPointsFontSmall={name="NativePointsSmall",size=14}
_G.bit={band=function(a,b) return math.floor(a/b)%2==1 and b or 0 end}
_G.InGuildView=function() return false end
_G.InputUtil={IsGamepadUIEnabled=function() return false end}
_G.SelectionBehaviorMixin.IsElementDataIntrusiveSelected=function(data) return data.intrusive==true end
local trackedIDs={}
local starts,stops,errors,trackingError={}, {}, {}, nil
_G.C_ContentTracking={
    IsTracking=function(_,id) return trackedIDs[id]==true end,
    GetTrackedIDs=function() local ids={} for id,tracked in pairs(trackedIDs) do if tracked then ids[#ids+1]=id end end return ids end,
    StopTracking=function(kind,id,reason) stops[#stops+1]={kind,id,reason};trackedIDs[id]=false end,
    StartTracking=function(kind,id) starts[#starts+1]={kind,id};if not trackingError then trackedIDs[id]=true end;return trackingError end,
}
_G.Constants={ContentTrackingConsts={MaxTrackedAchievements=2}}
_G.UIErrorsFrame={AddMessage=function(_,text) errors[#errors+1]=text end}
_G.ContentTrackingUtil={DisplayTrackingError=function(err) errors[#errors+1]=err end}
_G.ACHIEVEMENT_WATCH_TOO_MANY="Too many";_G.ERR_ACHIEVEMENT_WATCH_COMPLETED="Completed"
_G.format=string.format
_G.qLegacyTestTracked=trackedIDs
assert(loadstring("local trackedAchievements=_G.qLegacyTestTracked\n"..assert(achievement:match("(function AchievementTemplateMixin:ToggleTracking%b().-\nend)"))))()
local info={
    [1]={points=10,completed=false,flags=0,icon=123,name="Native challenge",description="Native description"},
    [2]={points=120,completed=true,flags=1,icon=456,name="Account challenge",description="Completed account description",wasEarnedByMe=true},
    [3]={points=0,completed=false,flags=0,icon=789,name="Zero challenge",description="No points"},
    [4]={points=25,completed=false,flags=0,icon=987,name="Progressive challenge",description="Progressive description",progressive=true},
    [5]={points=40,completed=true,flags=1,icon=555,name="Earned by another",description="Warband completion",wasEarnedByMe=false},
}
_G.GetAchievementInfo=function(category,index)
    local id=index or category;local data=assert(info[id])
    return id,data.name,data.points,data.completed,10,9,26,data.description,data.flags,data.icon,data.reward or "",false,data.wasEarnedByMe,"Native earner"
end
_G.GetAchievementCategory=function() return 99 end
local legacyFile=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyChallenges.lua"))
local legacyOverrides=legacyFile:read("*a");legacyFile:close()
_G.Constants.LegacyConsts={LEGACY_POINTS_TRAIT_CURRENCY_ID=7}
_G.C_Traits={GetTraitCurrencyForAchievement=function(currency,id) assert(currency==7);return info[id].points end}
for _,method in ipairs({"AchievementFrame_SetDateCompleted","AchievementFrame_ShowDateCompleted","AchievementFrame_ShowAsComplete","AchievementFrame_GetOverridePoints","AchievementShield_OnEnter"}) do
    assert(loadstring(assert(legacyOverrides:match("(function "..method.."%b().-\nend)"))))()
end
_G.GetPreviousAchievement=function(id) return info[id].progressive end
_G.AchievementButton_GetProgressivePoints=function() return 250 end
local objectives=env.NewFrame("Frame");objectives.RegisterForWidgetSet=false
_G.LegacyChallengeObjectives=objectives
function objectives:Display(id,width) self.displayID=id;self.displayWidth=width;self:SetHeight(70);return 70 end
local secureHook=_G.hooksecurefunc
_G.hooksecurefunc=function(target,name,callback)
    if target==objectives and name=="Display" then
        local original=target[name]
        target[name]=function(...) local result=original(...);callback(...);return result end
    else return secureHook(target,name,callback) end
end
_G.GenerateClosure=function(fn,owner) return function(...) return fn(owner,...) end end
_G.FormatShortDate=function(day,month,year) return string.format("%d/%d/%d",month,day,year) end
local sounds,trackingClicks,shieldClicks=0,0,0
_G.SOUNDKIT={IG_MAINMENU_OPTION_CHECKBOX_ON=1,IG_MAINMENU_OPTION_CHECKBOX_OFF=2}
_G.PlaySound=function() sounds=sounds+1 end
_G.TRACK_ACHIEVEMENT_TOOLTIP="Track";_G.UNTRACK_ACHIEVEMENT_TOOLTIP="Untrack"
_G.ACCOUNT_WIDE_ACHIEVEMENT_COMPLETED="General account completion"
_G.ACCOUNT_WIDE_ACHIEVEMENT="General account achievement"
_G.GameTooltip={SetOwner=function(self,owner,anchor) self.owner=owner;self.anchor=anchor end,
    SetText=function(self,text) self.text=text;self.shown=true end,
    AddLine=function(self,text) self.lines=self.lines or {};self.lines[#self.lines+1]=text end,
    Show=function(self) self.shown=true end,
    Hide=function(self) self.shown=false end}
_G.WHITE_FONT_COLOR = {GetRGBA = function() return 1,1,1,1 end}
_G.GRAY_FONT_COLOR = {GetRGBA = function() return .5,.5,.5,1 end}
_G.TextureKitConstants = {IgnoreAtlasSize = false, UseAtlasSize = true}
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyChallengeButton.lua"))()
local root = env.NewFrame("Frame"); root.CloseButton = false; root.Tabs = {}; root.Pages = {}
_G.LegacySystemFrame = root
local detail = env.NewFrame("Frame", nil, root); root.ChallengesPage = {DetailPane = detail}
local box = env.NewFrame("Frame", nil, detail); detail.ScrollBox = box
local rows = {}
function box:HasView() return true end
function box:ForEachFrame(fn) for _, row in ipairs(rows) do fn(row) end end
local acquired
_G.ScrollUtil.AddAcquiredFrameCallback = function(_, fn) acquired = fn end
local function card()
    local b = env.NewFrame("Button", nil, box); b.RegisterForWidgetSet = false; b.DisabledTexture = false; b:SetSize(516,122)
    for key, method in pairs(_G.LegacyChallengeTemplateMixin) do b[key] = method end
    for _, key in ipairs({"Background","BackgroundTop","BackgroundMiddle","BackgroundBottom","SelectedOverlay","TitleBar","PlusMinus"}) do
        b[key] = b:CreateTexture()
    end
    function b.BackgroundMiddle:SetVertTile(v) self.tiled = v end
    b.TitleBar:SetSize(431,40); b.TitleBar:SetPoint("TOPLEFT", b, "TOPLEFT",5,-4)
    for _, key in ipairs({"Label","Description","HiddenDescription"}) do b[key] = b:CreateFontString() end
    b.Label:SetText("Native challenge"); b.Description:SetText("Native description")
    b.selected = false
    function b:IsSelected() return self.selected end
    function b:ShouldShowPlusMinus() return true end
    function b:CreateMaskTexture() return env.NewTexture(self, "MaskTexture") end
    for _, key in ipairs({"TitleBar","SelectedOverlay"}) do
        b[key].AddMaskTexture = function(self, mask) self.mask = mask end
    end
    b.Icon = env.NewFrame("Frame", nil, b); b.Icon.RegisterForWidgetSet = false
    b.Icon.texture = b.Icon:CreateTexture(); b.Icon.texture:SetTexture(123)
    b.Icon.texture:SetSize(50,50);b.Icon.texture:SetTexCoord(.1,.9,.2,.8)
    b.Icon.frame=b.Icon:CreateTexture();b.Icon.frame:SetAtlas("Legacy-Tree-Frame-icon-frame")
    b.Icon.TextureMask=b.Icon:CreateTexture();b.Icon.TextureMask:SetAtlas("UI-Frame-IconMask")
    b.Icon.texture.nativeMask=b.Icon.TextureMask
    function b.Icon.texture:SetDesaturated(v) self.desaturated = v end
    for key, method in pairs(_G.LegacyChallengeIconFrameMixin) do b.Icon[key] = method end
    b.Shield = env.NewFrame("Button", nil, b); b.Shield.RegisterForWidgetSet = false
    b.Shield.Icon = b.Shield:CreateTexture(); b.Shield.Icon:SetAtlas("Legacy-Tree-Frame-Points-Icon")
    for key, method in pairs(_G.LegacyChallengeShieldMixin) do b.Shield[key] = method end
    b.Shield:SetScript("OnEnter",_G.AchievementShield_OnEnter)
    b.Shield:SetScript("OnLeave",_G.AchievementShield_OnLeave)
    b.Shield.Points=b.Shield:CreateFontString()
    function b.Shield.Points:SetFontObject(font)
        self.nativeFontObject=font;self:SetFont(font.name,font.size,"")
    end
    b.Shield.CheckBackground=b.Shield:CreateTexture()
    b.Shield.CheckBackground:SetAtlas("Legacy-Challenge-Cards-Date-BG");b.Shield.CheckBackground:SetSize(85,24)
    b.Shield.Check=b.Shield:CreateTexture();b.Shield.Check:SetAtlas("worldquest-tracker-checkmark")
    b.Shield.DateCompleted=b.Shield:CreateFontString();b.Shield.DateCompleted:SetTextColor(.8,.7,.6,1)
    function b.Shield:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
    function b.Shield.CheckBackground:AddMaskTexture(mask) self.mask=mask end
    b.Tracked=env.NewFrame("CheckButton",nil,b);b.Tracked.RegisterForWidgetSet=false;b.Tracked:SetSize(15,15)
    function b.Tracked:SetHitRectInsets(...) self.hitRectInsets={...} end
    b.Tracked:SetHitRectInsets(-100,0,0,0);b.Tracked.Text=b.Tracked:CreateFontString()
    b.Tracked.Text:SetText("Track achievement")
    for _,key in ipairs({"NormalTexture","PushedTexture","HighlightTexture","CheckedTexture","DisabledCheckedTexture"}) do
        b.Tracked[key]=b.Tracked:CreateTexture();b.Tracked[key]:SetTexture(key)
    end
    function b.Tracked:GetNormalTexture() return self.NormalTexture end
    function b.Tracked:GetPushedTexture() return self.PushedTexture end
    function b.Tracked:GetHighlightTexture() return self.HighlightTexture end
    function b.Tracked:GetCheckedTexture() return self.CheckedTexture end
    function b.Tracked:GetDisabledCheckedTexture() return self.DisabledCheckedTexture end
    b.Tracked.enabled=true
    function b.Tracked:IsEnabled() return self.enabled end
    function b.Tracked:GetChecked() return self.checked end
    function b.Tracked:SetChecked(value) self.checked=value end
    for key,method in pairs(_G.AchievementButtonCheckMixin) do b.Tracked[key]=method end
    b.Tracked:SetScript("OnEnter",b.Tracked.OnEnter);b.Tracked:SetScript("OnLeave",b.Tracked.OnLeave)
    b.collapsedHeight=122;b.HiddenDescription:SetHeight(24)
    function b:IsMouseOver() return false end
    function b:ToggleTracking() trackingClicks=trackingClicks+1;return _G.AchievementTemplateMixin.ToggleTracking(self) end
    function b:ProcessClick() shieldClicks=shieldClicks+1 end
    b:OnLoad()
    b:SetScript("OnClick", function() error("styling must not click a challenge") end)
    b:Init({id=1,completed=false,accountWide=false,collapsed=true})
    b:UpdateBackgroundForHeight(122)
    rows[#rows+1] = b; return b
end
local first = card()
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callbacks.Blizzard_LegacySystem(); env.RunTimers()
local backdrop, click = skin.GetBackdrop(first), first:GetScript("OnClick")
assert(backdrop and backdrop._quiRoundedSurface and first.Background:GetAlpha()==0,
    "legacy challenge cards must receive rounded QUI shells and suppress tiled native chrome")
assert(first.Description.textColor[1]==.5 and first.Icon.texture.desaturated and first.Icon.texture.texture==123,
    "native incomplete text dimming and icon desaturation/art must remain")
local trackedChrome=skin.GetBackdrop(first.Tracked)
local iconBorder=skin.GetFrameData(first.Icon.texture,"iconBorder")
assert(trackedChrome and trackedChrome._quiRoundedSurface and iconBorder and iconBorder._quiRoundedSurface,
    "legacy challenge tracking toggle and inner icon must receive rounded QUI chrome")
assert(first.Icon.frame:GetAlpha()==0 and first.Icon.texture.nativeMask==first.Icon.TextureMask
    and first.Icon.texture.texCoord[1]==.1 and first.Icon.texture:GetWidth()==50
    and first.Shield.Icon.atlas=="Legacy-Tree-Frame-Points-Icon",
    "native icon art, UV, mask and currency shield must remain")
assert(first.Tracked:GetWidth()==15 and first.Tracked.hitRectInsets[1]==-100
    and first.Tracked.CheckedTexture.texture=="CheckedTexture"
    and first.Tracked.DisabledCheckedTexture.texture=="DisabledCheckedTexture"
    and first.Tracked.Text:GetText()=="Track achievement",
    "native tracking check art, label and expanded hit area must remain")
assert(first.Shield.CheckBackground.mask and first.Shield.CheckBackground:GetWidth()==85
    and first.Shield.CheckBackground.color[1] and first.DateCompleted==first.Shield.DateCompleted,
    "date decoration must be rounded without changing native geometry or inherited date alias")
trackedIDs[1]=true;first:SetAsTracked(true,true)
assert(first.Tracked:GetChecked() and first.Tracked:IsShown() and sounds==0,
    "native tracking checked/visibility and no-sound semantics must remain")
first.Tracked:Fire("OnEnter")
assert(GameTooltip.text=="Untrack" and GameTooltip.owner==first.Tracked and GameTooltip.anchor=="ANCHOR_RIGHT",
    "native checked tooltip must remain")
assert(trackedChrome._quiBorderR==.9,"tracking hover must use QUI accent without changing native tooltip")
first.Tracked:Fire("OnLeave");assert(trackedChrome._quiBorderR==env.colors[1],"tracking leave must restore neutral border")
assert(not GameTooltip.shown,"native tracking leave must hide tooltip")
first.Tracked:Fire("OnEnter");first.Tracked.enabled=false;first.Tracked:Fire("OnDisable")
assert(trackedChrome._quiBorderR==env.colors[1]
    and first.Tracked.DisabledCheckedTexture.vertex[1]==.45,
    "disabling a hovered tracking control must clear accent outline and retain dimmed native check")
first.Tracked.enabled=true;first.Tracked:Fire("OnEnable");first.Tracked:Fire("OnLeave")
first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(trackingClicks==1 and not first.Tracked:GetChecked() and not first.Tracked:IsShown() and sounds==1,
    "inherited native tracking closure must remain connected")
first.Shield:Fire("OnClick",first.Shield,"LeftButton",false)
assert(shieldClicks==1,"inherited native shield click closure must remain")
_G.AchievementFrame_SetDateCompleted(first,9,10,26);_G.AchievementFrame_ShowDateCompleted(first,true)
assert(first.DateCompleted:GetText()=="10/9/26" and first.DateCompleted:IsShown()
    and first.DateCompleted.textColor[1]==.8 and first.Shield.Check.atlas=="worldquest-tracker-checkmark",
    "native completion date text/visibility/color and check art must remain")
_G.AchievementFrame_ShowDateCompleted(first,false)
assert(not first.DateCompleted:IsShown(),"native completion reset must hide date")
first.selected=true; first:RefreshStateArt()
assert(first.SelectedOverlay:IsShown() and first.SelectedOverlay.color[4]==.08 and first.SelectedOverlay.mask
    and first.Description.textColor[1]==1 and not first.Icon.texture.desaturated,
    "native selected visibility/readability must remain with rounded selection tint")
local selectedBorder = backdrop._quiBorderR
first.selected=false; first:RefreshStateArt()
assert(not first.SelectedOverlay:IsShown() and backdrop._quiBorderR~=selectedBorder,
    "native deselection must reset QUI border and selection visibility")
first:Init({id=2,intrusive=true})
assert(first.accountWide and first.completed and not first.collapsed
    and first.Icon.texture.texture==456 and first.Shield.Points:GetText()==120
    and first.Shield.Points.nativeFontObject==_G.AchievementPointsFontSmall
    and first.Shield.Points.font=="QUIFont.ttf" and first.Shield.Points.fontSize==14
    and first.DateCompleted:IsShown() and first.DateCompleted:GetText()=="10/9/26"
    and objectives.displayID==2 and objectives.displayWidth==516 and objectives:GetParent()==first
    and first:GetHeight()==196 and first.HiddenDescription:IsShown() and not first.Description:IsShown(),
    "complete native Init must update account/completion, small point font, date and expanded objective layout")
first:SetHeight(240); first:UpdateBackgroundForHeight(240); first:Saturate()
assert(first.BackgroundTop:IsShown() and first.BackgroundTop:GetAlpha()==0 and not first.Background:IsShown()
    and first.BackgroundMiddle.tiled and first:GetHeight()==240,
    "native expanded tiled visibility/layout must remain with decorative alpha suppressed")
assert(first.TitleBar.atlas=="Legacy-Challenge-Cards-Ribbon-Blue" and first.TitleBar.mask
    and first.TitleBar:GetWidth()==431 and first.PlusMinus.atlas=="128-redbutton-minus"
    and first.Description.points[#first.Description.points][4]==95,
    "account-wide ribbon, native header geometry and expanded glyph/description offset must remain")
first:UpdateShieldArt(0); assert(not first.Shield.Icon:IsShown())
first:UpdateShieldArt(10); assert(first.Shield.Icon:IsShown(), "native zero/nonzero point icon visibility must remain")
registry.skinLegacySystem.refresh()
assert(skin.GetBackdrop(first)==backdrop and first:GetScript("OnClick")==click and first:GetWidth()==516,
    "theme must preserve cached card shell, handlers and geometry")
ns.Helpers.GetSkinBorderColor=function() return .2,.6,.9,1 end
registry.skinLegacySystem.refresh()
assert(first.Tracked.CheckedTexture.vertex[1]==.2 and first.Tracked.DisabledCheckedTexture.vertex[1]==.1
    and skin.GetBackdrop(first.Tracked)==trackedChrome
    and skin.GetFrameData(first.Icon.texture,"iconBorder")==iconBorder
    and trackingClicks==1 and shieldClicks==1 and sounds==1,
    "theme must refresh both native check tints and cache inner chrome without action calls")
trackedIDs[4]=true
first:Init({id=4,index=4,category=99})
assert(not first.completed and not first.accountWide and first.collapsed and first:GetHeight()==122
    and first.Shield.Points:GetText()==250 and first.Shield.Points.nativeFontObject==_G.AchievementPointsFontSmall
    and first.Tracked:GetChecked() and first.Tracked:IsShown() and not first.DateCompleted:IsShown()
    and first.Icon.texture.texture==987 and first.Description.textColor[1]==.5 and first.Icon.texture.desaturated,
    "native indexed progressive reuse must reset completion/date/layout while retaining tracking and incomplete art")
first:Init({id=3})
assert(first.Shield.Points:GetText()=="" and not first.Shield.Icon:IsShown()
    and not first.Tracked:GetChecked() and not first.Tracked:IsShown() and first.Icon.texture.texture==789,
    "native zero-point reuse must clear points, badge and tracked state")
first:Init({id=1})
assert(first.Shield.Points:GetText()==10 and first.Shield.Points.nativeFontObject==_G.AchievementPointsFont
    and first.Shield.Points.font=="QUIFont.ttf" and first.Shield.Points.fontSize==20
    and first.Shield.Icon:IsShown() and first.Icon.texture.texture==123 and sounds==1,
    "native normal-point font and icon must restore after reuse without extra sound")
first:Init({id=5})
assert(not first.completed and first.accountWide and not first.DateCompleted:IsShown()
    and not first.Shield.CheckBackground:IsShown() and not first.Shield.Check:IsShown()
    and first.Shield.wasEarnedByMe==false and first.Shield.earnedBy=="Native earner"
    and first.Description.textColor[1]==.5 and first.Icon.texture.desaturated,
    "actual Legacy completion override must dim other-earned account challenges and hide all date/check decoration")
first:Init({id=2})
assert(first.completed and first.DateCompleted:IsShown() and first.Shield.CheckBackground:IsShown()
    and first.Shield.Check:IsShown() and first.DateCompleted:GetWidth()==first.DateCompleted:GetStringWidth()+5
    and first.Shield.Points:GetText()==120,
    "actual Legacy date width/visibility and trait-currency point override must remain")
local tooltipEnters,tooltipLeaves=0,0
first:SetScript("OnEnter",function(self) assert(self==first);tooltipEnters=tooltipEnters+1 end)
first:SetScript("OnLeave",function(self) assert(self==first);tooltipLeaves=tooltipLeaves+1 end)
local element={id=2}
function first:GetElementData() return element end
info[2].reward="Native Legacy reward"
GameTooltip.lines={}
first.Shield:Fire("OnEnter")
assert(GameTooltip.owner==first.Shield and GameTooltip.anchor=="ANCHOR_RIGHT" and GameTooltip.shown
    and #GameTooltip.lines==1 and GameTooltip.lines[1]=="Native Legacy reward" and tooltipEnters==0,
    "actual Legacy shield override must show achievement reward rather than account completion tooltip")
first.Shield:Fire("OnLeave")
assert(tooltipLeaves==1 and not GameTooltip.shown,"native shield leave must pass through to row and hide tooltip")
element={id=1};info[1].reward="Reused challenge reward"
first:Init({id=1});GameTooltip.lines={};first.Shield:Fire("OnEnter")
assert(GameTooltip.lines[1]=="Reused challenge reward" and tooltipEnters==0,
    "reused shield must query current element reward rather than stale earned or completion state")
element=nil;GameTooltip.lines={};first.Shield:Fire("OnEnter")
assert(tooltipEnters==1 and GameTooltip.shown and #GameTooltip.lines==0,
    "missing element must pass through to row tooltip without inventing reward text")
first.Shield:Fire("OnLeave")
assert(tooltipLeaves==2 and not GameTooltip.shown)
first:SetScript("OnEnter",nil);first:SetScript("OnLeave",nil)
first.Shield:Fire("OnEnter");assert(GameTooltip.shown,"absent row handler must retain native tooltip show behavior")
first.Shield:Fire("OnLeave");assert(not GameTooltip.shown,"absent row handler must retain native tooltip hide behavior")
element={id=3};GameTooltip.lines={}
first.Shield:Fire("OnEnter")
assert(#GameTooltip.lines==1 and GameTooltip.lines[1]=="","empty rewards must retain native AddLine behavior")
first.Shield:Fire("OnLeave")
assert(first.Shield:GetScript("OnEnter")==_G.AchievementShield_OnEnter
    and first.Shield:GetScript("OnLeave")==_G.AchievementShield_OnLeave,
    "skinning and card reuse must preserve native shield tooltip scripts")
first:Init({id=1})
trackingDisabled=true;first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(#starts==0 and #stops==1 and sounds==1,"native disabled tracking rule must suppress provider actions")
trackingDisabled=false;trackedIDs[42]=true
first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(errors[#errors]=="Too many" and #starts==0 and sounds==1,"native tracking capacity must reject without state/sound changes")
trackedIDs[42]=false;first:Init({id=2})
first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(errors[#errors]=="Completed" and #starts==0 and sounds==1,"native earned-completion eligibility must reject tracking")
first:Init({id=1});first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(#starts==1 and starts[1][2]==1 and first.Tracked:GetChecked() and first.Tracked:IsShown() and sounds==2,
    "native eligible click must check/show and start achievement tracking")
first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(#stops==2 and stops[2][2]==1 and stops[2][3]==_G.Enum.ContentTrackingStopType.Manual
    and not first.Tracked:GetChecked() and sounds==3,"native tracked click must stop with Manual reason and uncheck")
trackingError="Provider error";first.Tracked:Fire("OnClick",first.Tracked,"LeftButton",false)
assert(#starts==2 and errors[#errors]=="Provider error" and not trackedIDs[1]
    and first.Tracked:GetChecked() and sounds==4,
    "native provider failure must retain native immediate check and error delivery")
trackingError=nil
local nextCard=card(); acquired(box, nextCard); env.RunTimers()
assert(skin.GetBackdrop(nextCard), "newly acquired native challenge must be styled")
env.profile.general.skinLegacySystem=false
nextCard.Description:SetFont("Native",12,""); nextCard:RefreshStateArt()
assert(nextCard.Description.font=="Native", "disabled card reuse must stop font overrides")
env.profile.general.skinLegacySystem=true
root.IsForbidden = function() return true end
nextCard.Description:SetFont("Forbidden",12,""); nextCard:RefreshStateArt()
assert(nextCard.Description.font=="Forbidden", "forbidden root must stop card overrides")
root.IsForbidden = function() return false end
nextCard.IsForbidden = function() return true end
nextCard:RefreshStateArt()
assert(nextCard.Description.font=="Forbidden", "forbidden card must stop overrides")
nextCard.IsForbidden = function() return false end
nextCard.Description:SetFont("Native",12,"")
nextCard.parent=_G.UIParent; nextCard:RefreshStateArt()
assert(nextCard.Description.font=="Native", "card borrowed outside detail pane must remain native")
print("Legacy native challenge card states passed")
