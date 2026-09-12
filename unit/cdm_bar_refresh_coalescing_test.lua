local frames = {}
local inCombat, enabled = true, true
function InCombatLockdown() return inCombat end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function CreateFrame()
    local frame = { scripts = {} }
    function frame:SetScript(key, handler) self.scripts[key] = handler end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end

local function tick()
    for _, frame in ipairs(frames) do
        local update = frame.scripts.OnUpdate
        if update then update(frame, 0.016) end
    end
end

local ns = {}
assert(loadfile('QUI_CDM/cdm/cdm_icon_refresh.lua'))('QUI', ns)
assert(loadfile('QUI_CDM/cdm/cdm_icon_runtime_refresh.lua'))('QUI', ns)
local barUpdates, iconUpdates = 0, 0
local scheduler = ns.CDMIconUpdateScheduler.Create({
    isRuntimeEnabled = function() return enabled end,
    getBars = function() return { UpdateOwnedBars = function() barUpdates = barUpdates + 1 end } end,
    updateCooldownOnly = function() iconUpdates = iconUpdates + 1 end,
})
local runtime = ns.CDMIconRuntimeRefresh.Create({
    isRuntimeEnabled = function() return enabled end,
    getIconPools = function() return {} end,
    setBarsDirty = function(value) scheduler:SetBarsDirty(value) end,
    runDirtyBarUpdate = function() scheduler:RunDirtyBarUpdate() end,
    scheduleUpdate = function(fast, mode) scheduler:Schedule(fast, mode) end,
})

for _ = 1, 100 do runtime:HandleChargesChanged(nil, 12345) end
assert(barUpdates == 0, 'combat charge burst must defer all-bar work until the next frame; got ' .. barUpdates)
tick()
assert(barUpdates == 1, 'combat charge burst must produce one all-bar update')
assert(iconUpdates == 0, 'bar refresh must not add an all-icon cooldown pass')
assert(not scheduler:IsBarsDirty(), 'completed bar pass must clear scheduler dirty state')
tick()
assert(barUpdates == 1, 'bar driver must disarm after its pending work')

for _ = 1, 100 do
    runtime:HandleCooldownChanged(nil, 12345, nil, 'scanner_spell')
    runtime:HandleFrameEvent('UNIT_SPELLCAST_STOP', 'player', nil, 12345)
    runtime:HandleFrameEvent('BAG_UPDATE_COOLDOWN')
end
assert(barUpdates == 1, 'mixed combat events must share the same pending bar pass')
tick()
assert(barUpdates == 2, 'mixed combat burst must produce one all-bar update')
assert(iconUpdates == 0, 'mixed bar events must preserve scoped icon queues')

runtime:HandleChargesChanged(nil, 12345)
enabled = false
tick()
assert(barUpdates == 2, 'disabled runtime must discard its pending bar pass')
assert(not scheduler:IsBarsDirty(), 'disabled runtime must clear pending bar dirtiness')
enabled = true
tick()
assert(barUpdates == 2, 're-enabling must not replay stale bar work')

runtime:HandleChargesChanged(nil, 12345)
runtime:HandleFrameEvent('PLAYER_REGEN_DISABLED')
assert(barUpdates == 3, 'combat visibility change must refresh prepared bars immediately')
tick()
assert(barUpdates == 3, 'immediate combat refresh must consume the queued bar pass')

inCombat = false
runtime:HandleFrameEvent('ITEM_COUNT_CHANGED')
assert(barUpdates == 4, 'out-of-combat item updates should remain immediate')
print('OK: combat bar refresh bursts coalesce without all-icon work')
