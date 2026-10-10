local function noop() end
for _, isForever in ipairs({ false, true }) do
    local registered, menu
    local active, unlocked, combat, switchedGroup, switchedSpec, loot = 1, 2, false, nil, nil, 0
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.DUAL_SPEC_PRIMARY, env.DUAL_SPEC_SECONDARY = "Primary", "Secondary"
    env.GetNumSpecGroups = function() return unlocked end
    env.GetNumSpecializations = function() return 3 end
    env.GetLootSpecialization = function() return loot end
    env.SetLootSpecialization = function(value) loot = value end
    env.InCombatLockdown = function() return combat end
    env.C_Timer = { After = function(_, callback) callback() end }
    env.C_SpecializationInfo = {
        GetSpecialization = function() if not isForever then return active end end,
        GetSpecializationInfo = function(index) return 100 + index, "Spec" .. index, nil, 123 end,
        GetActiveSpecGroup = function() assert(isForever); return active end,
        SetActiveSpecGroup = function(index) assert(isForever); switchedGroup = index; active = index end,
        SetSpecialization = function(index) assert(not isForever); switchedSpec = index; active = index end,
    }
    local frame = { events = {}, SetAllPoints = noop }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, callback) self[event] = callback end
    env.CreateFrame = function() return frame end
    env.GameTooltip = { SetOwner = noop, ClearLines = noop, AddLine = noop, AddDoubleLine = noop, Show = noop }
    env.MenuUtil = { CreateContextMenu = function(_, builder)
        menu = { CreateTitle = noop, CreateDivider = noop }
        function menu:CreateRadio(label, selected, callback, value)
            self[#self + 1] = { label = label, selected = selected, callback = callback, value = value }
        end
        builder(nil, menu)
    end }
    local ns = {
        Client = { isForever = isForever },
        Addon = { Datatexts = { Register = function(_, id, definition)
            assert(id == "specswap"); registered = definition
        end } },
        L = setmetatable({}, { __index = function(_, key) return key end }),
    }
    local text = { SetText = function(self, value) self.value = value end,
        SetFormattedText = function(self, fmt, ...) self.value = string.format(fmt, ...) end }
    local slot = { text = text, EnableMouse = noop, RegisterForClicks = noop }
    function slot:SetScript(event, callback) self[event] = callback end
    local chunk = assert(loadfile("modules/infobar/specswap.lua"))
    setfenv(chunk, env); chunk("QUI", ns)
    registered.OnEnable(slot)
    assert(text.value:find(isForever and "Primary" or "Spec1", 1, true))
    slot:OnClick("LeftButton")
    assert(#menu == (isForever and 2 or 3))
    assert(menu[1].selected(1) and not menu[2].selected(2))
    combat = true
    menu[2].callback(2)
    assert(not switchedGroup and not switchedSpec, "switching remains blocked during combat")
    combat = false
    menu[2].callback(2)
    assert((isForever and switchedGroup or switchedSpec) == 2)
    if isForever then
        assert(frame.events.PLAYER_TALENT_UPDATE and frame.events.ACTIVE_PLAYER_SPECIALIZATION_CHANGED)
        frame:OnEvent("PLAYER_TALENT_UPDATE")
        assert(text.value:find("Secondary", 1, true), "native talent updates refresh the active group")
        unlocked = 1
        slot:OnClick("LeftButton")
        assert(#menu == 1 and menu[1].label == "Primary", "locked secondary group is not offered")
        env.ClassTalentsFrameMixin = {}
        env.ClassTalentCurrencyDisplayMixin = {}
        env.CreateAtlasMarkup = function() return "" end
        local native = assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua"))
        setfenv(native, env); native()
        local nativeFrame = { primarySpecTabID = 1, secondarySpecTabID = 2,
            SetDisabledOverlayShown = noop, SetSpecSwitchCastBarActive = noop,
            GetTab = function() return 1 end }
        env.ClassTalentActiveSpecMixin.ActivateSpec({ GetParent = function() return nativeFrame end })
        frame:OnEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
        assert(text.value:find("Primary", 1, true), "native group activation refreshes QUI's display")
        assert(env.ClassTalentsFrameMixin.GetActiveTab(nativeFrame) == active)
    else
        assert(not frame.events.PLAYER_TALENT_UPDATE)
        frame:OnEvent("PLAYER_SPECIALIZATION_CHANGED")
        assert(text.value:find("Spec2", 1, true))
    end
    slot:OnClick("RightButton")
    assert(#menu == 4 and menu[1].value == 0, "both clients retain the documented loot specialization menu")
    menu[3].callback(menu[3].value)
    assert(loot == 102)
    slot:OnEnter()
end
print("OK infobar_forever_specswap_test")
