local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinCommunities = true
_G.CommunitiesFrame = env.NewFrame("Frame")
local frame = _G.CommunitiesFrame
frame.TitleText = frame:CreateFontString()
frame.GetTitleText = function(owner) return owner.TitleText end
frame.SetTitle = function(owner, title)
    owner.TitleText:SetText(title)
    owner.TitleText:SetTextColor(1, 0.82, 0)
end
frame.PortraitContainer = env.NewFrame("Frame", nil, frame)
frame.PortraitOverlay = env.NewFrame("Frame", nil, frame)
frame.MaximizeMinimizeFrame = env.NewFrame("Frame", nil, frame)
local sizing = frame.MaximizeMinimizeFrame
sizing.MaximizeButton = env.NewFrame("Button", nil, sizing)
sizing.MinimizeButton = env.NewFrame("Button", nil, sizing)
sizing.MaximizeButton.DisabledTexture = false
sizing.MinimizeButton.DisabledTexture = false
for _, button in ipairs({ sizing.MaximizeButton, sizing.MinimizeButton }) do
    local createFontString = button.CreateFontString
    button.CreateFontString = function(self, ...)
        local text = createFontString(self, ...)
        local setFont, setText = text.SetFont, text.SetText
        local hasFont = false
        text.SetFont = function(owner, ...)
            hasFont = true
            return setFont(owner, ...)
        end
        text.SetText = function(owner, ...)
            assert(hasFont, "resize glyph must have a font before receiving text")
            return setText(owner, ...)
        end
        return text
    end
end

frame.CommunitiesList = env.NewFrame("Frame", nil, frame)
frame.CommunitiesList.ScrollBox = env.NewFrame("Frame", nil, frame.CommunitiesList)
local scrollBox = frame.CommunitiesList.ScrollBox
local navigationRow = env.NewFrame("Button", nil, scrollBox)
navigationRow.Name = navigationRow:CreateFontString()
navigationRow.Selection = navigationRow:CreateTexture()
navigationRow.Selection:SetShown(true)
function scrollBox:HasView() return true end
function scrollBox:ForEachFrame(callback) callback(navigationRow) end
_G.ScrollUtil = { AddAcquiredFrameCallback = function(owner, callback) owner.acquired = callback end }
frame.CommunitiesList.Bg = frame.CommunitiesList:CreateTexture()
frame.CommunitiesList.Bg:SetAtlas("bluemenu-main")
frame.CommunitiesList.FilligreeOverlay = env.NewFrame("Frame", nil, frame.CommunitiesList)
frame.CommunitiesList.FilligreeOverlay.Border = frame.CommunitiesList.FilligreeOverlay:CreateTexture()
frame.GuildFinderFrame = env.NewFrame("Frame", nil, frame)
local finder = frame.GuildFinderFrame
finder.DisabledFrame = false
finder.RequestToJoinFrame = env.NewFrame("Frame", nil, finder)
local dialog = finder.RequestToJoinFrame
dialog.BG = env.NewFrame("Frame", nil, dialog)
dialog.BG.Art = dialog.BG:CreateTexture()
dialog.BG.Art:SetTexture("native-translucent-dialog")
dialog.Apply = env.NewFrame("Button", nil, dialog)
dialog.Cancel = env.NewFrame("Button", nil, dialog)
local apply = function() error("styling must not submit an application") end
local cancel = function(owner) owner:GetParent():Hide() end
for _, button in ipairs({ dialog.Apply, dialog.Cancel }) do
    button.DisabledTexture = false
    button.normalTexture = button:CreateTexture()
    button.normalTexture:SetTexture("native-red-button")
end
dialog.Apply:SetScript("OnClick", apply)
dialog.Cancel:SetScript("OnClick", cancel)
dialog.Apply.enabled = false
dialog.ClubName = dialog:CreateFontString()
dialog.ClubName:SetTextColor(0, 1, 0)
dialog.ErrorDescription = dialog:CreateFontString()
dialog.ErrorDescription:SetTextColor(1, 0.1, 0.1)
dialog.MessageFrame = env.NewFrame("Frame", nil, dialog)
dialog.MessageFrame.Border = dialog.MessageFrame:CreateTexture()
dialog.MessageFrame.MessageScroll = env.NewFrame("ScrollFrame", nil, dialog.MessageFrame)
dialog.MessageFrame.MessageScroll.EditBox = env.NewFrame("EditBox", nil, dialog.MessageFrame.MessageScroll)
local note = dialog.MessageFrame.MessageScroll.EditBox
note:SetText("existing native note")
function note:GetText() return self.text end
local specRows = {}
function dialog:Initialize()
    local row = env.NewFrame("Frame", nil, self)
    row.Checkbox = env.NewFrame("CheckButton", nil, row)
    row.Checkbox.DisabledTexture = false
    function row.Checkbox:SetChecked(value) self.checked = value end
    function row.Checkbox:GetChecked() return self.checked end
    row.Checkbox:SetChecked(true)
    row.SpecName = row:CreateFontString()
    row.specID = 253
    specRows = { row }
    self.SpecsPool = { EnumerateActive = function() return coroutine.wrap(function() for _, row in ipairs(specRows) do coroutine.yield(row) end end) end }
