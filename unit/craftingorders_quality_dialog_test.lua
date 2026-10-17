local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false
 function f:SetEnabled(value) self.enabled=value end
 return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local dialog=frame(nil,form);form.QualityDialog=dialog
dialog:SetSize(329,207);dialog:Hide()
dialog.NineSlice=frame(nil,dialog)
dialog.Background=dialog:CreateTexture();dialog.Background:SetAtlas("Professions-QualityWindow-Background")
dialog.TitleText=dialog:CreateFontString()
function dialog:SetTitle(text) self.TitleText:SetText(text) end
for _,key in ipairs({"ClosePanelButton","AcceptButton","CancelButton"}) do dialog[key]=frame("Button",dialog) end
local allocationsChanged,accepted,sounds=0,0,0
_G.CreateFromMixins=function(base) local t={} for k,v in pairs(base) do t[k]=v end return t end
_G.CallbackRegistryMixin={}
function CallbackRegistryMixin:GenerateCallbackEvents() self.Event={Accepted="Accepted"} end
function CallbackRegistryMixin:OnLoad() end
function dialog:TriggerEvent() accepted=accepted+1 end
function dialog:UnregisterEvents() self.unregistered=true end
_G.PROFESSIONS_QUALITY_DIALOG_TITLE="Native quality selection"
_G.CANCEL="Native cancel";_G.ACCEPT="Native accept"
_G.SOUNDKIT={UI_PROFESSION_QUALITY_DIALOG_EXIT=1,UI_PROFESSION_QUALITY_DIALOG_CONFIRM=2}
_G.PlaySound=function() sounds=sounds+1 end
_G.Clamp=function(value,min,max) return math.max(min,math.min(max,value)) end
_G.GetEditBoxMetatable=function() return {__index={SetEnabled=function(self,value) self.enabled=value end}} end
_G.NumericInputSpinnerMixin={}
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local native=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua")
for _,key in ipairs({"SetValue","SetMinMaxValues","GetValue","SetEnabled"}) do
 assert(loadstring(assert(native:match("(function NumericInputSpinnerMixin:"..key.."%b().-\nend)"))))()
end
_G.ProfessionsUtil={GetReagentQuantityInPossession=function(reagent) return reagent.count end}
_G.ProfessionsButtonMixin={}
native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTemplates.lua")
for _,key in ipairs({"SetSlotQuality","SetReagent"}) do
 assert(loadstring(assert(native:match("(function ProfessionsButtonMixin:"..key.."%b().-\nend)"))))()
end
_G.TextureKitConstants={IgnoreAtlasSize=true}
_G.ColorManager={}
function ColorManager.GetAtlasDataForProfessionsItemQuality(quality) return {atlas="native-quality-"..quality} end
function ColorManager.GetColorDataForItemQuality(quality)
 local c=quality==4 and {.64,.21,.93,1} or {0,.44,1,1}
 return {color={GetRGBA=function() return unpack(c) end}}
end
local items={}
local masks=0
for index=1,3 do
 local c=frame(nil,dialog);dialog["Container"..index]=c;c:SetSize(100,75)
 local button=frame("Button",c);c.Button=button
 button.Icon=button:CreateTexture();button.QualityOverlay=button:CreateTexture();button.QualityOverlay:SetAtlas("native-rank-"..index)
 button.IconBorder=button:CreateTexture();button.IconBorder:Hide()
 button.SlotBackground=button:CreateTexture();button.Count=button:CreateFontString();button.Count:SetTextColor(1,.1,.1,1)
 function button.IconBorder:GetAtlas() return self.atlas end
 function button:CreateMaskTexture() return env.NewTexture(button,"MaskTexture") end
 function button.Icon:AddMaskTexture() masks=masks+1 end
 function button:SetItem(itemID) self.itemID=itemID;self.Icon:SetTexture(items[itemID].icon) end
 function button:GetItemInfo() return "Native reagent",items[self.itemID].quality end
 for key,method in pairs(_G.ProfessionsButtonMixin) do button[key]=method end
 function button:SetItemButtonCount(count) self.count=count;self.Count:SetText(tostring(count)) end
 function button:DesaturateHierarchy(value) self.desaturation=value end
 local edit=frame("EditBox",c);c.EditBox=edit
 edit.IncrementButton=frame("Button",edit);edit.DecrementButton=frame("Button",edit)
 function edit:SetFont(path,size,flags) self.font=path;self.fontSize=size;self.fontFlags=flags end
 function edit:GetFont() return self.font,self.fontSize,self.fontFlags end
 function edit:SetFontObject(name) self:SetFont(name,14,"") end
 function edit:SetNumber(value) self.number=value;self:SetText(tostring(value)) end
 function edit:GetNumber() return self.number or 0 end
 for key,method in pairs(_G.NumericInputSpinnerMixin) do edit[key]=method end
 edit:SetFont("Native input",14,"")
