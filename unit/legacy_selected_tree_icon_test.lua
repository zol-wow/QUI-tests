local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local corpus="tests/clients/forever/framexml/Interface/AddOns/"
local native=read(corpus.."Blizzard_LegacySystem/Blizzard_LegacyTree.lua")
local ring=read(corpus.."Blizzard_SharedXML/Shared/FrameTemplate/RingedFrameTemplate.lua")
_G.RingedMaskedButtonMixin={};_G.RingedFrameWithTooltipMixin={}
_G.SelectableButtonMixin={};_G.LegacyTreeIconMixin={};_G.LegacyTreeTraitPanelMixin={}
local function method(source,mixin,name)
    assert(loadstring(assert(source:match("(function "..mixin..":"..name.."%b().-\nend)"))))()
end
method(ring,"RingedFrameWithTooltipMixin","OnLoad")
for _,name in ipairs({"OnLoad","SetIconAtlas","SetEnabledState","OnMouseDown","OnMouseUp","UpdateHighlightTexture"}) do
    method(ring,"RingedMaskedButtonMixin",name)
end
method(read(corpus.."Blizzard_SharedXML/SelectableButton.lua"),"SelectableButtonMixin","OnLoad")
for _,name in ipairs({"OnLoad","OnClick","GetAppropriateTooltip"}) do method(native,"LegacyTreeIconMixin",name) end
method(native,"LegacyTreeTraitPanelMixin","SelectTree")
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);root.TreePage=page
local tree=env.NewFrame("Frame",nil,page);page.LegacyTreeTraitPanel=tree;tree.RegisterForWidgetSet=false
local icon=env.NewFrame("CheckButton",nil,tree);tree.SelectedTreeIcon=icon;icon.RegisterForWidgetSet=false
icon:SetSize(110,110);icon:SetFrameLevel(20)
for key,fn in pairs(_G.RingedMaskedButtonMixin) do icon[key]=fn end
for key,fn in pairs(_G.LegacyTreeIconMixin) do icon[key]=fn end
for _,key in ipairs({"NormalTexture","PushedTexture","HighlightTexture","CheckedTexture","CircleMask","DisabledOverlay","Ring"}) do
    local tex=icon:CreateTexture();icon[key]=tex;tex.masks={}
    function tex:AddMaskTexture(mask) self.masks[mask]=true end
    function tex:SetDesaturated(v) self.desaturated=v end
    function tex:SetAllPoints(target) self.allPoints=target end
end
icon.ringAtlas="Legacy-Tree-Frame-Ring-big";icon.ringWidth=130;icon.ringHeight=130
icon.checkedTextureSize=99;icon.circleMaskSizeOffset=2;icon.newTagYOffset=-5;icon.disabledOverlayAlpha=.75
icon.New=env.NewFrame("Frame",nil,icon);icon.Flash=env.NewFrame("Frame",nil,icon)
for _,key in ipairs({"Ring","Ring2","Portrait"}) do
    icon.Flash[key]=icon.Flash:CreateTexture()
    icon.Flash[key].AddMaskTexture=function(self,mask) self.mask=mask end
