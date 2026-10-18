local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local combat = false
_G.InCombatLockdown = function() return combat end
assert(loadfile("core/uikit.lua"))("QUI", env.ns)
local skin = env.ns.SkinBase
local callbacks, refreshes, frames, initializations = {}, {}, {}, {}
local names = {
    BankFrame = "skinBank", MerchantFrame = "skinMerchant", GossipFrame = "skinGossip",
    QuestFrame = "skinQuest", GearManagerPopupFrame = "skinCharacterFrame",
}
local originalSkinWindow = skin.SkinWindow
skin.SkinWindow = function(frame, ...)
    initializations[frame] = (initializations[frame] or 0) + 1
    return originalSkinWindow(frame, ...)
end
skin.OnAddOnLoaded = function(name, callback) callbacks[name] = callback end
env.ns.Registry = { Register = function(_, name, entry) refreshes[name] = entry.refresh end }
for name, setting in pairs(names) do
    env.profile.general[setting] = true
    local frame = env.NewFrame("Frame")
    frame.TabSystem, frame.BankPanel, frame.BankItemSearchBox = false, false, false
    frame:Hide()
    frames[name], _G[name] = frame, frame
end
local nativeShows = 0
frames.BankFrame:SetScript("OnShow", function(frame)
    nativeShows = nativeShows + 1
    if not frame.BankItemSearchBox then frame.BankItemSearchBox = env.NewFrame("EditBox", nil, frame) end
end)
assert(loadfile(os.getenv("QUI_INTERACTION_SOURCE") or "modules/skinning/frames/interaction.lua"))("QUI", env.ns)
callbacks.Blizzard_UIPanels_Game()
callbacks.Blizzard_UIPanels_Game()
for name, frame in pairs(frames) do
    assert(not skin.IsSkinned(frame) and not skin.GetBackdrop(frame), name .. " must not initialize while hidden")
    if refreshes[names[name]] then refreshes[names[name]]() end
    assert(not skin.IsSkinned(frame) and not skin.GetBackdrop(frame), name .. " refresh must preserve hidden initialization")
    assert(#frame.hooks.OnShow == 1, name .. " repeated loading and refresh must coalesce")
end
env.profile.general.skinMerchant = false
frames.MerchantFrame:Show()
assert(not skin.IsSkinned(frames.MerchantFrame), "first show must respect a setting disabled after loading")
env.profile.general.skinMerchant = true
refreshes.skinMerchant()
assert(skin.IsSkinned(frames.MerchantFrame), "refresh must initialize a visible newly enabled panel")
for _, frame in pairs(frames) do
    frame:Show()
    assert(skin.IsSkinned(frame) and skin.GetBackdrop(frame), "first opening must initialize window chrome")
    assert(initializations[frame] == 1, "one initial skin per frame")
    frame:Hide()
    frame:Show()
    assert(initializations[frame] == 1, "reopening must retain existing contents hooks without reinstalling the skin")
end
assert(nativeShows == 2 and skin.GetBackdrop(frames.BankFrame.BankItemSearchBox),
    "native OnShow must remain intact and its newly created controls must be styled")
local originalMerchant = frames.MerchantFrame
local visible = env.NewFrame("Frame")
_G.MerchantFrame = visible
callbacks.Blizzard_UIPanels_Game()
assert(skin.IsSkinned(visible) and initializations[visible] == 1, "already visible load must initialize immediately")
_G.MerchantFrame = originalMerchant

combat = true
for _, forever in ipairs({ false, true }) do
    env.ns.Client = { isForever = forever }
    for _, shown in ipairs({ false, true }) do
        for name, setting in pairs(names) do
            local frame = env.NewFrame("Frame")
            frame:SetShown(shown)
            frame.TabSystem, frame.BankPanel, frame.BankItemSearchBox = false, false, false
            _G[name] = frame
            local native = function() end
            frame:SetScript("OnShow", native)
            local item
            if name == "BankFrame" then
                frame.BankPanel = env.NewFrame("Frame", nil, frame)
                item = env.NewFrame("Button", nil, frame.BankPanel)
                frame.BankPanel.itemButtonPool = { EnumerateActive = function() return pairs({ [item] = true }) end }
                if forever then frame.itemButtonBagPool = frame.BankPanel.itemButtonPool end
            elseif name == "MerchantFrame" then
                _G.MerchantItem1 = env.NewFrame("Frame", nil, frame)
                item = env.NewFrame("Button", nil, _G.MerchantItem1)
                _G.MerchantItem1.ItemButton = item
            elseif name == "QuestFrame" then
                item = env.NewFrame("Button", nil, frame)
                _G.QuestProgressItem1 = item
            elseif name == "GearManagerPopupFrame" then
                frame.BorderBox = env.NewFrame("Frame", nil, frame)
                item = env.NewFrame("Button", nil, frame.BorderBox)
                frame.BorderBox.OkayButton = item
                frame.BorderBox.CancelButton = false
            else
                item = env.NewFrame("Button", nil, frame)
                frame.GreetingPanel = env.NewFrame("Frame", nil, frame)
                frame.GreetingPanel.ScrollBox = { ForEachFrame = function(_, callback) callback(item) end }
                local label = item:CreateFontString()
                item.GetFontString = function() return label end
            end
            item.DisabledTexture = false
            item.Icon = item:CreateTexture()
            item.Icon:SetTexture("native-item")
            item:SetScript("OnClick", native)
            for _, method in ipairs({ "SetSize", "SetWidth", "SetHeight", "ClearAllPoints", "SetPoint",
                "SetAllPoints", "SetParent", "SetAttribute" }) do
                frame[method] = function() error(name .. " must preserve native root geometry") end
                item[method] = function() error(name .. " must preserve native item action geometry") end
            end
            callbacks.Blizzard_UIPanels_Game()
            if not shown then
                assert(not skin.IsSkinned(frame), name .. " must stay deferred while hidden in combat")
                frame:Show()
            end
            assert(skin.IsSkinned(frame) and skin.GetBackdrop(frame),
                name .. " must initialize on first open or reload during combat")
            if name == "BankFrame" or name == "QuestFrame" or name == "GearManagerPopupFrame"
                or name == "GossipFrame" then
                assert(skin.GetBackdrop(item), name .. " content must initialize during combat")
            elseif name == "MerchantFrame" then
                assert(skin.GetBackdrop(_G.MerchantItem1), "merchant item rows must initialize during combat")
            end
            assert(item:GetScript("OnClick") == native and frame:GetScript("OnShow") == native,
                name .. " native scripts must survive combat initialization")
            if refreshes[setting] then refreshes[setting]() end
            frame:Hide()
            frame:Show()
            assert(initializations[frame] == 1, name .. " must reuse combat initialization")
        end
    end
end
print("PASS interaction_first_show_test")
