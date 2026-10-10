local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent)
 f.RegisterForWidgetSet=false;f.DisabledTexture=false
 return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local paths={
 browse={"BrowseResultsFrame","ItemList"},
 commodity={"CommoditiesBuyFrame","ItemList"},
 item={"ItemBuyFrame","ItemList"},
 summary={"AuctionsFrame","SummaryList"},
 bids={"AuctionsFrame","BidsList"},
 all={"AuctionsFrame","AllAuctionsList"},
 ownedcommodity={"AuctionsFrame","CommoditiesList"},
 owneditem={"AuctionsFrame","ItemList"},
}
local path=assert(paths[arg[2] or "browse"])
local panel=frame(nil,ah);ah[path[1]]=panel
panel.BackButton=false;panel.CancelAuctionButton=false
local list=frame(nil,panel);panel[path[2]]=list
local refresh=frame(nil,list);list.RefreshFrame=refresh
local button=frame("Button",refresh);refresh.RefreshButton=button
button.Icon=button:CreateTexture();button.Icon:SetAtlas("UI-RefreshButton")
local normal=button:CreateTexture();normal:SetAtlas("native-square")
function button:GetNormalTexture() return normal end
function button:GetHighlightTexture() return nil end
function button:GetPushedTexture() return nil end
function button:GetDisabledTexture() return nil end
function button.Icon:SetDesaturated(value) self.desaturated=value end
refresh.TotalQuantity=refresh:CreateFontString()
refresh.TotalQuantity:SetTextColor(1,.82,0,1)
local function read(path)
 local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local native=read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua")
_G.AuctionHouseRefreshFrameMixin={}
for _,method in ipairs({"SetQuantity","Deactivate","SetRefreshCallback"}) do
 assert(loadstring(assert(native:match("(function AuctionHouseRefreshFrameMixin:"..method..".-)\nfunction ")),"@native-refresh-"..method))()
 refresh[method]=_G.AuctionHouseRefreshFrameMixin[method]
end
_G.IconButtonMixin={}
local icons=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua")
assert(loadstring(assert(icons:match("(function IconButtonMixin:SetEnabledState.-\nend)")),"@native-icon-enabled"))()
button.SetEnabledState=_G.IconButtonMixin.SetEnabledState
function button:SetEnabled(value) self.enabled=value end
function button:IsEnabled() return self.enabled end
function button:SetOnClickHandler(callback) self.callback=callback end
_G.AUCTION_HOUSE_QUANTITY_AVAILABLE_FORMAT="%d available"
local callback=function() error("refresh request invoked") end
refresh:SetRefreshCallback(callback)
refresh:SetQuantity(42)
list.ScrollBox=frame(nil,list)
local removals=0
function list.ScrollBox:RemoveDataProvider() removals=removals+1 end
list.ResultsText=list:CreateFontString()
list.ResultsText:SetFont("Native",13,"");list.ResultsText:SetTextColor(1,.82,0,.8)
list.LoadingSpinner=frame(nil,list)
local spinner=list.LoadingSpinner
spinner.SearchingText=spinner:CreateFontString()
spinner.SearchingText:SetFont("Native",27,"");spinner.SearchingText:SetTextColor(1,.82,0,1)
spinner.SearchingText:SetText("Native searching")
local spinnerArt=spinner:CreateTexture();spinnerArt:SetAtlas("native-spinner")
_G.NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
_G.BROWSE_NO_RESULTS="Native no results"
_G.AuctionHouseItemListMixin={}
local itemList=read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemList.lua")
local constants=assert(itemList:match("(local ItemListState = {.-};)"))
for _,method in ipairs({"SetState","UpdateRefreshFrame","SetCustomError"}) do
 assert(loadstring(constants.."\n"..assert(itemList:match("(function AuctionHouseItemListMixin:"..method..".-)\nfunction ")),
 "@native-list-"..method))()
 list[method]=_G.AuctionHouseItemListMixin[method]
end
local quantity=42
list.totalQuantityFunc=function() return quantity end
list.searchStartedFunc=function() return false,"Native search instructions" end
list:SetState(1)
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end
skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(normal:GetAlpha()==0,"native refresh square must be suppressed")
assert(skin.GetBackdrop(button),"refresh control must have QUI chrome")
assert(button.Icon:GetAlpha()==1 and button.Icon.atlas=="UI-RefreshButton" and not button.Icon.desaturated,
 "native refresh icon must remain visible and enabled")
assert(refresh.TotalQuantity:GetText()=="42 available" and refresh.TotalQuantity.textColor[1]==.9,
 "result quantity must retain native text with neutral QUI typography")
refresh:Deactivate()
assert(not button:IsEnabled() and button.Icon.desaturated and refresh.TotalQuantity:GetText()=="",
 "deactivation must preserve native disabled/desaturated/empty state")
refresh:SetQuantity(0)
assert(button:IsEnabled() and not button.Icon.desaturated and refresh.TotalQuantity:GetText()=="",
 "zero results must allow refresh without a count")
refresh:SetQuantity(7)
_G.QUI_RefreshAuctionHouseColors()
assert(refresh.TotalQuantity:GetText()=="7 available" and button.callback==callback and button.Icon:GetAlpha()==1,
 "theme refresh must preserve count, native callback and icon")
assert(list.ResultsText.textColor[1]==.9 and spinner.SearchingText.textColor[1]==.9,
 "normal list messages need neutral QUI typography")
local _,resultSize=list.ResultsText:GetFont()
local _,searchSize=spinner.SearchingText:GetFont()
assert(resultSize==13 and searchSize==27,"native caption sizes must remain")
assert(list.ResultsText:IsShown() and list.ResultsText:GetText()=="Native search instructions"
 and not spinner:IsShown(),"native no-search message must remain")
list:SetState(3)
assert(not list.ResultsText:IsShown() and spinner:IsShown() and removals==2,
 "pending state must show native spinner and clear provider")
list:SetState(2)
assert(list.ResultsText:IsShown() and list.ResultsText:GetText()=="Native no results"
 and not spinner:IsShown() and removals==3,"native no-results state must remain")
list.ResultsText:SetTextColor(1,0,0,.6)
list:SetCustomError("Native error message")
assert(list.ResultsText:GetText()=="Native error message" and list.ResultsText:IsShown()
 and list.ResultsText.textColor[2]==0 and list.ResultsText.textColor[4]==.6,
 "custom error content and semantic red opacity must remain")
list:SetState(4)
local removed=removals
local count=refresh.TotalQuantity:GetText()
local enabled=button:IsEnabled()
_G.QUI_RefreshAuctionHouseColors()
assert(not list.ResultsText:IsShown() and not spinner:IsShown() and removals==removed
 and refresh.TotalQuantity:GetText()==count and button:IsEnabled()==enabled,
 "theme must retain native results state, provider, count and eligibility")
assert(spinnerArt.atlas=="native-spinner" and spinnerArt:GetAlpha()==1
 and spinner.SearchingText:GetText()=="Native searching","spinner art and caption must remain")
list.ResultsText:SetTextColor(1,.82,0,.8)
list:SetState(1)
assert(list.ResultsText.textColor[1]==.9 and list.ResultsText.textColor[4]==.8,
 "native normal-color reuse must restore neutral caption without changing opacity")
print("auctionhouse_list_refresh_test: PASS")
