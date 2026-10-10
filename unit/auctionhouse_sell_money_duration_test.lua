local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
_G.COPPER_PER_GOLD=10000;_G.COPPER_PER_SILVER=100
local colorblind=arg and arg[2]=="colorblind"
_G.CVarCallbackRegistry={GetCVarValueBool=function() return colorblind end}
_G.MONEY_DENOMINATION_SYMBOLS_BY_DISPLAY_TYPE={[1]="gold",[2]="silver",[3]="copper"}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_MoneyFrame/Shared/MoneyInputFrame.lua"))()
local sellPath="tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua"
local f=assert(io.open(sellPath));local source=f:read("*a");f:close()
for _,pair in ipairs({
 {"AuctionHouseSellFrameAlignedControlMixin",{"OnLoad","SetLabel"}},
 {"AuctionHouseAlignedDurationMixin",{"OnLoad","OnShow","GetDuration"}},
 {"AuctionHouseSellFrameMixin",{"UpdatePostButtonState","CanPostItem"}}}) do
 _G[pair[1]]={}
 for _,key in ipairs(pair[2]) do
  assert(loadstring(assert(source:match("(function "..pair[1]..":"..key..".-)\nfunction ")),"@native-sell-"..key))()
 end
end
_G.AUCTION_DURATION_ONE="Native 12 hours";_G.AUCTION_DURATION_TWO="Native 24 hours";_G.AUCTION_DURATION_THREE="Native 48 hours"
_G.GetCVar=function() return "2" end
_G.SetCVar=function() error("duration preference written") end
local ah=frame();_G.AuctionHouseFrame=ah
local panels={}
for _,name in ipairs({"CommoditiesSellFrame","ItemSellFrame"}) do
 local panel=frame(nil,ah);ah[name]=panel;panels[#panels+1]=panel
 local keys={"PriceInput","QuantityInput","Duration","Deposit","TotalPrice"}
 if name=="ItemSellFrame" then keys[#keys+1]="SecondaryPriceInput" end
 for _,key in ipairs(keys) do
  local control=frame(nil,panel);panel[key]=control
  control.Label=control:CreateFontString();control.Label:SetText(key);control.Label:SetTextColor(1,.1,.1,1)
  control.LabelTitle=control:CreateFontString();control.Subtext=control:CreateFontString()
  control.PerItemPostfix=control:CreateFontString()
  if key=="PriceInput" or key=="SecondaryPriceInput" then
   control.MoneyInputFrame=frame(nil,control)
   for _,method in ipairs({"SetAmount","GetAmount","SetEnabled"}) do
    control.MoneyInputFrame[method]=_G.LargeMoneyInputFrameMixin[method]
   end
   for i,fieldKey in ipairs({"GoldBox","SilverBox","CopperBox"}) do
    local field=frame("EditBox",control.MoneyInputFrame);control.MoneyInputFrame[fieldKey]=field
    field.Icon=field:CreateTexture();field.Text=field:CreateFontString()
    field.displayType=i;field.iconAtlas="native-coin-"..i;field.number=0
    function field:SetTextColor(...) self.textColor={...} end
    function field:SetNumber(value) self.number=value end
    function field:GetNumber() return self.number end
    function field:SetEnabled(value) self.enabled=value;self:SetTextColor(value and 1 or .4,value and 1 or .4,value and 1 or .4,1) end
    for _,method in ipairs({"OnLoad","SetAmount","GetAmount"}) do field[method]=_G.LargeMoneyInputBoxMixin[method] end
    field:OnLoad();field:SetScript("OnTextChanged",function() error("money change callback invoked") end)
   end
   control.MoneyInputFrame:SetAmount(12345)
  elseif key=="Duration" then
   control.labelText="Native duration"
   control.SetLabel=_G.AuctionHouseSellFrameAlignedControlMixin.SetLabel
   control.Dropdown=frame("Button",control)
   control.Dropdown.Text=control.Dropdown:CreateFontString();control.Dropdown.Arrow=control.Dropdown:CreateTexture()
   function control.Dropdown:SetupMenu(builder) self.nativeMenu=builder end
   function control.Dropdown:GenerateMenu() self.generations=(self.generations or 0)+1 end
   function control.Dropdown:SetWidth(value) self.nativeWidth=value end
   for k,v in pairs(_G.AuctionHouseAlignedDurationMixin) do control[k]=v end
   control:OnLoad();control:OnShow()
  elseif key=="QuantityInput" then
   control.InputBox=frame("EditBox",control);control.MaxButton=frame("Button",control)
  else
   control.MoneyDisplayFrame=frame(nil,control);control.MoneyDisplayFrame.Text=control.MoneyDisplayFrame:CreateFontString()
   control.MoneyDisplayFrame.Text:SetTextColor(1,.1,.1,1)
  end
 end
 panel.PostButton=frame("Button",panel);panel.PostButton.Text=panel.PostButton:CreateFontString()
 function panel.PostButton:GetFontString() return self.Text end
 function panel.PostButton:SetEnabled(value) self.enabled=value end
 function panel.PostButton:SetTooltip(value) self.nativeTooltip=value end
 local item={IsValid=function() return true end}
 function panel:GetItem() return item end
 function panel:GetQuantity() return 1 end
 function panel:GetDepositAmount() return 500 end
 panel.CanPostItem=_G.AuctionHouseSellFrameMixin.CanPostItem
 panel.UpdatePostButtonState=_G.AuctionHouseSellFrameMixin.UpdatePostButtonState
end
local money=1000
_G.GetMoney=function() return money end
_G.C_AuctionHouse={IsThrottledMessageSystemReady=function() return true end}
_G.AUCTION_HOUSE_SELL_FRAME_ERROR_DEPOSIT="Native deposit insufficient"
_G.AUCTION_HOUSE_SELL_FRAME_ERROR_ITEM="Native invalid item"
_G.AUCTION_HOUSE_SELL_FRAME_ERROR_QUANTITY="Native zero quantity"
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
for _,panel in ipairs(panels) do
 for _,key in ipairs(panel==panels[1] and {"PriceInput"} or {"PriceInput","SecondaryPriceInput"}) do
  local input=panel[key].MoneyInputFrame
  for _,fieldKey in ipairs({"GoldBox","SilverBox","CopperBox"}) do
   local field=input[fieldKey]
   assert(field.Icon:GetAlpha()==1 and field.Icon:IsShown()==not colorblind,"sell denomination icon must survive editbox decoration stripping")
   if colorblind then assert(field.Text:GetText()==_G.MONEY_DENOMINATION_SYMBOLS_BY_DISPLAY_TYPE[field.displayType],"native colorblind denomination symbol must remain") end
   assert(skin.GetBackdrop(field)._quiRoundedSurface,"sell money input must retain rounded chrome")
  end
  assert(input:GetAmount()==12345 and panel[key].Label.textColor[2]==.1,"native amount and red price label must remain")
  input:SetEnabled(false)
 end
 local duration=panel.Duration
 assert(skin.GetBackdrop(duration.Dropdown) and skin.GetFrameData(duration.Dropdown,"dropdownCaret"),
 "actual nested sell Duration.Dropdown must receive rounded QUI presentation")
 assert(duration:GetDuration()==2 and duration.Dropdown.nativeWidth==115 and duration.Dropdown.generations==1,
 "native duration value width and menu generation must remain")
 local radios={}
 local root={SetTag=function() end,CreateRadio=function(_,text,selected,choose,index)
  radios[#radios+1]={text=text,selected=selected,choose=choose,index=index}
  return {AddInitializer=function() end}
 end}
 duration.Dropdown.nativeMenu(duration.Dropdown,root)
 assert(#radios==3 and radios[2].selected(2) and not radios[1].selected(1),"native duration radio builder must remain without selecting")
 money=100
 panel:UpdatePostButtonState()
 assert(not panel.PostButton.enabled and panel.PostButton.nativeTooltip=="Native deposit insufficient",
 "native deposit eligibility and reason must remain")
 money=1000
 panel:UpdatePostButtonState()
 assert(panel.PostButton.enabled,"native sufficient deposit must retain eligible Post")
end
_G.QUI_RefreshAuctionHouseColors()
for _,panel in ipairs(panels) do
 assert(panel.PriceInput.MoneyInputFrame.GoldBox.textColor[1]==.4
 and panel.Deposit.MoneyDisplayFrame.Text.textColor[2]==.1 and panel.PriceInput.Label.textColor[2]==.1,
 "theme must preserve disabled money red deposit and price warning colors")
end
print("auctionhouse sell money and duration passed")
