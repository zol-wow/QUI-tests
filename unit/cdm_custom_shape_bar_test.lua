local path = arg and arg[1] or "QUI_CDM/cdm/cdm_containers.lua"
local file = assert(io.open(path))
local source = file:read("*a")
file:close()
local function LoadFunction(name, nextName, env)
    local first = assert(source:find("local function " .. name, 1, true))
    local last = assert(source:find("\nlocal function " .. nextName, first, true))
    local body = source:sub(first, last - 1):gsub("^local function " .. name, "return function", 1)
    local chunk = assert(loadstring(body, "@cdm_containers.lua#" .. name))
    setfenv(chunk, env)
    return chunk()
end
local owner = { Show = function(self) self.hidden = false end, Hide = function(self) self.hidden = true end,
    EnableMouse = function() end }
local settings = { shape = "bar", containerType = "customBar", barWidth = 215 }
local entries = { { id = 1307927, kind = "aura" }, { id = 1237205, kind = "aura" } }
local rendered, parked, cleared, iconLayouts, barClears = 0, 0, 0, 0, 0
local inCombat, nativeBarsEnabled = false, false
local bars, icons = {}, { {} }
local ns = {
    CDMIcons = {
        BuildIcons = function()
            assert(settings.shape == "icon", "bar shape must not build icons")
            assert(not nativeBarsEnabled, "native bars must retire before icon allocation")
            iconLayouts = iconLayouts + 1
            return {}
        end,
        ResolveCustomContainerEntries = function(key)
            assert(key == "custom")
            return entries
        end,
    },
    CDMIconFactory = {
        GetIconPool = function() return icons end,
        ClearPool = function(_, key)
            assert(key == "custom")
            cleared = cleared + 1
            icons = {}
        end,
    },
    CDMCustomAuraRuns = {
        Apply = function(frame, config)
            assert(frame == owner and config == nil)
            parked = parked + 1
        end,
        ShouldUseSettings = function() return false end,
    },
    CDMBars = {
        GetActiveBars = function(_, key) assert(key == "custom"); return bars end,
        ClearPool = function(_, key)
            assert(key == "custom" and not inCombat, "native bars must not be recycled during combat")
            bars, nativeBarsEnabled = {}, false
            barClears = barClears + 1
        end,
        Refresh = function(_, frame, config, width, key, runtime, configured)
            assert(not inCombat, "native bars must not be allocated during combat")
            assert(frame == owner and config == settings and width == 215)
            assert(key == "custom" and runtime == nil and configured == entries,
                "native bar rendering must receive the custom container's configured aura entries")
            bars, nativeBarsEnabled = { {}, {} }, true
            rendered = rendered + 1
        end,
    },
}
local env = setmetatable({
    ns = ns,
    containers = { custom = owner },
    viewerState = {},
    applying = {},
    BUILTIN_NAMES = {},
    CDMContainers_API = { HUD_LAYERING = { keys = {}, viewers = {} } },
    CDMLayout = { GetTotalIconCapacity = function() return 0 end },
    Helpers = { IsEditModeActive = function() return false end },
    GetHUDMinWidth = function() return false end,
    IsCDMRuntimeEnabled = function() return true end,
    GetTrackerSettings = function() return settings end,
    IsBarShape = function() return settings.shape == "bar" end,
    InCombatLockdown = function() return inCombat end,
}, { __index = _G })
env._G = env
env.ShouldDeferContainerLayoutInCombat = LoadFunction("ShouldDeferContainerLayoutInCombat", "GetDefaultsByContainerType", env)
local layout = LoadFunction("LayoutContainer", "RunPostLayoutRefresh", env)
layout("custom")
assert(rendered == 1 and parked == 1 and cleared == 1,
    "switching a custom container to bars must replace old icon visuals with native aura bars")
assert(env.applying.custom == false, "bar rendering must release the layout guard")
inCombat, settings.shape = true, "icon"
layout("custom")
assert(env.specTrackingPendingRefresh and nativeBarsEnabled and #bars == 2,
    "bar-to-icon combat changes must preserve the existing native bars until regen")
assert(barClears == 0 and iconLayouts == 0 and rendered == 1)
inCombat, env.specTrackingPendingRefresh = false, false
layout("custom")
assert(barClears == 1 and iconLayouts == 1 and not nativeBarsEnabled,
    "bar-to-icon changes must retire native bars before building icons after combat")
inCombat, settings.shape = true, "bar"
layout("custom")
assert(env.specTrackingPendingRefresh and rendered == 1 and iconLayouts == 1,
    "icon-to-bar combat changes must defer native bar creation")
inCombat = false
layout("custom")
assert(rendered == 2 and nativeBarsEnabled and env.applying.custom == false,
    "icon-to-bar changes must finish when combat ends")

local mouseDisabled = 0
for _, bar in ipairs(bars) do
    bar.EnableMouse = function(_, enabled)
        assert(enabled == false)
        mouseDisabled = mouseDisabled + 1
    end
end
env._disabledMouseFrames = {}
LoadFunction("DisableMouseForEditMode", "RestoreMouseAfterEditMode", env)("custom")
assert(mouseDisabled == 2, "edit mode must disable custom bar proxy mouse interaction")

settings.enabled = false
layout("custom")
assert(owner.hidden and not nativeBarsEnabled and #bars == 0,
    "disabling a custom container must retire its native bars and runtime proxies")
settings.enabled = true
layout("custom")
assert(nativeBarsEnabled and #bars == 2, "reenabling must rebuild the native bar pool")

local deleted, detached = 0, false
ns.CDMBars.DeleteContainer = function(_, key)
    assert(key == "custom" and not detached, "bar state must be deleted before its parent is detached")
    ns.CDMBars:ClearPool(key)
    deleted = deleted + 1
end
owner.ClearAllPoints = function() end
owner.SetParent = function(_, parent)
    assert(parent == nil and deleted == 1 and not nativeBarsEnabled)
    detached = true
end
local db = { containers = { custom = settings }, custom = settings }
env.GetDB = function() return db end
env.SyncSettingsFeatureLookups = function() end
local deleteStart = assert(source:find("function CDMContainers_API:DeleteContainer", 1, true))
local deleteEnd = assert(source:find("\nfunction CDMContainers_API:RenameContainer", deleteStart, true))
local deleteSource = source:sub(deleteStart, deleteEnd - 1):gsub("^function CDMContainers_API:DeleteContainer", "return function", 1)
local deleteChunk = assert(loadstring(deleteSource, "@cdm_containers.lua#DeleteContainer"))
setfenv(deleteChunk, env)
local deleteContainer = deleteChunk()
inCombat = true
assert(deleteContainer("custom") == false and deleted == 0 and nativeBarsEnabled,
    "combat must reject deletion without touching the native bar state")
inCombat = false
assert(deleteContainer("custom") == true)
assert(deleted == 1 and detached and env.containers.custom == nil
    and db.containers.custom == nil and db.custom == nil,
    "deleting a custom container must remove native bar state before orphaning its frame")
print("OK: cdm_custom_shape_bar_test")
