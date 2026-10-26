-- Exercise the actual provider composers against the shared native-bounds repair.
-- These headers can exist before WoW has assigned their label a screen rectangle.
local compile = loadstring or load
local unpackValues = unpack or table.unpack
local function Read(path)
    local f = assert(io.open(path)); local source = f:read("*a"); f:close(); return source
end
local function Extract(path, first, last)
    local source = Read(path)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start, true)) - 1)
end
local function Frame(parent)
    local f = {parent = parent, points = {}, hooks = {}, width = 700, height = 0, top = 100, shown = true}
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:GetPoint(index) return unpackValues(self.points[index or 1]) end
    function f:ClearAllPoints() self.points = {} end
    function f:SetWidth(width)
        self.width = width
        for _, callback in ipairs(self.hooks.OnSizeChanged or {}) do callback(self, width, self.height) end
    end
    function f:GetWidth() return self.width end
    function f:SetHeight(height) self.height = height end
    function f:GetHeight() return self.height end
    function f:GetTop() return self.top end
    function f:SetParent(value) self.parent = value end
    function f:SetScript(event, callback) self[event] = callback end
    function f:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        self.hooks[event][#self.hooks[event] + 1] = callback
    end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:SetText(text) self.text = text end
    function f:SetTextColor(...) self.color = {...} end
    function f:SetJustifyH(value) self.justify = value end
    function f:SetWordWrap(value) self.wrap = value end
    function f:GetStringHeight() return 28 end
    function f:CreateFontString() self.description = Frame(self); return self.description end
    return f
end
_G.CreateFrame = function(_, _, parent) return Frame(parent) end
local headers = {}
local options = {PADDING = 15}
function options.CreateAccentDotLabel(parent, text)
    local h = Frame(parent)
    h.title, h._dot, h._label = text, {}, Frame(parent)
    h._label.top = nil
    function h._label:SetPoint(...) self.points[#self.points + 1] = {...}; self.top = 90 end
    headers[#headers + 1] = h
    return h
end
function options.CreateSettingsCardGroup(parent)
    local f = Frame(parent); f.height = 40
    return {frame = f, Finalize = function() return 40 end}
end
local ns = {QUI_Options = options}
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
local context
local env = setmetatable({ns = ns, Opts = options, PADDING = 15, HEADER_GAP = 26,
    SECTION_BOTTOM_PAD = 6, DESCRIPTION_TEXT_COLOR = {1, 1, 1, 0.6}, FORM_ROW = 32,
    GetOptionsAPI = function() return options end, PrepareSectionHost = function() end,
    SetSearchContext = function(value) context = value end,
    GetSearchProviderKey = function() return "groupFramesParty" end,
    GetRenderContextMode = function() return "party" end,
    ResolveContainerKey = function() return "essential" end,
}, {__index = _G})
local cases = {
    {name = "Unit Frames", path = "QUI_UnitFrames/unitframes/settings/unit_frames_schema.lua", last = "local function GetRenderState(", gap = 26, bottom = 6},
    {name = "Group Frames", path = "QUI_GroupFrames/groupframes/settings/group_frames_schema.lua", last = "local function GetFontListWithDefault", gap = 26, bottom = 10, measured = true},
    {name = "Nameplates", path = "QUI_Nameplates/nameplates/settings/nameplates_schema.lua", last = "local function RefreshNameplates(", gap = 22, bottom = 6, measured = true},
    {name = "CDM", path = "QUI_CDM/cdm/settings/containers_page.lua", last = "local function RefreshUtilityAnchor(", gap = 22, bottom = 12},
    {name = "Action Bars", path = "QUI_ActionBars/actionbars/settings/action_bars_content.lua", first = "local function MakeSectionLayout(", last = "local BAR_OPTIONS =", gap = 26, bottom = 10},
}
local failures = {}
for _, case in ipairs(cases) do
    local ok, err = pcall(function()
        env.HEADER_GAP, env.SECTION_BOTTOM_PAD = case.gap, case.bottom
        local isActionBars = case.name == "Action Bars"
        local body = Extract(case.path, case.first or "local function CreateSectionBuilder(", case.last)
        local chunk = assert(compile(body .. "\nreturn " .. (isActionBars and "MakeSectionLayout" or "CreateSectionBuilder")))
        setfenv(chunk, env)
        local host = Frame()
        local build
        if isActionBars then
            local header, card, close, getY = chunk()(host)
            build = {Header = header, Card = card, CloseCard = close, Height = function(extra) return -getY() + (extra or 0) end}
        else
            build = chunk()(host, {}, {})
        end
        local initial = build.Height(0)
        local returned, origin = build.Header("Visible section")
        local header = headers[#headers]
        assert(header.OnUpdate, case.name .. " heading must recover missing native label bounds")
        header.OnUpdate(header); header.OnUpdate(header)
        local pad = isActionBars and 15 or 0
        assert(header._label:GetTop() and header.width == host:GetWidth() - 2 * pad,
            "heading must recover within its provider's own padding")
        host:SetWidth(480)
        assert(header.width == 480 - 2 * pad, "recovered heading must follow a narrower provider")
        host:SetWidth(900)
        assert(header.width == 900 - 2 * pad, "recovered heading must follow a wider provider")
        assert(build.Height(0) == initial + case.gap, "provider-specific heading spacing must be preserved")
        if case.name == "Nameplates" then
            assert(returned == header and origin == 0, "Nameplates needs its header and origin for editor reflow")
            local description = build.Description("A paragraph long enough to occupy two native text lines")
            assert(description.wrap and description.width == 900 and description.height == 28,
                "Nameplates descriptions retain explicit wrapped width and measured height")
            assert(build.Height(0) == 22 + 28 + 8, "Nameplates paragraph gap is retained")
        elseif case.name == "Unit Frames" then
            local previous = build.Height(0)
            build.Row(function(row)
                assert(row.height == 32 and select(5, row:GetPoint()) == -previous,
                    "custom Unit Frames row must be positioned before building its controls")
            end)
            assert(build.Height(0) == previous + 42, "custom Unit Frames row spacing is retained")
        elseif case.name == "Group Frames" then
            assert(context.providerKey == "groupFramesParty", "Group Frames search context remains contextual")
        end
        local card = build.Card()
        local previous = build.Height(0)
        build.CloseCard(card)
        assert(build.Height(0) == previous + 40 + (isActionBars and 14 or 0), "card spacing is retained")
        if case.measured then
            local baseline = build.Height()
            card.frame._quiMeasuredHeight = 70
            assert(host._quiMeasureSettingsHeight() == baseline + 30, "deferred card heights count once")
            if case.name == "Group Frames" then
                local editor = Frame(host); editor.height = 80
                build.Spacer(80, editor)
                baseline = build.Height()
                editor.height = 120
                assert(host._quiMeasureSettingsHeight() == baseline + 30 + 40,
                    "Group Frames embedded editors contribute their settled height")
            end
        end
    end)
    if not ok then failures[#failures + 1] = tostring(err) end
end
-- Copy Settings is a bespoke Group Frames section; its heading must still
-- follow the family composer even though its button/profile editor stay custom.
do
    local ok, err = pcall(function()
        local path = "QUI_GroupFrames/groupframes/settings/group_frames_schema.lua"
        ns.L = setmetatable({}, {__index = function(_, key) return key end})
        env.GetGUI = function()
            return {CreateLabel = function() return Frame() end, CreateButton = function() return Frame() end}
        end
        env.ResolveGroupFramesDB = function()
            return {contextMode = "party", targetMode = "raid", sourceLabel = "Party", targetLabel = "Raid"}
        end
        env.CreateSearchContext = function() return {} end
        env.string = setmetatable({format = function(format, ...)
            return string.format((format:gsub("%%[12]%$s", "%%s")), ...)
        end}, {__index = string})
        env.HEADER_GAP, env.SECTION_BOTTOM_PAD = 26, 10
        local builderBody = Extract(path, "local function CreateSectionBuilder(", "local function GetFontListWithDefault")
        local renderBody = Extract(path, "local function RenderGeneralCopySettingsSection(", "local function RenderAppearanceSection(")
        local chunk = assert(compile(builderBody .. renderBody .. "\nreturn RenderGeneralCopySettingsSection"))
        setfenv(chunk, env)
        local host = Frame()
        local height = chunk()(host, {})
        local header = headers[#headers]
        assert(header.OnUpdate, "Group Frames Copy Settings heading must recover missing native label bounds")
        header.OnUpdate(header); header.OnUpdate(header)
        assert(header._label:GetTop() and header.width == 700, "Copy Settings heading uses the same zero padding as group cards")
        assert(height == 100, "Copy Settings preserves its button and paragraph spacing")
    end)
    if not ok then failures[#failures + 1] = tostring(err) end
end
assert(#failures == 0, table.concat(failures, "\n"))
print("OK: provider_section_layout_test")
