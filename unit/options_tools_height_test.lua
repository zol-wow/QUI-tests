local frames = {}
local methods = {}
local function noop() end
for name in ("SetPoint ClearAllPoints SetBorderColor"):gmatch("%S+") do methods[name] = noop end
local function Node(parent)
    local frame = setmetatable({ parent = parent, width = 700, height = 0, shown = true, scripts = {} }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
function methods:GetParent() return self.parent end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetStringHeight() return 14 end
function methods:GetTop() error("Tools sizing must not depend on absolute screen coordinates") end
methods.GetBottom = methods.GetTop
function methods:SetWidth(width)
    local previous = self.width
    self.width = width
    if previous ~= width and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self) end
end
function methods:SetHeight(height)
    local previous = self.height
    self.height = height
    if previous ~= height and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self) end
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
local pending, runs, buttons = {}, {}, {}
local confirmed
local gui = { Colors = {}, SetSearchContext = noop, AttachTooltip = noop, RegisterSearchSettingWidget = noop }
function gui:CreateButton(parent, label, _, height, callback)
    local button = Node(parent)
    button:SetWidth(110)
    button:SetHeight(height)
    button.label, button.click = label, callback
    buttons[#buttons + 1] = button
    return button
end
function gui:ShowConfirmation(config) confirmed = config end
local ns = {
    L = setmetatable({ ["Run %1$s?"] = "Run %s?" }, { __index = function(_, key) return key end }),
    Helpers = { AssetPath = "" },
    QUI_Options = {
        PADDING = 15,
        CreateWrappedLabel = function(parent) return Node(parent) end,
        CreateAccentDotLabel = function(parent)
            local label = Node(parent)
            label:SetHeight(22)
            return label
        end,
    },
    DiagnosticsConsole = {
        CreateOutputPanel = function(parent) return Node(parent) end,
        Run = function(command, callback) runs[#runs + 1] = { command = command, callback = callback } end,
    },
}
assert(loadfile("QUI_Options/tiles/help_content.lua"))("QUI", ns)
local env = setmetatable({ QUI = { GUI = gui }, CreateFrame = function(_, _, parent) return Node(parent) end,
    C_Timer = { After = function(_, callback) pending[#pending + 1] = callback end } }, { __index = _G })
setfenv(assert(loadfile("core/settings/content/troubleshooting_page.lua")), env)("QUI", ns)
local parent, content = Node(), nil
parent:Hide()
content = Node(parent)
ns.QUI_TroubleshootingOptions.BuildTroubleshootingContent(content)
assert(not content:IsVisible() and content:GetHeight() > 400, "hidden warmed Tools page reserves its commands and full 320px output")
local originalHeight = content:GetHeight()
for _, callback in ipairs(pending) do callback() end
parent:Show()
assert(content:IsVisible() and content:GetHeight() == originalHeight, "cached Tools page keeps its full height on actual visibility")
local grid = assert(buttons[1].parent)
grid:SetWidth(220)
assert(content:GetHeight() > originalHeight, "narrowing the diagnostics grid grows scrollable content height immediately")
local narrowHeight = content:GetHeight()
grid:SetWidth(700)
assert(content:GetHeight() == originalHeight and content:GetHeight() < narrowHeight, "widening the grid releases unused scroll space")
local entries = ns.QUI_HelpContent.Diagnostics
assert(#buttons == #entries and #entries > 10, "every native diagnostic action remains mounted")
for index, entry in ipairs(entries) do
    if not entry.danger then
        buttons[index].click()
        assert(runs[#runs].command == entry.command and runs[#runs].callback == entry.run, "safe diagnostics retain their native command callbacks")
        break
    end
end
local before = #runs
for index, entry in ipairs(entries) do
    if entry.danger then
        buttons[index].click()
        assert(#runs == before and confirmed and confirmed.isDestructive, "destructive commands still wait for confirmation")
        confirmed.onAccept()
        assert(#runs == before + 1 and runs[#runs].command == entry.command and runs[#runs].callback == entry.run,
            "confirmed diagnostics retain their native action")
        break
    end
end
print("options_tools_height_test: ok")
