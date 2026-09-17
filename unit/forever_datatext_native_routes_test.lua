local sourceFile = assert(io.open('modules/datatexts/datatexts.lua'))
local source = sourceFile:read('*a')
sourceFile:close()

local function frame()
    local f = { scripts = {}, events = {}, text = {} }
    function f:SetAllPoints() end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:EnableMouse() end
    function f:RegisterForClicks() end
    function f.text:SetText(value) self.value = value end
    function f.text:SetFormattedText(pattern, ...) self.value = string.format(pattern, ...) end
    return f
end

local function loadNativeFunction(path, name, env)
    local file = assert(io.open(path))
    local native = file:read('*a')
    file:close()
    local first = assert(native:find('function ' .. name .. '(', 1, true))
    local last = assert(native:find('\nend', first, true)) + 3
    local chunk = assert(loadstring(native:sub(first, last), '@' .. path))
    setfenv(chunk, env)
    chunk()
end

local function harness(forever, provider)
    local state = { activeGroup = 1, groups = 2, menu = {}, tab = 'SpellBook' }
    local env = setmetatable({ ns = { Client = { isForever = forever }, L = setmetatable({}, { __index = function(_, key) return key end }) } }, { __index = _G })
    env._G = env
    env.format = string.format
    env.CreateFrame = frame
    env.GetSpecialization = function() return 1 end
    env.GetSpecializationInfo = function(index) return index + 100, 'Spec' .. index, nil, 123 end
    env.GetNumSpecializations = function() return 2 end
    env.GetLootSpecialization = function() return 0 end
    env.GetValueColor = function() return 255, 255, 255 end
    env.GetLabel = function(label) return label end
    env.InCombatLockdown = function() return state.combat end
    env.IsShiftKeyDown = function() return state.shift end
    env.IsControlKeyDown = function() return state.control end
    env.DUAL_SPEC_PRIMARY, env.DUAL_SPEC_SECONDARY = 'Primary', 'Secondary'
    env.GetNumSpecGroups = function() return state.groups end
    env.C_SpecializationInfo = {
        GetActiveSpecGroup = function() return state.activeGroup end,
        SetActiveSpecGroup = function(group) state.switchedGroup = group end,
        SetSpecialization = function(spec) state.switchedSpec = spec end,
    }
    env.PlayerUtil = { CanUseClassTalents = function() return true end }
    env.C_ClassTalents = {
        GetHasStarterBuild = function() assert(not forever, 'Forever queried Retail starter builds'); return false end,
        GetLastSelectedSavedConfigID = function() assert(not forever); return 99 end,
        GetConfigIDsBySpecID = function() assert(not forever); return { 99 } end,
    }
    env.C_Traits = { GetConfigInfo = function() return { name = 'Retail loadout' } end }
    env.C_MythicPlus = { GetOwnedKeystoneLevel = function() return nil end, GetOwnedKeystoneChallengeMapID = function() return nil end }
    env.C_Timer = { After = function(_, fn) fn() end }
    env.PlayerSpellsUtil = {
        FrameTabs = { ClassTalents = 'ClassTalents', ClassSpecializations = 'ClassSpecializations' },
        TogglePlayerSpellsFrame = function(tab) state.tab = tab; return true end,
    }
    loadNativeFunction('tests/clients/forever/framexml/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/PlayerSpellsUtil.lua', 'PlayerSpellsUtil.ToggleClassTalentOrSpecFrame', env)
    env.TogglePlayerSpellsFrame = function() state.genericToggle = true end
    env.Enum = { PremadeGroupFinderStyle = { Disabled = 0, Vanilla = 1 } }
    env.C_LFGList = { GetPremadeGroupFinderStyle = function() return forever and 1 or 2 end }
    env.C_AddOns = { IsAddOnLoaded = function(addon) return addon == 'Blizzard_GroupFinder_VanillaStyle' end }
    env.LFGVanilla_ToggleFrame = function() state.vanillaGroupFinder = true end
    if not forever then env.PVEFrame_ToggleFrame = function(panel, selection) state.groupFinder = { panel, selection } end end
    loadNativeFunction('tests/clients/forever/framexml/Interface/AddOns/Blizzard_Game/Shared/Game.lua', 'ToggleGroupFinderFrame', env)
    env.LFDParentFrame = {}
    env.GameTooltip = { lines = {} }
    for _, method in ipairs({ 'SetOwner', 'ClearLines', 'Show', 'Hide' }) do env.GameTooltip[method] = function() end end
    function env.GameTooltip:AddLine(line) table.insert(self.lines, line) end
    env.MenuUtil = { CreateContextMenu = function(_, build)
        state.menu = {}
        build(nil, {
            CreateTitle = function(_, title) state.title = title end,
            CreateButton = function(_, label, action) table.insert(state.menu, { label = label, action = action }) end,
            CreateDivider = function() end,
        })
    end }
    env.Datatexts = { EnsureText = function(slot) return slot.text end, Register = function(_, _, def) state.provider = def end }
    local start = assert(source:find('Datatexts:Register("' .. provider .. '"', 1, true))
    local finish = assert(source:find('\n})', start, true)) + 3
    local chunk = assert(loadstring(source:sub(start, finish), '@datatexts:' .. provider))
    setfenv(chunk, env)
    chunk()
    local slot = frame()
    state.instance = state.provider.OnEnable(slot, {})
    state.slot = slot
    function state:click(button) slot.scripts.OnClick(slot, button or 'LeftButton') end
    return state, env
