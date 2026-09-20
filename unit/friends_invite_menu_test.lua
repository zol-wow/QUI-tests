local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local legacySource = read("tests/framexml/Interface/AddOns/Blizzard_FriendsFrame/Mainline/FriendsFrame.lua")
local legacy = assert(legacySource:match("(function FriendsFrame_SetupTravelPassDropdown.-)\nfunction CanCooperateWithGameAccount"))
local modernSource = read("tests/framexml/Interface/AddOns/Blizzard_FriendsFrame/Mainline/FriendsListTemplates.lua")
local modern = assert(modernSource:match("(local function BuildWoWGameAccountDropdownText.-)\nfunction FriendsListSocialCardPartyButtonMixin:TryInviteFriend"))

local function newRoot()
    local root = { rows = {} }
    function root:SetTag(tag, context) self.tag, self.context = tag, context end
    function root:GetTag() return self.tag, self.context end
    function root:EnumerateElementDescriptions() return ipairs(self.rows) end
    function root:Insert(row, index) table.insert(self.rows, index or #self.rows + 1, row) end
    function root:CreateButton(text, callback)
        local row = { text = text, callback = callback, enabled = true }
        function row:SetEnabled(enabled) self.enabled = enabled end
        function row:IsEnabled() return self.enabled end
        function row:AddInitializer(initializer) self.initializer = initializer end
        self:Insert(row)
        return row
    end
    function root:CreateTitle(text)
        local row = self:CreateButton(text)
        row.title = true
        return row
    end
    return root
end

local function wow(id, restriction)
    return {
        clientProgram = "WoW", gameAccountID = id, characterName = "Toon" .. id,
        characterLevel = 80, raceName = "Human", className = "Mage",
        playerGuid = "Player-" .. id, factionName = "Alliance",
        wowProjectID = restriction and 2 or 1, realmID = 5,
        restriction = restriction and 1 or 0,
    }
end

local apps = { { clientProgram = "App" }, { clientProgram = "BSAp" } }

local function run(builder, accounts, options)
    options = options or {}
    local manager = { opens = {}, replacements = 0 }
    local menu = {}
    function menu:SetMenuDescription(root)
        manager.replacements = manager.replacements + 1
        manager.root = root
    end
    function manager:GetOpenMenu() return menu end
    function manager:OpenContextMenu(owner, root)
        self.opens[#self.opens + 1] = { owner = owner, root = root }
        assert(#self.opens <= 2, "Filtering must not recursively reopen the menu")
        self.owner, self.root = owner, root
    end
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.BNET_CLIENT_WOW = "WoW"
    env.WOW_PROJECT_ID, env.WOW_PROJECT_CLASSIC = 1, 2
    env.TRAVEL_PASS_INVITE = "Invite"
    env.FRIENDS_TOOLTIP_WOW_TOON_TEMPLATE = "%s %d %s %s"
    env.CANNOT_COOPERATE_LABEL, env.UNKNOWN = " (restricted)", "Unknown"
    env.SOCIAL_UI_FRIENDS_LIST_PARTY_DROPDOWN_ICON_NAME_FORMAT = "%s %s"
    env.INVITE_RESTRICTION_NONE, env.INVITE_RESTRICTION_WOW_PROJECT_ID = 0, 1
    env.INVITE_RESTRICTION_CLIENT = 2
    env.playerFactionGroup, env.playerRealmID = "Alliance", 5
    env.Enum = { TitleIconVersion = { Small = 1 } }
    env.C_PartyInfo = { CanFormCrossFactionParties = function() return true end }
    env.C_QuestSession = { Exists = function() return false end }
    env.CanInviteByGameMode = function() return true end
    env.C_Texture = {
        IsTitleIconTextureReady = function() return true end,
        GetTitleIconTexture = function(_, _, callback) callback(true, "BNetIcon") end,
    }
    env.BNet_GetClientEmbeddedTexture = function() return "|TBNetIcon:18|t" end
    env.BNet_GetValidatedCharacterName = function(name) return name end
    env.BattleNetFriendPartyInviteRestrictionType = { None = 0 }
    env.SocialUIUtil = {
        InitializeUserScaledDropdownButton = function() end,
        InitializeUserScaledDropdownTitle = function() end,
    }
    local invites, generated = {}, nil
    local function invite(guid, id) invites[#invites + 1] = { guid, id } end
    env.FriendsFrame_InviteOrRequestToJoin = invite
    env.FriendsListUtil = {
        IsPlayingWoW = function(info) return info.clientProgram == "WoW" end,
        GetGameAccountPartyInviteRestriction = function(info) return info.restriction end,
        InviteOrRequestToJoin = invite,
    }
    env.C_BattleNet = {
        GetFriendAccountInfo = function() return { battleTag = "Friend#1234" } end,
        GetFriendNumGameAccounts = function(index)
            assert(index == 7, "Filtering must resolve the native owner's friend index")
            return #accounts
        end,
        GetFriendGameAccountInfo = function(index, accountIndex)
            assert(index == 7)
            if generated and options.missingAccount == accountIndex then return nil end
            return accounts[accountIndex]
        end,
        GetGameAccountInfoByID = function(id)
            for _, info in ipairs(accounts) do
                if info.gameAccountID == id then return info end
            end
        end,
    }
    env.Menu = { GetManager = function() return manager end, CreateRootMenuDescription = newRoot }
    env.MenuVariants = { GetDefaultContextMenuMixin = function() return {} end }
    env.MenuUtil = {
        CreateRootMenuDescription = newRoot,
        CreateContextMenu = function(owner, generator)
            local root = newRoot()
            generator(owner, root)
            if options.addonRow then root:CreateButton("Addon action", options.addonRow) end
            if options.tag then root:SetTag(options.tag) end
            generated = root
            manager:OpenContextMenu(owner, root)
        end,
    }
    env.CreateFrame = function()
        return { RegisterEvent = function() end, SetScript = function() end }
    end
    env.FriendsFrame_UpdateFriendButton = function() end
    env.hooksecurefunc = function(target, name, callback)
        if type(target) == "string" then
            target, name, callback = env, target, name
        end
        local original = assert(target[name])
        target[name] = function(...)
            original(...)
            callback(...)
        end
    end
    local login
    local ns = {
        Helpers = { CreateDBGetter = function() return function() return {} end end },
        WhenLoggedIn = function(callback) login = callback end,
    }
    local module = assert(loadfile(arg[1] or "modules/qol/friends_decor.lua"))
    setfenv(module, env)
    module("QUI", ns)
    assert(login)()
    login()
    local source = builder == "modern" and modern .. "\nreturn ShowPartyInviteTargetSelectionDropdown"
        or legacy .. "\nreturn FriendsFrame_SetupTravelPassDropdown"
    local chunk = assert(loadstring(source))
    setfenv(chunk, env)
    local owner = builder == "modern" and { friendIndex = 7 }
        or { GetParent = function() return { id = 7 } end }
    if options.noIndex then owner = { GetParent = function() return {} end } end
    chunk()(7, owner)
    assert(manager.owner == owner, "Filtering must preserve the native owner/anchor")
    return manager.root, generated, manager, invites
end

for _, builder in ipairs({ "modern", "legacy" }) do
    local root, original, manager, invites = run(builder, { apps[1], apps[2], wow(10), wow(20) })
    assert(#root.rows == 3, builder .. ": expected title + 2 WoW characters, got " .. #root.rows .. " rows")
    assert(#manager.opens == 1 and manager.replacements == 1, builder .. ": replace the menu description once without reopening")
    assert(root.rows[1] == original.rows[1] and root.rows[1].title, "Preserve the native title")
    assert(root.rows[2] == original.rows[4] and root.rows[3] == original.rows[5], "Preserve native WoW descriptions")
    root.rows[2].callback()
    root.rows[3].callback()
    assert(invites[1][1] == "Player-10" and invites[1][2] == 10, "First toon must invite its own account")
    assert(invites[2][1] == "Player-20" and invites[2][2] == 20, "Second toon must invite its own account")
    if builder == "modern" then
        assert(root.rows[1].initializer and root.rows[2].initializer, "Preserve native UI scaling initializers")
    end

    local addonAction = function() end
    root, original = run(builder, { apps[1], wow(10), wow(20, true) }, { addonRow = addonAction })
    assert(#root.rows == 4 and root.rows[3] == original.rows[4], "Restricted WoW characters must remain")
    assert(root.rows[3].enabled == false and root.rows[3].callback == nil, "Native invite restriction must remain disabled")
    assert(root.rows[4] == original.rows[5] and root.rows[4].callback == addonAction, "Preserve appended addon entries")

    root, original, manager = run(builder, { wow(10), wow(20) })
    assert(root == original and #manager.opens == 1 and manager.replacements == 0, "WoW-only picker must remain untouched")

    root, original = run(builder, { apps[1], apps[2], wow(10) }, { missingAccount = 2 })
    local foundMissing = false
    for _, row in ipairs(root.rows) do
        if row == original.rows[3] then foundMissing = true end
    end
    assert(foundMissing, "Unavailable account data must not discard a native entry")

    for _, options in ipairs({ { noIndex = true }, { tag = "UNRELATED_MENU" } }) do
        root, original, manager = run(builder, { apps[1], wow(10) }, options)
        assert(root == original and #manager.opens == 1 and manager.replacements == 0, "Unrelated or unidentifiable menus must remain untouched")
    end
end

print("OK: friends_invite_menu_test")
