local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
local f=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua"))
local native=f:read("*a");f:close()
local artFile=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_TalentButtonArt.lua"))
local art=artFile:read("*a");artFile:close()
_G.TalentButtonArtMixin={}
assert(loadstring(assert(art:match("(function TalentButtonArtMixin:OnLoad%b().-\nend)"))))()
_G.TextureKitConstants={IgnoreAtlasSize=false,UseAtlasSize=true}
_G.TalentFrameBaseMixin={Event={TalentButtonAcquired="TalentButtonAcquired"}}
assert(loadstring(assert(native:match("(function TalentFrameBaseMixin:AcquireTalentButton%b().-\nend)"))))()
_G.TalentButtonBaseMixin={}
_G.GenerateClosure=function(fn,owner) return function(...) return fn(owner,...) end end
local root=env.NewFrame("Frame");root.CloseButton=false;root.Pages={};root.Tabs={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);page.RegisterForWidgetSet=false;root.TreePage=page
local tree=env.NewFrame("Frame",nil,page);tree.RegisterForWidgetSet=false;page.LegacyTreeTraitPanel=tree
tree.ButtonsParent=env.NewFrame("Frame",nil,tree);tree.ButtonsParent.RegisterForWidgetSet=false
tree.AcquireTalentButton=_G.TalentFrameBaseMixin.AcquireTalentButton
local acquired
function tree:RegisterCallback(event,fn,owner) assert(event=="TalentButtonAcquired" and owner==root);acquired=fn end
local events,edges,inits,setup=0,0,0,0
function tree:TriggerEvent(event,button) assert(event=="TalentButtonAcquired");events=events+1;acquired(self,button) end
function tree:MarkEdgesDirty(button) assert(button);edges=edges+1 end
function tree:GetButtonSize() return 44 end
tree.getTemplateType=function() return "TalentButtonLegacySquareTemplate" end
tree.getSpecializedMixin=function() return nil end
tree.TalentButtonCollectionReset=function() end
local nextButton,new=true,true
local pool={SetResetDisallowedIfNew=function(_,value) assert(value) end}
function pool:Acquire(template) assert(template=="TalentButtonLegacySquareTemplate");return nextButton,new end
tree.talentButtonCollection={GetOrCreatePool=function(_,kind,parent,template,reset,forbidden,mixin)
    assert(kind=="BUTTON" and parent==tree.ButtonsParent and template=="TalentButtonLegacySquareTemplate"
        and type(reset)=="function" and forbidden==nil and mixin==_G.TalentButtonBaseMixin)
    return pool,new
end}
local function button(parent)
    local b=env.NewFrame("Button",nil,parent);b.RegisterForWidgetSet=false;b.DisabledTexture=false
    b.SpendText=b:CreateFontString();b.SpendText:SetFont("NativeRank",12,"");b.SpendText:SetText("1 / 3")
    b.SpendText:SetTextColor(.2,.8,.3,1)
    b.spendTextShadows={b:CreateFontString(),b:CreateFontString()}
    for _,text in ipairs({b.SpendText,b.spendTextShadows[1],b.spendTextShadows[2]}) do
        function text:SetFontObject(font) self:SetFont(font,16,"OUTLINE") end
    end
    for _,key in ipairs({"IconMask","DisabledOverlayMask","Glow","Ghost","Shadow"}) do b[key]=b:CreateTexture() end
    b.artSet={spendFont="SystemFont16_Shadow_ThickOutline",iconMask=nil,glow="NativeGlow",ghost="NativeGhost",shadow="NativeShadow"}
    b.ApplySize=function() end
    b.NativeArtOnLoad=_G.TalentButtonArtMixin.OnLoad
    b.Icon=b:CreateTexture();b.Icon:SetTexture(123);b.Icon:SetTexCoord(.1,.9,.2,.8)
    function b:SetAndApplySize(w,h) self:SetSize(w,h) end
    function b:Init(owner) assert(owner==tree);inits=inits+1 end
    return b
