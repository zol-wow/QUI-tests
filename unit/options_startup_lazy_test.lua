local file = assert(io.open("init.lua", "r"))
local source = file:read("*a")
file:close()

local queued = {}
local loads, initialized, toggles, shows, wizardShows = 0, 0, 0, 0, 0
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    RunAfterFirstFrame = function(callback, delay)
        queued[#queued + 1] = { callback = callback, delay = delay }
    end,
    QUI_SetupWizard = { Show = function() wizardShows = wizardShows + 1 end },
}

QUI = {
    QUICore = {},
    db = { global = { setupWizard = { completedAt = 123 } } },
    BackwardsCompat = function() end,
    RegisterEvent = function() end,
    RegisterOptionalPullAlias = function() end,
    EnsureOptionsLoaded = function(self)
        loads = loads + 1
        self.GUI = {
            InitializeOptions = function() initialized = initialized + 1 end,
            Toggle = function() toggles = toggles + 1 end,
            Show = function() shows = shows + 1 end,
        }
        return true
    end,
}

for _, name in ipairs({ "OnEnable", "OpenOptions", "ShowOptions" }) do
    local first = assert(source:find("function QUI:" .. name .. "()", 1, true))
    local last = assert(source:find("\nend", first, true))
    assert((loadstring or load)("local ns = ...\n" .. source:sub(first, last + 3), "@init.lua:" .. name))(ns)
end

local function flush()
    local pending = queued
    queued = {}
    for _, item in ipairs(pending) do item.callback() end
end

QUI:OnEnable()
flush()
assert(loads == 0 and initialized == 0,
    "an established profile must not load or construct options after the first frame")

assert(QUI:OpenOptions(), "the normal options action must remain available")
assert(loads == 1 and toggles == 1, "opening options must load the companion before toggling it")
assert(QUI:ShowOptions(), "the explicit show action must remain available")
assert(loads == 2 and shows == 1, "showing options must load the companion before showing it")

ns._freshInstall = true
QUI.db.global.setupWizard.completedAt = false
QUI:OnEnable()
assert(#queued == 1 and queued[1].delay == 2, "fresh installs must retain the delayed setup wizard")
flush()
assert(loads == 3 and wizardShows == 1, "fresh installs must load options and show the setup wizard")
assert(initialized == 0, "showing the setup wizard must not prebuild the main options window")

QUI:OnEnable()
QUI.db.global.setupWizard.completedAt = 456
flush()
assert(loads == 3 and wizardShows == 1, "a completed wizard must not reopen when its timer fires")

print("OK: options_startup_lazy_test")
