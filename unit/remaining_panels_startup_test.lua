local Harness = dofile("tests/helpers/character_chrome_harness.lua")

local panels = {
    { "mail", "MailFrame", "skinMail", "Blizzard_MailFrame", "QUI_RefreshMailColors" },
    { "worldmap", "WorldMapFrame", "skinWorldMap", "Blizzard_WorldMap", "QUI_RefreshWorldMapColors" },
    { "professions", "ProfessionsFrame", "skinProfessions", "Blizzard_Professions", "QUI_RefreshProfessionsColors" },
}

local function Build(panel, shown, enabled, combat)
    local env = Harness.Build()
    if combat then
        _G.InCombatLockdown = function() return true end
        assert(loadfile("core/uikit.lua"))("QUI", env.ns)
        env.SkinBase = env.ns.SkinBase
    end
    env.profile.general[panel[3]] = enabled
    local frame = env.NewFrame("Frame", panel[2])
    if panel[1] == "worldmap" then frame.BorderFrame = env.NewFrame("Frame", nil, frame) end
    frame:SetShown(shown)
    _G[panel[2]] = frame
    _G.ProfessionsBookFrame = nil
    local callbacks = {}
    env.SkinBase.OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end
    local count = 0
    local mark = env.SkinBase.MarkSkinned
    env.SkinBase.MarkSkinned = function(target)
        if target == frame then count = count + 1 end
        return mark(target)
    end
    local native = function() end
    _G.InboxFrame_Update = native
    assert(loadfile((os.getenv("QUI_SKIN_SOURCE_DIR") or "modules/skinning/frames") .. "/" .. panel[1] .. ".lua"))("QUI", env.ns)
    return env, frame, callbacks[panel[4]], _G[panel[5]], function() return count end, native
end

for _, panel in ipairs(panels) do
    local env, frame, loaded, refresh, count, native = Build(panel, false, true)
    loaded()
    loaded()
    refresh()
    assert(count() == 0 and not env.SkinBase.IsSkinned(frame), panel[1] .. ": hidden load/refresh must defer")
    assert(#frame.hooks.OnShow == 1, panel[1] .. ": hidden load/refresh must share one show hook")
    if panel[1] == "mail" then
        assert(_G.InboxFrame_Update == native, "hidden mail must defer content update hooks")
    elseif panel[1] == "professions" then
        assert(not env.SkinBase.GetFrameData(frame, "qProfessionSetTitle"),
            "hidden professions refresh must not install title hooks")
    end
    frame:Show()
    assert(count() == 1, panel[1] .. ": first opening must initialize")
    local hooks = #frame.hooks.OnShow
    frame:Hide()
    frame:Show()
    loaded()
    refresh()
    assert(count() == 1 and #frame.hooks.OnShow == hooks, panel[1] .. ": reopening must reuse initialization")

    env, frame, loaded, refresh, count = Build(panel, true, true)
    loaded()
    assert(count() == 1, panel[1] .. ": already-visible load must initialize")

    env, frame, loaded, refresh, count = Build(panel, false, false)
    loaded()
    refresh()
    frame:Show()
    assert(count() == 0 and not frame.hooks.OnShow, panel[1] .. ": disabled skin must leave native loading untouched")

    env, frame, loaded, refresh, count = Build(panel, false, true)
    loaded()
    env.profile.general[panel[3]] = false
    frame:Show()
    assert(count() == 0, panel[1] .. ": disabled pending skin must not initialize")
    env.profile.general[panel[3]] = true
    refresh()
    assert(count() == 1, panel[1] .. ": enabling via refresh must initialize a visible panel")

    for _, shown in ipairs({ false, true }) do
        env, frame, loaded, refresh, count = Build(panel, shown, true, true)
        frame.IsProtected = function() return true end
        for _, method in ipairs({ "SetSize", "SetWidth", "SetHeight", "ClearAllPoints", "SetPoint", "SetAllPoints",
            "SetParent", "SetAttribute" }) do
            frame[method] = function() error(panel[1] .. " skin must leave its protected root geometry unchanged") end
        end
        loaded()
        if not shown then
            assert(count() == 0, panel[1] .. ": hidden skin must still defer during combat")
            frame:Show()
        end
        assert(count() == 1 and env.SkinBase.GetBackdrop(frame.BorderFrame or frame),
            panel[1] .. ": must apply its shell on first open or reload during combat")
        refresh()
        assert(count() == 1, panel[1] .. ": combat refresh must not repeat initialization")
    end
end

print("OK: remaining_panels_startup_test")
