-- tests/unit/options_profiles_dual_column_test.lua
-- Run: lua tests/unit/options_profiles_dual_column_test.lua

-- Headless WoW-ish stubs --------------------------------------------------
local function NewFontString()
    local fs = {}
    function fs:SetPoint() end
    function fs:SetText(text) self._text = text end
    function fs:SetTextColor() end
    function fs:SetJustifyH() end
    function fs:SetFont() end
    function fs:GetFont() return "font", 11, "" end
    function fs:SetWordWrap() end
    function fs:SetNonSpaceWrap() end
    function fs:SetWidth() end
    return fs
end

local function NewFrame()
    local f = {}
    function f:SetHeight(h) self._height = h end
    function f:GetHeight() return self._height or 0 end
    function f:SetWidth() end
    function f:SetSize() end
    function f:SetPoint() end
    function f:ClearAllPoints() end
    function f:SetScript(name, fn) self["_" .. name] = fn end
    function f:SetParent() end
    function f:Hide() end
    function f:Show() end
    function f:EnableMouse() end
    function f:Enable() self._enabled = true end
    function f:Disable() self._enabled = false end
    function f:CreateFontString() return NewFontString() end
    function f:CreateTexture() return NewFontString() end
    return f
end

_G.CreateFrame = function() return NewFrame() end
_G.C_Timer = { After = function() end }
_G.GetNumSpecializations = function() return 3 end
_G.GetSpecializationInfo = function(i) return i, "Spec" .. i end
_G.GetSpecialization = function() return 1 end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local gui = {
    Colors = {
        text = { 1, 1, 1, 1 },
        textMuted = { 0.6, 0.6, 0.6, 1 },
        accent = { 0.2, 0.8, 0.6, 1 },
    },
    ERROR_TEXT = { 0.9, 0.3, 0.3, 1 },
}
function gui:CreateLabel() return NewFontString() end
function gui:CreateButton(_parent, text, _width, _height, onClick)
    local b = NewFrame()
    b.text = NewFontString()
    b._buttonText = text
    b._onClick = onClick
    return b
end
function gui:CreateFormDropdown(_parent, _label, options, dbKey, dbTable, onChange)
    local d = NewFrame()
    d._options = options or {}
    function d:SetValue(value, skipOnChange)
        if dbTable and dbKey then dbTable[dbKey] = value end
        if onChange and not skipOnChange then onChange(value) end
    end
    d.SetOptions = function(first, second)
        d._options = (first == d and second or first) or {}
    end
    return d
end
function gui:CreateFormEditBox()
    local e = NewFrame()
    e.editBox = NewFrame()
    e.editBox.GetText = function() return "" end
    e.editBox.SetText = function() end
    return e
end
function gui:CreateFormCheckbox() return NewFrame() end
function gui:CreateFormToggle(_parent, _label, dbKey, dbTable, onChange)
    local toggle = NewFrame()
    function toggle:GetValue() return dbTable[dbKey] and true or false end
    function toggle:SetValue(value, skipCallback)
        dbTable[dbKey] = value and true or false
        if onChange and not skipCallback then onChange(dbTable[dbKey]) end
    end
    function toggle:SetEnabled(enabled) self._enabled = enabled and true or false end
    toggle._onClick = function()
        if toggle._enabled == false then return end
        toggle:SetValue(not toggle:GetValue())
    end
    return toggle
end
function gui:SetTooltipInfo(frame, description, label)
    frame._quiTooltipDescription = description
    frame._quiTooltipLabel = label
end
local confirmation
function gui:ShowConfirmation(opts) confirmation = opts end

_G.QUI = { GUI = gui, _presetProfiles = {}, imports = {} }

