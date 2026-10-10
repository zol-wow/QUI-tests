local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinBank = true
_G.CreateFromMixins = function(...) local t = {}; for _, m in ipairs({...}) do for k,v in pairs(m) do t[k]=v end end; return t end
_G.CallbackRegistryMixin = {GenerateCallbackEvents = function() end}
_G.Enum = {BankType={Account=2,Character=1}}
_G.Enum.PlayerInteractionType = {Banker=1,CharacterBanker=2,AccountBanker=3}
_G.Enum.BankLockedReason={BankConversionFailed=1,BankDisabled=2,NoAccountInventoryLock=3}
_G.Enum.BagSlotFlags={ExpansionCurrent=1,ExpansionLegacy=2}
_G.StaticPopupDialogs = {}
_G.RegisterPlayerInteraction = function() end
_G.TextureKitConstants = {IgnoreAtlasSize=false}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua"))()
local function frame(kind, parent)
    local f=env.NewFrame(kind or "Frame",nil,parent)
    f.RegisterForWidgetSet=false; f.DisabledTexture=false
    return f
end

local bank=frame()
_G.BankFrame=bank
bank.BankPanel=frame(nil,bank)
local panel=bank.BankPanel
panel.Prompts={}
panel.bankType=Enum.BankType.Account
panel.selectedTabID=1
local active,cache={},{}
local masks=0
_G.CallbackRegistrantMixin={OnHide=function() end,OnShow=function() end}
_G.FrameUtil={UnregisterFrameForEvents=function() end,RegisterFrameForEvents=function() end}
local function tab()
 local f=frame("Button",panel)
 for k,v in pairs(_G.BankPanelTabMixin) do f[k]=v end
 f.Border,f.Background,f.Icon,f.SearchOverlay,f.SelectedTexture=f:CreateTexture(),f:CreateTexture(),f:CreateTexture(),f:CreateTexture(),f:CreateTexture()
 f.highlightTexture=f:CreateTexture()
 function f:GetHighlightTexture() return self.highlightTexture end
 function f.Icon:SetDesaturated(value) self.nativeDesaturated=value end
 function f:IsEnabled() return self.enabled~=false end
 function f:SetEnabled(value) self.enabled=value end
 function f:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
 for _,t in ipairs({f.Icon,f.SearchOverlay,f.SelectedTexture,f.highlightTexture}) do
  function t:AddMaskTexture() masks=masks+1 end
 end
 function f:GetBankPanel() return panel end
 function f:GetBankTabSettingsMenu() return panel.TabSettingsMenu end
 f:SetScript("OnHide",f.OnHide)
 f:SetScript("OnClick",f.OnClick)
 f:SetScript("OnEnter",f.OnEnter)
 f:SetScript("OnLeave",f.OnLeave)
 f.nativeClick=f.OnClick
 f.SelectedTexture:SetAlpha(.6)
 f.TabContentsChangedAnim={native=true}
 return f
end
panel.bankTabPool={
 EnumerateActive=function() local i=0; return function() i=i+1; return active[i] end end,
 ReleaseAll=function() for _,f in ipairs(active) do f:Hide() end; active={} end,
 Acquire=function() local i=#active+1; cache[i]=cache[i] or tab(); active[i]=cache[i]; return cache[i] end,
}
panel.PurchaseTab=tab()
function panel:GetSelectedTabID() return self.selectedTabID end
panel.RefreshBankTabs=_G.BankPanelMixin.RefreshBankTabs
local locked,maxTabs,canPurchase=false,false,false
function panel:IsBankTypeLocked() return locked end
_G.C_Bank={HasMaxBankTabs=function() return maxTabs end,CanPurchaseBankTab=function() return canPurchase end}
_G.C_Container={IsContainerFiltered=function(id) return id==2 end}
_G.TextureKitConstants.UseAtlasSize=true
_G.QUESTION_MARK_ICON="question"
_G.SOUNDKIT={}; _G.PlaySound=function() end
local settingsRequests,selectionRequests=0,0
_G.BankPanelTabSettingsMenuMixin.Event={OpenTabSettingsRequested="settings"}
_G.BankPanelMixin.Event={BankTabClicked="selected"}
local settings=frame(nil,panel)
panel.TabSettingsMenu=settings
function settings:TriggerEvent(event,id) assert(event=="settings"); settingsRequests=settingsRequests+1; self.requested=id end
function panel:TriggerEvent(event,id)
 assert(event=="selected"); selectionRequests=selectionRequests+1
 self.selectedTabID=id
 for _,f in ipairs(active) do f:OnNewBankTabSelected(id) end
 self.PurchaseTab:OnNewBankTabSelected(id)
