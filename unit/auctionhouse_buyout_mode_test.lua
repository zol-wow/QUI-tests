local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local panel=frame(nil,ah);ah.ItemSellFrame=panel
local check=frame("CheckButton",panel);panel.BuyoutModeCheckButton=check
check.Text=check:CreateFontString()
local textures={}
for _,name in ipairs({"Normal","Pushed","Highlight","Checked","DisabledChecked"}) do
 textures[name]=check:CreateTexture();textures[name]:SetTexture("native-"..name)
 check["Get"..name.."Texture"]=function() return textures[name] end
end
function check:SetChecked(value) self.checked=value end
function check:GetChecked() return self.checked end
panel.PriceInput=frame(nil,panel)
local price=panel.PriceInput
price.PerItemPostfix=price:CreateFontString()
function price:SetLabel(value) self.label=value end
function price:SetSubtext(value) self.subtext=value end
panel.SecondaryPriceInput=frame(nil,panel)
local clears,updates,focus,dirty,resets=0,0,0,0,0
function panel.SecondaryPriceInput:Clear() clears=clears+1 end
function panel:UpdatePostState() updates=updates+1 end
function panel:UpdateFocusTabbing() focus=focus+1 end
function panel:MarkDirty() dirty=dirty+1 end
function panel:SetItem(item,fromDisplay,refreshPrevious)
 assert(item==nil and fromDisplay==nil and refreshPrevious);resets=resets+1
end
panel.DisabledOverlay=frame("Button",panel)
local overlay=panel.DisabledOverlay
local shade=overlay:CreateTexture();shade:SetVertexColor(0,0,0,.4)
_G.AuctionHouseMultisellProgressFrame=frame()
_G.AuctionHouseMultisellProgressFrame.CancelButton=false
local nativeFile=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemSellFrame.lua"))
local native=nativeFile:read("*a");nativeFile:close()
_G.AuctionHouseBuyoutModeCheckButtonMixin={}
_G.AuctionHouseItemSellFrameMixin={}
local function method(mixin,key)
 assert(loadstring(assert(native:match("(function "..mixin..":"..key..".-\nend)")),"@native-buyout-"..key))()
 return _G[mixin][key]
end
for _,key in ipairs({"OnLoad","OnShow","OnEnter","OnLeave","OnClick","UpdateState"}) do
 check[key]=method("AuctionHouseBuyoutModeCheckButtonMixin",key)
end
for _,key in ipairs({"OnShow","OnEnter","OnLeave","OnClick"}) do check:SetScript(key,check[key]) end
panel.SetSecondaryPriceInputEnabled=method("AuctionHouseItemSellFrameMixin","SetSecondaryPriceInputEnabled")
panel.SetMultiSell=method("AuctionHouseItemSellFrameMixin","SetMultiSell")
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
_G.GameFontNormal={}
_G.AUCTION_HOUSE_BUYOUT_MODE_CHECK_BOX="Native buyout only"
_G.AUCTION_HOUSE_BUYOUT_MODE_TOOLTIP="Native mode tooltip"
_G.AUCTION_HOUSE_BUYOUT_LABEL="Native buyout"
_G.AUCTION_HOUSE_BUYOUT_OPTIONAL_LABEL="Native optional"
_G.SOUNDKIT={IG_MAINMENU_OPTION_CHECKBOX_ON=123}
local sounds=0
_G.PlaySound=function(id) assert(id==123);sounds=sounds+1 end
local tooltip={}
_G.GameTooltip=tooltip
function tooltip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
function tooltip:Show() self.shown=true end
_G.GameTooltip_AddNormalLine=function(t,text,wrap) t.text=text;t.wrap=wrap end
_G.GameTooltip_Hide=function() tooltip.shown=false end
check:OnLoad();check:OnShow()
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(textures.Normal:GetAlpha()==0 and skin.GetBackdrop(check),
 "buyout mode must replace native checkbox decoration")
assert(check.Text:GetText()=="Native buyout only" and check.Text.textColor[1]==.9,
 "buyout mode caption must retain native text with neutral QUI typography")
assert(check:GetChecked() and not panel.SecondaryPriceInput:IsShown() and price.PerItemPostfix:IsShown(),
 "native default checked mode must hide secondary bid")
local click=check:GetScript("OnClick")
check:SetChecked(false);check:OnClick()
assert(not check:GetChecked() and panel.SecondaryPriceInput:IsShown() and not price.PerItemPostfix:IsShown()
 and price.subtext=="Native optional" and sounds==1,
 "native unchecked mode must show secondary bid and optional buyout caption")
local counts={clears,updates,focus,dirty}
textures.Checked:SetVertexColor(0,1,0,1);textures.DisabledChecked:SetVertexColor(0,1,0,1)
_G.QUI_RefreshAuctionHouseColors()
local ar,ag,ab=ns.UIKit.GetAccentColor()
assert(textures.Checked.vertex[1]==ar and textures.DisabledChecked.vertex[1]==ar*.5,
 "theme refresh must restore active and disabled checkbox accents")
assert(not check:GetChecked() and panel.SecondaryPriceInput:IsShown() and clears==counts[1]
 and updates==counts[2] and focus==counts[3] and dirty==counts[4] and sounds==1,
 "styling must not rerun native mode mutation or clear entered prices")
check:OnEnter()
assert(tooltip.shown and tooltip.owner==check and tooltip.anchor=="ANCHOR_RIGHT"
 and tooltip.text=="Native mode tooltip" and tooltip.wrap,"native mode tooltip must remain")
check:OnLeave();assert(not tooltip.shown,"native tooltip dismissal must remain")
panel:SetMultiSell(true)
_G.QUI_RefreshAuctionHouseColors()
assert(overlay:IsShown() and _G.AuctionHouseMultisellProgressFrame:IsShown()
 and shade:GetAlpha()==1 and panel.multisellInProgress and resets==0,
 "multisell overlay and progress must remain active across styling")
panel:SetMultiSell(false)
assert(not overlay:IsShown() and not _G.AuctionHouseMultisellProgressFrame:IsShown() and resets==1,
 "native multisell completion must dismiss overlay and reset item")
check:SetChecked(true);check:OnClick()
assert(not panel.SecondaryPriceInput:IsShown() and price.subtext==nil and sounds==2
 and check:GetScript("OnClick")==click,"native checked mode and click ownership must remain")
print("auctionhouse buyout mode checkbox passed")
