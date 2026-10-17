local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local function native(path,mixin,keys)
 _G[mixin]=_G[mixin] or {}
 local f=assert(io.open(path));local source=f:read("*a");f:close()
 for _,key in ipairs(keys) do
  assert(loadstring(assert(source:match("(function "..mixin..":"..key..".-)\nfunction ")),"@native-sell-"..key))()
 end
 return _G[mixin]
end
local shared="tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua"
local base=native(shared,"AuctionHouseSellFrameMixin",{"UpdatePostState","UpdateDeposit","UpdateTotalPrice","UpdatePostButtonState","CanPostItem"})
local itemMixin=native("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemSellFrame.lua",
 "AuctionHouseItemSellFrameMixin",{"UpdatePostState","CanPostItem"})
local aligned=native(shared,"AuctionHouseSellFrameAlignedControlMixin",{"SetLabelColor"})
local errorMixin=native(shared,"AuctionHouseAlignedPriceInputFrameMixin",{"SetErrorShown"})
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
_G.RED_FONT_COLOR={GetRGB=function() return 1,.1,.1 end}
_G.COPPER_PER_SILVER=100
local ah=frame();_G.AuctionHouseFrame=ah
local panel=frame(nil,ah);ah.ItemSellFrame=panel
for _,key in ipairs({"QuantityInput","PriceInput","Deposit","TotalPrice"}) do
 local control=frame(nil,panel);panel[key]=control
 control.Label=control:CreateFontString();control.Label:SetText(key);control.Label:SetTextColor(1,.82,0,1)
 control.LabelTitle=control:CreateFontString();control.LabelTitle:SetTextColor(1,.82,0,1)
 control.Subtext=control:CreateFontString();control.Subtext:SetTextColor(.5,.5,.5,1)
end
panel.QuantityInput.InputBox=frame("EditBox",panel.QuantityInput)
panel.QuantityInput.MaxButton=frame("Button",panel.QuantityInput)
panel.PriceInput.SetLabelColor=aligned.SetLabelColor
panel.PriceInput.PriceError=frame(nil,panel.PriceInput)
panel.PriceInput.SetErrorShown=errorMixin.SetErrorShown
for _,key in ipairs({"Deposit","TotalPrice"}) do
 local control=panel[key];control.MoneyDisplayFrame=frame(nil,control)
 control.MoneyDisplayFrame.Text=control.MoneyDisplayFrame:CreateFontString()
 control.MoneyDisplayFrame.Text:SetTextColor(1,.1,.1,1)
 function control:SetAmount(value) self.amount=value;self.MoneyDisplayFrame.Text:SetText(tostring(value)) end
end
panel.PostButton=frame("Button",panel);panel.PostButton.Text=panel.PostButton:CreateFontString()
function panel.PostButton:GetFontString() return self.Text end
for _,button in ipairs({panel.PostButton,panel.QuantityInput.MaxButton}) do
 button.enabled=true
 function button:IsEnabled() return self.enabled end
 function button:SetEnabled(value) local changed=self.enabled~=value;self.enabled=value;if changed then self:Fire(value and "OnEnable" or "OnDisable") end end
end
function panel.PostButton:SetTooltip(value) self.nativeTooltip=value end
local click=function() error("auction post invoked") end
panel.PostButton:SetScript("OnClick",click)
local quantity,maxQuantity,deposit,bid,buyout,money,valid,ready,copper=2,5,155,100,200,1000,true,true,false
local item={IsValid=function() return valid end}
function panel:GetItem() return item end
function panel:GetQuantity() return quantity end
function panel.QuantityInput:GetQuantity() return quantity end
function panel:GetMaxQuantity() return maxQuantity end
function panel:GetDepositAmount() return deposit end
function panel:GetTotalPrice() return quantity*(buyout or bid or 0) end
function panel:GetPrice() return bid,buyout end
function panel.PriceInput:GetAmount() return buyout or bid or 0 end
function panel:GetSearchResultPrice() return 300 end
function panel:ShowHelpTip() self.nativeHelp=true end
function panel:HideHelpTip() self.nativeHelp=false end
for k,v in pairs(base) do panel[k]=v end
panel.UpdatePostState=itemMixin.UpdatePostState;panel.CanPostItem=itemMixin.CanPostItem
_G.GetMoney=function() return money end
_G.C_AuctionHouse={SupportsCopperValues=function() return copper end,IsThrottledMessageSystemReady=function() return ready end}
for _,key in ipairs({"ITEM","DEPOSIT","QUANTITY","PRICE","BUYOUT"}) do _G["AUCTION_HOUSE_SELL_FRAME_ERROR_"..key]="Native "..key end
_G.ERR_GENERIC_THROTTLE="Native throttle"
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
panel:UpdatePostState()
assert(panel.PriceInput.Label.textColor[1]==.9 and panel.Deposit.Label.textColor[1]==.9,
 "native normal sell label color must map to neutral QUI after refresh")
assert(panel.Deposit.amount==200 and panel.TotalPrice.amount==400 and panel.PostButton:IsEnabled()
 and panel.QuantityInput.MaxButton:IsEnabled() and not panel.PriceInput.PriceError:IsShown(),
 "native deposit rounding total eligibility and Max state must remain")
buyout=100
panel:UpdatePostState()
assert(panel.PriceInput.Label.textColor[2]==.1 and panel.PriceInput.LabelTitle.textColor[2]==.1
 and panel.PriceInput.PriceError:IsShown() and not panel.PostButton:IsEnabled()
 and panel.PostButton.nativeTooltip=="Native BUYOUT","invalid bid/buyout warning color icon and eligibility must remain")
buyout=250;copper=true;quantity=5
panel:UpdatePostState()
assert(panel.PriceInput.Label.textColor[1]==.9 and not panel.PriceInput.PriceError:IsShown()
 and panel.Deposit.amount==155 and panel.TotalPrice.amount==1250 and not panel.QuantityInput.MaxButton:IsEnabled(),
 "valid reuse must neutralize native normal color while retaining exact copper totals and Max limit")
money=100
panel:UpdatePostState()
assert(not panel.PostButton:IsEnabled() and panel.PostButton.nativeTooltip=="Native DEPOSIT","insufficient deposit must retain native reason")
money=1000;quantity=0
panel:UpdatePostState()
assert(not panel.PostButton:IsEnabled() and panel.PostButton.nativeTooltip=="Native QUANTITY","zero quantity must retain native reason")
quantity=1;ready=false
panel:UpdatePostState()
assert(not panel.PostButton:IsEnabled() and panel.PostButton.nativeTooltip=="Native throttle","native throttling must remain")
ready=true;valid=false
panel:UpdatePostState()
assert(not panel.PostButton:IsEnabled() and panel.PostButton.nativeTooltip=="Native ITEM","invalid item must retain native reason")
valid=true;bid=nil;buyout=nil
panel:UpdatePostState()
assert(not panel.PostButton:IsEnabled() and panel.PostButton.nativeTooltip=="Native PRICE","missing prices must retain native reason")
bid=100;buyout=200;panel.multisellInProgress=true
panel:UpdatePostState()
assert(not panel.PostButton:IsEnabled(),"native multisell must retain disabled Post")
panel.multisellInProgress=false
panel:UpdatePostState()
_G.QUI_RefreshAuctionHouseColors()
assert(panel.PostButton:IsEnabled() and panel.PostButton:GetScript("OnClick")==click
 and panel.Deposit.MoneyDisplayFrame.Text.textColor[2]==.1 and panel.PriceInput.Subtext.textColor[1]==.5,
 "theme must preserve native action semantic money and subtext colors")
print("auctionhouse sell post states passed")
