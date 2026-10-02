-- tests/unit/underlight_angler_test.lua
-- Run: lua tests/unit/underlight_angler_test.lua
--
-- QUI_UnderlightAnglerHelper: the trait-tree data stays self-consistent, the
-- checklist picks the right next step, the client reads degrade to "unknown"
-- instead of erroring, and the folder is registered everywhere a suite addon
-- has to be.

local function readAll(path)
    local f = assert(io.open(path, "rb"), "missing " .. path)
    local d = f:read("*a"); f:close()
    return d:gsub("\r\n", "\n")
end
local function has(body, needle, message)
    assert(body:find(needle, 1, true), message .. "\nmissing: " .. needle)
end

local function loadData()
    local ns = {}
    assert(loadfile("QUI_UnderlightAnglerHelper/angler/data.lua"))("QUI_UnderlightAnglerHelper", ns)
    return ns.UnderlightAngler
end

local function resetClient()
    _G.C_Spell, _G.C_ArtifactUI, _G.C_TradeSkillUI = nil, nil, nil
    _G.C_Item, _G.C_QuestLog, _G.GetAchievementInfo, _G.Enum = nil, nil, nil, nil
end

-- 1) Tree data: twelve traits inside the art, links between known traits, both
--    priority routes are unbroken chains starting at the hub.
do
    resetClient()
    local Angler = loadData()
    local count = 0
    for powerID, trait in pairs(Angler.Traits) do
        count = count + 1
        assert(type(trait.spellID) == "number", "spellID on " .. powerID)
        assert(type(trait.name) == "string" and trait.name ~= "", "name on " .. powerID)
        assert(trait.maxRank == 1 or trait.maxRank == 3, "maxRank on " .. powerID)
        assert(trait.x > 0 and trait.x < 1 and trait.y > 0 and trait.y < 1, "position on " .. powerID)
    end
    assert(count == 12, "twelve traits, got " .. count)
    assert(Angler.Traits[Angler.ROOT_POWER_ID], "root power is a trait")

    local seen = {}
    for _, link in ipairs(Angler.Links) do
        assert(Angler.Traits[link.from] and Angler.Traits[link.to], "link endpoints are traits")
        assert(link.from ~= link.to, "no self links")
        assert(link.route == 0 or link.route == 1 or link.route == 2, "route is 0, 1 or 2")
        local key = link.from .. ">" .. link.to
        assert(not seen[key], "duplicate link " .. key)
        seen[key] = true
    end
    assert(seen["1021>1030"], "the trunk runs from Undercurrent to Bloodfishing")

    local function chainEnd(route, start)
        local at, steps = start, 0
        while true do
            local nextID
            for _, link in ipairs(Angler.Links) do
                if link.route == route and link.from == at then
                    assert(not nextID, "route " .. route .. " forks at " .. at)
                    nextID = link.to
                end
            end
            if not nextID then return at, steps end
            at, steps = nextID, steps + 1
        end
    end
    local last1, steps1 = chainEnd(1, 1021)
    assert(last1 == 1032 and steps1 == 4, "route 1 ends at Underlight Blessing")
    local last2, steps2 = chainEnd(2, 1030)
    assert(last2 == 1033 and steps2 == 3, "route 2 ends at Way of the Flounder")
end

-- 2) NextStep follows the order the game enforces.
do
    resetClient()
    local Angler = loadData()
    local function step(p) return Angler.NextStep(p) end
    assert(step({ achievement = false, skill = 100, pearl = true, rod = true }) == "achievement")
    assert(step({ achievement = true }) == "skillUnknown")
    assert(step({ achievement = true, skill = 99 }) == "skill")
    assert(step({ achievement = true, skill = 100 }) == "pearl")
    assert(step({ achievement = true, skill = 100, pearl = true }) == "khadgar")
    assert(step({ achievement = true, skill = 100, pearl = true, rod = true }) == "ready")
end

-- 3) Client reads: a bare client reports nothing done and nothing known.
do
    resetClient()
    local Angler = loadData()
    local p = Angler.ReadProgress()
    assert(p.achievement == false and p.pearl == false and p.rod == false, "bare client: nothing done")
    assert(p.skill == nil and p.maxSkill == nil, "bare client: skill unknown")
    assert(Angler.IsArtifactOpen() == false, "bare client: artifact closed")
    assert(Angler.TraitName(1021) == "Undercurrent", "falls back to the English trait name")
    assert(Angler.TraitName(9999) == nil, "unknown power has no name")
end

