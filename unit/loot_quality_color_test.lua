local function noop() end
local methods = {}
for _, name in ipairs({
    "SetSize", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetTexCoord", "SetFont",
    "SetJustifyH", "SetWordWrap", "SetAtlas", "SetHighlightTexture", "SetVertexColor",
    "SetFrameStrata", "SetToplevel", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "RegisterEvent", "UnregisterAllEvents", "SetBlendMode",
    "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues", "SetValue",
    "SetAlpha", "Enable", "SetEnabled", "SetDesaturated", "SetColorTexture",
}) do
    methods[name] = noop
end
local function widget()
    return setmetatable({ scripts = {}, events = {} }, { __index = methods })
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:CreateTexture() return widget() end
function methods:CreateFontString() return widget() end
function methods:GetHighlightTexture() return widget() end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:SetText(text) self.text = text end
function methods:SetTextColor(...) self.color = { ... } end
function methods:SetValue(value) self.value = value end
function methods:SetPoint(...) self.points = { ... } end
function methods:ClearAllPoints() self.points = nil end
function methods:GetHeight() return self.height or 1080 end
function methods:GetEffectiveScale() return 1 end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetVerticalScroll(offset) self.scrollOffset = offset end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetHeight(height) self.height = height end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(shown) self.shown = not not shown end
function methods:IsShown() return self.shown end

