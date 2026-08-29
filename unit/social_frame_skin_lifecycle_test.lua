local callbacks = {}
local frameData = setmetatable({}, { __mode = "k" })
local skinned = setmetatable({}, { __mode = "k" })
local calls = {
    buttons = setmetatable({}, { __mode = "k" }),
    buttonOptions = setmetatable({}, { __mode = "k" }),
    buttonFontOptions = setmetatable({}, { __mode = "k" }),
    checkBoxes = setmetatable({}, { __mode = "k" }),
    dropdowns = setmetatable({}, { __mode = "k" }),
    editBoxes = setmetatable({}, { __mode = "k" }),
    hiddenChrome = setmetatable({}, { __mode = "k" }),
    rowHooks = setmetatable({}, { __mode = "k" }),
    rowHookOptions = setmetatable({}, { __mode = "k" }),
    rows = setmetatable({}, { __mode = "k" }),
    hiddenTextures = setmetatable({}, { __mode = "k" }),
    scrollBars = setmetatable({}, { __mode = "k" }),
    stripped = setmetatable({}, { __mode = "k" }),
    tabGroups = {},
    windows = setmetatable({}, { __mode = "k" }),
    windowOptions = setmetatable({}, { __mode = "k" }),
    dropdownOptions = setmetatable({}, { __mode = "k" }),
}

function hooksecurefunc(target, method, callback)
    if type(target) == "string" then
        local original = _G[target]
        local hook = method
        _G[target] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
        return
    end
    local original = target[method]
    target[method] = function(self, ...)
        local results = { original(self, ...) }
        callback(self, ...)
        return unpack(results)
    end
end

local function Count(bucket, object)
    if not object then return end
    bucket[object] = (bucket[object] or 0) + 1
end

local settings = { skinFriends = true, skinCommunities = false }
local ns = {
    Helpers = {
        GetCore = function()
            return { db = { profile = { general = settings } } }
        end,
    },
    Registry = { Register = function() end },
}

