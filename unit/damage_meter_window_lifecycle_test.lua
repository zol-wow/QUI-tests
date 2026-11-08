local env = dofile("tools/_addon_env.lua")
local h = env.BuildHarness({ noSeed = true })
local AceDB = LibStub("AceDB-3.0")
local file = assert(io.open("QUI_DamageMeter/damage_meter/damage_meter.lua", "rb"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local WindowManager = {", 1, true))
local last = assert(source:find("local function ResetAllDamageMeterSessions", first, true))
local runtime = setmetatable({
    QUI_DamageMeter = { BumpAppearanceRevision = function() end },
    ns = { Helpers = { GetCore = function() return h.QUICore end } },
    LayoutKey = function(id) return "damageMeter_window_" .. id end,
    GetSettings = function() return h.db.profile.damageMeter.native end,
    Window = { New = function(id)
        return {
            windowID = id,
            initialAnchor = h.ns.Helpers.DeepCopy(h.db.profile.frameAnchoring["damageMeter_window_" .. id]),
        }
    end },
}, { __index = _G })
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn WindowManager"))
setfenv(chunk, runtime)
local manager = chunk()
local failures = {}
local function check(ok, message)
    if not ok then failures[#failures + 1] = message end
end
local function fresh()
    manager:DespawnAll()
    env.ApplySeed({})
    h = env.BuildHarness({ noSeed = true })
    manager:LoadSavedWindows()
end
local function reload()
    manager:DespawnAll()
    h.db:RegisterDefaults(nil)
    local saved = h.ns.Helpers.DeepCopy(h.db.sv)
    h.db = AceDB:New(saved, h.defaults, "Default")
    h.QUICore.db, h.QUI.db = h.db, h.db
    manager:LoadSavedWindows()
end

fresh()
check(manager:Count() == 1, "an untouched profile must still start with one window")
manager:DeleteWindow(1)
reload()
check(manager:Count() == 0, "reload must not resurrect the last deleted window")
check(next(h.db.profile.damageMeter.native.windows) == nil,
    "the settings list must remain empty after deleting every window and reloading")
reload()
check(manager:Count() == 0, "a second reload must preserve an intentionally empty window list")

fresh()
local second = manager:SpawnNew()
h.db.profile.damageMeter.native.windows[second].name = "Keep me"
manager:DeleteWindow(1)
reload()
check(manager:Count() == 1 and manager:Get(second) ~= nil,
    "deleting the default window must keep only the other saved window after reload")
check(h.db.profile.damageMeter.native.windows[second].name == "Keep me",
    "removing the default window must preserve another window's custom settings")

fresh()
local ids = { 1, manager:SpawnNew(), manager:SpawnNew() }
for _, id in ipairs(ids) do manager:DeleteWindow(id) end
local added = manager:SpawnNew()
check(manager:Count() == 1, "adding once after deleting all windows must create exactly one window")
reload()
check(manager:Count() == 1 and manager:Get(added) ~= nil,
    "delete all, add one, reload must keep exactly the added window")
reload()
check(manager:Count() == 1, "repeated reload must not duplicate the replacement window")
for _ = 1, 4 do check(manager:SpawnNew() ~= nil, "five windows must still be supported") end
check(manager:SpawnNew() == nil and manager:Count() == 5, "the five-window limit must still hold")

fresh()
local anchoring = h.db.profile.frameAnchoring
local unrelated = { parent = "screen", offsetX = 123 }
anchoring.unrelated = unrelated
local oldAnchor = {
    parent = "screen", point = "CENTER", relative = "CENTER", offsetX = 100000, offsetY = 100000,
}
anchoring.damageMeter_window_1 = h.ns.Helpers.DeepCopy(oldAnchor)
anchoring.damageMeter_window_2 = h.ns.Helpers.DeepCopy(oldAnchor)
manager:DeleteWindow(1)
for _ = 1, 2 do
    local id = manager:SpawnNew()
    local anchor = manager:Get(id).initialAnchor
    check(anchor.parent == "screen" and anchor.point == "CENTER" and anchor.relative == "CENTER"
        and math.abs(anchor.offsetX) < 200 and math.abs(anchor.offsetY) < 200,
        "a new window must get an onscreen center anchor instead of inheriting a deleted window's offscreen position")
end
check(anchoring.unrelated == unrelated and unrelated.offsetX == 123,
    "creating a damage window must preserve other frames' saved anchors")

assert(#failures == 0, table.concat(failures, "\n"))
print("OK damage_meter_window_lifecycle_test")
