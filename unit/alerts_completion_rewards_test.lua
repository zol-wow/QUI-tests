local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
local skin = env.SkinBase
for _, method in ipairs({"SetFrameBackdropColor", "SetFrameBackdropBorderColor"}) do
    env.ns.Helpers[method] = function(frame, ...) frame[method == "SetFrameBackdropColor" and "SetBackdropColor" or "SetBackdropBorderColor"](frame, ...) end
end
_G.C_Item.GetItemQualityByID = function(link) return link == "epic-link" and 4 or nil end
_G.C_Item.GetItemQualityColor = function() return 0.64, 0.21, 0.93 end
_G.SOUNDKIT = {LFG_REWARDS = 1, UI_SCENARIO_ENDING = 2}
_G.PlaySound = function() end
_G.LFG_SUBTYPEID_RAID, _G.LFG_SUBTYPEID_HEROIC = 2, 3
local file = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrameSystems.lua"))
local native = file:read("*a"); file:close()
local first = assert(native:find("-- Utility to acquire", 1, true))
local last = assert(native:find("-- [[ScenarioLegionInvasionAlertFrame ]]", first, true))
local coalesceStart = assert(native:find("function WorldQuestCompleteAlertFrame_Coalesce", 1, true))
local coalesceEnd = assert(native:find("-- [[LegendaryItemAlertFrame ]]", coalesceStart, true))
assert(loadstring(native:sub(first,last-1) .. native:sub(coalesceStart,coalesceEnd-1)))()
_G.ALERT_FRAME_COALESCE_SUCCESS, _G.ALERT_FRAME_COALESCE_CONTINUE = 1, 2
local originalCreate = _G.CreateFrame
local masksRemoved = 0
_G.CreateFrame = function(kind, name, parent, template)
    local frame = originalCreate(kind, name, parent, template)
    if template == "DungeonCompletionAlertFrameRewardTemplate" or template == "WorldQuestFrameRewardTemplate" then
        frame.texture, frame.CircleMask = frame:CreateTexture(), frame:CreateTexture()
        frame.ring = frame:CreateTexture()
        frame.ring:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-REWARDRING")
        frame.texture.masks = {[frame.CircleMask] = true}
        function frame.texture:RemoveMaskTexture(mask) self.masks[mask] = nil; masksRemoved = masksRemoved + 1 end
        function frame.texture:AddMaskTexture(mask) self.masks[mask] = true end
        function frame:CreateMaskTexture() local mask = self:CreateTexture(); mask.kind = "MaskTexture"; return mask end
        frame:SetScript("OnEnter", _G.DungeonCompletionAlertFrameReward_OnEnter)
        frame:SetScript("OnLeave", _G.DungeonCompletionAlertFrameReward_OnLeave)
        parent.RewardFrames = parent.RewardFrames or {}
        table.insert(parent.RewardFrames,frame)
    end
    return frame
end
local function alert()
    local f = env.NewFrame("Button")
    for _, key in ipairs({"raidArt","dungeonArt","dungeonTexture","shine","heroicIcon","BonusStar"}) do f[key] = f:CreateTexture() end
    f.glowFrame = env.NewFrame("Frame",nil,f); f.glowFrame.glow = f.glowFrame:CreateTexture()
    f.completionText, f.instanceName, f.dungeonName = f:CreateFontString(),f:CreateFontString(),f:CreateFontString()
    return f
end
local dungeon, scenario = alert(),alert()
_G.DungeonCompletionAlertSystem = {setUpFunction = _G.DungeonCompletionAlertFrame_SetUp,alertFramePool = {EnumerateActive = function() return next, {[dungeon] = true} end}}
_G.ScenarioAlertSystem = {setUpFunction = _G.ScenarioAlertFrame_SetUp,alertFramePool = {EnumerateActive = function() return next, {[scenario] = true} end}}
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI",env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
local rewards = {name = "Native name",subtypeID = 1,moneyAmount = 100,experienceGained = 0,numRewards = 1,
    rewards = {{texturePath = "native-epic",rewardID = 42,rewardItemLink = "epic-link"}},iconTextureFile = "native-dungeon"}
