local file = assert(io.open("modules/ui/uihider.lua", "rb"))
local source = file:read("*a")
file:close()
local first = assert(source:find("    if StatusTrackingBarManager then", 1, true))
local last = assert(source:find("    if UIErrorsFrame then", first, true))
local block = source:sub(first, last - 1)
local function run(hideXP, hideRep, editMode)
    local settings = { hideExperienceBar = hideXP, hideReputationBar = hideRep }
    local rep = { shownBarIndex = 1, mouseEnabled = false }
    local xp = { shownBarIndex = 4, mouseEnabled = false }
    for _, container in ipairs({rep, xp}) do
        function container:SetAlpha(alpha) self.alpha = alpha end
        function container:EnableMouse(enabled) self.mouseEnabled = enabled end
    end
    local manager = { barContainers = {rep, xp}, shown = true }
    function manager:Show() self.shown = true end
    function manager:Hide() self.shown = false end
    local env = setmetatable({
        settings = settings,
        StatusTrackingBarManager = manager,
        hookedSecureFrames = {},
        GetSettings = function() return settings end,
        IsInEditMode = function() return editMode end,
        hooksecurefunc = function() end,
        C_Timer = {After = function(_, callback) callback() end},
    }, {__index = _G})
    local chunk = assert(loadstring(block, "status hider"))
    setfenv(chunk, env)
    chunk()
    return manager, rep, xp
end
local manager, rep, xp = run(true, false, false)
assert(manager.shown and rep.alpha == 1 and xp.alpha == 0)
assert(not rep.mouseEnabled, "Visible reputation container must let the native child receive OnEnter/OnLeave")
assert(not xp.mouseEnabled, "Hidden experience container must not capture input")
manager, rep, xp = run(false, true, false)
assert(manager.shown and rep.alpha == 0 and xp.alpha == 1)
assert(not xp.mouseEnabled, "Visible experience container must let its native child receive hover")
assert(not rep.mouseEnabled)
manager = run(true, true, false)
assert(not manager.shown)
manager, rep, xp = run(true, false, true)
assert(manager.shown and rep.alpha == nil and xp.alpha == nil, "Edit Mode must retain native visibility ownership")
print("PASS uihider_status_tracking_hover_test")