-- 4) Client reads: skill line first, open Fishing page as the fallback; owning
--    the rod implies the pearl chain; the artifact is "open" only with the root.
do
    resetClient()
    local Angler = loadData()
    local askedLine
    _G.Enum = { Profession = { Fishing = 10 } }
    _G.C_TradeSkillUI = {
        GetProfessionInfoBySkillLineID = function(id)
            askedLine = id
            return { skillLevel = 42, maxSkillLevel = 100 }
        end,
        GetChildProfessionInfo = function() error("fallback must not run when the skill line answers") end,
    }
    local skill, maxSkill = Angler.GetLegionFishingSkill()
    assert(askedLine == Angler.LEGION_FISHING_SKILL_LINE and skill == 42 and maxSkill == 100, "skill line read")

    -- An unlearned skill line comes back zeroed: fall through to the open page.
    _G.C_TradeSkillUI.GetProfessionInfoBySkillLineID = function() return { skillLevel = 0, maxSkillLevel = 0 } end
    _G.C_TradeSkillUI.GetChildProfessionInfo = function()
        return { profession = 10, skillLevel = 77, maxSkillLevel = 100 }
    end
    skill, maxSkill = Angler.GetLegionFishingSkill()
    assert(skill == 77 and maxSkill == 100, "open Fishing page fallback")
    _G.C_TradeSkillUI.GetChildProfessionInfo = function()
        return { profession = 3, skillLevel = 77, maxSkillLevel = 100 }
    end
    assert(Angler.GetLegionFishingSkill() == nil, "another profession's page is not Fishing")

    local itemArgs
    _G.C_Item = { GetItemCount = function(...) itemArgs = { ... } return 1 end }
    _G.C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
    _G.GetAchievementInfo = function(id)
        assert(id == Angler.ACHIEVEMENT_ID)
        return id, "Bigger Fish to Fry", 10, true
    end
    local p = Angler.ReadProgress()
    assert(itemArgs[1] == Angler.ROD_ITEM_ID and itemArgs[2] == true, "rod counted including the bank")
    assert(p.rod and p.pearl, "owning the rod implies the pearl chain is done")
    assert(p.achievement and p.achievementName == "Bigger Fish to Fry", "achievement read")

    _G.C_Item.GetItemCount = function() return 0 end
    _G.C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 41010 end
    p = Angler.ReadProgress()
    assert(p.pearl and not p.rod, "any pearl quest counts as pearl progress")

    _G.C_ArtifactUI = { GetPowers = function() return { 5, 6, 7 } end }
    assert(Angler.IsArtifactOpen() == false, "another artifact is open")
    _G.C_ArtifactUI.GetPowers = function() return { 1030, 1021 } end
    assert(Angler.IsArtifactOpen() == true, "the Underlight Angler is open")
    _G.C_ArtifactUI.GetPowers = function() return nil end
    assert(Angler.IsArtifactOpen() == false, "no artifact open")

    _G.C_Spell = { GetSpellName = function(id) return id == 201891 and "Unterströmung" or nil end }
    assert(Angler.TraitName(1021) == "Unterströmung", "client spell name wins")
    assert(Angler.TraitName(1030) == "Bloodfishing", "missing spell name falls back")
    resetClient()
end

-- 5) Wiring: manifest, TOC, media, Module Addons row, lint scope.
do
    local manifest = assert(loadfile("core/addon_manifest.lua"))()
    local entry
    for _, e in ipairs(manifest) do if e.folder == "QUI_UnderlightAnglerHelper" then entry = e end end
    assert(entry and entry.class == "lod", "QUI_UnderlightAnglerHelper is a load-on-demand suite addon")
    assert(entry.legacyFlag == nil and entry.loadPolicy == nil, "toggled by the addon enable state alone")

    local toc = readAll("QUI_UnderlightAnglerHelper/QUI_UnderlightAnglerHelper.toc")
    has(toc, "## LoadOnDemand: 1", "TOC LoD flag")
    has(toc, "## Dependencies: QUI", "TOC dependency")
    has(toc, "## Group: QUI", "TOC group")
    local order = {}
    for _, file in ipairs({ "bootstrap.lua", "angler\\data.lua", "angler\\window.lua", "angler\\angler.lua" }) do
        order[#order + 1] = assert(toc:find("\n" .. file, 1, true), "TOC lists " .. file)
    end
    for i = 2, #order do assert(order[i - 1] < order[i], "TOC load order") end

    -- Both textures are power-of-two uncompressed TGAs.
    for file, size in pairs({ AnglerBackground = { 1024, 512 }, VioletCitadelMap = { 1024, 1024 } }) do
        local f = assert(io.open("QUI_UnderlightAnglerHelper/media/" .. file .. ".tga", "rb"), "missing media " .. file)
        local header = f:read(18); f:close()
        assert(header:byte(3) == 2, file .. " is an uncompressed true-colour TGA")
        assert(header:byte(13) + header:byte(14) * 256 == size[1], file .. " width")
        assert(header:byte(15) + header:byte(16) * 256 == size[2], file .. " height")
    end

    local window = readAll("QUI_UnderlightAnglerHelper/angler/window.lua")
    has(window, '"Interface\\\\AddOns\\\\" .. ADDON_NAME .. "\\\\media\\\\"', "media path follows the folder name")
    has(window, "773 / 1024", "map texcoord crops the padding of the square texture")
    has(window, "self:UnregisterAllEvents()", "the window stops listening when hidden")
    assert(not window:find("_G.QUI_", 1, true), "window exports on ns.*, never _G")
    local main = readAll("QUI_UnderlightAnglerHelper/angler/angler.lua")
    has(main, 'SLASH_QUIANGLER1 = "/quiangler"', "slash command")
    has(main, 'ns.SkinBase.OnAddOnLoaded("Blizzard_ArtifactUI", CreateLauncher)', "artifact window launcher")
    has(main, 'local STANDALONE_ADDON = "UnderlightAnglerUI"', "stands down for the standalone addon")

    local modulesPage = readAll("core/settings/content/module_addons_content.lua")
    has(modulesPage, 'QUI_UnderlightAnglerHelper = ns.L["Underlight Angler Helper"]', "Module Addons label")
    has(readAll("tools/lint.sh"), "QUI_UnderlightAnglerHelper/", "lint scope")

    -- Every string the module shows is reachable by the i18n extractor.
    local enUS = readAll("core/locale/enUS.lua")
    for _, key in ipairs({ "Underlight Angler Helper", "Acquisition checklist", "Artifact Tree",
        "Purchase %s for %s Artifact Power?", "Underlight Angler Tree" }) do
        has(enUS, ("%q"):format(key), "enUS base carries the module's strings")
    end
end

print("underlight_angler_test: ok")
