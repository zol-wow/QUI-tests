local Harness = dofile("tests/helpers/character_chrome_harness.lua")
for _, case in ipairs({
    { forever = true, popup = true, merchant = false, styled = true },
    { forever = true, popup = false, merchant = true, styled = false },
    { forever = false, popup = true, merchant = false, styled = false },
    { forever = true, popup = true, merchant = false, merchantOwner = true, styled = false },
}) do
    local h = Harness.Build()
    h.ns.Client = { isForever = case.forever }
    h.profile.general.skinMerchant = case.merchant
    h.profile.general.skinStaticPopups = case.popup
    dofile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXML/Mainline/StackSplitFrame.lua")
    local StackSplitMixin = _G.StackSplitMixin
    local StackSplitOkayButton_OnClick = _G.StackSplitOkayButton_OnClick
    local StackSplitCancelButton_OnClick = _G.StackSplitCancelButton_OnClick
    local StackSplitLeftButton_OnClick = _G.StackSplitLeftButton_OnClick
    local StackSplitRightButton_OnClick = _G.StackSplitRightButton_OnClick
    _G.STACKS, _G.TOTAL_STACKS = "%d Stacks", "%d Total"
    _G.gsub, _G.floor = string.gsub, math.floor
    local split = h.NewFrame("Frame")
    _G.StackSplitFrame = split
    for key, method in pairs(StackSplitMixin) do split[key] = method end
    split.SingleItemSplitBackground = split:CreateTexture()
    split.MultiItemSplitBackground = split:CreateTexture()
    split.StackSplitText = split:CreateFontString()
    split.StackItemCountText = split:CreateFontString()
    for _, key in ipairs({ "OkayButton", "CancelButton", "LeftButton", "RightButton" }) do
        split[key] = h.NewFrame("Button", nil, split)
        split[key].DisabledTexture = false
    end
    split:SetScript("OnChar", StackSplitMixin.OnChar)
    split:SetScript("OnKeyDown", StackSplitMixin.OnKeyDown)
    split.OkayButton:SetScript("OnClick", StackSplitOkayButton_OnClick)
    split.CancelButton:SetScript("OnClick", StackSplitCancelButton_OnClick)
    split.LeftButton:SetScript("OnClick", StackSplitLeftButton_OnClick)
    split.RightButton:SetScript("OnClick", StackSplitRightButton_OnClick)
    local owner = h.NewFrame("Button")
    local splitCalls = 0
    owner.SplitStack = function() splitCalls = splitCalls + 1 end
    _G.MerchantItem1 = case.merchantOwner and { ItemButton = owner } or nil
    h.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
    assert(loadfile(os.getenv("QUI_INTERACTION_SOURCE") or "modules/skinning/frames/interaction.lua"))("QUI", h.ns)
    split:OpenStackSplitFrame(200, owner, "BOTTOMLEFT", "TOPLEFT")
    local backdrop = h.SkinBase.GetBackdrop(split)
    assert((backdrop ~= nil) == case.styled, "quantity skin must respect Forever, popup, and merchant settings")
    if backdrop then
        assert(backdrop._quiRoundedSurface and backdrop._quiBgA == 1, "quantity popup needs opaque QUI chrome")
        assert(split.SingleItemSplitBackground:GetAlpha() == 0, "native quantity decoration must be suppressed")
        local field = h.SkinBase.GetFrameData(split, "qMerchantStackSplitField")
        assert(field and field.mouse == false, "quantity decoration must not intercept native typing")
    end
    assert(split:GetScript("OnChar") == StackSplitMixin.OnChar
        and split:GetScript("OnKeyDown") == StackSplitMixin.OnKeyDown, "preserve native keyboard handlers")
    assert(split.OkayButton:GetScript("OnClick") == StackSplitOkayButton_OnClick
        and split.CancelButton:GetScript("OnClick") == StackSplitCancelButton_OnClick, "preserve native confirmation handlers")
    split:Fire("OnChar", "1")
    split:Fire("OnChar", "2")
    assert(split.split == 12 and tonumber(split.StackSplitText:GetText()) == 12, "native typing must accept multiple digits")
    split:Fire("OnKeyDown", "BACKSPACE")
    assert(split.split == 1, "native backspace must remain functional")
    split:Fire("OnChar", "7")
    split.RightButton:Fire("OnClick")
    assert(split.split == 8 and splitCalls == 0, "preview controls must not split an item")
    split.CancelButton:Fire("OnClick")
    assert(not split:IsShown() and splitCalls == 0, "Cancel must leave the item untouched")
end
print("OK: Forever quantity chrome preserves native typing, arrows, Cancel, settings and Retail behavior")
