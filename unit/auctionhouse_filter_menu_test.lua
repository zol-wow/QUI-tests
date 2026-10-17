local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinContextMenus=true;env.profile.general.skinStaticPopups=false
local function frame(kind,parent)
 local f=env.NewFrame(kind or "Frame",nil,parent);f.RegisterForWidgetSet=false;f.DisabledTexture=false;function f:GetNumChildren() return #self.children end;return f
end
local function read(path)
 local f=assert(io.open(path));local s=f:read("*a");f:close();return s
end
local function copy(value)
 if type(value)~="table" then return value end
 local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
_G.CopyTable=copy
_G.CreateFromMixins=function() return {} end
_G.AuctionHouseSystemMixin={}
_G.AUCTION_HOUSE_DEFAULT_FILTERS={[1]=true,[2]=false}
_G.g_auctionHouseFilters={minLevel=10,maxLevel=20,filters=copy(_G.AUCTION_HOUSE_DEFAULT_FILTERS)}
assert(loadstring(read("tests/framexml/Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSearchBar.lua"),"@native-ah-menu-builder"))()
local bar=frame()
bar.FilterButton=frame("DropdownButton",bar)
local filter=bar.FilterButton
filter.ToggleFilter=_G.AuctionHouseFilterButtonMixin.ToggleFilter
local changes=0
function bar:OnFilterToggled() self:UpdateClearFiltersButton() end
function bar:UpdateClearFiltersButton() changes=changes+1 end
local generator
function filter:SetupMenu(fn) generator=fn end
_G.C_AuctionHouse={GetFilterGroups=function() return {{category=1,filters={1,2}}} end}
_G.GetAHFilterCategoryName=function() return "Native group" end
_G.GetAHFilterName=function(id) return "Native filter "..id end
_G.AUCTION_HOUSE_FILTER_DROP_DOWN_LEVEL_RANGE="Native level range"
_G.AuctionHouseSearchBarMixin.OnLoad(bar)
local menu=frame()
local range=frame(nil,menu)
range.MinLevel=frame("EditBox",range);range.MaxLevel=frame("EditBox",range)
local inputNative=read("tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua")
_G.LevelRangeFrameMixin={}
for _,key in ipairs({"OnLoad","OnHide","SetLevelRangeChangedCallback","OnLevelRangeChanged","FixLevelRange","SetMinLevel","SetMaxLevel","Reset","GetLevelRange"}) do
 assert(loadstring(assert(inputNative:match("(function LevelRangeFrameMixin:"..key..".-\nend)")),"@native-level-range-"..key))()
 range[key]=_G.LevelRangeFrameMixin[key]
end
for _,field in ipairs({range.MinLevel,range.MaxLevel}) do
 for _,key in ipairs({"Left","Middle","Right"}) do field[key]=field:CreateTexture() end
 local setText=field.SetText
 function field:SetText(value)
  setText(self,tostring(value))
  local fn=self:GetScript("OnTextChanged");if fn then fn(self,false) end
 end
 function field:SetNumber(value) self:SetText(value) end
 function field:GetNumber() return tonumber(self:GetText()) or 0 end
 function field:SetFont() error("Compositor-owned edit font changed") end
 function field:GetFont() error("Compositor-owned edit font read") end
end
range.MinLevel.Dash=range.MinLevel:CreateFontString();range.MinLevel.Dash:SetText("-");range.MinLevel.Dash:SetTextColor(1,1,1,1)
range:OnLoad()
local root={checks={}}
function root:SetTag(tag) self.tag=tag end
function root:CreateTitle() end
function root:QueueSpacer() end
function root:CreateTemplate(template)
 assert(template=="LevelRangeFrameTemplate")
 return {AddInitializer=function(_,fn) self.initializer=fn end}
