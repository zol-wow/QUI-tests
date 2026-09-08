-- tests/unit/alts_weeklies_view_test.lua
-- Run: lua tests/unit/alts_weeklies_view_test.lua

local ns = {}
ns.L = setmetatable({}, { __index = function(_, k) return k end })

ns.Helpers = {
    GetGeneralFont        = function() return "Fonts\\FRIZQT__.TTF" end,
    GetGeneralFontOutline = function() return "" end,
}
ns.Storage = { Store = {}, Bus = {} }

-- Provide RosterData.FormatResetIn for LockoutLine.
ns.Alts = {
    RosterData = {
        FormatResetIn = function(resetAt, now)
            if not resetAt then return "—" end
            local left = resetAt - (now or 0)
            if left <= 0 then return "expired" end
            local d = math.floor(left / 86400)
            local h = math.floor((left % 86400) / 3600)
            if d > 0 then return string.format("%dd %dh", d, h) end
            local m = math.floor((left % 3600) / 60)
            if h > 0 then return string.format("%dh %dm", h, m) end
            return string.format("%dm", math.max(m, 1))
        end,
    },
    Window = { RegisterTab = function() end },
}

assert(loadfile("modules/alts/views/shared.lua"))("QUI", ns)
assert(loadfile("modules/alts/views/weeklies.lua"))("QUI", ns)

local WV = ns.Alts.WeekliesView
assert(WV, "WeekliesView exported")

local cellTexts = WV.CellTexts({
    kind = "char",
    name = "Arel",
    weeklies = {
        mplusRating = 2475,
        keystoneMapID = 100,
        keystoneName = "The Stonevault",
        keystoneLevel = 12,
        activities = {
            { type = 1, threshold = 1, progress = 1 },
        },
    },
})
assert(cellTexts[1] == "Arel", "character cell text")
assert(cellTexts[2] == "2475", "rating cell text")
assert(cellTexts[3] == "The Stonevault +12", "keystone cell text")
assert(cellTexts[4] == "R 1/1", "vault cell text uses compact label")
assert(cellTexts[5] == "Unknown", "missing lockout scan is unknown")
assert(WV.CellTexts({ kind = "char", lockouts = {} })[5] == "None", "scanned empty lockouts")
assert(WV.CellTexts({ kind = "char", lockouts = { {}, {} } })[5] == "2 saved", "saved count summary")
assert(WV.CellTexts({ kind = "lockout" }) == nil, "details use dedicated lockout cells")

