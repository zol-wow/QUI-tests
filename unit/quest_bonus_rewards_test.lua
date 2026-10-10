local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local native = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
local function compile(pattern, parameters)
    return assert(loadstring("return function(" .. parameters .. ") " .. assert(native:match(pattern)) .. " end"))()
end
local honor = compile("rewardsFrame.HonorFrame:ClearAllPoints%b().-rewardsFrame.HonorFrame:Hide%b();?%s*end",
    "rewardsFrame, honor, BeginRewardsSection, AddRewardElement")
local skill = compile("if skillPoints then.-rewardsFrame.SkillPointFrame:Hide%b();?%s*end",
    "rewardsFrame, skillPoints, skillIcon, skillName, AddRewardElement")
local artifact = compile("rewardsFrame.ArtifactXPFrame:ClearAllPoints%b().-rewardsFrame.ArtifactXPFrame:Hide%b();?%s*end",
    "rewardsFrame, artifactXP, artifactCategory, AddRewardElement")
local warmode = compile("if hasWarModeBonus and C_PvP.IsWarModeDesired%b() then.-\n\t\tend",
    "rewardsFrame, hasWarModeBonus, AddRewardElement")
_G.C_PvP = {IsWarModeDesired = function() return true end, GetWarModeRewardBonus = function() return 10 end}
_G.PLUS_PERCENT_FORMAT = "+%d%%"
_G.BreakUpLargeNumbers = tostring; _G.format = string.format
_G.BONUS_SKILLPOINTS = "%s skill"; _G.BONUS_SKILLPOINTS_TOOLTIP = "%d %s skill points"
_G.HONOR = "Honor"; _G.PLAYER_FACTION_GROUP = {[0] = "Horde"}
local faction = "Horde"; _G.UnitFactionGroup = function() return faction end
_G.C_ArtifactUI = {GetArtifactXPRewardTargetInfo = function() return "Artifact", 777 end}
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}
_G.QuestInfoFrame = {rewardsFrame = rewards}
local masks = 0
for _, key in ipairs({"HonorFrame", "ArtifactXPFrame", "WarModeBonusFrame", "SkillPointFrame"}) do
    local b = env.NewFrame("Button", nil, rewards); rewards[key] = b
    b.DisabledTexture = false; b:SetSize(147, 41)
    b.Icon = b:CreateTexture(); b.Icon:SetSize(39, 39); b.Icon:SetTexCoord(0, 1, 0, 1)
    b.NameFrame = b:CreateTexture()
    function b.NameFrame:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
    b.Name = b:CreateFontString(); b.Count = b:CreateFontString(); b.ValueText = b:CreateFontString()
    for _, label in ipairs({b.Name, b.Count, b.ValueText}) do
        function label:SetFormattedText(pattern, ...) self:SetText(string.format(pattern, ...)) end
    end
    b.ValueText:SetTextColor(.3, 1, .4)
    function b:CreateMaskTexture() masks = masks + 1; return env.NewTexture(self, "MaskTexture") end
    function b.Icon:AddMaskTexture(mask) self.mask = mask end
    b:SetScript("OnClick", function() error("styling must not invoke reward action") end)
end
local ap = rewards.ArtifactXPFrame; ap.Overlay = ap:CreateTexture(); ap.Overlay:SetTexture("ArtifactPower-QuestBorder"); ap.Overlay:SetAlpha(.65)
local sp = rewards.SkillPointFrame
sp.CircleBackground = sp:CreateTexture(); sp.CircleBackgroundGlow = sp:CreateTexture(); sp.CircleBackgroundGlow:SetAlpha(.3)
local xp = env.NewFrame("Frame", nil, rewards); rewards.XPFrame = xp; xp.RegisterForWidgetSet = false
xp.ReceiveText = xp:CreateFontString(); xp.ReceiveText:SetText("Experience:"); xp.ReceiveText:SetTextColor(0, 0, 0)
xp.ValueText = xp:CreateFontString(); xp.ValueText:SetText("12345"); xp.ValueText:SetTextColor(1, .2, .1)
local money = env.NewFrame("Frame", nil, rewards); rewards.MoneyFrame = money; money.RegisterForWidgetSet = false
for _, key in ipairs({"GoldButton", "SilverButton", "CopperButton"}) do
    local b = env.NewFrame("Button", nil, money); money[key] = b; b.RegisterForWidgetSet = false
    b.Text = b:CreateFontString(); b.Text:SetText("12"); b.Text:SetTextColor(1, .1, .1)
    b.normalTexture = b:CreateTexture(); b.normalTexture:SetAtlas("coin-" .. key); b.normalTexture:SetAlpha(.8)
