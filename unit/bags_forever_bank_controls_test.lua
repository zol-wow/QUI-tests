local loader = dofile("tests/helpers/load_bags_data.lua")
loader.InstallBaseStubs()
APIDocumentation = { AddDocumentationTable = function(_, doc)
    for _, field in ipairs(doc.Tables[1].Fields) do Enum.BagIndex[field.Name] = field.EnumValue end
end }
dofile("tests/clients/forever/api-docs/blizzard/BagIndexConstantsDocumentation.lua")
Enum.PlayerInteractionType = { Banker = 1, CharacterBanker = 2, AccountBanker = 3 }
local ns = loader.LoadAll();
(dofile("tests/helpers/locale.lua"))(ns)
local forever = not arg or arg[1] ~= "retail"
ns.Client = { isForever = forever }
StaticPopupDialogs = {}
CreateFromMixins = function(...) local result = {}; for i = 1, select("#", ...) do
    for key, value in pairs(select(i, ...)) do result[key] = value end
end; return result end
SidePanelTabButtonMixin = {}
RegisterPlayerInteraction = function() end
assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/BankFrame.lua"))()
local nodes, clicked = {}, nil
local methods = {}
local function node(parent)
    local f = setmetatable({ parent = parent, scripts = {}, attributes = {}, shown = true,
        width = 24, height = 20 }, { __index = methods })
    nodes[#nodes + 1] = f
    return f
end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:SetText(text) self.text = text end
function methods:GetStringWidth() return #(self.text or "") * 6 end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetShown(value) self.shown = value end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:ClearNormalTexture() self.normalTexture = nil end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:SetID(value) self.id = value end
function methods:GetParent() return self.parent end
function methods:SetItemLocation(location) self.location = location end
function methods:CreateFontString() return node(self) end
function methods:CreateTexture() return node(self) end
function methods:SetContentSize(w, h) self.width, self.contentHeight = w, h end
function methods:SetFooterHeight(h) self.footerHeight = h end
for _, name in ipairs({ "SetFont", "SetScale", "SetAtlas", "ApplyPosition", "RegisterForClicks", "RegisterForDrag" }) do
    methods[name] = function() end
end
CreateFrame = function(kind, _, parent, template)
    local f = node(parent)
    if template == "BankItemButtonBagTemplate" then
        assert(kind == "ItemButton")
        for key, value in pairs(_G.BankItemButtonBagMixin) do f[key] = value end
        f.DisabledOverlay = node(f)
        f.Background = node(f)
        f.IconBorder = node(f)
        f.icon = node(f)
        f.normalTexture = "bank-frame-bag-slotframe"
        f.DisabledOverlay.atlas = "bankslot-icon-lock"
        f.icon.art = "native-bag-art"
        f:OnLoad()
        f.nativeBagButton = true
    end
    return f
end
local hooks = 0
hooksecurefunc = function(object, key, callback)
    hooks = hooks + 1
    local original = object[key]
    object[key] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Container.PickupContainerItem = function(bag, slot) clicked = { bag, slot } end
local bagQuality = 3
C_Container.GetContainerItemInfo = function(_, slot)
    if slot == 2 then return { quality = bagQuality } end
end
C_Bank.ShouldUsePlayerBagsInBank = function() return true end
local unavailableBank
C_Bank.CanViewBank = function(bankType) return bankType ~= unavailableBank end
C_Bank.CanPurchaseBankTab = function() return true end
C_Bank.FetchMaxNumBankTabs = function() return 9 end
C_Bank.FetchPurchasedBankTabData = function(bankType)
    local first = bankType == Enum.BankType.Account and 15 or 6
    return { { ID = first }, { ID = first + 1 }, { ID = first + 2 } }
end
C_Bank.FetchDepositedMoney = function() return 0 end
C_Bank.CanDepositMoney = function() return false end
C_Bank.CanWithdrawMoney = function() return false end
C_Bank.DoesBankTypeSupportAutoDeposit = function() return false end
StaticPopup_Hide = function() end
ns.Helpers = {
    CreateDBGetter = function() return function() return {} end end,
    GetGeneralFont = function() return "font" end,
    GetSkinColors = function() return 1, 1, 1 end,
        GetWindowColors = function() return 1, 1, 1, 1, 0.05, 0.05, 0.05, 0.95 end,
    GetCore = function() return {} end,
    ApplyIconStyle = function(button, icon) button.styledIcon = icon end,
}
ns.UIKit = {
    CreateBorderLines = function(button) button.borderCreated = true end,
    UpdateBorderLines = function(button, width, r, g, b, a) button.border = { width, r, g, b, a } end,
}
local Bags = ns.Bags
Bags.Chassis = {
    MakeScheduleRefresh = function(_, refresh) return refresh end,
    CreateWindow = function()
        local f = node()
        for _, key in ipairs({ "_body", "_footer", "_header", "_title", "_searchBox", "_close" }) do f[key] = node(f) end
        return f
    end,
    CreatePanelButton = function(parent, _, template)
        local f = node(parent)
        f._label = node(f)
        f.template = template
        return f
    end,
    ClampAppearance = function() return { iconSize = 24, spacing = 2, columns = 8 } end,
    MeasureHeaderWidth = function() return 200 end,
}
Bags.OwnerSelect = { Attach = function() local f = node(); f.Update = function() end; return f end }
local gridButtons = {}
local deferLiveButtons = false
local dressed = 0
Bags.ItemButtons = {
    AddSlotBackground = function(button) button.slotBackground = true end,
    GetQualityColor = function(quality) return quality / 10, 0.4, 0.8 end,
    CreateHolder = function(parent, bagID) local f = node(parent); f.bagID = bagID; return f end,
    CreateLive = function(parent)
        if deferLiveButtons then return nil end
        local f = node(parent); gridButtons[#gridButtons + 1] = f; return f
    end,
    CreateCached = function(parent) return node(parent) end,
    Dress = function() dressed = dressed + 1 end, DressCached = function() end,
    SetFocusFlash = function() end, SetBagHighlight = function() end,
}
assert(loadfile("QUI_Bags/bags/views/grid_layout.lua"))("QUI", ns)
QUI_StorageDB = nil
ns.Storage.Store.Initialize()
ns.Storage.Store.EnsureCurrentCharacter()
local rec = ns.Storage.Store.GetCurrentCharacter()
rec.bankTabs = {
    [6] = { name = "One", size = 50, slots = {} },
    [7] = { name = "Two", size = 50, slots = {} },
    [8] = { name = "Three", size = 50, slots = {} },
}
ns.Storage.Store.GetWarband().tabs = { [15] = { name = "Account", size = 10, slots = {} } }
assert(loadfile("QUI_Bags/bags/views/bank_window.lua"))("QUI", ns)
local bank = Bags.BankWindow
bank.ShowLive()
local win = bank.GetFrame()
local slots = {}
for _, f in ipairs(nodes) do if f.nativeBagButton then slots[#slots + 1] = f end end
assert(#slots == 8, "custom Forever bank must expose every bank bag equipment slot except the base storage")
assert(slots[1].location.bag == -2 and slots[1].location.slot == 2)
assert(not slots[1].DisabledOverlay:IsShown() and slots[3].DisabledOverlay:IsShown())
local first = slots[1]
if forever then
    assert(first.normalTexture == nil and first.Background.alpha == 0,
        "Forever bank bag slots must replace native gold frames and backgrounds")
    assert(first.borderCreated and first.slotBackground and first.styledIcon == first.icon)
    assert(first.IconBorder.alpha == 0 and first.border[2] == 0.3 and first.border[5] == 1,
        "equipped bag quality must color the QUI border")
    assert(slots[3].border[5] == 0.35, "empty locked slots use the normal empty-slot border")
    bagQuality = 4
    first:SetItemLocation(first.location)
    assert(first.border[2] == 0.4, "native item-location refresh must refresh the quality border")
    local hooksBefore = hooks
    bank.Refresh()
    assert(hooks == hooksBefore, "refresh must not install duplicate item-location hooks")
else
    assert(first.normalTexture == "bank-frame-bag-slotframe" and not first.borderCreated,
        "Forever styling must not affect Retail")
    assert(hooks == 0)
end
assert(first.icon.art == "native-bag-art" and slots[3].DisabledOverlay.atlas == "bankslot-icon-lock",
    "bag artwork and native lock overlays must survive styling")
assert(first.point[1] == "TOPLEFT" and first.width == 36 and first.height == 36,
    "native bag equipment targets must retain their geometry")
assert(first.OnClickInternal == _G.BankItemButtonBagMixin.OnClickInternal
    and first.Pickup == _G.BankItemButtonBagMixin.Pickup,
    "native pickup and click handlers must remain unchanged")
unavailableBank = Enum.BankType.Account
bank.Refresh()
if forever then
    assert(win._charBankBtn.enabled and win._charBankBtn.alpha == 1)
    assert(not win._warbandBankBtn.enabled and win._warbandBankBtn.alpha == 0.4,
        "unavailable live banks must be visibly disabled")
else
    assert(win._warbandBankBtn.enabled == nil and win._warbandBankBtn.alpha == nil,
        "Retail segment availability must remain unchanged")
end
unavailableBank = nil
bank.Refresh()
if forever then assert(win._warbandBankBtn.enabled and win._warbandBankBtn.alpha == 1) end
slots[1]:OnClickInternal()
assert(clicked[1] == -2 and clicked[2] == 2, "native bag drop/click path must use equipment container, not item grid")
slots[1]:Pickup()
assert(clicked[1] == -2 and clicked[2] == 2, "native bag drag path must remain available")
local all, purchase
for _, f in ipairs(nodes) do
    if f._entry and f._entry.all then all = f end
    if f._entry and f._entry.purchase then purchase = f end
end
assert(purchase.template == "BankPanelPurchaseButtonScriptTemplate")
assert(purchase.attributes.overrideBankType == Enum.BankType.Character)
assert(purchase.scripts.OnClick == nil, "purchase must preserve native secure template handler")
all.scripts.OnClick(all, "LeftButton")
local function visibleGrid()
    local result = {}
    for _, f in ipairs(gridButtons) do if f:IsShown() then result[#result + 1] = f end end
    return result
end
assert(#visibleGrid() == 88 and win._pageText.text == "1/2")
assert(not win._pagePrev.enabled and win._pageNext.enabled)
win._pageNext.scripts.OnClick()
assert(#visibleGrid() == 62 and win._pageText.text == "2/2")
assert(win._pagePrev.enabled and not win._pageNext.enabled)
win._warbandBankBtn.scripts.OnClick()
assert(slots[1].location.bag == -3 and slots[1].bankType == Enum.BankType.Account)
slots[1]:OnClickInternal()
assert(clicked[1] == -3 and clicked[2] == 2)
bank.ShowCached()
for _, button in ipairs(slots) do assert(not button:IsShown(), "cached browsing must not offer live bag changes") end
unavailableBank = Enum.BankType.Account
bank.Refresh()
if forever then assert(win._warbandBankBtn.enabled and win._warbandBankBtn.alpha == 1,
    "cached bank browsing must remain available without live service access") end
unavailableBank = nil
bank.ShowLive()
win._warbandBankBtn.scripts.OnClick()
local before = #gridButtons
ns.Storage.Store.GetWarband().tabs[15].size = 11
deferLiveButtons = true
dressed = 0
bank.Refresh()
assert(#gridButtons == before and #visibleGrid() == 10 and dressed == 10,
    "bank refresh must skip deferred slots while continuing to dress existing live slots")
deferLiveButtons = false
bank.Refresh()
assert(#gridButtons == before + 1 and #visibleGrid() == 11,
    "bank refresh must create and show the deferred slot after combat")
print("OK: Forever bank native bag controls, purchase template, pagination, cached view")
