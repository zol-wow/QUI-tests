local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame()
_G.AuctionHouseFrame=ah
local display=frame("Button",ah)
ah.ItemBuyFrame=frame(nil,ah);ah.ItemBuyFrame.ItemDisplay=display
ah.ItemBuyFrame.CancelAuctionButton=false
display.Name=display:CreateFontString()
display.Background=display:CreateTexture()
display.NineSlice=frame(nil,display)
local item=frame("Button",display)
display.ItemButton=item
item.Icon=item:CreateTexture()
item.CircleMask=item:CreateTexture();item.Count=item:CreateFontString()
item.IconBorder=item:CreateTexture()
item.highlight=item:CreateTexture()
function item:GetHighlightTexture() return self.highlight end
local masks,removed,writes=0,0,0
function item:CreateMaskTexture() local m=self:CreateTexture();m.kind="MaskTexture";return m end
function item.Icon:AddMaskTexture() masks=masks+1 end
function item.highlight:AddMaskTexture() masks=masks+1 end
function item.Icon:RemoveMaskTexture(mask) assert(mask==item.CircleMask);removed=removed+1 end
local click=function() writes=writes+1 end
display:SetScript("OnClick",click);item:SetScript("OnClick",click)
local file=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua"))
local source=file:read("*a");file:close()
_G.AuctionHouseItemDisplayMixin={}
for _,key in ipairs({"Reset","SetItemInternal","OnEvent"}) do
 local method=assert(source:match("(function AuctionHouseItemDisplayMixin:"..key..".-)\nfunction "))
 assert(loadstring(method,"@native-auction-item-"..key))()
end
display.OnEvent=_G.AuctionHouseItemDisplayMixin.OnEvent
display.Reset=_G.AuctionHouseItemDisplayMixin.Reset
display.SetItemInternal=_G.AuctionHouseItemDisplayMixin.SetItemInternal
local cached=true
local quality=4
local colors={[4]={.64,.21,.93,1},[2]={.12,1,.1,1}}
_G.ColorManager={GetColorDataForItemQuality=function(q)
 local values=colors[q]
 if not values then return nil end
 return {color={GetRGBA=function() return unpack(values) end,
 WrapTextInColorCode=function(_,text) return "quality:"..q..":"..text end}}
end}
function display:GetItemInfo() return "Native item",cached and "item:native" or nil,quality,100,"native-art" end
function display:IsPet() return false end
function display:GetItemDisplayText(name) return name end
function display:RegisterEvent(event) self.registered=event end
function display:UnregisterEvent(event) self.unregistered=event end
function item:UnlockHighlight() self.unlocked=true end
display.getItemCount=function() return 7 end
_G.SetItemButtonCount=function(button,value) button.Count:SetText(value and tostring(value) or "") end
_G.SetItemButtonTexture=function(button,value) button.Icon:SetTexture(value) end
_G.SetItemButtonQuality=function(button,q)
 button.IconBorder:SetVertexColor(1,1,1,1)
 button.IconBorder:SetShown(q~=nil)
end
ns.SafeCall=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
display:SetItemInternal(123)
local border=skin.GetFrameData(item.Icon,"iconBorder")
assert(border and border._quiRoundedSurface and masks==2 and removed>0,"native nested auction icon must receive rounded mask and border")
assert(item.Icon.texture=="native-art" and item.Count:GetText()=="7" and display.Name:GetText()=="quality:4:Native item",
 "native item art count and inline quality name must remain")
assert(border._quiBorderR==.64 and border._quiBorderB==.93 and item.IconBorder:GetAlpha()==0,
 "rounded quality border must use native quality color instead of white atlas vertex")
assert(display.Background:GetAlpha()==0 and display.NineSlice:GetAlpha()==0
 and skin.GetBackdrop(display)._quiRoundedSurface,"native display decoration must receive rounded QUI shell")
assert(item.highlight.texture==[[Interface\Buttons\WHITE8x8]] and item.unlocked,
 "highlight must use contained QUI tint while native unlock remains")
quality=2
display:SetItemInternal(456)
assert(border._quiBorderG==1 and masks==2,"native quality reuse must refresh border without duplicate masks")
display:Reset()
local sr=skin.GetWindowColors()
assert(item.Icon.texture==nil and display.Name:GetText()=="" and item.Count:GetText()=="" and border._quiBorderR==sr,
 "native empty reset must remove art/name/count and restore neutral border")
cached=false
display:SetItemInternal(789)
assert(display.pendingInfo.item==789 and display.registered=="GET_ITEM_INFO_RECEIVED" and item.Icon.texture==nil,
 "uncached native setup must preserve pending data event and empty art")
cached=true;quality=4
display:OnEvent("GET_ITEM_INFO_RECEIVED",789)
assert(display.unregistered=="GET_ITEM_INFO_RECEIVED" and item.Icon.texture=="native-art" and border._quiBorderR==.64,
 "cached native retry must restore art and quality chrome")
_G.QUI_RefreshAuctionHouseColors()
assert(masks==2 and display:GetScript("OnClick")==click and item:GetScript("OnClick")==click and writes==0,
 "theme refresh must reuse masks preserve handlers and invoke no auction action")
local late=frame("Button",ah)
late.Name=late:CreateFontString()
late.ItemButton=frame("Button",late)
local lateItem=late.ItemButton
lateItem.Icon=lateItem:CreateTexture();lateItem.CircleMask=lateItem:CreateTexture()
lateItem.IconBorder=lateItem:CreateTexture();lateItem.Count=lateItem:CreateFontString()
lateItem.highlight=lateItem:CreateTexture()
lateItem.GetHighlightTexture=item.GetHighlightTexture
lateItem.UnlockHighlight=item.UnlockHighlight
lateItem.CreateMaskTexture=item.CreateMaskTexture
lateItem.Icon.AddMaskTexture=item.Icon.AddMaskTexture
lateItem.highlight.AddMaskTexture=item.highlight.AddMaskTexture
function lateItem.Icon:RemoveMaskTexture(mask) assert(mask==lateItem.CircleMask) end
for _,key in ipairs({"GetItemInfo","IsPet","GetItemDisplayText","RegisterEvent","UnregisterEvent"}) do late[key]=display[key] end
for _,key in ipairs({"Reset","SetItemInternal","OnEvent"}) do late[key]=_G.AuctionHouseItemDisplayMixin[key] end
quality=2
late:SetItemInternal(456)
local lateBorder=skin.GetFrameData(lateItem.Icon,"iconBorder")
assert(lateBorder and lateBorder._quiBorderG==1 and masks==4,
 "later copied mixin methods must receive presentation and exactly one mask per native texture")
late:SetItemInternal(456)
_G.QUI_RefreshAuctionHouseColors()
assert(masks==4 and skin.GetFrameData(late,"qAHItemInstanceHooked"),
 "overlapping mixin/instance refresh paths must reuse masks and install instance hooks once")
late:Reset()
assert(lateItem.Icon.texture==nil and lateBorder._quiBorderR==sr,
 "later instance reset must restore native empty art and neutral border")
env.profile.general.skinAuctionHouse=false
local before=removed
display:SetItemInternal(999)
assert(removed==before,"disabled auction skin must stop subsequent item styling")
print("auctionhouse item display passed")