local widths = WV.ColumnWidths({
    { kind = "char", name = "Long Character Name", weeklies = {} },
    { kind = "char", name = "A", weeklies = {
        keystoneMapID = 1,
        keystoneName = "Very Long Keystone Name",
        keystoneLevel = 8,
    } },
}, function(text) return #text + 0.25 end)
assert(widths[1] == #"Long Character Name" + 13, "character width uses widest row and ceiling")
assert(widths[2] == #"M+ Rating" + 13, "rating width uses header")
assert(widths[3] == #"Very Long Keystone Name +8" + 13, "keystone width uses widest row")
assert(widths[4] == #"Great Vault" + 13, "vault width uses header")

---------------------------------------------------------------------------
-- VaultSummary: nil / empty
---------------------------------------------------------------------------
assert(WV.VaultSummary(nil)           == "—", "nil weeklies → —")
assert(WV.VaultSummary({})            == "—", "no activities key → —")
assert(WV.VaultSummary({ activities = {} }) == "—", "empty activities → —")

---------------------------------------------------------------------------
-- VaultSummary: single type, all slots completed
---------------------------------------------------------------------------
local w_raid_full = {
    activities = {
        { type = 1, index = 1, threshold = 1, progress = 2 },
        { type = 1, index = 2, threshold = 3, progress = 4 },
        { type = 1, index = 3, threshold = 8, progress = 8 },
    }
}
-- Raid type 1: all 3 completed → "Raid 3/3"
local got = WV.VaultSummary(w_raid_full)
assert(got == "Raid 3/3", "raid all 3: " .. got)

---------------------------------------------------------------------------
-- VaultSummary: mixed progress, two types
---------------------------------------------------------------------------
-- Raid type 1: 1 completed out of 3; Dungeons type 2: 2 completed out of 3.
local w_mixed = {
    activities = {
        { type = 1, index = 1, threshold = 1,  progress = 2 },   -- Raid complete
        { type = 1, index = 2, threshold = 4,  progress = 3 },   -- Raid incomplete
        { type = 1, index = 3, threshold = 8,  progress = 1 },   -- Raid incomplete
        { type = 2, index = 1, threshold = 1,  progress = 5 },   -- Dungeons complete
        { type = 2, index = 2, threshold = 4,  progress = 8 },   -- Dungeons complete
        { type = 2, index = 3, threshold = 10, progress = 3 },   -- Dungeons incomplete
    }
}
got = WV.VaultSummary(w_mixed)
assert(got == "Raid 1/3 · Dungeons 2/3", "mixed: " .. got)
assert(WV.VaultSummary(w_mixed, true) == "R 1/3 · D 2/3", "compact vault preserves each activity progress")

---------------------------------------------------------------------------
-- VaultSummary: unknown type falls back to "Type N"
---------------------------------------------------------------------------
local w_unknown = {
    activities = {
        { type = 99, index = 1, threshold = 5, progress = 5 },
    }
}
got = WV.VaultSummary(w_unknown)
assert(got == "Type 99 1/1", "unknown type label: " .. got)

---------------------------------------------------------------------------
-- VaultSummary: World type (3) and PvP (4)
---------------------------------------------------------------------------
local w_world = {
    activities = {
        { type = 3, index = 1, threshold = 1, progress = 0 },
        { type = 4, index = 1, threshold = 1, progress = 1 },
    }
}
got = WV.VaultSummary(w_world)
assert(got == "World 0/1 · PvP 1/1", "world + pvp: " .. got)
assert(WV.VaultSummary(w_world, true) == "W 0/1 · PvP 1/1", "compact world and PvP labels")

---------------------------------------------------------------------------
-- KeystoneText
---------------------------------------------------------------------------
assert(WV.KeystoneText(nil) == "—",        "nil weeklies → —")
assert(WV.KeystoneText({})  == "—",        "no mapID → —")

-- No level (nil level with mapID present)
local w_ks_nolevel = { keystoneMapID = 100, keystoneName = "Ara-Kara" }
got = WV.KeystoneText(w_ks_nolevel)
assert(got == "Ara-Kara +?", "no level → name +?: " .. got)

-- Normal keystone
local w_ks_normal = { keystoneMapID = 100, keystoneName = "The Stonevault", keystoneLevel = 12 }
got = WV.KeystoneText(w_ks_normal)
assert(got == "The Stonevault +12", "normal keystone: " .. got)

-- mapID present but no name (nil name)
local w_ks_noname = { keystoneMapID = 200, keystoneLevel = 7 }
got = WV.KeystoneText(w_ks_noname)
assert(got == "+7", "no name, has level: " .. got)

-- mapID present, no name, no level
local w_ks_neither = { keystoneMapID = 200 }
got = WV.KeystoneText(w_ks_neither)
assert(got == "+?", "no name no level: " .. got)

---------------------------------------------------------------------------
-- LockoutLine: normal with boss counts
---------------------------------------------------------------------------
-- now = 1000, resetAt = 1000 + 2*86400 + 5*3600 = 1000 + 190800 = 191800
local now = 1000
local lo_normal = {
    name           = "Amirdrassil",
    difficultyName = "Mythic",
    bossesKilled   = 8,
    bossesTotal    = 9,
    resetAt        = now + 2 * 86400 + 5 * 3600,
    extended       = nil,
}
got = WV.LockoutLine(lo_normal, now)
assert(got == "Amirdrassil Mythic 8/9 — resets 2d 5h",
    "normal lockout: " .. got)

---------------------------------------------------------------------------
-- LockoutLine: nil boss counts → omit progress
---------------------------------------------------------------------------
local lo_noboss = {
    name           = "Nerub-ar Palace",
    difficultyName = "Heroic",
    bossesKilled   = nil,
    bossesTotal    = nil,
    resetAt        = now + 86400,
}
got = WV.LockoutLine(lo_noboss, now)
assert(got == "Nerub-ar Palace Heroic — resets 1d 0h",
    "nil boss counts: " .. got)

---------------------------------------------------------------------------
-- LockoutLine: partial nil (one of killed/total nil) → omit progress
---------------------------------------------------------------------------
local lo_partial = {
    name         = "Blackrock Depths",
    bossesKilled = 3,
    bossesTotal  = nil,
    resetAt      = now + 3600,
}
got = WV.LockoutLine(lo_partial, now)
assert(got == "Blackrock Depths — resets 1h 0m",
    "partial nil boss: " .. got)

---------------------------------------------------------------------------
-- LockoutLine: extended suffix
---------------------------------------------------------------------------
local lo_extended = {
    name           = "Amirdrassil",
    difficultyName = "Normal",
    bossesKilled   = 9,
    bossesTotal    = 9,
    resetAt        = now + 86400,
    extended       = true,
}
got = WV.LockoutLine(lo_extended, now)
assert(got == "Amirdrassil Normal 9/9 — resets 1d 0h (extended)",
    "extended: " .. got)

---------------------------------------------------------------------------
-- LockoutLine: expired reset
---------------------------------------------------------------------------
local lo_expired = {
    name     = "Ulduar",
    resetAt  = now - 100,
}
got = WV.LockoutLine(lo_expired, now)
assert(got == "Ulduar — resets expired",
    "expired: " .. got)

---------------------------------------------------------------------------
-- LockoutLine: nil lockout
---------------------------------------------------------------------------
got = WV.LockoutLine(nil, now)
assert(got == "", "nil lockout → empty string: " .. tostring(got))

---------------------------------------------------------------------------
-- BuildDisplayRows: empty
---------------------------------------------------------------------------
local rows = WV.BuildDisplayRows({})
assert(#rows == 0, "empty chars → 0 rows")

rows = WV.BuildDisplayRows(nil)
assert(#rows == 0, "nil chars → 0 rows")

---------------------------------------------------------------------------
-- BuildDisplayRows: name-asc order + lockouts interleaved after character
---------------------------------------------------------------------------
local chars = {
    ["Zara-Realm"] = {
        name    = "Zara",
        details = { class = "MAGE" },
        weeklies = { mplusRating = 1200 },
        lockouts = {
            { name = "L1", resetAt = 9999 },
            { name = "L2", resetAt = 9999 },
        },
    },
    ["Arel-Realm"] = {
        name    = "Arel",
        details = { class = "WARRIOR" },
        weeklies = nil,
        lockouts = nil,
    },
    ["Mira-Realm"] = {
        name    = "Mira",
        details = { class = "DRUID" },
        weeklies = {},
        lockouts = {
            { name = "L3", resetAt = 9999 },
        },
    },
}

rows = WV.BuildDisplayRows(chars)

-- Expected order: Arel(char), Mira(char), L3(lockout), Zara(char), L1(lockout), L2(lockout)
assert(#rows == 6, "6 rows total: " .. #rows)

assert(rows[1].kind == "char"    and rows[1].name == "Arel", "row1 = Arel char: " .. tostring(rows[1].name))
assert(rows[2].kind == "char"    and rows[2].name == "Mira", "row2 = Mira char: " .. tostring(rows[2].name))
assert(rows[3].kind == "lockout" and rows[3].lockout.name == "L3", "row3 = L3 lockout")
assert(rows[4].kind == "char"    and rows[4].name == "Zara", "row4 = Zara char: " .. tostring(rows[4].name))
assert(rows[5].kind == "lockout" and rows[5].lockout.name == "L1", "row5 = L1 lockout")
assert(rows[6].kind == "lockout" and rows[6].lockout.name == "L2", "row6 = L2 lockout")

-- char rows carry weeklies
assert(rows[4].weeklies and rows[4].weeklies.mplusRating == 1200,
    "Zara char row carries weeklies")

-- char rows carry class
assert(rows[1].class == "WARRIOR", "Arel class: " .. tostring(rows[1].class))

assert(type(widths[5]) == "number" and widths[5] > 0, "lockouts has a fifth column")
assert(rows[4].lockouts == chars["Zara-Realm"].lockouts, "character retains lockout summary source")
assert(rows[3].key == "Mira-Realm" and rows[3].groupIndex == rows[2].groupIndex,
    "detail rows retain parent identity and band")
assert(rows[5].key == "Zara-Realm" and rows[6].groupIndex == rows[4].groupIndex,
    "all details share their character band")
assert(rows[1].groupIndex ~= rows[2].groupIndex, "adjacent characters have distinct bands")

local collapsed = { ["Mira-Realm"] = true }
local compact = WV.BuildDisplayRows(chars, collapsed)
assert(#compact == 5 and compact[3].name == "Zara", "individual collapse hides only its details")
assert(compact[2].lockouts == chars["Mira-Realm"].lockouts, "collapsed character retains summary")
assert(compact[3].groupIndex == rows[4].groupIndex, "collapse preserves later character band")
collapsed["Zara-Realm"] = true
assert(#WV.BuildDisplayRows(chars, collapsed) == 3, "collapse all leaves one row per character")
collapsed["Mira-Realm"] = nil
assert(#WV.BuildDisplayRows(chars, collapsed) == 4, "individual expansion restores details")
assert(#WV.BuildDisplayRows(chars, {}) == 6, "expand all restores every detail")

local cells = WV.LockoutCells(lo_normal, now)
assert(cells[1] == "Amirdrassil" and cells[2] == "Mythic", "instance and difficulty are separate")
assert(cells[3] == "8/9" and cells[4] == "2d 5h", "boss progress and reset are separate")
assert(WV.LockoutCells(lo_partial, now)[3] == "—", "partial boss counts remain unknown")
assert(WV.LockoutCells(lo_extended, now)[4] == "1d 0h (extended)", "extended status remains visible")
assert(WV.LockoutCells(lo_expired, now)[4] == "expired", "expired reset remains explicit")

local objects = {}
local methods = {}
local function widget(parent)
    local obj = setmetatable({ parent = parent, scripts = {}, shown = true, points = {} }, { __index = methods })
    objects[#objects + 1] = obj
    return obj
end
for _, method in ipairs({ "SetFont", "SetWordWrap", "SetTextColor", "SetJustifyH", "EnableMouseWheel",
    "SetAllPoints", "SetTexture", "SetVertexColor", "SetColorTexture", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "RegisterForClicks", "SetHighlightTexture", "SetNormalTexture", "SetPushedTexture" }) do
    methods[method] = function() end
end
function methods:SetVertexColor(...) self.vertexColor = { ... } end
function methods:GetScript(event) return self.scripts[event] end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetWidth(v) self.width = v end
function methods:SetHeight(v) self.height = v end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 1200 end
function methods:GetHeight() return self.height or 300 end
function methods:SetText(v) self.text = v end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #(self.text or "") * 6 end
methods.GetUnboundedStringWidth = methods.GetStringWidth
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsMouseOver() return self.mouseOver or false end
function methods:IsVisible() return self.shown end
function methods:SetShown(v) self.shown = v end
function methods:CreateFontString() return widget(self) end
function methods:CreateTexture() return widget(self) end
function methods:SetNormalFontObject() end
function methods:SetHighlightFontObject() end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetEnabled(v) self.enabled = v end

_G.GameTooltip = widget()
function _G.GameTooltip:SetOwner(owner, anchor, x, y)
    self.owner, self.anchor, self.offsetX, self.offsetY = owner, anchor, x, y
end
function _G.GameTooltip:SetText(text) self.text, self.lines = text, {} end
function _G.GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end

_G.CreateFrame = function(_, _, parent) return widget(parent) end
local scroll
ns.AltsViewShared.CreateScrollBar = function(parent, opts)
    scroll = { track = widget(parent), onScroll = opts.onScroll }
    function scroll:Update(total, visible, offset)
        self.total, self.visible, self.offset = total, visible, offset
    end
    return scroll
end
ns.UIKit = { CreateButton = function(parent, opts)
    local button = widget(parent)
    button:SetText(opts.text)
    button:SetScript("OnClick", opts.onClick)
    return button
end }
local builder
ns.Alts.Window.RegisterTab = function(_, _, fn) builder = fn end
local subscriptions = {}
ns.Storage.Store = {
    IsInitialized = function() return true end,
    ListCharacters = function() return { "Zara-Realm", "Arel-Realm", "Mira-Realm" } end,
    GetCharacter = function(key) return chars[key] end,
}
ns.Storage.Bus.Subscribe = function(event, callback) subscriptions[event] = callback end
assert(loadfile("modules/alts/views/weeklies.lua"))("QUI", ns)
local view = builder(widget())
view.Refresh()
assert(scroll.total == 6, "builder initially expands every lockout")

local function clickLabel(label)
    for _, obj in ipairs(objects) do
        if obj.text == label then
            local button = obj.scripts.OnClick and obj or obj.parent
            assert(button.scripts.OnClick, "clickable control: " .. label)
            button.scripts.OnClick(button)
            return
        end
    end
    error("missing control: " .. label)
end
clickLabel("Collapse all")
assert(scroll.total == 3, "collapse all button leaves character rows")
view.Refresh()
assert(scroll.total == 3, "data refresh preserves collapse choices")
clickLabel("Expand all")
assert(scroll.total == 6, "expand all button restores all lockouts")

local function visibleRow(key, kind)
    for _, obj in ipairs(objects) do
        if obj.shown and obj._row and obj._row.key == key and obj._row.kind == kind then return obj end
    end
    error("missing visible row: " .. key .. " " .. kind)
end
local mira = visibleRow("Mira-Realm", "char")
assert(mira._toggle.shown, "saved instances have an individual toggle")
mira._toggle.scripts.OnClick(mira._toggle)
assert(scroll.total == 5, "individual button hides only one character's lockouts")
subscriptions.LockoutsChanged()
assert(scroll.total == 5, "lockout event preserves individual collapse")
mira = visibleRow("Mira-Realm", "char")
mira._toggle.scripts.OnClick(mira._toggle)
assert(scroll.total == 6, "individual button expands its details again")
assert(not visibleRow("Arel-Realm", "char")._toggle.shown, "unknown lockouts have no toggle")
local zara = visibleRow("Zara-Realm", "char")
local detail = visibleRow("Zara-Realm", "lockout")
assert(detail._details[1].points[1][4] > zara._cells[4].points[1][4], "details sit in fifth column")
assert(detail._details[2].points[1][4] > detail._details[1].points[1][4], "detail fields align separately")

view.frame:SetHeight(132)
view.frame.scripts.OnSizeChanged(view.frame)
assert(scroll.visible < 6, "short viewport requires scrolling")
scroll.onScroll(2)
assert(scroll.offset == 2, "scrollbar moves the viewport")
local firstDetail = visibleRow("Mira-Realm", "lockout")
assert(firstDetail._cells[1].shown and firstDetail._cells[1].text == "Mira",
    "first visible detail retains character identity")
clickLabel("Collapse all")
assert(scroll.total == 3 and scroll.offset == 0, "global collapse resets scroll")
clickLabel("Expand all")
assert(scroll.total == 6 and scroll.offset == 0, "global expand resets scroll")

for _, budget in ipairs({ 720, 1200, 1600 }) do
    local fitted = WV.ColumnWidths(rows, function(text) return #text * 6 end, budget)
    local total = 0
    for _, width in ipairs(fitted) do
        assert(width > 0, "fitted columns remain positive")
        total = total + width
    end
    assert(math.abs(total - budget) < 0.01, "columns fit available width")
end

view.frame:SetHeight(300)
view.frame.scripts.OnSizeChanged(view.frame)
clickLabel("Collapse all")
mira = visibleRow("Mira-Realm", "char")
mira.scripts.OnEnter(mira)
assert(GameTooltip.anchor == "ANCHOR_CURSOR_RIGHT", "character tooltip anchors at cursor")
assert(GameTooltip.offsetX == 12 and GameTooltip.offsetY == 12, "tooltip stays above and right of cursor")
assert(mira._bg.vertexColor[4] > 0, "collapsed character row highlights on hover")
local function hasExpandHint()
    for _, line in ipairs(GameTooltip.lines) do
        if line == "Click to expand for details" then return true end
    end
    return false
end
assert(hasExpandHint(), "collapsed saved row offers expansion hint")
mira.scripts.OnLeave(mira)
assert(mira._bg.vertexColor[4] == 0 and not GameTooltip.shown, "row leave clears highlight and tooltip")
assert(mira._toggle.scripts.OnEnter, "lockout toggle forwards hover")
mira._toggle.scripts.OnEnter(mira._toggle)
assert(mira._bg.vertexColor[4] > 0 and GameTooltip.shown, "toggle hover highlights whole character row")
assert(GameTooltip.owner == mira and GameTooltip.anchor == "ANCHOR_CURSOR_RIGHT", "toggle tooltip belongs to character at cursor")
assert(hasExpandHint(), "collapsed toggle offers expansion hint")
mira._toggle.scripts.OnLeave(mira._toggle)
assert(mira._bg.vertexColor[4] == 0 and not GameTooltip.shown, "toggle leave clears row highlight and tooltip")

mira.mouseOver = true
mira.scripts.OnClick(mira)
assert(GameTooltip.shown and not hasExpandHint(), "hovered row click immediately updates tooltip hint")
mira.mouseOver = false
assert(scroll.total == 4, "clicking character row expands its details")
mira = visibleRow("Mira-Realm", "char")
mira.scripts.OnEnter(mira)
assert(not hasExpandHint(), "expanded row omits expansion hint")
mira.scripts.OnLeave(mira)
local miraDetail = visibleRow("Mira-Realm", "lockout")
miraDetail.scripts.OnEnter(miraDetail)
assert(GameTooltip.anchor == "ANCHOR_CURSOR_RIGHT" and not hasExpandHint(), "detail tooltip uses cursor with no expansion hint")
miraDetail.scripts.OnLeave(miraDetail)
miraDetail.scripts.OnClick(miraDetail)
assert(scroll.total == 4, "detail row click cannot toggle a character")
mira._toggle.scripts.OnClick(mira._toggle)
assert(scroll.total == 3, "toggle still collapses after row click expansion")

clickLabel("Expand all")
local arel = visibleRow("Arel-Realm", "char")
arel.scripts.OnEnter(arel)
assert(not hasExpandHint(), "unknown lockouts omit expansion hint")
arel.scripts.OnLeave(arel)
arel.scripts.OnClick(arel)
assert(scroll.total == 6, "unknown lockouts cannot toggle")
chars["Arel-Realm"].lockouts = { { name = "New raid" } }
view.Refresh()
assert(scroll.total == 7, "clicking unknown row did not create hidden collapse state")
chars["Arel-Realm"].lockouts = {}
view.Refresh()
arel = visibleRow("Arel-Realm", "char")
arel.scripts.OnEnter(arel)
assert(not hasExpandHint(), "empty lockouts omit expansion hint")
arel.scripts.OnLeave(arel)
arel.scripts.OnClick(arel)
assert(scroll.total == 6 and not arel._toggle.shown, "empty lockouts cannot toggle")
chars["Arel-Realm"].lockouts = { { name = "New raid" } }
view.Refresh()
assert(scroll.total == 7, "clicking empty row did not create hidden collapse state")
chars["Arel-Realm"].lockouts = nil

local crowdedRows = {
    { kind = "char", name = string.rep("LongCharacter", 4), weeklies = {
        keystoneMapID = 1, keystoneName = string.rep("LongDungeon", 8), keystoneLevel = 12,
        activities = w_mixed.activities,
    } },
}
local function textWidth(text) return #text * 6 end
local naturalWidths = WV.ColumnWidths(crowdedRows, textWidth)
local crowdedWidths = WV.ColumnWidths(crowdedRows, textWidth, 720)
assert(crowdedWidths[4] == naturalWidths[4], "compact vault keeps natural width despite long character and keystone")
local crowdedTotal = 0
for _, width in ipairs(crowdedWidths) do crowdedTotal = crowdedTotal + width end
assert(crowdedTotal == 720, "preserving vault width still fits viewport")
assert(crowdedWidths[3] < naturalWidths[3], "long keystone gives space to readable vault progress")
chars["Mira-Realm"].weeklies = w_mixed
view.Refresh()
mira = visibleRow("Mira-Realm", "char")
assert(mira._cells[4].text == "R 1/3 · D 2/3", "rendered vault uses compact text")
mira.scripts.OnEnter(mira)
local fullVaultTooltip = false
for _, line in ipairs(GameTooltip.lines) do
    if line == "Great Vault: Raid 1/3 · Dungeons 2/3" then fullVaultTooltip = true end
end
assert(fullVaultTooltip, "vault tooltip retains full activity names")
mira.scripts.OnLeave(mira)

local previousEnum = _G.Enum
_G.Enum = { WeeklyRewardChestThresholdType = { Raid = 11, Activities = 12 } }
assert(loadfile("modules/alts/views/weeklies.lua"))("QUI", ns)
local remappedVault = { activities = {
    { type = 11, threshold = 1, progress = 1 },
    { type = 12, threshold = 1, progress = 0 },
} }
assert(ns.Alts.WeekliesView.VaultSummary(remappedVault, true) == "R 1/1 · D 0/1",
    "compact labels follow native activity enum values")
assert(ns.Alts.WeekliesView.VaultSummary(remappedVault) == "Raid 1/1 · Dungeons 0/1",
    "full labels follow native activity enum values")
_G.Enum = previousEnum

print("OK: alts_weeklies_view_test")
