local function noop() end
local function frame(parent)
    local value = { parent = parent, shown = true, scripts = {}, events = {} }
    function value:GetParent() return self.parent end
    function value:SetParent(target) self.parent = target end
    function value:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function value:IsShown() return self.shown end
    function value:Show()
        if not self.shown then
            self.shown = true
            if self.scripts.OnShow then self.scripts.OnShow(self) end
        end
    end
    function value:Hide()
        if self.shown then
            self.shown = false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
    end
    function value:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function value:EnableMouse() end
    function value:ClearAllPoints() end
    function value:SetPoint() end
    function value:Layout() end
    function value:RegisterEvent(event) self.events[event] = true end
    function value:UnregisterEvent(event) self.events[event] = nil end
    function value:SetScript(script, callback) self.scripts[script] = callback end
    return value
end

local state = { timers = {}, layouts = {}, combat = false, setting = 1 }
local env = setmetatable({}, { __index = _G })
env._G = env
env.SetChunkEnv = function(level, target) setfenv(level + 1, target) end
env.InCombatLockdown = function() return state.combat end
env.CreateFrame = function() return frame() end
env.UIParent = frame()
env.MicroMenuContainer = frame(env.UIParent)
env.MicroMenu = frame(env.UIParent)
env.CharacterMicroButton = frame(env.MicroMenu)
env.StoreMicroButton = frame(env.MicroMenu)
env.StoreMicroButton.UpdateMicroButton = function(self) self:Show() end
env.MainMenuMicroButton = { IsEnabled = function() return false end }
env.MICRO_BUTTONS_DISABLED = true
local file = assert(io.open("tests/framexml/Interface/AddOns/Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua"))
local source = file:read("*a")
file:close()
local start = assert(source:find("function UpdateMicroButtons()", 1, true))
local finish = assert(source:find("function MicroButtonPulse", start, true))
local native = assert(loadstring(source:sub(start, finish - 1)))
setfenv(native, env)
native()
env.MainMenuBarMicroButtonMixin = {}
for _, method in ipairs({ "OnShow", "OnHide" }) do
    local first = assert(source:find("function MainMenuBarMicroButtonMixin:" .. method .. "()", 1, true))
    local last = assert(source:find("\nend", first, true))
    local chunk = assert(loadstring(source:sub(first, last + 3)))
    setfenv(chunk, env)
    chunk()
    env.CharacterMicroButton:SetScript(method, env.MainMenuBarMicroButtonMixin[method])
end
env.hooksecurefunc = function(target, name, callback)
    if type(target) == "string" then target, name, callback = env, target, name end
    local original = target[name]
    target[name] = function(...)
        original(...)
        callback(...)
    end
