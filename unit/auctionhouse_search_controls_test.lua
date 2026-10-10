local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local function copy(value)
 if type(value)~="table" then return value end
 local t={};for k,v in pairs(value) do t[k]=copy(v) end;return t
end
_G.CopyTable=copy
_G.tCompare=function(a,b)
 for k,v in pairs(a) do if v~=b[k] then return false end end
 for k,v in pairs(b) do if v~=a[k] then return false end end
 return true
end
_G.AUCTION_HOUSE_DEFAULT_FILTERS={[1]=true,[2]=false}
_G.g_auctionHouseFilters=nil
_G.CreateFromMixins=function() return {} end
_G.AuctionHouseSystemMixin={}
_G.WowStyle1FilterDropdownMixin={OnLoad=function() end}
_G.SquareIconButtonMixin={OnLoad=function() end,OnEnter=function() end}
local f=assert(io.open("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSearchBar.lua"))
assert(loadstring(f:read("*a"),"@native-ah-search"))();f:close()
local ah=frame();_G.AuctionHouseFrame=ah
local bar=frame(nil,ah);ah.SearchBar=bar
bar.SearchBox=frame("EditBox",bar);bar.SearchBox:SetText("native axes query")
bar.SearchButton=frame("Button",bar)
bar.FilterButton=frame("DropdownButton",bar)
local filter=bar.FilterButton
filter:SetFrameLevel(20);filter.Text=filter:CreateFontString();filter.Text:SetText("Native filter")
filter.Background=filter:CreateTexture();filter.Background:SetAtlas("common-dropdown-b-button")
filter.Arrow=false
filter.ClearFiltersButton=frame("Button",filter);filter.ClearFiltersButton:SetFrameLevel(21)
local clear=filter.ClearFiltersButton
local clearArt=clear:CreateTexture();clearArt:SetAtlas("auctionhouse-ui-filter-redx")
local clearHover=clear:CreateTexture();clearHover:SetAtlas("auctionhouse-ui-filter-redx");clearHover:SetAlpha(.4)
function clear:GetNormalTexture() return clearArt end
function clear:GetHighlightTexture() return clearHover end
bar.FavoritesSearchButton=frame("Button",bar)
local favorite=bar.FavoritesSearchButton
favorite:SetFrameLevel(10);favorite.Icon=favorite:CreateTexture()
function favorite:SetAtlas(atlas) self.Icon:SetAtlas(atlas) end
function favorite:SetOnClickHandler(handler) self.callback=handler end
function favorite:SetEnabled(enabled) self.enabled=enabled end
function favorite:IsEnabled() return self.enabled end
function favorite.Icon:SetDesaturated(value) self.desaturated=value end
function favorite:SetTooltipInfo(title,description) self.tooltipTitle=title;self.tooltipDescription=description end
for k,v in pairs(_G.AuctionHouseFavoritesSearchButtonMixin) do favorite[k]=v end
for k,v in pairs(_G.AuctionHouseFilterButtonMixin) do filter[k]=v end
for _,key in ipairs({"UpdateClearFiltersButton","OnFilterToggled","GetLevelFilterRange"}) do bar[key]=_G.AuctionHouseSearchBarMixin[key] end
local searches=0
function bar:StartFavoritesSearch() searches=searches+1 end
local hasFavorites=false
_G.C_AuctionHouse={HasFavorites=function() return hasFavorites end}
_G.AUCTION_HOUSE_FAVORITES_SEARCH_TOOLTIP_TITLE="Native favorites"
_G.AUCTION_HOUSE_FAVORITES_SEARCH_TOOLTIP_NO_FAVORITES="Native no favorites"
favorite:OnLoad();filter:OnLoad();favorite:UpdateState();bar:UpdateClearFiltersButton()
local clearClick=clear:GetScript("OnClick")
local favoriteClick=favorite.callback
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(skin.GetFrameData(filter,"dropdownCaret"),"filter dropdown must retain a visible QUI menu caret")
assert(skin.GetBackdrop(filter):GetFrameLevel()<clear:GetFrameLevel()
 and clearArt:GetAlpha()==1 and clearHover:GetAlpha()==.4 and not clear:IsShown(),
 "QUI filter backdrop must remain below native clear icon and default visibility")
filter:ToggleFilter(2)
assert(clear:IsShown() and _G.g_auctionHouseFilters.filters[2],"native non-default filter must expose clear action")
_G.g_auctionHouseFilters.minLevel=10;bar:UpdateClearFiltersButton()
assert(clear:IsShown() and filter:GetLevelRange()==10,"native level filter must expose clear action")
clearClick(clear)
assert(not clear:IsShown() and not _G.g_auctionHouseFilters.filters[2] and filter:GetLevelRange()==0,
 "native clear callback must restore bounded default filters and levels")
favorite:OnEnter()
assert(not favorite:IsEnabled() and favorite.Icon.desaturated and favorite.tooltipDescription=="Native no favorites",
 "native missing favorites must preserve disabled star and tooltip")
hasFavorites=true;favorite:OnEvent("AUCTION_HOUSE_FAVORITES_UPDATED")
favorite:OnEnter()
assert(favorite:IsEnabled() and not favorite.Icon.desaturated and favorite.tooltipDescription==nil,
 "native favorites update must preserve enabled semantic star")
local level=favorite:GetFrameLevel()
_G.QUI_RefreshAuctionHouseColors()
_G.QUI_RefreshAuctionHouseColors()
assert(favorite:GetFrameLevel()==level and favorite.Icon.atlas=="auctionhouse-icon-favorite"
 and favorite.Icon:GetAlpha()==1 and bar.SearchBox:GetText()=="native axes query" and searches==0,
 "theme must retain favorite level/art, entered query and invoke no search")
assert(clear:GetScript("OnClick")==clearClick and favorite.callback==favoriteClick,
 "native clear and favorite handlers must retain ownership")
print("auctionhouse search controls passed")
