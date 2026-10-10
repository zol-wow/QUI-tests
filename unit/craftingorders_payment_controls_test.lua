local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinCraftingOrders=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
_G.COPPER_PER_GOLD=10000;_G.COPPER_PER_SILVER=100
local colorblind=arg[2]=="colorblind"
_G.CVarCallbackRegistry={GetCVarValueBool=function() return colorblind end}
_G.MONEY_DENOMINATION_SYMBOLS_BY_DISPLAY_TYPE={[1]="gold",[2]="silver",[3]="copper"}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_MoneyFrame/Shared/MoneyInputFrame.lua"))()
local root=frame();_G.ProfessionsCustomerOrdersFrame=root
local form=frame(nil,root);root.Form=form;form.BackButton=false
local payment=frame(nil,form);form.PaymentContainer=payment
payment.CancelOrderButton=false;payment.ListOrderButton=false
payment.NoteEditBox=false;payment.DurationDropdown=false
local input=frame(nil,payment);payment.TipMoneyInputFrame=input
for _,key in ipairs({"SetAmount","GetAmount","SetEnabled"}) do input[key]=_G.LargeMoneyInputFrameMixin[key] end
for index,key in ipairs({"GoldBox","SilverBox","CopperBox"}) do
 local field=frame("EditBox",input);input[key]=field
 field.Icon=field:CreateTexture();field.Text=field:CreateFontString()
 field.displayType=index;field.iconAtlas="native-coin-"..index;field.number=0
 function field:SetNumber(value) self.number=value end
 function field:GetNumber() return self.number end
 function field:SetTextColor(...) self.textColor={...} end
 function field:SetEnabled(value)
  self.enabled=value;self:SetTextColor(value and 1 or .4,value and 1 or .4,value and 1 or .4,1)
 end
 for _,method in ipairs({"OnLoad","SetAmount","GetAmount"}) do field[method]=_G.LargeMoneyInputBoxMixin[method] end
 field:OnLoad();field:SetTextColor(1,0,0,1)
 field:SetScript("OnTextChanged",function() error("commission callback invoked by styling") end)
end
input.CopperBox:Hide();input:SetAmount(12345)
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
for _,key in ipairs({"Tip","Duration","TimeRemaining","PostingFee","TotalPrice"}) do
 payment[key]=payment:CreateFontString();payment[key]:SetText(key);payment[key]:SetTextColor(1,.82,0,1)
end
for _,key in ipairs({"TipMoneyDisplayFrame","PostingFeeMoneyDisplayFrame","TotalPriceMoneyDisplayFrame","TimeRemainingDisplay"}) do
 local display=frame(nil,payment);payment[key]=display
 display.Text=display:CreateFontString();display.Text:SetTextColor(1,0,0,1)
 function display:SetAmount(amount) self.amount=amount;self.Text:SetText("native-money:"..amount) end
end
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrdersForm.lua"))
local native=f:read("*a");f:close()
_G.ProfessionsCustomerOrderFormMixin={}
assert(loadstring(assert(native:match("(function ProfessionsCustomerOrderFormMixin:UpdateTotalPrice.-\nend)")),"@native-order-total"))()
form.UpdateTotalPrice=_G.ProfessionsCustomerOrderFormMixin.UpdateTotalPrice
form.depositCost=155;form.committed=false
local eligibility=0
function form:UpdateListOrderButton() eligibility=eligibility+1 end
_G.C_Timer.After=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/craftingorders.lua"))("QUI",ns)
for index,key in ipairs({"GoldBox","SilverBox","CopperBox"}) do
 local field=input[key]
 assert(skin.GetBackdrop(field) and skin.GetBackdrop(field)._quiRoundedSurface,
 "commission denomination field must receive rounded QUI chrome")
 assert(field.Icon:GetAlpha()==1 and field.Icon:IsShown()==not colorblind
 and field.Icon.atlas=="native-coin-"..index,"native denomination icon must retain visibility and art")
 assert(colorblind and field.Text:GetText()==_G.MONEY_DENOMINATION_SYMBOLS_BY_DISPLAY_TYPE[index]
 or not colorblind and (field.Text:GetText()==nil or field.Text:GetText()==""), "native colorblind denomination symbols must remain")
 assert(field.textColor[2]==0,"native semantic input color must survive font handling")
end
assert(input:GetAmount()==12345 and not input.CopperBox:IsShown() and eligibility==0
 and payment.Tip.textColor[1]==.9,"styling must preserve commission/copper visibility and normalize static labels")
form:UpdateTotalPrice()
assert(payment.TotalPriceMoneyDisplayFrame.amount==12500 and eligibility==1
 and payment.TotalPriceMoneyDisplayFrame.Text.textColor[2]==0,
 "native uncommitted total must retain deposit plus commission and eligibility update")
input:SetEnabled(false)
_G.QUI_RefreshCraftingOrdersColors()
assert(input.GoldBox.textColor[1]==.4 and input:GetAmount()==12345 and eligibility==1,
 "theme must preserve native disabled input color and amount without eligibility callbacks")
form.committed=true;form.order={tipAmount=34000};form:UpdateTotalPrice()
assert(payment.TotalPriceMoneyDisplayFrame.amount==34155 and eligibility==1,
 "native committed total must use recorded order tip without eligibility callback")
local color=payment.TotalPriceMoneyDisplayFrame.Text.textColor
_G.QUI_RefreshCraftingOrdersColors()
assert(payment.TotalPriceMoneyDisplayFrame.Text.textColor==color and not input.CopperBox:IsShown(),
 "theme must retain native money warning and hidden copper")
env.profile.general.skinCraftingOrders=false
input.GoldBox.Icon:SetAlpha(.65)
form:UpdateTotalPrice()
assert(input.GoldBox.Icon:GetAlpha()==.65,"disabled skin must stop commission presentation refresh")
print("craftingorders payment controls passed")
