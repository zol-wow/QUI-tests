local function sink()
    return setmetatable({
        color = { 1, 1, 1 },
        SetVertexColor = function(self, r, g, b) self.color = { r, g, b } end,
    }, { __index = function() return function() end end })
end

local created = {}
_G.CreateFrame = function(_, _, _, template)
    local f = { _scripts = {}, _template = template }
    function f.SetScript(self, which, fn) self._scripts[which] = fn end
    function f.GetScript(self, which) return self._scripts[which] end
    function f.HookScript(self, which, fn) self._scripts["hook:" .. which] = fn end
    function f.CreateTexture() return sink() end
    function f.CreateFontString() return sink() end
    function f.SetBagID() end
    function f.GetBagID() return 0 end
    function f.GetID() return 1 end
    function f.ClearNormalTexture() end
    function f.SetAlpha() end
    function f.SetAllPoints() end
    function f.SetPoint() end
    function f.SetID() end
    function f.RegisterForClicks() end
    function f.RegisterForDrag() end
    if template == "ContainerFrameItemButtonTemplate" then
        f.IconBorder = sink()
        f.BattlepayItemTexture = sink()
        f.Cooldown = sink()
        f.JunkIcon = sink()
        f.IconQuestTexture = sink()
        f.ItemContextOverlay = sink()
        f.NewItemTexture = sink()
        f.Icon = sink()
    end
    created[#created + 1] = f
    return f
end

local overlayLog = {}
_G.SetItemButtonOverlay = function(button, itemIDOrLink, quality)
    overlayLog[#overlayLog + 1] = { op = "set", button = button, link = itemIDOrLink, quality = quality }
end
_G.ClearItemButtonOverlay = function(button)
    overlayLog[#overlayLog + 1] = { op = "clear", button = button }
end
_G.SetItemButtonTexture = function() end
_G.SetItemButtonCount = function() end
_G.SetItemButtonDesaturated = function() end
_G.CooldownFrame_Set = function() end
_G.GameTooltip = sink()
_G.C_Container = {
    GetContainerItemCooldown = function() return 0, 0, 0 end,
    GetContainerItemInfo = function() return { isLocked = false } end,
    GetContainerItemEquipmentSetInfo = function() return false end,
}

local settings = {
    appearance = { corners = { tr1 = "crafting_quality" } },
    behavior = { junk = {} },
}

local ns = {
    UIKit = { CreateBorderLines = function() end, UpdateBorderLines = function() end },
    Helpers = {
        CreateDBGetter = function() return function() return settings end end,
        GetGeneralFont = function() return "font" end,
        GetSkinColors = function() return 1, 1, 1 end,
    },
    SafeCall = function(_, fn, ...) return pcall(fn, ...) end,
}

local chunk = assert(loadfile("QUI_Bags/bags/views/item_buttons.lua"))
chunk("QUI", ns)
local ItemButtons = ns.Bags.ItemButtons

local fails = 0
local function check(name, ok, detail)
    if ok then print("  ok  " .. name)
    else fails = fails + 1; print("FAIL  " .. name .. (detail and ("  " .. detail) or "")) end
end

local function reset() for i = #overlayLog, 1, -1 do overlayLog[i] = nil end end
local function last() return overlayLog[#overlayLog] end

local button = ItemButtons.CreateLive({}, 0)

check("live buttons opt out of Blizzard's profession quality overlay",
    button.noProfessionQualityOverlay == true)

local COSMETIC = "|cffa335ee|Hitem:190622::::::::80:::::|h[Cosmetic]|h|r"

reset()
ItemButtons.Dress(button, { icon = 1, quality = 4, link = COSMETIC })
local rec = last()
check("an occupied slot hands its link to SetItemButtonOverlay",
    rec ~= nil and rec.op == "set" and rec.link == COSMETIC and rec.quality == 4,
    rec and ("op=" .. rec.op) or "no overlay call")

reset()
ItemButtons.Dress(button, { icon = 1, quality = 1 })
rec = last()
check("a linkless entry clears instead of calling with nil",
    rec ~= nil and rec.op == "clear",
    rec and ("op=" .. rec.op .. " link=" .. tostring(rec.link)) or "no overlay call")

reset()
ItemButtons.Dress(button, nil)
rec = last()
check("an empty slot clears the overlay", rec ~= nil and rec.op == "clear",
    rec and ("op=" .. rec.op) or "no overlay call")

_G.GetGuildBankItemInfo = function() return nil, nil, false end

for _, case in ipairs({
    { "cached", ItemButtons.CreateCached, function(b, e) ItemButtons.DressCached(b, e) end },
    { "guild", ItemButtons.CreateGuildLive, function(b, e) ItemButtons.DressGuildLive(b, 1, 1, e) end },
}) do
    local label, create, dress = case[1], case[2], case[3]
    local b = create({})

    check(label .. " buttons own an IconOverlay texture", b.IconOverlay ~= nil)
    check(label .. " buttons opt out of the profession quality overlay",
        b.noProfessionQualityOverlay == true)

    reset()
    dress(b, { icon = 1, quality = 4, link = COSMETIC })
    local r = last()
    check(label .. " buttons hand their link to SetItemButtonOverlay",
        r ~= nil and r.op == "set" and r.link == COSMETIC and r.quality == 4,
        r and ("op=" .. r.op) or "no overlay call")

    reset()
    dress(b, nil)
    r = last()
    check(label .. " buttons clear the overlay when the slot empties",
        r ~= nil and r.op == "clear", r and ("op=" .. r.op) or "no overlay call")
end

_G.Enum = {
    ItemClass = { Recipe = 9 },
    ItemRecipeSubclass = { Tailoring = 2 },
    Profession = { Tailoring = 7 },
    TooltipDataLineType = { ItemSpellTriggerLearn = 38, LearnableSpell = 6, UsageRequirement = 43, NestedBlock = 19 },
    TooltipDataUsageRequirementType = { NotAlreadyKnown = 14 },
}
_G.ITEM_SPELL_KNOWN = "Already known"
_G.time = function() return 42 end
local current = {}
ns.Storage = {
    Store = { IsReady = function() return true end, GetCurrentCharacter = function() return current end },
    Bus = { Subscribe = function() end },
}
assert(loadfile("core/storage/recipe_learning.lua"))("QUI", ns)
_G.C_Item = { GetItemInfoInstant = function() return 100, nil, nil, nil, nil, 9, 2 end }
_G.C_TradeSkillUI = { GetProfessionSkillLineID = function() return 197 end }
_G.GetProfessions = function() return 4 end
_G.GetProfessionInfo = function() return nil, nil, nil, nil, nil, nil, 197 end
local recipeData = { lines = {
    { type = 43, requirementType = 14, usable = false },
    { type = 38 },
} }
_G.C_TooltipInfo = {
    GetBagItem = function() return recipeData end,
    GetHyperlink = function() return recipeData end,
}
settings.appearance.markUnusable = true
for _, case in ipairs({
    { "live bags and bank", button, ItemButtons.Dress },
    { "cached storage", ItemButtons.CreateCached({}), ItemButtons.DressCached },
    { "guild bank", ItemButtons.CreateGuildLive({}), function(b, e) ItemButtons.DressGuildLive(b, 1, 1, e) end },
}) do
    case[3](case[2], { icon = 1, quality = 1, link = "item:100" })
    local icon = case[2].Icon or case[2].icon or case[2]._icon
    check(case[1] .. " red-tints a known recipe without red text", icon.color[2] == 0.35)
    settings.appearance.markUnusable = false
    case[3](case[2], { icon = 1, quality = 1, link = "item:100" })
    check(case[1] .. " respects the tint setting", icon.color[2] == 1)
    settings.appearance.markUnusable = true
end
recipeData = { lines = { { type = 43, usable = false }, { type = 38 } } }
ItemButtons.Dress(button, { icon = 1, quality = 1, link = "item:100" })
check("unmet recipe learning requirements tint red", button.Icon.color[2] == 0.35)
recipeData = { lines = {
    { type = 38 },
    { type = 6 },
    { type = 19 },
    { type = 43, usable = false, leftColor = { r = 1, g = 0.1, b = 0.1 } },
} }
ItemButtons.Dress(button, { icon = 1, quality = 1, link = "item:100" })
check("crafted output requirements do not tint the recipe", button.Icon.color[2] == 1)
_G.GetProfessions = function() return nil end
recipeData = { lines = { { type = 6 } } }
for _, bagID in ipairs({ 0, 6, 12 }) do
    button.GetBagID = function() return bagID end
    ItemButtons.Dress(button, { icon = 1, quality = 1, link = "item:100" })
    check("a non-tailor's pattern tints red in bag " .. bagID, button.Icon.color[2] == 0.35)
end

if fails > 0 then
    print(("FAILED %d check(s)"):format(fails))
    os.exit(1)
end
print("PASS bags_cosmetic_overlay_test")