end
native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsQualityDialog.lua")
assert(loadstring(native,"@native-quality-dialog"))()
for key,method in pairs(_G.ProfessionsQualityDialogMixin) do dialog[key]=method end
dialog:OnLoad()
local input=dialog.Container1.EditBox
local enter=input:GetScript("OnEnterPressed");local changed=input:GetScript("OnTextChanged")
local accept=dialog.AcceptButton:GetScript("OnClick");local cancel=dialog.CancelButton:GetScript("OnClick")
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
assert(skin.GetBackdrop(dialog) and skin.GetBackdrop(dialog)._quiRoundedSurface and dialog.Background:GetAlpha()==0,
 "quality dialog must receive rounded QUI shell and suppress native background")
assert(skin.GetBackdrop(input) and input:GetFont()==ns.Helpers.GetGeneralFont()
 and skin.GetBackdrop(input.IncrementButton) and skin.GetBackdrop(input.DecrementButton),
 "quality allocation input and spinner controls must receive QUI chrome")
local quantities={}
local allocation={}
function allocation:Accumulate() local n=0 for _,value in pairs(quantities) do n=n+value end return n end
function allocation:GetQuantityAllocated(reagent) return quantities[reagent] or 0 end
function allocation:Allocate(reagent,value) quantities[reagent]=value;allocationsChanged=allocationsChanged+1 end
local reagents={{itemID=101,quality=3,count=8,icon="native-first"},{itemID=102,quality=4,count=0,icon="native-second"}}
for _,reagent in ipairs(reagents) do items[reagent.itemID]=reagent end
local schematic={quantityRequired=5,reagents=reagents}
dialog:Open(123,schematic,allocation,1,true,true)
assert(dialog:IsShown() and dialog.Container1:IsShown() and dialog.Container2:IsShown()
 and not dialog.Container3:IsShown() and not dialog.AcceptButton:IsEnabled(),"native setup must retain roster and incomplete allocation eligibility")
assert(input.min==0 and input.max==5 and input.enabled
 and not dialog.Container2.EditBox.enabled and dialog.Container2.Button.desaturation==1,
 "native spinner limits, inventory availability and desaturation must remain")
assert(dialog.Container1.Button.Icon.texture=="native-first" and dialog.Container1.Button.QualityOverlay.atlas=="native-rank-1",
 "item art and native quality overlay must survive dialog styling")
local itemBorder=assert(skin.GetFrameData(dialog.Container1.Button.Icon,"iconBorder"),"quality dialog item buttons must receive QUI borders")
assert(itemBorder._quiRoundedSurface and itemBorder._quiBorderG==.44
 and dialog.Container1.Button.IconBorder:GetAlpha()==0 and masks==3
 and dialog.Container1.Button.Count:GetText()=="8" and dialog.Container2.Button.Count:GetText()=="0",
 "native quality, denomination-tier counts and hidden third-tier mask must remain")
input:SetText("5");enter(input)
assert(allocationsChanged==1 and dialog.AcceptButton:IsEnabled() and quantities[reagents[1]]==5,
 "native Enter callback must allocate and update eligibility once")
local count=allocationsChanged
_G.QUI_RefreshCraftingOrdersColors()
assert(allocationsChanged==count and accepted==0 and sounds==0 and input:GetScript("OnEnterPressed")==enter
 and input:GetScript("OnTextChanged")==changed and dialog.AcceptButton:GetScript("OnClick")==accept
 and dialog.CancelButton:GetScript("OnClick")==cancel,"theme must not allocate, accept, cancel or replace native handlers")
reagents[1].quality=4;dialog:ReinitAllocations(allocation)
assert(itemBorder._quiBorderR==.64 and masks==3 and not dialog.Container2.EditBox.enabled
 and dialog.Container1.Button.Count.textColor[2]==.1,
 "native dialog setup reuse must update item quality and preserve availability/count color without new masks")
dialog:Close();dialog:OnHide()
assert(not dialog:IsShown() and dialog.recipeID==nil and dialog.allocations==nil and dialog.unregistered,
 "native close/hide must retain cleanup")
print("craftingorders quality dialog passed")
