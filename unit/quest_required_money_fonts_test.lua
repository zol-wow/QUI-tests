local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinQuest = true
local function read(path) local f=assert(io.open(path));local s=f:read("*a");f:close();return s end
local native = read("tests/framexml/Interface/AddOns/Blizzard_MoneyFrame/Shared/MoneyFrame.lua")
local fontNames = {"NumberFontNormalRight", "NumberFontNormalLargeRight",
    "UserScaledFontNumberNormalRight"}
for _, prefix in ipairs(fontNames) do
    for _, suffix in ipairs({"", "Yellow", "Red", "Gray", "Green"}) do
        _G[prefix .. suffix] = {name = prefix .. suffix, color = suffix == "Red" and {1,.1,.1,1} or {1,1,1,1}}
    end
end
local body = assert(native:match("(local MONEY_FRAME_FONT_SMALL = true;.-\nend)"))
local getFont, colorByFrame = assert(loadstring(body .. "\n" .. assert(native:match("(function SetMoneyFrameColorByFrame%b().-\nend)")) .. "\nreturn GetMoneyFrameFont, SetMoneyFrameColorByFrame"))()
_G.SetMoneyFrameColorByFrame = colorByFrame
for _, name in ipairs({"GetMoneyFrame", "SetMoneyFrameColor"}) do
    assert(loadstring(assert(native:match("(function " .. name .. "%b().-\nend)"))))()
end
local root = env.NewFrame("Frame", "QuestFrame"); root.CloseButton = false; root.FriendshipStatusBar = false
_G.QuestFrame = root; _G.QuestInfoTitleHeader = root:CreateFontString()
_G.QuestInfoFrame = {rewardsFrame = env.NewFrame("Frame", nil, root)}
local money = env.NewFrame("Frame", "QuestProgressRequiredMoneyFrame", root)
money.RegisterForWidgetSet = false; money.small = true; money.isUserScaled = false
_G.QuestProgressRequiredMoneyFrame = money
local function denomination(key, amount)
    local b = env.NewFrame("Button", nil, money); b.RegisterForWidgetSet = false; b.DisabledTexture = false
    money[key .. "Button"] = b
    local fs = b:CreateFontString(); fs:SetText(amount)
    function b:GetFontString() return fs end
    local art = b:CreateTexture(); art:SetAtlas("coin-" .. key); art:SetAlpha(.7); b.coin = art
    function b:SetNormalFontObject(font)
        self.nativeFont = font; self.setterCalls = (self.setterCalls or 0) + 1
        fs:SetFont(font.name, 12, ""); fs:SetTextColor(unpack(font.color))
    end
    return b, fs
end
local gold, amount = denomination("Gold", "12")
denomination("Silver", "34"); denomination("Copper", "56")
_G.SetMoneyFrameColor(money:GetName(), "red")
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = {Register = function(_, key, entry) registry[key] = entry end}
assert(loadfile(arg[1] or "modules/skinning/frames/interaction.lua"))("QUI", ns)
callbacks.Blizzard_UIPanels_Game()
assert(amount.font == "QUIFont.ttf" and amount.textColor[2] == .1, "required money must retain native red amount with QUI typography")
local calls = gold.setterCalls
_G.SetMoneyFrameColor(money:GetName(), "white")
assert(amount.font == "QUIFont.ttf" and amount.textColor[2] == 1 and gold.setterCalls == calls + 1,
    "native money font-object reset must retain QUI font and white amount without duplicate native setter")
money.isUserScaled = true
_G.SetMoneyFrameColor(money, "red")
assert(gold.nativeFont == getFont(money, "red") and amount.font == "QUIFont.ttf" and amount.textColor[2] == .1,
    "user-scaled native red font selection must preserve semantic color and QUI font")
money:Hide(); registry.skinQuest.refresh()
assert(not money:IsShown() and amount:GetText() == "12" and gold.coin.atlas == "coin-Gold" and gold.coin:GetAlpha() == .7,
    "theme must preserve native amount, denomination artwork/opacity and hidden visibility")
env.profile.general.skinQuest = false
_G.SetMoneyFrameColor(money, "red")
assert(amount.font == gold.nativeFont.name, "disabled existing money must stop font overrides")
env.profile.general.skinQuest = true; root.IsForbidden = function() return true end
_G.SetMoneyFrameColor(money, "white")
assert(amount.font == gold.nativeFont.name, "forbidden root must stop existing money font overrides")
root.IsForbidden = function() return false end
local other = env.NewFrame("Frame", nil, root); other.RegisterForWidgetSet = false
_G.QuestProgressRequiredMoneyFrame = other
env.profile.general.skinQuest = false; local fs = other:CreateFontString(); fs:SetFont("Native", 12, "")
registry.skinQuest.refresh(); assert(fs.font == "Native", "disabled fresh money must remain native")
env.profile.general.skinQuest = true; other.IsForbidden = function() return true end
registry.skinQuest.refresh(); assert(fs.font == "Native", "forbidden money must remain native")
other.IsForbidden = function() return false end; other.parent = _G.UIParent
registry.skinQuest.refresh(); assert(fs.font == "Native", "nonquest money must retain its presentation")
print("Quest required-money native font resets passed")
