local function setup(previous)
    local frames = {}
    local noop = function() end
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.QUI_GetCDMViewerFrame = function() return nil end
    env.InCombatLockdown = function() return true end
    env.C_Timer = { After = noop }
    env.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(name, callback) self[name] = callback end
        frame.Hide = noop
        frames[#frames + 1] = frame
        return frame
    end
    local ns = {
        _inInitSafeWindow = previous,
        Helpers = {
            GetCore = function() return nil end,
            CreateStateTable = function() return {} end,
            CreateDBGetter = function() return function() return nil end end,
        },
    }
    local chunk = assert(loadfile("QUI_CDM/cdm/cdm_buff_layout.lua"))
    setfenv(chunk, env)
    chunk("QUI_CDM", ns)
    local eventFrame
    for _, frame in ipairs(frames) do
        if frame.events.ADDON_LOADED then eventFrame = frame end
    end
    return ns, assert(eventFrame)
end

for _, mode in ipairs({ "nested", "closed", "absent" }) do
    local previous
    if mode == "nested" then previous = true elseif mode == "closed" then previous = false end
    local ns, eventFrame = setup(previous)
    eventFrame:OnEvent("ADDON_LOADED", "QUI_CDM")
    assert(ns._inInitSafeWindow == previous,
        "CDM initialization must preserve the outer core window for saved protected anchors: " .. mode)
    ns.CDMBuffLayout.Initialize()
    assert(ns._inInitSafeWindow == previous,
        "repeat CDM initialization must preserve the caller's window: " .. mode)
    eventFrame:OnEvent("PLAYER_ENTERING_WORLD", false, true)
    assert(ns._inInitSafeWindow == previous,
        "CDM reload layout must restore the caller's window: " .. mode)
    eventFrame:OnEvent("PLAYER_ENTERING_WORLD", true, false)
    assert(ns._inInitSafeWindow == previous,
        "CDM login layout must restore the caller's window: " .. mode)
end

print("OK cdm_buff_layout_init_window_test")
