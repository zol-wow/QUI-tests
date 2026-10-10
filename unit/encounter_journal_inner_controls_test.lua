local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinEncounterJournal = true
local frame = env.NewFrame("Frame")
_G.EncounterJournal = frame
frame.instanceSelect = env.NewFrame("Frame", nil, frame)
local select = frame.instanceSelect
select.bg = select:CreateTexture()
select.evergreenBg = select:CreateTexture()
select.ExpansionDropdown = env.NewFrame("Button", nil, select)
select.ExpansionDropdown.DisabledTexture = false
select.GreatVaultButton = env.NewFrame("Button", nil, select)
local vault = select.GreatVaultButton
vault.DisabledTexture = false
vault.NormalTexture = vault:CreateTexture()
vault.PushedTexture = vault:CreateTexture()
local vaultAction = function() end
vault:SetScript("OnClick", vaultAction)

frame.JourneysFrame = env.NewFrame("Frame", nil, frame)
local journeys = frame.JourneysFrame
journeys.BorderFrame = env.NewFrame("Frame", nil, journeys)
journeys.BorderFrame.Background = journeys.BorderFrame:CreateTexture()
journeys.JourneysList = env.NewFrame("Frame", nil, journeys)
local card = env.NewFrame("Button", nil, journeys.JourneysList)
card.NormalTexture = card:CreateTexture()
card.PushedTexture = card:CreateTexture()
card.RenownCardFactionName = card:CreateFontString()
card.RenownCardFactionLevel = card:CreateFontString()
card.DisabledTexture = false
local clicks = 0
card:SetScript("OnClick", function() clicks = clicks + 1 end)
journeys.Refresh = function() select.bg:SetAlpha(1) end
journeys.ResetView = journeys.Refresh
select.ScrollBox = env.NewFrame("Frame", nil, select)
local instance = env.NewFrame("Button", nil, select.ScrollBox)
instance.bgImage = instance:CreateTexture()
instance.bgImage:SetTexture("dungeon-preview")
instance.bgImage.AddMaskTexture = function(self, mask) self.mask = mask end
instance.CreateMaskTexture = instance.CreateTexture
instance.NormalTexture = instance:CreateTexture()
instance.GetNormalTexture = function(self) return self.NormalTexture end
frame.encounter = env.NewFrame("Frame", nil, frame)
frame.encounter.info = env.NewFrame("Frame", nil, frame.encounter)
local info = frame.encounter.info
info.model = env.NewFrame("ModelScene", nil, info)
info.model.dungeonBG = info.model:CreateTexture()
info.model.dungeonBG:SetTexture("native-dungeon-background")
info.model.imageTitle = info.model:CreateFontString()
local creatureButton = env.NewFrame("Button", nil, info)
creatureButton.DisabledTexture = false
creatureButton.creature = creatureButton:CreateTexture()
creatureButton.creature:SetTexture("native-creature-portrait")
creatureButton.displayInfo = 100
local creatureAction = function() end
creatureButton:SetScript("OnClick", creatureAction)
local alternateCreature = env.NewFrame("Button", nil, info)
alternateCreature.DisabledTexture = false
alternateCreature.displayInfo = 101
info.creatureButtons = { creatureButton, alternateCreature }
_G.EncounterJournal_DisplayCreature = function(button) info.shownCreatureButton = button end
info.shownCreatureButton = creatureButton
info.parchment = info:CreateTexture()
info.difficultyIcon = info:CreateTexture()
info.BossesScrollBox = env.NewFrame("Frame", nil, info)
local boss = env.NewFrame("Button", nil, info.BossesScrollBox)
boss.DisabledTexture = false
boss.creature = boss:CreateTexture()
boss.creature:SetTexture("boss-preview")
info.overviewTab = env.NewFrame("Button", nil, info)
info.overviewTab.DisabledTexture = false
info.overviewTab.selected = info.overviewTab:CreateTexture()
_G.EncounterJournal_SetTab = function(selected) info.overviewTab.selected:SetShown(selected) end
info.LootContainer = env.NewFrame("Frame", nil, info)
info.difficulty = env.NewFrame("Button", nil, info)
info.difficulty.DisabledTexture = false
info.LootContainer.filter = env.NewFrame("Button", nil, info.LootContainer)
info.LootContainer.filter.DisabledTexture = false
info.LootContainer.slotFilter = env.NewFrame("Button", nil, info.LootContainer)
info.LootContainer.slotFilter.DisabledTexture = false
info.LootContainer.slotFilter:SetPoint("LEFT", info.LootContainer.filter, "RIGHT", 10, 0)
local classMenu = function() end
info.LootContainer.filter:SetScript("OnClick", classMenu)
info.LootContainer.ScrollBox = env.NewFrame("Frame", nil, info.LootContainer)
info.LootContainer.classClearFilter = env.NewFrame("Frame", nil, info.LootContainer)
info.LootContainer.classClearFilter.text = info.LootContainer.classClearFilter:CreateFontString()
local clearFilter = info.LootContainer.classClearFilter
info.LootContainer.ScrollBox:SetPoint("TOPLEFT", clearFilter, "BOTTOMLEFT", 14, 7)
local lootRow = env.NewFrame("Button", nil, info.LootContainer.ScrollBox)
lootRow.icon = lootRow:CreateTexture()
lootRow.icon.AddMaskTexture = function(self, mask) self.mask = mask end
lootRow.CreateMaskTexture = lootRow.CreateTexture
lootRow.bossTexture = lootRow:CreateTexture()
lootRow.bosslessTexture = lootRow:CreateTexture()
lootRow.IconBorder = lootRow:CreateTexture()
lootRow.IconBorder.GetVertexColor = function(self) return unpack(self.vertex) end
lootRow.IconBorder:SetVertexColor(.6, .2, .9, 1)
lootRow.Init = function(self)
    self.bossTexture:SetAlpha(1)
    self.IconBorder:SetVertexColor(.1, .8, .2, 0)
