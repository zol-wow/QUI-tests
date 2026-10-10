local function noop() end
local hooks = {}
local settings = { showTooltips = false }
local button, otherButton = {}, {}
local owned = {
    useNativeButtons = true, skinnedButtons = { [button] = true },
    containers = {}, editOverlays = {},
}
local env = setmetatable({
    ActionBarsOwned = owned,
    LINKED_OWNED_BAR_KEYS = {}, ALL_MANAGED_BAR_KEYS = {},
    UIParent = {},
    GetDB = function() return {} end,
    GetGlobalSettings = function() return settings end,
    GetCore = noop,
    InCombatLockdown = function() return false end,
    InvalidateEffectiveSettingsCache = noop,
    ApplyAllFlyoutDirections = noop,
    BuildBar = noop,
    C_Timer = { After = noop },
    CreateFrame = function()
        return {
            RegisterEvent = noop,
            SetScript = function(self, event, callback) self[event] = callback end,
        }
    end,
    hooksecurefunc = function(name, callback)
        assert(name == "GameTooltip_SetDefaultAnchor", "test expects only tooltip hooks")
        hooks[#hooks + 1] = callback
    end,
    SetChunkEnv = function(level, scope) setfenv(level + 1, scope) end,
}, { __index = _G })
env._G = env
local ns = { ActionBarsEnv = env }
for _, name in ipairs({ "actionbars_native.lua", "actionbars_public.lua" }) do
    local chunk = assert(loadfile("QUI_ActionBars/actionbars/" .. name))
    setfenv(chunk, env)
    chunk("QUI_ActionBars", ns)
end
env.QUI_RefreshActionBarFade = noop
owned:Initialize()
assert(#hooks == 1, "native initialization must install the shared tooltip suppression hook")
local function tooltipFor(parent)
    local tooltip = {
        Hide = function(self) self.hidden = true end,
        SetOwner = function(self, owner, anchor) self.owner, self.anchor = owner, anchor end,
        ClearLines = function(self) self.cleared = true end,
    }
    for _, callback in ipairs(hooks) do callback(tooltip, parent) end
    return tooltip
end
local tooltip = tooltipFor(button)
assert(tooltip.hidden and tooltip.cleared and tooltip.owner == env.UIParent and tooltip.anchor == "ANCHOR_NONE",
    "saved Show Tooltips=false must suppress native action-button tooltips at startup")
assert(not tooltipFor(otherButton).hidden and not tooltipFor(nil).hidden,
    "action-bar tooltip settings must not suppress unrelated tooltips")
settings.showTooltips = true
assert(not tooltipFor(button).hidden, "enabling Show Tooltips must take effect immediately")
settings = { showTooltips = false }
assert(tooltipFor(button).hidden, "tooltip suppression must read the current profile settings")
settings = nil
assert(not tooltipFor(button).hidden, "missing global settings must leave tooltips enabled")
for _ = 1, 2 do
    owned:Initialize()
    owned:Refresh()
    env.initFrame.OnEvent(env.initFrame, "ADDON_LOADED", "Blizzard_ActionBar")
end
assert(#hooks == 1, "repeated initialization and refresh must not duplicate tooltip hooks")
print("OK: native action bars share tooltip suppression and respect current profile settings")
