local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
_G.CreateFromMixins=function(...)
 local result={};for _,base in ipairs({...}) do for k,v in pairs(base) do result[k]=v end end;return result
end
_G.AuctionHouseSystemMixin={}
local states
_G.EnumUtil={MakeEnum=function(...)
 states={};for i,key in ipairs({...}) do states[key]=i end;return states
end}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseBuyDialog.lua"))()
local ah=frame();_G.AuctionHouseFrame=ah
local dialog=frame(nil,ah);ah.BuyDialog=dialog
dialog:SetFrameLevel(1000);dialog:Hide()
for k,v in pairs(_G.AuctionHouseBuyDialogMixin) do dialog[k]=v end
dialog.Border=frame(nil,dialog)
dialog.ItemDisplay=frame(nil,dialog);dialog.ItemDisplay.ItemText=dialog.ItemDisplay:CreateFontString()
dialog.PriceFrame=frame(nil,dialog);dialog.PriceFrame.Amount=dialog.PriceFrame:CreateFontString()
dialog.PriceFrame.Amount:SetTextColor(1,.1,.1,1)
function dialog.PriceFrame:SetAmount(value) self.amount=value;self.Amount:SetText(tostring(value)) end
function dialog.PriceFrame:GetAmount() return self.amount end
dialog.TimeLeftText=dialog:CreateFontString();dialog.TimeLeftText:SetTextColor(1,.1,.1,1)
local writes=0
local click=function() writes=writes+1 end
_G.ButtonWithDisableMixin={}
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_UIPanelTemplates/Shared/UIPanelTemplatesShared.lua"))
local source=file:read("*a");file:close()
assert(loadstring(assert(source:match("(function ButtonWithDisableMixin:SetDisableTooltip.-)\nfunction ")),"@native-disable-tooltip"))()
for _,key in ipairs({"BuyNowButton","CancelButton","OkayButton"}) do
 local button=frame("Button",dialog);dialog[key]=button
 button.Text=button:CreateFontString();button.Text:SetText(key)
 function button:GetFontString() return self.Text end
 button.enabled=true
 function button:IsEnabled() return self.enabled end
 function button:SetEnabled(value)
  local changed=self.enabled~=value;self.enabled=value
  if changed then self:Fire(value and "OnEnable" or "OnDisable") end
 end
 button:SetScript("OnClick",click)
end
dialog.BuyNowButton.SetDisableTooltip=_G.ButtonWithDisableMixin.SetDisableTooltip
function dialog.OkayButton:GetTop() return 20 end
function dialog:GetBottom() return 0 end
function dialog:SetHeight(value) self.nativeHeight=value end
dialog.DarkOverlay=frame(nil,dialog);dialog.LoadingSpinner=frame(nil,dialog)
dialog.Notification=frame(nil,dialog);dialog.Notification.Text=dialog.Notification:CreateFontString()
dialog.Notification.Button=frame("Button",dialog.Notification)
for k,v in pairs(_G.AuctionHouseBuyDialogNotificationFrameMixin) do dialog.Notification[k]=v end
_G.GameFontNormal={}
_G.AUCTION_HOUSE_DIALOG_PRICE_UPDATED="Native price updated"
_G.AUCTION_HOUSE_DIALOG_PRICE_UNAVAILABLE="Native price unavailable"
_G.AUCTION_HOUSE_TOOLTIP_TITLE_NOT_ENOUGH_MONEY="Native insufficient money"
_G.AUCTION_HOUSE_DIALOG_ITEM_FORMAT="%s x %d"
_G.AuctionHouseUtil={SanitizeAuctionHousePrice=function(value) return value end}
_G.C_Item={GetItemNameByID=function() return "Native commodity" end,GetItemQualityByID=function() return 4 end}
_G.Enum={ItemQuality={Common=1}}
_G.ColorManager={GetColorDataForItemQuality=function()
 return {color={WrapTextInColorCode=function(_,name) return "quality:"..name end}}
end}
local money=1000
_G.GetMoney=function() return money end
ns.SafeCall=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(skin.GetBackdrop(dialog) and skin.GetBackdrop(dialog)._quiRoundedSurface and dialog.Border:GetAlpha()==0,
 "buy dialog must receive rounded QUI shell in place of native border")
