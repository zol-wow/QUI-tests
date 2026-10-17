local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local skin, ns = env.SkinBase, env.ns
env.profile.general.skinStable = true
env.profile.general.applyGlobalFontToBlizzard = true
ns.Client = { isForever = true }
local function read(path)
    local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local corpus = "tests/clients/forever/framexml/Interface/AddOns/"
local borderSource = read(corpus .. "Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua")
_G.ContainerFrameCurrencyBorderMixin = {}
for _, method in ipairs({"OnLoad", "SetupPiece"}) do
    assert(loadstring(assert(borderSource:match("(function ContainerFrameCurrencyBorderMixin:" .. method .. "%b().-\nend)"))))()
end
assert(loadfile(corpus .. "Blizzard_StableUI/Camelot/Blizzard_StableUI.lua"))()
local root = env.NewFrame("Frame"); root.CloseButton = false
_G.PetStableFrame = root
local wallet = env.NewFrame("Frame", "PetStableMoneyFrame", root)
local cost = env.NewFrame("Frame", "PetStableCostMoneyFrame", root)
_G.PetStableMoneyFrame = wallet; _G.PetStableCostMoneyFrame = cost
for _, money in ipairs({wallet, cost}) do
    money:SetSize(128, 13); money.RegisterForWidgetSet = false
    for _, key in ipairs({"GoldButton", "SilverButton", "CopperButton"}) do
        local b = env.NewFrame("Button", nil, money); money[key] = b
        b.RegisterForWidgetSet = false
        b.Text = b:CreateFontString(); b.Text:SetText("12"); b.Text:SetTextColor(1, .1, .1)
        b.normalTexture = b:CreateTexture(); b.normalTexture:SetAtlas("coin-" .. key)
        b.normalTexture:SetSize(13, 13); b.normalTexture:SetAlpha(.9)
        b:SetScript("OnClick", function() error("money popup must not be invoked by styling") end)
    end
end
local border = env.NewFrame("Frame", nil, wallet); wallet.Border = border
border:SetSize(128, 17); border.leftEdge = "common-coinbox-left"
border.rightEdge = "common-coinbox-right"; border.centerEdge = "_common-coinbox-center"
for _, key in ipairs({"Left", "Right", "Middle"}) do border[key] = border:CreateTexture() end
for key, value in pairs(_G.ContainerFrameCurrencyBorderMixin) do border[key] = value end
border:OnLoad()
_G.PetStableCostLabel = env.NewFrame("Frame", nil, root)
_G.PetStableSlotText = env.NewFrame("Frame", nil, root)
local purchase = env.NewFrame("Button", nil, root); root.purchaseButton = purchase
purchase.Text = purchase:CreateFontString(); purchase.RegisterForWidgetSet = false; purchase.DisabledTexture = false
function purchase:Enable() self.enabled = true end
function purchase:Disable() self.enabled = false end
purchase.Update = _G.PetStablePurchaseButtonMixin.Update
purchase:SetScript("OnClick", _G.PetStablePurchaseButtonMixin.OnClick)
local slots, cash, fee = 0, 0, 25000
_G.C_StableInfo = { GetNumStableSlots = function() return slots end, GetNextStableSlotCost = function() return fee end }
_G.Constants = { PetConsts = { MAX_STABLE_SLOTS = 2 } }
_G.GetMoney = function() return cash end
_G.HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }; _G.RED_FONT_COLOR = { r = 1, g = .1, b = .1 }
local colorCalls = 0
_G.SetMoneyFrameColor = function(name, r, g, b)
    colorCalls = colorCalls + 1
    for _, key in ipairs({"GoldButton", "SilverButton", "CopperButton"}) do _G[name][key].Text:SetTextColor(r, g, b) end
end
purchase:Update()
local callbacks, registry = {}, {}
skin.OnAddOnLoaded = function(addon, fn) callbacks[addon] = fn end
ns.Registry = { Register = function(_, key, entry) registry[key] = entry end }
local options, skinWindow = nil, skin.SkinWindow
skin.SkinWindow = function(frame, opts) options = opts; return skinWindow(frame, opts) end
local click = purchase:GetScript("OnClick")
assert(loadfile(arg[1] or "modules/skinning/frames/misc_frames.lua"))("QUI", ns)
callbacks.Blizzard_StableUI()
assert(border:GetFrameLevel() <= wallet:GetFrameLevel(), "wallet chrome must stay below denomination content")
assert(border._quiRoundedSurface, "Stable wallet must receive rounded currency-box chrome")
assert(options and options.noButtonFonts, "money state fonts must be excluded from generic button font replacement")
for _, money in ipairs({wallet, cost}) do
    for _, key in ipairs({"GoldButton", "SilverButton", "CopperButton"}) do
        local b = money[key]
        assert(b.normalTexture:GetAlpha() == .9 and b.normalTexture.atlas == "coin-" .. key and b.Text:GetText() == "12",
            "native coin artwork, opacity and amounts must remain")
        assert(b.Text.textColor[2] == .1 and b.Text.font == "QUIFont.ttf",
            "font-only typography must preserve native red money colors")
    end
end
assert(not purchase:IsEnabled() and cost:IsShown() and _G.PetStableCostLabel:IsShown(),
    "insufficient-money eligibility and footer visibility must remain")
cash = fee; purchase:Update()
assert(purchase:IsEnabled() and cost.GoldButton.Text.textColor[2] == 1, "native affordable purchase must restore money color")
slots = 2; purchase:Update()
assert(not purchase:IsShown() and not cost:IsShown() and not _G.PetStableSlotText:IsShown(),
    "maximum slots must hide native purchase footer")
local calls = colorCalls
border:OnLoad(); border.Left:SetAlpha(1)
registry.skinStable.refresh()
assert(border.Left:GetAlpha() == 0 and border.Right:GetAlpha() == 0 and border.Middle:GetAlpha() == 0
    and border.Left.atlas == "common-coinbox-left" and border:GetWidth() == 128 and border:GetHeight() == 17,
    "native border atlas lifecycle must remain while decoration stays suppressed")
assert(colorCalls == calls and not purchase:IsShown() and not cost:IsShown() and purchase:GetScript("OnClick") == click,
    "theme must retain eligibility without native money/action callbacks")
env.profile.general.skinStable = false
local fresh = env.NewFrame("Frame", nil, wallet); fresh.Left = fresh:CreateTexture(); wallet.Border = fresh
registry.skinStable.refresh()
assert(not fresh._quiRoundedSurface and fresh.Left:GetAlpha() == 1, "disabled skin must leave new footer native")
env.profile.general.skinStable = true
fresh.IsForbidden = function() return true end
registry.skinStable.refresh()
assert(not fresh._quiRoundedSurface, "forbidden footer border must remain native")
print("Stable footer purchase lifecycle passed")
