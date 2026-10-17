local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local function read(path)
 local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local native=read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua")
_G.AuctionHouseSellFrameMixin={}
_G.AuctionHouseSellFrameOverlayMixin={}
_G.AuctionHousePriceErrorFrameMixin={}
_G.AuctionHouseAlignedPriceInputFrameMixin={}
local function extract(mixin,key,source)
 assert(loadstring(assert(source:match("(function "..mixin..":"..key..".-)\nfunction ")),
 "@native-"..mixin.."-"..key))()
 return _G[mixin][key]
end
local ah=frame();_G.AuctionHouseFrame=ah
local panels={}
for _,name in ipairs({"CommoditiesSellFrame","ItemSellFrame"}) do
 local panel=frame(nil,ah);ah[name]=panel;panels[#panels+1]=panel
 panel.Overlay=frame("Button",panel)
 panel.ItemDisplay=frame("Button",panel)
 local display=panel.ItemDisplay
 display.Name=display:CreateFontString()
 display.ItemButton=frame("Button",display)
 local item=display.ItemButton
 item.Icon=item:CreateTexture();item.Count=item:CreateFontString()
 item.IconBorder=item:CreateTexture();item.highlight=item:CreateTexture()
 function item:GetHighlightTexture() return self.highlight end
 function item:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
 function item.Icon:AddMaskTexture() end
 function item.highlight:AddMaskTexture() end
 function item:LockHighlight() self.highlightLocked=true;self.highlight:Show() end
 function item:UnlockHighlight() self.highlightLocked=false;self.highlight:Hide() end
 function display:GetItemInfo() return nil end
 function display:SwitchItemWithCursor() error("cursor exchange invoked") end
 _G.AuctionHouseItemDisplayMixin=_G.AuctionHouseItemDisplayMixin or {}
 display.SetHighlightLocked=extract("AuctionHouseItemDisplayMixin","SetHighlightLocked",
 read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua"))
 for _,key in ipairs({"OnOverlayEnter","OnOverlayLeave","OnOverlayClick","OnOverlayReceiveDrag"}) do
  panel[key]=extract("AuctionHouseSellFrameMixin",key,native)
 end
 for _,key in ipairs({"OnEnter","OnLeave","OnClick","OnReceiveDrag"}) do
  local fn=extract("AuctionHouseSellFrameOverlayMixin",key,native)
  panel.Overlay[key]=fn;panel.Overlay:SetScript(key,fn)
 end
 panel.PriceInput=frame(nil,panel)
 local price=panel.PriceInput
 price.PriceError=frame(nil,price)
 local warning=price.PriceError
 warning.art=warning:CreateTexture();warning.art:SetTexture("native-alert-icon")
 warning.art:SetSize(20,20)
 for _,key in ipairs({"OnEnter","OnLeave","SetTooltip"}) do
  warning[key]=extract("AuctionHousePriceErrorFrameMixin",key,native)
 end
 warning:SetScript("OnEnter",warning.OnEnter);warning:SetScript("OnLeave",warning.OnLeave)
 for _,key in ipairs({"SetErrorTooltip","SetErrorShown"}) do
  price[key]=extract("AuctionHouseAlignedPriceInputFrameMixin",key,native)
 end
 price:SetErrorTooltip("Native invalid price");price:SetErrorShown(false)
end
local cursor
_G.C_Cursor={GetCursorItem=function() return cursor end}
local tooltip={shown=false}
_G.GameTooltip=tooltip
function tooltip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
function tooltip:Show() self.shown=true end
_G.RED_FONT_COLOR={}
_G.GameTooltip_AddColoredLine=function(t,text,color,wrap)
 t.text=text;t.color=color;t.wrap=wrap
end
_G.GameTooltip_Hide=function() tooltip.shown=false end
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
for _,panel in ipairs(panels) do
 local overlay=panel.Overlay
 local item=panel.ItemDisplay.ItemButton
 local price=panel.PriceInput
 local warning=price.PriceError
 local click,drag=overlay:GetScript("OnClick"),overlay:GetScript("OnReceiveDrag")
 local enter,leave=warning:GetScript("OnEnter"),warning:GetScript("OnLeave")
 cursor=nil;overlay:OnEnter()
 assert(not item.highlightLocked,"empty cursor must not lock item highlight")
 cursor={native=true};overlay:OnEnter()
 assert(item.highlightLocked and item.highlight:IsShown()
 and item.highlight.texture==[[Interface\Buttons\WHITE8x8]],
 "native cursor hover must lock the contained QUI item highlight")
 _G.QUI_RefreshAuctionHouseColors()
 assert(item.highlightLocked and item.highlight:IsShown(),"theme refresh must retain native hover lock")
 overlay:OnLeave()
 assert(not item.highlightLocked and not item.highlight:IsShown(),"native overlay leave must unlock highlight")
 price:SetErrorShown(true);warning:OnEnter()
 assert(warning:IsShown() and tooltip.shown and tooltip.owner==warning and tooltip.anchor=="ANCHOR_RIGHT"
 and tooltip.text=="Native invalid price" and tooltip.color==_G.RED_FONT_COLOR and tooltip.wrap,
 "native warning tooltip must retain owner, message, red semantics and wrapping")
 _G.QUI_RefreshAuctionHouseColors()
 assert(warning.art:GetAlpha()==1 and warning.art.texture=="native-alert-icon" and warning:IsShown(),
 "theme refresh must preserve native warning artwork and visibility")
 warning:OnLeave();price:SetErrorShown(false)
 assert(not tooltip.shown and not warning:IsShown(),"native warning leave and dismissal must remain")
 warning:SetTooltip(nil);warning:OnEnter()
 assert(not tooltip.shown,"empty warning tooltip must remain silent")
 assert(overlay:GetScript("OnClick")==click and overlay:GetScript("OnReceiveDrag")==drag
 and warning:GetScript("OnEnter")==enter and warning:GetScript("OnLeave")==leave,
 "cursor and warning handlers must retain native ownership")
end
print("auctionhouse sell overlay and warning passed")
