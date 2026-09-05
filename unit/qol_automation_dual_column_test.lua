local function NewFrame()
    return {
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetJustifyH = function() end,
        SetWordWrap = function() end,
        SetHeight = function(self, height) self.height = height end,
        GetHeight = function(self) return self.height end,
    }
end

_G.CreateFrame = NewFrame
local general = {}
local rows, headers = {}, {}
local gui = { Colors = { textMuted = {} } }
function gui:CreateLabel() return NewFrame() end
function gui:CreateFormCheckbox(_, _, key, db, callback)
    return { key = key, db = db, callback = callback }
end
function gui:CreateFormDropdown(parent, label, _, key, db, callback)
    return self:CreateFormCheckbox(parent, label, key, db, callback)
end
function gui:CreateFormSlider(parent, label, _, _, _, key, db, callback)
    return self:CreateFormCheckbox(parent, label, key, db, callback)
end
_G.QUI = { GUI = gui }

local ns = { QUI_Options = {
    GetDB = function() return { general = general } end,
    GetSoundList = function() return {} end,
    CreateAccentDotLabel = function(_, text)
        headers[#headers + 1] = text
        return NewFrame()
    end,
    BuildSettingRow = function(_, label, widget)
        return { label = label, widget = widget }
    end,
    CreateSettingsCardGroup = function()
        local frame = NewFrame()
        return {
            frame = frame,
            AddRow = function(left, right) rows[#rows + 1] = { left, right } end,
            Finalize = function() frame:SetHeight(#rows * 32) end,
        }
    end,
} }
local refreshed = {}
for _, name in ipairs({
    "RefreshWorldMapTeleports", "RefreshFocusMarker", "RefreshHealerMana",
    "RefreshDeathAlert", "ApplyPreferredAudioDevice", "RefreshCollectionFanfare",
    "RefreshEJLootSpecIcons", "RefreshGemPicker", "RefreshMailContacts",
}) do
    ns[name] = function() refreshed[name] = (refreshed[name] or 0) + 1 end
end
_G.QUI_RefreshAutoCombatLogging = function()
    refreshed.combatLogging = (refreshed.combatLogging or 0) + 1
end

(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
assert(loadfile(arg[1] or "modules/qol/settings/qol_content.lua"))("QUI", ns)
assert(ns.QUI_QoLOptions.BuildGeneralTab(NewFrame(), nil, "automation") > 0)
assert(#headers == 1 and headers[1] == "Automation", "must build only Automation")

local expected = {
    general = [[sellJunk autoRepair fastAutoLoot autoAcceptInvites autoAcceptSummons
        autoRoleAccept autoAcceptQuest autoTurnInQuest autoSelectGossip questHoldShift
        autoInsertKey closeBagsOnKeystoneInsert autoCombatLog autoCombatLogRaid
        mplusTeleportEnabled autoDeleteConfirm worldMapTeleports auctionHouseExpansionFilter
        craftingOrderExpansionFilter autoDeclineDuel autoDeclinePetBattle autoRelease
        blockReleaseInRaid audioOutputDevice autoUnwrapCollections autoConfirmSocketReplace
        autoConfirmTokenPurchase autoConfirmHighCost ejLootSpecIcons gemSocketPicker
        mailContactsPanel mailRememberRecipient]],
    focusMarker = "enabled marker useMouseover writeMacro",
    healerMana = "enabled instanceOnly",
    deathAlert = "enabled sound showKillingBlow showKiller classColorName instanceOnly duration",
    tradeMailLog = "enabled logTrades logSentMail logReceivedMail",
}
local remaining, expectedCount = {}, 0
for group, keys in pairs(expected) do
    local db = group == "general" and general or general[group]
    assert(type(db) == "table", "missing settings group: " .. group)
    remaining[db] = {}
    for key in keys:gmatch("%S+") do
        remaining[db][key] = true
        expectedCount = expectedCount + 1
    end
end

local actualCount, blankCount = 0, 0
for index, cells in ipairs(rows) do
    assert(cells[1] and cells[2], "Automation row " .. index .. " must have two columns")
    for column, cell in ipairs(cells) do
        local widget = cell.widget
        if widget then
            assert(type(cell.label) == "string" and cell.label ~= "", "missing setting label")
            assert(remaining[widget.db] and remaining[widget.db][widget.key],
                "unexpected or duplicate binding: " .. tostring(widget.key))
            remaining[widget.db][widget.key] = nil
            actualCount = actualCount + 1
            if widget.callback then widget.callback() end
        else
            assert(column == 2 and index == #rows, "blank cell must be last")
            blankCount = blankCount + 1
        end
    end
end
assert(actualCount == expectedCount, "Automation must retain every setting")
assert(#rows == math.ceil(expectedCount / 2), "Automation rows must be densely paired")
assert(blankCount == expectedCount % 2, "only an odd setting count needs a blank cell")
assert(refreshed.combatLogging == 2, "combat logging callbacks must remain connected")
assert(refreshed.RefreshFocusMarker == 4, "focus marker callbacks must remain connected")
assert(refreshed.RefreshHealerMana == 2, "healer mana callbacks must remain connected")
assert(refreshed.RefreshDeathAlert == 6, "death alert callbacks must remain connected")
for _, name in ipairs({
    "RefreshWorldMapTeleports", "ApplyPreferredAudioDevice", "RefreshCollectionFanfare",
    "RefreshEJLootSpecIcons", "RefreshGemPicker", "RefreshMailContacts",
}) do
    assert(refreshed[name] == 1, name .. " callback must remain connected")
end
print("qol_automation_dual_column_test: ok (" .. actualCount .. " settings)")
