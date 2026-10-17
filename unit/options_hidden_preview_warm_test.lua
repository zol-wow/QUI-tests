local function Frame(parent)
    local frame = { parent = parent, children = {}, scripts = {}, shown = true }
    if parent then parent.children[#parent.children + 1] = frame end
    function frame:GetParent() return self.parent end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:HookScript(key, callback) self.scripts[key] = callback end
    local function Notify(node, event)
        if node.scripts[event] then node.scripts[event](node) end
        for _, child in ipairs(node.children) do if child:IsShown() then Notify(child, event) end end
    end
    function frame:Show() self.shown = true; Notify(self, "OnShow") end
    function frame:Hide() self.shown = false; Notify(self, "OnHide") end
    return frame
end
local function Upvalue(callback, wanted)
    for index = 1, math.huge do
        local key, value = debug.getupvalue(callback, index)
        if not key then break end
        if key == wanted then return value end
    end
    error("missing upvalue: " .. wanted)
end
for _, definition in ipairs({
    { path = "QUI_GroupFrames/groupframes/settings/group_frames_surface.lua", key = "QUI_GroupFramesSettingsSurface" },
}) do
    local window = Frame()
    _G.QUI = { GUI = { MainFrame = window } }
    local ns = { Settings = { FullSurface = {} } }
    (dofile("tests/helpers/locale.lua"))(ns)
    local builds, shows, hides = 0, 0, 0
    _G.QUI_BuildGroupFramePreview = function() builds = builds + 1 end
    assert(loadfile(definition.path))("QUI", ns)
    local surface = ns[definition.key]
    local bind = Upvalue(surface.ShowPreviewOn, "BindPreviewBody")
    local state = Upvalue(bind, "State")
    state.previewPanel = {
        frame = Frame(window), contentHost = Frame(),
        Show = function() shows = shows + 1 end,
        Hide = function() hides = hides + 1 end,
        SetTitle = function() end,
    }
    local page = Frame(window)
    page:Hide()
    local body = Frame(page)
    assert(body:IsShown() and not body:IsVisible(), "hidden page bodies keep their own shown flag")
    surface.ShowPreviewOn(body)
    surface.ShowPreviewOn(body)
    assert(shows == 0 and builds == 0, definition.key .. ": hover warming must not activate the sibling preview")
    page:Show()
    assert(shows == 1 and builds == 1, definition.key .. ": showing the selected page activates its preview once")
    page:Hide()
    assert(hides == 1, definition.key .. ": leaving the selected page hides its preview")
    surface.ShowPreviewOn(body)
    assert(shows == 1 and builds == 1, definition.key .. ": rebinding a hidden cached page cannot reopen its preview")
    page:Show()
    assert(shows == 2 and builds == 2, definition.key .. ": cached pages reactivate through their existing visibility hooks")
end
print("options_hidden_preview_warm_test: ok")