end
local callbacks={}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function() end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local function acquire(b)
    nextButton=b
    return tree:AcquireTalentButton({type=1},1,20,-30,function(value)
        assert(value==b);setup=setup+1
    end)
end
env.profile.general.skinLegacySystem=false
local disabled=button(tree.ButtonsParent);assert(acquire(disabled)==disabled)
assert(disabled.SpendText.font=="NativeRank",
    "disabled Legacy skin must not restyle a newly acquired native talent node")
env.profile.general.skinLegacySystem=true
local normal=button(tree.ButtonsParent);assert(acquire(normal)==normal)
assert(normal.SpendText.font=="QUIFont.ttf" and normal.SpendText.fontSize==12
    and normal.SpendText:GetText()=="1 / 3" and normal.SpendText.textColor[2]==.8
    and normal:GetWidth()==44 and normal:GetHeight()==44 and normal.Icon.texture==123
    and normal.Icon.texCoord[1]==.1 and normal.points[#normal.points][2]==tree.ButtonsParent,
    "native acquisition must retain rank size/value/color, icon and node geometry while applying QUI fonts")
assert(events==2 and edges==2 and inits==2 and setup==2,
    "skinning must preserve native initialization/setup/event/edge ordering counts")
new=false;normal.SpendText:SetFont("NativeReuse",12,"");acquire(normal)
assert(normal.SpendText.font=="QUIFont.ttf" and inits==2 and events==3 and edges==3,
    "reused pool node must refresh typography without repeating native Init")
normal:NativeArtOnLoad()
assert(normal.SpendText.font=="QUIFont.ttf" and normal.SpendText.fontSize==16
    and normal.spendTextShadows[1].font=="QUIFont.ttf" and normal.spendTextShadows[2].font=="QUIFont.ttf"
    and not normal.IconMask:IsShown() and not normal.DisabledOverlayMask:IsShown()
    and normal.Glow.atlas=="NativeGlow" and normal.Ghost.atlas=="NativeGhost" and normal.Shadow.atlas=="NativeShadow",
    "actual native talent art OnLoad must retain atlas/mask setup while locked spend text/shadows use QUI face and native size")
env.profile.general.skinLegacySystem=false
normal:NativeArtOnLoad()
assert(normal.SpendText.font=="SystemFont16_Shadow_ThickOutline"
    and normal.spendTextShadows[1].font=="SystemFont16_Shadow_ThickOutline",
    "already locked talent spend text must stop overriding native setters when Legacy skinning is disabled")
env.profile.general.skinLegacySystem=true
normal:NativeArtOnLoad();assert(normal.SpendText.font=="QUIFont.ttf")
normal:SetParent(env.NewFrame("Frame"));normal:NativeArtOnLoad()
assert(normal.SpendText.font=="SystemFont16_Shadow_ThickOutline","borrowed locked node must stop font setter overrides")
normal:SetParent(tree.ButtonsParent)
for _,owner in ipairs({normal,tree,page,root}) do
    owner.IsForbidden=function() return true end
    normal:NativeArtOnLoad()
    assert(normal.SpendText.font=="SystemFont16_Shadow_ThickOutline","forbidden locked node ancestry must stop overrides")
    owner.IsForbidden=function() return false end
end
normal:NativeArtOnLoad();assert(normal.SpendText.font=="QUIFont.ttf","owned node must resume font styling")
local utilFile=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentUtil.lua"))
local util=utilFile:read("*a");utilFile:close()
_G.TalentButtonUtil={}
assert(loadstring(assert(util:match("(TalentButtonUtil.BaseVisualState = %b{})"))))()
_G.MixinUtil={CallMethodSafe=function(object,method,...) if object and object[method] then object[method](object,...) end end}
local function color(r,g,b)
    return {GetRGB=function() return r,g,b end,GetRGBA=function() return r,g,b,1 end}
end
_G.DISABLED_FONT_COLOR=color(.5,.5,.5);_G.GREEN_FONT_COLOR=color(.2,.8,.3)
_G.RED_FONT_COLOR=color(1,.1,.1);_G.YELLOW_FONT_COLOR=color(1,1,.1)
_G.DIM_RED_FONT_COLOR=color(.7,.1,.1);_G.WHITE_FONT_COLOR=color(1,1,1)
local camelotFile=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedTalentUI/Camelot/Blizzard_SharedTalentOverrides.lua"))
local camelot=camelotFile:read("*a");camelotFile:close()
for _,name in ipairs({"OnEnterVisuals","OnLeaveVisuals","SetBorderAtlas","UpdateSearchIcon","UpdateGlow","UpdateNonStateVisuals"}) do
    assert(loadstring(assert(art:match("(function TalentButtonArtMixin:"..name.."%b().-\nend)"))))()
end
assert(loadstring(assert(art:match("(local RefundInvalidOverlayAlpha = [^\n]+)")).."\n"
    ..assert(art:match("(function TalentButtonArtMixin:ApplyVisualState%b().-\nend)"))))()
assert(loadstring(assert(camelot:match("(function TalentButtonArtMixin:UpdateStateBorder%b().-\nend)"))))()
assert(loadstring(assert(camelot:match("(function TalentButtonUtil.GetColorForBaseVisualState%b().-\nend)"))))()
assert(loadstring(assert(util:match("(function TalentButtonUtil.SetSpendText%b().-\nend)"))))()
_G.TalentButtonUtil.GetHoverAlphaForVisualStyle=function() return .6 end
_G.CVarCallbackRegistry={GetCVarValueBool=function(_,name) assert(name=="colorblindMode");return true end}
assert(loadstring(assert(art:match("(TalentButtonArtMixin.ArtSet = %b{})"))))()
for name,fn in pairs(_G.TalentButtonArtMixin) do if type(fn)=="function" then normal[name]=fn end end
normal.artSet=_G.TalentButtonArtMixin.ArtSet.LegacySquare
for _,key in ipairs({"DisabledOverlay","StateBorder","StateBorderHover","SelectableIcon"}) do normal[key]=normal:CreateTexture() end
function normal.Icon:SetDesaturated(value) self.desaturated=value end
local states=_G.TalentButtonUtil.BaseVisualState
local expected={
    Normal={_G.GREEN_FONT_COLOR,"Legacy-Tree-Frame-icon-frame-Green",false,false,.25},
    Selectable={_G.GREEN_FONT_COLOR,"Legacy-Tree-Frame-icon-frame-Green",false,false,.25},
    Maxed={_G.YELLOW_FONT_COLOR,"Legacy-Tree-Frame-icon-frame",false,false,.25},
    Gated={_G.DISABLED_FONT_COLOR,"Legacy-Tree-Frame-icon-frame-disable",true,true,.7},
    Disabled={_G.DISABLED_FONT_COLOR,"Legacy-Tree-Frame-icon-frame-disable",true,true,.25},
    Locked={_G.DISABLED_FONT_COLOR,"Legacy-Tree-Frame-icon-frame-disable",true,true,.25},
    RefundInvalid={_G.RED_FONT_COLOR,"talents-node-square-red",false,true,.3},
    DisplayError={_G.RED_FONT_COLOR,"talents-node-square-red",false,false,.25},
}
for name,data in pairs(expected) do
    normal:ApplyVisualState(states[name])
    local r,g,b=data[1]:GetRGB()
    assert(normal.SpendText.textColor[1]==r and normal.SpendText.textColor[2]==g and normal.SpendText.textColor[3]==b
        and normal.StateBorder.atlas==data[2] and normal.Icon.desaturated==data[3]
        and normal.DisabledOverlay:IsShown()==data[4] and normal.DisabledOverlay:GetAlpha()==data[5],
        "actual Camelot native visual state must preserve rank color, border, desaturation and overlay: "..name)
    normal:OnEnterVisuals();assert(normal.StateBorderHover:IsShown() and normal.StateBorderHover:GetAlpha()==.6)
    normal:OnLeaveVisuals();assert(not normal.StateBorderHover:IsShown())
    normal:NativeArtOnLoad()
    assert(normal.SpendText.font=="QUIFont.ttf" and normal.SpendText.textColor[1]==r,
        "QUI font reassertion must preserve the native visual-state text color")
end
normal.SearchIcon=env.NewFrame("Frame",nil,normal)
function normal.SearchIcon:SetMatchType(value) self.matchType=value end
normal.matchType="Exact";normal.isGhosted=true;normal.shouldGlow=true
normal:UpdateNonStateVisuals()
assert(normal.SearchIcon.matchType=="Exact" and normal.SearchIcon:GetFrameLevel()==normal:GetFrameLevel()+50
    and normal.Ghost:IsShown() and normal.Glow:IsShown(),"native search marker level, ghost and glow ownership must survive")
normal.matchType=nil;normal.isGhosted=false;normal.shouldGlow=false;normal:UpdateNonStateVisuals()
assert(normal.SearchIcon.matchType==nil and not normal.Ghost:IsShown() and not normal.Glow:IsShown(),
    "native state reset must clear search match, ghost and glow")
local baseFile=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_TalentButtonBase.lua"))
local base=baseFile:read("*a");baseFile:close()
for _,name in ipairs({"GetSpendText","UpdateSpendText"}) do
    assert(loadstring(assert(base:match("(function TalentButtonBaseMixin:"..name.."%b().-\nend)"))))()
    normal[name]=_G.TalentButtonBaseMixin[name]
end
_G.Enum={TraitNodeEntryType={SpendSmallCircle=3}}
function normal:GetEntryInfo() return {type=1} end
function normal:IsSelectable() return false end
function normal:GetTalentFrame() return tree end
function tree:ShouldHideSingleRankNumbers() return true end
normal.nodeInfo={ranksPurchased=2,currentRank=2,maxRanks=3}
normal:UpdateSpendText()
assert(normal.SpendText:GetText()=="2" and normal.spendTextShadows[1]:GetText()=="2"
    and normal.spendTextShadows[2]:GetText()=="2","actual native rank update must deliver the same amount to spend text and both shadows")
normal.nodeInfo={ranksPurchased=1,currentRank=1,maxRanks=1};normal:UpdateSpendText()
assert(normal.SpendText:GetText()=="" and normal.spendTextShadows[1]:GetText()=="","native single-rank suppression must remain")
normal.nodeInfo={ranksPurchased=0,currentRank=0,maxRanks=3};normal:UpdateSpendText()
assert(normal.SpendText:GetText()=="","native unpurchased nonselectable node must clear spend text")

for _,owner in ipairs({root,page,tree}) do
    owner.IsForbidden=function() return true end
    local excluded=button(tree.ButtonsParent);acquire(excluded)
    assert(excluded.SpendText.font=="NativeRank","forbidden Legacy owner must exclude newly acquired nodes")
    owner.IsForbidden=function() return false end
end
local forbidden=button(tree.ButtonsParent);forbidden.IsForbidden=function() return true end
acquire(forbidden);assert(forbidden.SpendText.font=="NativeRank","forbidden talent must remain native")
local borrowed=button(env.NewFrame("Frame"))
acquired(tree,borrowed);assert(borrowed.SpendText.font=="NativeRank","foreign node must not be styled by Legacy callback")
local replacement=env.NewFrame("Frame")
_G.LegacySystemFrame=replacement
local stale=button(tree.ButtonsParent);acquire(stale)
assert(stale.SpendText.font=="NativeRank","callback registered on stale root must not style nodes")
_G.LegacySystemFrame=root
page.LegacyTreeTraitPanel=replacement
local replaced=button(tree.ButtonsParent);acquire(replaced)
assert(replaced.SpendText.font=="NativeRank","callback registered on replaced panel must not style nodes")
print("Legacy native talent acquisition guards passed")
