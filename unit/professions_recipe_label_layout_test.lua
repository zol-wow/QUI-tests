local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open(os.getenv("QUI_PROFESSIONS_SOURCE") or "modules/skinning/frames/professions.lua"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function StyleRecipeLabel(", 1, true), "recipe labels require post-font layout")
local last = assert(source:find("local function StyleOrderListRow(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn StyleScrollBoxRow"))
setfenv(chunk, setmetatable({ SkinBase = env.SkinBase }, { __index = _G }))
local apply = chunk()
local row = env.NewFrame("Button")
row:SetWidth(260)
row.Label = row:CreateFontString()
row.Label:SetText("Recycle Flasks")
row.Count = row:CreateFontString()
row.Count.GetStringWidth = function() return 30 end
row.SkillUps = env.NewFrame("Button", nil, row)
row.SkillUps:SetWidth(26)
row.LockedIcon = env.NewFrame("Button", nil, row)
row.LockedIcon:SetWidth(17)
row.LockedIcon:Hide()
row.Init = function(self) self.Label:SetWidth(80) end
row.GetElementData = function() return nil end
apply(row)
assert(row.Label:GetWidth() == 194, "recipe label must use available row width after applying QUI fonts")
row:Init()
assert(row.Label:GetWidth() == 194, "recycled native recipe initialization must not restore an undersized label")
row.Count:Hide()
row.LockedIcon:Show()
row:Init()
assert(row.Label:GetWidth() == 207, "recipe layout must reserve visible lock width and release hidden count width")
local category = env.NewFrame("Button")
category.Text = category:CreateFontString()
category.GetTitleRegion = function(self) return self.Text end
local categoryData = { categoryInfo = { unlearned = false } }
category.GetElementData = function() return { GetData = function() return categoryData end } end
category.CheckHighlightTitle = function(self) self.Text:SetTextColor(1, 0.82, 0) end
apply(category)
category:CheckHighlightTitle()
assert(select(2, category.Text:GetTextColor()) == 0.9,
    "native category hover must retain the QUI neutral heading color")
categoryData.categoryInfo.unlearned = true
category:CheckHighlightTitle()
assert(select(2, category.Text:GetTextColor()) == 0.55,
    "unlearned categories must retain visibly disabled semantics")
local ptrCategory = env.NewFrame("Button")
ptrCategory.Label = ptrCategory:CreateFontString()
local titleRegion = env.NewFrame("Frame", nil, ptrCategory)
titleRegion.GetTextColor = function() error("Frame title region is not a category FontString") end
ptrCategory.GetTitleRegion = function() return titleRegion end
ptrCategory.GetElementData = function() return { GetData = function() return categoryData end } end
ptrCategory.Init = function(self) self.Label:SetTextColor(1, 0.82, 0) end
apply(ptrCategory)
ptrCategory:Init()
assert(select(2, ptrCategory.Label:GetTextColor()) == 0.55,
    "the actual PTR Label-only category must preserve disabled color after native Init")
categoryData.categoryInfo.unlearned = false
ptrCategory:Init()
assert(select(2, ptrCategory.Label:GetTextColor()) == 0.9,
    "recycled PTR categories must return to neutral learned color")
print("OK: professions_recipe_label_layout_test")


local roundedCategory = env.NewFrame("Button")
roundedCategory.Label = roundedCategory:CreateFontString()
roundedCategory.GetElementData = ptrCategory.GetElementData
local roundedWrites = 0
function roundedCategory.Label:SetTextColor(r, g, b, a)
    roundedWrites = roundedWrites + 1
    assert(roundedWrites < 12, "native float-rounded colors must not recursively restyle forever")
    self.color = { r - 0.000000024, g - 0.000000024, b - 0.000000024, a }
end
function roundedCategory.Label:GetTextColor() return unpack(self.color or { 1, .82, 0, 1 }) end
apply(roundedCategory)
roundedCategory.Label:SetTextColor(1, .82, 0, 1)
assert(math.abs(select(1, roundedCategory.Label:GetTextColor()) - .9) < .0001, "rounded native colors must converge to the neutral shade")

local collapsed = false
local stateNode = { GetData = function() return categoryData end, IsCollapsed = function() return collapsed end }
local stateRow = env.NewFrame("Button")
stateRow.Label = stateRow:CreateFontString()
stateRow.GetElementData = function() return stateNode end
stateRow.Init = function() end
local click = function() collapsed = not collapsed end
stateRow:SetScript("OnClick", click)
apply(stateRow)
local glyph = env.SkinBase.GetFrameData(stateRow, "qRecipeCategoryIndicator")
assert(glyph and glyph:GetText() == "-", "expanded PTR categories require a visible minus")
stateRow:Fire("OnClick")
assert(collapsed and glyph:GetText() == "+", "native collapse clicks must hide children and refresh the plus")
collapsed = false
stateRow:Init()
assert(glyph:GetText() == "-", "recycled categories must refresh their current tree state")
assert(env.SkinBase.GetFrameData(stateRow, "qRecipeCategoryIndicator") == glyph,
    "recycled categories must not accumulate indicator regions")

local hoverFirst = assert(source:find("local function HookRecipeRowHover()", 1, true))
local hoverLast = assert(source:find("local function SkinRecipeList", hoverFirst, true))
local hoverChunk = assert(loadstring(source:sub(hoverFirst, hoverLast - 1) .. "\nreturn HookRecipeRowHover"))
local hovered
local hoverSkin = setmetatable({ SetRowHovered = function(row, value) hovered = value end }, { __index = env.SkinBase })
local mixin = { OnEnter = function() end, OnLeave = function() end }
setfenv(hoverChunk, setmetatable({ SkinBase = hoverSkin, _G = { ProfessionsRecipeListCategoryMixin = mixin } }, { __index = _G }))
hoverChunk()()
mixin.OnEnter(stateRow)
assert(hovered == true, "the native category hover path must highlight its row")
mixin.OnLeave(stateRow)
assert(hovered == false, "leaving a category must restore its normal border")

local function ReadNative(path)
    local f=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/"..path));local text=f:read("*a");f:close();return text
end
local list=ReadNative("Blizzard_SharedXML/ListTemplates.lua")
_G.ListHeaderVisualMixin={};_G.ListHeaderMixin={};_G.CollapseButtonMixin={}
for name in list:gmatch("function ListHeaderVisualMixin:([%w_]+)") do
    assert(loadstring(assert(list:match("(function ListHeaderVisualMixin:"..name.."%b().-\nend)"))))()
end
for name,fn in pairs(_G.ListHeaderVisualMixin) do _G.ListHeaderMixin[name]=fn end
for name in list:gmatch("function ListHeaderMixin:([%w_]+)") do
    assert(loadstring(assert(list:match("(function ListHeaderMixin:"..name.."%b().-\nend)"))))()
end
assert(loadstring(assert(list:match("(function CollapseButtonMixin:UpdateCollapsedState%b().-\nend)"))))()
local native=ReadNative("Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.lua")
_G.ProfessionsRecipeListCategoryMixin={}
for _,name in ipairs({"OnLoad","OnEnter","OnLeave","Init"}) do
    assert(loadstring(assert(native:match("(function ProfessionsRecipeListCategoryMixin:"..name.."%b().-\nend)"))))()
end
local function Color(r,g,b) return {GetRGB=function() return r,g,b end} end
_G.NORMAL_FONT_COLOR=Color(1,.82,0);_G.DISABLED_FONT_COLOR=Color(.5,.5,.5);_G.HIGHLIGHT_FONT_COLOR=Color(1,1,1)
_G.C_TradeSkillUI={IsTradeSkillGuild=function() return false end,IsTradeSkillGuildMember=function() return false end,GetCategories=function() return 999 end}
_G.tContains=function(values,wanted) for _,value in ipairs(values) do if value==wanted then return true end end end
local tooltip={Hide=function(self) self.shown=false end}
_G.GetAppropriateTooltip=function() return tooltip end
local header=env.NewFrame("Button");header:RegisterForClicks("LeftButtonUp")
header:SetSize(260,25);header.ButtonText=header:CreateFontString()
for name,fn in pairs(_G.ListHeaderMixin) do header[name]=fn end
for name,fn in pairs(_G.ProfessionsRecipeListCategoryMixin) do header[name]=fn end
function header:IsMouseMotionFocus() return false end
function header:IsTruncated() return false end
header.CollapseButton=env.NewFrame("Button",nil,header)
header.CollapseButton.Icon=header.CollapseButton:CreateTexture()
header.CollapseButton.UpdateCollapsedState=_G.CollapseButtonMixin.UpdateCollapsedState
function header.CollapseButton:SetHighlightAtlas(atlas) self.highlightAtlas=atlas end
function header.CollapseButton:LockHighlight() self.locked=true end
function header.CollapseButton:UnlockHighlight() self.locked=false end
header.RankBar=env.NewFrame("StatusBar",nil,header)
header.RankBar.Rank=header.RankBar:CreateFontString()
function header.RankBar.Rank:SetFormattedText(pattern,...) self:SetText(string.format(pattern,...)) end
function header.RankBar:SetMinMaxValues(a,b) self.range={a,b} end
function header.RankBar:SetValue(value) self.value=value end
local nativeData={categoryInfo={name="Recrafting",unlearned=false,hasProgressBar=true,categoryID=1,
    skillLineStartingRank=0,skillLineMaxLevel=100,skillLineCurrentLevel=42}}
local nativeCollapsed=false
local nativeNode={GetData=function() return nativeData end,IsCollapsed=function() return nativeCollapsed end}
function header:GetElementData() return nativeNode end
header:OnLoad();header:Init(nativeNode)
local clicks=0
header:SetClickHandler(function(button,mouseButton)
    assert(button==header and mouseButton=="LeftButton")
    clicks=clicks+1;nativeCollapsed=not nativeCollapsed;button:UpdateCollapsedState(nativeCollapsed)
end)
header:SetScript("OnClick",_G.ListHeaderMixin.OnClick)
apply(header)
local nativeGlyph=env.SkinBase.GetFrameData(header,"qRecipeCategoryIndicator")
assert(header.ButtonText:GetText()=="Recrafting" and nativeGlyph:GetText()=="-"
    and header.RankBar.value==42 and header.RankBar.range[2]==100,
    "native category initialization must retain title, rank provider values and expanded indicator")
header:OnEnter()
assert(header.RankBar.Rank:IsShown() and header.RankBar.Rank:GetText()=="42/100"
    and header.CollapseButton.locked and select(1,header.ButtonText:GetTextColor())==.9,
    "native category hover must retain rank text/highlight ownership while QUI heading stays neutral")
header:OnLeave()
assert(not header.RankBar.Rank:IsShown() and header.RankBar.Rank:GetText()==""
    and not header.CollapseButton.locked,"native category leave must clear rank text and collapse highlight")
header:Fire("OnClick","LeftButton")
assert(clicks==1 and nativeCollapsed and nativeGlyph:GetText()=="+" and header.CollapseButton.collapsed,
    "native header click and collapsed-state forwarding must drive the replacement indicator")
nativeData.categoryInfo={name="Unlearned",unlearned=true,hasProgressBar=false}
header:Init(nativeNode)
assert(header.ButtonText:GetText()=="Unlearned" and select(1,header.ButtonText:GetTextColor())==.55
    and not header.RankBar:IsShown() and header.RankBar.currentRank==nil
    and env.SkinBase.GetFrameData(header,"qRecipeCategoryIndicator")==nativeGlyph,
    "native reused category must reset rank eligibility, preserve disabled shade and reuse indicator")
print("Native profession category lifecycle passed")

_G.ProfessionsRecipeListRecipeMixin = {}
for _, name in ipairs({"GetLabelColor", "Init", "SetLabelFontColors", "OnLeave"}) do
    assert(loadstring(assert(native:match("(function ProfessionsRecipeListRecipeMixin:" .. name .. "%b().-\nend)"))))()
end
_G.PROFESSION_RECIPE_COLOR = Color(1, .45, .1)
_G.Professions = {GetHighestLearnedRecipe = function(info) return info end}
_G.C_TradeSkillUI.GetCraftableCount = function() return 2 end
_G.GameTooltip = {Hide = function() end}
local recipe = env.NewFrame("Button")
recipe:SetWidth(260)
recipe.Label = recipe:CreateFontString()
recipe.Count = recipe:CreateFontString()
recipe.Label.SetVertexColor = recipe.Label.SetTextColor
recipe.Count.SetVertexColor = recipe.Count.SetTextColor
recipe.Count.SetFormattedText = function(self, pattern, ...) self:SetText(string.format(pattern, ...)) end
recipe.LockedIcon = env.NewFrame("Button", nil, recipe)
recipe.SkillUps = env.NewFrame("Button", nil, recipe)
recipe.SkillUps:SetWidth(26)
local recipeData = {recipeInfo = {name = "Native recipe", recipeID = 1, learned = true}}
local recipeNode = {GetData = function() return recipeData end}
recipe.GetElementData = function() return recipeNode end
recipe.GetTitleRegion = function() return nil end
for name, method in pairs(_G.ProfessionsRecipeListRecipeMixin) do recipe[name] = method end
recipe:Init(recipeNode)
apply(recipe)
assert(not env.SkinBase.GetFrameData(recipe, "qRecipeCategoryIndicator") and not recipe.hooks.OnClick,
    "ordinary native recipe buttons with Frame:GetTitleRegion must not receive category controls")
assert(select(2, recipe.Label:GetTextColor()) == .45,
    "styling must retain the native learned recipe color")
recipe.Label:SetTextColor(.2, .8, .3, 1)
assert(select(2, recipe.Label:GetTextColor()) == .8,
    "native recipe color changes must not be replaced by category gray")
recipeData.recipeInfo.learned = false
recipe:Init(recipeNode)
assert(select(1, recipe.Label:GetTextColor()) == .5,
    "native unlearned recipe initialization must retain disabled text color")
recipe:SetLabelFontColors(_G.HIGHLIGHT_FONT_COLOR)
recipe:OnLeave()
assert(select(1, recipe.Label:GetTextColor()) == .5,
    "native recipe hover leave must restore disabled color")
for _, key in ipairs({"isDivider", "topPadding", "bottomPadding"}) do
    local spacer = env.NewFrame("Frame")
    spacer.GetTitleRegion = function() return nil end
    spacer.GetElementData = function() return {GetData = function() return {[key] = true} end} end
    spacer.HookScript = function(_, script) assert(script ~= "OnClick", "native spacer Frame does not support OnClick") end
    apply(spacer)
    assert(not env.SkinBase.GetFrameData(spacer, "qRecipeCategoryIndicator") and not env.SkinBase.IsStyled(spacer),
        "native divider and padding frames must remain outside recipe and category styling")
end
print("Native recipe versus category and spacer discrimination passed")
