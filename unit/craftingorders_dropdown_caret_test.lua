local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(parent)
 local f=env.NewFrame("Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
root.BrowseOrders=frame(root);root.BrowseOrders.SearchBar=frame(root.BrowseOrders)
local form=frame(root);root.Form=form;form.BackButton=false
form.PaymentContainer=frame(form);form.PaymentContainer.ListOrderButton=false;form.PaymentContainer.CancelOrderButton=false
form.MinimumQuality=frame(form)
local generators={}
local function dropdown(parent,text)
 local d=frame(parent);d:SetSize(160,22);d:SetFrameLevel(10)
 d.Text=d:CreateFontString();d.Text:SetText(text)
 d.Arrow=d:CreateTexture();d.Arrow:SetTexture("native-arrow");d.Arrow:SetSize(16,16);d.Arrow:SetPoint("RIGHT",d,"RIGHT",-5,0)
 d.menuGenerator=function() error("native menu generator invoked by styling") end
 generators[d]=d.menuGenerator
 d:SetScript("OnMouseDown",d.menuGenerator)
 return d
end
local filter=dropdown(root.BrowseOrders.SearchBar,"Native filters")
root.BrowseOrders.SearchBar.FilterDropdown=filter
filter.ResetButton=frame(filter);filter.ResetButton:SetFrameLevel(12);filter.ResetButton:Hide()
form.PaymentContainer.DurationDropdown=dropdown(form.PaymentContainer,"Native duration")
form.MinimumQuality.Dropdown=dropdown(form.MinimumQuality,"Native minimum quality")
form.OrderRecipientDropdown=dropdown(form,"Native recipient")
local controls={filter,form.PaymentContainer.DurationDropdown,form.MinimumQuality.Dropdown,form.OrderRecipientDropdown}
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
local carets={}
for _,d in ipairs(controls) do
 local caret=assert(skin.GetFrameData(d,"dropdownCaret"),"each stripped crafting-order dropdown must receive replacement caret")
 carets[d]=caret
 local point,relative=caret:GetPoint()
 assert(caret.line1 and caret.line2 and point=="CENTER" and relative==d.Arrow and d.Arrow:GetAlpha()==0,
  "replacement caret must follow actual native arrow anchor")
 assert(d.Text:GetText():find("Native",1,true) and d:GetWidth()==160 and d:GetHeight()==22
  and d:GetScript("OnMouseDown")==generators[d] and d.menuGenerator==generators[d],
  "dropdown text, geometry, native scripts and menu generator must remain")
end
assert(skin.GetBackdrop(filter):GetFrameLevel()==9 and filter.ResetButton:GetFrameLevel()==12 and not filter.ResetButton:IsShown(),
 "filter backdrop must stay below native reset control and preserve its visibility")
_G.QUI_RefreshCraftingOrdersColors()
for _,d in ipairs(controls) do assert(skin.GetFrameData(d,"dropdownCaret")==carets[d],"theme must reuse existing caret") end
print("craftingorders dropdown carets passed")
