local file = assert(io.open("QUI_DamageMeter/damage_meter/damage_meter.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()

local function extract(first, last)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start, true)) - 1)
end

local SecretSentinel = dofile("tests/helpers/secret_sentinel.lua")
local Instrument = dofile("tests/helpers/secret_instrument.lua")
local previousSecretStub = SecretSentinel.InstallSecretStub()
local secret = SecretSentinel.MakeSecretSentinel()
local environment = setmetatable({
    QUI_DamageMeter = {},
    Helpers = { IsSecretValue = issecretvalue },
    Enum = { DamageMeterType = { HealingDone = 2, Absorbs = 8 } },
}, { __index = _G })
local loader = assert(Instrument.loadString(table.concat({
    extract("local function SortByDescSafe", "local Data = {}"),
    extract("local function SessionKey", "function Data:ClearSourceGUIDCache"),
    "local Data = { _combinedHealingViews = {} }",
    extract("local function CanCombineHealingView", "function Data:GetCombinedHealingBreakdown"),
    "return Data",
}, "\n"), "damage_meter_restricted_healing"))
setfenv(loader, environment)
local Data = loader()
local healing, absorbs
local generation = 0
function Data:GetView(_, meterType)
    return meterType == 2 and healing or absorbs
end

local function reset()
    generation = generation + 2
    healing = {
        generation = generation, duration = 10, maxAmount = 100, totalAmount = 100,
        sources = {
            { name = "Healer", sourceGUID = "Player-One", totalAmount = 100, amountPerSecond = 10 },
        },
    }
    absorbs = {
        generation = generation + 1, duration = 10, maxAmount = 50, totalAmount = 50,
        sources = {
            { name = "Healer", sourceGUID = "Player-One", totalAmount = 50, amountPerSecond = 5 },
        },
    }
end

local function assertNative(message)
    local view = Data:GetCombinedHealingView(1)
    assert(rawequal(view, healing), message)
    assert(rawequal(view.sources, healing.sources), "fallback must preserve native rows")
    assert(rawequal(Data:GetCombinedHealingView(1), healing), "repeated restricted reads must stay native")
end

reset()
local combined = Data:GetCombinedHealingView(1)
assert(#combined.sources == 1 and combined.sources[1].totalAmount == 150
    and combined.sources[1].amountPerSecond == 15, "readable healing and absorbs must still merge")
assert(combined.maxAmount == 150 and combined.totalAmount == 150, "readable combined totals must agree")
assert(healing.sources[1].totalAmount == 100, "merging must not modify native healing")

for _, side in ipairs({ "healing", "absorbs" }) do
    for _, field in ipairs({ "sourceGUID", "totalAmount", "amountPerSecond" }) do
        reset()
        local view = side == "healing" and healing or absorbs
        view.sources[1][field] = secret
        assertNative(side .. " secret " .. field .. " must preserve native healing without duplicates")
    end
    reset()
    local view = side == "healing" and healing or absorbs
    view.totalAmount = secret
    assertNative(side .. " secret session total must not become a partial or zero combined total")
    for _, field in ipairs({ "sourceGUID", "totalAmount", "amountPerSecond" }) do
        reset()
        view = side == "healing" and healing or absorbs
        view.sources[1][field] = nil
        assertNative(side .. " missing " .. field .. " cannot be reliably merged")
    end
end

reset()
healing.sources[1].name = secret
absorbs.sources[1].name = secret
combined = Data:GetCombinedHealingView(1)
assert(#combined.sources == 1 and combined.totalAmount == 150,
    "display-only secret names must not prevent merging readable identities and amounts")
assert(rawequal(combined.sources[1].name, secret), "secret display name must pass through unchanged")

reset()
absorbs.sources[1].sourceGUID = "Player-Two"
combined = Data:GetCombinedHealingView(1)
assert(#combined.sources == 2, "different readable players must retain separate rows")

reset()
healing.totalAmount, healing.maxAmount = secret, secret
healing.sources[1].totalAmount, healing.sources[1].amountPerSecond = secret, secret
absorbs.sources = {}
assertNative("empty absorbs must preserve native secret healing data")

reset()
combined = Data:GetCombinedHealingView(1)
assert(#combined.sources == 1 and combined.totalAmount == 150,
    "readable data after restriction must resume combined healing")

local refreshEnvironment = setmetatable({
    Window = {},
    GetSettings = function() return { combineAbsorbsIntoHealing = true } end,
    Perf = { enabled = false },
    QUI_DamageMeter = {},
    ShouldReapplyAppearance = function() return false end,
    IsHealingType = function() return true end,
    Data = Data,
}, { __index = _G })
local refreshLoader = assert(loadstring(extract("function Window:Refresh()",
    "    local d = view.duration") .. "\nself._renderSources = view.sources\nend\nreturn Window.Refresh"))
setfenv(refreshLoader, refreshEnvironment)
local Refresh = refreshLoader()
local window = {
    frame = { IsShown = function() return true end },
    sessionType = 1,
    damageMeterType = 2,
    _lastGeneration = -1,
    _BindVisibleRows = function() end,
}
reset()
healing.generation = generation + 1
absorbs.generation = generation
Refresh(window)
assert(window._renderSources[1].totalAmount == 150, "readable window must render combined healing")
absorbs.generation = generation + 2
absorbs.sources[1].sourceGUID = secret
Refresh(window)
assert(rawequal(window._renderSources, healing.sources),
    "an absorbs-only restriction must replace combined rows even when native healing has the displayed generation")

local validationCount = 0
environment.Helpers.IsSecretValue = function(value)
    validationCount = validationCount + 1
    return issecretvalue(value)
end
for _, restricted in ipairs({ false, true }) do
    for _, side in ipairs({ "healing", "absorbs" }) do
        reset()
        if restricted then absorbs.sources[1].sourceGUID = secret end
        validationCount = 0
        local first = Data:GetCombinedHealingView(1)
        local initialCount = validationCount
        assert(initialCount > 0, "a new generation pair must validate source values")
        assert(rawequal(Data:GetCombinedHealingView(1), first), "unchanged generations must reuse their view")
        assert(validationCount == initialCount,
            (restricted and "native fallback" or "combined healing") .. " cache hits must skip repeated validation")
        local view = side == "healing" and healing or absorbs
        view.generation = view.generation + 1
        Data:GetCombinedHealingView(1)
        assert(validationCount > initialCount, side .. " generation changes must revalidate source values")
    end
end
SecretSentinel.RestoreSecretStub(previousSecretStub)
print("OK: damage_meter_restricted_healing_test")
