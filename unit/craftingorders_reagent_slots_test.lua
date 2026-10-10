local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
_G.ProfessionsButtonMixin={}
local native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTemplates.lua")
for _,key in ipairs({"SetSlotQuality","SetReagent"}) do
 assert(loadstring(assert(native:match("(function ProfessionsButtonMixin:"..key.."%b().-\nend)"))))()
end
_G.ProfessionsReagentSlotButtonMixin={}
native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeReagentSlotBase.lua")
for _,key in ipairs({"GetReagent","SetReagent","Init","Clear","Update","SetLocked","SetModifyingRequired","UpdateOverlay","UpdateCursor"}) do
 assert(loadstring(assert(native:match("(function ProfessionsReagentSlotButtonMixin:"..key.."%b().-\nend)"))))()
end
_G.TextureKitConstants={IgnoreAtlasSize=true}
_G.ColorManager={}
function ColorManager.GetAtlasDataForProfessionsItemQuality(q) return {atlas="native-quality-"..q} end
function ColorManager.GetColorDataForItemQuality(q)
 local color=q==4 and {.64,.21,.93,1} or {0,.44,1,1}
 return {color={GetRGBA=function() return unpack(color) end}}
end
_G.C_CurrencyInfo={GetCurrencyInfo=function() return {quality=4,iconFileID="native-currency-icon"} end}
local adds=0
local function slot()
 local s=frame(nil,form);s.Name=s:CreateFontString();s.Name:SetText("|cffff1111Native warning|r")
 s.Checkbox=frame("CheckButton",s);s.Checkbox:Hide()
 function s.Checkbox:GetChecked() return self.checked end
 function s.Checkbox:SetChecked(value) self.checked=value end
 local b=frame("ItemButton",s);s.Button=b
 b:SetSize(39,39)
 function b:CreateMaskTexture() return env.NewTexture(b,"MaskTexture") end
 for _,key in ipairs({"Icon","IconBorder","SlotBackground","CropFrame","QualityOverlay","AddIcon","ColorOverlay","HighlightTexture"}) do b[key]=b:CreateTexture() end
 b.IconBorder:Hide();b.Count=b:CreateFontString();b.Count:SetTextColor(1,.1,.1,1)
 function b.IconBorder:GetAtlas() return self.atlas end
 function b.Icon:AddMaskTexture() adds=adds+1 end
 b.normal=b:CreateTexture();b.pushed=b:CreateTexture();b.highlightBase=b:CreateTexture();b.highlight=b.highlightBase
 function b.highlightBase:AddMaskTexture() adds=adds+1 end
 function b:GetNormalTexture() return self.normal end
 function b:GetPushedTexture() return self.pushed end
 function b:GetHighlightTexture() return self.highlight end
 function b:SetNormalAtlas(asset) self.normal:SetAtlas(asset) end
 function b:SetPushedAtlas(asset) self.pushed:SetAtlas(asset) end
 function b:SetNormalTexture(asset) self.normal:SetTexture(asset) end
 function b:SetPushedTexture(asset) self.pushed:SetTexture(asset) end
 function b:SetHighlightTexture(asset) self.highlight=self.highlightBase;self.highlight:SetTexture(asset) end
 function b:ClearHighlightTexture() self.highlight=nil end
 b.InputOverlay=frame(nil,b)
 for _,key in ipairs({"AddIcon","AddIconHighlight","LockedIcon"}) do
  b.InputOverlay[key]=b.InputOverlay:CreateTexture();b.InputOverlay[key]:SetAtlas("native-"..key)
 end
 function b:IsMouseMotionFocus() return false end
 function b:SetItem(value) self.Icon:SetTexture(value);if not value then self.IconBorder:Hide() end end
 function b:GetItemInfo() return "Native item",3 end
 function b:SetItemButtonCount(value) self.Count:SetText(tostring(value)) end
 for key,method in pairs(_G.ProfessionsButtonMixin) do b[key]=method end
 for key,method in pairs(_G.ProfessionsReagentSlotButtonMixin) do b[key]=method end
 b:Init();b:SetModifyingRequired(false);b:SetReagent({itemID=123})
 b.QualityOverlay:SetAtlas("native-reagent-rank")
 b.ColorOverlay:SetVertexColor(1,.1,.1,.3);b.ColorOverlay:Show()
 s.CustomerState=s:CreateTexture();s.CustomerState:SetAtlas("native-customer-state")
 return s
end
local first=slot()
local active={first}
form.reagentSlotPool={}
function form.reagentSlotPool:EnumerateActive()
 local n=0;return function() n=n+1;return active[n] end
end
local updates=0
function form:UpdateReagentSlots() updates=updates+1 end
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local b=first.Button
local border=assert(skin.GetFrameData(b.Icon,"iconBorder"),"reagent slot must receive QUI item border")
assert(border._quiRoundedSurface and border._quiBorderG==.44 and b.Icon.texture==123 and b.IconBorder:GetAlpha()==0,
 "native populated slot must retain item quality and art within rounded chrome")
assert(b.normal:GetAlpha()==0 and b.pushed:GetAlpha()==0 and b.SlotBackground:GetAlpha()==0 and adds==2,
 "standard decorative slot art must be replaced without duplicate masks")
