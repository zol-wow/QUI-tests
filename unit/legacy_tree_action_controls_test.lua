local env=dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin,ns=env.SkinBase,env.ns
env.profile.general.skinLegacySystem=true
_G.CreateFromMixins=function(...)
    local result={};for _,mixin in ipairs({...}) do for key,value in pairs(mixin) do result[key]=value end end
    return result
end
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local corpus="tests/clients/forever/framexml/Interface/AddOns/"
assert(loadfile(corpus.."Blizzard_SharedXML/Shared/Button/UIButtonTemplate.lua"))()
assert(loadfile(corpus.."Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua"))()
local native=read(corpus.."Blizzard_LegacySystem/Blizzard_LegacyTree.lua")
_G.LegacyTreeTraitPanelMixin={}
assert(loadstring(assert(native:match("(function LegacyTreeTraitPanelMixin:UpdateConfigButtonsState%b().-\nend)"))))()
local root=env.NewFrame("Frame");root.CloseButton=false;root.Tabs={};root.Pages={}
_G.LegacySystemFrame=root
local page=env.NewFrame("Frame",nil,root);root.TreePage=page
local tree=env.NewFrame("Frame",nil,page);tree.RegisterForWidgetSet=false;page.LegacyTreeTraitPanel=tree
tree.UpdateConfigButtonsState=_G.LegacyTreeTraitPanelMixin.UpdateConfigButtonsState
local pending,canApply,changed,ready,valid,purchased,committing=false,false,false,false,true,true,false
function tree:GetConfigApplicationState() return pending,canApply,"Native disabled reason" end
function tree:HasAnyConfigChanges() return changed end
function tree:HasValidConfig() return valid end
function tree:HasAnyPurchasedRanks() return purchased end
function tree:IsCommitInProgress() return committing end
local glowShows,glowHides=0,0
_G.TalentFrameBaseMixin={ShowOrHideGlowOnChangesPending=function(self) glowShows=glowShows+1;self.ApplyButton.YellowGlow:Show() end}
_G.GlowEmitterFactory={Hide=function() glowHides=glowHides+1 end}
_G.InputUtil={IsGamepadUIEnabled=function() return false end}
local actions,sounds=0,0
_G.SOUNDKIT={IG_MAINMENU_OPTION_CHECKBOX_ON=1};_G.PlaySound=function() sounds=sounds+1 end
local function button(key,icon)
    local b=env.NewFrame("Button",nil,tree);tree[key]=b;b.DisabledTexture=false;b.RegisterForWidgetSet=false
    b.enabled=true;b:SetSize(icon and 25 or 164,icon and 25 or 22)
    function b:IsEnabled() return self.enabled end
    function b:SetEnabled(v) self.enabled=v end
    for method,fn in pairs(_G.UIButtonMixin) do b[method]=fn end
    b.onClickHandler=function() actions=actions+1 end;b:SetScript("OnClick",_G.UIButtonMixin.OnClick)
    if icon then
        b.Icon=b:CreateTexture();b.Icon:SetAtlas(icon);b.Icon:SetAlpha(.8)
        function b.Icon:SetDesaturated(v) self.desaturated=v end
        for method,fn in pairs(_G.IconButtonMixin) do b[method]=fn end
        b:SetScript("OnMouseDown",b.OnMouseDown);b:SetScript("OnMouseUp",b.OnMouseUp)
    else
        b.Text=b:CreateFontString();b.Text:SetText("Apply")
        function b:GetFontString() return self.Text end
        b.YellowGlow=env.NewFrame("Frame",nil,b)
    end
    return b
end
local apply=button("ApplyButton");local undo=button("UndoButton","Legacy-Tree-Frame-reset-button")
local reset=button("ResetButton","talents-button-reset")
tree:UpdateConfigButtonsState()
local callbacks,registry={},{}
skin.OnAddOnLoaded=function(addon,fn) callbacks[addon]=fn end
ns.Registry={Register=function(_,key,entry) registry[key]=entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI",ns)
callbacks.Blizzard_LegacySystem()
for _,b in ipairs({apply,undo,reset}) do assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface,
    "each legacy tree action must receive rounded QUI chrome") end
assert(not apply:IsEnabled() and not undo:IsShown() and reset:IsShown() and reset:IsEnabled()
    and reset.Icon.atlas=="talents-button-reset" and reset.Icon:GetAlpha()==.8 and not reset.Icon.desaturated,
    "native reset visibility/eligibility and functional icon must remain")
pending,canApply,changed=true,true,true;tree.isConfigReadyToApply=ready;tree:UpdateConfigButtonsState()
assert(apply:IsEnabled() and undo:IsShown() and not reset:IsShown() and glowShows==1
    and apply.YellowGlow:IsShown() and apply.disabledTooltip=="Native disabled reason",
    "native pending glow, apply eligibility/tooltip and undo/reset switch must remain")
reset:Fire("OnMouseDown");reset:Fire("OnMouseUp")
assert(reset.Icon.points[#reset.Icon.points][1]=="CENTER", "native icon press/release anchors must remain")
committing=true;tree:UpdateConfigButtonsState()
assert(not reset:IsEnabled() and reset.Icon.desaturated, "native commit-in-progress reset exclusion must remain")
local click=undo:GetScript("OnClick");local shows,hides=glowShows,glowHides
registry.skinLegacySystem.refresh()
assert(undo:GetScript("OnClick")==click and actions==0 and sounds==0 and glowShows==shows and glowHides==hides
    and undo:GetWidth()==25 and apply:GetWidth()==164,
    "theme must preserve handlers/geometry and must not invoke configuration or glow actions")
env.profile.general.skinLegacySystem=false;reset.Icon:SetAlpha(.3);registry.skinLegacySystem.refresh()
assert(reset.Icon:GetAlpha()==.3, "disabled tree refresh must stop styling")
env.profile.general.skinLegacySystem=true;tree.IsForbidden=function() return true end
registry.skinLegacySystem.refresh();assert(reset.Icon:GetAlpha()==.3,"forbidden tree must remain untouched")
print("Legacy native tree action state controls passed")
