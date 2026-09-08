local sourcePath = arg[1] or "QUI_ActionBars/actionbars/actionbars_skinning.lua"
local file = assert(io.open(sourcePath, "r"))
local source = file:read("*a")
file:close()
local start = assert(source:find("FadeHideEffects = function", 1, true))
local finish = assert(source:find("DRAG_PREVIEW_ALPHA =", start, true))
local env = setmetatable({
    GetFrameState = function(button) return button.state end,
    SuppressButtonProcVisuals = function() end,
}, { __index = _G })
local chunk = assert(loadstring(source:sub(start, finish - 1)))
setfenv(chunk, env)
chunk()

local function newButton(shown)
    local cooldown = { shown = shown, swipe = true, edge = true }
    function cooldown:IsShown() return self.shown end
    function cooldown:Show()
        if self.shown then return end
        self.shown = true
        if self.onShow then self.onShow(self) end
    end
    function cooldown:Hide() self.shown = false end
    function cooldown:HookScript(event, callback)
        assert(event == "OnShow")
        assert(not self.onShow, "fade hook must only be installed once")
        self.onShow = callback
    end
    function cooldown:GetDrawSwipe() return self.swipe end
    function cooldown:GetDrawEdge() return self.edge end
    function cooldown:SetDrawSwipe(value) self.swipe = value end
    function cooldown:SetDrawEdge(value) self.edge = value end
    return { cooldown = cooldown, state = {} }
end

local button = newButton(false)
env.FadeHideTextures(button.state, button)
button.cooldown:Show()
assert(not button.cooldown:IsShown(), "new cooldown must stay suppressed while faded")
env.FadeShowTextures(button.state, button)
assert(button.cooldown:IsShown(), "cooldown started while faded must return immediately on reveal")
assert(button.cooldown.swipe and button.cooldown.edge, "reveal must restore swipe and edge")
assert(not button.state._fhCooldownFrameShown, "reveal must consume the restore flag")
env.FadeHideTextures(button.state, button)
env.FadeShowTextures(button.state, button)
assert(button.cooldown:IsShown(), "an existing cooldown must survive repeated fades")

local idle = newButton(false)
env.FadeHideTextures(idle.state, idle)
env.FadeShowTextures(idle.state, idle)
assert(not idle.cooldown:IsShown(), "reveal must not show a cooldown that never started")

print("OK: actionbars_hidden_cooldown_restore_test")
