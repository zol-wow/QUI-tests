local unpack = table.unpack or unpack
local path = 'QUI_ActionBars/actionbars/actionbars_uprank.lua'
local function spell(id, low, name, extra)
    local entry = { spellID = id, actionID = id, itemType = 1, name = name or 'Heal',
        subName = '', iconID = id, isPassive = false, isOffSpec = false, skillLineIndex = 1,
        lowRank = low }
    for key, value in pairs(extra or {}) do entry[key] = value end
    return entry
end

local function setup(options)
    options = options or {}
    local s = { book = { spell(90, true), spell(30, false) },
        actions = { [1] = { 'spell', 30 }, [2] = { 'spell', 90 }, [3] = { 'macro', 30 },
            [4] = { 'item', 30 }, [180] = { 'spell', 30 } },
        db = { enabled = true, global = { autoUpgradeSpellRanks = options.enabled ~= false } },
        loggedIn = options.loggedIn ~= false, frames = {}, pickups = 0, placements = 0, clears = 0, errors = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
    local secret = {}
    s.secret = secret
    env.issecretvalue = function(value) return rawequal(value, secret) end
    env.geterrorhandler = function()
        return function(err) s.errors[#s.errors + 1] = err end
    end
    local function safe(value, fallback)
        if env.issecretvalue(value) then return fallback end
        return value
    end
    env.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(script, handler) self[script] = handler end
        s.frames[#s.frames + 1] = frame
        return frame
    end
    function s:event(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] then frame.OnEvent(frame, event, ...) end
        end
    end
    env.IsLoggedIn = function() return s.loggedIn end
    env.InCombatLockdown = function() return s.combat end
    env.GetCursorInfo = function()
        if s.cursor then return unpack(s.cursor) end
    end
    env.ClearCursor = function()
        s.clears = s.clears + 1
        s.cursor = nil
        s:event('CURSOR_CHANGED')
    end
    env.GetActionInfo = function(slot)
        assert(slot >= 1 and slot <= 180, 'action scan outside real slots')
        if s.actions[slot] then return unpack(s.actions[slot]) end
    end
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function()
            return { name = 'Class', itemIndexOffset = 0, numSpellBookItems = #s.book,
                isGuild = false, shouldHide = false }
        end,
        GetSpellBookItemInfo = function(slot, bank)
            assert(bank == 0)
            return s.book[slot]
        end,
        IsSpellBookItemLowRank = function(slot, bank)
            assert(bank == 0 and s.book[slot], 'rank API needs player spellbook indices')
            return s.book[slot].lowRank
        end,
    }
    if options.noRankAPI then env.C_SpellBook.IsSpellBookItemLowRank = nil end
    env.C_Spell = { PickupSpell = function(id)
        assert(not s.combat and not s.cursor, 'pickup must not touch occupied cursor or combat')
        s.pickups = s.pickups + 1
        if s.pickupFailure == 'error' then error('pickup rejected') end
        if s.pickupFailure == 'empty' then return end
        if s.pickupFailure == 'item' then s.cursor = { 'item', 555 }; return end
        s.cursor = { 'spell', 999, 'spell', s.pickupFailure == 'wrong' and 555 or id }
        s:event('CURSOR_CHANGED')
    end }
    env.PlaceAction = function(slot)
        assert(not s.combat and s.cursor and s.cursor[1] == 'spell')
        s.placements = s.placements + 1
        if s.placeFailure == 'error' then error('placement rejected') end
        if s.placeFailure == 'unexpected' then
            s.cursor = { 'spell', 999, 'spell', s.actions[slot][2] }
            s.actions[slot] = { 'item', 555 }
            return
        end
        if s.placeFailure then return end
        local old = s.actions[slot]
        s.actions[slot] = { 'spell', s.cursor[4] }
        s.cursor = { 'spell', 999, 'spell', old[2] }
        s:event('CURSOR_CHANGED')
    end
    s.callbacks = {}
    s.core = { db = { RegisterCallback = function(owner, event, handler)
        s.callbacks[event] = function() handler(event, s.core.db) end
    end } }
    s.ns = { Client = { isForever = options.forever ~= false }, Helpers = {
        SafeValue = safe, GetCore = function() return s.core end, CreateDBGetter = function(key)
            assert(key == 'actionBars')
            return function() return s.db end
        end,
    } }
    local safeCall = assert(loadfile('core/safecall.lua', 't', env))
    if setfenv then setfenv(safeCall, env) end
    safeCall('QUI', s.ns)
    local chunk = loadfile(path, 't', env)
    if chunk then
        if setfenv then setfenv(chunk, env) end
        chunk('QUI_ActionBars', s.ns)
    end
    function s:refresh()
        if self.ns.ActionBarsSpellRanks then self.ns.ActionBarsSpellRanks.Refresh() end
    end
    function s:learn(id, event)
        for _, entry in ipairs(self.book) do
            if entry.name == 'Heal' then entry.lowRank = true end
        end
        self.book[#self.book + 1] = spell(id, false)
        self:event(event or 'SPELLS_CHANGED', id)
    end
    s:refresh()
    return s
end

local s = setup()
s:learn(12)
assert(s.actions[1][2] == 12, 'new highest rank must upgrade previous highest action')
assert(s.actions[180][2] == 12, 'hidden final action page must upgrade')
assert(s.actions[2][2] == 90, 'intentional lower rank must survive')
assert(s.actions[3][1] == 'macro' and s.actions[4][1] == 'item', 'macros/items must survive')
assert(not s.cursor, 'successful placement must release only its own cursor')

for _, populateEvent in ipairs({ 'PLAYER_LOGIN', 'SPELLS_CHANGED' }) do
    s = setup({ loggedIn = false })
    s.book[2].lowRank = true
    s.book[#s.book + 1] = spell(12, false)
    if populateEvent == 'SPELLS_CHANGED' then
        s:event('SPELLS_CHANGED')
        assert(s.pickups == 0, 'pre-login spellbook population must never mutate existing slots')
    end
    s.loggedIn = true
    s:event('PLAYER_LOGIN')
    assert(s.pickups == 0 and s.actions[1][2] == 30,
        'login must baseline complete spellbook without treating initial ranks as newly learned')
    s.actions[5] = { 'spell', 12 }
    s:learn(8)
    assert(s.actions[1][2] == 30 and s.actions[5][2] == 8,
        'future learns must use login baseline and preserve existing lower ranks')
end

for _, options in ipairs({ { enabled = false }, { forever = false }, { noRankAPI = true } }) do
    s = setup(options)
    s:learn(12)
    assert(s.pickups == 0 and s.actions[1][2] == 30, 'unsupported/disabled mode must be inert')
end
s = setup()
s.db.enabled = false
s:refresh()
s:learn(12)
assert(s.pickups == 0, 'disabled action bars must be inert')

s = setup({ enabled = false })
s:learn(12)
s.db.global.autoUpgradeSpellRanks = true
s:refresh()
assert(s.actions[1][2] == 30, 'enabling must baseline without changing existing lower ranks')
s.actions[5] = { 'spell', 12 }
s:learn(8)
assert(s.actions[1][2] == 30 and s.actions[5][2] == 8, 'only post-enable prior highest upgrades')

for _, firstEvent in ipairs({ 'SPELLS_CHANGED', 'LEARNED_SPELL_IN_SKILL_LINE' }) do
    s = setup()
    s:learn(12, firstEvent)
    s:event(firstEvent == 'SPELLS_CHANGED' and 'LEARNED_SPELL_IN_SKILL_LINE' or 'SPELLS_CHANGED', 12)
    assert(s.actions[1][2] == 12 and s.placements == 2, 'learn event order must not double-upgrade')
end
s = setup()
s:event('LEARNED_SPELL_IN_SKILL_LINE', 12)
s:learn(12)
assert(s.actions[1][2] == 12, 'learn event before spellbook update must preserve baseline')

s = setup()
s.combat = true
s:learn(12)
s:refresh()
s:learn(8)
assert(s.pickups == 0, 'combat must defer mutations')
s.actions[180] = { 'macro', 77 }
s.combat = false
s:event('PLAYER_REGEN_ENABLED')
assert(s.actions[1][2] == 8, 'rapid rank learns must retain original slot and newest target')
assert(s.actions[180][1] == 'macro', 'queued slot edits must survive')

s = setup()
s.cursor = { 'item', 555 }
s:learn(12)
s:refresh()
assert(s.pickups == 0 and s.clears == 0 and s.cursor[2] == 555, 'user cursor must stay untouched')
s.cursor = nil
s:event('CURSOR_CHANGED')
assert(s.actions[1][2] == 12, 'cursor release must resume queued upgrade')

for _, reset in ipairs({ 'disable', 'profile' }) do
    s = setup()
    s.combat = true
    s:learn(12)
    if reset == 'disable' then s.db.global.autoUpgradeSpellRanks = false
    else s.db = { enabled = true, global = { autoUpgradeSpellRanks = true } } end
    s:refresh()
    s.combat = false
    s:event('PLAYER_REGEN_ENABLED')
    assert(s.actions[1][2] == 30 and s.pickups == 0, 'reset must discard queued old-profile writes')
end

for _, event in ipairs({ 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }) do
    s = setup()
    s.combat = true
    s:learn(12)
    s.callbacks[event]()
    s.combat = false
    s:event('PLAYER_REGEN_ENABLED')
    assert(s.pickups == 0, 'profile lifecycle must discard queued writes even with same DB table')
    s.actions[5] = { 'spell', 12 }
    s:learn(8)
    assert(s.actions[5][2] == 8 and s.actions[1][2] == 30, 'profile reset must establish fresh baseline')
end

for _, missing in ipairs({ 'removed', 'offspec', 'passive' }) do
    s = setup()
    if missing == 'removed' then table.remove(s.book, 2)
    elseif missing == 'offspec' then s.book[2].isOffSpec = true
    else s.book[2].isPassive = true end
    s:learn(12)
    assert(s.pickups == 0, 'old rank must still belong to active player spellbook')
end
s = setup()
s.combat = true
s:learn(12)
table.remove(s.book)
s.combat = false
s:event('PLAYER_REGEN_ENABLED')
assert(s.pickups == 0, 'queued target must still be known')

for _, failure in ipairs({ 'empty', 'wrong', 'item', 'error' }) do
    s = setup()
    s.pickupFailure = failure
    s:learn(12)
    assert(s.actions[1][2] == 30 and s.placements == 0, 'failed pickup must never place stale cursor')
    if failure == 'item' then assert(s.cursor[2] == 555 and s.clears == 0, 'unexpected cursor must survive') end
end
for _, failure in ipairs({ true, 'error' }) do
    s = setup()
    s.placeFailure = failure
    s:learn(12)
    assert(s.actions[1][2] == 30 and s.actions[180][2] == 30, 'failed placement must preserve actions')
    assert(not s.cursor, 'failed placement must clean up the owned cursor')
    if failure == 'error' then
        assert(#s.errors == 1 and s.errors[1]:find('placement rejected', 1, true),
            'unexpected placement errors must reach the error handler')
    end
end

s = setup()
s.placeFailure = 'unexpected'
s:learn(12)
assert(s.cursor and s.cursor[4] == 30 and s.clears == 0,
    'unexpected placement must preserve displaced original action on cursor')

s = setup()
s.book[#s.book + 1] = spell(777, false)
s:event('SPELLS_CHANGED')
s:learn(12)
assert(s.pickups == 0, 'ambiguous previous highest names must fail closed')
s = setup()
s.book[2].lowRank = true
s.book[#s.book + 1] = spell(12, false)
s.book[#s.book + 1] = spell(777, false)
s:event('SPELLS_CHANGED')
assert(s.pickups == 0, 'ambiguous current highest names must fail closed')
s = setup()
s.book[#s.book + 1] = spell(30, false)
s:event('SPELLS_CHANGED')
s:learn(12)
assert(s.actions[1][2] == 12, 'duplicate same spell ID is not ambiguous')

s = setup()
s.actions[1] = { 'spell', s.secret }
s:learn(12)
assert(rawequal(s.actions[1][2], s.secret) and s.actions[180][2] == 12, 'secret action IDs must be skipped')
s = setup()
s.book[2].lowRank = true
s.book[#s.book + 1] = spell(12, s.secret)
s:event('SPELLS_CHANGED')
assert(s.pickups == 0, 'secret spellbook rank flags must not become upgrade evidence')
s = setup()
s.cursor = { s.secret }
s:learn(12)
assert(s.pickups == 0 and s.clears == 0, 'secret cursor type must block mutation')
for _, field in ipairs({ 'spellID', 'name', 'isOffSpec', 'isPassive', 'itemType' }) do
    s = setup()
    s.book[2].lowRank = true
    s.book[#s.book + 1] = spell(12, false, nil, { [field] = s.secret })
    s:event('SPELLS_CHANGED')
    assert(s.pickups == 0, 'secret spellbook metadata must not become upgrade evidence: ' .. field)
end
print('OK: actionbars_spell_rank_upgrade_test')
