local now = 1000
local function Frame()
    local f = { shown = false, enabled = true, scripts = {} }
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn)
        local old = self.scripts[event]
        self.scripts[event] = function(...)
            if old then old(...) end
            fn(...)
        end
    end
    function f:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        if self.shown and self.PromptFrame then
            local button = self.PromptFrame.RollButton
            button.scripts.OnShow(button)
        end
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:IsShown() return self.shown end
    function f:SetEnabled(enabled) self.enabled = enabled end
    function f:IsEnabled() return self.enabled end
    function f:Disable() self.enabled = false end
    function f:Enable() self.enabled = true end
    function f:GetFrameLevel() return 5 end
    function f:SetFrameLevel() end
    function f:ClearAllPoints() end
    function f:SetPoint() end
    function f:SetHeight(height) self.height = height end
    function f:RegisterEvent() end
    return f
end

local env = setmetatable({
    time = function() return now end,
    GetTimePreciseSec = function() return now + 0.25 end,
    max = math.max,
    CreateFrame = Frame,
    EJ_GetEncounterInfo = function() return "Test Boss" end,
    GetDifficultyInfo = function() return "Heroic" end,
    EventRegistry = { RegisterCallback = function() end },
}, { __index = _G })
env._G = env
function env.hooksecurefunc(name, fn)
    local old = assert(env[name])
    env[name] = function(...)
        old(...)
        fn(...)
    end
end
assert(setfenv(assert(loadfile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua")), env))()

local xmlFile = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml"))
local xml = xmlFile:read("*a")
xmlFile:close()
local script = assert(xml:match('<Button parentKey="RollButton">.-<OnShow>(.-)</OnShow>'))
local nativeButtonShow = assert(setfenv(assert(loadstring("return function(self) " .. script .. " end")), env))()
local bonus = Frame()
bonus.PromptFrame = { Timer = Frame(), RollButton = Frame(), PassButton = Frame() }
bonus.PromptFrame.RollButton:SetScript("OnShow", nativeButtonShow)
bonus.LootSpinnerBG, bonus.IconBorder, bonus.BlackBackgroundHoist = Frame(), Frame(), Frame()
bonus:SetScript("OnShow", env.BonusRollFrame_OnShow)
bonus:SetScript("OnHide", env.BonusRollFrame_OnHide)
env.BonusRollFrame = bonus
local container = Frame()
container.rollFrames, container.waitingRolls = {}, {}
container.maxIndex, container.reservedSize = 0, 100
container.layoutParent = { Layout = function() end }
env.GroupLootContainer = container

local cfg = { enabled = true, announce = false, difficulty = { [15] = { hide = true } } }
local core = { db = { global = { bonusRoll = { seenDifficulties = {}, seenEncounters = {} } } }, Print = function() end }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = {
        GetCore = function() return core end,
        CreateDBGetter = function() return function() return { bonusRoll = cfg } end end,
        SafeNumberOrNil = function(value) if type(value) == "number" then return value end end,
        IsSecretValue = function() return false end,
    },
}
assert(setfenv(assert(loadfile("modules/qol/bonus_roll.lua")), env))("QUI", ns)
local sibling = Frame()
env.GroupLootContainer_AddFrame(container, sibling)
bonus.state, bonus.spellID, bonus.difficultyID = "prompt", 123, 15
bonus.instanceID, bonus.encounterID, bonus.endTime = 10, 100, now + 60
env.GroupLootContainer_AddFrame(container, bonus)
assert(not bonus:IsShown() and sibling:IsShown(), "filter must hide only the bonus prompt")
assert(container.rollFrames[1] == sibling and container.maxIndex == 1,
    "native removal must preserve other loot and reclaim the bonus-roll slot")

local token = assert(ns.BonusRoll.GetPendingRoll()).token
env.BonusRollFrame_OnEvent(bonus, "BONUS_ROLL_DEACTIVATE")
assert(not bonus.PromptFrame.RollButton:IsEnabled(), "native deactivation must disable Roll")
now = now + 15
assert(ns.BonusRoll.ShowPendingRoll(token), "pending native prompt must reopen")
assert(bonus.remaining == 45 and bonus.endTime == 1060, "native OnShow must retain original expiry")
assert(not bonus.PromptFrame.RollButton:IsEnabled(),
    "recovery must preserve Blizzard's disabled Roll despite its native OnShow enabling it")
assert(sibling:IsShown() and container.rollFrames[1] == sibling and container.rollFrames[2] == bonus,
    "native restoration must keep sibling loot intact and add only one bonus prompt")
env.BonusRollFrame_OnEvent(bonus, "BONUS_ROLL_ACTIVATE")
assert(bonus.PromptFrame.RollButton:IsEnabled(), "Blizzard must still control subsequent reactivation")
env.BonusRollFrame_CloseBonusRoll()
assert(not bonus:IsShown() and not ns.BonusRoll.ShowPendingRoll(token), "native timeout must invalidate recovery")
assert(sibling:IsShown(), "timeout must preserve unrelated loot")

print("OK: bonus_roll_native_frame_test")