end
env.C_Timer = { After = function(delay, callback)
    assert(delay == 0, "micro layout must retain next-frame scheduling")
    state.timers[#state.timers + 1] = callback
end }
local container = frame(env.UIParent)
env.ActionBarsOwned = { initialized = true, containers = { microbar = container }, nativeButtons = {} }
env.GetBarFrame = function() return env.MicroMenuContainer end
env.GetBarButtons = function() return { env.CharacterMicroButton, env.StoreMicroButton } end
env.GetEffectiveSettings, env.GetBarSettings = function() return {} end, function() return {} end
env.HideManagedBlizzardBarFrame, env.SetupOwnedBarMouseover, env.RestoreContainerPosition = noop, noop, noop
env.SKINNABLE_BAR_KEYS = {}
env.LayoutNativeButtons = function(key)
    assert(key == "microbar" and not state.combat, "layout must remain outside combat")
    if state.layoutError then error(state.layoutError) end
    assert(not state.layoutRunning, "native visibility hooks must not recurse into layout")
    state.layoutRunning = true
    state.layouts[#state.layouts + 1] = state.setting
    env.CharacterMicroButton:SetShown(not state.hideCharacter)
    state.layoutRunning = false
end
local ns = { ActionBarsEnv = env, Addon = frame() }
ns.Addon.RegisterEvent = function(self, event, callback) self.events[event] = callback end
assert(loadfile("QUI_ActionBars/actionbars/actionbars_builder.lua"))("QUI_ActionBars", ns)
env.BuildBar("microbar")
state.layouts, state.timers = {}, {}

local function drain()
    local timers = state.timers
    state.timers = {}
    for _, callback in ipairs(timers) do callback() end
end

for _ = 1, 10 do env.UpdateMicroButtons() end
assert(#state.layouts == 0 and #state.timers == 1,
    "nested Store and UpdateMicroButtons hooks must coalesce into one next-frame layout")
state.setting = 2
drain()
assert(#state.layouts == 1 and state.layouts[1] == 2,
    "the queued layout must apply current settings once")

env.CharacterMicroButton:SetParent(env.MicroMenu)
env.UpdateMicroButtons()
assert(env.CharacterMicroButton:GetParent() == container,
    "ownership must be reclaimed synchronously before the queued layout")
assert(#state.timers == 1, "a later independent update must queue another layout")
drain()
assert(#state.layouts == 2)

env.UpdateMicroButtons()
state.combat = true
drain()
assert(#state.layouts == 2, "entering combat before execution must prevent layout")
local combatFrame = assert(env.ActionBarsOwned._microLayoutFrame)
assert(combatFrame.events.PLAYER_REGEN_ENABLED, "combat must retain deferred layout registration")
state.combat = false
combatFrame.scripts.OnEvent(combatFrame, "PLAYER_REGEN_ENABLED")
assert(#state.layouts == 3 and not combatFrame.events.PLAYER_REGEN_ENABLED,
    "combat exit must consume and apply the pending layout")

env.UpdateMicroButtons()
env.MicroMenu:SetParent(frame())
drain()
assert(#state.layouts == 3 and env.ActionBarsOwned._microOwnedByUI,
    "a queued layout must yield if another UI takes ownership before execution")
env.MicroMenu:SetParent(env.UIParent)
assert(env.CharacterMicroButton:GetParent() == container,
    "returning from another UI must reclaim ownership immediately")
drain()
assert(#state.layouts == 4, "returning ownership must permit a fresh layout")

state.combat = true
env.UpdateMicroButtons()
env.UpdateMicroButtons()
assert(#state.timers == 0 and combatFrame.events.PLAYER_REGEN_ENABLED,
    "updates during combat must retain the existing event-based deferral")
state.combat = false
combatFrame.scripts.OnEvent(combatFrame, "PLAYER_REGEN_ENABLED")
assert(#state.layouts == 5)

state.hideCharacter = true
env.UpdateMicroButtons()
drain()
assert(#state.layouts == 6 and #state.timers == 1,
    "a native visibility transition may queue one followup but must not recurse synchronously")
drain()
assert(#state.layouts == 7 and #state.timers == 0,
    "the visibility reconciliation must quiesce when shown state is unchanged")

local failure = {}
state.layoutError = failure
env.UpdateMicroButtons()
local ok, err = pcall(drain)
assert(not ok and err == failure, "layout errors must still propagate")
state.layoutError = nil
env.UpdateMicroButtons()
assert(#state.timers == 1, "a failed layout must not poison future scheduling")
drain()
assert(#state.layouts == 8)

state.combat = true
env.CharacterMicroButton:SetParent(env.MicroMenu)
env.UpdateMicroButtons()
assert(env.CharacterMicroButton:GetParent() == env.MicroMenu and #state.timers == 0,
    "reparenting must remain deferred while combat prevents ownership changes")
local reclaim = assert(ns.Addon.events.PLAYER_REGEN_ENABLED)
state.combat = false
reclaim()
assert(env.CharacterMicroButton:GetParent() == container and #state.timers == 1,
    "combat exit must reclaim ownership before queueing its layout")
drain()
assert(#state.layouts == 9 and not ns.Addon.events.PLAYER_REGEN_ENABLED)
print("OK: actionbars_micro_layout_coalesce_test")
