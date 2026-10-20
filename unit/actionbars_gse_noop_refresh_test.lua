local function harness(bindings, withGSE)
    local state = { frames = {}, timers = {}, refreshes = 0, bindingRefreshes = 0, combat = false }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.InCombatLockdown = function() return state.combat end
    local function frame(name)
        local value = { attributes = {}, scripts = {}, events = {}, name = name }
        function value:GetName() return self.name end
        function value:GetAttribute(key) return self.attributes[key] end
        function value:SetAttribute(key, data) self.attributes[key] = data end
        function value:RegisterEvent(event) self.events[event] = true end
        function value:UnregisterAllEvents() self.events = {} end
        function value:SetScript(script, callback) self.scripts[script] = callback end
        function value:HookScript() end
        function value:WrapScript() end
        state.frames[#state.frames + 1] = value
        return value
    end
    env.CreateFrame = function(_, name) return frame(name) end
    env.QUI_Bar1Button1 = frame("QUI_Bar1Button1")
    env.QUI_Bar2Button1 = frame("QUI_Bar2Button1")
    env.SequenceOne = frame("SequenceOne")
    env.SequenceTwo = frame("SequenceTwo")
    env.QUI = { db = { profile = {} } }
    if bindings then env.QUI.db.profile.gseCompat = { bindings = { [0] = bindings } } end
    if withGSE then env.GSE = {} end
    env.C_Timer = { After = function(_, callback) state.timers[#state.timers + 1] = callback end }
    env.QUI_RefreshActionBars = function() state.refreshes = state.refreshes + 1 end
    env.QUI_ReapplyActionBarBindings = function() state.bindingRefreshes = state.bindingRefreshes + 1 end
    local ns = { SafeCallMethodIfPresent = function(_, target, method)
        if target[method] then target[method](target) end
    end }
    local chunk = assert(loadfile("QUI_ActionBars/actionbars/gse_compat.lua"))
    setfenv(chunk, env)
    chunk("QUI_ActionBars", ns)
    function state:fire(event)
        for _, target in ipairs(self.frames) do
            if target.events[event] then target.scripts.OnEvent(target, event) end
        end
    end
    function state:drain()
        while #self.timers > 0 do
            local pending = self.timers
            self.timers = {}
            for _, callback in ipairs(pending) do callback() end
        end
    end
    function state:expectRefreshes(count)
        assert(self.refreshes == count, "full bar refreshes: expected " .. count .. ", got " .. self.refreshes)
        assert(self.bindingRefreshes == count, "binding refreshes must match")
    end
    return state, env, ns.QUI_GSECompat
end

for _, withGSE in ipairs({ false, true }) do
    local state = harness({}, withGSE)
    state:fire("PLAYER_LOGIN")
    state:fire("PLAYER_ENTERING_WORLD")
    state:drain()
    state:expectRefreshes(0)
    state:fire("PLAYER_SPECIALIZATION_CHANGED")
    state:fire("PLAYER_REGEN_ENABLED")
    state:drain()
    state:expectRefreshes(0)
end

do
    local state, env, compat = harness()
    compat.Reapply()
    state:expectRefreshes(0)
    env.QUI_Bar1Button1:SetAttribute("gse-button", "StaleSequence")
    state.combat = true
    compat.Reapply()
    assert(env.QUI_Bar1Button1:GetAttribute("gse-button") == "StaleSequence")
    state:expectRefreshes(0)
    state.combat = false
    state:fire("PLAYER_REGEN_ENABLED")
    assert(env.QUI_Bar1Button1:GetAttribute("gse-button") == nil)
    assert(env.QUI_Bar1Button1:GetAttribute("type") == "action")
    state:expectRefreshes(1)
    compat.Reapply()
    state:expectRefreshes(1)
end

do
    local state, _, compat = harness({ QUI_Bar1Button1 = "MissingSequence", QUI_Bar3Button1 = "SequenceOne" }, true)
    compat.Reapply()
    state:expectRefreshes(0)
end

do
    local state, env, compat = harness({
        QUI_Bar1Button1 = "SequenceOne", QUI_Bar2Button1 = "SequenceTwo", QUI_Bar3Button1 = "MissingSequence",
    }, true)
    env.QUI_Bar1Button1:SetAttribute("gse-button", "OldSequence")
    compat.Reapply()
    state:drain()
    for index, sequence in ipairs({ "SequenceOne", "SequenceTwo" }) do
        local button = env["QUI_Bar" .. index .. "Button1"]
        assert(button:GetAttribute("gse-button") == sequence, "every successful override must install")
        assert(button:GetAttribute("clickbutton") == env[sequence])
        assert(button:GetAttribute("type") == "click")
    end
    state:expectRefreshes(1)
end

print("actionbars_gse_noop_refresh_test: OK")