end
local nativeLootInit = lootRow.Init
frame.encounter.instance = env.NewFrame("Frame", nil, frame.encounter)
local mapButton = env.NewFrame("Button", nil, frame.encounter.instance)
frame.encounter.instance.mapButton = mapButton
local lore = frame.encounter.instance:CreateTexture()
frame.encounter.instance.loreBG = lore
lore:SetTexture("native-dungeon-art")
lore.AddMaskTexture = function(self, mask) self.mask = mask end
frame.encounter.instance.CreateMaskTexture = frame.encounter.instance.CreateTexture

mapButton.DisabledTexture = false
mapButton.texture = mapButton:CreateTexture()
mapButton.nativeText = mapButton:CreateFontString()
mapButton.nativeText.IsObjectType = function() return false end
_G.ENCOUNTER_JOURNAL_SHOW_MAP = "Show\nMap"
local createMapText = mapButton.CreateFontString
mapButton.CreateFontString = function(self, ...)
    local text = createMapText(self, ...)
    local fontSet = false
    local setFont, setText = text.SetFont, text.SetText
    text.SetFont = function(label, ...)
        fontSet = true
        return setFont(label, ...)
    end
    text.SetText = function(label, value)
        assert(fontSet, "Show Map font must be initialized before writing its label")
        return setText(label, value)
    end
    return text
end
local mapClicks = 0
mapButton:SetScript("OnClick", function() mapClicks = mapClicks + 1 end)
frame.MonthlyActivitiesFrame = env.NewFrame("Frame", nil, frame)
local monthly = frame.MonthlyActivitiesFrame
monthly.Bg = monthly:CreateTexture()
monthly.ThemeContainer = env.NewFrame("Frame", nil, monthly)
monthly.ThemeContainer.Top = monthly.ThemeContainer:CreateTexture()
monthly.ThemeContainer.Bottom = monthly.ThemeContainer:CreateTexture()
monthly.FilterList = env.NewFrame("Frame", nil, monthly)
monthly.FilterList.Bg = monthly.FilterList:CreateTexture()
monthly.FilterList.ScrollBox = env.NewFrame("Frame", nil, monthly.FilterList)
monthly.ScrollBox = env.NewFrame("Frame", nil, monthly)
local activity = env.NewFrame("Button", nil, monthly.ScrollBox)
activity.DisabledTexture = false
activity.NormalTexture = activity:CreateTexture()
activity.Ribbon = activity:CreateTexture()
activity.RibbonStacked = activity:CreateTexture()
activity.Points = activity:CreateFontString()
activity.Points:SetText("100")
local filter = env.NewFrame("Button", nil, monthly.FilterList.ScrollBox)
filter.DisabledTexture = false
filter.Texture = filter:CreateTexture()
filter.Texture.GetAtlas = function() return "Options_List_Active" end
filter.UpdateStateInternal = function(self) self.Texture:SetAlpha(1) end
local oldForEach = env.SkinBase.ForEachScrollBoxFrame
env.SkinBase.ForEachScrollBoxFrame = function(scroll, callback)
    if scroll == monthly.ScrollBox then callback(activity)
    elseif scroll == monthly.FilterList.ScrollBox then callback(filter)
    else oldForEach(scroll, callback) end
