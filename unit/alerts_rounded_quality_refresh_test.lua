local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
_G.C_Item.GetItemQualityByID = function() return 4 end
_G.C_Item.GetItemQualityColor = function(quality)
    if quality == 2 then return 0.12, 1, 0 end
    if quality == 3 then return 0, 0.44, 0.87 end
    return 0.64, 0.21, 0.93
end
_G.Enum = {ItemQuality = {Uncommon = 2, Rare = 3, Epic = 4}}
_G.ColorManager = {GetAtlasDataForLootBorderItemQuality = function(quality)
    return ({[2] = "loottoast-itemborder-green", [3] = "loottoast-itemborder-blue", [4] = "loottoast-itemborder-purple"})[quality]
end}
local miscSystems = {}
for _, name in ipairs({"NewPetAlertSystem", "NewMountAlertSystem", "NewToyAlertSystem", "NewWarbandSceneAlertSystem"}) do
    local active = {}
    local system = {
        setUpFunction = function(owner, quality)
            owner.IconBorder:SetAtlas(_G.ColorManager.GetAtlasDataForLootBorderItemQuality(quality) or "unknown-border")
            owner.IconBorder:SetAlpha(1)
            owner.IconBorder:Show()
        end,
        alertFramePool = {EnumerateActive = function() return next, active end},
    }
    _G[name] = system
    miscSystems[#miscSystems + 1] = {system = system, active = active}
end
local alert = env.NewFrame("Frame")
alert.hyperlink = "item:123"
alert.Background = alert:CreateTexture()
alert.Icon = alert:CreateTexture()
alert.Icon:SetTexture("reward-art")
alert.Label = alert:CreateFontString()
_G.AchievementAlertSystem = { setUpFunction = function() end, alertFramePool = { EnumerateActive = function() return next, { [alert] = true } end } }
_G.DungeonCompletionAlertSystem = { setUpFunction = function(owner, heroic)
    owner.dungeonArt:SetTexture("native-dungeon-art")
    owner.dungeonArt:SetAlpha(1)
    owner.dungeonArt:Show()
    owner.raidArt:SetTexture("native-raid-art")
    owner.raidArt:SetAlpha(1)
    owner.raidArt:Show()
    owner.dungeonTexture:ClearAllPoints()
    owner.dungeonTexture:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 13, 18)
    owner.heroicIcon:SetShown(heroic)
end }
_G.ScenarioAlertSystem = { setUpFunction = function(owner, bonus)
    owner.BonusStar:SetShown(bonus)
end }
_G.WorldQuestCompleteAlertSystem = { setUpFunction = function(owner)
    owner.ToastBackground:SetTexture("native-quest-toast")
    owner.ToastBackground:SetAlpha(1)
    owner.ToastBackground:Show()
end }
_G.NewRecipeLearnedAlertSystem = { setUpFunction = function(owner, upgraded)
    owner.Icon:SetMask("native-portrait-mask")
    owner.Icon:SetTexture(upgraded and "upgraded-profession-art" or "profession-art")
    owner.Title:SetText(upgraded and "Recipe Upgraded" or "New Recipe")
    owner.Name:SetText(upgraded and "Native Recipe |Tnative-rank-star:0|t" or "Native Recipe")
end }
_G.EntitlementDeliveredAlertSystem = { setUpFunction = function(owner)
    owner.Title:SetText("Native entitlement")
end }
_G.RafRewardDeliveredAlertSystem = { setUpFunction = function(owner, fancy, gameTime)
    owner.StandardBackground:SetAtlas("native-standard-toast")
    owner.FancyBackground:SetAtlas("native-fancy-toast")
    owner.StandardBackground:SetAlpha(1)
    owner.FancyBackground:SetAlpha(1)
    owner.StandardBackground:SetShown(not fancy)
    owner.FancyBackground:SetShown(fancy)
    owner.Icon:ClearAllPoints()
    owner.Icon:SetPoint("LEFT", owner, "LEFT", 34, -5)
    owner.Title:SetTextColor(gameTime and 0.2 or 0.64, gameTime and 0.6 or 0.21, 0.93, 1)
end }
_G.DigsiteCompleteAlertSystem = { setUpFunction = function(owner)
    owner.DigsiteTypeTexture:SetTexture("native-digsite-art")
end }
_G.GuildChallengeAlertSystem = { setUpFunction = function(owner)
    owner.EmblemIcon:SetTexture("native-guild-emblem")
    owner.EmblemBackground:SetTexture("native-guild-color")
    owner.EmblemBorder:SetAlpha(1)
    owner.EmblemBorder:Show()
end }
_G.InvasionAlertSystem = { setUpFunction = function(owner, bonus)
    owner.BonusStar:SetShown(bonus)
end }
_G.CriteriaAlertSystem = { setUpFunction = function() end }
_G.MonthlyActivityAlertSystem = { setUpFunction = function() end }
_G.HonorAwardedAlertSystem = { setUpFunction = function() end }
_G.MoneyWonAlertSystem = { setUpFunction = function() end }
_G.LootAlertSystem = { setUpFunction = function() end }
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
_G.LootAlertSystem.setUpFunction(alert)
env.RunTimers()
assert(env.SkinBase.GetFrameData(alert, "backdrop")._quiRoundedSurface,
    "reward alert shell must match rounded QUI windows")
