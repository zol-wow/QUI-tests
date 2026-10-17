local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local ns, skin = env.ns, env.SkinBase
local newFrame = env.NewFrame
env.NewFrame = function(...)
    local frame = newFrame(...)
    frame.RegisterForWidgetSet = false
    return frame
end
env.profile.general.skinGuildRegistrar = true
_G.RegisterPlayerInteraction = function() end
_G.Enum = {PlayerInteractionType = {Registrar = 1}}
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/GuildRegistrarFrame.lua"))()
assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PetitionFrame.lua"))()
local nativePurchaseNavigation = _G.GuildRegistrar_ShowPurchaseFrame
local registrar = env.NewFrame("Frame", "GuildRegistrarFrame")
local petition = env.NewFrame("Frame", "PetitionFrame")
_G.GuildRegistrarFrame, _G.PetitionFrame = registrar, petition
for _, root in ipairs({registrar, petition}) do
    root.ScrollBar = env.NewFrame("Frame", nil, root)
    root.ScrollBar.Track = env.NewFrame("Frame", nil, root.ScrollBar)
    root.ScrollBar.Track.Thumb = env.NewFrame("Frame", nil, root.ScrollBar.Track)
    root.CreateMaskTexture = root.CreateTexture
end
_G.GuildRegistrarGreetingFrame = env.NewFrame("Frame", nil, registrar)
_G.GuildRegistrarPurchaseFrame = env.NewFrame("Frame", nil, registrar)
_G.AvailableServicesText = _G.GuildRegistrarGreetingFrame:CreateFontString()
_G.GuildRegistrarPurchaseText = _G.GuildRegistrarPurchaseFrame:CreateFontString()
_G.GuildRegistrarPurchaseText:SetText("Native charter explanation")
_G.GuildRegistrarPurchaseText:SetTextColor(0, 0, 0, 1)
_G.GuildRegistrarText = registrar:CreateFontString()
_G.GuildRegistrarFrameNpcNameText = registrar:CreateFontString()
_G.GuildRegistrarFramePortrait = registrar:CreateTexture()
_G.PetitionFramePortrait = petition:CreateTexture()
local masks = 0
function _G.GuildRegistrarFramePortrait:AddMaskTexture() masks = masks + 1 end
function _G.PetitionFramePortrait:AddMaskTexture() masks = masks + 1 end
local function button(name, parent, handler)
    local widget = env.NewFrame("Button", name, parent)
    _G[name] = widget
    widget.DisabledTexture = false
    widget.Text = widget:CreateFontString()
    widget.Text:SetText(name)
    widget:SetScript("OnClick", handler)
    function widget:Enable() self.enabled = true end
    function widget:Disable() self.enabled = false end
    return widget
end
for _, name in ipairs({"GuildRegistrarFrameGoodbyeButton", "GuildRegistrarFrameCancelButton", "GuildRegistrarFramePurchaseButton"}) do
    button(name, registrar, _G.GuildRegistrar_PurchaseCharter)
end
for index = 1, 2 do
    local service = button("GuildRegistrarButton" .. index, _G.GuildRegistrarGreetingFrame,
        index == 1 and _G.GuildRegistrar_ShowPurchaseFrame or function() end)
    service.Icon = service:CreateTexture()
end
_G.GuildRegistrarFrameEditBox = env.NewFrame("EditBox", nil, _G.GuildRegistrarPurchaseFrame)
local edit = _G.GuildRegistrarFrameEditBox
edit.value = "Native guild name"
function edit:GetText() return self.value end
function edit:SetText(value) self.value = value end
edit:SetScript("OnEnterPressed", _G.GuildRegistrar_PurchaseCharter)
_G.GuildRegistrarMoneyFrame = env.NewFrame("Frame", nil, _G.GuildRegistrarPurchaseFrame)
_G.GuildRegistrarMoneyFrame.quantity = _G.GuildRegistrarMoneyFrame:CreateFontString()
local purchases, signatures, costUpdates = 0, 0, 0
_G.BuyGuildCharter = function() purchases = purchases + 1 end
_G.SignPetition = function() signatures = signatures + 1 end
_G.MoneyFrame_Update = function(name, cost)
    costUpdates = costUpdates + 1
    _G[name].quantity:SetText(tostring(cost))
end
_G.GetGuildCharterCost = function() return 12345 end
_G.SetPortraitTexture = function(texture, unit) texture:SetTexture(unit) end
_G.UnitName = function() return "Native registrar" end
for _, name in ipairs({"PetitionFrameCancelButton", "PetitionFrameSignButton", "PetitionFrameRequestButton", "PetitionFrameRenameButton"}) do
    button(name, petition, _G.PetitionFrameSignButton_OnClick)