end
frame.suggestFrame = env.NewFrame("Frame", nil, frame)
local suggested = env.NewFrame("Frame", nil, frame.suggestFrame)
frame.suggestFrame.Suggestion1 = suggested
suggested.bg = suggested:CreateTexture()
suggested.icon = suggested:CreateTexture()
suggested.iconRing = suggested:CreateTexture()
suggested.button = env.NewFrame("Button", nil, suggested)
suggested.button.DisabledTexture = false
suggested.button:SetText("Accept Quest")
local suggestedClick = function() end
suggested.button:SetScript("OnClick", suggestedClick)
frame.TutorialsFrame = env.NewFrame("Frame", nil, frame)
local tutorial = env.NewFrame("Frame", nil, frame.TutorialsFrame)
frame.TutorialsFrame.Contents = tutorial
tutorial.parchment = tutorial:CreateTexture()
tutorial.Header = tutorial:CreateFontString()
tutorial.Description = tutorial:CreateFontString()
tutorial.StartButton = env.NewFrame("Button", nil, tutorial)
tutorial.StartButton.DisabledTexture = false
tutorial.StartButton:SetText("Start")
local acquire
local registrations = {}
env.SkinBase.HookScrollBoxAcquired = function(scroll, callback)
    if scroll then registrations[scroll] = (registrations[scroll] or 0) + 1 end
    if scroll == journeys.JourneysList then acquire = callback; callback(card) end
    if scroll == select.ScrollBox then callback(instance) end
    if scroll == info.BossesScrollBox then callback(boss) end
    if scroll == info.LootContainer.ScrollBox then callback(lootRow) end
end
local forEachFrame = env.SkinBase.ForEachScrollBoxFrame
env.SkinBase.ForEachScrollBoxFrame = function(scroll, callback)
    forEachFrame(scroll, callback)
    if scroll == journeys.JourneysList then callback(card) end
    if scroll == select.ScrollBox then callback(instance) end
    if scroll == info.BossesScrollBox then callback(boss) end
    if scroll == info.LootContainer.ScrollBox then callback(lootRow) end
end
for id, key in ipairs({ "JourneysTab", "MonthlyActivitiesTab", "dungeonsTab", "raidsTab" }) do
    local tab = env.NewFrame("Button", nil, frame)
    tab:SetID(id)
    tab:SetText(key)
    tab.DisabledTexture = false
    frame[key] = tab
end
local abilityHeader = env.NewFrame("Frame", nil, frame.encounter)
abilityHeader.descriptionBG = abilityHeader:CreateTexture()
abilityHeader.descriptionBGBottom = abilityHeader:CreateTexture()
abilityHeader.button = env.NewFrame("Button", nil, abilityHeader)
local ability = abilityHeader.button
ability.CreateMaskTexture = ability.CreateTexture
ability.DisabledTexture = false
ability.title = ability:CreateFontString()
ability.title:SetText("Ability")
ability.expandedIcon = ability:CreateFontString()
ability.abilityIcon = ability:CreateTexture()
ability.abilityIcon.AddMaskTexture = function(self, mask) self.mask = mask end
ability.nativeHover = ability:CreateTexture()
ability.textures = { expanded = { up = { ability:CreateTexture() }, down = {} } }
local abilityClick = function() end
ability:SetScript("OnClick", abilityClick)
frame.encounter.overviewFrame = env.NewFrame("Frame", nil, frame.encounter)
frame.encounter.overviewFrame.header = frame.encounter.overviewFrame:CreateTexture()
frame.encounter.overviewFrame.overviews = { abilityHeader }
frame.encounter.usedHeaders = {}
local progress = env.NewFrame("Frame", nil, journeys)
journeys.JourneyProgress = progress
progress.DelvesCompanionConfigurationFrame = env.NewFrame("Frame", nil, progress)
local companion = env.NewFrame("Button", nil, progress.DelvesCompanionConfigurationFrame)
progress.DelvesCompanionConfigurationFrame.CompanionConfigBtn = companion
companion.DisabledTexture = false
companion.NormalTexture = companion:CreateTexture()
companion.NormalTexture:SetAtlas("native-companion-control")
companion.PushedTexture = companion:CreateTexture()
companion.PushedTexture:SetAtlas("native-companion-control-pressed")
companion:SetScript("OnClick", vaultAction)
card.NormalTexture:SetAtlas("native-journey-card")
local function TrackNativeAtlas(texture)
    local original = texture.SetTexture
    texture.SetTexture = function(self, value)
        self.atlas = nil
        original(self, value)
    end
