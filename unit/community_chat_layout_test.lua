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

local settings = { skinFriends = true, skinCommunities = true }
local ns = {
    Helpers = {
        GetCore = function()
            return { db = { profile = { general = settings } } }
        end,
    },
    Registry = { Register = function() end },
}

ns.SkinBase = {
    DeferUntilShown = function(frame)
        assert(frame:IsShown(), "layout fixture must exercise a visible Communities frame")
        return false
    end,
    GetBackdrop = function(frame) return frame.backdrop end,
    GetWindowColors = function() return 1, 1, 1, 1, 0.1, 0.1, 0.1, 1 end,
    CreateBackdrop = function(frame) frame.roundedBackdrop = true end,
    ApplyButtonFontObjects = function(button, opts) calls.buttonFontOptions[button] = opts end,
    ApplyButtonFontObjectsDeep = function() end,
    ClampTextureHidden = function(texture) if texture then calls.hiddenTextures[texture] = true end end,
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
_G.FriendsFrame.TopTileStreaks = {}
_G.FriendsFrameBg = {}
_G.FriendsFrame.Inset = { Bg = {} }
_G.FriendsFrame.TitleText = NewFontString("Contacts")
function _G.FriendsFrame:GetTitleText() return self.TitleText end
function _G.FriendsFrame:SetTitle(text)
    self.TitleText:SetText(text)
    self.TitleText:SetTextColor(1, 0.82, 0)
end
_G.FriendsFrameIcon = {}
_G.WhoFrameTotals = NewFontString("0 people found")

local broadcast = { EditBox = {}, UpdateButton = {}, CancelButton = {} }
local menuNormal, menuPushed, menuDisabled = {}, {}, {}
local contactsMenu = {
    GetNormalTexture = function() return menuNormal end,
    GetPushedTexture = function() return menuPushed end,
    GetDisabledTexture = function() return menuDisabled end,
    Icon = {},
}
_G.FriendsFrameBattlenetFrame = { ContactsMenuButton = contactsMenu, BroadcastFrame = broadcast }
_G.FriendsFrame.IgnoreListWindow.UnignorePlayerButton = {}
_G.FriendsFrameAddFriendButton = {}
_G.FriendsFrameSendMessageButton = {}
_G.WhoFrameGroupInviteButton = {}
_G.WhoFrameAddFriendButton = {}
_G.WhoFrameWhoButton = {}
_G.WhoFrameEditBox = { searchIcon = { SetAlpha = function(self, alpha) self.alpha = alpha end } }
_G.WhoFrameDropdown = { TabHighlight = {} }
function _G.WhoFrameDropdown:ClearAllPoints() self.points = {} end
function _G.WhoFrameDropdown:SetPoint(...) self.points[#self.points + 1] = { ... } end

_G.FriendsFrameStatusDropdown = { Text = NewFontString() }
_G.UserScaledFontGameNormal = { GetFont = function() return "Interface\\FrameXML\\Fonts\\Default.ttf", 15 end }
_G.ALL_ASSIST_LABEL_SHORT = "All"
_G.RaidFrameAllAssistCheckButton_UpdateAvailable = function(check)
    check.Text:SetTextColor(0.5, 0.5, 0.5, 1)
end
for index = 1, 4 do
    _G["FriendsFrameTab" .. index] = {}
    _G["WhoFrameColumnHeader" .. index] = {}
end


ns.SkinBase.GetDepthColor = function() return 0.1, 0.1, 0.1, 1 end
ns.SkinBase.RefreshWidget = function() end
ns.SkinBase.SkinFontString = function() end
ns.SkinBase.SkinButton = function(button) if button then calls.buttons[button] = true end end
ns.SkinBase.StripTextures = function() end
ns.SkinBase.SkinDropdown = function() end
local function Geometry()
    local f = { points = {}, scripts = {} }
    function f:IsShown() return true end
    function f:SetPoint(point, ...) self.points[point] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetHeight(height) self.height = height end
    function f:SetTextInsets(...) self.insets = { ... } end
    function f:HookScript(name, callback) self.scripts[name] = callback end
    return f
end
local frame = Geometry()
frame.Chat, frame.ChatEditBox, frame.MemberList = Geometry(), Geometry(), Geometry()
frame.InviteButton = {}
frame.CommunitiesControlFrame = { GuildRecruitmentButton = {}, CommunitiesSettingsButton = {} }
frame.Chat.InsetFrame = Geometry()
local editBox = frame.ChatEditBox
local nativeEnter = function() end
editBox.scripts.OnEnterPressed = nativeEnter
local sizing = { minimized = false }
frame.MaximizeMinimizeFrame = sizing
function sizing:IsMinimized() return self.minimized end
function sizing:Maximize()
    self.minimized = false
    frame.Chat:SetPoint("BOTTOMRIGHT", frame.MemberList, "BOTTOMLEFT", -32, 28)
    editBox:SetHeight(32)
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", frame.Chat, "BOTTOMLEFT", -4, -4)
end
function sizing:Minimize()
    self.minimized = true
    frame.Chat:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 36)
    editBox:ClearAllPoints()
    editBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 0)
end
_G.CommunitiesFrame = frame
assert(loadfile(arg[1] or "modules/skinning/frames/social.lua"))("QUI", ns)
callbacks.Blizzard_Communities()
local function CheckFull()
    assert(editBox.height == 24, "chat input must leave room for the footer buttons")
    local bottom = frame.Chat.points.BOTTOMRIGHT
    assert(bottom[1] == frame.MemberList and bottom[4] == 36)
    local left, right = editBox.points.TOPLEFT, editBox.points.TOPRIGHT
    assert(left[1] == frame.Chat and left[3] == -10 and right[3] == 10,
        "input edges must align with the transcript")
    -- Native member pane bottom is 28 above the window bottom; footer top is 25.
    local inputBottom = 28 + bottom[4] + left[4] - editBox.height
    assert(inputBottom - 25 >= 8, "full input border must clear every footer action")
    local inset = frame.Chat.InsetFrame.points.BOTTOMRIGHT
    assert(inset[4] - left[4] >= 4, "transcript border must not extend behind the input")
    assert(editBox.insets[1] == 8 and editBox.insets[2] == 8)
    assert(editBox.scripts.OnEnterPressed == nativeEnter, "native message handler must survive")
end
CheckFull()
for _ = 1, 3 do
    sizing:Minimize()
    local bottom = frame.Chat.points.BOTTOMRIGHT
    local entry = editBox.points.BOTTOMLEFT
    assert(bottom[1] == frame and bottom[4] == 40)
    assert(entry[1] == frame.Chat and entry[3] == 0 and entry[4] == -32)
    assert(bottom[4] + entry[4] == 8, "compact input must be inset inside the window")
    assert(bottom[4] - (8 + editBox.height) == 8, "compact transcript must clear the input")
    sizing:Maximize()
    CheckFull()
    frame.scripts.OnShow(frame)
    CheckFull()
end
assert(calls.buttons[frame.InviteButton] and calls.buttons[frame.CommunitiesControlFrame.GuildRecruitmentButton]
    and calls.buttons[frame.CommunitiesControlFrame.CommunitiesSettingsButton])
print("OK: community_chat_layout_test")
