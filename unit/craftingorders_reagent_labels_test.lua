local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(parent)
 local f=env.NewFrame("Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(root);root.Form=form;form.BackButton=false
local container=frame(form);form.ReagentContainer=container
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
_G.ProfessionsReagentContainerMixin={}
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTemplates.lua"))
local native=f:read("*a");f:close()
for _,key in ipairs({"OnLoad","SetText"}) do
 assert(loadstring(assert(native:match("(function ProfessionsReagentContainerMixin:"..key.."%b().-\nend)"))))()
end
for _,key in ipairs({"Reagents","OptionalReagents"}) do
 local section=frame(container);container[key]=section
 section.Label=section:CreateFontString();section.Label:SetFont("native",11,"")
 section.Label:SetTextColor(1,.82,0,.7)
 section.SetText=_G.ProfessionsReagentContainerMixin.SetText
 section.OnLoad=_G.ProfessionsReagentContainerMixin.OnLoad
 section.labelText="Native "..key;section:OnLoad()
end
container.RecraftInfoText=container:CreateFontString()
container.RecraftInfoText:SetText("Native recraft instructions")
container.RecraftInfoText:SetTextColor(.5,.5,.5,1)
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local expected=ns.Helpers.GetGeneralFont()
for _,key in ipairs({"Reagents","OptionalReagents"}) do
 local label=container[key].Label
 assert(label:GetFont()==expected and label.textColor[1]==.9 and label.textColor[4]==.7,
  "nested reagent labels must receive QUI font and neutralize only native normal gold")
 assert(label:GetText()=="Native "..key,"native container label text must remain")
end
container.Reagents:SetText("Native provided reagents")
container.OptionalReagents:SetText("Native provided optional reagents")
container.Reagents.Label:SetTextColor(1,.1,.1,1)
container.OptionalReagents:Hide();_G.QUI_RefreshCraftingOrdersColors()
assert(container.Reagents.Label:GetText()=="Native provided reagents"
 and container.OptionalReagents.Label:GetText()=="Native provided optional reagents"
 and container.Reagents.Label.textColor[2]==.1 and not container.OptionalReagents:IsShown(),
 "native label reuse, warning color and section visibility must remain")
assert(container.RecraftInfoText:GetFont()==expected and container.RecraftInfoText.textColor[1]==.5
 and container.RecraftInfoText:GetText()=="Native recraft instructions",
 "recraft instructions must retain native text and gray color")
env.profile.general.skinCraftingOrders=false
container.Reagents.Label:SetTextColor(1,.82,0,1);_G.QUI_RefreshCraftingOrdersColors()
assert(container.Reagents.Label.textColor[1]==1,"disabled skin must stop reagent caption styling")
print("craftingorders nested reagent labels passed")
