local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local check=frame("CheckButton",form);form.AllocateBestQualityCheckbox=check
check:SetSize(26,26);check.text=check:CreateFontString()
local textures={}
for _,key in ipairs({"Normal","Pushed","Highlight","Checked","DisabledChecked"}) do
 textures[key]=check:CreateTexture();textures[key]:SetTexture("native-"..key)
 check["Get"..key.."Texture"]=function() return textures[key] end
end
function check:GetChecked() return self.checked end
function check:SetChecked(value) self.checked=value end
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua"))
local native=file:read("*a");file:close()
local start=assert(native:find("self.AllocateBestQualityCheckbox.text:SetText",1,true))
local stop=assert(native:find('SquareButton_SetIcon(self.OrderRecipientDisplay.SocialDropdown',start,true))
local setup=native:sub(start,stop-1)
_G.LIGHTGRAY_FONT_COLOR={WrapTextInColorCode=function(_,text) return "|cffaaaaaa"..text.."|r" end}
_G.PROFESSIONS_USE_BEST_QUALITY_REAGENTS="Native best quality"
_G.PROFESSIONS_USE_LOWEST_QUALITY_REAGENTS="Native lowest tooltip"
_G.PROFESSIONS_USE_HIGHEST_QUALITY_REAGENTS="Native highest tooltip"
local preference,allocations,updates,sounds=0,0,0,0
_G.Professions={}
function Professions.SetShouldAllocateBestQualityReagents(value,customer)
 assert(value==check:GetChecked() and customer);preference=preference+1
end
form.transaction={}
function Professions.AllocateAllBasicReagents(transaction,value)
 assert(transaction==form.transaction and value==check:GetChecked());allocations=allocations+1
end
function form:UpdateReagentSlots() updates=updates+1 end
_G.SOUNDKIT={UI_PROFESSION_USE_BEST_REAGENTS_CHECKBOX=123}
_G.PlaySound=function(id) assert(id==123);sounds=sounds+1 end
_G.GameTooltip={}
function GameTooltip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
function GameTooltip:Show() self.shown=true end
_G.GameTooltip_AddNormalLine=function(t,text) t.text=text end
_G.GameTooltip_Hide=function() GameTooltip.shown=false end
assert(loadstring("return function(self)\n"..setup.."\nend","@native-order-allocation-setup"))()(form)
check:SetChecked(true)
local handlers={}
for _,key in ipairs({"OnClick","OnEnter","OnLeave"}) do handlers[key]=check:GetScript(key) end
local nativeText=check.text:GetText()
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local bd=assert(skin.GetBackdrop(check),"allocation checkbox must receive QUI chrome")
assert(textures.Normal:GetAlpha()==0 and bd._quiRoundedSurface,"native checkbox art must yield to rounded QUI chrome")
assert(check:GetWidth()==26 and check:GetHeight()==26 and check:GetChecked()
 and check.text:GetText()==nativeText,"native geometry, allocation state and inline label color must remain")
handlers.OnEnter(check)
assert(GameTooltip.owner==check and GameTooltip.anchor=="ANCHOR_RIGHT"
 and GameTooltip.text==_G.PROFESSIONS_USE_LOWEST_QUALITY_REAGENTS,"checked tooltip must remain native")
check:SetChecked(false);handlers.OnClick(check)
assert(preference==1 and allocations==1 and updates==1 and sounds==1 and check:IsShown(),
 "native click must allocate once and retain hide/show lifecycle")
handlers.OnEnter(check)
assert(GameTooltip.text==_G.PROFESSIONS_USE_HIGHEST_QUALITY_REAGENTS,"unchecked tooltip must remain native")
handlers.OnLeave(check);assert(not GameTooltip.shown)
check:Hide();_G.QUI_RefreshCraftingOrdersColors()
assert(not check:IsShown() and not check:GetChecked() and preference==1 and allocations==1 and updates==1 and sounds==1,
 "theme must preserve visibility/state without invoking native allocation")
for key,handler in pairs(handlers) do assert(check:GetScript(key)==handler,"native handler ownership must remain") end
env.profile.general.skinCraftingOrders=false
textures.Normal:SetAlpha(.6);_G.QUI_RefreshCraftingOrdersColors()
assert(textures.Normal:GetAlpha()==.6,"disabled skin must stop allocation styling")
print("craftingorders allocation checkbox passed")
