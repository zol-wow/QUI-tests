local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local panel=frame(nil,ah)
local auctions=arg[2]=="auctions"
if auctions then ah.AuctionsFrame=panel;panel.BackButton=false else ah.ItemBuyFrame=panel;panel.CancelAuctionButton=false end
if auctions then
 panel.BidsList=frame(nil,panel);panel.BidsList.ScrollBox=false;panel.BidsList.ScrollBar=false
end
panel.BidFrame=frame(nil,panel);panel.BuyoutFrame=frame(nil,panel)
local bid,buyout=panel.BidFrame,panel.BuyoutFrame
bid.BidAmount=frame(nil,bid)
local writes=0
local click=function() writes=writes+1 end
local function loadMethods(path,mixin,keys)
 _G[mixin]={}
 local f=assert(io.open(path));local source=f:read("*a");f:close()
 for _,key in ipairs(keys) do
  assert(loadstring(assert(source:match("(function "..mixin..":"..key..".-)\nfunction ")),"@native-"..key))()
 end
 return _G[mixin]
end
local shared="tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua"
for k,v in pairs(loadMethods(shared,"AuctionHouseBidFrameMixin",{"SetPrice"})) do bid[k]=v end
for k,v in pairs(loadMethods(shared,"AuctionHouseBuyoutFrameMixin",{"SetPrice"})) do buyout[k]=v end
local disabled=loadMethods("tests/framexml/Interface/AddOns/Blizzard_UIPanelTemplates/Shared/UIPanelTemplatesShared.lua",
 "ButtonWithDisableMixin",{"SetDisableTooltip"})
for _,pair in ipairs({{panel,auctions and "CancelAuctionButton" or "BackButton"},{bid,"BidButton"},{buyout,"BuyoutButton"}}) do
 local b=frame("Button",pair[1]);pair[1][pair[2]]=b
 b.Text=b:CreateFontString();function b:GetFontString() return self.Text end
 b.enabled=true;function b:IsEnabled() return self.enabled end
 function b:SetEnabled(value) local change=self.enabled~=value;self.enabled=value;if change then self:Fire(value and "OnEnable" or "OnDisable") end end
 b.SetDisableTooltip=disabled.SetDisableTooltip;b:SetScript("OnClick",click)
end
for _,key in ipairs({"gold","silver","copper"}) do
 local field=frame("EditBox",bid.BidAmount);bid.BidAmount[key]=field
 field.texture=field:CreateTexture();field.texture:SetAtlas("native-coin-"..key);field.texture:SetAlpha(.75)
 field.label=field:CreateFontString();field.label:Hide()
 field.number=0
 function field:SetTextColor(...) self.textColor={...} end
 function field:GetNumber() return self.number end
 function field:SetNumber(value) self.number=value end
 function field:SetEnabled(value) self.enabled=value;self:SetTextColor(value and 1 or .4,value and 1 or .4,value and 1 or .4,1) end
 field:SetScript("OnEnterPressed",click)
end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_MoneyFrame/Mainline/MoneyInputFrame.lua"))
local source=f:read("*a");f:close()
for _,key in ipairs({"SetCopper","SetEnabled"}) do
 assert(loadstring(assert(source:match("(function MoneyInputFrame_"..key..".-)\nfunction ")),"@native-money-"..key))()
end
_G.floor=math.floor;_G.mod=function(a,b) return a%b end
_G.COPPER_PER_GOLD=10000;_G.COPPER_PER_SILVER=100
local money=200000
_G.GetMoney=function() return money end
_G.AUCTION_HOUSE_TOOLTIP_TITLE_NOT_ENOUGH_MONEY="Native insufficient money"
_G.AUCTION_HOUSE_TOOLTIP_TITLE_OWN_AUCTION="Native own auction"
bid:SetPrice(12345,false,false);buyout:SetPrice(15000,false)
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
local navigation=panel.BackButton or panel.CancelAuctionButton
assert(skin.GetBackdrop(navigation),"individual item-buy/auctions action must receive rounded QUI presentation")
if auctions then assert(skin.IsStyled(panel.BidsList),"native Auctions BidsList must receive list styling") end
for _,key in ipairs({"gold","silver","copper"}) do
 assert(skin.GetBackdrop(bid.BidAmount[key]) and skin.GetBackdrop(bid.BidAmount[key])._quiRoundedSurface,
 "every native lowercase bid field must receive rounded chrome")
 assert(bid.BidAmount[key].texture:GetAlpha()==.75 and not bid.BidAmount[key].label:IsShown(),
 "native coin art alpha and alternate label visibility must remain")