end

for _, forever in ipairs({ true, false }) do
    local key, env = harness(forever, 'mythickey')
    key:click()
    if forever then
        assert(key.vanillaGroupFinder and not key.groupFinder)
    else
        assert(key.groupFinder[1] == 'GroupFinderFrame' and key.groupFinder[2] == env.LFDParentFrame)
    end
    key.groupFinder, key.vanillaGroupFinder = nil, nil
    key:click('RightButton')
    assert(not key.groupFinder and not key.vanillaGroupFinder)
    key.combat = true
    key:click()
    assert(not key.groupFinder and not key.vanillaGroupFinder)
    for _, name in ipairs({ 'lootspec', 'playerspec' }) do
        local spec = harness(forever, name)
        spec.shift = true
        spec:click()
        assert(spec.tab == 'ClassTalents' and not spec.genericToggle)
        spec.tab, spec.combat = 'SpellBook', true
        spec:click()
        assert(spec.tab == 'SpellBook')
    end
end

local spec = harness(true, 'playerspec')
assert(spec.slot.text.value:find('Primary', 1, true))
spec:click()
assert(#spec.menu == 2 and spec.menu[2].label:find('Secondary', 1, true))
spec.menu[2].action()
assert(spec.switchedGroup == 2 and not spec.switchedSpec)
spec.switchedGroup = nil
spec.combat = true
spec.menu[2].action()
assert(not spec.switchedGroup)
spec.combat, spec.activeGroup = false, 2
assert(spec.instance.events.ACTIVE_PLAYER_SPECIALIZATION_CHANGED)
spec.instance.scripts.OnEvent(spec.instance, 'ACTIVE_PLAYER_SPECIALIZATION_CHANGED')
assert(spec.slot.text.value:find('Secondary', 1, true))
spec.control = true
spec:click()
assert(#spec.menu == 2)
spec.groups = 1
spec:click()
assert(#spec.menu == 1)
spec.slot.scripts.OnEnter(spec.slot)

local retail = harness(false, 'playerspec')
assert(retail.slot.text.value:find('Retail loadout', 1, true))
retail:click()
assert(#retail.menu == 2)
retail.menu[2].action()
assert(retail.switchedSpec == 2 and not retail.switchedGroup)
retail.control = true
retail:click()
assert(#retail.menu == 1 and retail.menu[1].label:find('Retail loadout', 1, true))
print('PASS: Forever and Retail datatext native routes, dual spec groups, combat gating, and Retail menus')
