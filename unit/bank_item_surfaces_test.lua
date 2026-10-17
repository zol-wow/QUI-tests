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
local panel=frame(nil,bank)
bank.BankPanel=panel
panel.Prompts={}
local active={}
panel.itemButtonPool={EnumerateActive=function()
    local i=0; return function() i=i+1; return active[i] end
end}
local masks, transactions=0,0
local function item()
    local f=frame("Button",panel)
    for k,v in pairs(_G.BankPanelItemButtonMixin) do f[k]=v end
    f.icon=f:CreateTexture(); f.Background=f:CreateTexture()
    f.IconBorder=f:CreateTexture(); f.IconBorder:Hide()
    f.IconQuestTexture=f:CreateTexture()
    f.Cooldown=frame(nil,f); f.Count=f:CreateFontString()
    function f.IconBorder:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
    function f:CreateMaskTexture() local m=self:CreateTexture(); m.kind="MaskTexture"; return m end
    function f.icon:SetDesaturated(value) self.nativeDesaturated=value end
    function f.icon:AddMaskTexture() masks=masks+1 end
    function f:UpdateItemContextMatching() self.contextUpdated=true end
    function f:SetMatchesSearch(value) self.searchMatches=value end
    local click=function() transactions=transactions+1 end
    f:SetScript("OnClick",click); f.nativeClick=click
    return f
end
local info={iconFileID=123,stackCount=7,quality=4,itemID=22,isBound=true,isLocked=true,isFiltered=true}
local quest={questID=91,isActive=false}
_G.C_Container={
 GetContainerItemInfo=function() return info end,
 GetContainerItemQuestInfo=function() return quest end,
 GetContainerItemCooldown=function() return 3,8,0 end,
 GetContainerNumSlots=function() return 3 end,
}
_G.ItemLocation={CreateFromBagAndSlot=function(_,tab,slot) return {tab=tab,slot=slot} end}
_G.TEXTURE_ITEM_QUEST_BANG="quest-bang"; _G.TEXTURE_ITEM_QUEST_BORDER="quest-border"
_G.SetItemButtonCount=function(f,n) f.Count:SetText(tostring(n)) end
_G.SetItemButtonQuality=function(f,q,id,suppress,bound)
 f.nativeQuality={q,id,suppress,bound}
 if q==4 then f.IconBorder:SetVertexColor(.7,.1,1,1); f.IconBorder:Show()
 else f.IconBorder:Hide() end
end
_G.SetItemButtonDesaturated=function(f,value) f.icon:SetDesaturated(value) end
_G.CooldownFrame_Set=function(f,s,d,e) f.nativeCooldown={s,d,e} end
_G.SetItemButtonTextureVertexColor=function(f,r,g,b) f.icon:SetVertexColor(r,g,b) end
panel.bankType=Enum.BankType.Account; panel.selectedTabID=13
panel.GenerateItemSlotsForSelectedTab=_G.BankPanelMixin.GenerateItemSlotsForSelectedTab
panel.RefreshAllItemsForSelectedTab=_G.BankPanelMixin.RefreshAllItemsForSelectedTab
panel.EnumerateValidItems=_G.BankPanelMixin.EnumerateValidItems
panel.itemButtonPool.ReleaseAll=function() active={} end
panel.itemButtonPool.Acquire=function() local f=item(); active[#active+1]=f; return f end
local callback,refresh
skin.OnAddOnLoaded=function(name,fn) if name=="Blizzard_UIPanels_Game" then callback=fn end end
ns.Registry={Register=function(_,key,entry) if key=="skinBank" then refresh=entry.refresh end end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI",ns)
callback()
panel:GenerateItemSlotsForSelectedTab()
assert(#active==3 and masks==3,"native acquired bank slots must each receive one rounded icon mask")
for _,f in ipairs(active) do
 assert(f.Background:GetAlpha()==0 and skin.GetBackdrop(f)._quiRoundedSurface,"bank slot decoration must be suppressed behind rounded chrome")
 assert(f.icon:IsShown() and f.icon.texture==123 and f.Count:GetText()=="7","native artwork and stack count must remain")
 assert(f.IconQuestTexture:IsShown() and f.IconQuestTexture.texture=="quest-bang","native quest marker must remain")
 assert(skin.GetFrameData(f.icon,"iconBorder")._quiBorderR==.7,"native rarity must color the rounded icon border")
 assert(f.nativeQuality[1]==4 and f.nativeQuality[4] and not f.searchMatches and f.contextUpdated,"quality bound state search and item context must remain")
 assert(f.icon.nativeDesaturated and f.icon.vertex[1]==.4,"native lock and unavailable cooldown feedback must remain")
 assert(f.Cooldown.nativeCooldown[2]==8 and f:GetScript("OnClick")==f.nativeClick,"native cooldown and click handler must remain")
end
info=nil; quest={}
panel:RefreshAllItemsForSelectedTab()
for _,f in ipairs(active) do
 assert(not f.icon.nativeDesaturated,"empty native reuse must clear lock feedback")
 assert(not f.icon:IsShown() and f.Count:GetText()=="0" and not f.IconQuestTexture:IsShown() and f.searchMatches,"empty reuse must clear native item state")
 f:SetBankType(Enum.BankType.Character); f:UpdateBackgroundForBankType()
 assert(skin.GetFrameData(f.icon,"iconBorder")._quiBorderR==skin.GetWindowColors(),"empty reuse must clear stale rarity")
 assert(f.Background:GetAlpha()==0,"character-bank atlas restoration must remain suppressed")
end
refresh()
assert(masks==3 and transactions==0,"refresh must reuse masks without moving or purchasing items")
panel.bankType=Enum.BankType.Character
panel.selectedTabID=14
panel:GenerateItemSlotsForSelectedTab()
assert(masks==6 and active[1]:GetBankType()==Enum.BankType.Character and active[1]:GetBankTabID()==14,
    "character tab generation must style newly acquired slots and retain native identity")
env.profile.general.skinBank=false
panel:GenerateItemSlotsForSelectedTab()
assert(masks==6 and active[1].Background:GetAlpha()==1,"disabled bank skin must leave newly acquired native slots alone")
assert(transactions==0,"audit must perform no item transaction")
print("bank item surfaces passed")
