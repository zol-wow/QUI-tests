-- tests/unit/alts_equipment_view_test.lua
-- Run: lua tests/unit/alts_equipment_view_test.lua
-- Covers the PURE parts of the equipment tab:
--   EquipmentView.BuildSlotRows (order, optional-slot elision)
--   EquipmentView.BuildColumns  (name sort, key fallback)

local ns = {}
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.Helpers = {
    GetGeneralFont        = function() return "Fonts\\FRIZQT__.TTF" end,
    GetGeneralFontOutline = function() return "" end,
}
ns.Storage = { Store = {}, Bus = {} }

-- equipment.lua calls Alts.Window.RegisterTab at file end; stub it.
ns.Alts = { Window = { RegisterTab = function() end } }

assert(loadfile("modules/alts/views/shared.lua"))("QUI", ns)
assert(loadfile("modules/alts/views/equipment.lua"))("QUI", ns)

local EV = ns.Alts.EquipmentView
assert(EV, "EquipmentView exported")

---------------------------------------------------------------------------
-- BuildSlotRows
---------------------------------------------------------------------------
do
    -- no char has shirt(4)/ranged(18)/tabard(19) → those rows elided
    local chars = {
        a = { equipped = { slots = { [1] = { itemID = 1 }, [16] = { itemID = 2 } } } },
        b = { equipped = { slots = { [2] = { itemID = 3 } } } },
    }
    local rows = EV.BuildSlotRows(chars)
    assert(#rows == 16, "16 mandatory slots: " .. #rows)
    assert(rows[1].slot == 1 and rows[1].label == "Head", "first row Head")
    for _, r in ipairs(rows) do
        assert(r.slot ~= 4 and r.slot ~= 18 and r.slot ~= 19, "optional slots elided")
    end

    -- a tabard on ONE char brings the row back for all
    chars.b.equipped.slots[19] = { itemID = 9 }
    rows = EV.BuildSlotRows(chars)
    assert(#rows == 17, "tabard row restored: " .. #rows)
    local found
    for _, r in ipairs(rows) do
        if r.slot == 19 then found = r.label end
    end
    assert(found == "Tabard", "tabard labeled")

    -- phase-1 record shape (equipped = {} without .slots) must not error
    local legacy = { c = { equipped = {} }, d = {} }
    rows = EV.BuildSlotRows(legacy)
    assert(#rows == 16, "legacy/empty records → mandatory slots only")
end

---------------------------------------------------------------------------
-- BuildColumns
---------------------------------------------------------------------------
do
    local chars = {
        ["Zed-Realm"] = { name = "Zed" },
        ["Abe-Realm"] = {},               -- no name → key fallback
    }
    local cols = EV.BuildColumns(chars)
    assert(#cols == 2, "two columns")
    assert(cols[1].key == "Abe-Realm" and cols[1].name == "Abe-Realm", "key fallback + sort")
    assert(cols[2].name == "Zed", "rec.name used")

    assert(#EV.BuildColumns({}) == 0, "empty chars → no columns")
    assert(#EV.BuildColumns(nil) == 0, "nil chars → no columns")
end

do
    local chars = {
        ["Same-RealmA"] = { name = "Same" },
        ["Same-RealmB"] = { name = "Same" },
        ["Other-Realm"] = { name = "Other" },
    }
    local columns = EV.BuildColumns(chars, { ["Same-RealmA"] = true })
    assert(#columns == 2, "hidden characters excluded")
    assert(columns[2].key == "Same-RealmB", "same-name characters filtered by full key")
    assert(#EV.BuildColumns(chars, {}) == 3, "empty filter shows every character")
    assert(#EV.BuildColumns(chars, {
        ["Same-RealmA"] = true, ["Same-RealmB"] = true, ["Other-Realm"] = true,
    }) == 0, "all characters can be hidden")
end

do
    local chars = {
        ["Same-B"] = { name = "Same", details = { level = 80, ilvl = 150 } },
        ["Same-A"] = { name = "Same", details = { level = 80, ilvl = 150 } },
        ["Zed-R"] = { name = "Zed", details = { level = 90, ilvl = 100 } },
        ["Abe-R"] = { name = "Abe", details = { ilvl = 200 } },
        ["Unknown-R"] = { name = "Unknown" },
    }
    local cols = EV.BuildColumns(chars, nil, "level")
    assert(cols[1].key == "Zed-R" and cols[1].level == 90, "level sort puts highest first and exposes level")
    assert(cols[2].key == "Same-A" and cols[3].key == "Same-B", "level ties sort by name and realm key")
    assert(cols[4].key == "Abe-R" and cols[5].key == "Unknown-R", "unknown levels sort last by name")
    cols = EV.BuildColumns(chars, nil, "ilvl")
    assert(cols[1].key == "Abe-R" and cols[1].ilvl == 200, "item level sort puts highest first and exposes ilvl")
    assert(cols[2].key == "Same-A" and cols[3].key == "Same-B", "item level ties sort by full key")
    assert(cols[5].key == "Unknown-R", "unknown item levels sort last")
    cols = EV.BuildColumns(chars, { ["Zed-R"] = true }, "level")
    assert(#cols == 4 and cols[1].key == "Same-A", "sorting respects character filter")
    cols = EV.BuildColumns(chars, nil, "name")
    assert(cols[1].key == "Abe-R" and cols[5].key == "Zed-R", "explicit name sorting remains alphabetical")
end

local objects, methods = {}, {}
local function widget(parent)
    local obj = setmetatable({ parent = parent, scripts = {}, shown = true, points = {} }, { __index = methods })
    objects[#objects + 1] = obj
    return obj
end
for _, method in ipairs({ "SetFont", "SetWordWrap", "SetTextColor", "SetJustifyH", "EnableMouseWheel",
    "SetAllPoints", "SetVertexColor", "SetColorTexture", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "RegisterForClicks", "SetHighlightTexture", "SetNormalTexture", "SetPushedTexture",
    "SetFrameStrata", "EnableMouse", "SetAutoFocus", "SetTextInsets", "SetMaxLetters", "ClearFocus" }) do
    methods[method] = function() end
end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetWidth(v) self.width = v end
function methods:SetHeight(v) self.height = v end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width or 600 end
function methods:GetHeight() return self.height or 340 end
function methods:SetText(v)
    self.text = v
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:HasFocus() return false end
function methods:GetText() return self.text end
function methods:SetTexture(v) self.texture = v end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetShown(v) self.shown = v end
function methods:CreateFontString() return widget(self) end
function methods:CreateTexture() return widget(self) end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetEnabled(v) self.enabled = v end
_G.UIParent = widget()
_G.CreateFrame = function(kind, name, parent, template)
    local frame = widget(parent)
    frame.kind, frame.name, frame.template = kind, name, template
    if name then _G[name] = frame end
    return frame
end
local function loadNativeFunction(path, name)
    local file = assert(io.open(path, "r"))
    local source = file:read("*a")
    file:close()
    local body = assert(source:match("function " .. name:gsub("%.", "%%.") .. "%b().-\nend"), name)
    assert(loadstring(body))()
end
_G.TooltipDataRules, _G.TooltipUtil = {}, {}
loadNativeFunction("tests/framexml/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataRules.lua", "TooltipDataRules.FinalizeItemTooltip")
loadNativeFunction("tests/framexml/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua", "TooltipUtil.ShouldDoItemComparison")
_G.GameTooltipDataMixin = {}
local tooltipSource = "tests/framexml/Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.lua"
loadNativeFunction(tooltipSource, "GameTooltip_IsUpdateNeeded")
loadNativeFunction(tooltipSource, "GameTooltip_OnUpdate")
loadNativeFunction(tooltipSource, "GameTooltipDataMixin:RefreshData")
loadNativeFunction(tooltipSource, "GameTooltipDataMixin:RefreshDataNextUpdate")
_G.TOOLTIP_UPDATE_TIME = 0.2
methods.RefreshData = _G.GameTooltipDataMixin.RefreshData
methods.RefreshDataNextUpdate = _G.GameTooltipDataMixin.RefreshDataNextUpdate
function methods:GetOwner() return self.owner end
function methods:RebuildFromTooltipInfo()
    self.rebuilds = (self.rebuilds or 0) + 1
    self:SetHyperlink(self.link)
end
local compareCalls, alwaysCompare = 0, false
_G.GameTooltip_ShowCompareItem = function() compareCalls = compareCalls + 1 end
_G.TooltipComparisonManager = { Clear = function() end }
_G.GetCVarBool = function() return alwaysCompare end
function methods:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function methods:GetProcessingTooltipInfo() return {} end
function methods:SetHyperlink(link)
    self.link = link
    _G.TooltipDataRules.FinalizeItemTooltip(self, {})
end
_G.GameTooltip = widget()
_G.GameTooltip.supportsItemComparison = true
local shift = false
_G.IsShiftKeyDown = function() return shift end
_G.IsModifiedClick = function() return shift end
local menuItems
_G.MenuUtil = { CreateContextMenu = function(owner, build)
    menuItems = {}
    local root = {}
    function root:CreateTitle() end
    function root:CreateRadio(label, isSelected, onClick, data)
        menuItems[label] = { isSelected = isSelected, onClick = onClick, data = data }
    end
    build(owner, root)
end }
local scrollbars = {}
ns.AltsViewShared.CreateScrollBar = function(parent, opts)
    local scroll = { track = widget(parent), onScroll = opts.onScroll }
    function scroll:Update(total, visible, offset)
        self.total, self.visible, self.offset = total, visible, offset
    end
    scrollbars[opts.orientation or "vertical"] = scroll
    return scroll
end
ns.UIKit = {
    CreateBackground = function() end,
    CreateAccentCheckbox = function(parent, opts)
        local checkbox = widget(parent)
        function checkbox:SetChecked(value, silent)
            self.checked = value
            if not silent then opts.onChange(value) end
        end
        function checkbox:Toggle() self:SetChecked(not self.checked) end
        return checkbox
    end,
    CreateBorderLines = function() end,
    UpdateBorderLines = function() end,
    CreateButton = function(parent, opts)
        local button = widget(parent)
        button:SetText(opts.text)
        button:SetScript("OnClick", opts.onClick)
        return button
    end,
}
local builder, filter
ns.Alts.Window.RegisterTab = function(_, _, fn) builder = fn end
assert(loadfile("modules/alts/views/filter_popup.lua"))("QUI", ns)
local attach = ns.Alts.FilterPopup.Attach
ns.Alts.FilterPopup.Attach = function(opts)
    filter = opts
    return attach(opts)
end
local settings = {}
ns.Alts.GetSettings = function() return settings end
local characters, keys = {}, {}
for n = 1, 8 do
    local key = string.format("Alt%02d-Realm", n)
    keys[n] = key
    characters[key] = { name = "Alt" .. n, equipped = { slots = {
        [1] = { itemID = n, icon = n, ilvl = 100, link = "item:" .. n },
        [17] = { itemID = 1700 + n, icon = 1700 + n, ilvl = 100 },
    } } }
end
characters[keys[8]].equipped.slots[18] = { itemID = 1808, icon = 1808, ilvl = 100 }
local subscriptions = {}
ns.Storage.Store = {
    IsInitialized = function() return true end,
    ListCharacters = function() return keys end,
    GetCharacter = function(key) return characters[key] end,
}
ns.Storage.Bus.Subscribe = function(event, callback) subscriptions[event] = callback end
assert(loadfile("modules/alts/views/equipment.lua"))("QUI", ns)
local view = builder(widget())
view.Refresh()
local horizontal, vertical = scrollbars.horizontal, scrollbars.vertical
assert(horizontal and vertical, "equipment scrolls both axes")
assert(horizontal.total == 8 and vertical.total == 17, "all characters and equipped optional slots render")
assert(vertical.visible < vertical.total, "larger icons require vertical scrolling at minimum height")
assert(filter and #filter.getRows() == 8, "character checklist contains full roster")
local function visibleText(text)
    for _, obj in ipairs(objects) do
        if obj.shown and obj.text == text then return obj end
    end
end
local function visibleIcon(texture)
    for _, obj in ipairs(objects) do
        if obj.shown and obj._icon and obj._icon.shown and obj._icon.texture == texture then return obj._icon end
    end
end
local icon = visibleIcon(1)
assert(icon and icon.width == 28 and icon.height == 28, "equipment icons are 28 pixels")
view.frame.scripts.OnMouseWheel(view.frame, -1)
assert(vertical.offset == 1 and horizontal.offset == 0, "ordinary wheel scrolls slots only")
shift = true
view.frame.scripts.OnMouseWheel(view.frame, -1)
assert(horizontal.offset == 1 and vertical.offset == 1, "Shift wheel scrolls characters only")
shift = false
vertical.onScroll(999)
horizontal.onScroll(999)
assert(vertical.offset == vertical.total - vertical.visible, "vertical offset clamps to final slot")
assert(visibleIcon(1808), "last optional equipment slot remains reachable")
filter.setChecked(keys[8], false)
filter.onChanged()
assert(settings.equipmentHiddenCharacters[keys[8]] == true, "unchecked character persists in profile")
assert(vertical.total == 16, "hidden character cannot keep optional slot visible")
assert(vertical.offset <= vertical.total - vertical.visible, "removing optional slot clamps vertical scroll")
assert(#filter.getRows() == 8 and not filter.isChecked(keys[8]), "hidden character remains available in checklist")
view.Refresh()
assert(horizontal.total == 7 and not filter.isChecked(keys[8]), "refresh preserves filter")
for n = 2, 7 do filter.setChecked(keys[n], false) end
filter.onChanged()
assert(horizontal.total == 1 and horizontal.offset == 0, "fewer selected columns clamp horizontal scroll")
assert(visibleIcon(1), "remaining character equipment renders after horizontal clamp")
filter.setChecked(keys[1], false)
filter.onChanged()
assert(horizontal.total == 0, "all columns can be deselected")
assert(visibleText("No characters selected"), "empty selection has clear guidance")
filter.setChecked(keys[1], true)
filter.onChanged()
assert(horizontal.total == 1 and filter.isChecked(keys[1]), "character can be restored")
vertical.onScroll(999)
assert(vertical.offset > 0, "short window retains vertical scrolling after restoring selection")
view.frame:SetHeight(700)
if view.frame.scripts.OnSizeChanged then view.frame.scripts.OnSizeChanged(view.frame) else view.Refresh() end
assert(vertical.offset == 0 and vertical.visible >= vertical.total, "taller window clears obsolete vertical offset")

filter.anchorButton.scripts.OnClick(filter.anchorButton)
local popup
for _, obj in ipairs(objects) do
    if obj._search then popup = obj end
end
assert(popup and popup:IsShown(), "character filter opens")
popup._search:SetText("Alt02")
local function checkboxFor(key)
    for _, obj in ipairs(objects) do
        if obj.parent == popup and obj.shown and obj._id == key then return obj._cb end
    end
end
assert(checkboxFor(keys[2]) and not checkboxFor(keys[2]).checked, "profile A has unchecked matching character")
settings = {}
view.Refresh()
assert(popup._search:GetText() == "Alt02", "profile refresh preserves popup search")
assert(checkboxFor(keys[2]).checked, "open popup updates checks when profile changes")
assert(not checkboxFor(keys[1]), "profile refresh keeps search applied")
local addedKey = "Alt020-Realm"
keys[#keys + 1] = addedKey
characters[addedKey] = { name = "Alt20" }
view.Refresh()
assert(checkboxFor(addedKey) and checkboxFor(addedKey).checked, "open popup includes matching newly cached character")
local removedKey = table.remove(keys, 2)
characters[removedKey] = nil
view.Refresh()
assert(not checkboxFor(removedKey) and checkboxFor(addedKey), "open popup removes deleted character and retains matching rows")
assert(popup._search:GetText() == "Alt02", "roster refresh preserves popup search")

popup._search:SetText("")
characters["Alt01-Realm"].details = { level = 60, ilvl = 300 }
characters["Alt08-Realm"].details = { level = 100, ilvl = 100 }
view.Refresh()
local labels = {}
for _, row in ipairs(filter.getRows()) do labels[row.id] = row.label end
assert(labels["Alt01-Realm"] == "Lvl 60 · Alt01-Realm", "checklist shows character level")
assert(labels[addedKey] == "Lvl — · " .. addedKey, "checklist labels unknown levels explicitly")
local function openSort()
    for _, obj in ipairs(objects) do
        if obj.shown and obj.text and obj.text:match("^Sort") then
            local button = obj.scripts.OnClick and obj or obj.parent
            if button.scripts.OnClick then
                button.scripts.OnClick(button)
                return
            end
        end
    end
    error("missing Sort button")
end
local function selectSort(label)
    openSort()
    local entry = assert(menuItems[label], "missing sort option: " .. label)
    entry.onClick(entry.data)
end
local function firstGridIcon()
    for _, obj in ipairs(objects) do
        if obj.shown and obj._icon and obj._icon.shown and obj.points[1][4] == 80 then
            return obj._icon.texture
        end
    end
end
openSort()
assert(menuItems.Name and menuItems.Level and menuItems["Item Level"], "native menu offers three sort options")
assert(menuItems.Name.isSelected(menuItems.Name.data), "default sort radio is Name")
horizontal.onScroll(999)
selectSort("Level")
assert(settings.equipmentSort == "level" and horizontal.offset == 0, "level sort persists and resets horizontal offset")
assert(firstGridIcon() == 8 and filter.getRows()[1].id == "Alt08-Realm", "level sort orders grid and full checklist highest first")
openSort()
assert(menuItems.Level.isSelected(menuItems.Level.data), "level radio reflects selected sort")
filter.setChecked("Alt08-Realm", false)
filter.onChanged()
assert(firstGridIcon() == 1 and filter.getRows()[1].id == "Alt08-Realm", "hidden top character stays in sorted checklist")
assert(not filter.isChecked("Alt08-Realm"), "sort preserves hidden selection")
selectSort("Item Level")
assert(settings.equipmentSort == "ilvl" and firstGridIcon() == 1, "item level callback sorts grid")
assert(filter.getRows()[1].id == "Alt01-Realm", "item level callback sorts checklist")
settings = { equipmentSort = "level" }
view.Refresh()
assert(firstGridIcon() == 8 and filter.getRows()[1].id == "Alt08-Realm", "profile change applies saved sort to grid and checklist")
assert(checkboxFor("Alt08-Realm").checked, "profile sort refresh updates visible popup checks")
selectSort("Name")
assert(settings.equipmentSort == "name" and firstGridIcon() == 1, "name callback restores alphabetical grid")

local itemCell, emptyCell
for _, obj in ipairs(objects) do
    if obj.shown and obj._icon then
        if obj._link == "item:1" then itemCell = obj end
        if not obj._link then emptyCell = obj end
    end
end
assert(itemCell and emptyCell, "hover test has equipped and empty slots")
alwaysCompare = true
GameTooltip:SetHyperlink("item:control")
assert(compareCalls == 1, "native rule comparison positive control honors always-compare")
compareCalls = 0
GameTooltip:Show()
itemCell.scripts.OnEnter(itemCell)
local itemTooltip
for _, obj in ipairs(objects) do
    if obj.kind == "GameTooltip" and obj.template == "GameTooltipTemplate" then itemTooltip = obj end
end
assert(itemTooltip and itemTooltip ~= GameTooltip and itemTooltip.parent == UIParent, "equipment tooltip sits outside the clipped Alts window")
assert(not itemTooltip.supportsItemComparison, "equipment tooltip has no comparison capability")
assert(itemTooltip.shown and itemTooltip.link == "item:1" and itemTooltip.owner == itemCell, "hover displays cached equipped item link")
assert(not GameTooltip.shown and compareCalls == 0, "always-compare adds no current-character comparison")
itemCell.scripts.OnLeave(itemCell)
assert(not itemTooltip.shown, "leaving item hides dedicated tooltip")
alwaysCompare, shift = false, true
GameTooltip:SetHyperlink("item:control")
assert(compareCalls == 1, "native comparison positive control honors Shift")
compareCalls = 0
itemCell.scripts.OnEnter(itemCell)
assert(itemTooltip.shown and compareCalls == 0, "Shift hover still shows only equipped item")
itemTooltip:RefreshDataNextUpdate()
assert(itemTooltip.shouldRefreshData, "native delayed tooltip update is pending")
assert(itemTooltip.scripts.OnUpdate, "dedicated item tooltip has update handler")
itemTooltip.scripts.OnUpdate(itemTooltip, 0.01)
assert(itemTooltip.rebuilds == 1 and not itemTooltip.shouldRefreshData, "native updater rebuilds delayed tooltip data")
assert(itemTooltip.link == "item:1" and compareCalls == 0, "delayed rebuild preserves cached item without comparisons")
local insertedLink
_G.ChatEdit_InsertLink = function(link) insertedLink = link end
itemCell.scripts.OnClick(itemCell)
assert(insertedLink == "item:1", "Shift click still inserts cached item link")
shift = false
itemCell.scripts.OnLeave(itemCell)
emptyCell.scripts.OnEnter(emptyCell)
assert(not itemTooltip.shown, "empty slot does not show item tooltip")
itemCell.scripts.OnEnter(itemCell)
view.Refresh()
assert(not itemTooltip.shown, "grid refresh hides stale item tooltip")
itemCell.scripts.OnEnter(itemCell)
view.frame.scripts.OnHide(view.frame)
assert(not itemTooltip.shown, "closing Equipment hides the floating item tooltip")

print("OK alts_equipment_view_test")