local iconBorder = env.SkinBase.GetFrameData(alert, "iconBorder")
assert(iconBorder._quiRoundedSurface, "reward icon borders must match other QUI icons")
_G.QUI_RefreshAlertColors()
local r, g, b = iconBorder._quiBorderR, iconBorder._quiBorderG, iconBorder._quiBorderB
assert(r == 0.64 and g == 0.21 and b == 0.93, "theme refresh must preserve reward item-quality borders")
assert(alert.Icon:GetAlpha() == 1, "reward artwork must remain visible")
assert(alert.Label.textColor[3] > 0.9, "loot heading must be neutral without overriding quality color")
local money = env.NewFrame("Button")
money.Background = money:CreateTexture()
money.IconBorder = money:CreateTexture()
money.Icon = money:CreateTexture()
money.Icon:SetTexture("coin-art")
money.Label = money:CreateFontString()
money.Amount = money:CreateFontString()
money.Amount:SetText("12 |Tgold:0|t")
_G.MoneyWonAlertSystem.setUpFunction(money)
env.RunTimers()
assert(env.SkinBase.GetFrameData(money, "iconBorder")._quiRoundedSurface, "money icon needs rounded border")
assert(money.Icon:GetAlpha() == 1 and money.Icon.texture == "coin-art", "native coin art must survive")
assert(money.Amount:GetText() == "12 |Tgold:0|t", "native currency formatting must survive")
assert(money.Label.textColor[1] > 0.9 and money.Label.textColor[3] > 0.9, "money heading must use neutral alert text")
local honor = env.NewFrame("Button")
honor.Background = honor:CreateTexture()
honor.IconBorder = honor:CreateTexture()
honor.Icon = honor:CreateTexture()
honor.Icon:SetTexture("honor-art")
honor.Label = honor:CreateFontString()
honor.Amount = honor:CreateFontString()
honor.Amount:SetText("125 Honor")
_G.HonorAwardedAlertSystem.setUpFunction(honor)
env.RunTimers()
assert(honor.Label.textColor[3] > 0.9 and honor.Amount:GetText() == "125 Honor", "honor label must be neutral and native amount retained")
assert(honor.Icon.texture == "honor-art", "honor identifier art must survive")
local achievement = env.NewFrame("Button")
achievement.Name = achievement:CreateFontString()
achievement.Unlocked = achievement:CreateFontString()
achievement.Icon = env.NewFrame("Frame", nil, achievement)
achievement.Icon.Texture = achievement.Icon:CreateTexture()
achievement.Icon.Texture:SetTexture("achievement-art")
achievement.Shield = env.NewFrame("Frame", nil, achievement)
achievement.Shield.Points = achievement.Shield:CreateFontString()
achievement.Shield.Points:SetText("10")
_G.AchievementAlertSystem.setUpFunction(achievement)
env.RunTimers()
assert(achievement.Name.textColor[3] > 0.9, "achievement name must use neutral alert text")
assert(achievement.Shield.Points:GetText() == "10" and achievement.Icon.Texture.texture == "achievement-art", "native achievement points and art must survive")
for _, system in ipairs({_G.CriteriaAlertSystem, _G.MonthlyActivityAlertSystem}) do
    local criteria = env.NewFrame("Button")
    criteria.Name = criteria:CreateFontString()
    criteria.Name:SetText("Native activity description")
    criteria.Unlocked = criteria:CreateFontString()
    criteria.Icon = env.NewFrame("Frame", nil, criteria)
    criteria.Icon.Texture = criteria.Icon:CreateTexture()
    criteria.Icon.Texture:SetTexture("native-activity-art")
    local nativeClick = function() end
    criteria:SetScript("OnClick", nativeClick)
    system.setUpFunction(criteria)
    env.RunTimers()
    assert(criteria.Name.textColor[3] > 0.9 and criteria.Unlocked.textColor[3] > 0.9, "criteria and monthly headings must share neutral alert text")
    assert(criteria.Name:GetText() == "Native activity description" and criteria.Icon.Texture.texture == "native-activity-art", "native activity content and art must survive")
    assert(criteria:GetScript("OnClick") == nativeClick, "native alert navigation handler must remain intact")
    assert(env.SkinBase.GetFrameData(criteria, "backdrop")._quiRoundedSurface, "both activity variants need rounded alert chrome")
