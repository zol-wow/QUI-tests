local env = dofile("tools/_addon_env.lua")
local secrets = {}
local isHarnessSecret = issecretvalue
_G.issecretvalue = function(value) return secrets[value] == true or isHarnessSecret(value) end
local function Secret()
    local value = setmetatable({}, {
        __concat = function() error("secret name must not be concatenated in Lua") end,
        __tostring = function() error("secret name must not be converted in Lua") end,
        __index = function() error("secret name must not be inspected in Lua") end,
    })
    secrets[value] = true
    return value
end
local names = {
    player = { "Tester", "Example" },
    party1 = { "Aria", "Moonwhisper" },
    raid1 = { "Borin", "Stonebeard" },
    party1target = { "Elara", "Dawnseeker" },
}
_G.UnitName = function(unit)
    local parts = names[unit] or {}
    return parts[1], parts[2]
end
_G.UnitExists = function(unit) return names[unit] ~= nil end
_G.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
local wraps = {}
_G.C_StringUtil = {
    WrapString = function(value, prefix, suffix)
        wraps[#wraps + 1] = { value = value, prefix = prefix, suffix = suffix }
        if issecretvalue(value) or issecretvalue(prefix) or issecretvalue(suffix) then
            return Secret()
        end
        if value == "" then return "" end
        return (prefix or "") .. value .. (suffix or "")
    end,
}
local ns = env.LoadCore()
ns.Client = { isForever = true }
local settings = {
    party = { showName = true, showLastName = true, maxNameLength = 0 },
    raid = { showName = true, showLastName = true, maxNameLength = 0 },
}
local function Read(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end
local source = Read("QUI_GroupFrames/groupframes/groupframes.lua")
local first = assert(source:find("local function UpdateName(frame)", 1, true))
local last = assert(source:find("local function UpdateAbsorbs(", first, true))
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn UpdateName"))
local gf = { GetFrameUnit = function(frame) return frame.unit end }
local context = setmetatable({
    QUI_GF = gf,
    Helpers = ns.Helpers,
    IsSecretValue = issecretvalue,
    GetNameSettings = function(isRaid) return isRaid and settings.raid or settings.party end,
    GetVisualDB = function() return {} end,
    Chrome = { AnchorBottomPadded = function() end },
    COLORS = { WHITE = { 1, 1, 1, 1 } },
}, { __index = _G })
setfenv(chunk, context)
local UpdateName = chunk()
local function NewFrame(unit, isRaid)
    return {
        unit = unit,
        _isRaid = isRaid,
        IsShown = function() return true end,
        nameText = {
            SetText = function(self, value) self.value = value end,
            SetTextColor = function() end,
        },
    }
end
local party = NewFrame("party1", false)
local raid = NewFrame("raid1", true)
UpdateName(party)
assert(party.nameText.value == "Aria Moonwhisper", "party frames must compose Forever first and last names")
UpdateName(raid)
assert(raid.nameText.value == "Borin Stonebeard", "raid frames must compose Forever first and last names")

local noop = function() end
context.UpdateName = UpdateName
context._state = { UpdateLevelText = noop }
for _, name in ipairs({
    "UpdateDarkModeVisuals", "UpdateHealth", "UpdatePower", "UpdateAbsorbs", "UpdateHealAbsorb",
    "UpdateHealPrediction", "UpdateRoleIcon", "UpdateReadyCheck", "UpdateResurrection", "UpdateSummonPending",
    "UpdateThreat", "UpdateTargetMarker", "UpdateLeaderIcon", "UpdatePhaseIcon", "UpdateConnection",
    "UpdateTargetHighlight", "UpdateDispelOverlay", "UpdatePortrait", "ApplyStatusBarTexture",
}) do context[name] = noop end
first = assert(source:find("local function UpdateFrame(frame)", 1, true))
last = assert(source:find("local function DecorateGroupFrame(", first, true))
chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn UpdateFrame"))
setfenv(chunk, context)
context.UpdateFrame = chunk()
context.ns = ns
first = assert(source:find("function QUI_GF:RefreshAllFrames(_reason)", 1, true))
last = assert(source:find("function QUI_GF:RefreshSettings()", first, true))
chunk = assert(loadstring(source:sub(first, last - 1)))
setfenv(chunk, context)
chunk()
gf.unitFrameMap = { party1 = { party }, raid1 = { raid } }
settings.party.showLastName = false
gf:RefreshAllFrames()
assert(party.nameText.value == "Aria" and raid.nameText.value == "Borin Stonebeard",
    "disabling party surnames must refresh visible frames without changing raid names")
settings.party.showLastName, settings.raid.showLastName = true, false
gf:RefreshAllFrames()
assert(party.nameText.value == "Aria Moonwhisper" and raid.nameText.value == "Borin",
    "raid surname preference must be independent of party preference on refresh")
settings.raid.showLastName = true
gf:RefreshAllFrames("roster")
assert(raid.nameText.value == "Borin Stonebeard", "roster refresh must also compose enabled surnames")

for _, frame in ipairs({ party, raid }) do
    local cfg = frame._isRaid and settings.raid or settings.party
    names[frame.unit] = { "Éla", "Lúnargent" }
    cfg.maxNameLength = 6
    UpdateName(frame)
    assert(frame.nameText.value == "Éla Lú", "group frame truncation must follow surname composition and count UTF-8 characters")
    cfg.maxNameLength = 0
    for _, parts in ipairs({ { "Boar" }, { "Boar", "" }, { "", "Surname" } }) do
        names[frame.unit] = parts
        UpdateName(frame)
        assert(frame.nameText.value == parts[1], "missing surname or empty first name must not leave a separator")
    end
    cfg.showName = false
    UpdateName(frame)
    assert(frame.nameText.value == "", "surname mode must respect hidden group names")
    cfg.showName = true
end

local targetSource = Read("QUI_GroupFrames/groupframes/groupframes_party_targets.lua")
first = assert(targetSource:find("local function RenderCompanion(frame)", 1, true))
last = assert(targetSource:find("local function Tick()", first, true))
chunk = assert(loadstring(targetSource:sub(first, last - 1) .. "\nreturn RenderCompanion"))
setfenv(chunk, setmetatable({
    Helpers = ns.Helpers,
    GetConfig = function() return {}, { name = settings.party } end,
    TruncateUTF8 = ns.Helpers.TruncateUTF8,
    UnitHealthPercent = function() return 100 end,
    UnitClass = function() return nil, nil end,
    CurveConstants = { ScaleTo100 = {} },
    FALLBACK_COLOR = { 0.6, 0.6, 0.6 },
}, { __index = _G }))
local RenderCompanion = chunk()
local companion = NewFrame("party1target", false)
companion.ptUnit = companion.unit
companion.healthBar = { SetValue = noop, SetStatusBarColor = noop }
RenderCompanion(companion)
assert(companion.nameText.value == "Elara Dawnse", "party target must inherit enabled party surnames with its existing 12-character cap")
settings.party.showLastName = false
RenderCompanion(companion)
assert(companion.nameText.value == "Elara", "party target must clear surnames when party preference is disabled")
settings.party.showLastName = true

for _, display in ipairs({
    { frame = party, render = UpdateName, cfg = settings.party },
    { frame = raid, render = UpdateName, cfg = settings.raid },
    { frame = companion, render = RenderCompanion, cfg = settings.party },
}) do
    local frame, render, cfg = display.frame, display.render, display.cfg
    cfg.maxNameLength = 6
    for _, parts in ipairs({ { Secret(), "Moonwhisper" }, { "Aria", Secret() }, { Secret(), Secret() } }) do
        names[frame.unit] = parts
        wraps = {}
        render(frame)
        assert(issecretvalue(frame.nameText.value), "group displays must preserve composed secret names through truncation")
        assert(#wraps == 2 and rawequal(wraps[1].value, parts[2]) and rawequal(wraps[2].value, parts[1]),
            "secret first and last names must reach native WrapString intact")
        cfg.showLastName = false
        wraps = {}
        render(frame)
        assert(rawequal(frame.nameText.value, parts[1]) and #wraps == 0,
            "disabled surname mode must preserve first names without calling WrapString")
        cfg.showLastName = true
    end
    ns.Client.isForever = false
    names[frame.unit] = { "Aria", "OtherRealm" }
    wraps = {}
    render(frame)
    assert(frame.nameText.value == "Aria" and #wraps == 0,
        "Retail group displays must not append the realm even with imported surname preferences")
    ns.Client.isForever = true
end

local defaults = ns.defaults.profile.quiGroupFrames
assert(defaults.party.name.showLastName == true and defaults.raid.name.showLastName == true,
    "party and raid surnames must both default to enabled")

assert(loadfile("QUI_GroupFrames/groupframes/settings/group_frames_preview_driver.lua"))("QUI", ns)
local previewSource = Read("QUI_GroupFrames/groupframes/settings/group_frames_preview_driver.lua")
first = assert(previewSource:find("local function ApplyTextContent(", 1, true))
last = assert(previewSource:find("local function FormatHealthText(", first, true))
chunk = assert(loadstring(previewSource:sub(first, last - 1) .. "\nreturn ApplyTextContent"))
setfenv(chunk, setmetatable({ ns = ns }, { __index = _G }))
local ApplyTextContent = chunk()
local preview = NewFrame("party1", false)
preview.nameText.Show, preview.nameText.Hide = noop, noop
local previewSettings = { showLastName = true, maxNameLength = 0 }
for _, mode in ipairs({ "party", "raid" }) do
    local member = ns.QUI_GroupFramesPreview._BuildRoster(mode, 1)[1]
    local originalName = member.name
    ApplyTextContent(preview, member, previewSettings)
    assert(preview.nameText.value == originalName .. " Stormwind",
        "options preview must show the enabled surname for synthetic party and raid members")
    assert(member.name == originalName, "preview surname display must preserve roster identity for filtering and sorting")
    previewSettings.maxNameLength = #originalName + 3
    ApplyTextContent(preview, member, previewSettings)
    assert(preview.nameText.value == originalName .. " St", "options preview must truncate after joining surnames")
    previewSettings.maxNameLength = 0
    previewSettings.showLastName = false
    ApplyTextContent(preview, member, previewSettings)
    assert(preview.nameText.value == originalName, "options preview must remove surnames when disabled")
    previewSettings.showLastName = true
    ns.Client.isForever = false
    ApplyTextContent(preview, member, previewSettings)
    assert(preview.nameText.value == originalName, "Retail options previews must preserve first names")
    ns.Client.isForever = true
end
ApplyTextContent(preview, { name = "Aria Moonwhisper" }, previewSettings)
assert(preview.nameText.value == "Aria Moonwhisper", "user-provided spotlight names must not receive a fabricated surname")

local editSource = Read("QUI_GroupFrames/groupframes/groupframes_editmode.lua")
first = assert(editSource:find("local displayName = name", 1, true))
last = assert(editSource:find("if nameSettings and nameSettings.nameTextUseClassColor then", first, true))
chunk = assert(loadstring(editSource:sub(first, last - 1)))
setfenv(chunk, setmetatable({
    ns = ns, name = "Tankthor", nameSettings = previewSettings, nameText = preview.nameText,
}, { __index = _G }))
chunk()
assert(preview.nameText.value == "Tankthor Stormwind", "Edit Mode preview must show enabled surnames")
previewSettings.maxNameLength = 10
chunk()
assert(preview.nameText.value == "Tankthor S", "Edit Mode preview must truncate the composed name")
previewSettings.maxNameLength, previewSettings.showLastName = 0, false
chunk()
assert(preview.nameText.value == "Tankthor", "Edit Mode preview must remove disabled surnames")
previewSettings.showLastName = true
ns.Client.isForever = false
chunk()
assert(preview.nameText.value == "Tankthor", "Retail Edit Mode previews must preserve first names")
print("PASS groupframes_surname_test")
