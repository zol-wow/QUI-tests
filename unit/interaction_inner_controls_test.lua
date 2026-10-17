local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
for _, key in ipairs({ "skinBank", "skinGuildBank", "skinTrainer" }) do env.profile.general[key] = true end
local function button(parent)
    local b = env.NewFrame("Button", nil, parent)
    b.DisabledTexture = false
    return b
end
_G.BankFrame = env.NewFrame("Frame")
local bank = _G.BankFrame
bank.TabSystem = false
bank.BankItemSearchBox = env.NewFrame("EditBox", nil, bank)
bank.BankPanel = env.NewFrame("Frame", nil, bank)
local panel = bank.BankPanel
panel.NineSlice, panel.EdgeShadows, panel.TabSettingsMenu = false, false, false
panel.Prompts = {}
panel.MoneyFrame = env.NewFrame("Frame", nil, panel)
panel.MoneyFrame.Border = false
panel.MoneyFrame.WithdrawButton = button(panel.MoneyFrame)
panel.MoneyFrame.DepositButton = button(panel.MoneyFrame)
panel.AutoDepositFrame = env.NewFrame("Frame", nil, panel)
panel.AutoDepositFrame.DepositButton = button(panel.AutoDepositFrame)
panel.AutoDepositFrame.IncludeReagentsCheckbox = env.NewFrame("CheckButton", nil, panel.AutoDepositFrame)
local deposit = function() end
panel.AutoDepositFrame.DepositButton:SetScript("OnClick", deposit)
_G.GuildBankFrame = env.NewFrame("Frame")
local guild = _G.GuildBankFrame
guild.DepositButton, guild.WithdrawButton = button(guild), button(guild)
guild.BuyInfo, guild.Info, guild.Log, guild.MoneyFrameBG = false, false, false, false
_G.ClassTrainerFrame = env.NewFrame("Frame")
local trainer = _G.ClassTrainerFrame
trainer.FilterDropdown = env.NewFrame("DropdownButton", nil, trainer)
trainer.FilterDropdown.DisabledTexture = false
trainer.ScrollBar, trainer.bottomInset, trainer.BG, trainer.ScrollBox = false, false, false, false
_G.ClassTrainerTrainButton = button(trainer)
local train = function() end
_G.ClassTrainerTrainButton:SetScript("OnClick", train)
_G.ClassTrainerFrame_InitServiceButton = function() end
env.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
assert(loadfile(os.getenv("QUI_INTERACTION_SOURCE") or "modules/skinning/frames/interaction.lua"))("QUI", env.ns)
assert(env.SkinBase.GetBackdrop(panel.AutoDepositFrame.DepositButton)._quiRoundedSurface,
    "bank auto-deposit action must use rounded controls")
assert(env.SkinBase.GetBackdrop(guild.WithdrawButton)._quiRoundedSurface,
    "guild-bank money actions must use rounded controls")
assert(env.SkinBase.GetBackdrop(trainer.FilterDropdown)._quiRoundedSurface,
    "trainer filter must use rounded controls")
assert(env.SkinBase.GetBackdrop(_G.ClassTrainerTrainButton)._quiRoundedSurface,
    "train action must use rounded controls")
assert(panel.AutoDepositFrame.DepositButton:GetScript("OnClick") == deposit
    and _G.ClassTrainerTrainButton:GetScript("OnClick") == train, "native transaction ownership must survive styling")
local row = button(trainer)
row.icon = row:CreateTexture()
row.icon:SetTexture("profession-art")
row.name, row.subText = row:CreateFontString(), row:CreateFontString()
row.name:SetTextColor(1, 0.1, 0.1, 1)
row.lock, row.disabledBG, row.selectedTex = false, false, false
_G.ClassTrainerFrame_InitServiceButton(row)
assert(env.SkinBase.GetBackdrop(row)._quiRoundedSurface and row.icon:GetAlpha() == 1,
    "pooled trainer rows must use QUI surfaces and preserve service icons")
assert(select(2, row.name:GetTextColor()) == 0.1, "trainer availability text must retain its semantic color")
print("OK: interaction_inner_controls_test")