end
icon.BlackBG=false
icon.SelectedTreeLabel=icon:CreateFontString();icon.SelectedTreeLabel:SetTextColor(.9,.8,.1,1)
function icon:SetEnabled(v) self.enabled=v end
function icon:GetChecked() return self.checked==true end
function icon:SetNormalAtlas(atlas) self.NormalTexture:SetAtlas(atlas) end
function icon:SetPushedAtlas(atlas) self.PushedTexture:SetAtlas(atlas) end
function icon:GetNormalTexture() return self.NormalTexture end
function icon:GetPushedTexture() return self.PushedTexture end
function icon:CreateMaskTexture() return env.NewTexture(self,"MaskTexture") end
icon.enabled=true;icon.checked=false
icon:OnLoad()
local configs,trees,updates=0,0,0
_G.LegacyTreeData={{treeID=42,iconAtlas="tree-first",name="First"},{treeID=84,iconAtlas="tree-second",name="Second"}}
_G.C_Traits={GetConfigIDByTreeID=function(id) return id+1 end}
function tree:SetConfigID(id) configs=configs+1;self.configID=id end
function tree:SetTalentTreeID(id,force) trees=trees+1;self.treeID=id;self.force=force end
function tree:UpdateConfigButtonsState() updates=updates+1 end
tree.SelectTree=_G.LegacyTreeTraitPanelMixin.SelectTree
tree:SelectTree(1)
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local chrome=skin.GetBackdrop(icon)
assert(chrome and chrome._quiRoundedSurface and icon.Ring:GetAlpha()==0,
    "legacy selected-tree display must replace oversized native ring with bounded QUI chrome")
assert(icon:GetWidth()==110 and icon.Ring:GetWidth()==130 and chrome:GetFrameLevel()==19
    and icon.NormalTexture.atlas=="tree-first" and icon.PushedTexture.atlas=="tree-first"
    and icon.NormalTexture.masks[icon.CircleMask] and icon.PushedTexture.masks[icon.CircleMask]
    and icon.DisabledOverlay.masks[icon.CircleMask] and icon.Flash.Portrait.mask==icon.CircleMask
    and icon.SelectedTreeLabel:GetText()=="First" and icon.SelectedTreeLabel.textColor[1]==.9,
    "native icon art, full Ringed OnLoad masks, dimensions and label must remain")
tree:SelectTree(2)
assert(tree.configID==85 and tree.treeID==84 and tree.force and tree.selectedTreeIdx==2
    and icon.NormalTexture.atlas=="tree-second" and icon.Flash.Portrait.atlas=="tree-second"
    and icon.SelectedTreeLabel:GetText()=="Second" and configs==2 and trees==2 and updates==2,
    "native SelectTree must retain provider/config/tree/art/label actions without extra calls")
icon:SetEnabledState(false)
assert(not icon.enabled and icon.NormalTexture.desaturated and icon.DisabledOverlay:IsShown()
    and icon.DisabledOverlay:GetAlpha()==.75 and icon.Ring.atlas=="Legacy-Tree-Frame-Ring-big-disabled",
    "native disabled state and overlay semantics must remain")
icon:SetEnabledState(true);icon:OnMouseDown("LeftButton")
local point=icon.CircleMask.points[#icon.CircleMask.points]
assert(point[2]==icon.PushedTexture and icon.CheckedTexture.allPoints==icon
    and icon.HighlightTexture.allPoints==icon,
    "native press must shift the circle mask while replacement state chrome stays bounded")
icon:OnMouseUp("LeftButton");point=icon.CircleMask.points[#icon.CircleMask.points]
assert(point[2]==icon.NormalTexture and not icon.NormalTexture.desaturated,
    "native release must restore the icon mask")
icon:OnClick();assert(configs==2 and updates==2 and not icon.selected and icon:GetAppropriateTooltip()==nil,
    "selected-tree display must retain no-op click and absent tooltip")
registry.skinLegacySystem.refresh()
assert(skin.GetBackdrop(icon)==chrome and configs==2 and trees==2 and updates==2,
    "theme must reuse chrome without tree/provider actions")
env.profile.general.skinLegacySystem=false;icon.SelectedTreeLabel:SetFont("Native",12,"")
icon:SetIconAtlas("disabled-update")
assert(icon.SelectedTreeLabel.font=="Native" and icon.NormalTexture.atlas=="disabled-update",
    "disabled skin must preserve native icon updates without typography override")
env.profile.general.skinLegacySystem=true;icon.IsForbidden=function() return true end
icon:UpdateHighlightTexture();assert(icon.SelectedTreeLabel.font=="Native","forbidden display must be excluded")
print("Legacy selected-tree native icon, press, disabled and no-op states passed")
