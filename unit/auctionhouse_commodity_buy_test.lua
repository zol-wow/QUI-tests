local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local panel=frame(nil,ah);ah.CommoditiesBuyFrame=panel
local display=frame(nil,panel);panel.BuyDisplay=display
display.Background=display:CreateTexture();display.NineSlice=frame(nil,display)
local writes=0
local click=function() writes=writes+1 end
for _,pair in ipairs({{panel,"BackButton"},{display,"BuyButton"}}) do
 local b=frame("Button",pair[1]);pair[1][pair[2]]=b;b:SetFrameLevel(30)
 b.Text=b:CreateFontString();function b:GetFontString() return self.Text end
 b.enabled=true;function b:IsEnabled() return self.enabled end
 function b:SetEnabled(value) local change=self.enabled~=value;self.enabled=value;if change then self:Fire(value and "OnEnable" or "OnDisable") end end
 b:SetScript("OnClick",click)
end
_G.ButtonWithDisableMixin={}
local function native(path,mixin,methods)
 _G[mixin]=_G[mixin] or {}
 local f=assert(io.open(path));local source=f:read("*a");f:close()
 for _,key in ipairs(methods) do
  assert(loadstring(assert(source:match("(function "..mixin..":"..key..".-)\nfunction ")),"@native-"..key))()
 end
 return _G[mixin]
end
display.BuyButton.SetDisableTooltip=native("tests/framexml/Interface/AddOns/Blizzard_UIPanelTemplates/Shared/UIPanelTemplatesShared.lua",
 "ButtonWithDisableMixin",{"SetDisableTooltip"}).SetDisableTooltip
local sellPath="tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua"
local priceMixin=native(sellPath,"AuctionHouseAlignedPriceDisplayMixin",{"GetAmount","SetAmount"})
local quantityMixin=native(sellPath,"AuctionHouseAlignedQuantityInputFrameMixin",{"GetQuantity","SetQuantity"})
for _,key in ipairs({"QuantityInput","UnitPrice","TotalPrice"}) do
 local control=frame(nil,display);display[key]=control
 control.Label=control:CreateFontString();control.Label:SetText(key)
 control.LabelTitle=control:CreateFontString();control.Subtext=control:CreateFontString()
 control.Subtext:SetTextColor(.5,.5,.5,1)
 if key=="QuantityInput" then
  control.InputBox=frame("EditBox",control)
  function control.InputBox:GetNumber() return self.number or 0 end
  function control.InputBox:SetNumber(value) self.number=value end
  control.MaxButton=frame("Button",control);control.MaxButton:Hide()
  for k,v in pairs(quantityMixin) do control[k]=v end
 else
  control.MoneyDisplayFrame=frame(nil,control)
  control.MoneyDisplayFrame.Text=control.MoneyDisplayFrame:CreateFontString()
  control.MoneyDisplayFrame.Text:SetTextColor(1,.1,.1,1)
  function control.MoneyDisplayFrame:SetAmount(value) self.amount=value;self.Text:SetText(tostring(value)) end
  function control.MoneyDisplayFrame:GetAmount() return self.amount end
  for k,v in pairs(priceMixin) do control[k]=v end
 end
end
display.ItemDisplay=frame("Button",display)
local header=display.ItemDisplay:CreateTexture();header:SetAtlas("auctionhouse-itemheaderframe")
function header:GetAtlas() return self.atlas end
display.ItemDisplay.ItemButton=frame("Button",display.ItemDisplay)
local item=display.ItemDisplay.ItemButton
item.Icon=item:CreateTexture();item.Icon:SetTexture("native-item-art")
item.CircleMask=item:CreateTexture()
function item.Icon:RemoveMaskTexture() end
function item:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
function item.Icon:AddMaskTexture() end
local buy=native("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseCommoditiesBuyFrame.lua",
 "AuctionHouseCommoditiesBuyDisplayMixin",{"SetPrice","UpdateBuyButton","SetQuantitySelected"})
for k,v in pairs(buy) do display[k]=v end
function display:GetItemID() return 123 end
_G.C_AuctionHouse={MakeItemKey=function(id) return {itemID=id} end,HasSearchResults=function() return true end}
local supply=3
_G.AuctionHouseUtil={AggregateSearchResultsByQuantity=function(_,quantity)
 local count=math.min(quantity,supply);return count,count*100
end,SanitizeAuctionHousePrice=function(value) return value end}
local money=1000
_G.GetMoney=function() return money end
_G.AUCTION_HOUSE_TOOLTIP_TITLE_NOT_ENOUGH_MONEY="Native insufficient money"
_G.AUCTION_HOUSE_TOOLTIP_TITLE_NONE_AVAILABLE="Native no stock"
display.resultsLoaded=true
display:SetQuantitySelected(5)
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(skin.GetBackdrop(panel.BackButton),"commodity Back action must receive QUI chrome")
assert(header:GetAlpha()==0 and item.Icon.texture=="native-item-art" and skin.GetFrameData(item.Icon,"iconBorder"),
 "nested commodity header decoration must be suppressed while native icon art is styled and retained")
assert(display.Background:GetAlpha()==0 and display.NineSlice:GetAlpha()==0,
 "commodity BuyDisplay native background and border must be suppressed")
assert(display.QuantityInput.Label.textColor[1]==.9 and display.UnitPrice.Label.textColor[1]==.9
 and display.TotalPrice.Label.textColor[1]==.9,"each commodity label must use neutral QUI presentation")
assert(display.QuantityInput:GetQuantity()==3 and display.UnitPrice:GetAmount()==100 and display.TotalPrice:GetAmount()==300,
 "native supply clamp and calculated prices must remain")
assert(not display.QuantityInput.MaxButton:IsShown(),"native hidden Max must stay hidden")
money=100
display:SetPrice(100,300)
assert(not display.BuyButton:IsEnabled() and display.BuyButton.disableTooltipTitle=="Native insufficient money",
 "native affordability eligibility must remain")
money=1000;supply=0
display:SetQuantitySelected(1)
assert(display.QuantityInput:GetQuantity()==0 and display.TotalPrice:GetAmount()==0
 and display.BuyButton.disableTooltipTitle=="Native no stock","native exhausted supply and unavailable tooltip must remain")
supply=4
display:SetQuantitySelected(2)
_G.QUI_RefreshAuctionHouseColors()
assert(display.BuyButton:IsEnabled() and display.TotalPrice:GetAmount()==200
 and display.TotalPrice.MoneyDisplayFrame.Text.textColor[2]==.1 and display.QuantityInput.Subtext.textColor[1]==.5,
 "restored supply and theme refresh must retain amounts and semantic money/subtext colors")
assert(panel.BackButton:GetScript("OnClick")==click and display.BuyButton:GetScript("OnClick")==click and writes==0,
 "styling must preserve native action ownership without invoking navigation or buying")
print("auctionhouse commodity buy passed")
