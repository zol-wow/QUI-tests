local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinAuctionHouse=true
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;return f
end
local ah=frame();_G.AuctionHouseFrame=ah
local list=frame(nil,ah);ah.CategoriesList=list
list.ScrollBox=frame(nil,list)
local row=frame("Button",list.ScrollBox)
row.Text=row:CreateFontString()
for _,key in ipairs({"Lines","NormalTexture","SelectedTexture","HighlightTexture"}) do row[key]=row:CreateTexture() end
row.Lines:SetAtlas("auctionhouse-nav-button-tertiary-filterline")
function row:GetFontString() return self.Text end
function row:SetText(value) self.Text:SetText(value) end
function row:GetHighlightTexture() return self.HighlightTexture end
local function read(path)
 local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
_G.CreateFromMixins=function() return {} end
_G.AuctionHouseSystemMixin={}
_G.ScrollBoxConstants={RetainScrollPosition=1,AlignBegin=2}
_G.CreateDataProvider=function(data) return data end
_G.tinsert=table.insert
_G.AuctionFrame_DoesCategoryHaveFlag=function() return false end
_G.AuctionHouseFrameMixin={Event={CategorySelected=1}}
_G.AuctionHouseFrameDisplayMode={WoWTokenBuy=1,Buy=2,ItemBuy=3,CommoditiesBuy=4}
local mode=2
function ah:GetDisplayMode() return mode end
function ah:SetDisplayMode(value) mode=value end
local events=0
function ah:TriggerEvent() events=events+1 end
function list:GetAuctionHouseFrame() return ah end
local function category(name,subs,token)
 return {name=name,subCategories=subs,HasFlag=function(_,flag) return flag=="WOW_TOKEN_FLAG" and token or false end}
end
_G.AuctionCategories={category("Weapons",{category("Axes",{category("One handed"),category("Two handed")})}),category("Token",nil,true)}
_G.AuctionHouseCategory_FindDeepest=function(a,b,c)
 local v=a and _G.AuctionCategories[a]
 if v and b then v=v.subCategories[b] end
 if v and c then v=v.subCategories[c] end
 return v
end
assert(loadstring(read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseCategoriesList.lua"),"@native-ah-categories"))()
assert(loadstring(read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseCategoriesList.lua"),"@native-ah-row-setup"))()
for _,key in ipairs({"GetSelectedCategory","SetSelectedCategory","IsWoWTokenCategorySelected","OnFilterClicked"}) do
 list[key]=_G.AuctionHouseCategoriesListMixin[key]
end
local data={}
function list.ScrollBox:SetDataProvider(provider) data=provider end
function list.ScrollBox:ScrollToElementDataIndex(value) self.scrollIndex=value end
function list.ScrollBox:HasView() return true end
function list.ScrollBox:ForEachFrame(fn) fn(row) end
local acquired
_G.ScrollUtil.AddAcquiredFrameCallback=function(_,fn) acquired=fn end
ns.SafeCallMethodIfPresent=function(_,obj,key,...)
 if not obj or type(obj[key])~="function" then return false end
 return pcall(obj[key],obj,...)
end
_G.C_Timer.After=function(_,fn) fn() end
ns.SafeCall=function(_,fn) fn() end;skin.OnAddOnLoaded=function(_,fn) fn() end
_G.AuctionFrameFilters_Update(list)
_G.AuctionHouseFilterButton_SetUp(row,data[1])
local click=function(button) list:OnFilterClicked(button,"LeftButton") end
row:SetScript("OnClick",click)
assert(loadfile(arg[1] or "modules/skinning/frames/auctionhouse.lua"))("QUI",ns)
assert(#data==2 and acquired and row.NormalTexture:GetAlpha()==0 and skin.GetBackdrop(row),
 "native root rows must receive QUI category chrome")
list:OnFilterClicked(row,"LeftButton")
assert(#data==3 and list.selectedCategoryIndex==1 and list.ScrollBox.scrollIndex==1,
 "native category selection must expand and scroll its provider")
_G.AuctionHouseFilterButton_SetUp(row,data[2])
list:OnFilterClicked(row,"LeftButton")
assert(#data==5 and list.selectedSubCategoryIndex==1,"native subcategory selection must expand leaves")
_G.AuctionHouseFilterButton_SetUp(row,data[3])
assert(row.Lines:IsShown() and row.Lines:GetAlpha()==1
 and row.Lines.atlas=="auctionhouse-nav-button-tertiary-filterline",
 "native tertiary hierarchy connector must survive category decoration stripping")
assert(row.Text:GetPoint(1)=="LEFT","native nested text anchors must remain")
list:OnFilterClicked(row,"LeftButton")
_G.AuctionHouseFilterButton_SetUp(row,data[3])
assert(list.selectedSubSubCategoryIndex==1 and row.SelectedTexture:IsShown()
 and row.Text.textColor[1]==1,"native leaf selection must retain selected QUI text")
list:OnFilterClicked(row,"LeftButton")
_G.AuctionHouseFilterButton_SetUp(row,data[3])
assert(list.selectedSubSubCategoryIndex==nil and not row.SelectedTexture:IsShown()
 and row.Text.textColor[1]==.72,"native leaf deselection must restore idle QUI text")
_G.AuctionHouseFilterButton_SetUp(row,data[2])
assert(not row.Lines:IsShown() and row.Lines:GetAlpha()==1,"recycled subcategory must hide connector natively")
list:OnFilterClicked(row,"LeftButton")
assert(#data==3 and list.selectedSubCategoryIndex==nil,"native subcategory collapse must remove leaves")
_G.AuctionHouseFilterButton_SetUp(row,data[1])
list:OnFilterClicked(row,"LeftButton")
assert(#data==2 and list.selectedCategoryIndex==nil,"native root collapse must remove descendants")
_G.AuctionHouseFilterButton_SetUp(row,data[2])
list:OnFilterClicked(row,"LeftButton")
assert(mode==1 and list.selectedCategoryIndex==2,"native token category must switch to token mode")
assert(row:GetScript("OnClick")==click and events>0,"native click ownership and category events must remain")
env.profile.general.skinAuctionHouse=false
local fresh=frame("Button",list.ScrollBox);fresh.Text=fresh:CreateFontString()
for _,key in ipairs({"Lines","NormalTexture","SelectedTexture","HighlightTexture"}) do fresh[key]=fresh:CreateTexture() end
function fresh:SetText(value) self.Text:SetText(value) end
_G.AuctionHouseFilterButton_SetUp(fresh,{type="category",name="Untouched",categoryIndex=1,selected=false})
assert(fresh.NormalTexture:GetAlpha()==1 and not skin.GetBackdrop(fresh),"disabled skin must leave newly rebound rows untouched")
print("auctionhouse category lifecycle passed")