end
TrackNativeAtlas(card.NormalTexture)
TrackNativeAtlas(companion.NormalTexture)
TrackNativeAtlas(vault.NormalTexture)
vault.NormalTexture:SetAtlas("native-vault-control")
progress.EncounterRewardProgressFrame = env.NewFrame("Frame", nil, progress)
local track = progress.EncounterRewardProgressFrame
for _, key in ipairs({ "LeftButton", "RightButton", "JumpLeftButton", "JumpRightButton" }) do
    track[key] = env.NewFrame("Button", nil, track)
    track[key].DisabledTexture = false
    track[key]:SetScript("OnMouseUp", vaultAction)
end
local reward = env.NewFrame("Frame", nil, track)
reward.RewardCardBG = reward:CreateTexture()
reward.LevelSquare = reward:CreateTexture()
reward.Icon = reward:CreateTexture()
reward.Icon:SetTexture("native-reward-art")
track.elementPool = { EnumerateActive = function()
    local nextFrame = reward
    return function() local result = nextFrame; nextFrame = nil; return result end
end }
track.RefreshView = function() reward.RewardCardBG:SetAlpha(1) end
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
progress.OverviewBtn = env.NewFrame("Button", nil, progress)
progress.OverviewBtn.DisabledTexture = false
progress.OverviewBtn:SetScript("OnClick", vaultAction)
progress.RenownTrackFrame = env.NewFrame("Frame", nil, progress)
local renownTrack = progress.RenownTrackFrame
for _, key in ipairs({ "LeftButton", "RightButton", "JumpLeftButton", "JumpRightButton" }) do
    renownTrack[key] = env.NewFrame("Button", nil, renownTrack)
    renownTrack[key].DisabledTexture = false
end
local levelCard = env.NewFrame("Frame", nil, renownTrack)
levelCard.Icon = levelCard:CreateTexture()
levelCard.Icon:SetTexture("renown-item-art")
levelCard.IconBorder = levelCard:CreateTexture()
levelCard.IconBorder.GetAtlas = function() return "reward-frame-yellow" end
levelCard.LevelRectangle = levelCard:CreateTexture()
levelCard.EarnedCheckmark = levelCard:CreateTexture()
renownTrack.elementPool = { EnumerateActive = function()
    local active = levelCard
    return function() local result = active; active = nil; return result end
end }
local detailReward = env.NewFrame("Frame", nil, progress)
detailReward.RewardCardBG = detailReward:CreateTexture()
detailReward.RewardCardIcon = detailReward:CreateTexture()
detailReward.RewardCardIcon:SetTexture("native-renown-reward")
detailReward.RewardCardBGGlow = detailReward:CreateTexture()
progress.rewardPool = { EnumerateActive = function()
    local active = detailReward
    return function() local result = active; active = nil; return result end
end }

journeys.JourneyOverview = env.NewFrame("Frame", nil, journeys)
local overview = journeys.JourneyOverview
overview.Highlights = env.NewFrame("Frame", nil, overview)
local highlightCard = env.NewFrame("Frame", nil, overview.Highlights)
highlightCard.Background = highlightCard:CreateTexture()
highlightCard.HighlightDescription = highlightCard:CreateFontString()
overview.Highlights.highlightPool = { EnumerateActive = function()
    local active = highlightCard
    return function() local result = active; active = nil; return result end
end }
overview.Highlights.DisplayHighlights = function()
    highlightCard.Background:SetAlpha(1)
end

