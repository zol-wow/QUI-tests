local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local function text(parent)
 local t=parent:CreateFontString();t:SetTextColor(1,.82,0,1);return t
end
local function button(parent)
 local b=frame("Button",parent);b.fontString=text(b);b.normal=b:CreateTexture()
 function b:GetFontString() return self.fontString end
 function b:GetNormalTexture() return self.normal end
 function b:GetPushedTexture() return nil end
 function b:GetHighlightTexture() return nil end
 function b:GetDisabledTexture() return nil end
 function b:SetEnabled(value) self.enabled=value end
 function b:IsEnabled() return self.enabled end
 b:SetScript("OnClick",function() error("token action invoked") end)
 return b
end
local ah=frame();_G.AuctionHouseFrame=ah
local buy=frame(nil,ah);ah.WoWTokenResults=buy
local sell=frame(nil,ah);ah.WoWTokenSellFrame=sell
buy.Buyout=button(buy);buy.BuyoutPrice=text(buy);buy.BuyoutLabel=text(buy)
buy.InvisiblePriceFrame=frame(nil,buy)
sell.PostButton=button(sell);sell.DummyRefreshButton=button(sell)
sell.DummyRefreshButton.Icon=sell.DummyRefreshButton:CreateTexture()
sell.DummyRefreshButton.Icon:SetAtlas("UI-RefreshButton");sell.DummyRefreshButton:SetEnabled(false)
sell.MarketPrice=text(sell);sell.TimeToSell=text(sell)
sell.InvisiblePriceFrame=frame(nil,sell)
for _,key in ipairs({"Background","CreateAuctionTabLeft","CreateAuctionTabMiddle","CreateAuctionTabRight"}) do sell[key]=sell:CreateTexture() end
buy.NineSlice=frame(nil,buy);sell.NineSlice=frame(nil,sell)
sell.DummyItemList=frame(nil,sell)
local dummy=sell.DummyItemList
dummy.Background=dummy:CreateTexture();dummy.NineSlice=frame(nil,dummy)
dummy.backgroundAtlas="auctionhouse-background-sell-right"
local function scrollbar(parent)
 local bar=frame(nil,parent);bar.Track=frame(nil,bar)
 local thumb=frame(nil,bar.Track);bar.Track.Thumb=thumb
 for _,key in ipairs({"Begin","Middle","End"}) do
  bar.Track[key]=bar.Track:CreateTexture();thumb[key]=thumb:CreateTexture()
 end
 thumb:Hide()
 return bar
end
buy.DummyScrollBar=scrollbar(buy);dummy.DummyScrollBar=scrollbar(dummy)
local tutorial=frame(nil,buy);buy.GameTimeTutorial=tutorial;tutorial:Hide()
tutorial.CloseButton=button(tutorial)
tutorial.Tutorial=tutorial:CreateTexture();tutorial.Tutorial:SetAtlas("token-info-background")
for _,key in ipairs({"LeftDisplay","RightDisplay"}) do
 local d=frame(nil,tutorial);tutorial[key]=d
 for _,k in ipairs({"Label","Tutorial1","Tutorial2","Tutorial3"}) do d[k]=text(d) end
end
local store=button(tutorial.RightDisplay);tutorial.RightDisplay.StoreButton=store
store.Left=store:CreateTexture();store.Middle=store:CreateTexture();store.Right=store:CreateTexture()
store.Logo=store:CreateTexture();store.Logo:SetTexture("native-store-logo")
function store.Logo:SetDesaturated(value) self.desaturated=value end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseWoWTokenFrame.lua"))
local native=f:read("*a");f:close()
local function global(key)
 assert(loadstring(assert(native:match("(function "..key.."%b().-\nend)")),"@native-token-"..key))()
 return _G[key]
