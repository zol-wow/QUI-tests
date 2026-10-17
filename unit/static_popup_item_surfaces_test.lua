local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinStaticPopups=true; env.profile.general.skinContextMenus=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false; f.DisabledTexture=false
 return f
end
local popup=frame()
_G.StaticPopup1=popup; _G.STATICPOPUP_NUMDIALOGS=1
popup.Text=popup:CreateFontString()
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua"))
local source=file:read("*a"); file:close()
local native=assert(source:match("(StaticPopupItemFrameMixin = {};.-)StaticPopup_AddShowCondition"))
assert(loadstring(native,"@native-static-popup-item-methods"))()
local itemFrame=frame(nil,popup)
popup.ItemFrame=itemFrame
for k,v in pairs(_G.StaticPopupItemFrameMixin) do itemFrame[k]=v end
itemFrame.Text=itemFrame:CreateFontString()
itemFrame.NameFrame=itemFrame:CreateTexture()
itemFrame.Item=frame("Button",itemFrame)
local button=itemFrame.Item
button.icon,button.IconBorder=button:CreateTexture(),button:CreateTexture()
button.Count=button:CreateFontString()
button.IconBorder:Hide()
function button.IconBorder:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
function button:SetItemLocation(location) self.nativeLocation=location; self.icon:SetTexture("location-art") end
local masks=0
function button:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
function button.icon:AddMaskTexture() masks=masks+1 end
local click=function() error("audit must not accept item confirmation") end
button:SetScript("OnClick",click)
local loaded,quality=false,4
local colors={[0]={1,1,1,1},[2]={.2,.8,.3,1},[4]={.7,.2,1,1}}
_G.C_Item={
 GetItemInfo=function() if loaded then return "Loaded item",nil,quality,nil,nil,nil,nil,nil,nil,"late-art" end end,
 GetItemInfoInstant=function() return 22,nil,nil,nil,"pending-art" end,
 GetItemQualityColor=function(q) return unpack(colors[q]) end,
 GetItemName=function() return "Location item" end,
 GetItemQuality=function() return 2 end,
}
_G.ColorManager={GetColorDataForItemQuality=function(q) return {color={GetRGB=function() return unpack(colors[q]) end}} end}
_G.SetItemButtonTexture=function(f,value) f.icon:SetTexture(value) end
_G.SetItemButtonQuality=function(f,q)
 f.nativeQuality=q
 if q and q>0 then f.IconBorder:SetVertexColor(unpack(colors[q])); f.IconBorder:Show()
 else f.IconBorder:Hide() end
end
_G.RETRIEVING_ITEM_INFO="Native retrieving"
_G.RED_FONT_COLOR={r=1,g=.1,b=.1}
local tooltip={SetOwner=function(self,f) self.owner=f end,SetHyperlink=function(self,link) self.link=link end,Hide=function(self) self.hidden=true end}
_G.GameTooltip=tooltip
itemFrame:SetScript("OnEnter",itemFrame.OnEnter); itemFrame:SetScript("OnLeave",itemFrame.OnLeave)
popup.data={link="item:22",count=3}
itemFrame:RetrieveInfo(popup.data)
itemFrame:DisplayInfo(popup.data.link,popup.data.name,popup.data.color,popup.data.texture,popup.data.count)
ns.WhenLoggedIn=function(fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
assert(masks==1 and skin.GetBackdrop(itemFrame) and skin.GetBackdrop(itemFrame)._quiRoundedSurface
 and itemFrame.NameFrame:GetAlpha()==0,"static item name area and icon must receive rounded QUI presentation")
local border=skin.GetFrameData(button.icon,"iconBorder")
assert(itemFrame.itemID==22 and itemFrame.Text:GetText()=="Native retrieving" and itemFrame.Text.textColor[2]==.1
 and button.icon.texture=="pending-art" and button.Count:IsShown(),"pending item feedback art and count must remain native")
loaded=true
itemFrame:OnEvent("GET_ITEM_INFO_RECEIVED",23)
assert(itemFrame.itemID==22,"unrelated item-info events must not replace current pending item")
itemFrame:OnEvent("GET_ITEM_INFO_RECEIVED",22)
assert(itemFrame.itemID==nil and itemFrame.Text:GetText()=="Loaded item" and button.icon.texture=="late-art"
 and border._quiBorderR==.7 and itemFrame.Text.textColor[1]==.7,"delayed native item update must retain quality text and rounded rarity border")
itemFrame:Fire("OnEnter")
assert(tooltip.owner==itemFrame and tooltip.link=="item:22","native hyperlink tooltip must remain")
itemFrame:Fire("OnLeave")
assert(tooltip.hidden,"native tooltip leave handler must remain")
local location={bag=1,slot=2}
itemFrame:DisplayInfoFromStandardCallback(location,nil,nil,1)
assert(button.nativeLocation==location and button.icon.texture=="location-art" and border._quiBorderG==.8
 and not button.Count:IsShown() and itemFrame.Text:GetText()=="Location item","native location callback must update art rarity name and count")
itemFrame:DisplayInfoFromStandardCallback(location,"Ordinary item",0,5)
assert(border._quiBorderR==skin.GetWindowColors() and button.Count:IsShown() and button.Count:GetText()=="5",
 "ordinary reuse must clear stale quality while retaining native count")
_G.QUI_RefreshSystemPopupSkins()
assert(masks==1 and button:GetScript("OnClick")==click,"theme refresh must reuse mask and preserve item handler")
local custom=0
itemFrame:SetCustomOnEnter(function() custom=custom+1 end)
itemFrame:Fire("OnEnter")
assert(custom==1,"caller-owned custom tooltip must remain")
print("static popup item surfaces passed")