end
local dungeon = env.NewFrame("Button")
for _, key in ipairs({"dungeonTexture", "dungeonArt", "raidArt", "heroicIcon"}) do dungeon[key] = dungeon:CreateTexture() end
dungeon.dungeonTexture:SetTexture("native-instance-art")
dungeon.heroicIcon:SetTexture("native-heroic-icon")
dungeon.completionText = dungeon:CreateFontString()
dungeon.instanceName = dungeon:CreateFontString()
for _, heroic in ipairs({true, false, true}) do
    _G.DungeonCompletionAlertSystem.setUpFunction(dungeon, heroic)
    env.RunTimers()
    assert(dungeon.dungeonArt:GetAlpha() == 0 and dungeon.raidArt:GetAlpha() == 0, "native completion chrome must stay suppressed on reuse")
    assert(dungeon.dungeonTexture.points[1][1] == "LEFT", "reused completion icon must keep QUI anchor")
    assert(dungeon.dungeonTexture.texture == "native-instance-art", "identifying instance art must survive")
    assert(dungeon.heroicIcon:GetAlpha() == 1 and dungeon.heroicIcon:IsShown() == heroic and dungeon.heroicIcon.texture == "native-heroic-icon", "heroic difficulty indicator must retain native art and visibility")
    assert(dungeon.instanceName.textColor[3] > 0.9, "instance caption must be neutral")
end
local scenario = env.NewFrame("Button")
scenario.dungeonTexture = scenario:CreateTexture()
scenario.dungeonTexture:SetTexture("native-scenario-art")
scenario.BonusStar = scenario:CreateTexture()
scenario.BonusStar:SetAtlas("Bonus-ToastBanner")
local scenarioLabel = scenario:CreateFontString()
scenarioLabel:SetTextColor(0.973, 0.937, 0.580, 1)
for _, bonus in ipairs({true, false}) do
    _G.ScenarioAlertSystem.setUpFunction(scenario, bonus)
    env.RunTimers()
    assert(scenarioLabel.textColor[3] > 0.9, "anonymous scenario completion heading must be neutral")
    assert(scenario.BonusStar:IsShown() == bonus and scenario.BonusStar.atlas == "Bonus-ToastBanner", "native scenario bonus indicator must survive")
