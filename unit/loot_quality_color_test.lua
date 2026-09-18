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
    return setmetatable({ scripts = {} }, { __index = methods })
end
function methods:CreateTexture() return widget() end
function methods:CreateFontString() return widget() end
function methods:GetHighlightTexture() return widget() end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:SetText(text) self.text = text end
function methods:SetTextColor(...) self.color = { ... } end
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
    if name then env[name] = frame end
    return frame
end
assert(env.GetItemQualityColor == nil, "legacy GetItemQualityColor must be absent")

local ns = {
    Addon = { db = { profile = { loot = { enabled = true }, lootRoll = { enabled = true } } } },
    Helpers = {
        CreateStateTable = function() return {} end,
        SetFrameBackdropColor = noop,
        SetFrameBackdropBorderColor = function(frame, ...) frame.borderColor = { ... } end,
    },
    SkinBase = {
        CHROME = { BORDER_PX = 1 },
        GetSkinColors = function() return 1, 1, 1, 1, 0, 0, 0, 1 end,
        ApplyPixelBackdrop = noop,
        SetPixelPoint = noop,
        CreateCloseButton = widget,
    },
    LSM = { Fetch = function() return "test-font" end },
    L = { Loot = "Loot" },
}
local chunk = assert(loadfile("modules/skinning/notifications/loot.lua", "t", env))
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

event("LOOT_OPENED", true)
assert(env.QUI_LootFrame:IsShown(), "loot window should open")
assert(env.QUI_LootFrame.height == 142, "all three loot slots should be laid out")
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
print("OK: loot_quality_color_test")
