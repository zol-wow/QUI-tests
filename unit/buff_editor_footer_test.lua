local path = os.getenv("QUI_BUFF_SOURCE") or "QUI_ActionBars/actionbars/settings/action_bars_buffdebuff_content.lua"
local file = assert(io.open(path)); local source = file:read("*a"); file:close()
local body = assert(source:match("(local function BuildBuffDebuffTab.-)\nns.QUI_BuffDebuffOptions"))
local function Frame()
    local f = {height = 0, width = 700, points = {}, hooks = {}}
    function f:SetPoint(point, relative, relativePoint, x, y)
        if point == "TOPLEFT" then self.y = y end
        for index, anchor in ipairs(self.points) do
            if anchor[1] == point then
                self.points[index] = {point, relative, relativePoint, x, y}
                return
            end
        end
        self.points[#self.points + 1] = {point, relative, relativePoint, x, y}
    end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(index) return unpack(self.points[index or 1]) end
    function f:ClearAllPoints() self.points = {} end
    function f:SetHeight(h) self.height = h end
    function f:GetHeight() return self.height end
    function f:GetTop() return 100 end
    function f:GetWidth() return self.width end
    function f:SetWidth(w)
        self.width = w
        for _, fn in ipairs(self.hooks) do fn(self, w) end
    end
    function f:SetScript(event, fn) self[event] = fn end
    function f:HookScript(event, fn) assert(event == "OnSizeChanged"); self.hooks[#self.hooks + 1] = fn end
    function f:Hide() end
    function f:Show() end
    return f
end
local settings, editors, callbacks, headers, cards = {}, {}, {}, {}, {}
local options = {PADDING = 15}
function options.CreateAccentDotLabel()
    local header = Frame()
    header._dot, header._label = {}, {points = {}}
    function header._label:GetTop() return self.top end
    function header._label:ClearAllPoints() self.points = {} end
    function header._label:SetPoint(...) self.points[#self.points + 1] = {...}; self.top = 90 end
    headers[#headers + 1] = header
    return header
end
function options.CreateSettingsCardGroup()
    local frame = Frame(); frame.height = 40
    local card = {frame = frame, Finalize = function() return 40 end}
    cards[#cards + 1] = card
    return card
end
local function Section(_, headerAt, sectionAt, closeSection)
    local header, headerY = headerAt("Section")
    local card, cardY = sectionAt()
    closeSection(card)
    return header, headerY, card.frame, cardY
end
local function Editor(parent, pad, gap, y, _, key)
    local f = Frame(); f.height = 60; editors[key] = f
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -pad, y)
    return y - 60 - gap, f, 60, function(fn) callbacks[key] = fn end
end
local ns = {QUI_Options = options, L = setmetatable({}, {__index = function(_, key) return key end})}
assert(loadfile("core/settings_layout_shared.lua"))("QUI", ns)
local env = setmetatable({ns = ns, Opts = options, GUI = {SetSearchContext = function() end},
    GetBuffBordersSettings = function() return settings end, BuildSharedSection = Section,
    BuildAuraSection = Section, BuildAuraEditorSection = Editor}, {__index = _G})
local chunk = assert(loadstring(body .. "\nreturn BuildBuffDebuffTab")); setfenv(chunk, env)
local tab = Frame(); chunk()(tab)
local function VerifyFooter()
    local last = editors.debuffAuras
    assert(tab.height == -last.y + last.height + 10,
        "buff/debuff scroll extent must end ten pixels after the last editor")
end
VerifyFooter()
assert(#headers == 3 and #cards == 3, "all three aura sections must render")
local headerY, cardY, editorY = headers[3].y, cards[3].frame.y, editors.debuffAuras.y
callbacks.buffAuras(120)
assert(headers[3].y == headerY - 60 and cards[3].frame.y == cardY - 60 and editors.debuffAuras.y == editorY - 60,
    "buff editor growth must shift the debuff heading, card, and editor by the same amount")
VerifyFooter()
for _, header in ipairs(headers) do
    assert(header.OnUpdate, "Buff/Debuff headings must recover missing native label bounds")
    header.OnUpdate(header); header.OnUpdate(header)
    assert(header._label:GetTop() and header.width == 670, "each repaired heading retains page padding")
end
assert(headers[3].y == headerY - 60, "heading repair must retain the current editor reflow offset")
tab:SetWidth(480)
for _, header in ipairs(headers) do assert(header.width == 450, "aura heading width follows a narrow page") end
tab:SetWidth(900)
for _, header in ipairs(headers) do assert(header.width == 870, "aura heading width follows a wider page") end
editors.debuffAuras.height = 140; callbacks.debuffAuras(140); VerifyFooter()
callbacks.buffAuras(60)
assert(headers[3].y == headerY and cards[3].frame.y == cardY and editors.debuffAuras.y == editorY,
    "shrinking the buff editor must restore all original debuff origins")
VerifyFooter()
print("OK: buff_editor_footer_test")
