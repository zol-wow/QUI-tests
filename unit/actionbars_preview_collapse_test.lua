local function Node(parent)
    local node = { parent = parent, scripts = {}, shown = true, height = 0 }
    setmetatable(node, { __index = function(_, key)
        if key:match("^%u") then return function() end end
    end })
    function node:SetHeight(height)
        self.height = height
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, 760, height) end
    end
    function node:GetHeight() return self.height end
    function node:SetScript(key, callback) self.scripts[key] = callback end
    function node:HookScript(key, callback)
        local previous = self.scripts[key]
        self.scripts[key] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function node:Hide() self.shown = false end
    function node:Show() self.shown = true end
    function node:IsShown() return self.shown end
    function node:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function node:CreateTexture() return Node(self) end
    function node:CreateFontString() return Node(self) end
    return node
end
_G.CreateFrame = function(_, _, parent) return Node(parent) end
local selector
local gui = { Colors = {} }
function gui:CreateFormDropdown(parent, _, _, _, state, callback)
    selector = Node(parent)
    selector.value = state.bar
    selector.callback = callback
    selector.SetValue = function(value) selector.value = value end
    return selector
end
_G.QUI = { GUI = gui }
local ns = {
    Helpers = { GetCore = function() end },
    QUI_Options = { PADDING = 15 },
    SafeCall = function(_, callback, ...) return pcall(callback, ...) end,
}
(dofile("tests/helpers/locale.lua"))(ns)
for _, path in ipairs({
    "core/settings/full_surface.lua",
    "QUI_ActionBars/actionbars/settings/action_bars_preview_driver.lua",
    "QUI_ActionBars/actionbars/settings/action_bars_content.lua",
}) do
    assert(loadfile(path))("QUI", ns)
end
local parent = Node()
parent:SetHeight(110)
local refreshed, fitHeight = 0, 140
local driver = ns.QUI_ActionBarsPreviewDriver
driver.Refresh = function()
    refreshed = refreshed + 1
    parent:SetHeight(fitHeight)
end
ns.QUI_ActionBarsOptions.BuildActionBarsPreview(parent)
local host = assert(parent._quiPreviewHost, "driver returns the existing icon viewport")
assert(host.parent == parent and selector.parent == parent, "selector remains beside the icon viewport")
assert(driver.Build(parent) == host, "repeated Build must return the existing viewport")
assert(parent:GetHeight() == 140, "expanded preview retains driver-owned auto-height")
local surface = ns.Settings.FullSurface
assert(surface.SetInlinePreviewCollapsed(parent, true))
assert(parent:IsVisible() and selector:IsVisible() and not host:IsVisible(),
    "collapse hides icons while keeping the bar selector visible")
assert(parent:GetHeight() == 30, "collapsed preview reserves one selector row")
fitHeight = 220
selector.callback("bar4")
assert(ns.QUI_ActionBarsOptions.GetSelectedBar() == "bar4" and selector.value == "bar4",
    "bar selection still synchronizes while the preview is collapsed")
assert(not host:IsVisible() and parent:GetHeight() == 30, "refresh cannot reopen a collapsed viewport")
local refreshCountBeforeExpand = refreshed
assert(surface.SetInlinePreviewCollapsed(parent, false))
assert(host:IsVisible() and selector:IsVisible(), "expansion restores icons and keeps the selector")
assert(parent:GetHeight() == 220 and refreshed == refreshCountBeforeExpand,
    "expansion must fit the bar selected while collapsed without a manual refresh")
print("actionbars_preview_collapse_test: ok")
