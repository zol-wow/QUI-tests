-- luacheck: globals Data WindowManager
local function readAll(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*a")
    file:close()
    return data:gsub("\r\n", "\n")
end

local failures = {}
local function check(value, message)
    if not value then failures[#failures + 1] = message end
end

local src = readAll("QUI_DamageMeter/damage_meter/damage_meter.lua")
local policyChunk = src:match("(local function CanOpenDetailInCombat.-\nend\n)")
check(policyChunk, "missing CanOpenDetailInCombat policy helper")
if policyChunk then
    local policy = assert(loadstring(policyChunk .. "\nreturn CanOpenDetailInCombat"))()
    local deathsType = 11
    check(policy({ isLocalPlayer = false }, 1, deathsType, false), "out-of-combat detail must be allowed")
    check(policy({ isLocalPlayer = false }, deathsType, deathsType, true), "Deaths detail must be allowed in combat")
    check(policy({ isLocalPlayer = true }, 1, deathsType, true), "local-player detail must be allowed in combat")
    check(not policy({ isLocalPlayer = false }, 1, deathsType, true), "other-player detail must remain blocked in combat")
    check(not policy(nil, 1, deathsType, true), "missing-source detail must remain blocked in combat")
end

local dataStart = assert(src:find("function Data:GetBreakdownView", 1, true))
local dataEnd = assert(src:find("\nlocal function AggregateSpellsByUnit", dataStart))
local dataChunk = src:sub(dataStart, dataEnd - 1)
local call
Data = {}
C_DamageMeter = {
    GetCombatSessionSourceFromID = function(...)
        call = { ... }
        return { combatSpells = {}, maxAmount = 0, totalAmount = 0 }
    end,
}
Helpers = { IsSecretValue = function() return false end }
NormalizeSpells = function(spells) return spells end
TableOrEmpty = function(value) return value or {} end
AmountOrDefault = function(value, fallback) return value == nil and fallback or value end
assert(loadstring(dataChunk))()
Data:GetBreakdownView(1, 7, "Player-1", 44, 93)
check(call and call[1] == 93 and call[2] == 7 and call[3] == "Player-1" and call[4] == 44,
    "historical breakdown must pass the selected sessionID and source identity to GetCombatSessionSourceFromID")

local windowStart = assert(src:find("function Window.New", 1, true))
local windowEnd = assert(src:find("\nfunction Window:Hide", windowStart))
local windowChunk = src:sub(windowStart, windowEnd - 1)
check(windowChunk:find("self.SegmentButton", 1, true), "window must expose a visible SegmentButton")
check(windowChunk:find("self:_OpenSessionMenu()", 1, true), "SegmentButton must open the session menu")

local openStart = assert(src:find("function Window:OpenBreakdown", 1, true))
local openEnd = assert(src:find("\nfunction Window:RefreshBreakdown", openStart))
local openChunk = src:sub(openStart, openEnd - 1)
check(openChunk:find("deathRecapID", 1, true), "Deaths rows must forward the source deathRecapID")
check(openChunk:find('UnitGUID("player")', 1, true), "local combat detail must use the player's non-secret GUID")

local targetsStart = assert(src:find("function Breakdown:_ResolveTargets", 1, true))
local targetsEnd = assert(src:find("\nfunction Breakdown:Refresh", targetsStart))
local targetsChunk = src:sub(targetsStart, targetsEnd - 1)
check(targetsChunk:find("InCombatLockdown", 1, true), "target reconstruction must remain disabled in combat")

local breakdownStart = assert(src:find("function Breakdown:_BuildRow", 1, true))
local breakdownEnd = assert(src:find("function Breakdown:_SetTargetRow", breakdownStart, true))
local breakdownChunk = src:sub(breakdownStart, breakdownEnd - 1)
check(breakdownChunk:find("%%", 1, true), "spell rows must display their percentage of the source total")
check(breakdownChunk:find("GameTooltip:SetSpellByID", 1, true), "spell rows must expose native spell tooltips")

check(tonumber(src:match("local BREAKDOWN_POOL_SIZE%s*=%s*(%d+)")) == 40,
    "breakdown popup must retain 40 detail rows")
check(tonumber(src:match("local PREVIEW_SPELL_LIMIT%s*=%s*(%d+)")) == 15,
    "hover preview must cap spell rows at 15")
check(tonumber(src:match("local PREVIEW_TARGET_LIMIT%s*=%s*(%d+)")) == 3,
    "hover preview must cap target rows at 3")
check(src:match("local BREAKDOWN_MAX_HEIGHT%s*=%s*%d+"),
    "breakdown popup must define a maximum height")

local newStart = assert(src:find("function Breakdown.New", 1, true))
local newEnd = assert(src:find("\nfunction Breakdown:_SetSpellRow", newStart))
local newChunk = src:sub(newStart, newEnd - 1)
check(newChunk:find("self.scrollFrame", 1, true), "breakdown popup must own a ScrollFrame")
check(newChunk:find("self.scrollContent", 1, true), "breakdown popup must own scroll content")
check(newChunk:find("SetScrollChild", 1, true), "breakdown popup must attach its scroll child")
check(newChunk:find("EnableMouseWheel", 1, true) and newChunk:find('SetScript("OnMouseWheel"', 1, true),
    "breakdown popup must scroll with the mouse wheel")
check(newChunk:find("No death recap available", 1, true),
    "empty Death hover previews must explain that no recap is available")

local refreshStart = assert(src:find("function Breakdown:Refresh", 1, true))
local refreshEnd = assert(src:find("\nfunction Breakdown:Open", refreshStart))
local refreshChunk = src:sub(refreshStart, refreshEnd - 1)
check(refreshChunk:find("GetPreviewSpellLimit", 1, true), "preview refresh must use the configured spell-row limit")
check(refreshChunk:find("PREVIEW_TARGET_LIMIT", 1, true), "preview refresh must use the target-row limit")
check(refreshChunk:find("BREAKDOWN_MAX_HEIGHT", 1, true) and refreshChunk:find("math.min", 1, true),
    "breakdown height must be capped instead of growing to every row")

local previewStart = src:find("function Window:PreviewBreakdown", 1, true)
local previewEnd = previewStart and src:find("\nfunction Window:ClosePreview", previewStart)
check(previewStart and previewEnd, "window must expose the rich hover preview lifecycle")
if previewStart and previewEnd then
    local previewChunk = src:sub(previewStart, previewEnd - 1)
    check(previewChunk:find("self:OpenBreakdown", 1, true) and previewChunk:find(", true)", 1, true),
        "hover preview must reuse the breakdown open path in preview mode")
end

local hoverStart = assert(src:find("function Window:_AttachRowVisuals", 1, true))
local hoverEnd = assert(src:find("\nif ns.TooltipInspect", hoverStart))
local hoverChunk = src:sub(hoverStart, hoverEnd - 1)
check(hoverChunk:find("self:PreviewBreakdown", 1, true), "main-row hover must open the rich breakdown preview")
check(hoverChunk:find("self:ClosePreview", 1, true), "leaving a main row must close its preview")
check(refreshChunk:find("Data:GetBreakdownView", 1, true), "rich hover must reuse the existing breakdown data path")
check(refreshChunk:find("self:_SetSpellRow", 1, true) and refreshChunk:find("self:_SetTargetRow", 1, true),
    "rich hover must render spell and target preview rows")

local trailingChunk = src:match("(local function TakeTrailingSessions.-\nend\n)")
check(trailingChunk, "missing TakeTrailingSessions helper")
if trailingChunk then
    local takeTrailing = assert(loadstring(trailingChunk .. "\nreturn TakeTrailingSessions"))()
    local sessions = {}
    for i = 1, 25 do sessions[i] = { sessionID = i } end
    local trailing = takeTrailing(sessions, 20)
    check(#trailing == 20 and trailing[1].sessionID == 6 and trailing[20].sessionID == 25,
        "segment picker must retain the trailing 20 sessions in order")
    check(#sessions == 25, "segment picker must not mutate Blizzard's session list")
end

check(src:find("function WindowManager:ApplySessionSelection", 1, true),
    "WindowManager must own opt-in synchronized segment selection")
check(src:find("function WindowManager:AutoCurrentOnCombat", 1, true),
    "WindowManager must restore historical windows to Current on combat start")
check(src:find("syncSegments", 1, true), "segment selection must consult each window's sync opt-in")
check(src:find("autoCurrentOnCombat", 1, true), "combat-start selection must consult each window's auto-current setting")
check(src:find("TakeTrailingSessions(sessions, 20)", 1, true),
    "session menu must use the trailing-20 helper")
check(src:find("sessionID == self.sessionID", 1, true) or src:find("self.sessionID == sessionID", 1, true),
    "session menu must identify the active historical segment")
check(src:find("BuildPreviousSessionLabel", 1, true),
    "historical sessions must keep their Blizzard name and duration label")

local managerStart = src:find("local function ApplySessionToWindow", 1, true)
local managerEnd = managerStart and src:find("\nfunction WindowManager:Spawn", managerStart)
if managerStart and managerEnd then
    local settings = { windows = {
        [1] = { syncSegments = true, autoCurrentOnCombat = true, sessionType = 1 },
        [2] = { syncSegments = true, autoCurrentOnCombat = true, sessionType = 0 },
        [3] = { syncSegments = false, autoCurrentOnCombat = false, sessionType = 0 },
    } }
    WindowManager = { windows = {}, refreshes = 0 }
    function WindowManager:Enumerate(fn)
        for id, window in pairs(self.windows) do fn(id, window) end
    end
    function WindowManager:RefreshAll() self.refreshes = self.refreshes + 1 end
    GetSettings = function() return settings end
    Enum = { DamageMeterSessionType = { Current = 1, Overall = 0 } }
    assert(loadstring(src:sub(managerStart, managerEnd - 1)))()
    local w1 = { windowID = 1, sessionType = 1 }
    local w2 = { windowID = 2, sessionType = 0 }
    local w3 = { windowID = 3, sessionType = 0 }
    WindowManager.windows = { [1] = w1, [2] = w2, [3] = w3 }
    WindowManager:ApplySessionSelection(w1, nil, 91)
    check(w1.sessionID == 91 and w2.sessionID == 91 and w3.sessionID == nil,
        "synced session selection must update only the opted-in cohort")
    check(settings.windows[1].sessionType == 1 and settings.windows[2].sessionType == 0,
        "historical session IDs must remain runtime-only")
    w1.sessionID, w1.sessionType = 17, nil
    w2.sessionID, w2.sessionType = nil, 0
    w3.sessionID, w3.sessionType = 33, nil
    WindowManager.refreshes = 0
    WindowManager:AutoCurrentOnCombat()
    check(w1.sessionID == nil and w1.sessionType == 1,
        "auto-current must restore an opted-in historical window")
    check(w2.sessionID == nil and w2.sessionType == 0,
        "auto-current must not change an Overall window")
    check(w3.sessionID == 33 and w3.sessionType == nil,
        "auto-current must leave an opted-out historical window unchanged")
    check(WindowManager.refreshes == 1, "auto-current must refresh once after changing windows")
end

for _, event in ipairs({ "UNIT_FLAGS", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD" }) do
    check(src:find('RegisterEvent("' .. event .. '"', 1, true),
        "damage-meter lifecycle must register " .. event)
end
check(src:find("WindowManager:AutoCurrentOnCombat()", 1, true),
    "group or encounter pull must invoke historical auto-current")

local defaultsSrc = readAll("core/defaults.lua")
local settingsSrc = readAll("QUI_DamageMeter/damage_meter/settings/damage_meter_content.lua")
for _, key in ipairs({
    "syncSegments", "autoCurrentOnCombat", "autoSwapChallengeSessions", "mythicStartDMType",
    "showSpellTooltips", "showAllBreakdownSpells", "hoverTooltipScale",
}) do
    check(defaultsSrc:find(key, 1, true), "damage-meter defaults must expose " .. key)
    check(settingsSrc:find(key, 1, true), "damage-meter settings must expose " .. key)
end
local damageMeterDefaultsStart = assert(defaultsSrc:find("damageMeter = {", 1, true))
local windowsStart = assert(defaultsSrc:find("windows = {", damageMeterDefaultsStart, true))
local windowsEnd = assert(defaultsSrc:find("\n%s*windowCount", windowsStart))
local windowDefaults = defaultsSrc:sub(windowsStart, windowsEnd - 1)
for _, key in ipairs({ "syncSegments", "autoCurrentOnCombat", "autoSwapChallengeSessions", "mythicStartDMType" }) do
    check(windowDefaults:find(key, 1, true), "per-window defaults must expose " .. key)
end

local challengeStart = src:find("function WindowManager:ApplyChallengeModeStart", 1, true)
local challengeEnd = challengeStart and src:find("\nfunction WindowManager:ApplyChallengeModeReset", challengeStart)
local challengeChunk = challengeStart and challengeEnd and src:sub(challengeStart, challengeEnd - 1) or ""
check(challengeChunk:find("autoSwapChallengeSessions", 1, true),
    "Mythic+ session swap must be configured per window")
check(challengeChunk:find("windowState.mythicStartDMType", 1, true),
    "Mythic+ start meter type must be configured per window")

if managerStart and challengeStart and challengeEnd then
    local settings = { autoResetOnChallengeStart = false, windows = {
        [1] = { autoSwapChallengeSessions = true, mythicStartDMType = 4, sessionType = 0 },
        [2] = { autoSwapChallengeSessions = false, mythicStartDMType = 6, sessionType = 0 },
        [3] = { autoSwapChallengeSessions = true, mythicStartDMType = false, sessionType = 1 },
    } }
    WindowManager = { windows = {}, refreshes = 0 }
    function WindowManager:Enumerate(fn)
        for id, window in pairs(self.windows) do fn(id, window) end
    end
    function WindowManager:RefreshAll() self.refreshes = self.refreshes + 1 end
    GetSettings = function() return settings end
    Enum = { DamageMeterSessionType = { Current = 1, Overall = 0 } }
    ResetAllDamageMeterSessions = function() end
    local helperEnd = assert(src:find("\nfunction WindowManager:ApplySessionSelection", managerStart))
    local helperChunk = src:sub(managerStart, helperEnd - 1)
    assert(loadstring(helperChunk .. "\n" .. challengeChunk))()
    local function window(id, sessionType, sessionID, meterType)
        local value = { windowID = id, sessionType = sessionType, sessionID = sessionID, damageMeterType = meterType }
        function value:SetDamageMeterType(nextType)
            self.damageMeterType = nextType
            settings.windows[id].damageMeterType = nextType
        end
        return value
    end
    local w1 = window(1, 0, nil, 0)
    local w2 = window(2, 0, nil, 0)
    local w3 = window(3, 1, 55, 0)
    WindowManager.windows = { [1] = w1, [2] = w2, [3] = w3 }
    local okStart = pcall(WindowManager.ApplyChallengeModeStart, WindowManager)
    check(okStart and w1.sessionType == 1 and w1.damageMeterType == 4,
        "M+ start must apply the first window's swap and meter-type default")
    check(okStart and w2.sessionType == 0 and w2.damageMeterType == 6,
        "M+ start meter type must apply independently of session swapping")
    check(okStart and w3.sessionID == 55,
        "M+ start must preserve a selected historical segment")
    local okCompleted = pcall(WindowManager.ApplyChallengeModeCompleted, WindowManager)
    check(okCompleted and w1.sessionType == 0 and w2.sessionType == 0 and w3.sessionID == 55,
        "M+ completion must swap only opted-in Current windows to Overall")
end

check(src:find("showSpellTooltips", 1, true), "spell tooltip runtime must honor showSpellTooltips")
check(src:find("showAllBreakdownSpells", 1, true), "hover preview runtime must honor showAllBreakdownSpells")
check(src:find("hoverTooltipScale", 1, true) and src:find("SetScale", 1, true),
    "hover preview runtime must apply hoverTooltipScale")
check(src:find("self.isEmbedded = not self.isPreview", 1, true)
    and src:find("self.frame:SetAllPoints(self.parentWindow.frame)", 1, true),
    "clicked breakdowns must replace the meter content in-window")
local previewLimitStart = assert(src:find("local PREVIEW_SPELL_LIMIT", 1, true))
local previewLimitEnd = assert(src:find("\nQUI_DamageMeter.GetPreviewSpellLimit", previewLimitStart))
local previewLimitChunk = src:sub(previewLimitStart, previewLimitEnd - 1)
local hoverSettings
GetSettings = function() return hoverSettings end
local getPreviewSpellLimit = assert(loadstring(previewLimitChunk .. "\nreturn GetPreviewSpellLimit"))()
hoverSettings = { showAllBreakdownSpells = true }
check(getPreviewSpellLimit() == 15, "show-all hover previews must retain the 15-row spell limit")
hoverSettings.showAllBreakdownSpells = false
check(getPreviewSpellLimit() < 15, "compact hover previews must use fewer than 15 spell rows")
local anchorStart = assert(src:find("local function AnchorBreakdownTo", 1, true))
local anchorEnd = assert(src:find("\nfunction Breakdown:_BuildRow", anchorStart))
local anchorChunk = src:sub(anchorStart, anchorEnd - 1)
for _, mode in ipairs({ '"center"', '"left"', '"right"' }) do
    check(anchorChunk:find(mode, 1, true), "breakdown anchoring must support " .. mode)
end
for _, mode in ipairs({ '"row"', '"center"', '"left"', '"right"' }) do
    check(settingsSrc:find(mode, 1, true), "breakdownAnchor settings must expose " .. mode)
end

local deathChunk = src:match("(local function GetDeathRecapRows.-\nend\n)")
check(deathChunk, "missing custom death-recap data helper")
if deathChunk then
    local recapID
    C_DeathRecap = {
        GetRecapEvents = function(id)
            recapID = id
            return { { timestamp = 30 }, { timestamp = 10 } }
        end,
        GetRecapMaxHealth = function() return 500 end,
    }
    IsSecretValue = function() return false end
    ns = { SafeCall = function(_, fn, ...) return true, fn(...) end }
    local getDeathRows = assert(loadstring(deathChunk .. "\nreturn GetDeathRecapRows"))()
    local events, maxHealth = getDeathRows(77)
    check(recapID == 77 and maxHealth == 500, "custom death recap must query the selected recap ID and max health")
    check(#events == 2 and events[1].timestamp == 10 and events[2].timestamp == 30,
        "custom death recap must render events oldest to newest")
end

local deathData = refreshChunk:find("GetDeathRecapRows", 1, true)
local deathRender = refreshChunk:find("self:_SetDeathRow", 1, true)
check(deathData and deathRender, "Deaths must use the custom recap data and row renderer")
local customOpen = openChunk:find("self._breakdown:Open", 1, true)
local nativeFallback = openChunk:find("OpenDeathRecapUI", 1, true)
check(customOpen and (not nativeFallback or customOpen < nativeFallback),
    "Deaths must attempt QUI detail before any native recap fallback")
check(not openChunk:find("if isPreview then return false", 1, true),
    "Deaths hover must not take the old native-only early exit")
check(src:find("function Breakdown:_SetDeathRow", 1, true), "Deaths must have a dedicated event-row renderer")

check(refreshChunk:find("isEnemyAttackers", 1, true),
    "Enemy Damage Taken must have a dedicated attacker branch")
check(refreshChunk:find("Data:GetEnemyAttackers", 1, true),
    "Enemy Damage Taken must query its attacker breakdown directly")
check(refreshChunk:find("self:_SetTargetRow(self.rows[i]", 1, true),
    "Enemy Damage Taken must render attackers as the primary detail rows")
check(refreshChunk:find("primaryLimit = self.isPreview and GetPreviewSpellLimit() or BREAKDOWN_POOL_SIZE", 1, true),
    "Enemy Damage Taken must use 15 hover rows and 40 clicked rows")

if #failures > 0 then
    error(table.concat(failures, "\n"), 0)
end

print("OK: damage_meter_detail_parity_test")