for _, system in ipairs({_G.DungeonCompletionAlertSystem,_G.ScenarioAlertSystem}) do
    local frame = system == _G.DungeonCompletionAlertSystem and dungeon or scenario
    system.setUpFunction(frame,rewards); env.RunTimers()
    assert(frame.rewardData == rewards and frame.numUsedRewardFrames == 2,"native reward payload and money/item count must survive")
    for index, reward in ipairs(frame.RewardFrames) do
        assert(reward.ring:GetAlpha() == 0,"completion reward ring must be suppressed")
        assert(not reward.texture.masks[reward.CircleMask],"native circular clip must not constrain rounded icons")
        local mask = skin.GetFrameData(reward.texture,"roundedIconMask")
        assert(mask and reward.texture.masks[mask],"reward art must have the shared QUI rounded mask")
        assert(reward:GetScript("OnEnter") == _G.DungeonCompletionAlertFrameReward_OnEnter
            and reward:GetScript("OnLeave") == _G.DungeonCompletionAlertFrameReward_OnLeave,"native tooltip/pause handlers must survive")
        local border = skin.GetFrameData(reward,"iconBorder")
        assert(border and border._quiRoundedSurface.radius == 4,"completion reward must use shared QUI icon border")
        if index == 2 then assert(border._quiBorderR == 0.64 and reward.texture.texture == "native-epic","native item art and epic rarity must survive") end
        assert(reward:GetPoint(1) == (index == 1 and "TOP" or "CENTER"),"native reward anchoring must survive")
    end
end
local removed = masksRemoved
local border = skin.GetFrameData(dungeon.RewardFrames[2],"iconBorder")
rewards.moneyAmount = 0; rewards.numRewards = 0
_G.DungeonCompletionAlertSystem.setUpFunction(dungeon,rewards);env.RunTimers()
assert(not dungeon.RewardFrames[1]:IsShown() and not dungeon.RewardFrames[2]:IsShown(),"pooled unused rewards must stay hidden")
dungeon.questID = 123
_G.WorldQuestCompleteAlertFrame_Coalesce(dungeon,123,"epic-link","coalesced-art")
assert(dungeon.numUsedRewardFrames == 1 and dungeon.RewardFrames[1].texture.texture == "coalesced-art"
    and skin.GetFrameData(dungeon.RewardFrames[1],"iconBorder")._quiBorderR == 0.64,"coalesced reward must be skinned without repeating parent setup")
rewards.moneyAmount = 100
_G.DungeonCompletionAlertSystem.setUpFunction(dungeon,rewards);env.RunTimers()
assert(skin.GetFrameData(dungeon.RewardFrames[1],"iconBorder")._quiBorderR ~= 0.64,"reused money reward must clear prior item rarity")
assert(masksRemoved == removed and skin.GetFrameData(dungeon.RewardFrames[2],"iconBorder") == border,"reuse must not recreate mask or border")
border._quiBorderR = 0.11
_G.QUI_RefreshAlertColors()
assert(border._quiBorderR == 0.64,"theme refresh must cover pooled alert-system child rewards and retain item quality")
env.profile.general.skinAlerts = false
local reward = dungeon.RewardFrames[1]
reward.ring:SetTexture("native-disabled");reward.ring:SetAlpha(1)
_G.StandardRewardAlertFrame_AdjustRewardAnchors(dungeon)
assert(reward.ring:GetAlpha() == 0,"already styled art remains clamped when skin disabled")
local untouched = alert()
_G.DungeonCompletionAlertFrame_SetUp(untouched,rewards)
assert(not skin.GetFrameData(untouched.RewardFrames[1],"iconBorder")
    and untouched.RewardFrames[1].ring:GetAlpha() == 1
    and untouched.RewardFrames[1].texture.masks[untouched.RewardFrames[1].CircleMask],
    "disabled skin must leave newly created native rewards untouched")
print("OK: alerts_completion_rewards_test")