end
function root:CreateCheckbox(label,selected,choose,id)
 self.checks[#self.checks+1]={label=label,selected=selected,choose=choose,id=id}
end
function root:AddMenuAcquiredCallback(fn) self.acquired=fn end
generator(filter,root);root.initializer(range)
local checkbox=frame("Button",menu)
checkbox.Checkmark=checkbox:CreateTexture();checkbox.Checkmark:SetAtlas("common-icon-checkmark")
checkbox.label=checkbox:CreateFontString();checkbox.label:SetText("Native filter");checkbox.label:SetTextColor(1,.82,0,1)
function checkbox.label:SetFont() error("Compositor-owned menu font changed") end
function checkbox.label:GetFont() error("Compositor-owned menu font read") end
local manager={}
function manager:GetOpenMenu() return self.open end
function manager:OpenMenu(_,description) self.open=menu;self.description=description end
_G.Menu={GetManager=function() return manager end}
_G.C_Timer.After=function(_,fn) fn() end
ns.WhenLoggedIn=function(fn) fn() end
_G.STATICPOPUP_NUMDIALOGS=0
_G.UIDROPDOWNMENU_MAXLEVELS=0
assert(loadfile(arg[1] or "modules/skinning/system/popups.lua"))("QUI",ns)
manager:OpenMenu(filter,root)
assert(skin.GetBackdrop(range.MinLevel) and skin.GetBackdrop(range.MaxLevel)
 and skin.GetBackdrop(range.MinLevel)._quiRoundedSurface,
 "native level range fields must receive rounded QUI chrome")
assert(range.MinLevel.Left:GetAlpha()==0 and range.MaxLevel.Right:GetAlpha()==0
 and range.MinLevel.Dash:GetText()=="-","native input decoration must be replaced while separator remains")
local min,max=range:GetLevelRange()
assert(min==10 and max==20 and changes==0 and range.MinLevel.nextEditBox==range.MaxLevel
 and range.MaxLevel.nextEditBox==range.MinLevel,"styling must preserve native initialized values, callbacks and focus cycle")
assert(root.tag=="MENU_AUCTION_HOUSE_SEARCH_FILTER" and #root.checks==2
 and root.checks[1].selected(1) and not root.checks[2].selected(2),"native filter menu descriptions must remain")
root.checks[2].choose(2)
assert(_G.g_auctionHouseFilters.filters[2] and changes==1,"native checkbox selection must remain")
range:SetMinLevel(30)
assert(_G.g_auctionHouseFilters.minLevel==30 and _G.g_auctionHouseFilters.maxLevel==20 and changes==2,
 "native input callback must update bounded range data")
range:OnHide()
assert(range.MinLevel:GetNumber()==20 and _G.g_auctionHouseFilters.minLevel==20 and changes==3,
 "native range normalization on hide must remain")
local before=changes
_G.QUI_RefreshSystemPopupSkins()
assert(changes==before and range.MinLevel:GetNumber()==20 and range.MaxLevel:GetNumber()==20
 and checkbox.Checkmark.atlas=="common-icon-checkmark" and checkbox.Checkmark:GetAlpha()==1,
 "theme must retain native checkbox art and range values without callbacks or font access")
assert(root.acquired,"native menu acquired callback must be installed")
root.acquired(menu)
assert(changes==before and skin.GetBackdrop(range.MinLevel)._quiRoundedSurface,
 "menu reacquisition must retain field chrome and native input state")
local nonWidget=frame(nil,menu);nonWidget.MinLevel=1;nonWidget.MaxLevel=2
local forbidden=frame(nil,menu)
forbidden.MinLevel=frame("EditBox",forbidden);forbidden.MaxLevel=frame("EditBox",forbidden)
function forbidden.MinLevel:IsForbidden() return true end
_G.QUI_RefreshSystemPopupSkins()
assert(not skin.GetBackdrop(forbidden.MinLevel),"forbidden range field must remain untouched")
env.profile.general.skinContextMenus=false
local untouched=frame(nil,menu)
untouched.MinLevel=frame("EditBox",untouched);untouched.MaxLevel=frame("EditBox",untouched)
_G.QUI_RefreshSystemPopupSkins()
assert(not skin.GetBackdrop(untouched.MinLevel),"disabled context skin must not style new fields")
print("auctionhouse filter menu level range passed")