local colors = {
    [1] = { 1, 1, 1 },
    [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
}
local items = {
    { texture = 133788, name = "1 Copper", quantity = 0, quality = 1 },
    { texture = 134400, name = "Epic Item", quantity = 3, quality = 4 },
    { texture = 134400, name = "Unknown Quality", quantity = 1 },
}
local qualityCalls = {}
local pendingTimers = {}
local createdFrames = {}
local nativeRollIDs, remainingTimes = { 88, 99 }, { [88] = 6000 }
local cursor, modified, clicks, itemLootedEvents, hiddenDialogs = 200, false, {}, {}, {}
local unpackValues = table.unpack or unpack
local env = setmetatable({
    unpack = unpackValues,
    tinsert = table.insert,
    tremove = table.remove,
    UIParent = widget(),
    LootFrame = widget(),
    GameTooltip_Hide = noop,
    InCombatLockdown = function() return false end,
    GetTime = function() return 100 end,
    GetCursorPosition = function() return cursor, cursor end,
    IsModifiedClick = function() return modified end,
    GetLootSlotLink = function(index) return "item:" .. index end,
    HandleModifiedItemClick = function(link) clicks[#clicks + 1] = link end,
    LootSlot = function(index) clicks[#clicks + 1] = index end,
    StaticPopup_Hide = function(dialog) hiddenDialogs[#hiddenDialogs + 1] = dialog end,
    EventRegistry = { TriggerEvent = function(_, event) itemLootedEvents[#itemLootedEvents + 1] = event end },
    GetActiveLootRollIDs = function() return nativeRollIDs end,
    GetLootRollTimeLeft = function(rollID) return remainingTimes[rollID] or 30000 end,
    C_Loot = { GetLootRollDuration = function(rollID) return rollID ~= 99 and 60000 or nil end },
    C_Timer = { After = function(_, callback) pendingTimers[#pendingTimers + 1] = callback end },
    GetNumLootItems = function() return #items end,
    LootSlotHasItem = function() return true end,
    GetLootSlotInfo = function(index)
        local item = items[index]
        return item.texture, item.name, item.quantity, nil, item.quality, false, false
    end,
    GetLootRollItemInfo = function(rollID)
        return 134400, "Roll Item", 1, rollID == 1 and 4 or nil, false, true, true, false
    end,
    C_Item = {
        GetItemQualityColor = function(quality)
            qualityCalls[#qualityCalls + 1] = quality
            return unpackValues((assert(colors[quality], "unexpected item quality")))
        end,
    },
}, { __index = _G })
env._G = env
env.CreateFrame = function(_, name)
    local frame = widget()
    createdFrames[#createdFrames + 1] = frame
    if name then env[name] = frame end
    return frame
end
assert(env.GetItemQualityColor == nil, "legacy GetItemQualityColor must be absent")

local ns = {
    Addon = { db = { profile = { loot = { enabled = true }, lootRoll = { enabled = true } } } },
    Helpers = { ApplyBarStyle = function(bar, path) bar:SetStatusBarTexture(path) end, ApplyIconStyle = function() end,
        CreateStateTable = function() return {} end,
        SetFrameBackdropColor = noop,
        SetFrameBackdropBorderColor = function(frame, ...) frame.borderColor = { ... } end,
    },
    SkinBase = {
        CHROME = { BORDER_PX = 1 },
        GetWindowColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end,
        GetSkinColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end,
        ApplyPixelBackdrop = noop,
        ApplyChromeBackdrop = function(frame, opts) frame.chrome = opts end,
        RoundIconTexture = function(_, texture) texture.rounded = true end,
        SetPixelPoint = noop,
        CreateCloseButton = widget,
        SkinTrimScrollBar = noop,
    },
    LSM = { Fetch = function() return "test-font" end },
    L = { Loot = "Loot" },
}
local chunk = assert(loadfile(arg[1] or "modules/skinning/notifications/loot.lua", "t", env))
if setfenv then setfenv(chunk, env) end
chunk("QUI", ns)
local loot = ns.Addon.Loot
loot:Initialize()
local function event(name, ...)
    loot.eventFrame.scripts.OnEvent(loot.eventFrame, name, ...)
end
local function checkColor(frame, quality)
    assert(frame:IsShown(), "loot entry should be visible")
    for channel = 1, 3 do
        assert(frame.name.color[channel] == colors[quality][channel], "wrong item name color")
        assert(frame.iconBorder.borderColor[channel] == colors[quality][channel], "wrong item border color")
    end
end

local timerManager = assert(createdFrames[1])
timerManager.scripts.OnUpdate(timerManager, 0.01)
local restoredRoll = assert(env.QUI_LootRollFrame1, "initialization must restore pending native rolls")
assert(restoredRoll.rollID == 88 and restoredRoll.timer.value == 0.1,
    "initialization after reload must restore live native roll progress")
event("CANCEL_ALL_LOOT_ROLLS")
assert(not restoredRoll:IsShown(), "native mass cancellation must immediately hide restored rolls")
nativeRollIDs, qualityCalls = {}, {}

event("LOOT_OPENED", true)
assert(env.QUI_LootFrame:IsShown(), "loot window should open")
assert(env.QUI_LootFrame.height == 142, "all three loot slots should be laid out")
assert(env.QUI_LootFrame.chrome.radius == 8, "loot shell must use rounded window chrome")
assert(env.QUI_LootSlot1.iconBorder.chrome.radius == 4 and env.QUI_LootSlot1.icon.rounded, "loot icon and quality border must share rounded corners")
assert(restoredRoll.chrome.radius == 8 and restoredRoll.icon.rounded, "restored roll must keep rounded shell and item artwork")
assert(restoredRoll.needBtn.chrome.radius == 5 and restoredRoll.needBtn.icon.rounded, "roll actions must use rounded controls without losing their icons")
for index, item in ipairs(items) do
    local slot = env.QUI_LootFrame.slots[index]
    checkColor(slot, item.quality or 1)
    assert(slot.name.text == item.name, "loot name should survive coloring")
    assert(slot.icon.texture == item.texture, "loot icon should survive coloring")
end
assert(not env.QUI_LootSlot1.count:IsShown(), "zero-quantity money must not show a stack count")
assert(env.QUI_LootSlot2.count:IsShown() and env.QUI_LootSlot2.count.text == 3, "item stack should show its count")
assert(not env.QUI_LootSlot4:IsShown(), "unused slots should stay hidden")

event("START_LOOT_ROLL", 1, 60)
checkColor(env.QUI_LootRollFrame1, 4)
event("START_LOOT_ROLL", 2, 60)
checkColor(env.QUI_LootRollFrame2, 1)

loot:ShowLootPreview()
for index, quality in ipairs({ 4, 1, 2 }) do
    checkColor(env.QUI_LootFrame.slots[index], quality)
end
loot:ShowRollPreview()
for index, quality in ipairs({ 4, 4, 3, 3 }) do
    checkColor(env["QUI_LootRollFrame" .. index], quality)
end
assert(#qualityCalls == 12, "live loot, live rolls, and both previews must use C_Item colors")
assert(loot.eventFrame.events.LOOT_SLOT_CHANGED, "replacement must subscribe to native slot changes")
assert(loot.eventFrame.events.CANCEL_ALL_LOOT_ROLLS, "replacement must subscribe to native mass cancellation")
ns.Addon.db.profile.loot.lootUnderMouse = true
env.QUI_LootFrame.scrollFrame:SetVerticalScroll(20)
event("LOOT_OPENED", false, true)
assert(env.QUI_LootFrame.points[4] == 200 and env.QUI_LootFrame.scrollFrame.scrollOffset == 0,
    "native container loot must position the window and reset scrolling")
local anchors = env.QUI_LootFrame.points
env.QUI_LootFrame.scrollFrame:SetVerticalScroll(15)
cursor = 500
items[2].name, items[2].quantity, items[2].quality = "Updated Loot", 5, 2
event("LOOT_SLOT_CHANGED", 2)
assert(env.QUI_LootFrame.points == anchors, "slot refresh must preserve the original loot window position")
assert(env.QUI_LootFrame.scrollFrame.scrollOffset == 15, "slot refresh must preserve scrolling")
checkColor(env.QUI_LootSlot2, 2)
assert(env.QUI_LootSlot2.name.text == "Updated Loot" and env.QUI_LootSlot2.count.text == 5,
    "changed slots must refresh their current item fields")
for index = 4, 40 do items[index] = { texture = 134400, name = "Overflow " .. index, quantity = 1, quality = 2 } end
event("LOOT_OPENED")
checkColor(assert(env.QUI_LootSlot40, "loot must expose slots beyond the original ten-row pool"), 2)
assert(env.QUI_LootFrame.height <= env.UIParent:GetHeight() - 100, "large loot windows must remain within the viewport")
assert(env.QUI_LootFrame.scrollFrame.scrollChild == env.QUI_LootFrame.scrollChild
    and env.QUI_LootFrame.scrollChild.height > env.QUI_LootFrame.height,
    "overflow slots must remain accessible through native scrolling")
local overflowSlot = env.QUI_LootSlot40
modified = true
overflowSlot.scripts.OnClick(overflowSlot)
assert(clicks[#clicks] == "item:40" and env.LootFrame.selectedSlot == nil,
    "modified clicks must use native item actions without looting")
modified = false
overflowSlot.scripts.OnClick(overflowSlot)
assert(clicks[#clicks] == 40 and env.LootFrame.selectedSlot == 40 and env.LootFrame.selectedLootFrame == overflowSlot,
    "overflow slots must preserve native master-loot selection")
assert(env.LootFrame.selectedItemLink == "item:40" and env.LootFrame.selectedItemName == "Overflow 40"
    and env.LootFrame.selectedQuality == 2 and env.LootFrame.selectedTexture == 134400,
    "native master-loot selection must carry current item display data")
assert(hiddenDialogs[#hiddenDialogs] == "CONFIRM_LOOT_DISTRIBUTION" and itemLootedEvents[#itemLootedEvents] == "LootFrame.ItemLooted",
    "ordinary clicks must preserve native dialog cleanup and loot notifications")
for index = 4, 40 do items[index] = nil end
event("LOOT_SLOT_CHANGED", 2)
assert(not overflowSlot:IsShown(), "reused loot windows must hide stale overflow slots")
loot:HideRollPreview()
event("CANCEL_ALL_LOOT_ROLLS")
ns.Addon.db.profile.lootRoll.maxFrames = 2
event("START_LOOT_ROLL", 3, 60000)
event("START_LOOT_ROLL", 4, 60000)
event("START_LOOT_ROLL", 5, 60000)
timerManager.scripts.OnUpdate(timerManager, 0.01)
assert(env.QUI_LootRollFrame1.timer.value == 0.5, "roll progress must use native remaining time")
remainingTimes[5] = 12000
event("CANCEL_LOOT_ROLL", 3)
for _, callback in ipairs(pendingTimers) do callback() end
pendingTimers = {}
timerManager.scripts.OnUpdate(timerManager, 0.01)
assert(env.QUI_LootRollFrame1.rollID == 5 and env.QUI_LootRollFrame1.timer.value == 0.2,
    "a delayed queued roll must retain its native elapsed progress")
event("START_LOOT_ROLL", 6, 60000)
event("CANCEL_LOOT_ROLL", 4)
event("CANCEL_ALL_LOOT_ROLLS")
for _, callback in ipairs(pendingTimers) do callback() end
for index = 1, 8 do
    local frame = env["QUI_LootRollFrame" .. index]
    assert(not frame or not frame:IsShown(), "mass cancellation must hide active rolls and clear queued rolls")
end
nativeRollIDs, remainingTimes[7] = { 7, 99 }, 6000
event("PLAYER_ENTERING_WORLD")
timerManager.scripts.OnUpdate(timerManager, 0.01)
assert(env.QUI_LootRollFrame1.rollID == 7 and env.QUI_LootRollFrame1.timer.value == 0.1,
    "entering world must restore native pending rolls without restarting their clock")
assert(not env.QUI_LootRollFrame2:IsShown(), "missing native duration must not produce a roll frame")
nativeRollIDs = {}
event("PLAYER_ENTERING_WORLD")
assert(not env.QUI_LootRollFrame1:IsShown(), "world transitions must discard stale native rolls")
env.GetActiveLootRollIDs = nil
event("PLAYER_ENTERING_WORLD")
assert(not env.QUI_LootRollFrame1:IsShown(), "clients without native active-roll enumeration must remain supported")
event("START_LOOT_ROLL", 8, 60000)
assert(env.QUI_LootRollFrame1:IsShown() and env.QUI_LootRollFrame1.rollID == 8,
    "a live roll must exist before testing unavailable native enumeration")
event("PLAYER_ENTERING_WORLD")
assert(env.QUI_LootRollFrame1:IsShown() and env.QUI_LootRollFrame1.rollID == 8,
    "world entry without native enumeration must preserve running roll notifications")
ns.Addon.db.profile.lootRoll.enabled = false
event("PLAYER_ENTERING_WORLD")
assert(not env.QUI_LootRollFrame1:IsShown(), "disabled roll notifications must clear even when enumeration is unavailable")
ns.Addon.db.profile.lootRoll.enabled = true
event("LOOT_CLOSED")
local previousItems = items
items = {}
event("LOOT_OPENED", false, true)
assert(not env.QUI_LootFrame:IsShown(), "initial empty loot must retain the existing unopened behavior")
items = previousItems
event("LOOT_OPENED", false, false)
assert(env.QUI_LootSlot1:IsShown(), "loot must be present before testing an empty refresh")
local previousAnchors = env.QUI_LootFrame.points
items = {}
event("LOOT_SLOT_CHANGED", 1)
for _, slot in ipairs(env.QUI_LootFrame.slots) do
    assert(not slot:IsShown(), "empty slot refresh must clear stale visible loot rows")
end
assert(env.QUI_LootFrame.scrollChild.height == 0, "empty slot refresh must clear the scroll content extent")
assert(env.QUI_LootFrame.points == previousAnchors, "empty slot refresh must preserve the existing window position")
print("OK: loot_quality_color_test")