end
assert(bid.BidAmount.gold:GetNumber()==1 and bid.BidAmount.silver:GetNumber()==23
 and bid.BidAmount.copper:GetNumber()==45 and bid.BidButton:IsEnabled() and buyout.BuyoutButton:IsEnabled(),
 "native denomination values and available actions must remain")
bid:SetPrice(12345,false,true)
assert(not bid.BidButton:IsEnabled() and not bid.BidAmount.gold.enabled and bid.BidAmount.gold.textColor[1]==.4,
 "native high bidder must retain disabled money color and action")
bid:SetPrice(12345,true,false);buyout:SetPrice(15000,true)
assert(bid.BidButton.disableTooltipTitle=="Native own auction" and buyout.BuyoutButton.disableTooltipTitle=="Native own auction",
 "own-auction restrictions and tooltips must remain")
money=100
bid:SetPrice(12345,false,false);buyout:SetPrice(15000,false)
assert(bid.BidButton.disableTooltipTitle=="Native insufficient money" and not buyout.BuyoutButton:IsEnabled(),
 "native affordability restrictions must remain")
bid:SetPrice(0,false,false);buyout:SetPrice(0,false)
assert(not bid.BidButton:IsEnabled() and not buyout.BuyoutButton:IsEnabled(),
 "zero price must retain native unavailable actions")
money=200000
bid:SetPrice(23456,false,false);buyout:SetPrice(30000,false)
_G.QUI_RefreshAuctionHouseColors()
assert(bid.BidAmount.gold:GetNumber()==2 and bid.BidAmount.silver:GetNumber()==34
 and bid.BidAmount.copper:GetNumber()==56 and bid.BidAmount.gold.textColor[1]==1
 and bid.BidButton:IsEnabled() and buyout.BuyoutButton:IsEnabled() and buyout.price==30000,
 "native eligible reuse and theme must retain values enabled state and field color")
assert(navigation:GetScript("OnClick")==click and bid.BidButton:GetScript("OnClick")==click
 and buyout.BuyoutButton:GetScript("OnClick")==click and bid.BidAmount.gold:GetScript("OnEnterPressed")==click and writes==0,
 "styling must preserve native actions and money entry without invocation")
if auctions then
 local mixin=loadMethods("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseAuctionsFrame.lua",
  "AuctionHouseAuctionsFrameMixin",{"UpdateCancelAuctionButton"})
 _G.Enum={AuctionStatus={Sold=2,Active=1}}
 panel.selectedAuctionID=nil
 mixin.UpdateCancelAuctionButton(panel,{status=1})
 assert(not panel.CancelAuctionButton:IsEnabled(),"unselected auction must retain disabled cancel")
 panel.selectedAuctionID=123
 mixin.UpdateCancelAuctionButton(panel,{status=2})
 assert(not panel.CancelAuctionButton:IsEnabled(),"sold auction must retain disabled cancel")
 mixin.UpdateCancelAuctionButton(panel,{status=1})
 assert(panel.CancelAuctionButton:IsEnabled(),"active selected auction must retain eligible cancel")
 _G.QUI_RefreshAuctionHouseColors()
 assert(panel.CancelAuctionButton:IsEnabled() and writes==0,"theme must retain cancel eligibility without cancelling")
end
env.profile.general.skinAuctionHouse=false
local fresh=frame("EditBox",bid.BidAmount);fresh.number=0
function fresh:GetNumber() return self.number end
function fresh:SetNumber(value) self.number=value end
function fresh:SetEnabled(value) self.enabled=value end
bid.BidAmount.gold=fresh
bid:SetPrice(10000,false,false)
assert(not skin.GetBackdrop(fresh),"disabled skin must leave fresh native bid input untouched")
print(auctions and "auctionhouse auctions bid controls passed" or "auctionhouse item buy controls passed")