end
local quest = env.NewFrame("Button")
quest.ToastBackground = quest:CreateTexture()
quest.QuestTexture = quest:CreateTexture()
quest.QuestTexture:SetTexture("native-quest-art")
quest.ToastText = quest:CreateFontString()
quest.QuestName = quest:CreateFontString()
for i = 1, 2 do
    _G.WorldQuestCompleteAlertSystem.setUpFunction(quest)
    env.RunTimers()
    assert(quest.ToastBackground:GetAlpha() == 0, "world quest toast must suppress restored native background on reuse")
    assert(quest.QuestTexture.texture == "native-quest-art" and quest.QuestName.textColor[3] > 0.9, "world quest icon must survive with neutral caption")
end
local recipe = env.NewFrame("Button")
recipe.Icon = recipe:CreateTexture()
function recipe.Icon:SetMask(value) self.nativeMask = value end
local recipeBackground = recipe:CreateTexture()
recipeBackground:SetAtlas("recipetoast-bg")
function recipeBackground:GetAtlas() return self.atlas end
recipe.Title = recipe:CreateFontString()
recipe.Name = recipe:CreateFontString()
local recipeClick = function() end
recipe:SetScript("OnClick", recipeClick)
for _, upgraded in ipairs({false, true, false}) do
    _G.NewRecipeLearnedAlertSystem.setUpFunction(recipe, upgraded)
    env.RunTimers()
    assert(recipe.Icon.nativeMask == "", "reused recipe icon must clear native portrait mask")
    assert(recipe.Icon.texture == (upgraded and "upgraded-profession-art" or "profession-art") and recipe.Icon:GetAlpha() == 1, "profession art must survive regardless of region order")
    assert(recipeBackground:GetAlpha() == 0, "recipe toast background must be suppressed by its atlas")
    assert(recipe.Icon.points[1][1] == "LEFT", "reused recipe icon must retain QUI alignment")
    assert(recipe.Title.textColor[3] > 0.9 and recipe.Name.textColor[3] > 0.9, "recipe labels must be neutral")
    assert(recipe.Name:GetText() == (upgraded and "Native Recipe |Tnative-rank-star:0|t" or "Native Recipe"), "recipe rank art and text must remain native")
    assert(recipe:GetScript("OnClick") == recipeClick, "native profession navigation must survive")
end
for _, system in ipairs({_G.EntitlementDeliveredAlertSystem, _G.RafRewardDeliveredAlertSystem}) do
    local entitlement = env.NewFrame("Button")
    entitlement.Icon = entitlement:CreateTexture()
    entitlement.Icon:SetTexture("native-entitlement-art")
    entitlement.Title = entitlement:CreateFontString()
    entitlement.StandardBackground = entitlement:CreateTexture()
    entitlement.FancyBackground = entitlement:CreateTexture()
    local entitlementClick = function() end
    entitlement:SetScript("OnClick", entitlementClick)
    for _, fancy in ipairs({false, true, false}) do
        system.setUpFunction(entitlement, fancy, fancy)
        env.RunTimers()
        assert(entitlement.StandardBackground:GetAlpha() == 0 and entitlement.FancyBackground:GetAlpha() == 0, "both RAF chrome variants must remain suppressed on reuse")
        assert(entitlement.Icon.points[1][2] == env.SkinBase.GetFrameData(entitlement, "backdrop"), "entitlement icon must realign with QUI shell after reuse")
        assert(entitlement.Icon.texture == "native-entitlement-art" and entitlement:GetScript("OnClick") == entitlementClick, "entitlement art and native delivery navigation must survive")
        if system == _G.RafRewardDeliveredAlertSystem then
            assert(entitlement.Title.textColor[1] == (fancy and 0.2 or 0.64), "RAF reward type colors must remain semantic")
        end
    end