end
_G.AuctionHouseBackgroundMixin={}
local bgFile=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua"))
local bgSource=bgFile:read("*a");bgFile:close()
assert(loadstring(assert(bgSource:match("(function AuctionHouseBackgroundMixin:OnLoad.-\nend)")),"@native-token-dummy-background"))()
dummy.OnLoad=_G.AuctionHouseBackgroundMixin.OnLoad
dummy:OnLoad()
_G.WoWTokenSellFrameMixin={};_G.AuctionHouseStoreButtonMixin={}
global("BrowseWowTokenResults_Update")
global("WoWTokenSellFrameMixin:Refresh");sell.Refresh=_G.WoWTokenSellFrameMixin.Refresh
global("WoWTokenGameTimeTutorial_OnShow")
global("WowTokenGameTimeTutorialStoreButton_UpdateState")
for _,key in ipairs({"OnEnable","OnDisable"}) do global("AuctionHouseStoreButtonMixin:"..key);store[key]=_G.AuctionHouseStoreButtonMixin[key] end
function store:Enable() self:SetEnabled(true);self:OnEnable() end
function store:Disable() self:SetEnabled(false);self:OnDisable() end
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
_G.GameFontRed={color={1,0,0,1}};_G.PriceFontWhite={color={1,1,1,1}}
for _,t in ipairs({buy.BuyoutPrice,sell.MarketPrice}) do
 function t:SetFontObject(obj) if obj.color then self:SetTextColor(unpack(obj.color)) end end
end
local price,money,dialog,balance,limited=100,200,false,false,false
_G.C_WowTokenPublic={
 GetCurrentMarketPrice=function() return price,2 end,
 GetGuaranteedPrice=function() return 90 end,
 GetCommerceSystemStatus=function() return true,true,balance end}
_G.GetCVarBitfield=function() return true end
_G.SetCVarBitfield=function() error("tutorial preference write invoked") end
_G.WowToken_IsWowTokenAuctionDialogShown=function() return dialog end
_G.GetMoney=function() return money end
_G.GetFormattedWoWTokenPrice=function(value) return "native-price:"..value end
_G.GetMoneyString=function(value) return "native-money:"..value end
_G.GameLimitedMode_IsActive=function() return limited end
_G.TOKEN_AUCTIONS_UNAVAILABLE="Native unavailable"
_G.TOKEN_MARKET_PRICE_NOT_AVAILABLE="Native missing price"
_G.ERR_NOT_ENOUGH_GOLD="Native not enough gold"
_G.ERR_FEATURE_RESTRICTED_TRIAL="Native trial restriction"
_G.UNKNOWN="Native unknown"
_G.AUCTION_TIME_LEFT2_DETAIL="Native duration"
_G.TUTORIAL_TOKEN_GAME_TIME_STEP_2="Native game time"
_G.TUTORIAL_TOKEN_GAME_TIME_STEP_2_BALANCE="Native balance: %s"
_G.WowTokenRedemptionFrame_GetBalanceString=function() return "native balance value" end
function tutorial.LeftDisplay.Tutorial3:SetIndentedWordWrap(value) self.indented=value end
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
local handlers={}
for _,b in ipairs({buy.Buyout,sell.PostButton,sell.DummyRefreshButton,store}) do handlers[b]=b:GetScript("OnClick") end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(buy.Buyout.normal:GetAlpha()==0 and skin.GetBackdrop(buy.Buyout)
 and sell.PostButton.normal:GetAlpha()==0 and skin.GetBackdrop(store),"token action buttons must receive QUI chrome")
assert(not tutorial:IsShown() and skin.GetBackdrop(tutorial)._quiRoundedSurface
 and tutorial.Tutorial.atlas=="token-info-background" and tutorial.Tutorial:GetAlpha()==1,
 "tutorial must receive rounded shell without opening or hiding instructional artwork")
assert(sell.Background:GetAlpha()==0 and sell.CreateAuctionTabLeft:GetAlpha()==0
 and sell.DummyRefreshButton.Icon.atlas=="UI-RefreshButton" and not sell.DummyRefreshButton:IsEnabled(),
 "token decorative chrome must be suppressed while disabled refresh icon remains")
local function update() _G.BrowseWowTokenResults_Update(buy);sell:Refresh() end
update()
assert(buy.Buyout:IsEnabled() and sell.PostButton:IsEnabled() and buy.BuyoutPrice:GetText()=="native-price:100"
 and sell.MarketPrice:GetText()=="native-money:100" and sell.TimeToSell:GetText()=="Native duration",
 "available token market must preserve native prices and eligibility")