ns.SkinBase = {
    ApplyButtonFontObjects = function(button, opts) calls.buttonFontOptions[button] = opts end,
    ApplyButtonFontObjectsDeep = function() end,
    ClampTextureHidden = function(texture) calls.hiddenTextures[texture] = true end,
    GetFrameData = function(frame, key)
        return frameData[frame] and frameData[frame][key]
    end,
    HidePortraitFrameChrome = function(frame) calls.hiddenChrome[frame] = true end,
    HookScrollBoxAcquired = function(scrollBox, callback, opts)
        Count(calls.rowHooks, scrollBox)
        calls.rowHookOptions[scrollBox] = opts or false
        scrollBox.rowCallback = callback
    end,
    HookScrollBoxRowFonts = function() end,
    IsSkinned = function(frame) return skinned[frame] == true end,
    KillNineSlice = function() end,
    LockFrameTextObjects = function() end,
    LockFontObject = function() end,
    LockPooledRowText = function(row) calls.rows[row] = true end,
    MarkSkinned = function(frame) skinned[frame] = true end,
    OnAddOnLoaded = function(addon, callback) callbacks[addon] = callback end,
    RefreshFrameBackdropColors = function() end,
    SetFrameData = function(frame, key, value)
        frameData[frame] = frameData[frame] or {}
        frameData[frame][key] = value
    end,
    SkinButton = function(button, opts)
        Count(calls.buttons, button)
        calls.buttonOptions[button] = opts or false
    end,
    SkinCheckBox = function(checkBox) Count(calls.checkBoxes, checkBox) end,
    SkinCloseButton = function() end,
    SkinDropdown = function(dropdown, opts)
        Count(calls.dropdowns, dropdown)
        calls.dropdownOptions[dropdown] = opts or false
    end,
    SkinEditBox = function(editBox) Count(calls.editBoxes, editBox) end,
    SkinFontString = function(fontString, opts)
        local color = opts and opts.color
        if color then fontString:SetTextColor(color[1], color[2], color[3], color[4]) end
    end,
    SkinFrameText = function() end,
    SkinTabGroup = function(tabs, owner, opts)
        calls.tabGroups[#calls.tabGroups + 1] = { tabs = tabs, owner = owner, opts = opts }
    end,
    SkinTrimScrollBar = function(scrollBar) Count(calls.scrollBars, scrollBar) end,
    SkinWindow = function(frame, opts)
        Count(calls.windows, frame)
        calls.windowOptions[frame] = opts or false
    end,
    StripTextures = function(frame) calls.stripped[frame] = true end,
}

local function NewList()
    return { ScrollBox = {}, ScrollBar = {} }
end

local function NewContactView()
    local frame = NewList()
    frame.FilterBar = { SearchBar = {}, SearchFilterDropdown = {} }
    frame.ActionButton = {}
    return frame
end

local function NewFontString(text)
    local fontString = { text = text }
    function fontString:SetText(value) self.text = value end
    function fontString:SetTextColor(...) self.textColor = { ... } end
    function fontString:ClearAllPoints() self.point = nil end
    function fontString:SetPoint(...) self.point = { ... } end
    return fontString
end

_G.FriendsListFrame = NewList()
_G.WhoFrame = NewList()
_G.WhoFrame.WhoFrameListInset = {}
local contactTabs = { {}, {}, {} }
_G.FriendsTabHeader = { TabSystem = { tabs = contactTabs } }
_G.FriendsFrame = { IgnoreListWindow = NewList(), FriendsTabHeader = _G.FriendsTabHeader }
_G.FriendsFrame.IgnoreListWindow.UnignorePlayerButton = {}
_G.FriendsFrameAddFriendButton = {}
_G.FriendsFrameSendMessageButton = {}
_G.WhoFrameGroupInviteButton = {}
_G.WhoFrameAddFriendButton = {}
_G.WhoFrameWhoButton = {}
_G.WhoFrameEditBox = { searchIcon = { SetAlpha = function(self, alpha) self.alpha = alpha end } }
_G.WhoFrameDropdown = { TabHighlight = {} }
_G.FriendsFrameStatusDropdown = {}
_G.UserScaledFontGameNormal = { GetFont = function() return "Interface\\FrameXML\\Fonts\\Default.ttf", 15 end }
_G.ALL_ASSIST_LABEL_SHORT = "All"
_G.RaidFrameAllAssistCheckButton_UpdateAvailable = function(check)
    check.Text:SetTextColor(0.5, 0.5, 0.5, 1)
end
for index = 1, 4 do
    _G["FriendsFrameTab" .. index] = {}
    _G["WhoFrameColumnHeader" .. index] = {}
end

assert(loadfile("modules/skinning/frames/social.lua"))("QUI", ns)

for _, addon in ipairs({
    "Blizzard_FriendsFrame", "Blizzard_SocialUI", "Blizzard_QuickJoin",
    "Blizzard_RaidFrame", "Blizzard_RaidUI", "Blizzard_RecentAllies",
}) do
    assert(type(callbacks[addon]) == "function", addon .. " must refresh Social-frame content")
end

callbacks.Blizzard_FriendsFrame()

assert(calls.windows[_G.FriendsFrame] == 1, "legacy FriendsFrame shell must use QUI chrome")
assert(calls.scrollBars[_G.FriendsListFrame.ScrollBar] == 1, "Contacts scrollbar must be skinned")
assert(calls.scrollBars[_G.WhoFrame.ScrollBar] == 1, "Who scrollbar must be skinned")
assert(calls.hiddenChrome[_G.WhoFrame.WhoFrameListInset], "Who inset chrome must be removed")
for _, index in ipairs({ 1, 3, 4 }) do
    assert(calls.buttons[_G["WhoFrameColumnHeader" .. index]] == 1,
        "sortable Who column headers must use QUI button chrome")
end
assert(not calls.buttons[_G.WhoFrameColumnHeader2] and calls.stripped[_G.WhoFrameColumnHeader2],
    "the Zone dropdown container must be transparent, not button-skinned")
assert(calls.dropdowns[_G.WhoFrameDropdown] == 1
    and calls.dropdownOptions[_G.WhoFrameDropdown].skinArrow == true,
    "the Zone selector must use dropdown chrome and a QUI arrow")
assert(#calls.tabGroups == 1 and calls.tabGroups[1].tabs == contactTabs
    and calls.tabGroups[1].owner == _G.FriendsTabHeader
    and calls.tabGroups[1].opts.resizeToText == true,
    "Friends, Recent Allies, and Recruit A Friend must use the QUI top-tab skin")
assert(calls.windowOptions[_G.FriendsFrame].tabs[1] == _G.FriendsFrameTab1
    and calls.windowOptions[_G.FriendsFrame].tabs[4] == _G.FriendsFrameTab4,
    "Contacts, Who, Raid, and Quick Join must remain one navigation tab group")
assert(_G.WhoFrameEditBox.searchIcon.alpha == 1, "Who search must retain its search icon")
assert(calls.buttons[_G.WhoFrameWhoButton] == 1, "Who action buttons must use QUI chrome")
for _, button in ipairs({ _G.WhoFrameAddFriendButton, _G.WhoFrameGroupInviteButton }) do
    local color = calls.buttonOptions[button].disabledFontColor
    assert(color and color[1] == 1 and color[2] == 1 and color[3] == 1,
        "disabled Who action text must remain QUI white")
end

_G.QuickJoinFrame = NewList()
_G.QuickJoinFrame.JoinQueueButton = {}
callbacks.Blizzard_QuickJoin()
assert(calls.scrollBars[_G.QuickJoinFrame.ScrollBar] == 1,
    "late-loaded legacy Quick Join scrollbar must be skinned")
assert(calls.buttons[_G.QuickJoinFrame.JoinQueueButton] == 1,
    "late-loaded legacy Quick Join action must be skinned")
assert(calls.rowHookOptions[_G.QuickJoinFrame.ScrollBox] == false,
    "Quick Join rows must skin after their dynamic FontStrings are initialized")

_G.RaidFrame = { RaidFrameNotInRaid = { ScrollingDescriptionScrollBar = {} } }
_G.RaidFrameConvertToRaidButton = {}
_G.RaidFrameRaidInfoButton = {}
_G.RaidFrameAllAssistCheckButton = { Text = NewFontString("All") }
callbacks.Blizzard_RaidFrame()
assert(calls.buttons[_G.RaidFrameConvertToRaidButton] == 1,
    "late-loaded legacy Raid actions must be skinned")
local legacyConvertColor = calls.buttonOptions[_G.RaidFrameConvertToRaidButton].disabledFontColor
assert(legacyConvertColor[1] == 1 and legacyConvertColor[2] == 1 and legacyConvertColor[3] == 1,
    "legacy Convert to Raid text must remain QUI white when disabled")
assert(calls.buttonFontOptions[_G.RaidFrameConvertToRaidButton].size == 15,
    "legacy Convert to Raid must match the user-scaled Social action font size")
assert(calls.checkBoxes[_G.RaidFrameAllAssistCheckButton] == 1,
    "late-loaded legacy Raid checkbox must be skinned")
_G.RaidFrameAllAssistCheckButton_UpdateAvailable(_G.RaidFrameAllAssistCheckButton)
local legacyAllText = _G.RaidFrameAllAssistCheckButton.Text
assert(legacyAllText.textColor[1] == 1 and legacyAllText.textColor[2] == 1
    and legacyAllText.textColor[3] == 1,
    "legacy All Assist text must remain white after Blizzard disables it")
assert(legacyAllText.point[1] == "LEFT"
    and legacyAllText.point[2] == _G.RaidFrameAllAssistCheckButton
    and legacyAllText.point[3] == "RIGHT" and legacyAllText.point[4] == 4,
    "legacy All Assist text must clear the QUI checkbox border")

local friendsList = NewContactView()
local recentAlliesList = NewContactView()
local friendRequestsList = NewContactView()
local quickJoin = NewContactView()
local raidPlayerBackground = {}
local raidPlayerStatusIcon = {}
local raidPlayerName = NewFontString("Mage")
raidPlayerName:SetTextColor(0.25, 0.5, 1, 1)
local raidPlayer = {
    Background = raidPlayerBackground,
    StatusIcon = raidPlayerStatusIcon,
    Name = raidPlayerName,
}
local raid = {
    RaidInfoButton = {},
    ConvertToRaidButton = {},
    AllAssistCheckButton = {
        Icon = {},
        AllText = NewFontString("All"),
        UpdateAvailable = function(self)
            self.AllText:SetText("|cff808080All|r")
            self.AllText:SetTextColor(0.5, 0.5, 0.5, 1)
        end,
    },
    groups = {},
    players = { raidPlayer },
    UpdateContents = function() end,
}
local raidInfo = NewList()
raidInfo.CloseButton = {}
raidInfo.ExtendButton = {}
local ignoreList = NewList()
ignoreList.BlockButton = {}
ignoreList.UnblockButton = {}
local broadcast = { EditBox = {}, UpdateButton = {}, CancelButton = {} }
_G.SocialUIFrame = {
    BattleNetBar = {
        ControlsContainer = {
            OnlineStatusDropdown = {},
            BattleNetMenuButton = {},
        },
    },
    FriendsList = friendsList,
    RecentAlliesList = recentAlliesList,
    FriendRequestsList = friendRequestsList,
    QuickJoinFrame = quickJoin,
    RaidFrame = raid,
    RaidInfoFrame = raidInfo,
    IgnoreListFrame = ignoreList,
    BattleNetBroadcastFrame = broadcast,
}

callbacks.Blizzard_SocialUI()

assert(calls.windows[_G.SocialUIFrame] == 1, "modern SocialUIFrame shell must use QUI chrome")
assert(calls.editBoxes[friendsList.FilterBar.SearchBar] == 1,
    "modern Contacts search box must be skinned")
assert(calls.dropdowns[friendsList.FilterBar.SearchFilterDropdown] == 1,
    "modern Contacts filter must be skinned")
assert(calls.buttons[friendsList.ActionButton] == 1, "modern Contacts action must be skinned")
assert(calls.editBoxes[recentAlliesList.FilterBar.SearchBar] == 1
    and calls.dropdowns[recentAlliesList.FilterBar.SearchFilterDropdown] == 1
    and calls.buttons[recentAlliesList.ActionButton] == 1,
    "modern Recent Allies controls must be skinned")
assert(calls.editBoxes[friendRequestsList.FilterBar.SearchBar] == 1
    and calls.dropdowns[friendRequestsList.FilterBar.SearchFilterDropdown] == 1
    and calls.buttons[friendRequestsList.ActionButton] == 1,
    "modern Friend Requests controls must be skinned")
local onlineStatusDropdown = _G.SocialUIFrame.BattleNetBar.ControlsContainer.OnlineStatusDropdown
assert(calls.dropdowns[onlineStatusDropdown] == 1
    and calls.dropdownOptions[onlineStatusDropdown].skinArrow == true,
    "modern online-status dropdown must use QUI chrome and arrow")
assert(calls.scrollBars[quickJoin.ScrollBar] == 1, "modern Quick Join scrollbar must be skinned")
assert(calls.rowHookOptions[quickJoin.ScrollBox] == false,
    "modern Quick Join rows must skin after initialization")
assert(calls.buttons[raid.RaidInfoButton] == 1 and calls.buttons[raid.ConvertToRaidButton] == 1,
    "modern Raid actions must be skinned")
local modernConvertColor = calls.buttonOptions[raid.ConvertToRaidButton].disabledFontColor
assert(modernConvertColor[1] == 1 and modernConvertColor[2] == 1 and modernConvertColor[3] == 1,
    "modern Convert to Raid text must remain QUI white when disabled")
assert(calls.buttonFontOptions[raid.ConvertToRaidButton].size == 15,
    "modern Convert to Raid must match the user-scaled Social action font size")
assert(calls.checkBoxes[raid.AllAssistCheckButton] == 1, "modern Raid checkbox must be skinned")
raid.AllAssistCheckButton:UpdateAvailable()
local modernAllText = raid.AllAssistCheckButton.AllText
assert(modernAllText.text == "All",
    "modern All Assist text must discard Blizzard's inline disabled color")
assert(modernAllText.textColor[1] == 1 and modernAllText.textColor[2] == 1
    and modernAllText.textColor[3] == 1,
    "modern All Assist text must remain white after Blizzard disables it")
assert(modernAllText.point[1] == "LEFT" and modernAllText.point[2] == raid.AllAssistCheckButton.Icon
    and modernAllText.point[3] == "RIGHT" and modernAllText.point[4] == 4,
    "modern All Assist text must clear the assist icon without removing it")
assert(calls.windows[raidInfo] == 1 and calls.scrollBars[raidInfo.ScrollBar] == 1,
    "modern Raid Info side window must be fully skinned")
assert(calls.windows[ignoreList] == 1 and calls.scrollBars[ignoreList.ScrollBar] == 1
    and calls.buttons[ignoreList.BlockButton] == 1 and calls.buttons[ignoreList.UnblockButton] == 1,
    "modern Ignore List window and actions must be skinned")
assert(calls.editBoxes[broadcast.EditBox] == 1
    and calls.buttons[broadcast.UpdateButton] == 1 and calls.buttons[broadcast.CancelButton] == 1,
    "modern Battle.net broadcast controls must be skinned")
assert(calls.rows[raidPlayer] and calls.hiddenTextures[raidPlayerBackground],
    "modern Raid player rows must receive QUI fonts and hide only row chrome")
assert(not calls.hiddenTextures[raidPlayerStatusIcon]
    and raidPlayerName.textColor[1] == 0.25 and raidPlayerName.textColor[2] == 0.5
    and raidPlayerName.textColor[3] == 1 and raidPlayerName.textColor[4] == 1,
    "modern Raid player rows must preserve semantic icons and class colors")

callbacks.Blizzard_RecentAllies()
assert(calls.rowHooks[friendsList.ScrollBox] == 1,
    "later Social addon loads must not duplicate pooled-row callbacks")

print("OK: social_frame_skin_lifecycle_test")
