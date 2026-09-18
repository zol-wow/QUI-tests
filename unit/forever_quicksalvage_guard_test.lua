local combat, alt, ctrl, shift, targeting = false, true, false, false, false
local casts, targets, frames = {}, {}, {}
local crafted, tooltipCallback
local settings = { enabled = true, modifier = "ALT" }
local function noop() end
local world = setmetatable({}, { __index = _G })
world._G = world
local methods = {}
local function frame(name)
    local value = setmetatable({ attributes = {}, scripts = {}, events = {}, shown = false }, { __index = methods })
    frames[#frames + 1] = value
    if name then world[name] = value end
    return value
end
function methods:SetAttribute(key, value)
    assert(key ~= "_onleave" and key ~= "_onattributechanged", "Forever salvage cannot install restricted snippets")
    self.attributes[key] = value
end
function methods:GetAttribute(prefix, name, suffix)
    if not name then return self.attributes[prefix] end
    return self.attributes[prefix .. name .. suffix] or self.attributes["*" .. name .. suffix]
        or self.attributes[prefix .. name .. "*"] or self.attributes[name]
end
function methods:SetScript(name, handler) self.scripts[name] = handler end
function methods:HookScript(name, handler)
    local previous = self.scripts[name]
    self.scripts[name] = function(...) if previous then previous(...) end; handler(...) end
end
function methods:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetSize() return self.width or 40, self.height or 40 end
function methods:GetScale() return 1 end
function methods:CreateTexture() return frame() end
function methods:CreateAnimationGroup() return frame() end
function methods:CreateAnimation() return frame() end
for _, name in ipairs({ "SetFrameStrata", "EnableMouse", "RegisterForClicks", "ClearAllPoints", "SetPoint",
    "SetAtlas", "SetDesaturated", "SetLooping", "SetTarget", "SetDuration", "SetFlipBookColumns",
    "SetFlipBookRows", "SetFlipBookFrames", "Play", "Stop", "SetVertexColor" }) do methods[name] = noop end
world.UIParent = frame()
world.CreateFrame = function(_, name, _, template)
    assert(not template or template == "InsecureActionButtonTemplate", "Forever salvage must use native out-of-combat actions")
    local value = frame(name)
    if template then
        local file = assert(io.open("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml"))
        local xml = file:read("*a"); file:close()
        local body = assert(xml:match('name="InsecureActionButtonTemplate".-<OnClick>(.-)</OnClick>'))
        local chunk = assert(loadstring("return function(self, button, down) " .. body .. " end"))
        setfenv(chunk, world)
        value.scripts.OnClick = chunk()
    end
    return value
end
world.CreateColor = function() return { GetRGB = function() return 1, 1, 1 end } end
world.CopyTable = function(value) local out = {}; for k, v in pairs(value) do out[k] = v end; return out end
world.GetFrameMetatable = function() return { __index = methods } end
world.InCombatLockdown = function() return combat end
world.IsAltKeyDown = function() return alt end
world.IsControlKeyDown = function() return ctrl end
world.IsShiftKeyDown = function() return shift end
world.GetCVarBool = function() return false end
world.C_SpellBook = {
    IsSpellKnown = function(id) return id == 13262 end,
    FindSpellBookSlotForSpell = function() return 1 end,
}
world.CastSpellByID = function(id) casts[#casts + 1] = id; targeting = true end
world.SpellCanTargetItem = function() return targeting end
world.SpellCanTargetItemID = function() return false end
world.C_Container = { UseContainerItem = function(bag, slot) targets[#targets + 1] = { bag, slot }; targeting = false end }
world.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
world.C_TradeSkillUI = { CraftSalvage = function(recipe, count, location) crafted = { recipe, count, location } end }
world.C_Macro = { RunMacroText = function(text)
    local chunk = assert(loadstring(assert(text:match("^/run (.+)$"))))
    setfenv(chunk, world); chunk()
end }
world.UnitHasVehicleUI = function() return false end
world.GameTooltip_Hide = noop
world.GameTooltip = { AddLine = noop, Show = noop }
world.UnregisterStateDriver = noop
world.Enum = { TooltipDataType = { Item = 1 } }
world.TooltipDataProcessor = { AddTooltipPostCall = function(_, callback) tooltipCallback = callback end }
local function load(path, ns)
    local chunk = assert(loadfile(path)); setfenv(chunk, world); chunk("QUI", ns)
end
load("tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua")
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }),
    Client = { isForever = true, restrictedExecutionUnavailable = true }, Helpers = {
    GetModuleDB = function() return { quickSalvage = settings } end,
} }
load(os.getenv("QUI_SALVAGE_SOURCE") or "modules/qol/quicksalvage.lua", ns)
local button = assert(ns.QuickSalvage and ns.QuickSalvage.Button, "Forever must initialize Quick Salvage")
button:UpdateAttributeDriver()
button:ApplySpell(0, 4, "item:123", 13262, nil, { 100, 200, 40, 40 })
assert(button:IsShown(), "holding Alt over a salvageable item must show the overlay")
button.scripts.OnClick(button, "LeftButton", false)
assert(casts[1] == 13262 and #casts == 1, "native click must cast the actual selected spell once")
assert(targets[1][1] == 0 and targets[1][2] == 4, "native click must target the selected bag slot")
alt = false
button.scripts.OnClick(button, "LeftButton", false)
assert(#casts == 1, "releasing the modifier must not cast")
alt, ctrl = true, true
button.scripts.OnClick(button, "LeftButton", false)
assert(#casts == 1, "unconfigured modifier combination must not cast")
settings.modifier = "ALTCTRL"
button:UpdateAttributeDriver()
assert(not button:IsShown(), "changing modifiers must clear the old overlay and bindings")
button:ApplySpell(2, 8, "item:456", 13262, nil, { 100, 200, 40, 40 })
button.scripts.OnClick(button, "LeftButton", false)
assert(#casts == 2 and targets[2][1] == 2 and targets[2][2] == 8, "Alt-Ctrl must select the current item")
combat = true
button.scripts.OnClick(button, "LeftButton", false)
assert(#casts == 2, "native XML handler must forbid casting in combat")
local eventFrame
for _, value in ipairs(frames) do if value.events.PLAYER_REGEN_DISABLED then eventFrame = value end end
assert(eventFrame, "Forever overlay must observe combat start")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_DISABLED")
assert(not button:IsShown() and button:GetAttribute("target-slot") == nil, "combat start must hide and clear the ordinary overlay")
button:ApplySpell(0, 1, nil, 13262, nil, { 100, 200, 40, 40 })
assert(not button:IsShown(), "combat must not allow the overlay to be configured")
combat = false
button:ApplySpell(0, 1, nil, 13262, nil, { 100, 200, 40, 40 })
button.scripts.OnLeave(button)
assert(not button:IsShown() and button:GetAttribute("alt-ctrl-type1") == nil, "leaving must clear the click action without a snippet")
world.C_SpellBook.FindSpellBookSlotForSpell = function() return nil end
button:ApplySpell(3, 7, nil, 54321, nil, { 100, 200, 40, 40 })
button.scripts.OnClick(button, "LeftButton", false)
assert(crafted and crafted[1] == 54321 and crafted[2] == 1
    and crafted[3].bag == 3 and crafted[3].slot == 7, "native recipe macro must salvage the selected recipe and exact item location")
combat = true
crafted = nil
button.scripts.OnClick(button, "LeftButton", false)
assert(crafted == nil, "native recipe macro must not run during combat")
combat = false
button:ApplySpell(0, 1, nil, 13262, nil, { 100, 200, 40, 40 })
settings.enabled = false
ns.QuickSalvage.Refresh()
assert(not button:IsShown(), "disabling salvage must remove an existing overlay")
settings.enabled = true
world.GetTime = function() return 100 end
world.C_AddOns = { IsAddOnLoaded = function() return true end }
world.table = setmetatable({ wipe = function(value) for key in pairs(value) do value[key] = nil end end }, { __index = table })
world.Enum.TradeskillRecipeType = { Salvage = 1, Item = 2 }
world.C_TradeSkillUI.GetFilteredRecipeIDs = function() return { 54321 } end
world.C_TradeSkillUI.GetRecipeInfo = function(id)
    if id == 54321 then return { recipeID = id, learned = true, disabled = false } end
end
world.C_TradeSkillUI.GetRecipeSchematic = function(id)
    return { recipeID = id, recipeType = 1, reagentSlotSchematics = {
        { quantityRequired = 5, reagents = { { itemID = 67890 } } },
    } }
end
world.C_Item = { GetStackCount = function() return 5 end, GetItemInfoInstant = function() return nil end }
local owner = {
    GetSlotAndBagID = function() return 9, 2 end,
    GetScaledRect = function() return 100, 200, 40, 40 end,
}
local tooltip = { GetOwner = function() return owner end }
button:UpdateAttributeDriver()
crafted = nil
tooltipCallback(tooltip, { id = 67890, hyperlink = "item:67890" })
assert(button:IsShown(), "documented schematic recipeID and learned recipe must enable salvage without spellbook membership")
button.scripts.OnClick(button, "LeftButton", false)
assert(crafted and crafted[1] == 54321 and crafted[3].bag == 2 and crafted[3].slot == 9,
    "discovered learned recipe must craft against the hovered bag item")
print("OK forever_quicksalvage_guard_test")
