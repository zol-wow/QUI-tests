local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local native = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
_G.QuestInfoRewardSpellCodeMixin = {}
for _, method in ipairs({"OnEnter", "OnLeave", "OnClick"}) do
    assert(loadstring(assert(native:match("(function QuestInfoRewardSpellCodeMixin:" .. method .. "%b().-\nend)"))))()
end
local assignment = assert(native:match("(local spellRewardFrame = rewardsFrame.spellRewardPool:Acquire%b().-spellRewardFrame:Show%b())"))
local populate = assert(loadstring("return function(rewardsFrame, spellInfo) " .. assignment .. " return spellRewardFrame end"))()
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root); rewards.RewardButtons = {}
_G.QuestInfoFrame = { rewardsFrame = rewards }
local active, created, masks = {}, {}, 0
local pool = {}; rewards.spellRewardPool = pool
function pool:EnumerateActive() return pairs(active) end
function pool:Acquire()
    local b = table.remove(created)
    local isNew = b == nil
    if not b then
        b = env.NewFrame("Button", "QuestSpell" .. (#env.frames + 1), rewards)
        b.DisabledTexture = false; b.RegisterForWidgetSet = false; b:SetSize(147, 41)
        b.Icon = b:CreateTexture(); b.Icon:SetSize(39, 39)
        b.Name = b:CreateFontString(); b.Name:SetTextColor(1, .82, 0)
        b.NameFrame = b:CreateTexture(); b.NameFrame:SetTexture("native-quest-nameplate")
        function b.NameFrame:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
        b.spellBorder = b:CreateTexture(); b.spellBorder:SetTexture("Interface/Spellbook/Spellbook-Parts")
        function b.spellBorder:GetName() return "NativeSpellBorder" end
        b.extra = b:CreateTexture(); b.extra:SetTexture("functional-extra")
        function b.extra:GetName() return "NativeExtra" end
        function b:CreateMaskTexture() masks = masks + 1; return env.NewTexture(self, "MaskTexture") end
        function b.Icon:AddMaskTexture(mask) self.mask = mask end
        for _, script in ipairs({"OnEnter", "OnLeave", "OnClick"}) do
            b:SetScript(script, _G.QuestInfoRewardSpellCodeMixin[script])
        end
    end
    active[b] = b
    return b, isNew
end
function pool:ReleaseAll()
    for b in pairs(active) do b:Hide(); active[b] = nil; created[#created + 1] = b end
end
local originalHook = _G.hooksecurefunc
_G.hooksecurefunc = function(target, method, callback)
    if target == pool and method == "Acquire" then
        local acquire = target[method]
        target[method] = function(...)
            local frame, isNew = acquire(...)
            callback(...)
            return frame, isNew
        end
    else
        originalHook(target, method, callback)
    end
end
local tooltip = { SetOwner = function(self, owner) self.owner = owner end,
    SetSpellByID = function(self, id) self.id = id end, Hide = function(self) self.hidden = true end }
_G.GameTooltip = tooltip
local resets, links = 0, 0
_G.ResetCursor = function() resets = resets + 1 end
_G.IsModifiedClick = function() return false end
_G.ChatFrameUtil = { InsertLink = function() links = links + 1 end }
_G.C_Spell = { GetSpellLink = function() error("ordinary spell click must not request a chat link") end }
local first = populate(rewards, { texture = 123, name = "First spell", spellID = 10 })
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
local function check(b, id)
    assert(skin.GetBackdrop(b) and skin.GetBackdrop(b)._quiRoundedSurface,
        "pooled spell rewards must receive rounded row chrome")
    assert(b.NameFrame:GetAlpha() == 0 and b.spellBorder:GetAlpha() == 0 and b.extra:GetAlpha() == 1,
        "exact spell/name decoration must be suppressed while other art remains")
    assert(b.Icon:GetAlpha() == 1 and b.Icon.mask and b.rewardSpellID == id and b:GetWidth() == 147,
        "native spell artwork, identity and geometry must remain")
end
check(first, 10)
local second = populate(rewards, { texture = 456, name = "Second spell", spellID = 20 }); check(second, 20)
second:Fire("OnEnter"); assert(tooltip.owner == second and tooltip.id == 20)
second:Fire("OnLeave"); second:Fire("OnClick")
assert(resets == 1 and tooltip.hidden and links == 0, "native tooltip/cursor and ordinary click must remain")
local click = second:GetScript("OnClick"); local backdrop = skin.GetBackdrop(second)
pool:ReleaseAll()
local reused = populate(rewards, { texture = 789, name = "Reused spell", spellID = 30 }); check(reused, 30)
registry.skinQuest.refresh()
assert(masks == 2 and skin.GetBackdrop(second) == backdrop and second:GetScript("OnClick") == click,
    "pool/theme reuse must preserve masks, surfaces and native callbacks")
assert(reused.Name:GetText() == "Reused spell" and reused.Icon.texture == 789 and reused:IsShown(),
    "native population after acquisition must retain updated art and text")
local remaining = populate(rewards, { texture = 790, name = "Remaining spell", spellID = 31 }); check(remaining, 31)
env.profile.general.skinQuest = false
local fresh = populate(rewards, { texture = 999, name = "Fresh spell", spellID = 40 })
assert(not skin.GetBackdrop(fresh) and fresh.spellBorder:GetAlpha() == 1,
    "disabled spell acquisition must remain native")
env.profile.general.skinQuest = true
root.IsForbidden = function() return true end
local forbidden = populate(rewards, { texture = 1000, name = "Forbidden root spell", spellID = 41 })
assert(not skin.GetBackdrop(forbidden) and forbidden.spellBorder:GetAlpha() == 1,
    "forbidden quest root must exclude pooled spell styling")
print("Quest pooled spell rewards passed")