end
local layouts = 0
local function layout(frame) layouts = layouts + 1; frame:Show() end
honor(rewards, 500, function() end, layout)
skill(rewards, 2, 888, "Alchemy", layout)
artifact(rewards, 1000, 1, layout)
local xml = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.xml")
local template = assert(xml:match('<Button name="WarModeBonusFrameTemplate".-</Button>'))
local onload = assert(loadstring("return function(self) " .. assert(template:match("<OnLoad>(.-)</OnLoad>")) .. " end"))()
_G.WAR_MODE_BONUS = "War Mode bonus"; _G.GREEN_FONT_COLOR = {GetRGB = function() return .3, 1, .4 end}
_G.SetItemButtonTexture = function(b, texture) b.Icon:SetTexture(texture) end
onload(rewards.WarModeBonusFrame)
warmode(rewards, true, layout)
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
local click = rewards.HonorFrame:GetScript("OnClick")
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
for _, key in ipairs({"HonorFrame", "ArtifactXPFrame", "WarModeBonusFrame", "SkillPointFrame"}) do
    local b = rewards[key]
    assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface and b.NameFrame:GetAlpha() == 0,
        "bonus reward cards must receive shared rounded chrome")
    assert(b.Icon.mask and b.Icon.texCoord[1] == 0 and b:GetWidth() == 147, "bonus artwork UVs and row geometry must remain")
end
assert(ap.Overlay:GetAlpha() == .65 and sp.CircleBackground:GetAlpha() == 1 and sp.CircleBackgroundGlow:GetAlpha() == .3,
    "functional artifact overlay and skill badge must remain")
assert(sp.ValueText:GetText() == 2 and sp.Name:GetText() == "Alchemy skill" and sp.tooltip == "2 Alchemy skill points",
    "native skill values/name/tooltip must remain")
assert(rewards.WarModeBonusFrame.Count:GetText() == "+10%", "native War Mode percentage must remain")
assert(rewards.WarModeBonusFrame.Name.textColor[2] == 1 and rewards.WarModeBonusFrame.Count.textColor[1] == .3,
    "native War Mode green semantics must remain")
assert(xp.ReceiveText.textColor[1] == .92 and xp.ValueText:GetText() == "12345" and xp.ValueText.textColor[2] == .2,
    "static XP caption must become neutral while XP amount/color remain")
for _, key in ipairs({"GoldButton", "SilverButton", "CopperButton"}) do
    assert(money[key].normalTexture:GetAlpha() == .8 and money[key].Text:GetText() == "12" and money[key].Text.textColor[2] == .1,
        "native money coin art, values and red state must remain")
end
faction = "Alliance"; honor(rewards, 750, function() end, layout)
assert(rewards.HonorFrame.Icon.texture == "Interface\\Icons\\PVPCurrency-Honor-Alliance" and rewards.HonorFrame.Count:GetText() == "750")
honor(rewards, 0, function() end, layout); skill(rewards, nil, nil, nil, layout); artifact(rewards, 0, 1, layout)
local count = layouts; registry.skinQuest.refresh()
assert(not rewards.HonorFrame:IsShown() and not sp:IsShown() and not ap:IsShown() and layouts == count and masks == 4,
    "native zero/absent visibility and cached surfaces must survive theme")
assert(rewards.HonorFrame:GetScript("OnClick") == click, "native reward action ownership must remain")
env.profile.general.skinQuest = false
local fresh = env.NewFrame("Button", nil, rewards); rewards.HonorFrame = fresh
registry.skinQuest.refresh(); assert(not skin.GetBackdrop(fresh), "disabled fresh bonus reward must remain native")
env.profile.general.skinQuest = true; fresh.IsForbidden = function() return true end
registry.skinQuest.refresh(); assert(not skin.GetBackdrop(fresh), "forbidden bonus reward must remain native")
print("Quest bonus reward native branches passed")