end
finder.InsetFrame = env.NewFrame("Frame", nil, finder)
finder.InsetFrame.GuildDescription = finder.InsetFrame:CreateFontString()
finder.InsetFrame.GuildDescription:SetTextColor(1, 0.82, 0)
finder.InsetFrame.ErrorDescription = finder.InsetFrame:CreateFontString()
finder.InsetFrame.ErrorDescription:SetTextColor(1, 0, 0)
finder.OptionsList = env.NewFrame("Frame", nil, finder)
local options = finder.OptionsList
options.ClubFilterDropdown = env.NewFrame("DropdownButton", nil, options)
options.ClubFilterDropdown.DisabledTexture = false
options.ClubFilterDropdown.Label = options.ClubFilterDropdown:CreateFontString()
options.ClubFilterDropdown.Label:SetTextColor(1, 0.82, 0)
options.SearchBox = env.NewFrame("EditBox", nil, options)
options.SearchBox.searchIcon = options.SearchBox:CreateTexture()
options.SearchBox:SetSize(145, 35)
options.Search = env.NewFrame("Button", nil, options)
options.Search.DisabledTexture = false
options.Search.Text = options.Search:CreateFontString()
options.Search:SetSize(150, 20)
options.Search:SetPoint("BOTTOM", options.SearchBox, "BOTTOM", -3, -15)
local search = function() end
options.Search:SetScript("OnClick", search)
finder.ClubFinderSearchTab = env.NewFrame("CheckButton", nil, finder)
local tab = finder.ClubFinderSearchTab
tab.DisabledTexture = false
tab.Icon = tab:CreateTexture()
tab.Icon:SetAtlas("communities-search")
frame.GuildBenefitsFrame = env.NewFrame("Frame", nil, frame)
local benefits = frame.GuildBenefitsFrame
benefits.ShowOfflineButton = false
local benefitRows = {}
for _, key in ipairs({ "Perks", "Rewards" }) do
    local pane = env.NewFrame("Frame", nil, benefits)
    benefits[key] = pane
    pane.Background = pane:CreateTexture()
    pane.Background:SetTexture("native-brown-panel")
    pane.TitleText = pane:CreateFontString()
    pane.TitleText:SetTextColor(1, 0.82, 0)
    pane.ScrollBox = env.NewFrame("Frame", nil, pane)
    local row = env.NewFrame("Button", nil, pane.ScrollBox)
    row.DisabledTexture = false
    row.NormalBorder = false
    row.DisabledBorder = false
    row.SubText = false
    row.Icon = row:CreateTexture()
    row.Icon:SetTexture("native-item-art")
    row.Name = row:CreateFontString()
    row.Name:SetTextColor(0.5, 0.5, 0.5)
    row.normalTexture = row:CreateTexture()
    row.normalTexture:SetTexture("native-row-panel")
    row.Lock = row:CreateTexture()
    row.Lock:SetShown(false)
    row.DisabledBG = row:CreateTexture()
    row.DisabledBG:SetShown(true)
    function pane.ScrollBox:HasView() return true end
    function pane.ScrollBox:ForEachFrame(callback) callback(row) end
    if key == "Rewards" then row.achievementID = 123 end
    benefitRows[key] = row
end
finder.CommunityCards = env.NewFrame("Frame", nil, finder)
local cards = finder.CommunityCards
cards.Cards = {}
cards.ScrollBox = env.NewFrame("Frame", nil, cards)
local result = env.NewFrame("Button", nil, cards.ScrollBox)
result.DisabledTexture = false
result.CardBackground = false
result.Background = result:CreateTexture()
result.Background:SetAtlas("communitiesfinder-card")
result.CommunityLogo = result:CreateTexture()
result.CommunityLogo:SetTexture("native-community-logo")
local join = function() error("styling must not join a community") end
result:SetScript("OnClick", join)
function cards.ScrollBox:HasView() return true end
function cards.ScrollBox:ForEachFrame(callback) callback(result) end
result.RequestJoin = env.NewFrame("Frame", nil, result)
result.RequestJoin.AddTexture = result.RequestJoin:CreateTexture()
result.RequestJoin.AddTexture:SetAtlas("communities-icon-addgroupplus")
finder.GuildCards = env.NewFrame("Frame", nil, finder)
local guildCards = finder.GuildCards
guildCards.Cards = {}
local requestJoin = function() error("styling must not request guild membership") end
for index = 1, 3 do
    local card = env.NewFrame("Button", nil, guildCards)
    card.DisabledTexture = false
    card.Background = false
    card.CardBackground = card:CreateTexture()
    card.GuildBannerEmblemLogo = card:CreateTexture()
    card.GuildBannerEmblemLogo:SetTexture("native-guild-emblem")
    card.RequestJoin = env.NewFrame("Button", nil, card)
    card.RequestJoin.DisabledTexture = false
    card.RequestJoin.Text = card.RequestJoin:CreateFontString()
    card.RequestJoin.normalTexture = card.RequestJoin:CreateTexture()
    card.RequestJoin.normalTexture:SetTexture("native-red-button")
    card.RequestJoin:SetScript("OnClick", requestJoin)
    guildCards.Cards[index] = card
