local Harness = dofile("tests/helpers/character_chrome_harness.lua")

local function Protect(frame)
    frame.IsProtected = function() return true end
    for _, method in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetScale", "ClearAllPoints", "SetPoint",
        "SetAllPoints", "SetParent", "SetAttribute", "Show", "Hide", "SetShown" }) do
        frame[method] = function() error("social skin must preserve protected frame " .. method) end
    end
end

for _, modern in ipairs({ false, true }) do
    for _, shown in ipairs({ false, true }) do
        local env = Harness.Build()
        _G.InCombatLockdown = function() return true end
        assert(loadfile("core/uikit.lua"))("QUI", env.ns)
        local skin = env.ns.SkinBase
        env.profile.general.skinFriends = true
        env.ns.Client = { isForever = modern }
        for _, name in ipairs({ "FriendsFrame", "SocialUIFrame", "FriendsListFrame", "RaidFrame",
            "RaidGroupButton1", "FriendsFrameTab1" }) do _G[name] = nil end
        local callbacks = {}
        skin.OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end
        local function Frame(kind, parent)
            local frame = env.NewFrame(kind or "Frame", nil, parent)
            frame.DisabledTexture = false
            return frame
        end
        local frame = Frame()
        frame:SetShown(shown)
        frame.Bg = frame:CreateTexture()
        frame.Bg:SetTexture("native-background")
        frame.CloseButton = Frame("Button", frame)
        local clicks = 0
        local nativeClick = function() clicks = clicks + 1 end
        frame.CloseButton:SetScript("OnClick", nativeClick)
        local list = Frame("Frame", frame)
        list.ScrollBox = Frame("Frame", list)
        list.ScrollBar = Frame("Frame", list)
        local contact = Frame("Button", list.ScrollBox)
        contact.background = contact:CreateTexture()
        contact.travelPassButton = Frame("Button", contact)
        contact.travelPassButton.Text = contact.travelPassButton:CreateFontString()
        contact.travelPassButton:SetScript("OnClick", nativeClick)
        local acquired
        skin.HookScrollBoxAcquired = function(_, callback)
            acquired = callback
            callback(contact)
        end
        local raid = Frame("Frame", frame)
        local group = Frame("Frame", raid)
        local player = Frame("Button", group)
        player:SetScript("OnClick", nativeClick)
        player.Name = player:CreateFontString()
        player.Name:SetText("Mage")
        player.Name:SetTextColor(0.25, 0.5, 1, 1)
        player.Background = player:CreateTexture()
        player.Background:SetTexture("native-raid-background")
        local tab = Frame("Button", frame)
        tab.Text = tab:CreateFontString()
        tab.Text:SetText("Friends")
        tab:SetScript("OnClick", nativeClick)
        if modern then
            _G.SocialUIFrame = frame
            frame.FriendsList = list
            list.FilterBar = { SearchBar = Frame("EditBox", list), SearchFilterDropdown = Frame("Button", list) }
            list.ActionButton = Frame("Button", list)
            frame.RaidFrame = raid
            raid.groups = { group }
            raid.players = { player }
            raid.RaidInfoButton = Frame("Button", raid)
            raid.ConvertToRaidButton = Frame("Button", raid)
            raid.AllAssistCheckButton = Frame("CheckButton", raid)
            raid.AllAssistCheckButton.Icon = raid.AllAssistCheckButton:CreateTexture()
            raid.AllAssistCheckButton.AllText = raid.AllAssistCheckButton:CreateFontString()
            raid.UpdateContents = function() end
            frame.EnumerateTabs = function()
                local visited = false
                return function() if not visited then visited = true; return tab end end
            end
        else
            _G.FriendsFrame = frame
            _G.FriendsListFrame = list
            _G.RaidFrame = raid
            _G.RaidGroupButton1 = player
            _G.FriendsFrameTab1 = tab
        end
        Protect(frame)
        Protect(raid)
        Protect(group)
        Protect(player)
        assert(loadfile(os.getenv("QUI_SOCIAL_SOURCE") or "modules/skinning/frames/social.lua"))("QUI", env.ns)
        callbacks.Blizzard_FriendsFrame()
        callbacks.Blizzard_SocialUI()
        if not shown then
            assert(not skin.GetBackdrop(frame) and not acquired, "hidden combat social must still defer all skin work")
            frame.shown = true
            frame:Fire("OnShow")
        end
        assert(skin.IsSkinned(frame) and skin.GetBackdrop(frame),
            (modern and "modern" or "legacy") .. " social must skin on first opening or reload during combat")
        assert(not frame.Bg:IsShown() and skin.GetBackdrop(tab), "combat social must skin shell and navigation")
        assert(skin.GetBackdrop(contact.travelPassButton) and contact.background:GetAlpha() == 0,
            "combat social must skin existing contacts and invite controls")
        if modern then
            assert(player.Background:GetAlpha() == 0 and skin.GetBackdrop(raid.ConvertToRaidButton),
                "combat social must skin secure raid rows cosmetically and ordinary sibling controls")
            assert(skin.GetBackdrop(list.FilterBar.SearchBar) and skin.GetBackdrop(list.ActionButton),
                "combat social must skin contact search and actions")
            player.Background:SetTexture("native-raid-refresh")
            raid:UpdateContents()
            assert(player.Background:GetAlpha() == 0, "native raid refresh must retain combat skin")
        end
        assert(player.Name.textColor[1] == 0.25 and player.Name.textColor[2] == 0.5,
            "secure raid labels must preserve native class colors")
        local backdrop = skin.GetBackdrop(frame)
        callbacks.Blizzard_RaidUI()
        acquired(contact)
        frame:Fire("OnShow")
        assert(skin.GetBackdrop(frame) == backdrop, "combat addon load and reopen must reuse the shell")
        assert(player:GetScript("OnClick") == nativeClick and tab:GetScript("OnClick") == nativeClick
            and frame.CloseButton:GetScript("OnClick") == nativeClick and clicks == 0,
            "combat skinning must preserve native action ownership without invoking actions")
    end
end

print("OK: social_combat_first_show_test")
