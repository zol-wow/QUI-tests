local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(parent)
 local f=env.NewFrame("Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
_G.TableBuilderMixin={}
local native=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/TableBuilder.lua")
for _,key in ipairs({"AddRow","ArrangeCells","ArrangeHorizontally","EnumerateHeaders"}) do
 assert(loadstring(assert(native:match("(function TableBuilderMixin:"..key.."%b().-\nend)"))))()
end
_G.ProfessionsCustomerTableCellItemNameMixin={}
_G.ProfessionsCustomerTableCellStatusMixin={}
_G.ProfessionsTableCellTextMixin={}
native=read("tests/framexml/Interface/AddOns/Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTemplates.lua")
for _,pair in ipairs({{"ProfessionsCustomerTableCellItemNameMixin","Populate"},{"ProfessionsCustomerTableCellStatusMixin","Populate"},{"ProfessionsTableCellTextMixin","SetText"}}) do
 assert(loadstring(assert(native:match("(function "..pair[1]..":"..pair[2].."%b().-\nend)"))))()
end
_G.Enum={CraftingOrderState={Creating=1,Created=2,Claiming=3,Claimed=4,Crafting=5,Recrafting=6,Expiring=7,Expired=8,Fulfilling=9,Fulfilled=10,Rejecting=11,Rejected=12,Canceling=13,Canceled=14}}
for _,key in ipairs({"LISTED","IN_PROGRESS","EXPIRED","COMPLETED","REJECTED","CANCELED"}) do
 _G["PROFESSIONS_CRAFTING_ORDER_"..key]="Native "..key
end
_G.PROFESSIONS_RECRAFT_ORDER_NAME_FMT="Recraft %s"
_G.C_TradeSkillUI={GetRecipeItemQualityInfo=function() return {} end}
_G.Professions={GetChatIconMarkupForQuality=function() return "|A:native-rank:12:12|a" end}
local callbacks={}
_G.Item={CreateFromItemID=function(_,id)
 return {
  ContinueOnItemLoad=function(self,callback) callbacks[#callbacks+1]=callback end,
  GetItemIcon=function() return "native-icon-"..id end,
  GetItemName=function() return "Native item "..id end,
  GetItemQualityColor=function() return {color={WrapTextInColorCode=function(_,text) return "|cffaa22ff"..text.."|r" end}} end,
 }
end}
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local owner=frame(root);root.BrowseOrders=owner
local builder={rows={}};owner.tableBuilder=builder
for key,method in pairs(_G.TableBuilderMixin) do builder[key]=method end
builder.headerPoolCollection={EnumerateActive=function() return pairs({}) end}
local order={itemID=123,spellID=456,minQuality=2,isRecraft=true,orderState=2}
local data={option=order}
function builder:GetDataProviderData() return data end
function builder:GetTableMargins() return 5,5 end
local masks=0
local function cell(row,kind)
 local c=frame(row);c.Text=c:CreateFontString();c.Text:SetTextColor(1,.1,.1,1)
 if kind=="item" then
  c.Icon=c:CreateTexture();c.IconBorder=c:CreateTexture();c.IconBorder:SetAtlas("auctionhouse-itemicon-small-border")
  function c:CreateMaskTexture() return env.NewTexture(c,"MaskTexture") end
  function c.Icon:AddMaskTexture() masks=masks+1 end
  c.Populate=_G.ProfessionsCustomerTableCellItemNameMixin.Populate
 else c.Populate=_G.ProfessionsCustomerTableCellStatusMixin.Populate end
 c:Populate(data,1)
 return c
end
local columns={}
for _,kind in ipairs({"item","status"}) do
 local column={}
 function column:ConstructCell(row) return cell(row,kind) end
 function column:GetCellWidth() return 100 end
 function column:GetCellPadding() return 2,3 end
 function column:GetPadding() return 1 end
 columns[#columns+1]=column
end
builder.columns=columns
function builder:GetColumns() return self.columns end
local row=frame(owner);row:SetSize(210,20)
row.FavoriteButton=frame(row);row.FavoriteButton.NormalTexture=row.FavoriteButton:CreateTexture()
row.FavoriteButton.NormalTexture:SetAtlas("auctionhouse-icon-favorite")
row.FavoriteButton:Hide()
skin.SkinScrollRow(row);skin.LockPooledRowText(row,4)
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
builder:AddRow(row,1)
local item,status=row.cells[1],row.cells[2]
local border=assert(skin.GetFrameData(item.Icon,"iconBorder"),"late table cell icon must receive QUI border")
assert(border._quiRoundedSurface and item.IconBorder:GetAlpha()==0 and masks==1
 and item.Text:GetFont()==ns.Helpers.GetGeneralFont() and status.Text:GetFont()==ns.Helpers.GetGeneralFont(),
 "cells added after row font flag must receive rounded art and durable typography")
assert(item:GetHeight()==20 and item:GetWidth()==100 and item:GetPoint()=="TOPLEFT"
 and status:GetHeight()==20 and status:GetWidth()==100,"native table-cell dimensions and arrangement must remain")
assert(item.Icon.texture==nil and item.Text:GetText()==nil,"styling must not force pending item data")
callbacks[1]()
assert(item.Icon.texture=="native-icon-123"
 and item.Text:GetText()=="Recraft |cffaa22ffNative item 123|r |A:native-rank:12:12|a",
 "native delayed item callback must retain art, quality markup, recraft caption and rank badge")
assert(status.Text:GetText()=="Native LISTED" and status.Text.textColor[2]==.1,
 "native status text and semantic color must remain")
for _,entry in ipairs({{4,"IN_PROGRESS"},{8,"EXPIRED"},{10,"COMPLETED"},{12,"REJECTED"},{14,"CANCELED"}}) do
 order.orderState=entry[1];status:Populate(data,1)
 assert(status.Text:GetText()=="Native "..entry[2],"native status reuse must remain")
end
order.itemID=789;order.isRecraft=false;order.minQuality=1
item:Populate(data,1);callbacks[2]()
builder:ArrangeCells(row)
assert(item.Icon.texture=="native-icon-789" and item.Text:GetText()=="|cffaa22ffNative item 789|r"
 and masks==1 and not row.FavoriteButton:IsShown()
 and row.FavoriteButton.NormalTexture.atlas=="auctionhouse-icon-favorite",
 "cell reuse must retain new native art/name, reuse mask and preserve favorite art/state")
_G.QUI_RefreshCraftingOrdersColors()
assert(#callbacks==2 and masks==1,"theme must not repopulate or request item data")
print("craftingorders table cells passed")