for _,key in ipairs({"BuyNowButton","CancelButton","OkayButton"}) do
 assert(skin.GetBackdrop(dialog[key]) and skin.GetBackdrop(dialog[key])._quiRoundedSurface,
  "each native dialog action must receive rounded QUI chrome")
end
assert(not dialog:IsShown(),"styling must leave closed buy dialog closed")
dialog:SetItemID(123,2,100,200)
assert(dialog.ItemDisplay.ItemText:GetText()=="quality:Native commodity x 2" and dialog.PriceFrame:GetAmount()==200
 and dialog.BuyNowButton:IsShown() and not dialog.BuyNowButton:IsEnabled()
 and dialog.nativeHeight==100,"native waiting quote item/price and eligibility must remain")
dialog:SetState(states.PriceConfirmed)
assert(dialog.BuyNowButton:IsEnabled() and dialog.CancelButton:IsEnabled()
 and dialog:GetScript("OnUpdate")==_G.AuctionHouseBuyDialogMixin.OnUpdate,
 "native confirmed state must enable actions and attach quote timer")
money=100
dialog:SetState(states.PriceConfirmed)
assert(not dialog.BuyNowButton:IsEnabled() and dialog.BuyNowButton.disableTooltipTitle=="Native insufficient money",
 "native affordability tooltip and disabled purchase must remain")
money=1000
dialog:OnEvent("COMMODITY_PRICE_UPDATED",102,204)
assert(dialog.PriceFrame:GetAmount()==204 and dialog.Notification:IsShown()
 and dialog.Notification.Button:IsShown() and dialog.Notification.Text:GetText()=="Native price updated"
 and dialog.nativeHeight==126,"native small price increase and warning icon must remain")
dialog:OnEvent("COMMODITY_PRICE_UPDATED",200,400)
assert(dialog.OkayButton:IsShown() and not dialog.BuyNowButton:IsShown()
 and not dialog.ItemDisplay:IsShown() and dialog.nativeHeight==85
 and dialog.Notification.Text:GetText()=="Native price unavailable","native excessive-price fallback must remain")
dialog:SetState(states.Purchasing)
assert(not dialog.BuyNowButton:IsEnabled() and not dialog.CancelButton:IsEnabled()
 and not dialog.LoadingSpinner:IsShown(),"native purchasing eligibility must remain without purchase invocation")
dialog:SetState(states.Waiting)
assert(dialog.LoadingSpinner:IsShown() and dialog.DarkOverlay:IsShown()
 and dialog.LoadingSpinner:GetAlpha()==1 and dialog.DarkOverlay:GetAlpha()==1,
 "native waiting spinner and overlay must remain visible")
dialog.quoteDurationRemaining=9;dialog:UpdateTimeLeft()
assert(dialog.TimeLeftText:IsShown() and tonumber(dialog.TimeLeftText:GetText())==9
 and dialog.TimeLeftText.textColor[1]==1 and dialog.TimeLeftText.textColor[2]==.1,
 "native timer value visibility and red semantic color must remain")
dialog.quoteDurationRemaining=12;dialog:UpdateTimeLeft()
assert(not dialog.TimeLeftText:IsShown(),"native above-threshold timer must stay hidden")
_G.QUI_RefreshAuctionHouseColors()
assert(dialog.PriceFrame.Amount.textColor[1]==1 and dialog.PriceFrame.Amount.textColor[2]==.1
 and dialog.LoadingSpinner:IsShown() and dialog.DarkOverlay:IsShown() and writes==0
 and dialog.BuyNowButton:GetScript("OnClick")==click,"theme must retain semantic money/loading and invoke no action")
print("auctionhouse buy dialog passed")
