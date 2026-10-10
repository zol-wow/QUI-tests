local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local native = read("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua")
local body = assert(native:match("(local function QuestInfo_ShowRewardAsItemCommon%b().-\nend)"))
local populate = assert(loadstring(body:gsub("local function QuestInfo_ShowRewardAsItemCommon", "return function", 1)))()
local itemSource = read("tests/framexml/Interface/AddOns/Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua")
assert(loadstring(assert(itemSource:match("(function SetItemButtonNameFrameVertexColor%b().-\nend)"))))()
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root
_G.QuestInfoTitleHeader = root:CreateFontString()
local rewards = env.NewFrame("Frame", nil, root)
_G.QuestInfoFrame = { rewardsFrame = rewards, questLog = false }
local function button(parent)
    local b = env.NewFrame("Button", nil, parent); b.DisabledTexture = false; b.type = "reward"
    b.Icon = b:CreateTexture(); b.IconBorder = b:CreateTexture()
    b.NameFrame = b:CreateTexture(); b.NameFrame:SetTexture("Interface/QuestFrame/UI-QuestItemNameFrame")
    b.NameFrame:SetSize(128, 64); b.NameFrame:SetPoint("LEFT", b.Icon, "RIGHT", -10, 0)
    b.Name = b:CreateFontString(); b.Count = b:CreateFontString(); b.Count:SetTextColor(1, .2, .1, 1)
    function b.NameFrame:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
    function b.IconBorder:GetVertexColor() return unpack(self.vertex or {1, 1, 1, 1}) end
    function b:CreateMaskTexture() return env.NewTexture(self, "MaskTexture") end
    function b.Icon:AddMaskTexture(mask) self.mask = mask end
    function b:UpdateQuestRewardContextFlags(flags) self.flags = flags end
    b:SetScript("OnClick", function() error("quest reward must not be selected by styling") end)
    return b
end
local b = button(rewards); rewards.RewardButtons = {b}
local quality = {.7, .2, 1, 1}
_G.SetItemButtonQuality = function(target)
    target.IconBorder:SetVertexColor(unpack(quality)); target.IconBorder:Show()
end
_G.SetItemButtonTexture = function(target, texture) target.Icon:SetTexture(texture) end
_G.SetItemButtonCount = function(target, amount) target.Count:SetText(amount) end
_G.SetItemButtonTextureVertexColor = function(target, ...) target.Icon:SetVertexColor(...) end
local usable, itemID = false, 42
_G.GetQuestItemInfo = function() return "Reward", 1234, 2, 4, usable, itemID, 7 end
_G.GetQuestItemLink = function() return "item:42" end
local pending
_G.Item = { CreateFromItemID = function(_, id)
    assert(id == itemID)
    return { ContinueOnItemLoad = function(_, fn) pending = fn end }
end }
local acquisition = assert(native:match("(local function ResetRewardButton%b().-\nend\n\nfunction QuestInfo_GetRewardButton%b().-\nend)"))
assert(loadstring(acquisition))()
local factory, created = _G.CreateFrame, 0
_G.CreateFrame = function(kind, name, parent, template)
    if template == "QuestRewardFixture" then
        assert(kind == "BUTTON" and parent == rewards and name == "$parentQuestInfoItem2",
            "native reward factory arguments must remain")
        created = created + 1
        return button(parent)
    end
    return factory(kind, name, parent, template)
end
rewards.buttonTemplate = "QuestRewardFixture"
local originalHook = _G.hooksecurefunc
_G.hooksecurefunc = function(target, method, callback)
    if target == "QuestInfo_GetRewardButton" then
        local nativeAcquire, postHook = _G[target], method
        _G[target] = function(...)
            local acquired = nativeAcquire(...)
            postHook(...)
            return acquired
        end
    else
        originalHook(target, method, callback)
    end
end
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
local click = b:GetScript("OnClick")
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
assert(b.NameFrame:GetAlpha() == 0, "Quest reward native nameplate art must be suppressed")
b.currencyInfo = {old = true}; b.flags = 99
assert(_G.QuestInfo_GetRewardButton(rewards, 1) == b and b.currencyInfo == nil and b.flags == nil and created == 0,
    "native existing reward reset/return identity must survive acquisition styling")
local acquired = _G.QuestInfo_GetRewardButton(rewards, 2)
assert(acquired == rewards.RewardButtons[2] and created == 1 and skin.GetBackdrop(acquired)
    and acquired.NameFrame:GetAlpha() == 0,
    "native newly created reward must receive QUI chrome after factory/reset")
acquired.currencyInfo = {old = true}; acquired.flags = 88
assert(_G.QuestInfo_GetRewardButton(rewards, 2) == acquired and created == 1
    and acquired.currencyInfo == nil and acquired.flags == nil,
    "native reward reuse must preserve identity and clear currency/context without allocating")
local rowBorder = skin.GetBackdrop(b)
local iconBorder = skin.GetFrameData(b.Icon, "iconBorder")
populate(b, 1, function() error("non-log branch expected") end)
assert(pending and b.flags == 7 and b.objectType == "item", "native deferred reward setup must remain")
pending()
assert(rowBorder._quiBorderR == .9 and rowBorder._quiBorderG == 0 and iconBorder._quiBorderR == .7,
    "unusable row border and item-quality icon border must remain independent")
assert(b.Icon.texture == 1234 and b.Icon.vertex[1] == .9 and b.Count:GetText() == 2
    and b.Count.textColor[2] == .2 and b.Name:GetText() == "Reward", "native reward art/count/text colors must remain")
usable = true; populate(b, 1); pending()
assert(rowBorder._quiBorderR == env.colors[1] and b.Icon.vertex[2] == 1,
    "native usable reuse must reset row warning without losing item quality")
_G.SetItemButtonNameFrameVertexColor(b, .9, 0, 0)
registry.skinQuest.refresh()
assert(rowBorder._quiBorderR == .9 and iconBorder._quiBorderR == .7 and b.NameFrame:GetAlpha() == 0,
    "theme refresh must preserve row usability and independent quality")
b.NameFrame:Hide()
assert(rowBorder._quiBorderR == env.colors[1], "hidden nameplate must stop row warning")
b.NameFrame:Show(); b.NameFrame:SetAlpha(1)
assert(rowBorder._quiBorderR == .9 and b.NameFrame:GetAlpha() == 0 and b.NameFrame:GetWidth() == 128,
    "native show/alpha reuse must retain state and anchor geometry")
assert(b:GetScript("OnClick") == click, "native reward selection ownership must remain")
env.profile.general.skinQuest = false
local fresh = button(rewards); rewards.RewardButtons[2] = fresh
_G.QuestInfo_GetRewardButton(rewards, 2)
assert(not skin.GetBackdrop(fresh) and fresh.NameFrame:GetAlpha() == 1,
    "disabled reward acquisition must leave new controls untouched")
env.profile.general.skinQuest = true
fresh.IsForbidden = function() return true end
_G.QuestInfo_GetRewardButton(rewards, 2)
assert(not skin.GetBackdrop(fresh), "forbidden reward acquisition must remain native")
local unrelated = button(_G.UIParent); rewards.RewardButtons[3] = unrelated
_G.QuestInfo_GetRewardButton(rewards, 3)
assert(not skin.GetBackdrop(unrelated), "non-quest reward ownership must remain native")
print("Quest reward nameplate native lifecycle passed")
