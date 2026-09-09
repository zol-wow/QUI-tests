local now, precise = 1000, 42.125
local messages, frames = {}, {}
local secret = {}
local cfg, global
local callbacks = {}
local preview = false
local activeMap, activeLevel, completion = nil, 0, { mapChallengeModeID = 999, level = 2 }
local currentDifficulty, currentMap = 8, 100
local tier, instance, journalDifficulty = 1, 30, 14
local journalReady = false
local journal = {
    { id = 10, name = "Current Raid", map = 100, bosses = { { 101, "First Boss" }, { 102, "Second Boss" } } },
    { id = 20, name = "Current Expansion", map = 0, bosses = { { 201, "World Boss" } } },
}

local function newFrame()
    local frame = { scripts = {}, shown = false }
    function frame:HookScript(event, callback)
        local old = self.scripts[event]
        self.scripts[event] = function(...)
            if old then old(...) end
            callback(...)
        end
    end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent() end
    function frame:IsShown() return self.shown end
    function frame:Show()
        if self.shown then return end
        self.shown = true
        if self.state == "prompt" then self.remaining = self.endTime - now end
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end

local bonus = newFrame()
bonus.PromptFrame = { RollButton = newFrame(), PassButton = newFrame() }
function bonus.PromptFrame.RollButton:IsEnabled() return self.enabled ~= false end
function bonus.PromptFrame.RollButton:Disable() self.enabled = false end
local env = setmetatable({
    time = function() return now end,
    GetTimePreciseSec = function() return precise end,
    CreateFrame = newFrame,
    BonusRollFrame = bonus,
    GroupLootContainer = { rollFrames = {} },
    QUI_IsLayoutModeActive = function() return preview end,
    GetDifficultyInfo = function(id) return "Difficulty " .. id end,
    GetInstanceInfo = function() return "Dungeon", "party", currentDifficulty, "Mythic+", 5, 0, false, currentMap end,
    C_ChallengeMode = {
        GetActiveChallengeMapID = function() return activeMap end,
        GetActiveKeystoneInfo = function() return activeLevel end,
        GetChallengeCompletionInfo = function() return completion end,
    },
    C_EncounterJournal = { GetInstanceForGameMap = function(id) return id == 100 and 10 or 30 end },
    EventRegistry = { RegisterCallback = function(_, event, callback, owner) callbacks[event] = { callback, owner } end },
    EJ_GetNumTiers = function() return journalReady and 2 or 0 end,
    EJ_GetCurrentTier = function() return tier end,
    EncounterJournal = { instanceID = instance },
    EJ_GetDifficulty = function() return journalDifficulty end,
    EJ_SetDifficulty = function(id) journalDifficulty = id end,
    EJ_SelectTier = function(id) tier = id end,
    EJ_SelectInstance = function(id) instance = id end,
    EJ_GetTierInfo = function() return "Current Expansion" end,
    EJ_IsValidInstanceDifficulty = function(id) return id == 14 or id == 15 or id == 16 end,
    EJ_GetInstanceByIndex = function(index)
        local entry = journal[index]
        if entry then return entry.id, entry.name, nil, nil, nil, nil, nil, entry.map end
    end,
    EJ_GetEncounterInfoByIndex = function(index, id)
        for _, entry in ipairs(journal) do
            if entry.id == id then
                local boss = entry.bosses[index]
                if boss then return boss[2], nil, boss[1] end
            end
        end
    end,
    EJ_GetEncounterInfo = function(id)
        for _, entry in ipairs(journal) do
            for _, boss in ipairs(entry.bosses) do
                if boss[1] == id then return boss[2] end
            end
        end
    end,
}, { __index = _G })
env._G = env
function env.GroupLootContainer_AddFrame(container, frame)
    container.rollFrames[frame] = true
    frame:Show()
end
function env.GroupLootContainer_RemoveFrame(container, frame)
    container.rollFrames[frame] = nil
    frame:Hide()