-- Recorders: every accent-dot header and card group the builder creates.
local headers = {}
local cards = {}
local Shared = {
    PADDING = 10,
    CreateScrollableContent = function() end,
    CreateAccentDotLabel = function(_, text)
        headers[#headers + 1] = text
        return NewFrame()
    end,
    CreateSettingsCardGroup = function()
        local card = { frame = NewFrame(), rows = {} }
        function card.AddRow(left, right)
            card.rows[#card.rows + 1] = { left = left, right = right }
            return NewFrame()
        end
        function card.Finalize() card.frame:SetHeight(#card.rows * 32) end
        function card.GetRowCount() return #card.rows end
        cards[#cards + 1] = card
        return card
    end,
    BuildSettingRow = function(_, labelText, widget, desc)
        return { _settingRowLabel = labelText, _widgetLabel = labelText, _widget = widget, _desc = desc }
    end,
}

local db = { _current = "Default" }
function db:GetProfiles() return { "Default", "Raid" } end
function db:GetCurrentProfile() return self._current end
function db:SetProfile() end
function db:CopyProfile() end
function db:DeleteProfile() end
function db:ResetProfile() end
function db:ResetDB() end
function db:IsDualSpecEnabled() return false end
function db:SetDualSpecEnabled() end
function db:GetDualSpecProfile() return "" end
function db:SetDualSpecProfile() end

local copied
local pinnedSources = {}
local pinOptOuts = {}
local pinnedCall
local unpinnedCall
local core = { db = db }
function core:GetProfileExportCategories()
    return {
        {
            id = "groupFrames",
            label = "Group / Raid Frames",
            children = {
                { id = "groupFramesParty", label = "Party" },
                { id = "groupFramesRaid", label = "Raid" },
            },
        },
        {
            id = "customTrackers",
            label = "Custom CDM Bars",
            children = {
                { id = "customTrackersShared", label = "Shared Settings" },
                { id = "customTrackerBar:1", label = "Bar 1", dynamic = true },
            },
        },
    }
end
function core:CopyProfileSelection(sourceName, categoryIDs)
    copied = { sourceName = sourceName, categoryIDs = categoryIDs }
    return true, "Copied settings."
end
function core:GetProfileFeatureSource(categoryID)
    return pinnedSources[categoryID]
end
function core:GetGlobalProfileFeatureSource(categoryID)
    return pinnedSources[categoryID]
end
function core:IsProfileFeaturePinOptedOut(categoryID)
    local profileOptOuts = pinOptOuts[db:GetCurrentProfile()]
    return profileOptOuts and profileOptOuts[categoryID] == true or false
end
function core:SetProfileFeaturePinOptOut(categoryID, optedOut)
    local profileName = db:GetCurrentProfile()
    pinOptOuts[profileName] = pinOptOuts[profileName] or {}
    pinOptOuts[profileName][categoryID] = optedOut and true or nil
    if next(pinOptOuts[profileName]) == nil then pinOptOuts[profileName] = nil end
    return true
end
function core:PinCurrentProfileSelection(categoryID)
    pinnedSources[categoryID] = db:GetCurrentProfile()
    pinnedCall = { categoryID = categoryID }
    return true
end
function core:UnpinProfileSelection(categoryID)
    pinnedSources[categoryID] = nil
    for profileName, profileOptOut in pairs(pinOptOuts) do
        profileOptOut[categoryID] = nil
        if next(profileOptOut) == nil then pinOptOuts[profileName] = nil end
    end
    unpinnedCall = categoryID
    return true
end

local ns = {
    QUI_Options = Shared,
    Helpers = { GetCore = function() return core end },
}

(dofile("tests/helpers/locale.lua"))(ns)
assert(loadfile("core/settings/content/profiles_content.lua"))("QUI", ns)
local Profiles = ns.QUI_ProfilesOptions
assert(Profiles and type(Profiles.BuildSpecProfilesContent) == "function",
    "profiles_content must expose BuildSpecProfilesContent")
assert(ns.QUI_ProfileCopyOptions and type(ns.QUI_ProfileCopyOptions.CreateCard) == "function",
    "profiles_content must expose the shared profile-copy card builder")
assert(type(ns.QUI_ProfileCopyOptions.HasSourceProfile) == "function",
    "profiles_content must expose profile-copy availability")

local content = NewFrame()
Profiles.BuildSpecProfilesContent(content)

assert(#headers == 4, "expected 4 section headers, got " .. #headers
    .. " (" .. table.concat(headers, ", ") .. ")")
assert(headers[1] == "Current Profile",
    "header 1 must be Current Profile, got " .. tostring(headers[1]))
assert(headers[2] == "Manage Profiles",
    "header 2 must be Manage Profiles, got " .. tostring(headers[2]))
assert(headers[3] == "Copy Feature Settings",
    "header 3 must be Copy Feature Settings, got " .. tostring(headers[3]))
assert(headers[4] == "Spec Auto-Switch",
    "header 4 must be Spec Auto-Switch, got " .. tostring(headers[4]))

assert(#cards == 4, "expected 4 card groups, got " .. #cards)
local currentCard, manageCard, copyCard, specCard = cards[1], cards[2], cards[3], cards[4]

-- Current Profile: two paired rows (active|reset-profile, movers|factory).
assert(#currentCard.rows == 2,
    "Current Profile card must have 2 rows, got " .. #currentCard.rows)
assert(currentCard.rows[1].right, "Current Profile row 1 must be paired")
assert(currentCard.rows[2].right, "Current Profile row 2 must be paired")

-- Manage Profiles: switch|copy then delete|create.
assert(#manageCard.rows == 2,
    "Manage Profiles card must have 2 rows, got " .. #manageCard.rows)
assert(manageCard.rows[1].left._settingRowLabel == "Switch Profile",
    "row 1 left must be Switch Profile, got " .. tostring(manageCard.rows[1].left._settingRowLabel))
assert(manageCard.rows[1].right._settingRowLabel == "Copy From",
    "row 1 right must be Copy From, got " .. tostring(manageCard.rows[1].right._settingRowLabel))
assert(manageCard.rows[2].left._settingRowLabel == "Delete Profile",
    "row 2 left must be Delete Profile, got " .. tostring(manageCard.rows[2].left._settingRowLabel))
assert(manageCard.rows[2].right,
    "Manage Profiles row 2 must pair the create cell on the right")
assert(manageCard.rows[2].right._widgetLabel == "New Profile",
    "create cell must carry _widgetLabel for the search cache")

assert(#copyCard.rows == 3,
    "Copy Feature Settings card must have 3 rows, got " .. #copyCard.rows)
assert(copyCard.rows[1].left._settingRowLabel == "Source Profile",
    "copy row 1 must select the source profile")
assert(copyCard.rows[2].left._settingRowLabel == "Feature Settings",
    "copy row 2 must select the feature category")
assert(copyCard.rows[3].left._widget._buttonText == "Copy Settings",
    "copy row 3 must contain the Copy Settings button")
assert(copyCard.rows[3].right == nil,
    "general feature copy must not offer unsupported profile pins")

local sourceDropdown = copyCard.rows[1].left._widget
assert(#sourceDropdown._options == 1 and sourceDropdown._options[1].value == "Raid",
    "copy source choices must exclude the active profile")
db._current = "Raid"
copyCard.frame._OnShow()
assert(#sourceDropdown._options == 1 and sourceDropdown._options[1].value == "Default",
    "copy source choices must refresh when the card is shown")
db._current = "Default"
copyCard.frame._OnShow()

local categoryDropdown = copyCard.rows[2].left._widget
local categoryIDs = {}
for _, option in ipairs(categoryDropdown._options) do categoryIDs[option.value] = true end
assert(categoryIDs.groupFramesParty and categoryIDs.groupFramesRaid,
    "copy categories must include static Party and Raid children")
assert(categoryIDs.customTrackersShared and not categoryIDs["customTrackerBar:1"],
    "copy categories must retain static children and exclude dynamic custom bars")

sourceDropdown:SetValue("Raid", true)
categoryDropdown:SetValue("groupFramesParty", true)
copyCard.rows[3].left._widget._onClick()
assert(confirmation and confirmation.isDestructive and type(confirmation.onAccept) == "function",
    "Copy Settings must require explicit destructive overwrite confirmation")
confirmation.onAccept()
assert(copied and copied.sourceName == "Raid" and copied.categoryIDs[1] == "groupFramesParty",
    "confirmed copy must call CopyProfileSelection with one selected category")

-- Spec Auto-Switch: full-width enable row, then 3 specs paired two-up.
assert(#specCard.rows == 3,
    "Spec card must have 3 rows (enable + 2 spec rows), got " .. #specCard.rows)
assert(specCard.rows[1].right == nil, "enable row must stay full-width")
assert(specCard.rows[1].left._settingRowLabel == "Enable Spec Profiles",
    "spec row 1 must be the enable checkbox")
assert(specCard.rows[2].right, "first spec row must be paired")
assert(specCard.rows[3].left and specCard.rows[3].right == nil,
    "odd spec count must leave the last row solo")

local fixedCopy = ns.QUI_ProfileCopyOptions.CreateCard(NewFrame(), {
    fixedCategoryID = "auraDisplays",
    fixedCategoryLabel = "Aura Displays",
})
assert(fixedCopy.categoryDropdown == nil and fixedCopy.frame:GetHeight() == 64,
    "fixed-category copy cards must omit the category dropdown and stay two rows tall")
local fixedCard = cards[#cards]
assert(fixedCard.rows[1].left._settingRowLabel == "Source Profile"
        and fixedCard.rows[1].right._settingRowLabel == "Current Profile",
    "fixed-category row 1 must pair the source profile with the current-profile copy")
assert(fixedCard.rows[2].left._settingRowLabel == "Pinned Settings"
        and fixedCard.rows[2].right._settingRowLabel == "Ignore",
    "fixed-category row 2 must pair the global pin with the current-profile override")
assert(fixedCard.rows[2].left._desc == nil,
    "pinned settings help must not render beneath the label in the narrow paired row")
assert(fixedCopy.pinButton._quiTooltipDescription
        == "Capture the current value and keep it across profile switches.",
    "pinned settings help must remain available as a tooltip")
assert(fixedCopy.pinButton._buttonText == "Pin across all profiles")
assert(fixedCard.rows[1].right._widget._enabled == true)
assert(fixedCopy.profilePinToggle:GetValue() == false
    and fixedCopy.profilePinToggle._enabled == false,
    "profile opt-out must stay disabled until a global pin exists")

fixedCopy.pinButton._onClick()
assert(pinnedCall and pinnedCall.categoryID == "auraDisplays")
assert(fixedCopy.pinButton._buttonText == "Unpin")
assert(fixedCopy.pinButton._quiTooltipDescription == "Click to unpin. Edits affect all profiles.")
assert(fixedCard.rows[1].right._widget._enabled == false,
    "one-time copy must be disabled while the feature is pinned")
assert(fixedCopy.profilePinToggle._enabled == false,
    "the global source must not ignore its own pin")

db._current = "Raid"
fixedCopy.RefreshSources()
assert(fixedCopy.pinButton._buttonText == "Unpin",
    "global unpin must remain available from a destination profile")
assert(fixedCopy.profilePinToggle:GetValue() == false
    and fixedCopy.profilePinToggle._enabled == true)
fixedCopy.profilePinToggle._onClick()
assert(pinOptOuts.Raid and pinOptOuts.Raid.auraDisplays == true)
assert(fixedCopy.profilePinToggle:GetValue() == true,
    "Ignore must stay visibly enabled while the current profile opts out")
assert(fixedCard.rows[1].right._widget._enabled == true,
    "one-time copy must be available while this profile ignores the pin")

confirmation = nil
fixedCopy.profilePinToggle._onClick()
assert(confirmation and confirmation.isDestructive and type(confirmation.onAccept) == "function",
    "rejoining a pin must confirm before overwriting this profile's settings")
assert(pinOptOuts.Raid and pinOptOuts.Raid.auraDisplays == true)
assert(fixedCopy.profilePinToggle:GetValue() == true,
    "Ignore must remain visibly enabled until rejoin is confirmed")
confirmation.onAccept()
assert(pinOptOuts.Raid == nil)
assert(fixedCopy.profilePinToggle:GetValue() == false)
assert(fixedCard.rows[1].right._widget._enabled == false)

db._current = "Default"
fixedCopy.RefreshSources()
fixedCopy.pinButton._onClick()
assert(unpinnedCall == "auraDisplays")
assert(fixedCopy.pinButton._buttonText == "Pin across all profiles")
assert(fixedCard.rows[1].right._widget._enabled == true)

db.GetProfiles = function() return { "Default" } end
assert(ns.QUI_ProfileCopyOptions.HasSourceProfile() == false,
    "profile copy must be unavailable with only the active profile")
assert(ns.QUI_ProfileCopyOptions.CreateCard(NewFrame(), {}) == nil,
    "profile copy must not render with only the active profile")
local soloFixed = ns.QUI_ProfileCopyOptions.CreateCard(NewFrame(), {
    fixedCategoryID = "auraDisplays",
    fixedCategoryLabel = "Aura Displays",
})
local soloCard = cards[#cards]
assert(soloFixed and soloFixed.pinButton._buttonText == "Pin across all profiles",
    "global pin controls must remain available with one profile")
assert(soloCard.rows[1].right._widget._enabled == false,
    "one-time copy must be disabled when no source profile exists")
pinnedSources.auraDisplays = "Default"
soloFixed.RefreshSources()
assert(soloFixed.pinButton._buttonText == "Unpin",
    "a remaining global pin must be removable with one profile")
assert(soloFixed.profilePinToggle._enabled == false,
    "a sole source profile must not expose an opt-out")
soloFixed.pinButton._onClick()
assert(pinnedSources.auraDisplays == nil)
for _, path in ipairs({
    "QUI_GroupFrames/groupframes/settings/group_frames_schema.lua",
    "modules/trackers/settings/aura_displays_content.lua",
}) do
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    assert(not source:find("profileCopy.HasSourceProfile()", 1, true),
        path .. " must not hide fixed global pin controls when only one profile exists")
end
headers = {}
cards = {}
Profiles.BuildSpecProfilesContent(NewFrame())
assert(#headers == 3 and headers[3] == "Spec Auto-Switch",
    "single-profile Profiles content must omit the feature-copy section")

print("OK options_profiles_dual_column_test")
