-- tests/unit/player_spells_skin_dynamic_text_test.lua
-- Run: lua tests/unit/player_spells_skin_dynamic_text_test.lua
--
-- Spellbook content is paged and pooled. Text styling must be applied after
-- Blizzard displays/acquires the visible spell rows, not only once on addon load.

-- luacheck: globals _G C_Timer hooksecurefunc PagedContentFrameBaseMixin TalentFrameBaseMixin

C_Timer = { After = function(_, fn) fn() end }
function hooksecurefunc(target, method, callback)
    if type(target) ~= "table" or type(target[method]) ~= "function" then return end
    local original = target[method]
    target[method] = function(self, ...)
        local results = { original(self, ...) }
        callback(self, ...)
        return unpack(results)
    end
end

PagedContentFrameBaseMixin = { Event = { OnUpdate = "OnUpdate" } }
TalentFrameBaseMixin = { Event = { TalentButtonAcquired = "TalentButtonAcquired" } }

local callbacks = {}
local registered = {}
local calls = {}
local frameData = setmetatable({}, { __mode = "k" })
local settings = { skinSpellBook = true }

local function NewFontString(r, g, b, a)
    local fontString = { color = { r, g, b, a }, font = "Blizzard.ttf", size = 16, flags = "OUTLINE" }
    function fontString:GetFont() return self.font, self.size, self.flags end
    function fontString:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function fontString:SetTextColor(red, green, blue, alpha) self.color = { red, green, blue, alpha } end
    return fontString
end

local function NewTalentButton()
    local button = {
        SpendText = NewFontString(1, 0.82, 0, 1),
        spendTextShadows = {},
    }
    for index = 1, 4 do
        button.spendTextShadows[index] = NewFontString(0, 0, 0, 1)
    end
    function button:ApplyVisualState()
        self.SpendText:SetTextColor(1, 0.82, 0, 1)
    end
    return button
end

local function NewPagedSpellsFrame(row)
    local pagedSpellsFrame = {}
    function pagedSpellsFrame:RegisterCallback(event, callback, owner)
        self.callbackEvent = event
        self.callback = callback
        self.callbackOwner = owner
    end
    function pagedSpellsFrame:EnumerateFrames()
        local index = 0
        local frames = { row }
        return function()
            index = index + 1
            if frames[index] then
                return index, frames[index]
            end
        end
    end
    return pagedSpellsFrame
end

