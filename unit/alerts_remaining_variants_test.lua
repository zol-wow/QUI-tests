local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
local skin = env.SkinBase
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
_G.Enum = {ItemQuality = {Epic = 4, Legendary = 5}}
local colors = {[4] = {0.64, 0.21, 0.93}, [5] = {1, 0.5, 0}}
_G.C_Item.GetItemQualityByID = function() return nil end
_G.C_Item.GetItemQualityColor = function(quality) return unpack(colors[quality]) end
_G.ColorManager = {GetAtlasDataForLootBorderItemQuality = function(quality)
    return ({[4] = "loottoast-itemborder-purple", [5] = "loottoast-itemborder-orange"})[quality]
end}
local nativeClick = function() end
local specs = env.NewFrame("Button")
specs.Icon = specs:CreateTexture()
function specs.Icon:SetMask(value) self.nativeMask = value end
specs.Title = specs:CreateFontString()
specs.Name = specs:CreateFontString()
local specsBG = specs:CreateTexture()
function specsBG:GetAtlas() return self.atlas end
specs:SetScript("OnClick", nativeClick)
_G.SkillLineSpecsUnlockedAlertSystem = {
    setUpFunction = function(owner, name)
        owner.Icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        owner.Icon:SetTexture("native-profession-art")
        owner.Title:SetText("New Feature")
        owner.Name:SetText(name .. " Specializations")
        owner.Name:SetTextColor(1, 0.82, 0, 1)
        specsBG:SetAtlas("recipetoast-bg")
        specsBG:SetAlpha(1)
        specsBG:Show()
    end,
    alertFramePool = {EnumerateActive = function() return next, {[specs] = true} end},
}
local guild = env.NewFrame("Button")
guild.HeaderLabel = guild:CreateFontString()
guild.GuildName = guild:CreateFontString()
for _, name in ipairs({"GuildTabardBackground", "GuildTabardEmblem", "GuildTabardBorder"}) do
    guild[name] = guild:CreateTexture()
end
local guildBG = guild:CreateTexture()
guild:SetScript("OnClick", nativeClick)
_G.GuildRenameAlertSystem = {
    setUpFunction = function(owner, name)
        owner.GuildName:SetText(name)
        owner.GuildName:SetTextColor(0, 1, 0, 1)
        owner.HeaderLabel:SetTextColor(1, 0.82, 0, 1)
        guildBG:SetTexture("Interface\\GuildFrame\\GuildChallenges")
        guildBG:SetAlpha(1)
        guildBG:Show()
        for _, key in ipairs({"GuildTabardBackground", "GuildTabardEmblem", "GuildTabardBorder"}) do
            owner[key]:SetTexture("native-" .. key)
            owner[key]:Show()
        end
    end,
    alertFramePool = {EnumerateActive = function() return next, {[guild] = true} end},
}
local rewards = {}
for _, name in ipairs({"NewRuneforgePowerAlertSystem", "NewCosmeticAlertFrameSystem"}) do
    local frame = env.NewFrame("Button")
    frame.Icon = frame:CreateTexture()
    frame.IconBorder = frame:CreateTexture()
    function frame.IconBorder:GetAtlas() return self.atlas end
    frame.Name = frame:CreateFontString()
    frame.Label = frame:CreateFontString()
    frame.IconOverlay = frame:CreateTexture()
    frame.IconOverlay:SetAtlas("native-cosmetic-identifier")
    frame:SetScript("OnClick", nativeClick)
    local system = {
        setUpFunction = function(owner, quality)
            owner.Icon:SetTexture("native-reward-art")
            owner.IconBorder:SetAtlas(_G.ColorManager.GetAtlasDataForLootBorderItemQuality(quality))
            owner.IconBorder:SetAlpha(1)
            owner.IconBorder:Show()
            owner.Name:SetText("Native reward name")
            owner.Name:SetTextColor(unpack(colors[quality]))
        end,
        alertFramePool = {EnumerateActive = function() return next, {[frame] = true} end},
    }
    _G[name] = system
    rewards[#rewards + 1] = {frame = frame, system = system}
end
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
for _, name in ipairs({"Alchemy", "Blacksmithing"}) do
    _G.SkillLineSpecsUnlockedAlertSystem.setUpFunction(specs, name)
    _G.GuildRenameAlertSystem.setUpFunction(guild, name .. " Guild")
    env.RunTimers()
    assert(specs.Icon.nativeMask == "" and specs.Icon.texture == "native-profession-art", "specialization must remove native portrait clipping and preserve profession art")
    assert(specsBG:GetAlpha() == 0 and specs.Name.textColor[3] > 0.9, "specialization chrome and captions must use QUI styling on reuse")
    assert(specs.Name:GetText() == name .. " Specializations" and specs:GetScript("OnClick") == nativeClick, "native specialization name and navigation must survive")
    assert(skin.GetFrameData(guild, "backdrop"), "iconless guild rename toast needs a full-frame QUI shell")
    assert(guildBG:GetAlpha() == 0 and guild.HeaderLabel.textColor[3] > 0.9, "guild rename chrome and caption must use QUI styling on reuse")
    assert(guild.GuildName:GetText() == name .. " Guild" and guild.GuildName.textColor[2] == 1 and guild.GuildName.textColor[1] == 0, "native guild-name color and text must survive")
    for _, key in ipairs({"GuildTabardBackground", "GuildTabardEmblem", "GuildTabardBorder"}) do
        assert(guild[key].texture == "native-" .. key and guild[key]:IsShown(), "all native tabard layers must survive")
    end
    assert(guild:GetScript("OnClick") == nativeClick, "native guild navigation must survive")
end
for _, entry in ipairs(rewards) do
    for _, quality in ipairs({5, 4, 5}) do
        entry.system.setUpFunction(entry.frame, quality)
        env.RunTimers()
        local border = skin.GetFrameData(entry.frame, "iconBorder")
        border._quiBorderR = 0.11
        _G.QUI_RefreshAlertColors()
        assert(border._quiBorderR == colors[quality][1] and border._quiBorderB == colors[quality][3], "Runeforge and cosmetic reward quality must survive theme refresh")
        assert(entry.frame.Icon.texture == "native-reward-art" and entry.frame.Name.textColor[1] == colors[quality][1], "native reward art and name rarity must survive")
        assert(entry.frame.IconOverlay.atlas == "native-cosmetic-identifier" and entry.frame:GetScript("OnClick") == nativeClick, "native cosmetic identifier and navigation must survive")
    end
end
for _, frame in ipairs({guild, specs}) do
    local bd = skin.GetFrameData(frame, "backdrop")
    bd._quiBorderR = 0.11
    _G.QUI_RefreshAlertColors()
    local r = skin.GetWindowColors(env.profile.general, "alerts")
    assert(bd._quiBorderR == r, "specialization and guild rename shells must participate in theme refresh")
end
print("OK: alerts_remaining_variants_test")