end
for _, name in ipairs({"PetitionFrameInstructions", "PetitionFrameNpcNameText", "PetitionFrameCharterTitle",
    "PetitionFrameCharterName", "PetitionFrameMasterTitle", "PetitionFrameMasterName", "PetitionFrameMemberTitle"}) do
    _G[name] = petition:CreateFontString()
end
for index = 1, 9 do
    _G["PetitionFrameMemberName" .. index] = petition:CreateFontString()
    _G["PetitionFrameMemberName" .. index].name = "PetitionFrameMemberName" .. index
end
local owner, canSign, names, required = true, false, 1, 3
_G.CanSignPetition = function() return canSign end
_G.GetPetitionInfo = function() return "guild", "Native guild", "body", required, "Native leader", owner, required end
_G.GetNumPetitionNames = function() return names end
_G.GetPetitionNameInfo = function(index) return "Native member " .. index end
_G.GUILD_PETITION_LEADER_INSTRUCTIONS, _G.GUILD_PETITION_MEMBER_INSTRUCTIONS = "Owner instructions", "Member instructions"
_G.GUILD_CHARTER_TEMPLATE, _G.GUILD_NAME, _G.GUILD_RANK0_DESC, _G.RENAME_GUILD, _G.NOT_YET_SIGNED =
    "%s charter", "Guild", "Leader", "Rename", "Not yet signed"
local callback, refresh = nil, {}
skin.OnAddOnLoaded = function(name, fn) if name == "Blizzard_UIPanels_Game" then callback = fn end end
ns.Registry = {Register = function(_, key, entry) refresh[key] = entry.refresh end}
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callback()
assert(skin.IsStyled(_G.GuildRegistrarButton1) and skin.IsStyled(_G.PetitionFrameSignButton),
    "service and charter actions must receive complete styling")
assert(_G.GuildRegistrarPurchaseText.textColor[1] > 0.9 and _G.GuildRegistrarPurchaseText:GetText() == "Native charter explanation",
    "native parchment text must be readable without changing its contents")
assert(skin.GetBackdrop(registrar.ScrollBar.Track.Thumb) and skin.GetBackdrop(petition.ScrollBar.Track.Thumb),
    "both native scrollbar thumbs must remain visible and styled")
_G.GuildRegistrar_OnShow()
assert(_G.GuildRegistrarGreetingFrame:IsShown() and not _G.GuildRegistrarPurchaseFrame:IsShown()
    and _G.GuildRegistrarFrameNpcNameText:GetText() == "Native registrar", "native greeting navigation and NPC identity must survive")
_G.GuildRegistrar_ShowPurchaseFrame()
assert(_G.GuildRegistrarPurchaseFrame:IsShown() and not _G.GuildRegistrarGreetingFrame:IsShown()
    and _G.GuildRegistrarMoneyFrame.quantity:GetText() == "12345" and costUpdates == 1,
    "native purchase navigation and cost formatting must survive without extra cost updates")
for _, state in ipairs({{true, false, 1, 3}, {false, true, 2, 3}, {true, false, 2, 2}}) do
    owner, canSign, names, required = state[1], state[2], state[3], state[4]
    _G.PetitionFrame_Update(petition)
    assert(_G.PetitionFrameRequestButton:IsShown() == owner and _G.PetitionFrameSignButton:IsShown() == not owner
        and _G.PetitionFrameRenameButton:IsShown() == owner and _G.PetitionFrameSignButton:IsEnabled() == canSign,
        "native owner/signer action visibility and eligibility must survive")
    assert(_G.PetitionFrameRequestButton:IsEnabled() == (names < required), "native signature limit must survive")
    assert(_G.PetitionFrameCharterName:GetText() == "Native guild" and _G.PetitionFrameMasterName:GetText() == "Native leader"
        and _G.PetitionFrameMemberName1:GetText() == "Native member 1", "native charter identity and signatures must survive")
    assert(_G.PetitionFrameInstructions:GetText() == (owner and "Owner instructions" or "Member instructions"),
        "native contextual instructions must survive")
end
assert(not _G.PetitionFrameMemberName3:IsShown(), "native signature rows removed on reuse must stay hidden")
refresh.skinGuildRegistrar()
refresh.skinPetition()
assert(masks == 2 and edit:GetText() == "Native guild name"
    and edit:GetScript("OnEnterPressed") == _G.GuildRegistrar_PurchaseCharter
    and _G.GuildRegistrarButton1:GetScript("OnClick") == nativePurchaseNavigation
    and _G.GuildRegistrarButton1.Icon:GetAlpha() == 1 and purchases == 0 and signatures == 0,
    "refresh must retain native handlers, text, service art and masks without purchasing or signing")
print("OK: guild_registrar_petition_surfaces_test")
