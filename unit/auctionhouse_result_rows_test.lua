local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame();_G.AuctionHouseFrame=ah
ah.BrowseResultsFrame=frame(nil,ah)
local list=frame(nil,ah.BrowseResultsFrame)
ah.BrowseResultsFrame.ItemList=list
list.ScrollBox=frame(nil,list)
local row=frame("Button",list.ScrollBox)
row:SetFrameLevel(30)
row.NormalTexture=row:CreateTexture()
row.SelectedHighlight=row:CreateTexture()
row.HighlightTexture=row:CreateTexture()
function row:GetNormalTexture() return self.NormalTexture end
local masks=0
function row:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
for _,texture in ipairs({row.SelectedHighlight,row.HighlightTexture}) do
 function texture:AddMaskTexture() masks=masks+1 end
end
row.Name=row:CreateFontString();row.Name:SetText("Native result")
row.Price=row:CreateFontString();row.Price:SetTextColor(1,.1,.1,1);row.Price:SetText("Native price")
row.rowData={id=1};function row:GetElementData() return self.rowData end
function row:GetItemList() return list end
local alternate,acquired,dirty,enters,leaves=nil,nil,0,0,0
_G.CreateScrollBoxListLinearView=function() return {SetElementFactory=function() end} end
_G.CreateTableBuilder=function() return {} end
_G.ScrollUtil.InitScrollBoxListWithScrollBar=function() end
_G.ScrollUtil.RegisterTableBuilder=function() end
_G.ScrollUtil.RegisterAlternateRowBehavior=function(_,fn) alternate=fn end
_G.ScrollUtil.AddAcquiredFrameCallback=function(_,fn) acquired=fn end
_G.C_Timer.After=function(_,fn) fn() end
function list.ScrollBox:HasView() return true end
function list.ScrollBox:ForEachFrame(fn) fn(row) end
ns.SafeCallMethodIfPresent=function(_,object,key,...)
 if not object or type(object[key])~="function" then return false end
 return pcall(object[key],object,...)
end
ns.SafeCall=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
_G.AuctionHouseItemListMixin={};_G.AuctionHouseItemListLineMixin={}
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemList.lua"))
local source=file:read("*a");file:close()
for _,pair in ipairs({
 {"AuctionHouseItemListMixin","Init"},{"AuctionHouseItemListMixin","SetSelectedEntry"},
 {"AuctionHouseItemListLineMixin","OnLineEnter"},{"AuctionHouseItemListLineMixin","OnLineLeave"}}) do
 local method=assert(source:match("(function "..pair[1]..":"..pair[2]..".-)\nfunction "))
 assert(loadstring(method,"@native-auction-row-"..pair[2]))()
end
function list:DirtyScrollFrame() dirty=dirty+1 end
function list:OnEnterListLine() enters=enters+1 end
function list:OnLeaveListLine() leaves=leaves+1 end
list.highlightCallback=function(data,selected) return data==selected,.6 end
list.selectionCallback=function() return true end
_G.AuctionHouseItemListMixin.Init(list)
_G.AuctionHouseItemListMixin.SetSelectedEntry(list,row.rowData)
alternate(row,false)
row.HighlightTexture:Hide()
row:SetScript("OnEnter",_G.AuctionHouseItemListLineMixin.OnLineEnter)
row:SetScript("OnLeave",_G.AuctionHouseItemListLineMixin.OnLineLeave)
local click=function() error("auction action invoked") end
row:SetScript("OnClick",click)
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(row.SelectedHighlight.texture==[[Interface\Buttons\WHITE8x8]] and masks==2,
 "result selected and hover surfaces must receive rounded QUI tints")
assert(row.SelectedHighlight:IsShown() and row.SelectedHighlight:GetAlpha()==.6
 and not row.HighlightTexture:IsShown(),"styling must preserve native selection and hover state")
assert(skin.GetBackdrop(row):GetFrameLevel()<row:GetFrameLevel(),"row chrome must stay below native content")
assert(row.Price:GetText()=="Native price" and row.Price.textColor[1]==1 and row.Price.textColor[2]==.1,
 "native price caption and semantic red must remain")
row:Fire("OnEnter")
assert(row.HighlightTexture:IsShown() and enters==1,"native hover tooltip routing must remain")
row:Fire("OnLeave")
assert(not row.HighlightTexture:IsShown() and leaves==1,"native hover leave must remain")
_G.AuctionHouseItemListMixin.SetSelectedEntry(list,nil)
alternate(row,true)
assert(not row.SelectedHighlight:IsShown() and row.NormalTexture:GetAlpha()==0,
 "native deselection and alternate-stripe suppression must remain")
row.rowData={id=2}
acquired(nil,row)
_G.AuctionHouseItemListMixin.SetSelectedEntry(list,row.rowData)
alternate(row,false)
_G.QUI_RefreshAuctionHouseColors()
assert(row.SelectedHighlight:IsShown() and row.SelectedHighlight:GetAlpha()==.6 and masks==2
 and dirty==3 and row:GetScript("OnClick")==click,"reuse/theme must retain selection handlers and single mask attachments")
row.rowData=nil
alternate(row,true)
assert(not row.SelectedHighlight:IsShown(),"native incomplete row must remain unselected")
env.profile.general.skinAuctionHouse=false
local fresh=frame("Button",list.ScrollBox)
acquired(nil,fresh)
assert(not skin.GetBackdrop(fresh),"disabled auction skin must leave fresh rows native")
print("auctionhouse result rows passed")