end
for _, entry in ipairs(miscSystems) do
    local misc = env.NewFrame("Button")
    misc.Icon = misc:CreateTexture()
    misc.Icon:SetTexture("native-collection-art")
    misc.IconBorder = misc:CreateTexture()
    function misc.IconBorder:GetAtlas() return self.atlas end
    misc.Name = misc:CreateFontString()
    misc.Name:SetText("|cffa335eeNative collection name|r")
    misc.Label = misc:CreateFontString()
    entry.active[misc] = true
    for _, quality in ipairs({2, 4, 3, 99, 4}) do
        entry.system.setUpFunction(misc, quality)
        env.RunTimers()
        local border = env.SkinBase.GetFrameData(misc, "iconBorder")
        border:SetBackdropBorderColor(1, 0, 0, 1)
        _G.QUI_RefreshAlertColors()
        if quality ~= 99 then
            local qr, qg, qb = _G.C_Item.GetItemQualityColor(quality)
            assert(border._quiBorderR == qr and border._quiBorderG == qg and border._quiBorderB == qb, "collection alert quality must survive reuse and refresh without a hyperlink")
        else
            assert(env.SkinBase.GetFrameData(misc, "miscAlertQualityColor") == nil, "unrecognized quality must clear pooled color rather than retaining prior rarity")
            assert(border._quiBorderR == env.colors[1] and border._quiBorderB == env.colors[3], "unrecognized quality must reset to current theme chrome")
        end
        assert(misc.Icon.texture == "native-collection-art" and misc.Name:GetText() == "|cffa335eeNative collection name|r", "collection art and semantic name must survive")
        assert(misc.Label.textColor[3] > 0.9 and misc.IconBorder:GetAlpha() == 0, "collection heading must be neutral and native border suppressed")
    end
end
local digsite = env.NewFrame("Button")
digsite.DigsiteTypeTexture = digsite:CreateTexture()
local digsiteTitle = digsite:CreateFontString()
local digsiteBackdrop = digsite:CreateTexture()
local guild = env.NewFrame("Button")
guild.EmblemIcon = guild:CreateTexture()
guild.EmblemBackground = guild:CreateTexture()
guild.EmblemBorder = guild:CreateTexture()
local guildHeading = guild:CreateFontString()
local guildBackdrop = guild:CreateTexture()
local invasion = env.NewFrame("Button")
invasion.BonusStar = invasion:CreateTexture()
invasion.BonusStar:SetAtlas("Bonus-ToastBanner")
local invasionHeading = invasion:CreateFontString()
local invasionIcon = invasion:CreateTexture()
invasionIcon:SetTexture(236293)
local invasionBackdrop = invasion:CreateTexture()
invasionBackdrop:SetAtlas("legioninvasion-Toast-Frame")
for _, texture in ipairs({invasionIcon, invasionBackdrop, invasion.BonusStar}) do
    function texture:GetAtlas() return self.atlas end
    function texture:GetTexture() return self.texture end
end
for _, bonus in ipairs({true, false, true}) do
    _G.DigsiteCompleteAlertSystem.setUpFunction(digsite)
    _G.GuildChallengeAlertSystem.setUpFunction(guild)
    _G.InvasionAlertSystem.setUpFunction(invasion, bonus)
    env.RunTimers()
    assert(digsite.DigsiteTypeTexture.texture == "native-digsite-art" and digsite.DigsiteTypeTexture:GetAlpha() == 1, "digsite art must survive even when it is the first region")
    assert(digsiteBackdrop:GetAlpha() == 0 and digsiteTitle.textColor[3] > 0.9, "digsite chrome and text must be consistent")
    assert(guild.EmblemIcon.texture == "native-guild-emblem" and guild.EmblemBackground.texture == "native-guild-color" and guild.EmblemBackground:GetAlpha() == 1, "guild tabard identity and colors must survive native reuse")
    assert(guild.EmblemBorder:GetAlpha() == 0 and guildBackdrop:GetAlpha() == 0 and guildHeading.textColor[3] > 0.9, "guild decorative art must stay suppressed after setup")
    assert(invasionIcon.texture == 236293 and env.SkinBase.GetFrameData(invasion, "iconBorder"), "invasion demon art must be styled regardless of region order")
    assert(invasionBackdrop:GetAlpha() == 0 and invasionHeading.textColor[3] > 0.9, "invasion anonymous heading and background must receive QUI styling")
    assert(invasion.BonusStar:IsShown() == bonus and invasion.BonusStar.atlas == "Bonus-ToastBanner", "invasion native bonus state must survive")
end
print("OK: alerts_rounded_quality_refresh_test")
