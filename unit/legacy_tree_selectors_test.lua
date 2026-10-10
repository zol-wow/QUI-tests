local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
ns.Helpers.GetSkinBorderColor=function() return .9,.1,.1,1 end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local corpus="tests/clients/forever/framexml/Interface/AddOns/"
local legacy=read(corpus.."Blizzard_LegacySystem/Blizzard_LegacyTree.lua")
local ring=read(corpus.."Blizzard_SharedXML/Shared/FrameTemplate/RingedFrameTemplate.lua")
_G.LegacyTreeSelectionPanelMixin={};_G.LegacyTreeButtonMixin={};_G.RingedMaskedButtonMixin={}
local function method(source,mixin,name)
    assert(loadstring(assert(source:match("(function "..mixin..":"..name.."%b().-\nend)"))))()
end
for _,name in ipairs({"RefreshTreeButtons","UpdateSelection"}) do method(legacy,"LegacyTreeSelectionPanelMixin",name) end
for _,name in ipairs({"OnSelected","RefreshSelectionVisuals","SetupLegacyTreeButton","OnClick"}) do method(legacy,"LegacyTreeButtonMixin",name) end
for _,name in ipairs({"SetIconAtlas","SetEnabledState","UpdateHighlightTexture"}) do method(ring,"RingedMaskedButtonMixin",name) end
local selectedCalls,sounds,events=0,0,{}
_G.SelectableButtonMixin={OnClick=function() selectedCalls=selectedCalls+1 end}
_G.SOUNDKIT={IG_CHARACTER_INFO_TAB=1};_G.PlaySound=function() sounds=sounds+1 end
_G.EventRegistry={TriggerEvent=function(_,key,index) events[#events+1]={key,index} end}
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);root.TreePage=page
local panel=env.NewFrame("Frame",nil,page);panel.RegisterForWidgetSet=false;page.LegacyTreeSelectionPanel=panel
for key,fn in pairs(_G.LegacyTreeSelectionPanelMixin) do panel[key]=fn end
local selections=env.NewFrame("Frame",nil,panel);panel.TreeSelections=selections
local layouts=0;function selections:Layout() layouts=layouts+1 end
local free,active,made={},{},0
local pool={};panel.treeButtonPool=pool
function pool:ReleaseAll() for _,b in ipairs(active) do b:Hide();free[#free+1]=b end;active={} end
function pool:Acquire(template)
    assert(template=="LegacyTreeButtonTemplate")
    local b=table.remove(free)
    if not b then
        made=made+1;b=env.NewFrame("CheckButton",nil,selections);b.RegisterForWidgetSet=false;b:SetSize(67,67)
        for key,fn in pairs(_G.RingedMaskedButtonMixin) do b[key]=fn end
        for key,fn in pairs(_G.LegacyTreeButtonMixin) do b[key]=fn end
        for _,key in ipairs({"Background","Ring","SelectedGlow","CheckedTexture","HighlightTexture","NormalTexture","PushedTexture","DisabledOverlay","CircleMask"}) do
            b[key]=b:CreateTexture();b[key].masks={}
            b[key].GetAtlas=function(self) return self.atlas end
        end
        b.Background:SetSize(142,93);b.Ring:SetSize(70,70);b.ringAtlas="Legacy-Tree-Frame-Card-Ring"
        b.highlightAtlas=b.ringAtlas;b.DisabledOverlay:SetAlpha(.75);b.CheckedTexture:SetAlpha(0)
        b.NormalTexture.masks[b.CircleMask]=true;b.PushedTexture.masks[b.CircleMask]=true
        function b:GetNormalTexture() return self.NormalTexture end
        function b:GetPushedTexture() return self.PushedTexture end
        function b:SetNormalAtlas(atlas) self.NormalTexture:SetAtlas(atlas) end
        function b:SetPushedAtlas(atlas) self.PushedTexture:SetAtlas(atlas) end
        function b.NormalTexture:SetDesaturated(v) self.desaturated=v end
        function b.PushedTexture:SetDesaturated(v) self.desaturated=v end
        function b:GetChecked() return self.checked==true end
        function b:SetChecked(v) self.checked=v end
        function b:SetEnabled(v) self.enabled=v end
        b.enabled=true;b.Flash={Portrait=b:CreateTexture()}
        function b:ClearTooltipLines() self.lines={} end
        function b:AddTooltipLine(text) self.lines[#self.lines+1]=text end
        function b:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
        function b.HighlightTexture:AddMaskTexture(mask) self.roundMask=mask end
        function b.HighlightTexture:SetAllPoints(target) self.allPoints=target end
        b:SetScript("OnClick",b.OnClick)
    end
    active[#active+1]=b;return b
end
_G.LegacyTreeData={{name="First",iconAtlas="tree-first"},{name="Second",iconAtlas="tree-second"}}
panel:RefreshTreeButtons()
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local first=panel.treeButtons[1];local shell=skin.GetBackdrop(first)
assert(shell and shell._quiRoundedSurface and first.Background:GetAlpha()==0 and first.Ring:GetAlpha()==0,
    "legacy selectors must receive rounded bounded chrome without stripping icon textures")
assert(first:GetWidth()==67 and first.Background:GetWidth()==142 and first.NormalTexture.atlas=="tree-first"
    and first.PushedTexture.atlas=="tree-first" and first.NormalTexture:GetAlpha()==1
    and first.NormalTexture.masks[first.CircleMask] and first.lines[1]=="First",
    "native icon art/mask, tooltip name and hit/background geometry must remain")
panel:UpdateSelection(1)
assert(first:GetChecked() and first.SelectedGlow:IsShown() and first.SelectedGlow:GetAlpha()==0
    and shell._quiBorderR==.9 and first.HighlightTexture.allPoints==first and first.HighlightTexture.roundMask,
    "native selected state/glow visibility must remain with bounded QUI selection/hover")
panel:UpdateSelection(2);assert(not first:GetChecked() and shell._quiBorderR==env.colors[1],
    "native deselection must reset selector border")
first:SetEnabledState(false)
assert(not first.enabled and first.DisabledOverlay:IsShown() and first.DisabledOverlay:GetAlpha()==.75
    and first.NormalTexture.desaturated and first.Ring.atlas=="Legacy-Tree-Frame-Card-Ring-disabled",
    "native disabled overlay/desaturation/atlas semantics must remain")
first:SetEnabledState(true)
assert(not first.DisabledOverlay:IsShown() and not first.NormalTexture.desaturated,"native reenable must restore icon state")
first:Fire("OnClick")
assert(selectedCalls==1 and sounds==1 and events[1][1]=="Legacy.SelectTree" and events[1][2]==1,
    "native selector click must retain base selection, sound and event/index")
panel:RefreshTreeButtons();registry.skinLegacySystem.refresh()
assert(made==2 and layouts==2 and selectedCalls==1 and sounds==1 and #events==1,
    "native pooled rebuild and theme must not allocate unnecessarily or emit selections")
env.profile.general.skinLegacySystem=false
first.HighlightTexture:SetColorTexture(.3,.4,.5,1);first:RefreshSelectionVisuals()
assert(first.HighlightTexture.color[1]==.3,"disabled selector must stop hover overrides")
env.profile.general.skinLegacySystem=true;first.parent=_G.UIParent
first:RefreshSelectionVisuals();assert(first.HighlightTexture.color[1]==.3,"borrowed selector must retain presentation")
print("Legacy native selector pooled state controls passed")