b:SetModifyingRequired(true)
assert(b.normal.atlas=="itemupgrade_greenplusicon" and b.normal:GetAlpha()==1
 and b.pushed.atlas=="itemupgrade_greenplusicon_pressed" and b.pushed:GetAlpha()==1 and not b:GetHighlightTexture(),
 "native modifying-required plus icons must remain functional and visible")
b:SetLocked(true)
assert(b.InputOverlay.LockedIcon:IsShown() and not b.InputOverlay.AddIcon:IsShown(),
 "native locked overlay must remain")
b:SetLocked(false);b:SetModifyingRequired(false);b:Clear()
local sr=skin.GetWindowColors()
assert(b.InputOverlay.AddIcon:IsShown() and not b.InputOverlay.LockedIcon:IsShown()
 and b.Icon.texture==nil and border._quiBorderR==sr and b.normal:GetAlpha()==0,
 "native cleared ordinary slot must retain add overlay and neutral rounded border")
b:SetReagent({currencyID=7})
assert(b.Icon.texture=="native-currency-icon" and border._quiBorderR==.64
 and not b.InputOverlay.AddIcon:IsShown(),"native currency icon/quality reuse must remain")
assert(first.Name:GetText()=="|cffff1111Native warning|r" and b.Count.textColor[2]==.1
 and b.QualityOverlay.atlas=="native-reagent-rank" and b.ColorOverlay:IsShown()
 and first.CustomerState.atlas=="native-customer-state" and not first.Checkbox:IsShown(),
 "inline name/count colors, rank, warning, customer state and checkbox visibility must remain")
local second=slot();active={second};form:UpdateReagentSlots()
assert(skin.GetFrameData(second.Button.Icon,"iconBorder") and updates==1,
 "new active pool slots must be styled after native update")
_G.ProfessionsReagentSlotMixin={}
native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeReagentSlot.lua")
for _,key in ipairs({"GetNameColor","SetNameText","UpdateQualityOverlay","Update"}) do
 assert(loadstring(assert(native:match("(function ProfessionsReagentSlotMixin:"..key.."%b().-\nend)"))))()
 second[key]=_G.ProfessionsReagentSlotMixin[key]
end
_G.Enum={CraftingReagentType={Optional=1}}
local function color(prefix) return {WrapTextInColorCode=function(_,text) return prefix..text.."|r" end} end
_G.HIGHLIGHT_FONT_COLOR=color("|cffffffff")
_G.DISABLED_REAGENT_COLOR=color("|cff777777")
_G.Professions={ReagentInputMode={Quality=1}}
function Professions.GetReagentInputMode() return 1 end
function Professions.GetReagentQualityInfo(reagent)
 return {iconInventory="native-rank-"..reagent.rank,iconMixed="native-mixed-ranks"}
end
_G.ProfessionsUtil={GetReagentQuantityInPossession=function(reagent) return reagent.count end}
_G.TextureKitConstants.UseAtlasSize=true
local tier1={rank=1,count=2};local tier2={rank=2,count=3}
local schematic={slotIndex=1,reagentType=0,reagents={tier1,tier2}}
local allocations={}
local transaction={}
function transaction:HasAnyAllocations() return #allocations>0 end
function transaction:ShouldUseCharacterInventoryOnly() return true end
function transaction:EnumerateAllocations() return ipairs(allocations) end
function second:GetTransaction() return transaction end
function second:GetReagentSlotSchematic() return schematic end
function second:GetSlotIndex() return 1 end
local pending=true
second.continuableContainer={AreAnyLoadsOutstanding=function() return pending end}
local textUpdates=0
function second:UpdateAllocationText() textUpdates=textUpdates+1;self:SetNameText("Native allocation quantity") end
local oldName=second.Name:GetText()
second:Update()
assert(textUpdates==0 and second.Name:GetText()==oldName,
 "pending native item load must skip allocation text and rank updates")
pending=false;second:Update()
assert(textUpdates==1 and second.Name:GetText()=="|cff777777Native allocation quantity|r"
 and second.Button.QualityOverlay.atlas=="native-mixed-ranks",
 "native ready update must preserve disabled name and inventory mixed-rank badge")
allocations={{reagent=tier1}};second:Update()
assert(second.Name:GetText()=="|cffffffffNative allocation quantity|r"
 and second.Button.QualityOverlay.atlas=="native-rank-1",
 "native allocation must select its single rank and highlight name")
allocations={{reagent=tier1},{reagent=tier2}};second:Update()
assert(second.Button.QualityOverlay.atlas=="native-mixed-ranks",
 "native mixed allocations must retain mixed-rank badge")
second.overrideNameColor=color("|cffff1111");second:Update()
assert(second.Name:GetText()=="|cffff1111Native allocation quantity|r",
 "native name warning override must survive button styling")
second.Name:Hide();second:SetNameText("Different hidden native name");second:Update()
assert(not second.Name:IsShown(),"native hidden name must remain hidden")
second.Name:Show();second.overrideNameColor=nil;allocations={}
tier1.count=0;tier2.count=0;second:Update()
assert(second.Button.QualityOverlay.atlas==nil,
 "native unavailable ranks must clear previous badge")
local masks=adds;_G.QUI_RefreshCraftingOrdersColors()
assert(adds==masks and updates==1,"theme must reuse masks without native pool update")
env.profile.general.skinCraftingOrders=false
b.normal:SetAlpha(.6);b:Update()
assert(b.normal:GetAlpha()==.6,"disabled skin must stop reagent styling")
print("craftingorders pooled reagent slots passed")
