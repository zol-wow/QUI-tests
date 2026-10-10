local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local source = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
_G.QuestInfoReputationRewardButtonMixin = {}
for _, method in ipairs({"SetUpMajorFactionReputationReward", "OnEnter", "OnLeave"}) do
    assert(loadstring(assert(source:match("(function QuestInfoReputationRewardButtonMixin:" .. method .. "%b().-\nend)"))))()
end
_G.QUEST_REPUTATION_REWARD_TITLE = "%s reputation"
_G.QUEST_REPUTATION_REWARD_TOOLTIP = "%d reputation with %s"
_G.MAJOR_FACTION_REPUTATION_REWARD_ICON_FORMAT = "Interface/MajorFactions/%s"
_G.REPUTATION_TOOLTIP_ACCOUNT_WIDE_LABEL = "Account wide"
_G.HIGHLIGHT_FONT_COLOR = {}; _G.ACCOUNT_WIDE_FONT_COLOR = {}
_G.AbbreviateNumbers = function(amount) return amount >= 1000 and (amount / 1000) .. "k" or tostring(amount) end
_G.C_MajorFactions = { GetMajorFactionData = function(id) return { name = "Faction " .. id, factionID = id, textureKit = "kit" .. id } end }
_G.C_Reputation = { IsAccountWideReputation = function(id) return id == 1 end }
local tooltip = { SetOwner = function(self, owner) self.owner = owner; self.lines = {} end,
    Show = function(self) self.shown = true end }
_G.GameTooltip = tooltip
_G.GameTooltip_SetTitle = function(t, text) t.title = text end
_G.GameTooltip_AddColoredLine = function(t, text) t.lines[#t.lines + 1] = text end
_G.GameTooltip_AddNormalLine = function(t, text) t.lines[#t.lines + 1] = text end
_G.GameTooltip_Hide = function() tooltip.shown = false end
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}
_G.QuestInfoFrame = { rewardsFrame = rewards }
local active, released, masks = {}, {}, 0
local pool = {}; rewards.reputationRewardPool = pool
function pool:EnumerateActive() return pairs(active) end
function pool:Acquire()
    local b = table.remove(released); local isNew = b == nil
    if not b then
        b = env.NewFrame("Button", nil, rewards); b.DisabledTexture = false; b:RegisterForClicks("LeftButtonUp")
        b:SetSize(147, 41)
        b.Icon = b:CreateTexture(); b.Icon:SetSize(39, 39); b.Icon:SetTexCoord(.1, .9, .2, .8)
        b.NameFrame = b:CreateTexture(); b.NameFrame:SetTexture("native-reputation-nameplate")
        function b.NameFrame:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
        b.Name = b:CreateFontString()
        b.RewardAmount = b:CreateFontString(); b.RewardAmount:SetTextColor(.3, 1, .4)
        function b:CreateMaskTexture() masks = masks + 1; return env.NewTexture(self, "MaskTexture") end
        function b.Icon:AddMaskTexture(mask) self.mask = mask end
        b.SetUpMajorFactionReputationReward = _G.QuestInfoReputationRewardButtonMixin.SetUpMajorFactionReputationReward
        b:SetScript("OnEnter", _G.QuestInfoReputationRewardButtonMixin.OnEnter)
        b:SetScript("OnLeave", _G.QuestInfoReputationRewardButtonMixin.OnLeave)
    end
    active[b] = b; return b, isNew
end
function pool:ReleaseAll()
    for b in pairs(active) do b:Hide(); active[b] = nil; released[#released + 1] = b end
end
local originalHook = _G.hooksecurefunc
_G.hooksecurefunc = function(target, method, callback)
    if target == pool and method == "Acquire" then
        local acquire = target[method]
        target[method] = function(...) local b, isNew = acquire(...); callback(...); return b, isNew end
    else originalHook(target, method, callback) end
end
local function reward(id, amount)
    local b = pool:Acquire(); b:SetUpMajorFactionReputationReward({factionID = id, rewardAmount = amount}); b:Show(); return b
end
local first = reward(1, 3400)
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
local function check(b, id, text)
    assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface,
        "pooled reputation rewards must receive rounded chrome")
    assert(b.NameFrame:GetAlpha() == 0 and b.Icon.texture == "Interface/MajorFactions/kit" .. id
        and b.Icon.texCoord[1] == .1 and b.Icon.texCoord[3] == .2 and b.Icon.mask,
        "native faction art and UVs must remain while nameplate decoration is suppressed")
    assert(b.RewardAmount:GetText() == text and b.RewardAmount.textColor[1] == .3 and b:GetWidth() == 147,
        "native reward amount, semantic color and row geometry must remain")
end
check(first, 1, "3.4k")
first:Fire("OnEnter")
assert(tooltip.owner == first and tooltip.title == "Faction 1 reputation" and tooltip.lines[1] == "Account wide"
    and tooltip.lines[2] == "3400 reputation with Faction 1", "native account-wide tooltip must remain")
first:Fire("OnLeave"); assert(not tooltip.shown)
local second = reward(2, 250); check(second, 2, "250")
second:Fire("OnEnter")
assert(#tooltip.lines == 1 and tooltip.lines[1] == "250 reputation with Faction 2",
    "native character-only tooltip must omit account-wide label")
local backdrop = skin.GetBackdrop(first)
pool:ReleaseAll()
local reused = reward(2, 500); check(reused, 2, "500")
registry.skinQuest.refresh()
assert(masks == 2 and skin.GetBackdrop(first) == backdrop, "theme/pool reuse must retain cached surfaces")
reward(1, 100)
env.profile.general.skinQuest = false
local fresh = reward(3, 200)
assert(not skin.GetBackdrop(fresh) and fresh.NameFrame:GetAlpha() == 1, "disabled fresh reputation reward must remain native")
env.profile.general.skinQuest = true; root.IsForbidden = function() return true end
local forbidden = reward(4, 300)
assert(not skin.GetBackdrop(forbidden), "forbidden root must exclude reputation reward acquisition")
print("Quest pooled reputation reward native methods passed")
