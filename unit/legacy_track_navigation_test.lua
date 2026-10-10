local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXML/RewardTrackTemplates.lua"))()
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyRewardTrack.lua"))()
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);page.RegisterForWidgetSet=false;root.RewardTrackPage=page
for key,method in pairs(_G.LegacyRewardTrackPageMixin) do page[key]=method end
local track=env.NewFrame("Frame",nil,page);track.RegisterForWidgetSet=false;page.LegacyRewardProgressFrame=track;track.ClipFrame={Mask=false};page.LegacyRewardProgressBar=false
local levels={{level=1},{level=2},{level=3},{level=4},{level=5}}
page.majorFactionData={factionID=1,maxLevel=5};page.actualLevel=2
_G.C_MajorFactions={GetRenownLevels=function() return levels end,GetRenownRewardsForLevel=function() return {} end}
_G.InputUtil={IsMKBUIEnabled=function() return true end,IsGamepadUIEnabled=function() return false end}
local elements={}
function track:SetCenteringEnabled(v) self.centering=v end
function track:Init(info)
    elements={}
    for _,data in ipairs(info) do
        local e={level=data.level};function e:GetLevel() return self.level end
        function e:SetMouseClickEnabled(v) self.mouse=v end
        elements[#elements+1]=e
    end
end
function track:GetElements() return elements end
function track:SetSelection(index,force) self.selectedIndex=index;self.force=force end
local start,stop,request,sounds=0,0,0,0
function track:StartScroll(direction) start=start+1;self.direction=direction end
function track:StopScroll() stop=stop+1 end
function track:RequestStop() request=request+1 end
track.scrollStartSound=1
_G.PlaySound=function() sounds=sounds+1 end
local function button(key,direction,jump)
    local b=env.NewFrame("Button",nil,track);track[key]=b;b.DisabledTexture=false;b.RegisterForWidgetSet=false
    b.direction=direction;b.enabled=true;b:SetSize(22,jump and 22 or 34)
    local normal=b:CreateTexture();normal:SetAtlas("native-arrow");b.normalTexture=normal
    local pushed=b:CreateTexture();b.pushedTexture=pushed
    local highlight=b:CreateTexture();b.highlightTexture=highlight
    local disabled=b:CreateTexture()
    function b:GetPushedTexture() return pushed end
    function b:GetDisabledTexture() return disabled end
    function b:IsEnabled() return self.enabled end
    local mixin=jump and _G.RewardTrackJumpButtonMixin or _G.RewardTrackButtonMixin
    for method,fn in pairs(mixin) do b[method]=fn end
    if jump then b:SetScript("OnClick",b.OnClick);_G.RewardTrackJumpButtonMixin.OnLoad(b)
    else
        b:SetScript("OnMouseDown",b.OnMouseDown);b:SetScript("OnMouseUp",b.OnMouseUp);b:SetScript("OnDisable",b.OnDisable)
        _G.RewardTrackArtButtonMixin.OnLoad(b)
    end
    return b
end
local left=button("LeftButton",-1,false);local right=button("RightButton",1,false)
local jumpLeft=button("JumpLeftButton",-1,true);local jumpRight=button("JumpRightButton",1,true)
page:SetupRewardTrack()
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
for _,b in ipairs({left,right,jumpLeft,jumpRight}) do
    assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface and b:IsShown() and b:GetWidth()==22,
        "native reward navigation must receive rounded chrome without changing dimensions/visibility")
end
local glyph=skin.GetFrameData(jumpRight,"nextPrevGlyph")
assert(glyph:GetText()=="»" and skin.GetFrameData(jumpLeft,"nextPrevGlyph"):GetText()=="«",
    "jump directions must remain distinct from single-step glyphs")
right:Fire("OnMouseDown");right:Fire("OnMouseUp")
assert(start==1 and stop==1 and track.direction==1 and sounds==1,
    "native enabled step handlers must retain scroll direction/stop/sound ownership")
right.enabled=false;right:Fire("OnDisable")
assert(request==1 and skin.GetFrameData(right,"nextPrevGlyph"):GetAlpha()==.35,
    "native disable request-stop and QUI disabled feedback must both run")
right:Fire("OnMouseDown");right:Fire("OnMouseUp")
assert(start==1 and stop==1 and sounds==1,"disabled step handlers must remain inert")
right.enabled=true;right:Fire("OnEnable")
assert(skin.GetFrameData(right,"nextPrevGlyph"):GetAlpha()==1,"reenabled step glyph must restore opacity")
track.selectedIndex=1;jumpRight:Fire("OnClick")
assert(track.selectedIndex==3 and sounds==2,"native forward jump must target next unlock")
jumpRight:Fire("OnClick")
assert(track.selectedIndex==5 and sounds==3,"native forward jump at unlock must target maximum")
jumpLeft:Fire("OnClick")
assert(track.selectedIndex==3 and sounds==4,"native backward jump must target next unlock")
jumpLeft:Fire("OnClick")
assert(track.selectedIndex==1 and sounds==5,"native backward jump at unlock must target first")
levels={{level=1},{level=2}};page:SetupRewardTrack()
assert(not left:IsShown() and not jumpRight:IsShown() and not track.centering and not elements[1].mouse,
    "native static track must hide navigation and disable card selection")
registry.skinLegacySystem.refresh()
assert(not left:IsShown() and left:GetHeight()==34 and jumpRight:GetHeight()==22 and sounds==5,
    "theme must preserve native hidden controls/geometry without navigation")
env.profile.general.skinLegacySystem=false;glyph:SetAlpha(.7);registry.skinLegacySystem.refresh()
assert(glyph:GetAlpha()==.7,"disabled skin must stop glyph overrides")
env.profile.general.skinLegacySystem=true;track.IsForbidden=function() return true end
registry.skinLegacySystem.refresh();assert(glyph:GetAlpha()==.7,"forbidden track must remain untouched")
print("Legacy native track navigation and visibility passed")