money=10;update()
assert(not buy.Buyout:IsEnabled() and buy.Buyout.tooltip=="Native not enough gold","native affordability restriction must remain")
money=200;buy.noneForSale=true;update()
assert(not buy.Buyout:IsEnabled() and buy.InvisiblePriceFrame:IsShown(),"native no-stock price visibility must remain")
buy.noneForSale=false;price=nil;update()
assert(not buy.Buyout:IsEnabled() and not sell.PostButton:IsEnabled() and not buy.InvisiblePriceFrame:IsShown()
 and buy.BuyoutPrice.textColor[2]==0 and sell.MarketPrice.textColor[2]==0
 and sell.TimeToSell:GetText()=="Native unknown","missing price must retain native red warning and unavailable state")
price=100;buy.disabled=true;sell.disabled=true;update()
_G.QUI_RefreshAuctionHouseColors()
assert(not buy.Buyout:IsEnabled() and not sell.PostButton:IsEnabled() and buy.BuyoutPrice.textColor[2]==0,
 "theme must preserve disabled token market and native warning color")
buy.disabled=false;sell.disabled=false;dialog=true;update()
assert(buy.BuyoutPrice:GetText()=="native-price:90" and sell.MarketPrice:GetText()=="native-money:90",
 "native guaranteed quote display must remain")
limited=true;_G.WowTokenGameTimeTutorialStoreButton_UpdateState(store)
_G.QUI_RefreshAuctionHouseColors()
assert(not store:IsEnabled() and store.tooltip=="Native trial restriction" and store.Logo.desaturated
 and store.Logo:GetAlpha()==.4 and store.Left:GetAlpha()==0,"native trial state must retain disabled semantic logo and suppress gold chrome")
limited=false;_G.WowTokenGameTimeTutorialStoreButton_UpdateState(store)
assert(store:IsEnabled() and store.Logo:GetAlpha()==1 and not store.Logo.desaturated and store.Left:GetAlpha()==0,
 "native enabled Store logo must remain without restoring gold art")
balance=true;_G.WoWTokenGameTimeTutorial_OnShow(tutorial)
_G.QUI_RefreshAuctionHouseColors()
assert(tutorial.LeftDisplay.Tutorial3:GetText()=="Native balance: native balance value"
 and tutorial.LeftDisplay.Tutorial3.indented and not tutorial:IsShown(),"native balance instructions and wrapping must remain")
balance=false;_G.WoWTokenGameTimeTutorial_OnShow(tutorial)
assert(tutorial.LeftDisplay.Tutorial3:GetText()=="Native game time","native game-time instruction reuse must remain")
assert(dummy.Background:GetAlpha()==0 and dummy.NineSlice:GetAlpha()==0
 and buy.NineSlice:GetAlpha()==0 and sell.NineSlice:GetAlpha()==0,
 "native token panel and dummy list backgrounds/borders must be suppressed")
dummy:OnLoad()
dummy.Background:SetAlpha(1);dummy.NineSlice:SetAlpha(1)
assert(dummy.Background.atlas=="auctionhouse-background-sell-right"
 and dummy.Background:GetAlpha()==0 and dummy.NineSlice:GetAlpha()==0,
 "native background reuse must retain atlas while suppressing decoration")
for _,bar in ipairs({buy.DummyScrollBar,dummy.DummyScrollBar}) do
 local thumb=bar.Track.Thumb
 assert(bar.Track:GetAlpha()==1 and not thumb:IsShown() and skin.GetBackdrop(thumb)._quiRoundedSurface
 and bar.Track.Begin:GetAlpha()==0 and thumb.Middle:GetAlpha()==0,
 "dummy scrollbar must receive QUI thumb without exposing native hidden thumb")
 thumb:Show();_G.QUI_RefreshAuctionHouseColors()
 assert(thumb:IsShown() and bar.Track:GetAlpha()==1,"theme refresh must preserve visible thumb")
 thumb:Hide()
end
for b,fn in pairs(handlers) do assert(b:GetScript("OnClick")==fn,"native token action handlers must remain") end
print("auctionhouse token controls passed")
