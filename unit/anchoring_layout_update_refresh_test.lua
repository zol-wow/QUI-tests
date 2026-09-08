local file = assert(io.open("modules/layout/anchoring.lua", "rb"))
local source = file:read("*a")
file:close()
local first = assert(source:find('local layoutUpdateFrame = CreateFrame("Frame")', 1, true))
local last = assert(source:find("local HasFrameResolverForKey", first, true))

local timers, onEvent = {}, nil
local anchors, unitRefreshes, groupRefreshes = 0, 0, 0
local combat, editMode = false, false
local env = setmetatable({
    pendingAnchoredFrameUpdateAfterCombat = false,
    CreateFrame = function()
        return {
            RegisterEvent = function(_, event)
                assert(event == "EDIT_MODE_LAYOUTS_UPDATED")
            end,
            SetScript = function(_, script, fn)
                assert(script == "OnEvent")
                onEvent = fn
            end,
        }
    end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    InCombatLockdown = function() return combat end,
    nsHelpers = { IsEditModeActive = function() return editMode end },
    QUI_Anchoring = { ApplyAllFrameAnchors = function() anchors = anchors + 1 end },
    ns = { SafeCall = function(_, fn) return pcall(fn) end },
    _G = {
        QUI_RefreshUnitFrames = function() unitRefreshes = unitRefreshes + 1 end,
        QUI_RefreshGroupFrames = function() groupRefreshes = groupRefreshes + 1 end,
    },
}, { __index = _G })
local chunk = assert(loadstring(source:sub(first, last - 1)))
setfenv(chunk, env)
chunk()

local function drain()
    local queued = timers
    timers = {}
    for _, fn in ipairs(queued) do fn() end
end

onEvent()
onEvent()
assert(#timers == 1, "layout event bursts must coalesce")
assert(anchors == 0, "anchor repair must wait for the layout to settle")
drain()
assert(anchors == 1 and unitRefreshes == 1, "layout updates must still restore anchors and unit frames")
assert(groupRefreshes == 0, "Blizzard layout updates must not rebuild all QUI group-frame decorations")

onEvent()
combat = true
drain()
assert(env.pendingAnchoredFrameUpdateAfterCombat, "combat must defer anchor repair")
assert(anchors == 1 and unitRefreshes == 1, "combat must not refresh protected frames")

combat, editMode = false, true
onEvent()
drain()
assert(anchors == 1 and unitRefreshes == 1, "active Edit Mode must retain control of positions")

editMode = false
onEvent()
drain()
assert(anchors == 2 and unitRefreshes == 2, "later layout events must still run")
assert(groupRefreshes == 0, "later layout events must also avoid full group-frame rebuilds")
print("PASS anchoring_layout_update_refresh_test")
