local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local listings=frame(nil,form);form.CurrentListings=listings;listings:SetSize(285,450)
listings.TitleContainer=frame(nil,listings)
local title=listings.TitleContainer:CreateFontString();listings.TitleContainer.TitleText=title
title:SetFont("Native title",12,"");title:SetText("Current Listings");title:SetTextColor(1,.82,0,1)
title:SetPoint("TOP",listings.TitleContainer,"TOP",0,-5)
local close=frame("Button",listings);listings.CloseButton=close;close:SetSize(120,22)
close.Text=close:CreateFontString();close.Text:SetText("Close")
function close:GetFontString() return self.Text end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua"))
local native=f:read("*a");f:close()
_G.ProfessionsCustomerOrderFormMixin={}
local prefix="local baseFrameWidth=800;local currentListingsPopoutFrameWidth=330;\n"
for _,key in ipairs({"HideCurrentListings","ShowCurrentListings"}) do
 assert(loadstring(prefix..assert(native:match("(function ProfessionsCustomerOrderFormMixin:"..key.."%b().-\nend)"))))()
 form[key]=_G.ProfessionsCustomerOrderFormMixin[key]
end
local layouts,requests=0,0
_G.SetUIPanelAttribute=function(panel,key,value) assert(panel==root and key=="width");panel.panelWidth=value end
_G.UpdateUIPanelPositions=function(panel) assert(panel==root);layouts=layouts+1 end
function form:RequestCurrentListings() requests=requests+1 end
local start=assert(native:find("self.CurrentListings:SetTitle",1,true))
local stop=assert(native:find("self.CurrentListings.SetSortOrder",start,true))
function listings:SetTitle(text) title:SetText(text) end
_G.PROFESSIONS_CURRENT_LISTINGS="Current Listings"
assert(loadstring("return function(self)\n"..native:sub(start,stop-1).."\nend"))()(form)
local click=close:GetScript("OnClick")
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
assert(title:GetFont()==ns.Helpers.GetGeneralFont(),"nested listings title must receive QUI typography")
assert(title:GetText()=="Current Listings" and select(2,title:GetTextColor())==.82,
 "native title text and color must remain")
assert(skin.GetBackdrop(close) and close.Text:GetText()=="Close" and not skin.GetFrameData(close,"closeLabel"),
 "native labeled close button must retain its label without replacement X")
form:ShowCurrentListings()
assert(listings:IsShown() and root.panelWidth==1130 and layouts==1 and requests==1,
 "native opening must expand panel once and request listings once")
click(close)
assert(not listings:IsShown() and root.panelWidth==800 and layouts==2 and requests==1,
 "native close must hide popout and restore panel width once")
title:SetFontObject("Native rebound")
assert(title:GetFont()==ns.Helpers.GetGeneralFont(),"title font object reuse must retain QUI typography")
_G.QUI_RefreshCraftingOrdersColors()
assert(not listings:IsShown() and root.panelWidth==800 and layouts==2 and requests==1
 and close:GetScript("OnClick")==click,"theme must preserve native state and handler without layout or requests")
local point,relative=title:GetPoint()
assert(point=="TOP" and relative==listings.TitleContainer and close:GetWidth()==120
 and close:GetHeight()==22 and listings:GetWidth()==285,"native control and title geometry must remain")
listings.TitleContainer.IsForbidden=function() return true end
title:SetFont("Forbidden title",12,"");_G.QUI_RefreshCraftingOrdersColors()
assert(title:GetFont()=="Forbidden title","forbidden title container must stop styling")
print("craftingorders listings title passed")
