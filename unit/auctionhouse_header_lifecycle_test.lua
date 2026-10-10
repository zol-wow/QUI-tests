local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local function read(path)
 local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local native=read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseTableBuilder.lua")
_G.AuctionHouseTableHeaderStringMixin={}
for _,key in ipairs({"OnClick","Init","UpdateArrow","SetArrowState"}) do
 assert(loadstring(assert(native:match("(function AuctionHouseTableHeaderStringMixin:"..key..".-\nend)")),"@native-ah-header-"..key))()
end
local copied={}
for k,v in pairs(_G.AuctionHouseTableHeaderStringMixin) do copied[k]=v end
_G.AuctionHouseSortOrderState={PrimarySorted=1,PrimaryReversed=2,Unsorted=3}
local ah=frame();_G.AuctionHouseFrame=ah
ah.BrowseResultsFrame=frame(nil,ah)
local list=frame(nil,ah.BrowseResultsFrame);ah.BrowseResultsFrame.ItemList=list
list.ScrollBox=frame(nil,list);list.ScrollBox:SetSize(300,200)
local state,clicks,registered=1,0,0
local owner={}
function owner:GetSortOrderState(order) return order==7 and state or 3 end
function owner:RegisterHeader() registered=registered+1 end
function owner:SetSortOrder(order) assert(order==7);state=state==1 and 2 or 1;clicks=clicks+1 end
local function header()
 local h=frame("Button",list)
 h.Text=h:CreateFontString()
 for _,key in ipairs({"Left","Middle","Right","Arrow","Highlight"}) do h[key]=h:CreateTexture() end
 h.Arrow:SetAtlas("auctionhouse-ui-sortarrow");h.Arrow:SetPoint("LEFT",h.Text,"RIGHT",3,0)
 function h:GetHighlightTexture() return self.Highlight end
 function h:GetFontString() return self.Text end
 function h:SetText(value) self.Text:SetText(value) end
 function h:SetEnabled(value) self.enabled=value end
 function h:IsEnabled() return self.enabled end
 for k,v in pairs(copied) do h[k]=v end
 h:SetScript("OnClick",h.OnClick)
 return h
end
local first=header();first:Init(owner,"Native unit price",7)
local second=header()
local headers={[first]=true}
local builder={}
list.tableBuilder=builder
_G.TableBuilderMixin={}
local tableNative=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/TableBuilder.lua")
assert(loadstring(assert(tableNative:match("(function TableBuilderMixin:EnumerateHeaders.-\nend)")),"@native-enumerate-ah-headers"))()
builder.EnumerateHeaders=_G.TableBuilderMixin.EnumerateHeaders
builder.headerPoolCollection={EnumerateActive=function() return pairs(headers) end}
local resets,arranges=0,0
function builder:Reset() resets=resets+1;headers={} end
function builder:SetTableWidth(width) self.width=width end
function builder:Arrange() arranges=arranges+1 end
list.tableBuilderLayoutFunction=function() headers[second]=true;second:Init(owner,"Native recycled price",7) end
_G.AuctionHouseItemListMixin={}
local listNative=read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemList.lua")
assert(loadstring(assert(listNative:match("(function AuctionHouseItemListMixin:UpdateTableBuilderLayout.-\nend)")),"@native-ah-layout"))()
list.UpdateTableBuilderLayout=_G.AuctionHouseItemListMixin.UpdateTableBuilderLayout
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(first.Left:GetAlpha()==0 and first.Middle:GetAlpha()==0 and first.Highlight:GetAlpha()==0,
 "already initialized copied header must suppress native decoration")
assert(first:IsEnabled() and first.Arrow:IsShown() and first.Arrow.atlas=="auctionhouse-ui-sortarrow"
 and first.Arrow.texCoord[3]==1,"native initial sorted arrow and eligibility must remain")
local click=first:GetScript("OnClick")
first:OnClick()
assert(clicks==1 and first.Arrow:IsShown() and first.Arrow.texCoord[3]==0,
 "native sorting click must retain reversed arrow direction")
first:Init(owner,"Native unsortable",nil)
assert(not first:IsEnabled() and not first.Arrow:IsShown() and first.Text:GetText()=="Native unsortable",
 "copied Init must preserve unsortable disabled header and hidden arrow")
first:Init(owner,"Native reused price",7)
assert(first:IsEnabled() and first.Arrow:IsShown() and first.Left:GetAlpha()==0,
 "reused copied Init must restore styling and native sortable state")
list.tableBuilderLayoutDirty=true;list:UpdateTableBuilderLayout()
assert(resets==1 and arranges==1 and builder.width==300 and not list.tableBuilderLayoutDirty
 and second.Left:GetAlpha()==0 and second.Arrow:IsShown(),
 "native table rebuild must style pre-copied newly enumerated header without changing layout lifecycle")
second:Init(owner,"Native disabled reused",nil)
_G.QUI_RefreshAuctionHouseColors()
assert(not second:IsEnabled() and not second.Arrow:IsShown() and first:GetScript("OnClick")==click
 and clicks==1 and resets==1 and registered>0,"theme must preserve native disabled state, sorting and handler ownership")
env.profile.general.skinAuctionHouse=false
local fresh=header();fresh:Init(owner,"Untouched",7)
assert(fresh.Left:GetAlpha()==1 and not skin.GetFrameData(fresh,"qAHHeaderInitHooked"),
 "disabled skin must leave fresh header untouched")
print("auctionhouse header sorting lifecycle passed")