end
function env.BonusRollFrame_StartBonusRoll(spellID, difficultyID, encounterID, instanceID, duration)
    bonus.state, bonus.spellID, bonus.difficultyID = "prompt", spellID, difficultyID
    bonus.encounterID, bonus.instanceID, bonus.endTime = encounterID, instanceID, now + (duration or 60)
    env.GroupLootContainer_AddFrame(env.GroupLootContainer, bonus)
end
function env.BonusRollFrame_CloseBonusRoll() bonus:Hide() end
function env.hooksecurefunc(name, callback)
    local original = env[name]
    env[name] = function(...) original(...); callback(...) end
end

local core = { Print = function(_, message) messages[#messages + 1] = message end }
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Helpers = {
        CreateDBGetter = function() return function() return { bonusRoll = cfg } end end,
        GetCore = function() return core end,
        IsSecretValue = function(value) return value == secret end,
        SafeNumberOrNil = function(value) if value ~= secret then return tonumber(value) end end,
    },
}
local function reset()
    cfg = { enabled = true, announce = true, mythicPlus = { mode = "show", minLevel = 10 }, difficulty = {} }
    global = { seenDifficulties = {}, seenEncounters = {} }
    core.db = { global = { bonusRoll = global } }
    env.BonusRollFrame_CloseBonusRoll()
    preview = false
end
reset()
assert(setfenv(assert(loadfile("modules/qol/bonus_roll.lua")), env))("QUI", ns)
local api = ns.BonusRoll
local events = frames[#frames]
local function event(name) events.scripts.OnEvent(events, name) end
local function offer(diff, boss, instanceID, spell)
    env.BonusRollFrame_CloseBonusRoll()
    env.BonusRollFrame_StartBonusRoll(spell or 7, diff, boss or 101, instanceID or 10)
end
local function token()
    return assert(api.GetPendingRoll(), "expected hidden pending prompt").token
end

cfg.enabled = false
cfg.difficulty[15] = { hide = true }
offer(15)
assert(bonus:IsShown() and not api.GetPendingRoll(), "disabled filtering must show")
cfg.enabled = true
offer(15)
assert(not bonus:IsShown(), "whole difficulty rule must hide")
local originalToken, originalEnd = token(), bonus.endTime
assert(messages[#messages]:find("|Haddon:qui:bonusroll:" .. originalToken, 1, true), "notice must contain local offer link")
now = now + 10
local callback = callbacks.SetItemRef
callback[1](callback[2], "addon:qui:bonusroll:" .. originalToken)
assert(bonus:IsShown() and bonus.remaining == 50 and bonus.endTime == originalEnd, "restore must retain native expiry")
assert(not api.GetPendingRoll(), "visible prompt must disable recovery button")
bonus:Hide()
bonus:Show()
assert(bonus:IsShown(), "manual recovery bypass lasts for that offer")
offer(15)
assert(token() ~= originalToken and not api.ShowPendingRoll(originalToken), "old link cannot restore another offer")
assert(not bonus:IsShown())
now = bonus.endTime
assert(not api.GetPendingRoll() and not api.ShowPendingRoll(), "expiry boundary must reject restoration")

reset()
cfg.difficulty[15] = { encounters = { [101] = true } }
offer(15, 101)
assert(not bonus:IsShown(), "selected boss hidden")
offer(15, 102)
assert(bonus:IsShown(), "unselected boss visible")
offer(14, 101)
assert(bonus:IsShown(), "boss rule isolated to difficulty")
cfg.difficulty[16] = { hide = true }
offer(233)
assert(not bonus:IsShown(), "flex Mythic shares Mythic filters")
offer(secret)
assert(bonus:IsShown(), "unreadable difficulty fails open")
offer(15, secret)
assert(bonus:IsShown(), "unreadable boss cannot match specific rule")
cfg.difficulty[15].hide = true
offer(15, secret)
assert(not bonus:IsShown(), "known difficulty still applies with unknown boss")
offer(15)
bonus.state = secret
assert(not api.ShowPendingRoll(), "unreadable native state cannot be restored")
offer(15)
bonus.endTime = secret
assert(not api.ShowPendingRoll(), "unreadable native expiry cannot be restored")
preview = true
offer(15)
assert(bonus:IsShown(), "Layout Mode previews are exempt")
preview = false
offer(15)
bonus.PromptFrame.PassButton.scripts.OnClick()
assert(not api.ShowPendingRoll(), "pass clears recovery")
offer(15)
bonus.PromptFrame.RollButton.scripts.OnClick()
assert(not api.ShowPendingRoll(), "roll clears recovery")
for _, name in ipairs({ "BONUS_ROLL_STARTED", "BONUS_ROLL_FAILED", "BONUS_ROLL_RESULT" }) do
    offer(15)
    event(name)
    assert(not api.ShowPendingRoll(), name .. " clears recovery")
end

reset()
cfg.mythicPlus.mode = "minimum"
event("PLAYER_ENTERING_WORLD")
offer(8)
assert(bonus:IsShown(), "unrelated completion must not supply key level")
activeMap, activeLevel = 1, 9
event("CHALLENGE_MODE_START")
offer(8)
assert(not bonus:IsShown(), "+9 below +10 minimum")
local boundToken = token()
local boundEnd = bonus.endTime
currentDifficulty, currentMap, activeMap, activeLevel = 0, 0, nil, 0
event("PLAYER_ENTERING_WORLD")
env.BonusRollFrame_StartBonusRoll(7, 0, 0, 0, boundEnd - now)
assert(token() == boundToken and api.GetPendingRoll().level == 9, "same reissued offer retains bound level across zoning")
assert(api.ShowPendingRoll(boundToken), "reissued offer can recover")
currentDifficulty, currentMap, activeMap, activeLevel = 8, 100, 1, 10
event("CHALLENGE_MODE_START")
offer(8)
assert(bonus:IsShown(), "+10 meets +10 minimum")
activeLevel = 9
event("CHALLENGE_MODE_START")
offer(8, 101, 30)
assert(bonus:IsShown(), "unrelated dungeon cannot borrow active key")
event("CHALLENGE_MODE_RESET")
offer(8)
assert(bonus:IsShown(), "reset run cannot supply stale key")
cfg.mythicPlus.mode = "hide"
offer(8)
assert(not bonus:IsShown(), "hide-all works with unknown key level")

reset()
cfg = { enabled = true, difficulty = { [15] = { hide = true } } }
offer(8)
assert(bonus:IsShown(), "sparse profile import must tolerate missing M+ config")
offer(15)
assert(not bonus:IsShown(), "sparse difficulty applies")
cfg.announce = true
api.ClearFilters()
assert(cfg.enabled and cfg.announce and not cfg.difficulty[15].hide and cfg.mythicPlus.mode == "show")
assert(not bonus:IsShown(), "clearing settings affects future offers only")
offer(15)
assert(bonus:IsShown())

reset()
assert(#api.GetEncounterGroups(15) == 0, "journal not ready returns empty")
journalReady = true
local groups = api.GetEncounterGroups(15)
assert(#groups == 1 and groups[1].id == 10 and groups[1].encounters[2].id == 102, "journal retry preserves raid and boss order")
assert(tier == 1 and instance == 30 and journalDifficulty == 14, "journal selection restored")
groups = api.GetEncounterGroups(172)
assert(#groups == 1 and groups[1].id == 20 and groups[1].encounters[1].id == 201, "world bosses separate")
offer(999, 901)
offer(998, 901)
assert(#api.GetEncounterGroups(999) == 1 and #api.GetEncounterGroups(998) == 1, "unknown encounters retain all seen difficulties")
assert(global.seenDifficulties[999] and global.seenEncounters[901].name == "Encounter 901")
assert(api.GetSeenDifficulties()[1] == 998, "seen difficulty list sorted")

print("OK: bonus_roll_filter_test")
