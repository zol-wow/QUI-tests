local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
local f=assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacyTree.lua"))
local native=f:read("*a");f:close()
_G.LegacyTreeTraitPanelMixin={}
assert(loadstring(assert(native:match("(function LegacyTreeTraitPanelMixin:UpdateTreeCurrencyInfo%b().-\nend)"))))()
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);root.TreePage=page
local tree=env.NewFrame("Frame",nil,page);tree.RegisterForWidgetSet=false;page.LegacyTreeTraitPanel=tree
tree.UpdateTreeCurrencyInfo=_G.LegacyTreeTraitPanelMixin.UpdateTreeCurrencyInfo
local points=env.NewFrame("Frame",nil,tree);tree.SpentPointsFrame=points;points.RegisterForWidgetSet=false
points:SetSize(30,30);points:SetFrameLevel(200)
points.Background=points:CreateTexture();points.Background:SetAtlas("Legacy-Tree-Frame-level-circle")
points.Text=points:CreateFontString();points.Text:SetTextColor(.8,.9,1,1)
local count=11;local updates,conditions,providers=0,0,0
_G.TalentFrameBaseMixin={UpdateTreeCurrencyInfo=function(self)
    providers=providers+1;self.treeCurrencyInfo=count and {{spentInTree=count}} or nil
end}
_G.LegacySystem={UpdateCurrencyInfo=function() updates=updates+1 end}
function tree:RefreshConditionsCache() conditions=conditions+1 end
tree:UpdateTreeCurrencyInfo()
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
local backdrop=skin.GetBackdrop(points)
assert(backdrop and backdrop._quiRoundedSurface and points.Background:GetAlpha()==0,
    "legacy spent-points badge must receive rounded QUI chrome")
assert(points.Text:GetText()==11 and points.Text.points[#points.Text.points][2]==-2
    and points.Text.points[#points.Text.points][3]==-1 and points.Text.textColor[1]==.8,
    "native count, leading-one alignment and semantic text color must remain")
assert(points:GetWidth()==30 and points:GetHeight()==30 and points:GetFrameLevel()==200
    and backdrop:GetFrameLevel()==199 and updates==1 and conditions==1 and providers==1,
    "badge styling must preserve geometry/frame order without invoking currency/provider actions")
count=5;tree:UpdateTreeCurrencyInfo()
assert(points.Text:GetText()==5 and points.Text.points[#points.Text.points][2]==0
    and points.Text.font=="QUIFont.ttf" and updates==2 and conditions==2,
    "native regular count alignment and currency callbacks must remain")
count=nil;tree:UpdateTreeCurrencyInfo()
assert(points.Text:GetText()==5 and updates==2 and conditions==2,
    "native absent-currency branch must not change retained count or trigger callbacks")
registry.skinLegacySystem.refresh()
assert(skin.GetBackdrop(points)==backdrop and providers==3 and updates==2 and conditions==2,
    "theme must cache badge without querying or changing currency")
env.profile.general.skinLegacySystem=false;points.Text:SetFont("Native",12,"")
count=12;tree:UpdateTreeCurrencyInfo()
assert(points.Text.font=="Native" and points.Text:GetText()==12,
    "disabled badge must preserve native count updates and stop font override")
env.profile.general.skinLegacySystem=true;points.IsForbidden=function() return true end
tree:UpdateTreeCurrencyInfo();assert(points.Text.font=="Native","forbidden badge must stop styling")
points.IsForbidden=function() return false end;root.IsForbidden=function() return true end
registry.skinLegacySystem.refresh();assert(points.Text.font=="Native","forbidden root must stop badge overrides")
print("Legacy native spent-points count/alignment passed")
