local function noop() end
local function falseValue() return false end

for _, client in ipairs({ { false, false }, { false, true }, { true, true } }) do
    local isForever, separateSpells = client[1], client[2]
    local combat, registered = false, nil
    local buttons, calls, nativeCalls = {}, {}, {}
    local openedTab
    local world = setmetatable({}, { __index = _G })
    world._G = world
    world.InCombatLockdown = function() return combat end
    world.SecureCmdOptionParse = function(condition)
        assert(condition == "[combat] true")
        return combat and "true" or nil
    end
    world.GetCVarBool = function(name) return name == "ActionButtonUseKeyDown" end
    world.IsShiftKeyDown, world.IsControlKeyDown, world.IsAltKeyDown = falseValue, falseValue, falseValue
    world.SpellCanTargetItem, world.SpellCanTargetItemID = falseValue, falseValue
    world.C_PaperDollInfo = { GetInventorySlotInfo = function(slot) return slot end, IsRangedSlotShown = falseValue }
    world.CopyTable = function(source)
        local copy = {}
        for key, value in pairs(source) do copy[key] = value end
        return copy
    end
    local methods = {}
    function methods:GetParent() return self.parent end
    function methods:GetAttribute(prefix, name, suffix)
        if not name then return self.attributes[prefix] end
        for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix,
            prefix .. name .. "*", "*" .. name .. "*", name }) do
            if self.attributes[key] ~= nil then return self.attributes[key] end
        end
    end
    function methods:SetAttribute(key, value) self.attributes[key] = value end
    function methods:SetScript(key, value) self.scripts[key] = value end
    function methods:GetScript(key) return self.scripts[key] end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height or 24 end
    function methods:RegisterForClicks(event) self.clickEvent = event end
    methods.SetAllPoints, methods.SetPoint = noop, noop
    methods.SetNormalAtlas, methods.SetPushedAtlas, methods.SetHighlightAtlas = noop, noop, noop
    methods.SetHighlightTexture = noop
    function methods:CreateTexture()
        return { SetAllPoints = noop, SetTexture = noop, SetVertexColor = noop }
    end
    function methods:Click(button)
        assert(self.clickEvent == "AnyUp", "micromenu keeps release-only clicks")
        if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton", false) end
        if self.scripts.PostClick then self.scripts.PostClick(self, button or "LeftButton", false) end
    end
    world.GetFrameMetatable = function() return { __index = methods } end
    world.Enum = { ForbiddenAspect = { ScriptedInput = 1 }, GameRule = {} }
    local nativePath = isForever and "tests/clients/forever/framexml/" or "tests/framexml/"
    local secureTemplates = assert(loadfile(nativePath .. "Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua"))
    setfenv(secureTemplates, world)()
    world.CreateFrame = function(_, _, parent, template)
        local frame = setmetatable({ parent = parent, attributes = {}, scripts = {}, template = template }, { __index = methods })
        if template == "SecureActionButtonTemplate" then
            frame.scripts.OnClick = world.SecureActionButton_OnClick
        end
        return frame
    end
    world.SecureHandlerWrapScript = function(frame, script, owner, body)
        assert(script == "OnClick" and owner == frame)
        local wrapped = assert(frame:GetScript(script))
        local pre = assert(loadstring("return function(self, button, down) " .. body .. " end"))
        setfenv(pre, world)
        pre = pre()
        frame:SetScript(script, function(self, button, down)
            if pre(self, button, down) ~= false then wrapped(self, button, down) end
        end)
    end
    world.SetPortraitTexture = noop
    world.C_GameRules = { IsGameRuleActive = falseValue }
    world.GameRulesUtil = { EJIsDisabled = falseValue }
    local function callback(key)
        return function()
            assert(not combat, "insecure panel callback must never run in combat: " .. key)
            calls[key] = (calls[key] or 0) + 1
        end
    end
    world.ToggleCharacter = callback("Character")
    world.PlayerSpellsUtil = {
        ToggleSpellBookFrame = callback("Spellbook"),
        ToggleClassTalentOrSpecFrame = callback("Talents"),
        FrameTabs = { SpellBook = "spellbook", ClassTalents = "talents" },
        TogglePlayerSpellsFrame = function(tab) openedTab = tab end,
    }
    world.KeybindFrames_InQuickKeybindMode = falseValue
    world.PlayerSpellsMicroButtonMixin = {}
    local nativeFile = assert(io.open(nativePath .. "Interface/AddOns/Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua"))
    local nativeSource = nativeFile:read("*a"); nativeFile:close()
    local start = assert(nativeSource:find("function PlayerSpellsMicroButtonMixin:OnClick(button, down)", 1, true))
    local stop = assert(nativeSource:find("function PlayerSpellsMicroButtonMixin:UpdateMicroButton()", start, true))
    local nativeClick = assert(loadstring(nativeSource:sub(start, stop - 1)))
    setfenv(nativeClick, world)()
    world.ToggleProfessionsBook = callback("Professions")
    world.ToggleAchievementFrame = callback("Achievements")
    world.ToggleLegacySystemUI = callback("Legacy")
    world.ToggleQuestLog = callback("Quest Log")
    world.ToggleCollectionsJournal = callback("Collections")
    world.ToggleGroupFinderFrame = callback("Group Finder")
    world.PVEFrame_ToggleFrame = callback("Group Finder")
    world.ToggleEncounterJournal = callback("Adventure Guide")
    world.HousingFramesUtil = { ToggleHousingDashboard = callback("Housing") }
    world.ToggleHelpFrame = callback("Support")
    world.securecall = noop
    world.StoreFrame = {
        GetAttribute = falseValue,
        SetAttribute = function(_, key) if key == "action" then callback("Shop")() end end,
    }
    local targets = {
        Character = "CharacterMicroButton",
        Spellbook = separateSpells and "SpellbookMicroButton" or "PlayerSpellsMicroButton",
        Talents = separateSpells and "TalentMicroButton" or "PlayerSpellsMicroButton",
        Professions = "ProfessionMicroButton",
        [isForever and "Legacy" or "Achievements"] = isForever and "LegacyMicroButton" or "AchievementMicroButton",
        ["Quest Log"] = "QuestLogMicroButton",
        Collections = "CollectionsMicroButton",
        ["Group Finder"] = "LFDMicroButton",
        ["Adventure Guide"] = "EJMicroButton",
        Housing = "HousingMicroButton",
        Shop = "StoreMicroButton",
        Support = "HelpMicroButton",
    }
    local targetNames = { "PlayerSpellsMicroButton" }
    for _, target in pairs(targets) do targetNames[#targetNames + 1] = target end
    for _, target in ipairs(targetNames) do
        local name = target
        world[name] = {
            spellbookOnly = name == "SpellbookMicroButton",
            talentsOnly = name == "TalentMicroButton",
            suggestedTab = "remembered",
            HasAccessConstraints = falseValue,
            HasAnyForbiddenAspects = falseValue,
            Click = function(self, button)
                assert(button == "LeftButton", "native forwarding preserves the mouse button")
                nativeCalls[name] = (nativeCalls[name] or 0) + 1
                if name == "SpellbookMicroButton" or name == "TalentMicroButton" or name == "PlayerSpellsMicroButton" then
                    world.PlayerSpellsMicroButtonMixin.OnClick(self, button, false)
                end
            end,
        }
    end
    local ns = {
        Helpers = { CHROME = {}, GetCore = noop, CreateStateTable = function() return {} end },
        Client = { isForever = isForever },
        L = setmetatable({}, { __index = function(_, key) return key end }),
        Addon = {
            db = { profile = { infobar = { micromenu = { buttons = {} } } } },
            Datatexts = { Register = function(_, _, definition) registered = definition end },
        },
    }
    local uikit = assert(loadfile("core/uikit.lua"))
    setfenv(uikit, world)("QUI", ns)
    local createIconButton = ns.UIKit.CreateIconButton
    local plainCalls = 0
    local plain = createIconButton(nil, {
        registerClicks = "AnyUp",
        onClick = function() plainCalls = plainCalls + 1 end,
    })
    assert(not plain.template and plain:GetScript("OnClick") and not plain:GetScript("PostClick"),
        "ordinary UIKit callers retain their plain button and click script")
    plain:Click()
    combat = true
    plain:Click()
    assert(plainCalls == 2, "unguarded plain UIKit callers keep their existing combat behavior")
    combat = false
    ns.UIKit.CreateIconButton = function(parent, opts)
        local button = createIconButton(parent, opts)
        buttons[opts.tooltip] = button
        return button
    end
    local micromenu = assert(loadfile("modules/infobar/micromenu.lua"))
    setfenv(micromenu, world)("QUI", ns)
    registered.OnEnable(world.CreateFrame("Frame"))
    for label, target in pairs(targets) do
        local button = assert(buttons[label], label)
        local alwaysNative = label == "Spellbook" or label == "Talents"
        local expectedTab = separateSpells and (label == "Spellbook" and "spellbook" or "talents") or "remembered"
        button:Click()
        if alwaysNative then
            assert(openedTab == expectedTab, label .. " must use its dedicated native tab when available")
            assert(nativeCalls[target] == 1 and not calls[label],
                label .. " must open through native secure dispatch even outside combat to avoid secret cooldown taint")
        else
            assert(calls[label] == 1 and not nativeCalls[target], label .. " runs its original callback exactly once out of combat")
        end
        combat = true
        local before = nativeCalls[target] or 0
        button:Click()
        assert(nativeCalls[target] == before + 1, label .. " must forward one native click during combat")
        if alwaysNative then assert(openedTab == expectedTab, label .. " must retain its native tab in combat") end
        assert(calls[label] == (not alwaysNative and 1 or nil), label .. " must not run its insecure callback in combat")
        assert(button:GetAttribute("useOnKeyDown") == false, "release works with ActionButtonUseKeyDown enabled")
        combat = false
        button:Click()
        if alwaysNative then
            assert(nativeCalls[target] == before + 2 and not calls[label],
                label .. " must stay on native dispatch after combat ends")
            assert(openedTab == expectedTab, label .. " must retain its native tab after combat")
            world[target].HasAccessConstraints = function() return true end
            button:Click()
            assert(nativeCalls[target] == before + 2 and not calls[label],
                label .. " must not fall back to an insecure callback when native access is blocked")
            world[target].HasAccessConstraints = falseValue
            world[target].HasAnyForbiddenAspects = function() return true end
            button:Click()
            assert(nativeCalls[target] == before + 2 and not calls[label],
                label .. " must respect forbidden scripted input outside combat")
            world[target].HasAnyForbiddenAspects = falseValue
        else
            assert(calls[label] == 2 and nativeCalls[target] == before + 1, label .. " resumes its original callback after combat")
        end
        nativeCalls[target] = nil
    end
    combat = true
    world.CharacterMicroButton.HasAccessConstraints = function() return true end
    buttons.Character:Click()
    assert(not nativeCalls.CharacterMicroButton and calls.Character == 2,
        "native dispatcher honors access constraints without falling back to insecure calls")
    world.CharacterMicroButton.HasAccessConstraints = falseValue
    world.CharacterMicroButton.HasAnyForbiddenAspects = function() return true end
    buttons.Character:Click()
    assert(not nativeCalls.CharacterMicroButton and calls.Character == 2,
        "native dispatcher honors forbidden scripted input")
    combat = false
    world.CharacterMicroButton = nil
    registered.OnEnable(world.CreateFrame("Frame"))
    local fallback = buttons.Character
    local before = calls.Character
    fallback:Click()
    assert(calls.Character == before + 1, "missing native target keeps the original callback")
    combat = true
    fallback:Click()
    assert(calls.Character == before + 1, "missing native target remains guarded in combat")
    combat = false
    world[targets.Spellbook], world[targets.Talents] = nil, nil
    registered.OnEnable(world.CreateFrame("Frame"))
    for _, label in ipairs({ "Spellbook", "Talents" }) do
        buttons[label]:Click()
        combat = true
        buttons[label]:Click()
        combat = false
        assert(not calls[label], label .. " must never use the tainting callback when its native target is absent")
    end
end

print("OK infobar_micromenu_combat_click_test")
