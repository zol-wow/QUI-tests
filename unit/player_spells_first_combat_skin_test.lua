local function Read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local native = Read("tests/clients/forever/framexml/Interface/AddOns/Blizzard_UIPanelTemplates/Shared/UIPanelSpellButtonFrame.xml")
assert(native:find('parentKey="Button" inherits="SecureFrameTemplate"', 1, true),
    "assistant spell button must retain the native secure-frame contract")

for _, alreadyLoaded in ipairs({ true, false }) do
    local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
    local combat = true
    _G.InCombatLockdown = function() return combat end
    assert(loadfile(os.getenv("QUI_SKIN_UIKIT_SOURCE") or "core/uikit.lua"))("QUI", env.ns)
    local skin = env.ns.SkinBase
    env.profile.general.skinSpellBook = true
    _G.C_AddOns = { IsAddOnLoaded = function(name)
        return name == "Blizzard_PlayerSpells" and alreadyLoaded
    end }
    local frame = env.NewFrame("Frame", "PlayerSpellsFrame")
    _G.PlayerSpellsFrame = frame
    frame.NineSlice = env.NewFrame("Frame", nil, frame)
    frame.NineSlice.Art = frame.NineSlice:CreateTexture()
    frame.CloseButton = env.NewFrame("Button", nil, frame)
    frame.TabSystem = env.NewFrame("Frame", nil, frame)
    local tab = env.NewFrame("Button", nil, frame.TabSystem)
    tab.Text = tab:CreateFontString()
    tab.Text:SetText("Spellbook")
    frame.TabSystem.tabs = { tab }
    frame.SpellBookFrame = env.NewFrame("Frame", nil, frame)
    local book = frame.SpellBookFrame
    book.BookBGLeft = book:CreateTexture()
    book.SearchBox = env.NewFrame("EditBox", nil, book)
    book.AssistedCombatRotationSpellFrame = env.NewFrame("Frame", nil, book)
    local rotation = book.AssistedCombatRotationSpellFrame
    rotation.Button = env.NewFrame("Button", nil, rotation)
    rotation.Button:SetSize(32, 32)
    rotation.Button.Icon = rotation.Button:CreateTexture()
    rotation.Button.Icon:SetTexture("native-assistant-icon")
    rotation.Button.Border = rotation.Button:CreateTexture()
    rotation.Label = rotation:CreateFontString()
    rotation.Label:SetText("Single-Button|nAssistant")
    rotation.Label.GetUnboundedStringWidth = function() return 160 end
    local nativeClick = function() end
    rotation.Button:SetScript("OnClick", nativeClick)
    book.PagedSpellsFrame = env.NewFrame("Frame", nil, book)
    local paged = book.PagedSpellsFrame
    local row = env.NewFrame("Frame", nil, paged)
    row.Backplate = row:CreateTexture()
    row.Name = row:CreateFontString()
    row.Name:SetText("Native spell")
    row.Button = env.NewFrame("Button", nil, row)
    row.Button.Icon = row.Button:CreateTexture()
    row.Button.Icon:SetTexture("native-spell-icon")
    row.Button.Border = row.Button:CreateTexture()
    row.Button:SetScript("OnClick", nativeClick)
    paged.EnumerateFrames = function()
        local pending = row
        return function()
            local result = pending
            pending = nil
            if result then return 1, result end
        end
    end
    for _, widget in ipairs(env.frames) do widget.RegisterForWidgetSet = false end
    local geometryWrites = 0
    for _, protected in ipairs({ frame, book, rotation, rotation.Button, paged, row, row.Button }) do
        protected.IsProtected = function() return true end
        for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetParent",
            "SetSize", "SetWidth", "SetHeight", "SetScale", "Show", "Hide", "SetShown" }) do
            local original = protected[method]
            protected[method] = function(self, ...)
                assert(not combat, "restricted native frame mutation during combat: " .. method)
                geometryWrites = geometryWrites + 1
                return original(self, ...)
            end
        end
    end
    local initialWidth = rotation:GetWidth()
    assert(loadfile(os.getenv("QUI_JOURNALS_SOURCE") or "modules/skinning/frames/journals.lua"))("QUI", env.ns)
    if not alreadyLoaded then
        assert(not skin.IsSkinned(frame), "unloaded spellbook must wait for ADDON_LOADED")
        for _, watcher in ipairs(env.frames) do
            local handler = watcher:GetScript("OnEvent")
            if handler then handler(watcher, "ADDON_LOADED", "Blizzard_PlayerSpells") end
        end
    end
    env.RunTimers()
    assert(skin.IsSkinned(frame), "first combat load must complete spellbook skin initialization")
    assert(skin.GetBackdrop(frame), "window chrome must exist before combat ends")
    assert(skin.GetBackdrop(tab), "tab chrome must exist before combat ends")
    assert(book.BookBGLeft:GetAlpha() == 0 and row.Backplate:GetAlpha() == 0,
        "native book and spell-row artwork must be suppressed immediately")
    assert(rotation.Button.Border:GetAlpha() == 0 and row.Button.Border:GetAlpha() == 0,
        "secure spell-button artwork must be skinned immediately")
    assert(rotation.Label:GetText() == "Single-Button Assistant" and row.Name.font == "QUIFont.ttf",
        "assistant and spell-row fonts must be styled immediately")
    assert(rotation.Button.Icon.texture == "native-assistant-icon" and row.Button.Icon.texture == "native-spell-icon",
        "combat initialization must retain native spell icons")
    assert(rotation.Button:GetScript("OnClick") == nativeClick and row.Button:GetScript("OnClick") == nativeClick,
        "combat initialization must preserve native spell actions")
    assert(rotation:GetWidth() == initialWidth and geometryWrites == 0,
        "combat initialization must defer protected geometry only")
    combat = false
    for _, watcher in ipairs(env.frames) do
        local handler = watcher:GetScript("OnEvent")
        if handler then handler(watcher, "PLAYER_REGEN_ENABLED") end
    end
    assert(rotation:GetWidth() == rotation.Label:GetWidth() + rotation.Button:GetWidth() + 21,
        "protected assistant geometry must catch up after combat")
end

print("OK: player_spells_first_combat_skin_test")
