local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local panel=frame(nil,ah);ah.AuctionsFrame=panel
panel.BackButton=false;panel.CancelAuctionButton=false
local list=frame(nil,panel);panel.SummaryList=list
list.ScrollBox=frame(nil,list)
local row=frame("Button",list.ScrollBox)
row:SetFrameLevel(30)
row.Text=row:CreateFontString()
row.Icon=row:CreateTexture();row.IconBorder=row:CreateTexture()
row.SelectedHighlight=row:CreateTexture();row.SelectedHighlight:SetAlpha(.8)
row.HighlightTexture=row:CreateTexture()
row.HighlightTexture:Hide()
row.NormalTexture=false;function row:GetNormalTexture() return nil end
local masks=0
function row:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
for _,texture in ipairs({row.Icon,row.SelectedHighlight,row.HighlightTexture}) do
 function texture:AddMaskTexture() masks=masks+1 end
end
local index=2
function row:GetElementData() return index end
function row:RegisterEvent(event) self.registered=event end
function row:UnregisterEvent(event) self.unregistered=event end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseAuctionsFrame.lua"))
local source=f:read("*a");f:close()
_G.AuctionHouseAuctionsSummaryLineMixin={}
local constant=assert(source:match("local ALL_INDEX = [^\n]+"))
for _,key in ipairs({"Init","SetIconShown","SetSelected","OnEvent","OnHide"}) do
 assert(loadstring(constant.."\n"..assert(source:match("(function AuctionHouseAuctionsSummaryLineMixin:"..key..".-)\nfunction ")),
 "@native-summary-"..key))()
end
for k,v in pairs(_G.AuctionHouseAuctionsSummaryLineMixin) do row[k]=v end
local bids,cached=false,true
function panel:IsDisplayingBids() return bids end
_G.AUCTION_HOUSE_ALL_BIDS="Native all bids"
_G.AUCTION_HOUSE_ALL_AUCTIONS="Native all auctions"
_G.C_AuctionHouse={
 GetOwnedAuctionType=function(i) return {itemID=100+i} end,
 GetBidType=function(i) return {itemID=200+i} end,
 GetItemKeyInfo=function(key) if cached then return {iconFileID="native-art-"..key.itemID,itemName="native-item-"..key.itemID,quality=key.itemID<200 and 4 or 2} end end}
_G.AuctionHouseUtil={GetItemDisplayText=function(name) return name end}
_G.ColorManager={GetColorDataForItemQuality=function(q)
 return {color={WrapTextInColorCode=function(_,text) return "quality:"..q..":"..text end}}
end}
f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseUtil.lua"))
local utilSource=f:read("*a");f:close()
assert(loadstring(assert(utilSource:match("(function AuctionHouseUtil.GetItemDisplayTextFromItemKey.-)\nfunction ")),
 "@native-summary-item-name"))()
row:Init(2);row:SetSelected(true)
local click=function() error("summary click invoked") end
row:SetScript("OnClick",click)
row:SetScript("OnEvent",row.OnEvent);row:SetScript("OnHide",row.OnHide)
_G.C_Timer.After=function(_,fn) fn() end
local acquired
_G.ScrollUtil.AddAcquiredFrameCallback=function(_,fn) acquired=fn end
function list.ScrollBox:HasView() return true end
function list.ScrollBox:ForEachFrame(fn) fn(row) end
ns.SafeCallMethodIfPresent=function(_,object,key,...)
 if not object or type(object[key])~="function" then return false end
 return pcall(object[key],object,...)
end
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(row.Icon:GetAlpha()==1 and row.Icon.texture=="native-art-101" and row.Icon:IsShown() and row.Text:GetText()=="quality:4:native-item-101",
 "summary native item art must survive direct texture stripping")
local border=skin.GetFrameData(row.Icon,"iconBorder")
assert(border and border._quiRoundedSurface and border:IsShown() and masks==3,
 "summary icon needs rounded border and reused icon/selection/hover masks")
assert(row.IconBorder:GetAlpha()==0 and row.SelectedHighlight:IsShown() and row.SelectedHighlight:GetAlpha()==.8,
 "native decoration suppression must retain selection visibility and opacity")
index=1;row:Init(index)
assert(not row.Icon:IsShown() and not border:IsShown() and row.Text:GetText()=="Native all auctions" and row.Text.textColor[1]==.9,
 "native All row must hide icon and its replacement border")
bids=true;row:Init(1)
assert(row.Text:GetText()=="Native all bids" and not border:IsShown(),"native bids All caption must remain")
index=2;row:Init(index)
assert(row.Icon.texture=="native-art-201" and row.Icon:IsShown() and border:IsShown() and masks==3
 and row.Text:GetText()=="quality:2:native-item-201",
 "bid item reuse must restore art and border without duplicate masks")
cached=false;row:Init(2)
assert(row.pendingItemID==201 and row.registered=="ITEM_KEY_ITEM_INFO_RECEIVED"
 and row.Text:GetText()=="" and not row.Icon:IsShown() and not border:IsShown(),
 "uncached native item state must preserve pending event and hide icon/border")
cached=true
row:OnEvent("ITEM_KEY_ITEM_INFO_RECEIVED",999)
assert(row.pendingItemID==201 and not border:IsShown(),"unrelated native item event must not populate row")
row:OnEvent("ITEM_KEY_ITEM_INFO_RECEIVED",201)
assert(row.pendingItemID==nil and row.Icon.texture=="native-art-201" and border:IsShown()
 and row.unregistered=="ITEM_KEY_ITEM_INFO_RECEIVED","matching native event must restore row and clear pending state")
row:SetSelected(false)
_G.QUI_RefreshAuctionHouseColors()
assert(not row.SelectedHighlight:IsShown() and masks==3 and row:GetScript("OnClick")==click,
 "theme refresh must preserve deselection and native click ownership")
row:Hide()
assert(row.unregistered=="ITEM_KEY_ITEM_INFO_RECEIVED","native hide must retain event cleanup")
env.profile.general.skinAuctionHouse=false
local fresh=frame("Button",list.ScrollBox);fresh.Icon=fresh:CreateTexture()
acquired(nil,fresh)
assert(fresh.Icon:GetAlpha()==1 and not skin.GetBackdrop(fresh),"disabled skin must leave fresh summary art untouched")
print("auctionhouse summary rows passed")