end
function guildCards:RefreshLayout() end
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_SOCIAL_SOURCE") or "modules/skinning/frames/social.lua"))("QUI", env.ns)
env.RunTimers()
assert(navigationRow.Selection:IsShown(), "styling must preserve Blizzard's selected community row")
local selectedBorder = env.BorderColor(env.SkinBase.GetBackdrop(navigationRow))
local _, _, _, accentAlpha = env.SkinBase.GetSkinColors()
assert(selectedBorder[4] == accentAlpha, "selected community rows must retain their accent border after acquisition")
navigationRow.Selection:SetShown(false)
local unselectedBorder = env.BorderColor(env.SkinBase.GetBackdrop(navigationRow))
assert(unselectedBorder[4] ~= selectedBorder[4], "native deselection must clear the community row accent")
navigationRow.Selection:SetShown(true)
assert(env.BorderColor(env.SkinBase.GetBackdrop(navigationRow))[4] == selectedBorder[4],
    "native selection must restore the community row accent")
assert(frame.CommunitiesList.Bg:GetAlpha() == 0, "community navigation must suppress native decorative backgrounds")
assert(env.SkinBase.GetBackdrop(finder.InsetFrame)._quiRoundedSurface, "finder content must use rounded QUI chrome")
assert(env.SkinBase.GetBackdrop(options.ClubFilterDropdown)._quiRoundedSurface, "finder filters must use rounded QUI chrome")
assert(env.SkinBase.GetBackdrop(options.Search)._quiRoundedSurface, "finder search action must use rounded QUI chrome")
assert(options.Search:GetScript("OnClick") == search, "finder search must remain Blizzard-owned")
assert(options.SearchBox.searchIcon:GetAlpha() == 1 and tab.Icon:GetAlpha() == 1, "search magnifier and tab icon must remain visible")
tab:SetChecked(true)
assert(env.SkinBase.GetFrameData(tab, "tabUnderline"):IsShown(), "checked community tabs must show the selected line")
tab:SetChecked(false)
assert(not env.SkinBase.GetFrameData(tab, "tabUnderline"):IsShown(), "cleared community tabs must hide the selected line")
frame.PortraitContainer:SetAlpha(1)
frame.PortraitOverlay:SetAlpha(1)
assert(frame.PortraitContainer:GetAlpha() == 0 and frame.PortraitOverlay:GetAlpha() == 0,
    "native portrait refresh must not restore detached Communities chrome")
assert(env.SkinBase.GetFrameData(sizing.MaximizeButton, "qCommunitySizingGlyph"):GetText() == "+",
    "Communities resize action must retain a visible semantic glyph")
local left, top = tab.Icon.texCoord[1], tab.Icon.texCoord[3]
assert(left == 0.08 and top == 0.08, "finder icons must crop baked native borders")
assert(env.SkinBase.GetBackdrop(tab):GetFrameLevel() < tab:GetFrameLevel(),
    "finder tab background must remain below its icon and selected line")
frame:SetTitle("Guild & Communities")
local r, g, b = frame.TitleText:GetTextColor()
assert(r == 1 and g == 1 and b == 1, "native title updates must retain neutral heading color")
r, g, b = finder.InsetFrame.GuildDescription:GetTextColor()
assert(r == 0.85 and g == 0.85 and b == 0.85, "finder descriptions must use neutral readable text")
r, g, b = finder.InsetFrame.ErrorDescription:GetTextColor()
assert(r == 1 and g == 0 and b == 0, "finder errors must retain semantic red")
r, g, b = options.ClubFilterDropdown.Label:GetTextColor()
assert(r == 0.9 and g == 0.9 and b == 0.9, "finder dropdown headings must match QUI controls")
env.RunTimers()
for _ = 1, 3 do
    frame:Hide()
    frame:Show()
