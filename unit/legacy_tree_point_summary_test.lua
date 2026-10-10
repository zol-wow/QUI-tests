local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
local f=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyTree.lua"))
local native=f:read("*a");f:close()
_G.LegacyTreePointSummaryMixin={}
for _,method in ipairs({"OnLoad","OnEnter","OnLeave","RefreshText"}) do
    assert(loadstring(assert(native:match("(function LegacyTreePointSummaryMixin:"..method.."%b().-\nend)"))))()
end
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);root.TreePage=page
local summary=env.NewFrame("Frame",nil,page);page.LegacyTreePointSummary=summary
summary.RegisterForWidgetSet=false;summary:SetSize(212,36);summary:SetFrameLevel(800)
summary.AvailablePointsLabel=summary:CreateFontString()
summary.AvailablePointsLabel:SetTextColor(.9,.7,.2,1)
function summary.AvailablePointsLabel:SetFormattedText(fmt,...) self:SetText(string.format(fmt,...)) end
summary.Border=summary:CreateTexture();summary.Border:SetAtlas("Legacy-Tree-Frame-Points-Bar")
summary.Border:SetHeight(37)
summary.Border:SetPoint("LEFT",summary.AvailablePointsLabel,"LEFT",-15,-2)
summary.Border:SetPoint("RIGHT",summary.AvailablePointsLabel,"RIGHT",15,-2)
summary.Shield=env.NewFrame("Button",nil,summary);summary.Shield:RegisterForClicks("AnyUp")
summary.Shield:SetSize(46,64);summary.Shield.Icon=summary.Shield:CreateTexture()
summary.Shield.Icon:SetAtlas("UI-Legacy-Points-icon-c60");summary.Shield.Icon:SetSize(46,66)
summary.Shield.Points=summary.Shield:CreateFontString();summary.Shield.Points:SetTextColor(.8,.9,1,1)
for k,v in pairs(_G.LegacyTreePointSummaryMixin) do summary[k]=v end
local currency={quantity=7,renownCurrency=11,maxQuantity=100}
local callback,owner,registered
_G.LegacySystem={
    RegisterCurrencyInfoCallback=function(o,cb) owner=o;callback=cb;registered=(registered or 0)+1 end,
    GetCurrencyInfo=function() return currency end,
}
_G.LEGACY_POINTS_AMOUNT="%d points";_G.LEGACY_POINTS_AVAILABLE="Available: %s"
_G.LEGACY_POINTS_SEASONAL_CAP="Season cap: %d"
local tooltip={shown=false}
function tooltip:SetOwner(...) self.ownerArgs={...} end
function tooltip:SetText(t) self.text=t end
function tooltip:Show() self.shown=true end
function tooltip:Hide() self.shown=false end
_G.GetAppropriateTooltip=function() return tooltip end
summary:OnLoad();callback(owner,currency)
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local chrome=skin.GetBackdrop(summary)
assert(chrome and chrome._quiRoundedSurface and summary.Border:GetAlpha()==0,
    "legacy currency summary must replace native decorative bar with rounded chrome")
local p1,p2=chrome.points[1],chrome.points[2]
assert(p1[1]=="TOPLEFT" and p1[2]==summary.Border and p1[3]=="TOPLEFT"
    and p2[1]=="BOTTOMRIGHT" and p2[2]==summary.Border and p2[3]=="BOTTOMRIGHT",
    "summary chrome must follow both native label-dependent border anchors")
assert(summary:GetWidth()==212 and summary:GetHeight()==36 and chrome:GetFrameLevel()==799
    and summary.Border.points[1][2]==summary.AvailablePointsLabel and summary.Border:GetHeight()==37,
    "native summary geometry and stretched border references must remain")
assert(summary.AvailablePointsLabel:GetText()=="Available: 7 points" and summary.Shield.Points:GetText()==11
    and summary.AvailablePointsLabel.textColor[1]==.9 and summary.Shield.Points.textColor[1]==.8
    and summary.Shield.Icon.atlas=="UI-Legacy-Points-icon-c60" and summary.Shield.Icon:GetAlpha()==1
    and summary.Shield:GetWidth()==46 and summary.Shield.Icon:GetHeight()==66,
    "native localized counts, semantic colors and currency art must remain")
currency={quantity=123456,renownCurrency=29,maxQuantity=200}
callback(owner,currency)
assert(summary.AvailablePointsLabel:GetText()=="Available: 123456 points"
    and summary.Shield.Points:GetText()==29 and summary.AvailablePointsLabel.font=="QUIFont.ttf",
    "native callback must update counts without losing fonts or border ownership")
summary:OnEnter()
assert(tooltip.shown and tooltip.text=="Season cap: 200" and tooltip.ownerArgs[1]==summary
    and tooltip.ownerArgs[2]=="ANCHOR_RIGHT" and tooltip.ownerArgs[3]==-4 and tooltip.ownerArgs[4]==-10,
    "native currency-cap tooltip ownership and offsets must remain")
summary:OnLeave();assert(not tooltip.shown,"native leave must hide tooltip")
currency=nil;summary:OnEnter();assert(not tooltip.shown,"absent currency must keep tooltip hidden")
registry.skinLegacySystem.refresh()
assert(skin.GetBackdrop(summary)==chrome and registered==1,
    "theme must reuse chrome without registering native callbacks")
env.profile.general.skinLegacySystem=false;summary.AvailablePointsLabel:SetFont("Native",12,"")
callback(owner,{quantity=0,renownCurrency=0})
assert(summary.AvailablePointsLabel.font=="Native" and summary.AvailablePointsLabel:GetText()=="Available: 0 points",
    "disabled skin must preserve native callback updates")
env.profile.general.skinLegacySystem=true;summary.IsForbidden=function() return true end
registry.skinLegacySystem.refresh();assert(summary.AvailablePointsLabel.font=="Native","forbidden summary must be excluded")
summary.IsForbidden=function() return false end;page.IsForbidden=function() return true end
callback(owner,{quantity=1,renownCurrency=1})
assert(summary.AvailablePointsLabel.font=="Native","forbidden page must prevent summary overrides")
print("Legacy native currency summary counts, anchors and tooltip passed")
