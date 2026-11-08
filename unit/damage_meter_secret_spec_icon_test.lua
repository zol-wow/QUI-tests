local file = assert(io.open("QUI_DamageMeter/damage_meter/damage_meter.lua", "rb"))
local source = file:read("*a")
file:close()
local Sentinel = dofile("tests/helpers/secret_sentinel.lua")
local Instrument = dofile("tests/helpers/secret_instrument.lua")
local restore = Sentinel.InstallSecretStub()
local secretIcon = Sentinel.MakeSecretSentinel()
local isSecret = _G.issecretvalue
local function noop() end
local iconStyle = "spec"
local env = setmetatable({
    Window = {},
    Breakdown = {},
    Data = {},
    IsSecretValue = isSecret,
    type = function(value)
        if isSecret(value) then return "number" end
        return type(value)
    end,
    Helpers = { IsSecretValue = isSecret, ApplyBarStyle = noop },
    ApplyRowBackgroundVisibility = noop,
    ResolveAppearance = function(_, key)
        if key == "iconStyle" then return iconStyle end
    end,
    ResolveBarTexture = function() return "bar" end,
    ShortenName = function(value) return value end,
    IsPerSecondType = function() return false end,
    BuildValueText = function() return "100" end,
    ComputeBarFill = function() return 0, 100, 50 end,
    SetRowBarColor = noop,
    CLASS_ICON_TCOORDS = { MAGE = { 0, 0.25, 0, 0.25 } },
    FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark",
}, { __index = _G })
local function loadMethod(first, following)
    local startAt = assert(source:find(first, 1, true))
    local endAt = assert(source:find(following, startAt, true))
    local chunk = assert(Instrument.loadString(source:sub(startAt, endAt - 1), first))
    setfenv(chunk, env)
    chunk()
end
loadMethod("function Data:_CacheSourceGUIDs", "\nfunction Data:ResolveSourceSelector")
loadMethod("function Window:_SetRowSource", "\nfunction Window:_ApplyHeader")
loadMethod("function Breakdown:_SetTargetRow", "\nfunction Breakdown:_UpdateTitle")

local function newRow()
    return {
        Icon = {
            SetTexture = function(self, texture) self.texture = texture end,
            SetTexCoord = function(self, ...) self.coords = { ... } end,
        },
        Name = { SetText = noop, SetTextColor = noop },
        Value = { SetText = noop },
        Bar = { SetMinMaxValues = noop, SetValue = noop },
    }
end
local classTexture = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local failures = {}
local function check(name, run)
    local ok, err = pcall(run)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
end

check("source row secret icon and readable fallbacks", function()
    local window = setmetatable({ windowID = 1, damageMeterType = 0 }, { __index = env.Window })
    local row = newRow()
    for _, case in ipairs({
        { icon = secretIcon, expected = secretIcon },
        { icon = 123, expected = 123 },
        { icon = 0, class = "MAGE", expected = classTexture },
        { class = "MAGE", expected = classTexture },
        { expected = env.FALLBACK_ICON },
    }) do
        local data = { specIconID = case.icon, classFilename = case.class, name = "Player", rank = 1 }
        window:_SetRowSource(row, data, 100)
        assert(rawequal(row.Icon.texture, case.expected), "source icon must preserve secret identity and readable fallbacks")
        assert(row._source == data, "reused row must retain its current source")
    end
    iconStyle = "class"
    window:_SetRowSource(row, { specIconID = secretIcon, classFilename = "MAGE" }, 100)
    assert(row.Icon.texture == classTexture, "class style must retain the class atlas with a secret spec icon")
    iconStyle = "none"
    window:_SetRowSource(row, { specIconID = secretIcon }, 100)
    assert(row.Icon.texture == nil, "disabled icons must clear a reused row")
    iconStyle = "spec"
end)

check("target row secret icon and readable fallbacks", function()
    local breakdown = setmetatable({ parentWindowID = 1, parentWindow = { damageMeterType = 0 } },
        { __index = env.Breakdown })
    local row = newRow()
    for _, case in ipairs({
        { icon = secretIcon, expected = secretIcon },
        { icon = 456, expected = 456 },
        { icon = 0, class = "MAGE", expected = classTexture },
        { class = "MAGE", expected = classTexture },
        {},
    }) do
        local data = { specIconID = case.icon, classFilename = case.class, name = "Target" }
        breakdown:_SetTargetRow(row, data, 100)
        assert(rawequal(row.Icon.texture, case.expected), "target icon must preserve secret identity and clear missing icons")
        assert(row._target == data, "reused row must retain its current target")
    end
end)

check("source GUID cache excludes secret icons", function()
    local data = setmetatable({ _sourceGUIDBySelector = {}, _inCombat = false }, { __index = env.Data })
    data:_CacheSourceGUIDs("type:1", {
        { specIconID = secretIcon, sourceGUID = "Player-Secret" },
        { specIconID = 101, sourceGUID = "Player-One" },
        { specIconID = 0, sourceGUID = "Player-Zero" },
        { sourceGUID = "Player-Missing" },
    })
    local cached = data._sourceGUIDBySelector["type:1"]
    assert(cached[secretIcon] == nil, "secret icons must not become identity cache keys even outside combat")
    assert(cached[101] == "Player-One" and cached[0] == nil, "readable positive icons must retain their GUID lookup")
    data:_CacheSourceGUIDs("type:1", { { specIconID = 101, sourceGUID = "Player-Other" } })
    assert(cached[101] == false, "duplicate readable spec icons must remain ambiguous")
end)

Sentinel.RestoreSecretStub(restore)
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: damage_meter_secret_spec_icon_test")
