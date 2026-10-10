local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local tracking=frame(nil,form);form.TrackRecipeCheckbox=tracking;tracking:SetScale(.9)
tracking.Text=tracking:CreateFontString();tracking.Text:SetFont("Native label",12,"")
local checkbox=frame("CheckButton",tracking);tracking.Checkbox=checkbox
checkbox:SetSize(26,26);checkbox:SetPoint("RIGHT",tracking.Text,"LEFT",2,0)
local textures={}
for _,key in ipairs({"Normal","Pushed","Highlight","Checked","DisabledChecked"}) do
 textures[key]=checkbox:CreateTexture();textures[key]:SetTexture("native-"..key)
 checkbox["Get"..key.."Texture"]=function() return textures[key] end
end
function checkbox:SetChecked(value) self.checked=value end
function checkbox:GetChecked() return self.checked end
_G.LIGHTGRAY_FONT_COLOR={WrapTextInColorCode=function(_,text) return "|cffaaaaaa"..text.."|r" end}
_G.PROFESSIONS_TRACK_RECIPE="Native track recipe"
local writes,reads,sounds=0,0,0
local last
_G.C_TradeSkillUI={
 IsRecipeTracked=function(id,recraft) assert(id==123 and not recraft);reads=reads+1;return true end,
 SetRecipeTracked=function(id,value,recraft) writes=writes+1;last={id,value,recraft} end,
}
_G.SOUNDKIT={UI_PROFESSION_TRACK_RECIPE_CHECKBOX=1}
_G.PlaySound=function(id) assert(id==1);sounds=sounds+1 end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua"))
local native=f:read("*a");f:close()
local start=assert(native:find("self.TrackRecipeCheckbox.Text:SetText",1,true))
local stop=assert(native:find("local function SetFavoriteTooltip",start,true))
assert(loadstring("return function(self)\n"..native:sub(start,stop-1).."\nend"))()(form)
start=assert(native:find("function ProfessionsCustomerOrderFormMixin:InitSchematic()",1,true))
start=assert(native:find("\n",start,true))
stop=assert(native:find("local recipeSchematic",start,true))
local init=assert(loadstring("return function(self)\n"..native:sub(start,stop-1).."\nend"))()
form.ReagentContainer=frame(nil,form)
form.ReagentContainer.Reagents=frame(nil,form.ReagentContainer)
form.ReagentContainer.OptionalReagents=frame(nil,form.ReagentContainer)
form.ReagentContainer.RecraftInfoText=frame(nil,form.ReagentContainer)
form.order={spellID=123,isRecraft=false}
init(form)
local text=tracking.Text:GetText();local click=checkbox:GetScript("OnClick")
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local bd=assert(skin.GetBackdrop(checkbox),"nested tracking checkbox must receive QUI chrome")
assert(bd._quiRoundedSurface and textures.Normal:GetAlpha()==0
 and checkbox:GetChecked() and tracking.Text:GetFont()==ns.Helpers.GetGeneralFont()
 and tracking.Text:GetText()==text,"tracking state, inline label and checkbox styling must remain")
local point,relative=checkbox:GetPoint()
assert(checkbox:GetWidth()==26 and checkbox:GetHeight()==26 and point=="RIGHT"
 and relative==tracking.Text and tracking.scale==.9,"native checkbox geometry, label anchor and wrapper scale must remain")
checkbox:SetChecked(false);click(checkbox)
assert(writes==1 and last[1]==123 and last[2]==false and last[3]==false and sounds==1,
 "native click must retain recipe/recraft arguments and one tracking callback")
form.committed=true;init(form)
assert(not tracking:IsShown(),"native committed schematic must hide tracking wrapper")
local before=reads;_G.QUI_RefreshCraftingOrdersColors()
assert(not tracking:IsShown() and not checkbox:GetChecked() and reads==before and writes==1
 and checkbox:GetScript("OnClick")==click,"theme must preserve committed state and callback without tracking reads/writes")
form.committed=false;form.order.spellID=nil;init(form)
assert(not tracking:IsShown(),"native no-recipe draft must leave tracking hidden")
tracking.IsForbidden=function() return true end
textures.Normal:SetAlpha(.6);_G.QUI_RefreshCraftingOrdersColors()
assert(textures.Normal:GetAlpha()==.6,"forbidden tracking wrapper must stop descendant styling")
print("craftingorders tracking control passed")
