-- luacheck: globals MailFrame OpenMailFrame UpdateUIPanelPositions UpdateScaleForFitForOpenPanels

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function noop() end
local frames, pending, foci = {}, {}, {}
local lastRaised, inCombat
local methods = {}
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:IsForbidden() return self.forbidden or false end
function methods:IsProtected() return self.protected or false end
function methods:IsShown() return self.shown or false end
function methods:IsVisible() return self:IsShown() end
function methods:GetScale() return 1 end
function methods:GetFrameLevel() return 1 end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:GetWidth() return 300 end
function methods:GetHeight() return 300 end
function methods:GetSize() return 300, 300 end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:Raise() lastRaised = self end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:HookScript(event, callback)
    assert(not self.protected, "secure mail root must not receive script hooks")
    local previous = self.hooks[event]
    self.hooks[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function methods:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.hooks.OnShow then self.hooks.OnShow(self) end
end
function methods:Hide()
    self.shown = false
    if self.hooks.OnHide then self.hooks.OnHide(self) end
end
function methods:SetShown(shown)
    if shown then self:Show() else self:Hide() end
end
for _, method in ipairs({ "IsMovable", "IsClampedToScreen", "IsMouseEnabled", "IsMouseWheelEnabled", "IsUserPlaced", "IsMouseOver" }) do
    methods[method] = function() return false end
end

local function newFrame(name, parent, protected)
    local frame = setmetatable({
        name = name, parent = parent, protected = protected,
        points = {}, scripts = {}, hooks = {}, events = {}, children = {},
    }, { __index = function(_, key) return methods[key] or (key:match("^[A-Z]") and noop or nil) end })
    frames[#frames + 1] = frame
    if parent then parent.children[#parent.children + 1] = frame end
    return frame
end

UIParent = newFrame("UIParent")
MailFrame = newFrame("MailFrame", UIParent, true)
CharacterFrame = newFrame("CharacterFrame", UIParent)
OpenMailFrame = newFrame("OpenMailFrame", MailFrame, true)
_G.AuctionHouseFrame = newFrame("AuctionHouseFrame", UIParent)
_G.MerchantFrame = newFrame("MerchantFrame", UIParent)
_G.MerchantFrame.selectedTab = 1
local bagWindow = newFrame("QUI_BagWindow", UIParent)
local bagItem = newFrame("BagItem", bagWindow)
function bagItem:GetBagID() return 0 end
function bagItem:GetID() return 3 end
local auctionButton = newFrame("PostButton", _G.AuctionHouseFrame)
local mailButton = newFrame("MailButton", MailFrame)
local characterButton = newFrame("CharacterButton", CharacterFrame)
local openMailButton = newFrame("OpenMailButton", OpenMailFrame)
local unrelated = newFrame("UnmanagedPanel", UIParent)

function CreateFrame(_, name, parent) return newFrame(name, parent) end
function RunNextFrame(callback) pending[#pending + 1] = callback end
function InCombatLockdown() return inCombat or false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetMouseFoci() return foci end
function hooksecurefunc(target, name, callback)
    if type(target) == "string" then
        callback, name, target = name, target, _G
    end
    assert(not target.protected, "secure mail root must not receive method hooks")
    local original = assert(target[name], name)
    target[name] = function(...)
        original(...)
        callback(...)
    end
end
C_AddOns = { IsAddOnLoaded = function() return true end }

local native = readFile("tests/framexml/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua")
local nativeUpdate = assert(native:match("(function FramePositionDelegate:UpdateUIPanelPositions%(currentFrame%).-)\nfunction FramePositionDelegate:UpdateScaleForFitForOpenPanels"))
local delegate = { left = MailFrame, center = CharacterFrame }
function delegate:GetUIPanel(key) return self[key] end
delegate.EvaluateAutoMinimize = noop
local layout = { TOP_OFFSET = -116, LEFT_OFFSET = 16, CENTER_OFFSET = 340, RIGHT_OFFSET = 660, PANEl_SPACING_X = 10, DEFAULT_FRAME_WIDTH = 300 }
local nativeEnvironment = setmetatable({
    FramePositionDelegate = delegate,
    GetUIPanelAttribute = function(_, name) if name == "area" then return "left" end end,
    GetUIPanelLayoutAttribute = function(name) return layout[name] end,
    SetUIPanelLayoutAttribute = function(name, value) layout[name] = value end,
    GetUIPanelWidth = function(frame) return frame:GetWidth() end,
    ClampUIPanelY = function(_, value) return value end,
    CanShowCenterUIPanel = function() return true end,
    CanShowRightUIPanel = function() return true end,
}, { __index = _G })
local nativeChunk = assert(loadstring(nativeUpdate))
setfenv(nativeChunk, nativeEnvironment)
nativeChunk()
function UpdateUIPanelPositions(frame) delegate:UpdateUIPanelPositions(frame) end
function UpdateScaleForFitForOpenPanels() delegate:UpdateUIPanelPositions() end
function ShowUIPanel(frame)
    frame:Show()
    UpdateUIPanelPositions(frame)
end

local containerSource = readFile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua")
local containerClick = assert(containerSource:match("(function ContainerFrameItemButton_OnClick%(self, button%).-)\nfunction ContainerFrameItemButton_CalculateItemTooltipAnchors"))
local usedBag, usedSlot
local containerEnvironment = setmetatable({
    MerchantFrame_ResetRefundItem = noop,
    ContainerFrame_GetExtendedPriceString = function() return false end,
    ItemLocation = { CreateFromBagAndSlot = function() return {} end },
    BankUtil_IsAccountBankDepositRefundable = function() return false end,
    BankFrame = { GetActiveBankType = noop },
    StackSplitFrame = { Hide = noop },
    C_Container = { UseContainerItem = function(bag, slot)
        usedBag, usedSlot = bag, slot
        delegate:UpdateUIPanelPositions()
    end },
    GetCursorInfo = noop,
    SpellCanTargetItem = function() return true end,
}, { __index = _G })
local containerChunk = assert(loadstring(containerClick))
setfenv(containerChunk, containerEnvironment)
containerChunk()
_G.ContainerFrameItemButton_OnClick = containerEnvironment.ContainerFrameItemButton_OnClick

local profile = { blizzardMover = { enabled = true, requireModifier = true, scaleEnabled = false, frames = {} } }
local ns = {
    Helpers = { GetProfile = function() return profile end },
    SafeCall = function(_, callback, ...) return pcall(callback, ...) end,
    SafeCallMethod = function(_, object, name, ...) return pcall(object[name], object, ...) end,
    SafeCallMethodIfPresent = function(_, object, name, ...)
        if object and object[name] then return pcall(object[name], object, ...) end
    end,
}
assert(loadfile(arg[1] or "modules/qol/blizzard_mover.lua"))("QUI", ns)
local mover = assert(ns.QUI_BlizzardMover)
mover.functions.InitDB()
for _, name in ipairs({ "MailFrame", "CharacterFrame", "OpenMailFrame", "AuctionHouseFrame", "MerchantFrame" }) do
    mover.functions.RegisterFrame({
        id = name, label = name, group = "test", names = { name }, defaultEnabled = true,
        secureFrame = name == "MailFrame" or name == "OpenMailFrame", disableMove = true,
    })
end

local function flush()
    local callbacks = pending
    pending = {}
    for _, callback in ipairs(callbacks) do callback() end
end
local function tick()
    for _, frame in ipairs(frames) do
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.016) end
    end
    flush()
end
local function click(frame)
    foci = { frame }
    for _, receiver in ipairs(frames) do
        if receiver.events.GLOBAL_MOUSE_DOWN and receiver.scripts.OnEvent then
            receiver.scripts.OnEvent(receiver, "GLOBAL_MOUSE_DOWN", "LeftButton")
        end
    end
end
local function reflow(expected, message)
    UpdateUIPanelPositions()
    assert(lastRaised == expected, message .. " before the next rendered frame")
    flush()
    assert(lastRaised == expected, message)
end

ShowUIPanel(CharacterFrame)
ShowUIPanel(MailFrame)
tick()
delegate:UpdateUIPanelPositions()
assert(lastRaised == CharacterFrame, "native left-to-right layout must raise Character last")
click(mailButton)
reflow(MailFrame, "interacting with mail must survive native Character-last layout")
reflow(MailFrame, "later background layout must preserve mail foreground without another click")
click(characterButton)
reflow(CharacterFrame, "clicking Character must restore its normal foreground behavior")
click(mailButton)
ShowUIPanel(CharacterFrame)
flush()
assert(lastRaised == CharacterFrame, "a managed show must supersede a queued mail click")
MailFrame:Hide()
tick()
ShowUIPanel(MailFrame)
ShowUIPanel(CharacterFrame)
tick()
assert(lastRaised == CharacterFrame, "secure show polling must not override a newer managed show")
click(mailButton)
ShowUIPanel(OpenMailFrame)
tick()
assert(lastRaised == OpenMailFrame, "opening child mail must select the newly shown panel")
click(openMailButton)
reflow(OpenMailFrame, "nearest registered child must win over its registered parent")
OpenMailFrame:Hide()
tick()
click(mailButton)
flush()
UpdateScaleForFitForOpenPanels()
assert(lastRaised == MailFrame, "scale-fit reflow must preserve foreground before the next rendered frame")
flush()
assert(lastRaised == MailFrame, "native scale-fit reflow must preserve foreground")

click(mailButton)
profile.blizzardMover.enabled = false
reflow(CharacterFrame, "disabled mover must not repair stacking")
profile.blizzardMover.enabled = true
click(mailButton)
profile.blizzardMover.frames.MailFrame.enabled = false
reflow(CharacterFrame, "disabled panel must not repair stacking")
profile.blizzardMover.frames.MailFrame.enabled = true
click(mailButton)
inCombat = true
reflow(CharacterFrame, "queued repair must not Raise in combat")
inCombat = false
click(mailButton)
MailFrame:Hide()
reflow(CharacterFrame, "queued repair must not Raise a hidden panel")
MailFrame:Show()
tick()
click(mailButton)
click(unrelated)
reflow(CharacterFrame, "clicking unmanaged UI must release mover foreground")
click(mailButton)
ShowUIPanel(unrelated)
unrelated:Raise()
flush()
assert(lastRaised == unrelated, "new unmanaged window must supersede pending managed repair")
click(mailButton)
local forbidden = newFrame("Forbidden", UIParent)
forbidden.forbidden = true
forbidden.GetParent = function() error("forbidden frame ancestry must not be inspected") end
click(forbidden)
reflow(CharacterFrame, "forbidden focus must release managed foreground without traversal")

click(mailButton)
MailFrame.IsShown = function() error("visibility unavailable") end
reflow(CharacterFrame, "unreadable visibility must skip deferred Raise")
MailFrame.IsShown = nil
local secret = {}
function issecretvalue(value) return value == secret end
click(mailButton)
MailFrame.IsShown = function() return secret end
reflow(CharacterFrame, "secret visibility must skip deferred Raise")
MailFrame.IsShown = nil
click(mailButton)
click(secret)
reflow(CharacterFrame, "secret focus must skip traversal")
local handle = setmetatable({}, { __index = function() error("frame handles must not be inspected") end })
function IsFrameHandle(value) return value == handle end
click(mailButton)
click(handle)
reflow(CharacterFrame, "opaque frame handles must skip traversal")

delegate.left, delegate.center = nil, nil
delegate.doublewide, delegate.right = _G.AuctionHouseFrame, CharacterFrame
ShowUIPanel(_G.AuctionHouseFrame)
tick()
click(auctionButton)
flush()
for _ = 1, 3 do
    reflow(_G.AuctionHouseFrame, "auction listing refresh must not render Character above the Auction House")
end
click(characterButton)
reflow(CharacterFrame, "Character must still come forward when clicked beside Auction House")

delegate.doublewide, delegate.right = nil, nil
delegate.left, delegate.center = _G.MerchantFrame, CharacterFrame
ShowUIPanel(_G.MerchantFrame)
tick()
click(bagItem)
_G.ContainerFrameItemButton_OnClick(bagItem, "RightButton")
assert(usedBag == 0 and usedSlot == 3, "native bag right-click must still use the chosen item")
assert(lastRaised == _G.MerchantFrame, "bag sale must restore vendor foreground before rendering")
flush()
reflow(_G.MerchantFrame, "later sale refresh must keep vendor above Character")
click(characterButton)
reflow(CharacterFrame, "clicking Character after selling must still select Character")
click(bagItem)
_G.ContainerFrameItemButton_OnClick(bagItem, "LeftButton")
flush()
assert(lastRaised == CharacterFrame, "left-click item spell targeting must not select the vendor")

profile.blizzardMover.frames.MerchantFrame.enabled = false
click(bagItem)
_G.ContainerFrameItemButton_OnClick(bagItem, "RightButton")
flush()
assert(lastRaised == CharacterFrame, "disabled vendor mover must not restore sale foreground")
profile.blizzardMover.frames.MerchantFrame.enabled = true
inCombat = true
click(bagItem)
_G.ContainerFrameItemButton_OnClick(bagItem, "RightButton")
flush()
assert(lastRaised == CharacterFrame, "bag sale must not Raise in combat")
inCombat = false

_G.PlayerSpellsFrame = newFrame("PlayerSpellsFrame", UIParent)
local playerSpells = mover.functions.RegisterFrame({
    id = "PlayerSpellsFrame", defaultEnabled = false, disableMove = true,
})
mover.functions.RefreshEntry(playerSpells)
click(characterButton)
ShowUIPanel(_G.PlayerSpellsFrame)
_G.PlayerSpellsFrame:Raise()
flush()
assert(lastRaised == _G.PlayerSpellsFrame, "disabled talents panel must open without retaining another panel's queued raise")
reflow(CharacterFrame, "disabled talents panel must not acquire foreground tracking")

profile.blizzardMover.enabled = false
ShowUIPanel(_G.PlayerSpellsFrame)
flush()
profile.blizzardMover.enabled = true
profile.blizzardMover.frames.PlayerSpellsFrame.enabled = true
mover.functions.RefreshEntry(playerSpells)
_G.PlayerSpellsFrame:Hide()
ShowUIPanel(_G.PlayerSpellsFrame)
reflow(_G.PlayerSpellsFrame, "enabling talents after an early settings refresh must install foreground tracking")

local deferred = newFrame("DeferredSecurePanel", UIParent, true)
_G.DeferredSecurePanel = deferred
inCombat = true
local deferredPanel = mover.functions.RegisterFrame({
    id = "DeferredSecurePanel", secureFrame = true, disableMove = true,
})
assert(mover.variables.combatQueue[deferred] == deferredPanel, "combat must defer secure panel setup")
ShowUIPanel(deferred)
flush()
assert(lastRaised == CharacterFrame, "deferred panel must open without a mover raise during combat")
inCombat = false
mover.functions.TryHookEntry(deferredPanel)
assert(mover.variables.combatQueue[deferred] == nil, "secure panel setup must recover after combat")
deferred:Hide()
tick()
ShowUIPanel(deferred)
tick()
reflow(deferred, "deferred secure panel must acquire foreground tracking after setup completes")

print("OK: blizzard_mover_panel_stacking_test")
