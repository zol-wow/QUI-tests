local Harness = dofile("tests/helpers/character_chrome_harness.lua")
for _, case in ipairs({ { forever = true, enabled = true }, { forever = false, enabled = true },
    { forever = true, enabled = false } }) do
    local h = Harness.Build()
    local skin, ns = h.SkinBase, h.ns
    ns.Client = { isForever = case.forever }
    h.profile.general.skinBank = case.enabled
    local function frame(kind, parent)
        local f = h.NewFrame(kind or "Frame", nil, parent)
        f.RegisterForWidgetSet, f.DisabledTexture = false, false
        return f
    end
    local bank = frame()
    _G.BankFrame = bank
    bank.BankPanel = frame(nil, bank)
    bank.TitleText = bank:CreateFontString()
    function bank:GetTitleText() return self.TitleText end
    bank.TitleText:SetText("Bank")
    bank.BagText, bank.BagCost = bank:CreateFontString(), bank:CreateFontString()
    local divider = bank:CreateTexture()
    divider:SetAtlas("bank-divider")
    function divider:GetAtlas() return self.atlas end
    local purchase = frame("Button", bank.BankPanel)
    bank.BankPanel.PurchaseButton = purchase
    purchase.normalTexture = purchase:CreateTexture()
    purchase.normalTexture:SetAtlas("native-red-button")
    local nativeAction = function() error("styling must not buy or move items") end
    purchase:SetScript("OnClick", nativeAction)
    purchase.enabled = false
    local slots, pages = {}, {}
    local function pool(items)
        return { EnumerateActive = function()
            local index = 0
            return function() index = index + 1; return items[index] end
        end }
    end
    bank.itemButtonBagPool, bank.bankPageTabPool = pool(slots), pool(pages)
    local function newSlot()
        local slot = frame("ItemButton", bank)
        slot:SetSize(36, 36)
        slot:SetPoint("TOPLEFT", bank, "BOTTOMLEFT", 10, 80)
        slot.Icon, slot.Background = slot:CreateTexture(), slot:CreateTexture()
        slot.Icon:SetTexture("native-bag-art")
        slot.normalTexture = slot:CreateTexture()
        slot.normalTexture:SetAtlas("bank-frame-bag-slotframe")
        slot.DisabledOverlay = slot:CreateTexture()
        slot.DisabledOverlay:SetAtlas("bankslot-icon-lock")
        slot:SetScript("OnClick", nativeAction)
        slot:SetScript("OnDragStart", nativeAction)
        slots[#slots + 1] = slot
        return slot
    end
    local slot = newSlot()
    local slotAnchor = slot.points[1]
    local tab = frame("Frame", bank)
    tab:SetSize(40, 40)
    tab:SetPoint("TOPLEFT", bank, "TOPRIGHT", 3, -60)
    tab.Icon, tab.SelectedTexture = tab:CreateTexture(), tab:CreateTexture()
    tab.Icon:SetTexture("native-page-art")
    function tab:SetChecked(checked) self.SelectedTexture:SetShown(checked) end
    tab:SetScript("OnMouseUp", nativeAction)
    local tabAnchor = tab.points[1]
    pages[1] = tab
    function bank:RefreshBagButtons() end
    function bank:RefreshPageTabs() end
    skin.OnAddOnLoaded = function(_, fn) fn() end
    assert(loadfile(os.getenv("QUI_INTERACTION_SOURCE") or "modules/skinning/frames/interaction.lua"))("QUI", ns)
    local styled = case.forever and case.enabled
    assert((skin.GetBackdrop(purchase) ~= nil) == styled, "Forever Purchase button needs skin with client/setting gates")
    assert((skin.GetBackdrop(slot) ~= nil) == styled, "Forever bag equipment slots need skin")
    assert((skin.GetBackdrop(tab) ~= nil) == styled, "Forever page tabs need skin")
    if styled then
        assert(slot.normalTexture:GetAlpha() == 0 and slot.Background:GetAlpha() == 0 and divider:GetAlpha() == 0,
            "native slot border/background and bank divider must be suppressed")
        local later = newSlot()
        bank:RefreshBagButtons()
        assert(skin.GetBackdrop(later), "new pooled bag slots must receive styling after native refresh")
        tab:SetChecked(false)
        bank:RefreshPageTabs()
        assert(not tab.SelectedTexture:IsShown(), "native deselection must survive refresh")
    end
    assert(slot.Icon.texture == "native-bag-art" and slot.Icon:GetAlpha() == 1
        and slot.DisabledOverlay:IsShown() and slot.DisabledOverlay:GetAlpha() == 1,
        "native item art and locked-slot indication must remain")
    assert(tab.Icon.texture == "native-page-art" and tab.Icon:GetAlpha() == 1,
        "native page icon must remain")
    assert(slot.points[1] == slotAnchor and slot:GetWidth() == 36
        and tab.points[1] == tabAnchor and tab:GetWidth() == 40, "native slot/page positions and sizes must remain")
    assert(purchase:GetScript("OnClick") == nativeAction and not purchase:IsEnabled()
        and slot:GetScript("OnClick") == nativeAction and slot:GetScript("OnDragStart") == nativeAction
        and tab:GetScript("OnMouseUp") == nativeAction, "native actions and purchase eligibility must remain")
end
print("OK: Forever bank controls style without changing native art, locks, layout, actions or Retail")
