local combat = false
local learnedSpellEventValid = false
local registered
local frameMethods = {}
local function noop() end
local function newFrame(template)
    assert(not template or not template:find("SecureHandler", 1, true),
        "travel must not depend on the secure snippet compiler")
    return setmetatable({ shown = false, attributes = {}, scripts = {}, events = {} }, { __index = frameMethods })
end
function frameMethods:SetScript(name, fn) self.scripts[name] = fn end
function frameMethods:SetAttribute(name, value)
    assert(name:sub(1, 1) ~= "_", "travel must not install secure snippets")
    self.attributes[name] = value
    if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, name, value) end
end
function frameMethods:GetAttribute(name) return self.attributes[name] end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:IsShown() return self.shown end
function frameMethods:GetHeight() return 24 end
function frameMethods:GetStringWidth() return 36 end
function frameMethods:GetFont() end
function frameMethods:CreateTexture() return newFrame() end
function frameMethods:CreateFontString() return newFrame() end
function frameMethods:GetNormalTexture() return newFrame() end
function frameMethods:RegisterEvent(event)
    assert(event ~= "LEARNED_SPELL_IN_SKILL_LINE" or learnedSpellEventValid, "must not register unsupported spell event")
    self.events[event] = true
end
for _, method in ipairs({
    "UnregisterEvent", "UnregisterAllEvents", "SetAllPoints", "SetSize",
    "SetPoint", "ClearAllPoints", "SetParent", "SetFrameStrata", "SetFixedFrameStrata",
    "SetColorTexture", "RegisterForClicks", "SetNormalTexture", "SetHighlightTexture",
    "SetText", "SetTextColor", "SetJustifyH", "SetWordWrap", "SetDrawSwipe", "SetDrawEdge",
    "SetHideCountdownNumbers",
}) do frameMethods[method] = noop end
function CreateFrame(_, _, _, template) return newFrame(template) end
function InCombatLockdown() return combat end
function SecureCmdOptionParse(condition)
    assert(condition == "[combat] hide; ignore")
    return combat and "hide" or "ignore"
end
function IsSpellKnown() error("travel must not require deprecated spellbook globals") end
Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = { IsSpellInSpellBook = function(spellID, bank, includeOverrides)
    assert(spellID == 123 and bank == Enum.SpellBookSpellBank.Player and includeOverrides == false)
    return true
end }
strmatch = string.match
table.wipe = function(tbl) for key in pairs(tbl) do tbl[key] = nil end return tbl end
UIParent = newFrame()
C_Item = { GetItemIconByID = function() return 1 end, GetItemNameByID = function() return "Hearthstone" end }
C_ChallengeMode = { GetMapTable = function() return { 1 } end, GetMapUIInfo = function() return "Dungeon" end }
C_Spell = { GetSpellName = function() return "Teleport" end }
C_Timer = { After = function(_, fn) fn() end }
C_EventUtils = { IsEventValid = function(event) return event ~= "LEARNED_SPELL_IN_SKILL_LINE" or learnedSpellEventValid end }
GameTooltip = setmetatable({}, { __index = function() return noop end })
local ns = {
    Client = { restrictedExecutionUnavailable = true },
    Addon = { db = { profile = {} }, Datatexts = { Register = function(_, _, definition) registered = definition end } },
    DungeonData = { GetTeleportSpellID = function() return 123 end },
    L = setmetatable({}, { __index = function(_, key) return key end }),
}

assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua"))()
assert(loadfile("modules/infobar/travel.lua"))("QUI", ns)
local frame = registered.OnEnable(newFrame())
assert(not frame.events.LEARNED_SPELL_IN_SKILL_LINE, "unsupported spell event stays unregistered")
local flyout = frame._flyout
assert(not flyout:IsShown(), "travel flyout starts closed")
frame._hearth.scripts.OnEnter(frame._hearth)
assert(flyout:IsShown(), "hover opens travel flyout outside combat")
combat = true
_G.SecureStateDriverManager.scripts.OnUpdate(_G.SecureStateDriverManager, 1)
assert(not flyout:IsShown(), "native state driver hides travel flyout entering combat")
frame._hearth.scripts.OnEnter(frame._hearth)
assert(not flyout:IsShown(), "hover cannot reopen travel flyout in combat")
combat = false
_G.SecureStateDriverManager.scripts.OnUpdate(_G.SecureStateDriverManager, 1)
assert(not flyout:IsShown(), "leaving combat does not reopen travel flyout")
frame._hearth.scripts.OnEnter(frame._hearth)
assert(flyout:IsShown(), "hover reopens travel flyout after combat")
frame._flyoutDirty = true
frame._hearth.scripts.OnEnter(frame._hearth)
assert(frame._flyout ~= flyout, "dirty travel data rebuilds the flyout")
flyout:Show()
combat = true
_G.SecureStateDriverManager.scripts.OnUpdate(_G.SecureStateDriverManager, 1)
assert(flyout:IsShown(), "old flyout visibility driver was unregistered during rebuild")
assert(not frame._flyout:IsShown(), "replacement flyout retains native combat hiding")
registered.OnDisable(frame)
combat = false
frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
frame._flyout:Show()
combat = true
_G.SecureStateDriverManager.scripts.OnUpdate(_G.SecureStateDriverManager, 1)
assert(frame._flyout:IsShown(), "deferred disable unregisters native visibility driver")
combat = false
learnedSpellEventValid = true
local another = registered.OnEnable(newFrame())
assert(another.events.LEARNED_SPELL_IN_SKILL_LINE, "supported spell event remains registered")
registered.OnDisable(another)
another._flyout:Show()
combat = true
_G.SecureStateDriverManager.scripts.OnUpdate(_G.SecureStateDriverManager, 1)
assert(another._flyout:IsShown(), "ordinary disable unregisters native visibility driver")
print("OK infobar_travel_native_visibility_test")
