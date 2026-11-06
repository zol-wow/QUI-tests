local file = assert(io.open("QUI_CDM/cdm/settings/composer.lua", "rb"))
local source = file:read("*a")
file:close()
local body = assert(source:match("(RefreshAddList = function%(%)\n.-\nend)\n"))
local function noop() end
local entries = {}
local cells = {}
local spellData = { GetAvailableSpells = function() return entries end }
local env = setmetatable({
    addListContent = { GetWidth = function() return 400 end, SetHeight = noop },
    activeContainer = "essential",
    activeAddTab = "cdm_spells",
    addCells = cells,
    GRID_CELL_STRIDE = 40,
    GetCDMSpellData = function() return spellData end,
    Helpers = { FoldSearchUTF8 = string.lower },
    ResolveContainerType = function() return "cooldown" end,
    GetContainerDB = function() return {} end,
    GetChromeBorder = function() return 1, 1, 1 end,
    IsEntryRegisteredInBlizzCDM = function() return true end,
    math_floor = math.floor,
    math_max = math.max,
    math_abs = math.abs,
    GetOrCreateAddCell = function(index)
        if not cells[index] then
            cells[index] = {
                Hide = noop, ClearAllPoints = noop, SetParent = noop,
                SetAlpha = noop, SetBackdropBorderColor = noop,
                SetScript = noop, SetPoint = noop, Show = noop,
                _icon = {
                    SetTexture = function(self, texture) self.texture = texture end,
                    SetDesaturated = noop, SetVertexColor = noop,
                },
            }
        end
        return cells[index]
    end,
}, { __index = _G })
local chunk = assert(loadstring(body .. "\nreturn RefreshAddList"))
setfenv(chunk, env)
local refresh = chunk()

for _, case in ipairs({
    { icon = 0, want = "Interface\\Icons\\INV_Misc_QuestionMark" },
    { want = "Interface\\Icons\\INV_Misc_QuestionMark" },
    { icon = 134400, want = 134400 },
    { icon = "Interface/ICONS/INV_POTION_114", want = "Interface/ICONS/INV_POTION_114" },
}) do
    entries = {{ spellID = 9999, _entryID = 9999, _entryType = "consumable", name = "Category 9999", icon = case.icon }}
    refresh()
    assert(cells[1]._icon.texture == case.want,
        "Add Entries must render missing category icons as a question mark and preserve valid icons; got " .. tostring(cells[1]._icon.texture))
end

print("OK cdm_composer_add_icon_fallback_test")

local equipped = {}
local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
ItemUtil = {
    GetValidatedItemLocation = function(slot) return equipped[slot] end,
}
C_Item = {
    GetItemIcon = function(item) return item.icon end,
    GetItemIconByID = function() return nil end,
    GetItemInfoInstant = function() return nil end,
}
C_PaperDollInfo = {
    GetInventorySlotInfoForInvSlot = function(slot)
        assert(slot == 13 or slot == 14)
        return slot, 136528
    end,
}
GetInventoryItemID = function(_, slot) return equipped[slot] and equipped[slot].id end
local native = readAll("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXMLUtil/ItemUtil.lua")
assert(loadstring(assert(native:match("(function ItemUtil.GetEquipSlotTexture%(equipSlot%).-\nend)\n"))))()
local ns = { SafeCall = function(_, fn, ...) return pcall(fn, ...) end }
assert(loadfile("QUI_CDM/cdm/cdm_sources.lua"))("QUI", ns)
assert(loadfile("QUI_CDM/cdm/cdm_catalog.lua"))("QUI", ns)
C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(category) return category == 0 and { 101, 102 } or {} end,
    GetCooldownViewerCooldownInfo = function(id) return { equipSlot = id - 88, isKnown = true } end,
}
env.Sources = ns.CDMSources
env.ns = ns
env.ns.L = setmetatable({}, { __index = function(_, key) return key end })
local iconChunk = assert(loadstring(assert(source:match("(local function GetEntryIcon%(entry%).-\nend)\n")) .. "\nreturn GetEntryIcon"))
setfenv(iconChunk, env)
local entryIcon = iconChunk()
local resolver = readAll("QUI_CDM/cdm/cdm_resolvers.lua")
local resolverChunk = assert(loadstring(assert(resolver:match("(function CDMResolvers.GetEntryTexture%(entry%).-\nend)\n"))))
local resolvers = {}
setfenv(resolverChunk, setmetatable({ CDMResolvers = resolvers, Sources = ns.CDMSources }, { __index = _G }))
resolverChunk()
spellData.GetUsableItems = function() return {} end

for _, withEquipment in ipairs({ false, true }) do
    equipped[13] = withEquipment and { id = 1001, icon = 987654 } or nil
    equipped[14] = withEquipment and { id = 1002, icon = 987655 } or nil
    spellData.GetUsableItems = function()
        return withEquipment and {{ type = "slot", id = 13, slotID = 13, icon = 0 }} or {}
    end
    entries = ns.CDMCatalog.GetAvailableSpellsForContainer("custom1", "cooldown", {}, {})
    assert(#entries == 2)
    for _, entry in ipairs(entries) do
        local want = withEquipment and equipped[entry._entryID].icon or 136528
        assert(entry.icon == want, "CDM picker must use native trinket artwork for empty and uncached equipped slots")
        assert(entryIcon({ type = "slot", id = entry._entryID }) == want,
            "composer entry list must use native trinket artwork")
        assert(resolvers.GetEntryTexture({ type = "slot", id = entry._entryID }) == want,
            "preview resolver must use native trinket artwork")
    end
    for _, tab in ipairs({ "cdm_spells", "items" }) do
        env.activeAddTab = tab
        refresh()
        for index = 1, 2 do
            local slot = cells[index]._sourceEntry._entryID
            local want = withEquipment and equipped[slot].icon or 136528
            assert(cells[index]._icon.texture == want, tab .. " must render both trinket slots")
        end
    end
end

print("OK cdm_composer_trinket_slot_icons")