local function NewPlayerSpellsFrame(name, row)
    local pagedSpellsFrame = NewPagedSpellsFrame(row)
    local talentButton = NewTalentButton()
    local talentDisplays = {}
    local frame = {
        name = name,
        TabSystem = { tabs = {} },
        SpellBookFrame = {
            PagedSpellsFrame = pagedSpellsFrame,
        },
        TalentsFrame = { talentDisplayFramePool = {} },
    }
    function frame.TalentsFrame:EnumerateAllTalentButtons()
        local yielded
        return function()
            if yielded then return nil end
            yielded = true
            return talentButton
        end
    end
    function frame.TalentsFrame:RegisterCallback(event, callback, owner)
        self.callbackEvent = event
        self.callback = callback
        self.callbackOwner = owner
    end
    function frame.TalentsFrame.talentDisplayFramePool:EnumerateActive()
        local index = 0
        return function()
            index = index + 1
            return talentDisplays[index]
        end
    end
    function frame.TalentsFrame:AcquireTalentDisplayFrame()
        local display = NewTalentButton()
        talentDisplays[#talentDisplays + 1] = display
        return display
    end
    return frame, pagedSpellsFrame, talentButton
end

local lateSpellRow = { name = "lateSpellRow" }
local playerSpellsFrame, pagedSpellsFrame, talentButton = NewPlayerSpellsFrame("PlayerSpellsFrame", lateSpellRow)
_G.PlayerSpellsFrame = playerSpellsFrame

local function CreateStateTable()
    local tbl = setmetatable({}, { __mode = "k" })
    return tbl, function(key)
        local state = tbl[key]
        if not state then
            state = {}
            tbl[key] = state
        end
        return state
    end
end

local ns = {
    Helpers = {
        CreateStateTable = CreateStateTable,
        GetCore = function()
            return {
                db = {
                    profile = {
                        general = settings,
                    },
                },
            }
        end,
    },
    Registry = {
        Register = function(_, key, feature)
            registered[key] = feature
        end,
    },
}

ns.SkinBase = {
    RefreshFrameBackdropColors = function() end,
    IsSkinned = function(frame) return calls.marked == frame end,
    SkinButtonFrameTemplate = function(frame)
        calls.buttonFrame = frame
    end,
    SkinTabGroup = function() end,
    RefreshTabSelected = function() end,
    SkinFrameText = function(frame, opts)
        calls[frame] = opts or {}
    end,
    SkinFontString = function(fontString, opts)
        local color = opts and opts.color
        if color then
            fontString:SetTextColor(color[1], color[2], color[3], color[4])
        end
    end,
    LockFrameTextObjects = function(frame)
        calls.locked = calls.locked or {}
        calls.locked[frame] = true
    end,
    MarkSkinned = function(frame)
        calls.marked = frame
    end,
    SetFrameData = function(frame, key, value)
        frameData[frame] = frameData[frame] or {}
        frameData[frame][key] = value
    end,
    GetFrameData = function(frame, key)
        local data = frameData[frame]
        return data and data[key]
    end,
    OnAddOnLoaded = function(addon, callback)
        callbacks[addon] = callback
    end,
}

assert(loadfile("modules/skinning/frames/journals.lua"))("QUI", ns)
assert(type(callbacks.Blizzard_PlayerSpells) == "function", "PlayerSpells load hook must be registered")

callbacks.Blizzard_PlayerSpells()

assert(calls.buttonFrame == playerSpellsFrame, "PlayerSpellsFrame must still get QUI frame chrome")
assert(calls.marked == playerSpellsFrame, "PlayerSpellsFrame must be marked skinned")
assert(pagedSpellsFrame.callbackEvent == PagedContentFrameBaseMixin.Event.OnUpdate,
    "spellbook skin must hook paged spell updates")
assert(playerSpellsFrame.TalentsFrame.callbackEvent == TalentFrameBaseMixin.Event.TalentButtonAcquired,
    "talent skin must hook newly acquired buttons")
assert(talentButton.SpendText.color[1] == 1 and talentButton.SpendText.color[2] == 1
    and talentButton.SpendText.color[3] == 1 and talentButton.SpendText.color[4] == 1,
    "talent spend text must use QUI white")
for _, shadow in ipairs(talentButton.spendTextShadows) do
    assert(shadow.color[1] == 0 and shadow.color[2] == 0 and shadow.color[3] == 0 and shadow.color[4] == 1,
        "talent spend text shadows must remain black")
end

talentButton:ApplyVisualState()
assert(talentButton.SpendText.color[1] == 1 and talentButton.SpendText.color[2] == 1
    and talentButton.SpendText.color[3] == 1 and talentButton.SpendText.color[4] == 1,
    "native talent visual updates must not restore yellow spend text")

local switchedSpecTalentButton = NewTalentButton()
playerSpellsFrame.TalentsFrame.callback(playerSpellsFrame.TalentsFrame.callbackOwner, switchedSpecTalentButton)
switchedSpecTalentButton:ApplyVisualState()
assert(switchedSpecTalentButton.SpendText.color[1] == 1 and switchedSpecTalentButton.SpendText.color[2] == 1
    and switchedSpecTalentButton.SpendText.color[3] == 1 and switchedSpecTalentButton.SpendText.color[4] == 1,
    "talent buttons acquired after a spec switch must use QUI white")
for _, shadow in ipairs(switchedSpecTalentButton.spendTextShadows) do
    assert(shadow.color[1] == 0 and shadow.color[2] == 0 and shadow.color[3] == 0 and shadow.color[4] == 1,
        "talent buttons acquired after a spec switch must keep black shadows")
end

local acquiredTalentDisplay = playerSpellsFrame.TalentsFrame:AcquireTalentDisplayFrame()
acquiredTalentDisplay:ApplyVisualState()
assert(acquiredTalentDisplay.SpendText.color[1] == 1 and acquiredTalentDisplay.SpendText.color[2] == 1
    and acquiredTalentDisplay.SpendText.color[3] == 1 and acquiredTalentDisplay.SpendText.color[4] == 1,
    "pooled talent displays acquired after a loadout change must use QUI white")

pagedSpellsFrame.callback(pagedSpellsFrame, pagedSpellsFrame.callbackOwner)

assert(calls[lateSpellRow] and calls[lateSpellRow].recurse == true and calls[lateSpellRow].chrome == true,
    "late spellbook rows must receive recursive QUI chrome text styling")
-- LockFrameTextObjects was removed from SkinSpellRows; static text durability now
-- comes from the global font-object override. Interactive reverts on spell rows accepted.

settings.skinSpellBook = false
calls = {}
frameData = setmetatable({}, { __mode = "k" })
local refreshLateSpellRow = { name = "refreshLateSpellRow" }
local refreshPlayerSpellsFrame, refreshPagedSpellsFrame, refreshTalentButton =
    NewPlayerSpellsFrame("RefreshPlayerSpellsFrame", refreshLateSpellRow)
_G.PlayerSpellsFrame = refreshPlayerSpellsFrame

callbacks.Blizzard_PlayerSpells()

assert(calls.buttonFrame == nil, "disabled spellbook skin must not skin on Blizzard load")
assert(refreshPagedSpellsFrame.callbackEvent == nil, "disabled spellbook skin must not hook paged updates")

settings.skinSpellBook = true
assert(registered.skinSpellBook and type(registered.skinSpellBook.refresh) == "function",
    "spellbook skin must register an options refresh")
registered.skinSpellBook.refresh()

assert(calls.buttonFrame == refreshPlayerSpellsFrame,
    "enabling spellbook skin after Blizzard load must skin PlayerSpellsFrame")
assert(refreshPagedSpellsFrame.callbackEvent == PagedContentFrameBaseMixin.Event.OnUpdate,
    "enabling spellbook skin after Blizzard load must hook paged updates")
assert(refreshTalentButton.SpendText.color[1] == 1 and refreshTalentButton.SpendText.color[2] == 1
    and refreshTalentButton.SpendText.color[3] == 1 and refreshTalentButton.SpendText.color[4] == 1,
    "refreshed talent spend text must use QUI white")

refreshPagedSpellsFrame.callback(refreshPagedSpellsFrame, refreshPagedSpellsFrame.callbackOwner)

assert(calls[refreshLateSpellRow]
    and calls[refreshLateSpellRow].recurse == true
    and calls[refreshLateSpellRow].chrome == true,
    "refreshed spellbook rows must receive recursive QUI chrome text styling")
-- LockFrameTextObjects removed from SkinSpellRows; interactive reverts on refreshed
-- spell rows are accepted under the global font-object override.

print("OK: player_spells_skin_dynamic_text_test")
