local function noop() end

local inCombat = false
local frames = {}
local timers = {}
local function newFrame(name)
    local frame = { scripts = {}, events = {}, click = false, shown = false }
    local methods = {}
    function methods:CreateTexture() return newFrame() end
    function methods:CreateFontString() return newFrame() end
    function methods:SetScript(script, handler) self.scripts[script] = handler end
    function methods:GetScript(script) return self.scripts[script] end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:RegisterUnitEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:IsShown() return self.shown end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    for _, method in ipairs({ "SetParent", "SetPoint", "ClearAllPoints", "SetSize", "SetScale", "SetAttribute", "Show", "Hide" }) do
        methods[method] = function(self)
            assert(not inCombat, "protected mutation during combat: " .. tostring(name) .. ":" .. method)
            if method == "Show" or method == "Hide" then
                local shown = method == "Show"
                if self.shown ~= shown then
                    self.shown = shown
                    local handler = self.scripts[shown and "OnShow" or "OnHide"]
                    if handler then handler(self) end
                end
            end
        end
    end
    local f = setmetatable(frame, { __index = function(_, k) return methods[k] or noop end })
    if name then _G[name] = f end
    return f
end
function CreateFrame(_, name)
    local frame = newFrame(name)
    frames[#frames + 1] = frame
    return frame
end
local function fire(event, ...)
    local listeners = {}
    for _, frame in ipairs(frames) do
        if frame.events[event] then listeners[#listeners + 1] = frame end
    end
    local reverse = os.getenv("QUI_TEST_REVERSE_EVENTS")
    for i = 1, #listeners do
        local frame = listeners[reverse and (#listeners - i + 1) or i]
        frame.scripts.OnEvent(frame, event, ...)
    end
end
local function runTimers()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
function LibStub() return nil end
function UnitClass() return "Mage", "MAGE" end
function InCombatLockdown() return inCombat end
function IsInInstance() return false, "none" end
function IsPlayerSpell() return false end
function IsLoggedIn() return true end
function GetTime() return 0 end
function GetInventoryItemID() return nil end
function GetWeaponEnchantInfo() return false, nil, nil, nil, false, nil, nil, nil end
function GetNumGroupMembers() return 0 end
function IsInRaid() return false end
function UnitExists() return false end

UIParent = newFrame()
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_BAG_SLOTS = 1
Enum = {
    ItemClass = { Consumable = 0 },
    ItemConsumableSubclass = { FoodAndDrink = 5, Flask = 3, Phial = 3 },
}
C_Container = {
    GetContainerNumSlots = function(bag)
        return bag == 0 and 1 or 0
    end,
    GetContainerItemID = function(bag, slot)
        if bag == 0 and slot == 1 then return 245926 end
        return nil
    end,
    GetContainerItemInfo = function() return { stackCount = 2 } end,
}
C_Item = {
    GetItemSpell = function() return nil, nil end,
    GetItemInfoInstant = function(itemID) return nil, nil, nil, nil, 100000 + itemID end,
    GetItemInfo = function(itemID) return "item:" .. tostring(itemID) end,
    GetItemCount = function() return 0 end,
    GetItemIconByID = function(itemID) return 100000 + itemID end,
}
C_Spell = { GetSpellTexture = function() return nil end }

local auras = {}
C_UnitAuras = { GetAuraDataByIndex = function(_, i) return auras[i] end }

C_Timer = { After = function(_, cb) timers[#timers + 1] = cb end, NewTicker = function() return { Cancel = noop } end }

local settings = {}
local ns = {
    __test = true,
    Helpers = {
        CreateDBGetter = function() return function() return settings end end,
        IsSecretValue = function() return false end,
        SafeValue = function(v) return v end,
        SafeToNumber = function(v) return tonumber(v) or 0 end,
    },
    ConsumableMacros = {
        GetVariantOrderForItem = function() return nil end,
        GetSelectedItem = function() return nil end,
    },
    Utils = { IsInInstancedContent = function() return false end },
    WhenLoggedIn = function(fn) if fn then fn() end end,
}

(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("modules/qol/consumablecheck.lua"))("QUI", ns)
runTimers()
local frame = _G.QUI_ConsumablesFrame
local originalFoodButton = frame.buttons.food
local originalFrameCount = #frames
assert(not frame:IsShown(), "consumables start hidden")
inCombat = true
fire("READY_CHECK")
assert(not frame:IsShown(), "ready check must wait for combat to end")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(frame:IsShown(), "active ready check must appear after combat")
fire("READY_CHECK_FINISHED")
assert(not frame:IsShown(), "finished ready check hides normally")

inCombat = true
fire("READY_CHECK")
fire("READY_CHECK_FINISHED")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(not frame:IsShown(), "finished ready check must cancel deferred display")

inCombat = true
_G.QUI_ShowConsumables()
_G.QUI_HideConsumables()
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(not frame:IsShown(), "explicit hide must cancel deferred display")

settings.consumablePersistent = true
fire("PLAYER_ENTERING_WORLD")
inCombat = true
runTimers()
fire("READY_CHECK_FINISHED")
assert(not frame:IsShown(), "delayed persistent display must also wait for combat")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(frame:IsShown(), "persistent display must survive ready-check completion")
settings.consumablePersistent = false
_G.QUI_HideConsumables()

inCombat = true
fire("READY_CHECK")
settings.consumableCheckEnabled = false
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(not frame:IsShown(), "disabled consumables must not display after combat")
settings.consumableCheckEnabled = true
fire("PLAYER_REGEN_ENABLED")
assert(not frame:IsShown(), "discarded request must not leak into a later combat")

fire("READY_CHECK")
assert(frame:IsShown(), "out-of-combat ready check still displays immediately")
assert(frame.buttons.food == originalFoodButton, "ready checks must reuse initialized buttons")
assert(#frames == originalFrameCount + 1, "only the combat-hide listener should be allocated")
inCombat = true
fire("READY_CHECK_FINISHED")
assert(frame.alpha == 0, "combat hide still suppresses visible ready-check contents")
fire("READY_CHECK")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(frame:IsShown() and frame.alpha == 1, "new ready check must supersede a pending hide")

settings.consumableIconSize = 48
_G.QUI_ShowConsumables()
assert(frame.buttonSize == 48, "standalone display must still apply a changed button size")

print("OK: consumablecheck_combat_display_test")
