local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinInspectFrame=true;env.profile.character={enabled=false}
local root=env.NewFrame("Frame");_G.InspectFrame=root;root.CloseButton=false
local model=env.NewFrame("PlayerModel",nil,root);_G.InspectModelFrame=model;model.rotation=0
local controls=env.NewFrame("Frame",nil,model);model.controlFrame=controls;controls:SetAlpha(.5);controls:Hide()
local nativeBg=controls:CreateTexture();nativeBg:SetTexture("native-control-panel")
_G.CreateFromMixins=function(...)
 local result={}
 for _,mixin in ipairs({...}) do for key,value in pairs(mixin) do result[key]=value end end
 return result
end
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Mainline/ModelControlButtonMixin.lua"))()
local sounds,zooms,pans,resets,rotations=0,0,0,0,0
_G.ZOOM_IN="Native zoom in";_G.ZOOM_OUT="Native zoom out";_G.DRAG_MODEL="Native pan";_G.RESET_POSITION="Native reset"
_G.ROTATE_LEFT="Native left";_G.ROTATE_RIGHT="Native right";_G.DRAG_MODEL_TOOLTIP="Native pan help";_G.ROTATE_TOOLTIP="Native rotate help"
_G.SOUNDKIT={IG_INVENTORY_ROTATE_CHARACTER=1};_G.PlaySound=function() sounds=sounds+1 end
function model:OnMouseWheel(amount) zooms=zooms+amount end
function model:StartPanning(owner) assert(owner==_G.ModelPanningFrame);pans=pans+1 end
function model:ResetModel() resets=resets+1 end
function model:SetRotation(value) self.lastRotation=value;rotations=rotations+1 end
_G.ModelPanningFrame={}
_G.GetCVar=function() return "1" end
_G.HIGHLIGHT_FONT_COLOR={r=1,g=1,b=1}
_G.GameTooltip={SetText=function(self,text) self.text=text end,AddLine=function(self,text) self.help=text end,
 Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
_G.GameTooltip_SetDefaultAnchor=function() end
local types={_G.ModelControlZoomButtonMixin,_G.ModelControlZoomButtonMixin,_G.ModelControlPanButtonMixin,
 _G.ModelControlRotateButtonMixin,_G.ModelControlRotateButtonMixin,_G.ModelControlResetButtonMixin}
local buttons={}
for i,mixin in ipairs(types) do
 local b=env.NewFrame("Button",nil,controls);b.RegisterForWidgetSet=false;b.DisabledTexture=false;b:SetSize(18,18)
 b.bg=b:CreateTexture();b.icon=b:CreateTexture();b.icon:SetTexture("native-control-glyph")
 b.zoomIn=i==1;b.rotateDirection=i==4 and "left" or "right"
 for key,method in pairs(mixin) do b[key]=method end
 b:OnLoad()
 for _,script in ipairs({"OnClick","OnMouseDown","OnMouseUp","OnEnter","OnLeave"}) do b:SetScript(script,b[script]) end
 buttons[i]=b
end
local click=buttons[1]:GetScript("OnClick");local uv=buttons[1].icon.texCoord[1]
local setup;skin.OnAddOnLoaded=function(_,fn) setup=fn end
assert(loadfile(arg[1] or "modules/skinning/frames/inspect.lua"))("QUI",ns);setup()
assert(nativeBg:GetAlpha()==0,"inspect model toolbar must suppress native panel chrome")
for _,b in ipairs(buttons) do
 assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface and b.icon:GetAlpha()==1 and b.bg:GetAlpha()==0,
 "each model control must receive rounded chrome while preserving native glyph")
 assert(b.icon.texture=="native-control-glyph" and b:GetWidth()==18,"native glyph and control geometry must remain")
end
assert(not controls:IsShown() and controls:GetAlpha()==.5 and buttons[1].icon.texCoord[1]==uv,
 "native toolbar visibility, fade opacity and glyph UVs must remain")
buttons[1]:Fire("OnClick");buttons[2]:Fire("OnClick")
assert(zooms==0,"native zoom in/out must retain opposite signed amounts")
buttons[4]:Fire("OnClick");buttons[5]:Fire("OnClick")
assert(rotations==2 and math.abs(model.lastRotation)<.00001,"native rotation controls must retain opposite increments")
buttons[6]:Fire("OnClick");assert(resets==1,"native reset must run once")
local pan=buttons[3];pan:Fire("OnMouseDown")
assert(pans==1 and controls.buttonDown==pan and pan.icon.points[1][2]==1,"native pressed offset and pan ownership must remain")
_G.ModelControlFrameMixin.OnHide(controls)
assert(controls.buttonDown==nil and pan.icon.points[#pan.icon.points][2]==0,"native toolbar hide must release pressed control")
pan:Fire("OnEnter")
assert(controls:GetAlpha()==1 and _G.GameTooltip.text=="Native pan","native toolbar hover and tooltip must remain")
pan:Fire("OnLeave");assert(controls:GetAlpha()==.5 and not _G.GameTooltip.shown,"native leave must restore toolbar fade")
local before=sounds;_G.QUI_RefreshInspectColors()
assert(sounds==before and resets==1 and pans==1 and buttons[1]:GetScript("OnClick")==click,
 "theme must preserve native handlers without model callbacks")
controls.IsForbidden=function() return true end;nativeBg:SetAlpha(.6);_G.QUI_RefreshInspectColors()
assert(nativeBg:GetAlpha()==.6,"forbidden toolbar must stop styling")
print("inspect model controls passed")
