local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
env.profile.general.skinAlerts = true
local skin = env.SkinBase
local borderColor = {0.2, 0.3, 0.4, 1}
local backgroundColor = {0.05, 0.06, 0.07, 0.9}
local accent = {0.8, 0.1, 0.2}
skin.GetWindowColors = function() return unpack({borderColor[1], borderColor[2], borderColor[3], borderColor[4],
    backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4]}) end
skin.GetSkinColors = function() return unpack(accent) end
env.ns.Helpers.SetFrameBackdropBorderColor = function(frame, ...) frame:SetBackdropBorderColor(...) end
env.ns.Helpers.SetFrameBackdropColor = function(frame, ...) frame:SetBackdropColor(...) end
env.ns.Helpers.ApplyBarStyle = function() end
local frame = env.NewFrame("Frame")
_G.BonusRollFrame = frame
local prompt = env.NewFrame("Frame", nil, frame)
frame.PromptFrame = prompt
prompt.Icon = prompt:CreateTexture()
prompt.Icon:SetTexture("native-chest-art")
prompt.InfoFrame = env.NewFrame("Frame", nil, prompt)
prompt.InfoFrame.Label = prompt.InfoFrame:CreateFontString()
prompt.InfoFrame.Cost = prompt.InfoFrame:CreateFontString()
prompt.InfoFrame.Cost:SetText("1 |Tnative-currency:0|t")
prompt.Timer = env.NewFrame("StatusBar", nil, prompt)
prompt.Timer.GetStatusBarTexture = function() return nil end
prompt.Timer.SetStatusBarColor = function(owner, ...) owner.color = {...} end
local nativeClick, nativeEnter = function() end, function() end
for _, name in ipairs({"RollButton", "PassButton"}) do
    local button = env.NewFrame("Button", nil, prompt)
    prompt[name] = button
    button:SetScript("OnClick", nativeClick)
    button:SetScript("OnEnter", nativeEnter)
    button.normalTexture = button:CreateTexture()
    button.normalTexture:SetTexture(name .. "-native-art")
    button.highlightTexture = button:CreateTexture()
end
prompt.EncounterJournalLinkButton = env.NewFrame("Button", nil, prompt)
prompt.EncounterJournalLinkButton:SetScript("OnClick", nativeClick)
_G.BonusRollFrame_StartBonusRoll = function() end
_G.LootWonAlertFrame_SetUp = function() end
_G.C_Item.GetItemQualityByID = function(link) return link == "epic-item" and 4 or nil end
_G.C_Item.GetItemQualityColor = function() return 0.64, 0.21, 0.93 end
local loot = env.NewFrame("Button")
_G.BonusRollLootWonFrame = loot
loot.Icon = loot:CreateTexture()
loot.Icon:SetTexture("native-reward-art")
loot.hyperlink = "epic-item"
_G.BonusRollMoneyWonFrame = nil
assert(loadfile(os.getenv("QUI_ALERTS_SOURCE") or "modules/skinning/notifications/alerts.lua"))("QUI", env.ns)
env.ns.Addon.Alerts:HookAlertSystems()
_G.BonusRollFrame_StartBonusRoll()
_G.LootWonAlertFrame_SetUp(loot)
local lootBorder = skin.GetFrameData(loot, "iconBorder")
lootBorder._quiBorderR = 0.11
local rollBorder = skin.GetFrameData(prompt.RollButton, "backdrop")
local passBorder = skin.GetFrameData(prompt.PassButton, "backdrop")
assert(rollBorder and passBorder, "prompt controls must retain refreshable rounded borders")
borderColor = {0.4, 0.5, 0.6, 0.8}
backgroundColor = {0.1, 0.2, 0.3, 0.7}
accent = {0.2, 0.7, 0.9}
_G.QUI_RefreshAlertColors()
assert(lootBorder._quiBorderR == 0.64 and lootBorder._quiBorderB == 0.93,
    "standalone reward quality must refresh even when the money frame is absent")
local backdrop = skin.GetFrameData(frame, "backdrop")
assert(backdrop._quiBorderR == 0.4 and backdrop._quiBorderA == 0.8, "prompt shell must refresh theme border")
local bg = backdrop._quiRoundedSurface.background.color
assert(bg[1] == 0.1 and bg[4] == 0.7, "prompt shell must refresh theme background")
assert(prompt.Timer.color[1] == 0.2 and prompt.Timer.color[3] == 0.9, "native countdown must refresh accent color")
for _, name in ipairs({"RollButton", "PassButton"}) do
    local button = prompt[name]
    local border = skin.GetFrameData(button, "backdrop")
    assert(border._quiBorderR == 0.4 and border._quiBorderA == 0.8, "both action borders must refresh")
    assert(button.highlightTexture.color[1] == 0.2 and button.highlightTexture.color[3] == 0.9,
        "both action highlights must refresh accent")
    assert(button.normalTexture.texture == name .. "-native-art", "native action identifiers must survive")
    assert(button:GetScript("OnClick") == nativeClick and button:GetScript("OnEnter") == nativeEnter,
        "native actions and tooltip handlers must survive")
end
_G.BonusRollFrame_StartBonusRoll()
assert(skin.GetFrameData(prompt.RollButton, "backdrop") == rollBorder and skin.GetFrameData(prompt.PassButton, "backdrop") == passBorder,
    "repeated setup must reuse action borders")
assert(prompt.InfoFrame.Cost:GetText() == "1 |Tnative-currency:0|t", "native currency cost formatting must survive")
assert(prompt.Icon.texture == "native-chest-art" and prompt.EncounterJournalLinkButton:GetScript("OnClick") == nativeClick,
    "native chest artwork and journal navigation must survive")
print("OK: bonus_roll_theme_refresh_test")
