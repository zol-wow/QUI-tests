local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(parent)
 local f=env.NewFrame("Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(root);root.Form=form;form.BackButton=false
form.RecipeHeader=form:CreateTexture();form.RecipeHeader:SetAtlas("CraftingOrders-Header-Frame")
form.RecipeHeader:SetSize(490,70);form.RecipeHeader:SetPoint("TOPLEFT",form,"TOPLEFT",8,-10)
for _,key in ipairs({"RecipeName","RecraftRecipeName","ProfessionText","OrderStateText"}) do
 form[key]=form:CreateFontString();form[key]:SetFont("Native text",14,"");form[key]:SetTextColor(1,.1,.1,1)
end
function form.RecipeName:GetStringHeight() return 20 end
form.OrderStateText:SetText("Native completed state")
form.FavoriteButton=frame(form);form.FavoriteButton.NormalTexture=form.FavoriteButton:CreateTexture()
form.FavoriteButton.NormalTexture:SetAtlas("auctionhouse-icon-favorite")
form.FavoriteButton:SetPoint("TOPRIGHT",form.RecipeHeader,"TOPRIGHT",-5,-5)
form.OrderRecipientDisplay=frame(form)
for _,key in ipairs({"PostedTo","Crafter","CrafterValue"}) do
 form.OrderRecipientDisplay[key]=form.OrderRecipientDisplay:CreateFontString()
 form.OrderRecipientDisplay[key]:SetFont("Native text",14,"")
 form.OrderRecipientDisplay[key]:SetText("Native "..key);form.OrderRecipientDisplay[key]:SetTextColor(.2,.8,.2,1)
end
form.ReagentContainer=frame(form)
form.ReagentContainer.Reagents=frame(form.ReagentContainer)
form.ReagentContainer.OptionalReagents=frame(form.ReagentContainer)
form.ReagentContainer.RecraftInfoText=frame(form.ReagentContainer)
form.TrackRecipeCheckbox=frame(form);form.TrackRecipeCheckbox.Checkbox=frame(form.TrackRecipeCheckbox)
function form.TrackRecipeCheckbox.Checkbox:SetChecked(value) self.checked=value end
form.AllocateBestQualityCheckbox=frame(form)
form.RecraftSlot=frame(form);form.RecraftSlot.OutputSlot=frame(form.RecraftSlot)
function form.RecraftSlot:Init(transaction) self.transaction=transaction end
form.OutputIcon=frame(form)
local updates=0
for _,key in ipairs({"UpdateReagentSlots","UpdateMinimumQuality","UpdateDepositCost","UpdateListOrderButton"}) do
 form[key]=function() updates=updates+1 end
end
local schematic={name="Native schematic",recipeID=123,reagentSlotSchematics={}}
_G.ProfessionsUtil={GetRecipeSchematic=function() return schematic end}
_G.CreateProfessionsRecipeTransaction=function()
 local t={}
 function t:GetRecipeSchematic() return schematic end
 function t:SetRecraftAllocationOrderID(orderID) self.orderID=orderID end
 return t
end
local allocations=0;local outputs=0;local linked=true
_G.Professions={
 AllocateAllBasicReagents=function() allocations=allocations+1 end,
 SetupOutputIcon=function() outputs=outputs+1 end,
 DoesSchematicIncludeReagentQualities=function() return false end,
}
_G.SetItemCraftingQualityOverlayOverride=function() end
_G.C_TradeSkillUI={
 IsRecipeTracked=function() return true end,
 GetRecipeItemQualityInfo=function() return {iconSmall="native-quality-badge"} end,
 GetQualitiesForRecipe=function() return {501,502} end,
 GetRecipeOutputItemData=function() return {hyperlink=linked and "native-link" or nil} end,
 GetProfessionNameForSkillLineAbility=function() return "Native profession" end,
}
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
_G.CRAFTING_ORDER_RECIPE_PROFESSION_FMT="Profession: %s"
_G.PROFESSIONS_ORDER_RECRAFT_TITLE_FMT="Recraft: %s"
_G.CreateAtlasMarkup=function(atlas) return "|A:"..atlas..":12:12|a" end
_G.Item={CreateFromItemLink=function()
 return {
  GetItemName=function() return "Native quality item" end,
  GetItemQualityColorRGB=function() return .64,.21,.93 end,
  GetItemQualityColor=function() return {color={WrapTextInColorCode=function(_,text) return "|cffaa22ff"..text.."|r" end}} end,
 }
end}
local loaders={}
_G.CreateProfessionsRecipeLoader=function(_,callback) loaders[#loaders+1]=callback;return {} end
_G.ProfessionsCustomerOrderFormMixin={}
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua"))
local native=f:read("*a");f:close()
assert(loadstring(assert(native:match("(function ProfessionsCustomerOrderFormMixin:InitSchematic%b().-\nend)"))))()
form.InitSchematic=_G.ProfessionsCustomerOrderFormMixin.InitSchematic
form.order={spellID=123,minQuality=2,skillLineAbilityID=321,reagents={},orderID=7}
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
assert(form.RecipeHeader:GetAlpha()==0 and form.RecipeName:GetFont()==ns.Helpers.GetGeneralFont(),
 "form header must suppress native decoration and style actual recipe title")
local _,relative=form.FavoriteButton:GetPoint()
assert(relative==form.RecipeHeader and form.RecipeHeader:GetWidth()==490
 and form.RecipeHeader:GetHeight()==70 and form.FavoriteButton.NormalTexture.atlas=="auctionhouse-icon-favorite",
 "native header dimensions and favorite anchor/art must remain")
form:InitSchematic()
assert(form.RecipeName:GetText()==nil and #loaders==1,"styling must retain deferred recipe-name population")
loaders[1]()
assert(form.RecipeName:GetText()=="Native quality item" and form.RecipeName.textColor[1]==.64
 and form.RecipeName:GetHeight()==20 and outputs==1 and allocations==1,
 "native loader must retain quality RGB, measured title height and setup callbacks")
form.committed=true;form:InitSchematic();loaders[2]()
assert(form.RecipeName:GetText()=="Native quality item |A:native-quality-badge:12:12|a" and allocations==1,
 "committed native title must retain quality badge without basic allocation")
form.order.isRecraft=true;form:InitSchematic();loaders[3]()
assert(form.RecraftRecipeName:GetText()=="Recraft: |cffaa22ffNative quality item |A:native-quality-badge:12:12|a|r"
 and form.ProfessionText:GetPoint()=="TOPLEFT","native recraft loader must retain quality markup and profession anchoring")
linked=false;form.order.isRecraft=false;form:InitSchematic();loaders[4]()
assert(form.RecipeName:GetText()=="Native schematic" and form.RecipeName.textColor[2]==.82,
 "native no-link title must retain fallback name and normal color")
local before=updates
_G.QUI_RefreshCraftingOrdersColors()
assert(updates==before and #loaders==4 and form.OrderStateText:GetText()=="Native completed state"
 and form.OrderStateText.textColor[2]==.1 and form.OrderRecipientDisplay.CrafterValue.textColor[2]==.8,
 "theme must preserve state/recipient colors without rerunning native setup or loading")
form.RecipeHeader:SetAlpha(1)
assert(form.RecipeHeader:GetAlpha()==0,"native atlas decoration must stay suppressed on reuse")
print("craftingorders form header passed")