end
_G.GameTooltip={}
local tooltipShows,tooltipHides=0,0
function _G.GameTooltip:SetOwner(owner) self.owner=owner end
function _G.GameTooltip:Show() tooltipShows=tooltipShows+1 end
_G.GameTooltip_SetTitle=function(_,text) _G.GameTooltip.title=text end
_G.GameTooltip_AddInstructionLine=function() end
_G.GameTooltip_Hide=function() tooltipHides=tooltipHides+1 end
panel.PurchaseTab:Init({ID=-1})
panel.purchasedBankTabData={{ID=1,name="First",icon="native-first"},{ID=2,name="Second",icon="native-second"}}
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_UIPanels_Game" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinBank" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
panel:RefreshBankTabs()
assert(#active==2 and masks==12,"two pooled bank tabs and purchase tab must receive four masks each")
local first,second,purchase=active[1],active[2],panel.PurchaseTab
assert(first.Icon.texture=="native-first" and second.Icon.texture=="native-second" and purchase.Icon.atlas=="Garr_Building-AddFollowerPlus",
 "native identifying icons and purchase plus must remain")
assert(first.SelectedTexture:IsShown() and not second.SelectedTexture:IsShown()
 and not first.SearchOverlay:IsShown() and second.SearchOverlay:IsShown(),"native selection and search visibility must remain")
assert(first.SelectedTexture:GetAlpha()==.6 and first.TabContentsChangedAnim.native
 and first.SelectedTexture.vertex[4]==.15,"selected texture must retain native animation alpha with accent tint")
assert(first.Border:GetAlpha()==0 and purchase.Background:GetAlpha()==0,"native tab scenery must be suppressed")
local accent=skin.GetSkinColors()
local neutral=skin.GetWindowColors()
assert(skin.GetBackdrop(first)._quiBorderR==accent and skin.GetBackdrop(second)._quiBorderR==neutral,
 "selected bank tab must use accent while other tab uses shared neutral chrome")
assert(not purchase:IsEnabled() and purchase.Icon.nativeDesaturated and purchase:IsShown(),
 "native unaffordable purchase eligibility and desaturation must remain")
second:Fire("OnEnter")
assert(tooltipShows==1 and _G.GameTooltip.title=="Second" and skin.GetBackdrop(second)._quiBorderR==accent,
 "native tooltip and QUI hover must coexist")
second:Fire("OnLeave")
assert(tooltipHides==1 and skin.GetBackdrop(second)._quiBorderR==neutral,"leaving must restore neutral border and close native tooltip")
second:OnClick("RightButton")
assert(settingsRequests==1 and settings.requested==2 and selectionRequests==1 and second.SelectedTexture:IsShown()
 and not first.SelectedTexture:IsShown(),"native right click must preserve settings request and tab selection")
assert(skin.GetBackdrop(second)._quiBorderR==accent and skin.GetBackdrop(first)._quiBorderR==neutral,
 "selection callback must transfer accent")
first:Fire("OnEnter")
assert(skin.GetFrameData(first,"qBankTabHover"),"hover fixture must be active before pooled release")
canPurchase=true
panel:RefreshBankTabs()
assert(not skin.GetFrameData(first,"qBankTabHover"),"pooled tab release must clear stale hover")
assert(active[1]==first and masks==12 and purchase:IsEnabled() and not purchase.Icon.nativeDesaturated,
 "pooled refresh must reuse masks and retain purchase enable changes")
purchase:OnClick("RightButton")
assert(settingsRequests==1 and panel.selectedTabID==-1 and purchase.SelectedTexture:IsShown(),
 "purchase tab right click must retain native navigation without opening settings")
maxTabs=true
panel:RefreshBankTabs()
assert(not purchase:IsShown(),"native maximum-tab state must hide purchase tab")
maxTabs=false; locked=true
panel:RefreshBankTabs()
assert(not purchase:IsShown(),"native locked-bank state must hide purchase tab")
refresh()
assert(masks==12 and first:GetScript("OnClick")==first.nativeClick and selectionRequests==2,
 "theme refresh must reuse masks and retain click handler without selecting a tab")
print("bank tab surfaces passed")
