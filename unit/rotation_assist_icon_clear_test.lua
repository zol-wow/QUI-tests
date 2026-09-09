-- Run: luajit tests/unit/rotation_assist_icon_clear_test.lua
--
-- The standalone Rotation Assist icon subscribes to QUI.AssistedCombatNext.
-- A nil notification ("no suggestion" / Assisted Combat went away) must drop
-- the previous spell's texture and keybind instead of leaving it on screen,
-- and a later valid suggestion must restore the display.

local function noop() end

function issecretvalue(v) return type(v) == "table" and v.__secret == true end
function InCombatLockdown() return false end
function UnitExists() return false end
function UnitCanAttack() return false end
function GetTime() return 0 end
function GetBindingKey() return nil end
function hooksecurefunc() end

UIParent = { GetCenter = function() return 0, 0 end }
C_ActionBar = { FindSpellActionButtons = function() return nil end }
C_Spell = {
    GetSpellTexture = function(id) return "tex:" .. tostring(id) end,
    IsSpellUsable = function() return true, false end,
    SpellHasRange = function() return false end,
    IsSpellInRange = function() return true end,
    GetOverrideSpell = function(id) return id end,
}

local afterQueue = {}
C_Timer = {
    After = function(_, fn) afterQueue[#afterQueue + 1] = fn end,
    NewTimer = function() return { Cancel = noop } end,
    NewTicker = function(_, fn) return { Cancel = noop, fn = fn } end,
}

local nextSpell = nil
C_AssistedCombat = {
    GetNextCastSpell = function() return nextSpell end,
    GetActionSpell = function() return 9999 end,
    IsAvailable = function() return true end,
}

-- Permissive widget stub: records what the test cares about, ignores the rest.
local function NewWidget()
    local w = { shown = false }
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:SetTexture(t) self.texture = t end
    function w:SetVertexColor(r, g, b) self.color = { r, g, b } end
    function w:SetText(t) self.text = t end
    function w:Clear() self.cleared = true end
    function w:SetScript(name, fn) self[name] = fn end
    function w:RegisterEvent() end
    return setmetatable(w, { __index = function() return noop end })
end

local iconFrame
local allFrames = {}
function CreateFrame(kind, name)
    local f = NewWidget()
    allFrames[#allFrames + 1] = f
    function f:CreateTexture() self.icon = NewWidget(); return self.icon end
    function f:CreateFontString() self.keybindText = NewWidget(); return self.keybindText end
    if name == "QUI_RotationAssistIcon" then iconFrame = f end
    if kind == "Cooldown" then f.isCooldown = true end
    return f
end

local profile = {
    rotationAssistIcon = { enabled = true, visibility = "always", showKeybind = true, cooldownSwipeEnabled = false },
    general = {},
}
local core = { db = { profile = profile } }

local addon = {
    LSM = { Fetch = function() return "font" end },
    Helpers = {
        GetCore = function() return core end,
        IsSecretValue = function(v) return issecretvalue(v) end,
        ApplyCooldownFromSpell = function() return false end,
        GetGeneralFont = function() return "font" end,
        GetGeneralFontOutline = function() return "" end,
        GetSkinBorderColor = function() return 1, 1, 1, 1 end,
        GetSkinBgColor = function() return 0, 0, 0 end,
        CreateStateTable = function() return setmetatable({}, { __mode = "k" }) end,
    },
}
_G.QUI = addon

assert(loadfile("core/safecall.lua"))("QUI", addon)
-- keybinds.lua owns the shared poller; it loads before rotationassist.lua in the toc.
assert(loadfile("modules/utility/keybinds.lua"))("QUI", addon)
assert(loadfile("modules/combat/rotationassist.lua"))("QUI", addon)

local failures = 0
local function check(label, cond)
    if cond then print("ok   - " .. label) else failures = failures + 1; print("FAIL - " .. label) end
end

-- Boot: PLAYER_ENTERING_WORLD → InitOrCatchUp → deferred via C_Timer.After.
nextSpell = 100
_G.QUI_RefreshRotationAssistIcon()
for _, fn in ipairs(afterQueue) do fn() end
afterQueue = {}

local poll = addon.AssistedCombatNext
assert(iconFrame, "icon frame should have been created")
check("icon subscribes to the shared poller once enabled", poll.IsPolling())

poll._Tick()
check("first suggestion paints the spell texture", iconFrame.icon.texture == "tex:100")

-- The poller reports "no suggestion".
nextSpell = nil
poll._Tick()
check("nil suggestion drops the previous spell texture", iconFrame.icon.texture ~= "tex:100")
check("nil suggestion falls back to the Assisted Combat action icon", iconFrame.icon.texture == "tex:9999")
check("nil suggestion clears the keybind text", iconFrame.keybindText.text == "")
check("frame stays visible under 'always' visibility", iconFrame.shown == true)

-- A later valid suggestion restores the display.
nextSpell = 200
poll._Tick()
check("next valid suggestion repaints the texture", iconFrame.icon.texture == "tex:200")

-- Target change resets the query cache; an empty answer afterwards must
-- still repaint (the cache and the painted state are not the same thing).
local function FireEvent(event)
    for _, f in ipairs(allFrames) do
        if f.OnEvent then f.OnEvent(f, event) end
    end
end
nextSpell = nil
FireEvent("PLAYER_TARGET_CHANGED")
check("target change with no suggestion clears the old texture", iconFrame.icon.texture == "tex:9999")
nextSpell = 300
poll._Tick()
check("suggestion after target change repaints", iconFrame.icon.texture == "tex:300")
nextSpell = 310
FireEvent("PLAYER_TARGET_CHANGED")
nextSpell = nil
poll._Tick()
check("poller nil after a target-change reset still clears", iconFrame.icon.texture == "tex:9999")
nextSpell = 200
poll._Tick()
check("suggestion after poller clear repaints", iconFrame.icon.texture == "tex:200")

-- Assisted Combat going away clears without re-querying.
nextSpell = 200 -- API would still answer with the stale spell
C_AssistedCombat.IsAvailable = function() return false end
poll.Reset()
check("unavailable spec clears the stale texture even though the API still answers", iconFrame.icon.texture == "tex:9999")

-- Refreshing the icon while unavailable re-queries (API still answers 200)
-- and re-subscribes; the subscribe must deliver the clear again.
_G.QUI_RefreshRotationAssistIcon()
check("refresh while unavailable does not resurrect the stale suggestion", iconFrame.icon.texture == "tex:9999")

-- Disabling the icon unsubscribes.
C_AssistedCombat.IsAvailable = function() return true end
profile.rotationAssistIcon.enabled = false
_G.QUI_RefreshRotationAssistIcon()
poll.Reset()
check("disabled icon is not subscribed to the poller", not poll.IsPolling())

if failures > 0 then
    print(("FAILED: rotation_assist_icon_clear_test (%d)"):format(failures))
    os.exit(1)
end
print("OK: rotation_assist_icon_clear_test")
