local contracts = {
    { "QUI_ActionBars/actionbars/actionbars_editmode.lua", 'overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")', 'overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "QUI_ActionBars/actionbars/actionbars_extra_buttons.lua", 'mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")', 'mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "QUI_ActionBars/actionbars/settings/action_bars_buffdebuff_content.lua", 'tabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")', 'tabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "QUI_DamageMeter/damage_meter/damage_meter.lua", 'self.TitleLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'self.TitleLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "QUI_DamageMeter/damage_meter/damage_meter.lua", 'self.TargetsLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'self.TargetsLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "QUI_Debug/aura_probe.lua", 'outputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'outputFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "QUI_Debug/aura_probe.lua", 'copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")', 'copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "QUI_Debug/cdm_debug.lua", '_taintFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")', '_taintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "QUI_GroupFrames/groupframes/raidbuffs.lua", 'mainFrame.labelBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'mainFrame.labelBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "QUI_Options/shared.lua", 'local text = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")', 'local text = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "init.lua", 'panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")', 'panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")' },
    { "modules/dungeon/map_teleports.lua", 'btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "modules/qol/communities_privacy.lua", 'overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")', 'overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")' },
    { "modules/qol/gem_picker.lua", 'panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "modules/qol/mail_contacts.lua", 'panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', 'panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")' },
    { "modules/skinning/character_pane/character.lua", 'popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")', 'popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")' },
    { "core/diagnostics_console.lua", 'popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")', 'popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")' },
    { "QUI_Bags/bags/views/guild_window.lua", 'NORMAL_FONT_COLOR_CODE or "|cffffd200"', 'HIGHLIGHT_FONT_COLOR_CODE or "|cffffffff"' },
    { "modules/qol/xptracker.lua", 'headerRight:SetTextColor(1.0, 0.82, 0.0, 1)', 'headerRight:SetTextColor(1, 1, 1, 1)' },
    { "modules/trackers/preytracker.lua", 'panel.title:SetTextColor(1, 0.82, 0)', 'panel.title:SetTextColor(1, 1, 1)' },
    { "modules/alts/views/roster.lua", 'h._label:SetTextColor(1, 0.82, 0)', 'h._label:SetTextColor(1, 1, 1)' },
    { "modules/alts/views/professions.lua", 'hdrName:SetTextColor(1, 0.82, 0)', 'hdrName:SetTextColor(1, 1, 1)' },
    { "modules/alts/views/professions.lua", 'hdrProf:SetTextColor(1, 0.82, 0)', 'hdrProf:SetTextColor(1, 1, 1)' },
    { "modules/alts/views/filter_popup.lua", 'r._label:SetTextColor(1, 0.82, 0)', 'r._label:SetTextColor(1, 1, 1)' },
    { "modules/alts/views/weeklies.lua", 'header:SetTextColor(1, 0.82, 0)', 'header:SetTextColor(1, 1, 1)' },
    { "modules/alts/views/reputations.lua", 'r._name:SetTextColor(1, 0.82, 0)', 'r._name:SetTextColor(1, 1, 1)' },
}

local cache = {}
for _, contract in ipairs(contracts) do
    local path, old, new = contract[1], contract[2], contract[3]
    if not cache[path] then
        local file = assert(io.open(path, "rb"))
        cache[path] = file:read("*a")
        file:close()
    end
    assert(not cache[path]:find(old, 1, true), path .. " still uses ordinary gold text")
    assert(cache[path]:find(new, 1, true), path .. " must use canonical white text")
end

print("OK: ordinary_text_color_contract_test")
