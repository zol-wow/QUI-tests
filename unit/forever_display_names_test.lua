local env = dofile("tools/_addon_env.lua")
local secrets = {}
local isHarnessSecret = issecretvalue
_G.issecretvalue = function(value) return secrets[value] == true or isHarnessSecret(value) end
local function Secret()
    local secret = setmetatable({}, {
        __concat = function() error("secret name must not be concatenated in Lua") end,
        __tostring = function() error("secret name must not be converted in Lua") end,
        __index = function() error("secret name must not be inspected in Lua") end,
    })
    secrets[secret] = true
    return secret
end
local names = {
    player = { "Tester", "Example" },
    target = { "Aria", "Moonwhisper" },
    targettarget = { "Borin", "Stonebeard" },
    boss1 = { "Ragnaros" },
    boss1target = { "Borin", "Stonebeard" },
}
_G.UnitName = function(unit)
    local parts = names[unit] or {}
    return parts[1], parts[2]
end
_G.UnitExists = function(unit) return names[unit] ~= nil end
_G.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
local wraps = {}
_G.C_StringUtil = {
    WrapString = function(text, prefix, suffix)
        wraps[#wraps + 1] = { text = text, prefix = prefix, suffix = suffix }
        if issecretvalue(text) or issecretvalue(prefix) or issecretvalue(suffix) then
            return Secret()
        end
        if text == "" then return "" end
        return (prefix or "") .. text .. (suffix or "")
    end,
}
local ns = env.LoadCore()
ns.Client = { isForever = true }
local Helpers = ns.Helpers
local npSettings = { name = { showLastName = false, classColorPlayers = false } }
local NP = { GetTypeSettings = function() return npSettings end }
ns.QUI_Nameplates = NP
assert(loadfile("QUI_Nameplates/nameplates/plate_health.lua"))("QUI", ns)

local function NewText()
    return {
        SetText = function(self, value) self.value = value end,
        SetTextColor = function() end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
end

local plate = { unit = "target", nameText = NewText(), npNameTruncate = 40 }
NP.Health.UpdateName(plate)
assert(plate.nameText.value == "Aria", "nameplate toggle off must preserve the first name")
npSettings.name.showLastName = true
NP.Health.UpdateName(plate)
assert(plate.nameText.value == "Aria Moonwhisper", "nameplate toggle on must display the Forever surname")
npSettings.name.showLastName = false
NP.Health.UpdateName(plate)
assert(plate.nameText.value == "Aria", "disabling surnames must clear the previously rendered surname")

local function Read(path)
    local file = assert(io.open(path, "r"))
    local value = file:read("*a")
    file:close()
    return value
end

local previewSource = Read("QUI_UnitFrames/unitframes/settings/unit_frames_surface.lua")
local previewStart = assert(previewSource:find("local rawName", 1, true))
local previewStop = assert(previewSource:find("local masterOn", previewStart, true))
local preview = { _nameText = NewText() }
local previewSettings = { showLastName = false, maxNameLength = 0 }
local previewChunk = assert(loadstring(previewSource:sub(previewStart, previewStop - 1)))
setfenv(previewChunk, setmetatable({
    ns = ns,
    State = { selectedUnit = "player" },
    unitDB = previewSettings,
    mock = preview,
    TruncateName = Helpers.TruncateUTF8,
}, { __index = _G }))
previewChunk()
assert(preview._nameText.value == "Tester", "player preview must preserve first-name mode")
previewSettings.showLastName = true
previewChunk()
assert(preview._nameText.value == "Tester Example", "player preview must show the enabled surname")
previewSettings.showLastName = false
previewChunk()
assert(preview._nameText.value == "Tester", "player preview must refresh when surnames are disabled")

local source = Read("QUI_UnitFrames/unitframes/unitframes.lua")
local layoutStart = assert(source:find("local names = {", source:find("function QUI_UF:ShowPreview", 1, true), true))
local layoutStop = assert(source:find("\n    if frame.levelText then", layoutStart, true))
local layoutFrame = { nameText = NewText() }
local layoutSettings = { showLastName = true }
local layoutChunk = assert(loadstring("if true then\n" .. source:sub(layoutStart, layoutStop - 1)))
setfenv(layoutChunk, setmetatable({
    ns = ns,
    Helpers = Helpers,
    SafeValue = Helpers.SafeValue,
    GetNameSettings = function(value) return value end,
    settings = layoutSettings,
    frame = layoutFrame,
    unitKey = "player",
}, { __index = _G }))
layoutChunk()
assert(layoutFrame.nameText.value == "Tester Example", "Layout Mode player preview must include the enabled surname")
layoutSettings.showLastName = false
layoutChunk()
assert(layoutFrame.nameText.value == "Tester", "Layout Mode must preserve first-name mode")
local start = assert(source:find("local function UpdateName(frame)", 1, true))
local stop = assert(source:find("local function UpdateLevelText(frame)", start, true))
local settings = { showName = true, showLastName = false, maxNameLength = 0 }
local chunk = assert(loadstring(source:sub(start, stop - 1) .. "\nreturn UpdateName"))
setfenv(chunk, setmetatable({
    ns = ns,
    Helpers = Helpers,
    QUI_UF = { GetFrameUnit = function(frame) return frame.unit end },
    GetUnitSettings = function() return settings end,
    GetNameSettings = function(value) return value end,
    GetGeneralSettings = function() return {} end,
    IsSecretValue = Helpers.IsSecretValue,
    TruncateName = Helpers.TruncateUTF8,
    string_format = string.format,
}, { __index = _G }))
local UpdateName = chunk()
local frame = { unit = "target", unitKey = "target", nameText = NewText() }
UpdateName(frame)
assert(frame.nameText.value == "Aria", "unit frame toggle off must preserve the first name")
settings.showLastName = true
UpdateName(frame)
assert(frame.nameText.value == "Aria Moonwhisper", "unit frame toggle on must display the Forever surname")
settings.showInlineToT = true
UpdateName(frame)
assert(frame.nameText.value == "Aria Moonwhisper|cFFFFFFFF >> |rBorin Stonebeard",
    "target inline target-of-target must use the same surname setting")
frame.unit, frame.unitKey = "boss1", "boss"
UpdateName(frame)
assert(frame.nameText.value == "Ragnaros|cFFFFFFFF >> |rBorin Stonebeard",
    "boss inline target must include its surname while the NPC retains its name")
settings.showLastName = false
UpdateName(frame)
assert(frame.nameText.value == "Ragnaros|cFFFFFFFF >> |rBorin",
    "disabling surnames must also refresh the boss inline target")
settings.showInlineToT = false
frame.unit, frame.unitKey = "target", "target"
settings.showLastName = true
npSettings.name.showLastName = true

names.target = { "Éla", "Lúnargent" }
settings.maxNameLength, plate.npNameTruncate = 6, 6
UpdateName(frame)
NP.Health.UpdateName(plate)
assert(frame.nameText.value == "Éla Lú" and plate.nameText.value == "Éla Lú",
    "both displays must truncate the joined name by UTF-8 characters")
settings.maxNameLength, plate.npNameTruncate = 0, 40

for _, parts in ipairs({ { "Boar" }, { "Boar", "" }, { "", "Surname" }, {} }) do
    names.target = parts
    UpdateName(frame)
    NP.Health.UpdateName(plate)
    assert(frame.nameText.value == (parts[1] or "") and plate.nameText.value == (parts[1] or ""),
        "missing or empty surname must not add a separator or lose an NPC name")
end

ns.Client.isForever = false
names.target = { "Aria", "OtherRealm" }
UpdateName(frame)
NP.Health.UpdateName(plate)
assert(frame.nameText.value == "Aria" and plate.nameText.value == "Aria",
    "Retail must not display the realm as a surname even with imported toggles enabled")
ns.Client.isForever = true

for _, parts in ipairs({
    { Secret(), "Moonwhisper" },
    { "Aria", Secret() },
    { Secret(), Secret() },
}) do
    names.target = parts
    wraps = {}
    UpdateName(frame)
    assert(issecretvalue(frame.nameText.value), "unit frame must pass the formatted secret name to SetText")
    assert(#wraps == 2 and rawequal(wraps[1].text, parts[2]) and rawequal(wraps[2].text, parts[1]),
        "secret name parts must reach native WrapString without being discarded")
    wraps = {}
    NP.Health.UpdateName(plate)
    assert(issecretvalue(plate.nameText.value), "nameplate must pass the formatted secret name to SetText")
    assert(#wraps == 2, "nameplate must format both secret name parts through native WrapString")
    settings.showLastName, npSettings.name.showLastName = false, false
    wraps = {}
    UpdateName(frame)
    NP.Health.UpdateName(plate)
    assert(rawequal(frame.nameText.value, parts[1]) and rawequal(plate.nameText.value, parts[1]) and #wraps == 0,
        "first-name mode must pass secret names through without formatting")
    settings.showLastName, npSettings.name.showLastName = true, true
end

print("OK: forever_display_names_test")