end
assert(#env.timers == 0, "reopening Communities must not enqueue new permanent row callbacks")
for _, key in ipairs({ "Perks", "Rewards" }) do
    local pane, row = benefits[key], benefitRows[key]
    assert(pane.Background:GetAlpha() == 0, "nested benefits must suppress native panel art")
    assert(env.SkinBase.GetBackdrop(pane)._quiRoundedSurface, "benefit panels must use shared chrome")
    assert(row.normalTexture:GetAlpha() == 0, "benefit rows must suppress native button chrome")
    assert(row.Icon.texture == "native-item-art" and row.Icon:GetAlpha() == 1, "benefit art must survive")
    assert(row.Name.textColor[1] == 0.5, "benefit availability color must survive")
end
local reward = benefitRows.Rewards
reward.achievementID = nil
benefits.Rewards.ScrollBox.acquired(nil, reward)
env.RunTimers()
assert(reward.Name.textColor[1] == 1 and reward.Name.textColor[2] == 1,
    "available reward labels must use neutral chrome text")
assert(not benefitRows.Rewards.Lock:IsShown() and benefitRows.Rewards.DisabledBG:IsShown(),
    "reward restriction visibility must remain native")
assert(result.Background:GetAlpha() == 0, "finder results must suppress native beveled panels")
assert(env.SkinBase.GetBackdrop(result)._quiRoundedSurface, "finder results must use shared rounded chrome")
assert(result.CommunityLogo.texture == "native-community-logo" and result.CommunityLogo:GetAlpha() == 1,
    "finder styling must preserve identity art")
assert(result:GetScript("OnClick") == join, "finder styling must preserve native join ownership")
guildCards:RefreshLayout()
for _, card in ipairs(guildCards.Cards) do
    local button = card.RequestJoin
    assert(button.normalTexture:GetAlpha() == 0, "guild finder child actions must hide native red chrome")
    assert(env.SkinBase.GetBackdrop(button)._quiRoundedSurface, "guild finder child actions must use rounded QUI chrome")
    assert(button:GetScript("OnClick") == requestJoin, "guild finder must preserve native membership action ownership")
    assert(card.GuildBannerEmblemLogo.texture == "native-guild-emblem" and card.GuildBannerEmblemLogo:GetAlpha() == 1,
        "guild identity art must survive child action styling")
end
assert(result.RequestJoin.AddTexture.atlas == "communities-icon-addgroupplus" and
    result.RequestJoin.AddTexture:GetAlpha() == 1, "community join frames must retain their native semantic plus icon")
assert(not env.SkinBase.GetBackdrop(result.RequestJoin), "community join icon frames must not be treated as guild action buttons")
local fieldBottom = 100 - options.SearchBox:GetHeight() / 2
local point, relative, relativePoint, x, y = options.Search:GetPoint(1)
local actionTop = fieldBottom + y
if point == "BOTTOM" then actionTop = actionTop + options.Search:GetHeight() end
assert(fieldBottom - actionTop >= 4, "finder field and search action must have a visible gap without overlapping borders")
assert(relative == options.SearchBox and relativePoint == "BOTTOMLEFT" and x == 0,
    "finder action left edge must align with the search field")
local rightPoint, rightRelative, rightRelativePoint, rightX, rightY = options.Search:GetPoint(2)
assert(rightPoint == "TOPRIGHT" and rightRelative == options.SearchBox and
    rightRelativePoint == "BOTTOMRIGHT" and rightX == 0 and rightY == y,
    "finder action right edge must align with the search field")
assert(options.SearchBox:GetHeight() + 4 + options.Search:GetHeight() <= 50,
    "separated finder controls must fit the native header footprint")
assert(env.SkinBase.GetBackdrop(dialog), "finder application preview must have QUI chrome")
assert(env.SkinBase.GetBackdrop(dialog)._quiBgA == 1, "finder application preview must obscure underlying result cards")
assert(dialog.BG.Art:GetAlpha() == 0, "finder preview must suppress native translucent dialog art")
assert(dialog.Apply.normalTexture:GetAlpha() == 0 and dialog.Cancel.normalTexture:GetAlpha() == 0,
    "finder preview actions must suppress native red chrome")
assert(dialog.Apply:GetScript("OnClick") == apply and dialog.Cancel:GetScript("OnClick") == cancel,
    "finder preview must preserve native application and cancellation handlers")
assert(not dialog.Apply:IsEnabled() and note:GetText() == "existing native note",
    "styling must preserve native enabled state and note text")
assert(env.SkinBase.GetBackdrop(dialog.MessageFrame), "finder note must have a bordered container")
assert(dialog.ClubName.textColor[2] == 1 and dialog.ErrorDescription.textColor[2] == 0.1,
    "finder identity and error colors must survive")
for _ = 1, 2 do
    dialog:Initialize()
    local row = specRows[1]
    assert(env.SkinBase.GetBackdrop(row.Checkbox), "newly acquired specialization checks must be styled")
    assert(row.Checkbox:GetChecked() and row.specID == 253, "styling must preserve native specialization state")
end
print("OK: communities_inner_controls_test")
