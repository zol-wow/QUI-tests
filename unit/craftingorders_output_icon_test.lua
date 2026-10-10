local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local output=frame("Button",form);form.OutputIcon=output
output:SetSize(47,47)
function output:CreateMaskTexture() return env.NewTexture(output,"MaskTexture") end
for _,key in ipairs({"Icon","CircleMask","IconBorder","IconOverlay","IconOverlay2","CountShadow"}) do
 output[key]=output:CreateTexture()
end
output.Count=output:CreateFontString();output.Count:SetTextColor(1,.2,.2,1)
function output.Count:SetFormattedText(format,...) self:SetText(string.format(format,...)) end
local highlight=output:CreateTexture();highlight:SetAtlas("native-circle-highlight")
function output:GetHighlightTexture() return highlight end
function output.IconBorder:GetAtlas() return self.atlas end
local adds,removes=0,0
for _,texture in ipairs({output.Icon,highlight}) do
 function texture:AddMaskTexture() adds=adds+1 end
end
function output.Icon:RemoveMaskTexture(mask) assert(mask==output.CircleMask);removes=removes+1 end
local colors={[0]={.7,.7,.7,1},[3]={0,.44,1,1},[4]={.64,.21,.93,1}}
_G.ColorManager={}
function ColorManager.GetAtlasDataForAuctionHouseItemQuality(quality) return {atlas="quality-"..quality} end
function ColorManager.GetColorDataForItemQuality(quality)
 local value=colors[quality]
 return value and {color={GetRGBA=function() return unpack(value) end}}
end
_G.ClearItemButtonOverlay=function(button)
 button.IconOverlay:Hide();button.IconOverlay2:Hide();button.isProfessionItem=false;button.isCraftedItem=false
end
_G.SetItemButtonBorder=function(button,atlas)
 button.IconBorder:SetShown(atlas~=nil)
 if atlas then button.IconBorder:SetAtlas(atlas) end
end
_G.SetItemButtonBorderVertexColor=function(button,...) button.IconBorder:SetVertexColor(...) end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local native=read("tests/framexml/Interface/AddOns/Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua")
_G.CircularGiantItemButtonMixin={}
assert(loadstring(assert(native:match("(function CircularGiantItemButtonMixin:SetItemButtonQuality%b().-\nend)"))))()
output.SetItemButtonQuality=_G.CircularGiantItemButtonMixin.SetItemButtonQuality
_G.SetItemButtonQuality=function(button,...) button:SetItemButtonQuality(...) end
_G.Professions={}
native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_Professions.lua")
assert(loadstring(assert(native:match("(function Professions.SetupOutputIconCommon%b().-\nend)"))))()
_G.Lerp=function(a,b,t) return a+(b-a)*t end
function output.Count:GetWidth() return self.wide and 50 or 20 end
_G.Professions.SetupOutputIconCommon(output,2,5,"native-first-icon","native-link",4)
local cleared=arg[2]=="cleared"
if cleared then output:SetItemButtonQuality(nil) end
local enter=function() end;local click=function() error("output click invoked by styling") end
output:SetScript("OnEnter",enter);output:SetScript("OnClick",click)
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local border=assert(skin.GetFrameData(output.Icon,"iconBorder"),"output icon must receive QUI border")
assert(adds==2 and removes>=1 and output.IconBorder:GetAlpha()==0 and highlight.texture=="Interface\\Buttons\\WHITE8x8",
 "native circle decoration must become rounded icon and highlight")
local expectedR=cleared and skin.GetWindowColors() or .64
assert(border._quiBorderR==expectedR and output.Icon.texture=="native-first-icon" and output.Count:GetText()=="2-5"
 and output.CountShadow:IsShown(),"pre-skin item art, quantity range and visible/cleared quality must remain")
_G.Professions.SetupOutputIconCommon(output,1,1,"native-second-icon","native-link",3)
assert(border._quiBorderG==.44 and output.Icon.texture=="native-second-icon"
 and output.Count:GetText()=="" and not output.CountShadow:IsShown(),"native quality rebind and singleton quantity must remain")
output.Count.wide=true
_G.Professions.SetupOutputIconCommon(output,2,10,"native-third-icon","native-link",0)
assert(output.Count:GetText()=="~6" and output.CountShadow:IsShown(),"native wide quantity abbreviation must remain")
output:SetItemButtonQuality(nil)
local sr=skin.GetWindowColors()
assert(border._quiBorderR==sr and not output.IconBorder:IsShown(),"cleared quality must return neutral without reading stale native atlas")
output:Hide();_G.QUI_RefreshCraftingOrdersColors()
assert(not output:IsShown() and output:GetWidth()==47 and output:GetHeight()==47 and adds==2
 and output.Count.textColor[2]==.2 and output:GetScript("OnEnter")==enter and output:GetScript("OnClick")==click,
 "theme must preserve visibility, geometry, masks, count colors and native handlers")
env.profile.general.skinCraftingOrders=false
output:SetItemButtonQuality(4);_G.QUI_RefreshCraftingOrdersColors()
assert(border._quiBorderR==sr and adds==2,"disabled skin must stop output styling")
print("craftingorders output icon passed")
