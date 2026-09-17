local function noop() end
for _, isForever in ipairs({ false, true }) do
    local registered, buttons, calls = nil, {}, {}
    local legacyEnabled = true
    local disabledRules, ejDisabled = {}, false
    local world = setmetatable({}, { __index = _G })
    world._G = world
    world.CreateFrame = function() return { SetAllPoints = noop } end
    world.PlayerSpellsUtil = {
        ToggleSpellBookFrame = function() calls.spellbook = true end,
        ToggleClassTalentOrSpecFrame = function() calls.talents = true end,
    }
    world.Enum = { GameRule = setmetatable({}, { __index = function(_, key) return key end }) }
    world.C_GameRules = { IsGameRuleActive = function(rule) return disabledRules[rule] end }
    world.GameRulesUtil = { EJIsDisabled = function() return ejDisabled end }
    if isForever then
        world.ToggleGroupFinderFrame = function() calls.lfg = true end
        world.PVEFrame_ToggleFrame = function() error("must use native group-finder dispatcher") end
    else
        world.PVEFrame_ToggleFrame = function(...) assert(select("#", ...) == 0); calls.lfg = true end
    end
    world.ToggleAchievementFrame = function() calls.achievements = true end
    world.LegacyMicroButton = { IsEnabled = function() return legacyEnabled end }
    world.LoadAddOnWithErrorHandling = function(name)
        assert(name == "Blizzard_LegacySystem")
        calls.loadedLegacy = true
        world.LegacySystemFrame = {}
        return true
    end
    world.ToggleFrame = function(frame)
        assert(frame == world.LegacySystemFrame)
        calls.legacy = (calls.legacy or 0) + 1
    end
    local bootstrap = assert(loadfile("tests/clients/forever/framexml/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacySystem_Bootstrap.lua"))
    setfenv(bootstrap, world); bootstrap("Blizzard_LegacySystem")
    local ns = {
        Client = { isForever = isForever },
        Addon = {
            db = { profile = { infobar = { micromenu = { buttons = {} } } } },
            Datatexts = { Register = function(_, id, definition) assert(id == "micromenu"); registered = definition end },
        },
        L = setmetatable({}, { __index = function(_, key) return key end }),
        UIKit = { CreateIconButton = function(_, opts)
            buttons[opts.tooltip] = opts
            return { SetSize = noop, SetPoint = noop, GetWidth = function() return opts.size end }
        end },
    }
    local chunk = assert(loadfile("modules/infobar/micromenu.lua"))
    setfenv(chunk, world); chunk("QUI", ns)
    local slot = { GetHeight = function() return 24 end }
    registered.OnEnable(slot)
    assert(buttons.Character and buttons.Spellbook and buttons.Talents)
    buttons.Spellbook.onClick()
    buttons.Talents.onClick()
    buttons["Group Finder"].onClick()
    assert(calls.lfg, "group finder uses the client-aware native dispatcher")
    assert(calls.spellbook and calls.talents, "both clients retain modern spellbook and talent routes")
    if isForever then
        assert(buttons.Legacy and not buttons.Achievements, "Forever exposes Legacy in place of the Retail achievement entry")
        assert(buttons.Legacy.atlasTriplet == "UI-HUD-MicroMenu-Legacy" and buttons.Legacy.combatGuard)
        legacyEnabled = false
        buttons.Legacy.onClick()
        assert(not calls.loadedLegacy, "locked Legacy system must remain unavailable")
        legacyEnabled = true
        buttons.Legacy.onClick()
        assert(calls.loadedLegacy and calls.legacy == 1, "Legacy click uses Blizzard's load-on-demand bootstrap")
        buttons.Legacy.onClick()
        assert(calls.legacy == 2, "loaded Legacy frame remains toggleable")
        disabledRules.HousingDashboardDisabled = true
        disabledRules.FinderPanelDisabled = true
        ejDisabled = true
        buttons = {}
        registered.OnEnable(slot)
        assert(not buttons.Housing and not buttons["Adventure Guide"] and not buttons["Group Finder"],
            "Forever honors Blizzard's panel game rules")
        assert(buttons.Legacy and buttons.Character)
        ns.Addon.db.profile.infobar.micromenu.buttons.legacy = false
        buttons = {}
        registered.OnEnable(slot)
        assert(not buttons.Legacy, "Forever Legacy preference is respected")
    else
        assert(buttons.Achievements and not buttons.Legacy, "Retail retains Achievements without a Forever-only entry")
        buttons.Achievements.onClick()
        assert(calls.achievements and not calls.legacy)
    end
end
print("OK infobar_forever_micromenu_test")