assert(loadfile(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))("QUI", env.ns)
assert(select.bg:GetAlpha() == 0, "Journeys native page background must stay suppressed")
assert(info.parchment:GetAlpha() == 0, "encounter parchment must be removed")
assert(info.difficultyIcon:GetAlpha() == 1, "encounter semantic difficulty icon must remain visible")
assert(boss.creature:GetAlpha() == 1, "boss preview art must remain visible")
assert(env.SkinBase.GetBackdrop(boss)._quiRoundedSurface, "boss list buttons must use QUI chrome")
local selectedLine = env.SkinBase.GetFrameData(info.overviewTab, "qEncounterSelectedLine")
assert(selectedLine:IsShown(), "encounter selected tab must show an accent line")
_G.EncounterJournal_SetTab(false)
assert(not selectedLine:IsShown(), "native encounter tab changes must refresh the accent line")

assert(env.SkinBase.GetBackdrop(select.ExpansionDropdown)._quiRoundedSurface, "expansion selector must use rounded QUI controls")
assert(journeys.BorderFrame.Background:GetAlpha() == 0, "Journeys inner native border must be removed")
assert(card.NormalTexture:GetAlpha() == 0, "pooled renown cards must suppress native button art")
assert(env.SkinBase.GetBackdrop(card)._quiRoundedSurface.radius == 6, "renown cards must use rounded QUI surfaces")
assert(instance.bgImage:GetAlpha() == 1 and instance.bgImage.mask, "dungeon preview art must remain visible inside rounded chrome")
assert(instance.NormalTexture:GetAlpha() == 0, "dungeon card native border must be suppressed")
card:Fire("OnClick")
assert(clicks == 1, "journey drill-down actions must remain native")
journeys:Refresh()
assert(select.bg:GetAlpha() == 0, "native Journeys refresh must not restore native page art")
local recycled = env.NewFrame("Button")
recycled.NormalTexture = recycled:CreateTexture()
recycled.RenownCardFactionName = recycled:CreateFontString()
recycled.DisabledTexture = false
acquire(recycled)
assert(env.SkinBase.GetBackdrop(recycled)._quiRoundedSurface, "late pooled cards must receive the same chrome")
assert(env.SkinBase.GetFrameData(frame.JourneysTab, "tabWindowJoin"), "journal tabs must join the footer")
assert(lootRow.bossTexture:GetAlpha() == 0 and lootRow.bosslessTexture:GetAlpha() == 0, "loot rows must suppress both native gold variants")
assert(lootRow.icon.mask, "loot artwork must use a rounded mask")
assert(env.SkinBase.GetBackdrop(lootRow)._quiRoundedSurface.radius == 5, "loot rows must use rounded QUI chrome")
local lootIcon = env.SkinBase.GetFrameData(lootRow, "qEncounterLootIconFrame")
assert(env.SkinBase.GetBackdrop(lootIcon)._quiRoundedSurface.radius == 4, "loot quality borders must use rounded QUI chrome")
lootRow:Init()
assert(lootRow.bossTexture:GetAlpha() == 0, "native loot refresh must not restore gold row art")
assert(nativeLootInit ~= lootRow.Init, "loot refresh must be hooked without replacing its behavior")
local quality = env.SkinBase.GetBackdrop(lootIcon)._quiRoundedSurface.border.top.vertex
assert(quality[1] == .1 and quality[2] == .8 and quality[3] == .2 and quality[4] == 1, "recycled loot icons must keep updated native quality colors")
mapButton.nativeText:SetAlpha(1)
assert(mapButton.texture:GetAlpha() == 0, "Show Map must suppress its native gold art")
assert(env.SkinBase.GetFrameData(mapButton, "qEncounterMapText") == mapButton.nativeText, "Show Map must reuse the native label to avoid duplicate font regions")
assert(mapButton.nativeText:GetPoint(1) == "CENTER", "Show Map label must be integrated inside the control")
assert(env.SkinBase.GetFrameData(mapButton, "qEncounterMapText"):GetText() == "Show Map", "Show Map must retain a readable integrated label")
mapButton:Fire("OnClick")
assert(mapClicks == 1, "Show Map must retain its native action")
assert(monthly.Bg:GetAlpha() == 0 and monthly.FilterList.Bg:GetAlpha() == 0, "Traveler panels must suppress native parchment and borders")
assert(monthly.ThemeContainer.Top:GetAlpha() == 1 and monthly.ThemeContainer.Bottom:GetAlpha() == 0, "Traveler seasonal header art must remain while decorative panel borders disappear")
assert(activity.NormalTexture:GetAlpha() == 0 and activity.Ribbon:GetAlpha() == 0, "Traveler activity cards must suppress native chrome")
assert(activity.Points:GetText() == "100", "Traveler activity reward points must remain readable")
assert(env.SkinBase.GetBackdrop(activity)._quiRoundedSurface.radius == 5, "Traveler cards must match QUI rounded rows")
filter:UpdateStateInternal(false)
assert(filter.Texture:GetAlpha() == 0, "native filter refresh must not restore a gold selection gradient")
assert(suggested.bg:GetAlpha() == 0 and suggested.iconRing:GetAlpha() == 0, "Suggested Content must suppress parchment and gold rings")
assert(suggested.icon:GetAlpha() == 1, "Suggested Content must retain semantic activity icons")
assert(env.SkinBase.GetBackdrop(suggested)._quiRoundedSurface.radius == 6, "Suggested Content must use QUI panels")
assert(suggested.button:GetScript("OnClick") == suggestedClick, "suggested quest action must remain native")
assert(tutorial.parchment:GetAlpha() == 0, "Tutorials must suppress baked parchment")
assert(tutorial.Header:GetPoint(1) == "TOPLEFT", "Tutorials text must use the integrated content area")
assert(env.SkinBase.GetBackdrop(tutorial.StartButton)._quiRoundedSurface, "Tutorials action must use QUI chrome")
assert(ability.nativeHover:GetAlpha() == 0, "Abilities hover must not restore native gold highlights")
assert(abilityHeader.descriptionBG:GetAlpha() == 0, "Abilities must suppress description parchment")
assert(ability.textures.expanded.up[1]:GetAlpha() == 0, "Abilities must suppress native gold header pieces")
ability.textures.expanded.up[1]:SetAlpha(1)
assert(ability.textures.expanded.up[1]:GetAlpha() == 0, "native expand refresh must not restore gold header pieces")
assert(env.SkinBase.GetBackdrop(ability)._quiRoundedSurface.radius == 4, "Abilities must use QUI rounded rows")
assert(ability.abilityIcon:GetAlpha() == 1, "Abilities must retain the semantic spell icon")
assert(ability:GetScript("OnClick") == abilityClick, "Abilities must retain native expand action")
local _, owner = clearFilter:GetPoint(1)
assert(owner == info.LootContainer, "clear filter must anchor to the container and avoid a cycle with its dependent list")
local _, listOwner, _, _, listY = info.LootContainer.ScrollBox:GetPoint(#info.LootContainer.ScrollBox.points)
assert(listOwner == clearFilter and listY == -4, "filtered loot must begin below the clear strip without overlapping")
print("OK: encounter_journal_inner_controls_test")


assert(info.LootContainer.filter:GetWidth() == 160, "long class and specialization labels need a full-width selector")
local fp, fo, fr, fx = info.LootContainer.filter:GetPoint()
local sp, so, sr, sx = info.LootContainer.slotFilter:GetPoint()
assert(fp == "TOPRIGHT" and fo == info.LootContainer.slotFilter and fr == "TOPLEFT" and fx == -8, "class selector must sit left of slots with a consistent gap")
assert(sp == "TOPRIGHT" and so == info.difficulty and sr == "TOPLEFT" and sx == -8, "slot selector must anchor independently to difficulty to avoid a cycle")
assert(info.LootContainer.filter:GetScript("OnClick") == classMenu, "class filter menu remains native")

assert(vault.NormalTexture:GetAlpha() == 0 and vault.PushedTexture:GetAlpha() == 0,
    "vault shortcut must suppress its baked native gold control art")
assert(vault:GetScript("OnClick") == vaultAction and vault:GetWidth() == 26,
    "compact vault shortcut must retain its native action")
assert(env.SkinBase.GetFrameData(vault, "qVaultShortcutText"):GetText() == "V",
    "vault shortcut requires a readable neutral glyph")

assert(card.NormalTexture.atlas == "native-journey-card"
    and companion.NormalTexture.atlas == "native-companion-control" and vault.NormalTexture.atlas == "native-vault-control",
    "native AlphaHighlight buttons must retain atlas metadata required for pressed-state updates")
assert(companion.NormalTexture:GetAlpha() == 0 and companion:GetScript("OnClick") == vaultAction,
    "actual nested companion button requires rounded chrome with native navigation")
track:RefreshView()
assert(reward.RewardCardBG:GetAlpha() == 0 and reward.Icon.texture == "native-reward-art",
    "recycled Journey reward cards must suppress decorative art while preserving reward icons")
assert(env.SkinBase.GetBackdrop(reward)._quiRoundedSurface.radius == 5,
    "Journey reward cards require individually rounded surfaces")
assert(env.SkinBase.GetBackdrop(track.JumpLeftButton) and env.SkinBase.GetBackdrop(track.JumpRightButton),
    "both Jump paging controls require visible QUI chrome")

assert(env.SkinBase.GetBackdrop(progress.OverviewBtn) and progress.OverviewBtn:GetScript("OnClick") == vaultAction,
    "renown Overview requires native navigation and QUI chrome")
assert(env.SkinBase.GetBackdrop(renownTrack.LeftButton), "separate renown paging controls must be skinned")
assert(levelCard.IconBorder:GetAlpha() == 0 and levelCard.LevelRectangle:GetAlpha() == 0,
    "renown track must suppress gold decorative borders")
assert(levelCard.Icon.texture == "renown-item-art" and levelCard.EarnedCheckmark:GetAlpha() == 1,
    "renown reward art and earned semantic state must remain native")
assert(detailReward.RewardCardBG:GetAlpha() == 0 and detailReward.RewardCardBGGlow:GetAlpha() == 1
    and detailReward.RewardCardIcon.texture == "native-renown-reward",
    "renown detail cards must retain item art and unclaimed reward glow")
assert(env.SkinBase.GetBackdrop(detailReward)._quiRoundedSurface.radius == 5,
    "renown detail cards require QUI rounded chrome")

overview.Highlights:DisplayHighlights()
assert(highlightCard.Background:GetAlpha() == 0
    and env.SkinBase.GetBackdrop(highlightCard)._quiRoundedSurface.radius == 5,
    "renown Overview highlights require individually styled recycled cards")


assert(lore.texture == "native-dungeon-art" and lore:GetAlpha() == 1,
    "overview must retain identifying dungeon art")
assert(lore.texCoord[1] > 0 and lore.texCoord[2] < .7617187 and lore.texCoord[3] > 0 and lore.texCoord[4] < .65625,
    "overview crop must exclude baked native gold border inside its padded source region")
assert(env.SkinBase.GetFrameData(frame.encounter.instance, "qEncounterLorePanel"),
    "overview art requires its own QUI border")

assert(frame.encounter.overviewFrame.header:GetAlpha() == 0, "Overview heading must suppress native gold art while retaining its anchor")

assert(info.model.dungeonBG:GetAlpha() == 0 and env.SkinBase.GetBackdrop(info.model),
    "model viewport must replace native paper with QUI chrome")
assert(env.SkinBase.GetBackdrop(info.model):GetFrameLevel() < info.model:GetFrameLevel(),
    "viewport background must remain below native 3D actors")
assert(creatureButton.creature.texture == "native-creature-portrait" and creatureButton.creature:GetAlpha() == 1
    and creatureButton:GetScript("OnClick") == creatureAction,
    "creature selector must preserve portrait and native model navigation")
assert(env.SkinBase.GetFrameData(creatureButton, "skinSelected"), "current model creature must receive selection state")

_G.EncounterJournal_DisplayCreature(alternateCreature)
assert(not env.SkinBase.GetFrameData(creatureButton, "skinSelected")
    and env.SkinBase.GetFrameData(alternateCreature, "skinSelected"),
    "native creature switching must move selection to the actual current portrait")
local wr, wg, wb = env.SkinBase.GetWindowColors()
local stored = env.SkinBase.GetFrameData(creatureButton, "windowColor")
assert(stored[1] == wr and stored[2] == wg and stored[3] == wb,
    "old creature must restore neutral border including hover-leave state")
assert(creatureButton:GetWidth() == alternateCreature:GetWidth(),
    "native selected resizing must not shift the portrait column")

local registered = {}
for scroll, count in pairs(registrations) do registered[scroll] = count end
for _ = 1, 3 do
    frame:Fire("OnShow")
    journeys:Refresh()
    _G.EncounterJournal_DisplayCreature(creatureButton)
    _G.QUI_RefreshEncounterJournalColors()
end
for scroll, count in pairs(registered) do
    assert(registrations[scroll] == count, "journal show and native/theme refresh must reuse acquired callbacks")
end
assert(env.SkinBase.GetBackdrop(card)._quiRoundedSurface,
    "existing journey cards must still refresh with guarded acquired callbacks")
