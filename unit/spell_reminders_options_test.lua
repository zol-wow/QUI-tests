-- Exercise the real editor callbacks against the reminder runtime and a small
-- widget boundary. Search capture also executes these builders with QUI's UI.
local H = (dofile("tests/helpers/spell_reminders.lua"))({ deferRuntime = true })
local ns, widgets, buttons = H.ns, {}, {}
local buttonFrames, allWidgets = {}, {}
local createFrame = CreateFrame
_G.CreateFrame = function(...)
    local frame = createFrame(...)
    function frame:SetParent(parent) self.parent = parent end
    function frame:GetParent() return self.parent end
    function frame:GetTop() return 900 end
    for _, event in ipairs({ "Show", "Hide" }) do
        local original = frame[event]
        frame[event] = function(self)
            local changed = self:IsShown() ~= (event == "Show")
            original(self)
            if changed and self.scripts["On" .. event] then self.scripts["On" .. event](self) end
        end
    end
    function frame:GetPoint(index)
        local point = self.points[index or 1]
        if point then return unpack(point) end
    end
    function frame:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    for _, dimension in ipairs({ "Width", "Height" }) do
        local setter = frame["Set" .. dimension]
        frame["Set" .. dimension] = function(self, value)
            local previous = self["Get" .. dimension](self)
            setter(self, value)
            if previous ~= value and self.scripts.OnSizeChanged then
                self.scripts.OnSizeChanged(self, self:GetWidth(), self:GetHeight())
            end
        end
    end
    return frame
end
local GUI = { _searchContext = {} }
_G.QUI = { GUI = GUI }
local function Widget(parent, key, db, change)
    local widget = CreateFrame("Frame", nil, parent)
    function widget:Change(value)
        db[key] = value
        if change then change(value) end
    end
    widget.db, widget.key = db, key
    return widget
end
local function DescribedWidget(parent, key, db, change, options)
    local widget = Widget(parent, key, db, change)
    widget.description = options and options.description
    allWidgets[#allWidgets + 1] = widget
    return widget
end
function GUI:CreateFormCheckbox(parent, _, key, db, change, options) return DescribedWidget(parent, key, db, change, options) end
function GUI:CreateFormEditBox(parent, _, key, db, change, options) return DescribedWidget(parent, key, db, change, options) end
function GUI:CreateFormDropdown(parent, _, options, key, db, change, info, dropdownOptions)
    local widget = DescribedWidget(parent, key, db, change, info)
    widget.options = options
    widget.placeholder = dropdownOptions and dropdownOptions.placeholder
    widget.Refresh = function() widget.displayedValue = db[key] end
    return widget
end
function GUI:CreateFormSlider(parent, _, _, _, _, key, db, change, options) return DescribedWidget(parent, key, db, change, options) end
function GUI:CreateFormColorPicker(parent, _, key, db, change, options) return DescribedWidget(parent, key, db, change, options) end
function GUI:CreateButton(parent, label, _, _, callback)
    buttons[label] = callback
    local button = CreateFrame("Button", nil, parent)
    buttonFrames[label] = button
    return button
end
function GUI:SetSearchContext(context)
    self._searchContext = context
    if context.featureId == "spellRemindersPage" then
        H.searchPage, H.searchTile = context.subPageIndex, context.tileId
    end
end
function GUI:SetSearchSection() end
function GUI:TeardownFrameTree(root)
    H.editorBuilds = (H.editorBuilds or 0) + 1
    local function Within(frame)
        while frame do
            if frame == root then return true end
            frame = frame.parent
        end
        return false
    end
    for label, widget in pairs(widgets) do
        if Within(widget) then widgets[label] = nil end
    end
    for label, frame in pairs(buttonFrames) do
        if Within(frame) then buttons[label], buttonFrames[label] = nil, nil end
    end
end
function GUI:ShowConfirmation(options) H.confirmation = options end
local function Copy(value)
    local copy = {}
    for key, item in pairs(value or {}) do copy[key] = item end
    return copy
end
ns.QUI_Options = {
    BuildSettingRow = function(_, label, widget) widgets[label] = widget; return widget end,
    GetDB = function() return { spellReminders = H.db } end,
    GetSoundList = function() return { { value = "None", text = "None" } } end,
    GetFontList = function() return {} end,
}
local realLayoutNS = { QUI_Options = ns.QUI_Options }
assert(loadfile(os.getenv("QUI_LAYOUT_SOURCE") or "core/settings_layout_shared.lua"))("QUI", realLayoutNS)
ns.QUI_SettingsLayoutShared = {
    VerifyInitialBounds = realLayoutNS.QUI_SettingsLayoutShared.VerifyInitialBounds,
    BuildNinePointAnchorOptions = function() return {} end,
    MakeLayout = function(host, _, startY, options)
        local y = startY or 0
        return {
            headerAt = function(title)
                y = y - 30
                if host.RegisterSection then host:RegisterSection(title, title, CreateFrame("Frame", nil, host)) end
            end,
            sectionAt = function()
                return { frame = CreateFrame("Frame", nil, host), AddRow = function() y = y - 30 end }
            end,
            closeSection = function() y = y - 20 end,
            intro = function(text)
                y = y - 40
                local label = host:CreateFontString()
                label:SetFont("font", 12, "")
                label:SetText(text)
                return label
            end,
            placeCustom = function(frame, height)
                local layout = realLayoutNS.QUI_SettingsLayoutShared.MakeLayout(host, nil, y, options)
                layout.placeCustom(frame, height)
                y = layout.getY()
            end,
            getY = function() return y end,
            finish = function() host:SetHeight(-y); return -y end,
        }
    end,
}
ns.Settings = {
    Util = { ShallowCopy = Copy },
    Schema = { Feature = function(value) return value end, Section = function(value) return value end },
    FullSurface = { CreateTabStrip = function(parent)
        return CreateFrame("Frame", nil, parent), function(tabs, active, callback)
            H.tabPaints = (H.tabPaints or 0) + 1
            H.tabs, H.activeTab, H.selectTab = tabs, active, callback
        end
    end },
}
ns.QUI_LayoutMode_Utils = {
    BuildPositionCollapsible = function(host, key, _, sections)
        H.positionHost, H.positionKey = host, key
        sections[#sections + 1] = { kind = "position" }
    end,
    BuildOpenFullSettingsLink = function(host, key, sections)
        H.fullSettingsHost, H.fullSettingsKey = host, key
        sections[#sections + 1] = { kind = "settings" }
    end,
    StandardRelayout = function(host, sections)
        assert(#sections == 2, "layout routes must include anchoring controls and the settings link")
        host:SetHeight(88)
    end,
}
assert(loadfile("core/settings/registry.lua"))("QUI", ns)
assert(loadfile("core/settings/search_route.lua"))("QUI", ns)
assert(loadfile("core/settings/render_adapters.lua"))("QUI", ns)
assert(loadfile(os.getenv("QUI_REMINDER_OPTIONS_SOURCE") or "QUI_Reminders/spell_reminders/settings/spell_reminders.lua"))("QUI", ns)
assert(loadfile("QUI_Reminders/spell_reminders/settings/spell_reminder_tracking.lua"))("QUI", ns)
H.feature = assert(ns.Settings.Registry:GetFeature("spellRemindersPage"))
local O = ns.SpellReminderOptions
local tiles = {}
ns.QUI_Options.RegisterFeatureTile = function(_, tile) tiles[tile.id] = tile end
assert(loadfile("QUI_Options/tiles/gameplay.lua"))("QUI", ns)
ns.QUI_GameplayTile.Register({})
assert(loadfile("QUI_Options/tiles/reminders.lua"))("QUI", ns)
ns.QUI_RemindersTile.Register({})
assert(#tiles.gameplay.subPages == 8, "both reminder pages leave Gameplay")
assert(tiles.reminders.moduleFeatureId == "moduleAddon_QUI_Reminders")
assert(#tiles.reminders.subPages == 2 and tiles.reminders.subPages[1].name == "Defensive Reminders")
assert(tiles.reminders.subPages[1].featureId == "remindersPage")
assert(tiles.reminders.subPages[2].featureId == H.feature.id and H.feature.nav.subPageIndex == 2
    and H.feature.nav.tileId == "reminders", "reminder tabs share the dedicated module tile")
local content = CreateFrame("Frame", nil, UIParent)
assert(#H.feature.getNavigationTabs() == 0, "cold navigation cannot expose tabs for an unloaded module")
O.Build(content)
assert(not widgets["Enable Spell Reminders"] and not buttons["Power Infusion Preset"],
    "a disabled module shows guidance without exposing unavailable runtime actions")
assert(not ns.SpellReminderModel and not ns.SpellReminders, "opening options does not load the module")
H.LoadRuntime()
H.db.enabled = false
assert(type(H.feature.getNavigationContexts) == "function", "Spell Reminders must expose a persistent collection, not only the selected spell")
assert(H.feature.getNavigationRoot().key == "general" and H.feature.getNavigationRoot().label == "Add Reminder",
    "creation must remain a reachable navigation destination with no reminders")
assert(#H.feature.getNavigationContexts() == 0 and H.feature.getNavigationLabel() == "Spell Reminders (0)",
    "empty navigation must identify the collection and its count")
for _, id in ipairs({10060, 29166, 6940, 1022, 1044}) do assert(H.R.Add(id)) end
local entries = H.feature.getNavigationContexts()
assert(#entries == 5 and H.feature.getNavigationLabel() == "Spell Reminders (5)",
    "all five saved reminders must be discoverable independently of selection")
local identities = {}
for _, entry in ipairs(entries) do
    assert(not identities[entry.id] and H.db.reminders[entry.id] and #entry.tabs >= 4,
        "each saved reminder must have a unique stable identity and its own tabs")
    identities[entry.id] = true
end
for id in pairs(identities) do H.R.Remove(id) end
assert(#H.feature.getNavigationContexts() == 0 and H.feature.getNavigationRoot().key == "general",
    "deleting the last reminder must preserve the Add Reminder destination")
assert(#H.feature.getNavigationTabs() == 0, "cold navigation cannot expose tabs without a reminder")
O.Build(content)
assert(not widgets.Reminder and widgets["New Spell ID"] and next(H.db.reminders) == nil, "empty collection opens creation without inventing a reminder")
assert(select(4, O.activeBody:GetParent():GetPoint(1)) == 0,
    "Reminder editor must not add a second horizontal inset around shared cards")
assert(select(5, O.activeBody:GetPoint(1)) == 0,
    "General page must not reserve empty tab-header space")
assert(buttons["Add Spell"] and buttons["Power Infusion Preset"], "empty collection retains direct creation actions")
local emptyBuilds = H.editorBuilds
assert(not H.feature.searchNavigate({surfaceTabKey = "requests"}, {opts = {}})
    and H.editorBuilds == emptyBuilds and next(H.db.reminders) == nil,
    "PI-only search must stay unavailable without creating a reminder or rebuilding an empty editor")
-- The real General builder places its action buttons with shared MakeLayout.
-- Native cached pages can retain their anchors but lose resolved row bounds.
do
    local row = buttonFrames["Add Spell"]:GetParent()
    local host = row:GetParent()
    local parentReady, lost, repairs = false, true, 0
    function host:GetTop() return parentReady and 900 or nil end
    function row:GetTop() return not lost and host:GetTop() or nil end
    local setPoint = row.SetPoint
    function row:SetPoint(...)
        setPoint(self, ...)
        lost, repairs = false, repairs + 1
    end
    local function Tick()
        if row.scripts.OnUpdate then row.scripts.OnUpdate(row) end
    end
    row:Hide(); row:Show()
    for _ = 1, 4 do Tick() end
    assert(lost and repairs == 0, "action row recovery must wait for its host bounds")
    parentReady = true
    host:SetWidth(685)
    for _ = 1, 5 do Tick() end
    assert(row:GetTop() and row:GetWidth() == 655,
        "Add Spell row must recover its native bounds before it can be clicked")
    local first = row:GetPoint(1)
    assert(first == "TOPLEFT" and #row.points == 1)
    for _, width in ipairs({480, 900, 685}) do
        lost = true
        host:SetWidth(width)
        for _ = 1, 5 do Tick() end
        assert(row:GetTop() and row:GetWidth() == width - 30,
            "action buttons must follow the shared custom row after resize")
    end
    lost = true
    row:Hide(); row:Show()
    for _ = 1, 5 do Tick() end
    assert(row:GetTop(), "returning to a cached page must recover its action row")
    local count = repairs
    row:Hide(); row:Show()
    for _ = 1, 5 do Tick() end
    assert(repairs == count, "valid custom row bounds must not be rewritten on return")
end
widgets["Enable Spell Reminders"]:Change(true)
buttons["Power Infusion Preset"]()
assert(H.R.hosts[10060].sample.name.text == ns.L["PI Recipient"], "the first PI preset creates its preview label")
assert(H.R.Get(10060) and #H.tabs == 8 and H.activeTab == "timing",
    "adding a preset opens its named Timing editor, with a route back to creation")
assert(ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:10060") == H.feature,
    "dynamic reminders must resolve to the existing settings feature")
local routeHost = CreateFrame("Frame", nil, UIParent)
assert(H.feature.render.layout(routeHost, { providerKey = "spellReminder:10060" }) == 88
    and H.positionHost == routeHost and H.positionKey == "spellReminder:10060"
    and H.fullSettingsHost == routeHost and H.fullSettingsKey == "spellReminder:10060",
    "the real layout adapter must build anchoring controls and a settings link for the exact reminder")
assert(widgets.Reminder.enabled == true, "adding the first reminder must enable selection")
assert(widgets["Allow Estimated Early Alerts"], "adding a reminder opens its Timing controls")
H.selectTab("timing")
assert(widgets.Reminder and widgets.Reminder.db.value == 10060,
    "every child page must expose the reminder being edited and allow switching it")
assert(not widgets["Enable Spell Reminders"] and not buttons["Add Spell"],
    "child tabs must not retain global controls or creation actions")
local body = O.activeBody
local editor = body.parent
local function AssertEditorAnchorGeometry()
    local fractions = { TOPLEFT = 0, TOPRIGHT = 0, RIGHT = 0.5 }
    local expectedTop
    assert(#editor.points == 2, "the editor must retain both horizontal bounds")
    for _, anchor in ipairs(editor.points) do
        local point, parent, relativePoint, _, offsetY = unpack(anchor)
        assert(parent == content, "editor bounds must follow the settings content")
        local top = -content:GetHeight() * fractions[relativePoint] + offsetY
            + editor:GetHeight() * fractions[point]
        if expectedTop then
            assert(math.abs(top - expectedTop) < 0.01,
                "editor anchors must agree with its declared height as the scroll content grows")
        end
        expectedTop = top
    end
end
AssertEditorAnchorGeometry()
local rootHeight, editorHeight = content:GetHeight(), editor:GetHeight()
body:SetHeight(body:GetHeight() + 200)
assert(editor:GetHeight() == editorHeight + 200 and content:GetHeight() == rootHeight + 200,
    "responsive controls must grow the editor and scroll extent without changing tabs")
AssertEditorAnchorGeometry()
local _, _, _, x, y = editor:GetPoint(1)
editor:ClearAllPoints()
editor:SetPoint("TOPLEFT", content, "TOPLEFT", x, y - 50)
editor:SetPoint("TOPRIGHT", content, "TOPRIGHT", -x, y - 50)
body:SetHeight(body:GetHeight() - 100)
assert(content:GetHeight() == rootHeight + 150,
    "the scroll extent must use the editor's current offset after controls above it reflow")
AssertEditorAnchorGeometry()
local paints = H.tabPaints
local strip = body.points[1][2]
strip:SetWidth(strip:GetWidth() + 100)
assert(H.tabPaints == paints + 1, "resizing the tab strip must repaint wrapped tabs")
strip:SetHeight(strip:GetHeight() + 20)
assert(H.tabPaints == paints + 1, "changing strip height must not start a repaint loop")
assert(H.searchPage == 2 and H.searchTile == "reminders", "editor search entries target the new spell reminder tab")
widgets["Allow Estimated Early Alerts"]:Change(true)
assert(H.R.Get(10060).useEstimate)
H.selectTab("requests")
widgets["Recipient Selection"]:Change("rotation")
widgets["Player Names"]:Change("Mage-Realm, Missing, Healer-Realm")
assert(H.R.Get(10060).pi.whisper.rotation[3] == "Healer-Realm")
H.selectTab("tracking")
widgets["Alert Sound"]:Change("QUI Reminder Bell")
widgets["Sound on Party Cooldowns"]:Change(true)
widgets["Sound on Raid Cooldowns"]:Change(true)
widgets["Sound on Focus Cooldowns"]:Change(true)
assert(H.R.Get(10060).pi.partySound and H.R.Get(10060).pi.raidSound and H.R.Get(10060).pi.focusSound)
buttons["Test Alert Sound"]()
assert(H.sounds[#H.sounds] == 567458)
H.selectTab("sounds")
widgets.Voice:Change(2)
widgets["Ready Announcement"]:Change("Power Infusion is ready")
widgets["Speak When Ready"]:Change(true)
buttons["Test Voice"]()
assert(H.voice == 2 and H.speech[#H.speech] == "Power Infusion is ready")
assert(H.speechRate == 0 and H.speechVolume == 100, "voice preview uses normal rate and audible volume")
H.cooldowns[10060] = { isActive = true, isEnabled = true, startTime = 10, duration = 120 }
H.emit("SPELL_UPDATE_COOLDOWN")
H.cooldowns[10060].isActive = false
H.emit("SPELL_UPDATE_COOLDOWN")
assert(#H.speech == 2 and H.voice == 2 and H.speech[2] == "Power Infusion is ready",
    "the configured phrase and voice reach the real readiness trigger")
widgets.Voice:Change(0)
buttons["Test Voice"]()
assert(H.voice == 1 and H.speech[#H.speech] == "Power Infusion is ready",
    "default voice selection reaches the same supported TTS call")
H.selectTab("tracking")
widgets["Highlight Style"]:Change("countdown")
buttons["Preview / Drag"]()
assert(H.R.hosts[10060].sample.shown and H.R.previews[10060])
H.selectTab("general")
buttons["Innervate Preset"]()
assert(not H.R.previews[10060], "adding a different preset ends the old preview")
assert(H.R.Get(29166) and #H.tabs == 5 and H.activeTab == "timing", "PI tabs cannot leak into another spell")
assert(#widgets.Reminder.options == 2)
H.feature.onNavigate("spellReminder:10060")
assert(#H.tabs == 8 and H.activeTab == "timing" and widgets.Reminder.db.value == 10060,
    "layout navigation must select the matching reminder in the editor and dropdown")
H.feature.onNavigate("spellReminder:999999")
H.feature.onNavigate("cdmCustom_10060")
assert(widgets.Reminder.db.value == 10060, "invalid layout routes must preserve selection")
local context = { opts = {} }
H.feature.searchNavigate({ surfaceTabKey = "requests" }, context)
assert(H.activeTab == "requests" and #H.tabs == 8 and context.opts.searchRoot == O.activeBody)
widgets["Enable Whisper Requests"]:Change(true)
assert(H.R.Get(10060).pi.whisper.enabled, "search navigation selects the PI reminder")
assert(H.feature.searchNavigate({}, context) and H.activeTab == "general"
    and context.opts.searchRoot == O.activeBody and widgets["New Spell ID"] and not widgets.Reminder,
    "searching a general setting must leave the active child tab and expose the root controls")
H.selectTab("timing", 29166)
assert(H.activeTab == "timing" and #H.tabs == 5)
buttons["Delete Reminder"]()
assert(H.R.Get(29166), "deletion waits for the concrete confirmation")
H.confirmation.onAccept()
assert(not H.R.Get(29166) and #widgets.Reminder.options == 1)
assert(not ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:29166"),
    "deleting a reminder must remove its dynamic settings lookup")
H.selectTab("general")
local savedContext = { tileId = "other" }
GUI:SetSearchContext(savedContext)
O.CaptureSearch(content)
for _, widget in ipairs(allWidgets) do
    assert(type(widget.description) == "string" and widget.description ~= "",
        "every reminder setting must explain its behavior: " .. tostring(widget.key))
end
editor:ClearAllPoints()
local currentHeight = content:GetHeight()
body:SetHeight(body:GetHeight() + 1)
assert(content:GetHeight() == currentHeight, "late resize events from a retired editor must not change the active page")
assert(GUI._searchContext.tileId == "other" and H.R.Get(10060).pi.whisper.enabled,
    "search capture must preserve the real configuration and caller context")
local descriptor
function GUI:RegisterTileSurfacePages(_, value) descriptor = value; return true end
function GUI:RefreshTileSurfacePages() H.navigationRefreshes = (H.navigationRefreshes or 0) + 1 end
function GUI:InitializeNavigationSections(host)
    host._sections = {}
    function host:RegisterSection(id, label, frame)
        self._sections[#self._sections + 1] = { id = id, label = label, frame = frame }
    end
end
paints = H.tabPaints
O.Build(content)
assert(descriptor and #descriptor.getTabs() == 7 and H.tabPaints == paints,
    "spell settings use sidebar pages without creating a second horizontal tab strip")
assert(descriptor.getActiveTab() == "general" and not widgets.Reminder and widgets["Enable Spell Reminders"],
    "the parent destination opens the general controls")
assert(not descriptor.getPage(descriptor.getActiveTab())._scrollFrame,
    "the editor can be constructed before the outer page exposes its scroll frame")
content._scrollFrame = CreateFrame("ScrollFrame")
function content._scrollFrame:SetVerticalScroll(offset) self.offset = offset end
content._scrollFrame.offset = 400
local firstPage = descriptor.getPage(descriptor.getActiveTab())
assert(firstPage._contentBody == O.activeBody and firstPage._scrollFrame == content._scrollFrame
    and #firstPage._contentBody._sections > 0, "section jumps use the active editor body and owning page scroll")
assert(firstPage == O.activeBody and type(firstPage:GetWidth()) == "number" and firstPage:GetHeight() > 0,
    "navigation layout readiness receives a real frame with dimensions")
assert(descriptor.selectTab("appearance") and widgets["Icon Glow"] and widgets.Animation,
    "Appearance must render Glow and Animation controls on its own page")
assert(content._scrollFrame.offset == 0, "changing pages must reveal the new page from its top")
assert(widgets.Reminder and widgets.Reminder.db.value == 10060 and not widgets["New Spell ID"] and not widgets["Enable Spell Reminders"]
    and not buttons["Add Spell"] and buttons["Delete Reminder"],
    "Appearance exposes named deletion without retaining collection creation controls")
assert(widgets.Font.options[1] and widgets.Font.options[1].value == ""
    and widgets.Font.options[1].text == "Global Font",
    "inherited reminder font must have a visible, selectable default")
local appearance = descriptor.getPage("appearance")
assert(#appearance._sections == 3 and appearance._sections[2].id == "Glow and Animation",
    "Appearance navigation must expose its actual sections, including Glow and Animation")
assert(descriptor.selectRoot() and descriptor.getActiveTab() == "general"
    and descriptor.getPage("general") == O.activeBody and not descriptor.getPage("appearance")
    and not widgets.Reminder and widgets["New Spell ID"] and not widgets["Icon Glow"],
    "clicking the parent returns to general controls and retires Appearance")
appearance:ClearAllPoints()
local generalHeight = content:GetHeight()
appearance:SetHeight(appearance:GetHeight() + 1)
assert(content:GetHeight() == generalHeight, "a retired child page cannot resize or break the active root page")
assert(not descriptor.selectRoot(), "reselecting the root must not rebuild it")
assert(H.feature.searchNavigate({ surfaceTabKey = "appearance" }, context)
    and descriptor.getActiveTab() == "appearance" and widgets["Icon Glow"] and widgets.Animation
    and context.opts.searchRoot == O.activeBody and widgets.Reminder.db.value == 10060,
    "Appearance search results open the child settings without the general controls")
do
    local page, edit, builds = O.activeBody, widgets["Reminder Label"], H.editorBuilds
    edit:SetText("Unsubmitted label")
    edit.focused = true
    content._scrollFrame.offset = 123
    assert(H.feature.searchNavigate({surfaceTabKey = "appearance"}, context), "same-tab search remains a handled route")
    assert(H.editorBuilds == builds and O.activeBody == page and widgets["Reminder Label"] == edit
        and edit.text == "Unsubmitted label" and edit.focused and content._scrollFrame.offset == 123,
        "same-tab search must retain the actual editor, unsaved input, focus, and scroll")
    assert(not H.feature.searchNavigate({surfaceTabKey = "missing"}, context)
        and H.editorBuilds == builds and O.activeBody == page, "invalid search cannot rebuild or change tabs")
end
H.feature.onNavigate("spellReminder:10060")
assert(descriptor.getActiveTab() == "timing" and widgets.Reminder.db.value == 10060,
    "a layout link must open the exact reminder editor")
assert(descriptor.selectTab("sounds") and descriptor.getActiveTab() == "sounds"
    and descriptor.getPage("sounds")._contentBody == O.activeBody and descriptor.getPage("timing") == nil,
    "sidebar navigation renders the requested tab and retires previous section frames")
assert(not descriptor.selectTab("sounds") and not descriptor.selectTab("missing"),
    "current and unavailable navigation destinations must not rebuild the editor")
assert(descriptor.selectTab("general") and widgets["New Spell ID"] and not widgets.Reminder,
    "history can restore the general page using the normal surface key")
buttons["Innervate Preset"]()
assert(#descriptor.getTabs() == 4 and not descriptor.selectTab("requests"),
    "PI-only sidebar pages remain unavailable for another selected spell")
assert(#H.feature.getNavigationTabs() == 4, "cold navigation respects an explicitly selected non-PI reminder")
widgets.Reminder:Change(10060)
assert(#descriptor.getTabs() == 7 and descriptor.selectTab("requests") and H.navigationRefreshes > 0,
    "changing the selected spell refreshes its dynamic sidebar pages")
local requests = H.feature.getNavigationTabs()[7]
H.R.Get(10060).pi.whisper.mode = "rotation"
assert(requests.isSectionAvailable("Rotation Order") and not requests.isSectionAvailable("Priority Order"),
    "rotation requests only expose their available section")
H.R.Get(10060).pi.whisper.mode = "priority"
assert(requests.isSectionAvailable("Priority Order") and not requests.isSectionAvailable("Rotation Order")
    and requests.isSectionAvailable("Whisper Requests"), "priority requests preserve common sections and omit rotation")
do
    local currentEditor = O.activeBody:GetParent()
    local parentReady, lostBounds, repairs, persistentLoss = false, true, 0, false
    function content:GetTop() if parentReady then return 900 end end
    function currentEditor:GetTop()
        if not lostBounds and content:GetTop() then return content:GetTop() + select(5, self:GetPoint(1)) end
    end
    local setPoint = currentEditor.SetPoint
    function currentEditor:SetPoint(...)
        setPoint(self, ...)
        lostBounds, repairs = persistentLoss, repairs + 1
    end
    local function Tick()
        if currentEditor.scripts.OnUpdate then currentEditor.scripts.OnUpdate(currentEditor) end
    end
    local function Settle()
        for _ = 1, 6 do Tick() end
        assert(currentEditor:GetTop() and not currentEditor.scripts.OnUpdate,
            "editor bounds recovery must restore position and stop once valid")
    end
    content:SetWidth(685)
    currentEditor:SetWidth(655)
    currentEditor:Hide()
    assert(not currentEditor.scripts.OnUpdate, "hidden editors must cancel pending bounds verification")
    currentEditor:Show()
    assert(currentEditor.scripts.OnUpdate,
        "showing the cached editor must rearm bounds recovery after native position loss")
    for _ = 1, 4 do Tick() end
    assert(lostBounds and repairs == 0 and currentEditor.scripts.OnUpdate,
        "recovery must wait for its parent to have native bounds")
    parentReady = true
    Tick()
    assert(lostBounds, "recovery must let parent layout settle before repairing the editor")
    Settle()
    assert(#currentEditor.points == 1 and currentEditor:GetWidth() == 685,
        "native bounds recovery must keep the top anchor and use the parent's inset width")
    local page = O.activeBody
    for _ = 1, 2 do
        lostBounds = true
        currentEditor:Hide()
        currentEditor:Show()
        Settle()
        assert(O.activeBody == page and O.activeBody:GetParent() == currentEditor,
            "returning to a cached module must recover without rebuilding its active page")
    end
    for _, key in ipairs({"appearance", "buffs", "appearance", "buffs"}) do
        lostBounds = true
        assert(descriptor.selectTab(key))
        Settle()
        assert(O.activeBody:GetParent() == currentEditor and descriptor.getPage(key) == O.activeBody,
            "child page rebuilds must recover the retained editor on every visit")
    end
    for _, width in ipairs({900, 480, 685}) do
        lostBounds = true
        content:SetWidth(width)
        Settle()
        assert(currentEditor:GetWidth() == width,
            "a recovered editor must retain responsive inset sizing")
    end
    local repairCount = repairs
    currentEditor:Hide()
    currentEditor:Show()
    Settle()
    assert(repairs == repairCount, "valid editor bounds must not be rewritten on return")
    persistentLoss, lostBounds = true, true
    for _ = 1, 2 do
        repairCount = repairs
        currentEditor:Hide()
        currentEditor:Show()
        for _ = 1, 10 do Tick() end
        assert(not currentEditor:GetTop() and repairs == repairCount + 1 and not currentEditor.scripts.OnUpdate,
            "failed native recovery must stop after one repair until another activation")
    end
    persistentLoss = false
    currentEditor:Hide()
    currentEditor:Show()
    Settle()
end
-- The inner tab host can lose native bounds independently of its editor.
-- Reuse shared custom-host recovery on later resizes, preserving the active tab.
do
    local page, editor = O.activeBody, O.activeBody:GetParent()
    local lost, setWidth = false, page.SetWidth
    function page:GetTop() if not lost then return 800 end end
    function page:SetWidth(width) lost = false; setWidth(self, width) end
    for _, width in ipairs({900, 480, 685}) do
        lost = true
        editor:SetWidth(width)
        for _ = 1, 6 do if page.scripts.OnUpdate then page.scripts.OnUpdate(page) end end
        assert(not lost and page:GetWidth() == width and #page.points == 1,
            "resizing must recover the reminder tab host without blank content")
        assert(O.activeBody == page and descriptor.getPage("buffs") == page,
            "host recovery must retain the selected tab and its controls")
    end
end
-- Context remains explicit while moving between existing reminder editors.
H.feature.onNavigate("spellReminder:10060")
assert(descriptor.getContextLabel and descriptor.getContextLabel() == ns.SpellReminderPresentation.Name(H.R.Get(10060)),
    "mounted sidebar must identify its selected reminder")
assert(H.feature.getNavigationContextLabel() == descriptor.getContextLabel(),
    "cold and mounted navigation must name the same selected reminder")
descriptor.selectTab("timing")
local piReady = H.R.Get(10060).readyDuration
widgets.Reminder:Change(29166)
assert(descriptor.getActiveTab() == "timing" and widgets.Reminder.db.value == 29166,
    "changing reminders keeps a compatible editing tab")
widgets["Hide After Ready"]:Change(piReady + 9)
assert(H.R.Get(29166).readyDuration == piReady + 9 and H.R.Get(10060).readyDuration == piReady,
    "editing after a selector change must write only to the named reminder")
widgets.Reminder:Change(10060)
assert(widgets["Hide After Ready"].db == H.R.Get(10060), "switching back binds the original reminder")
assert(descriptor.selectTab("requests"))
widgets.Reminder:Change(29166)
assert(descriptor.getActiveTab() == "timing" and not widgets["Enable Whisper Requests"],
    "switching away from PI on a PI-only tab must select a supported editor")
assert(descriptor.getContextLabel() == ns.SpellReminderPresentation.Name(H.R.Get(29166)),
    "navigation context must change with the actual binding")
print("OK: named reminder context, selector transitions, and isolated editing")

ns.Settings.Registry:UnregisterLookupKey("spellRemindersPage", "spellReminder:10060")
assert(loadfile(os.getenv("QUI_REMINDER_OPTIONS_SOURCE") or "QUI_Reminders/spell_reminders/settings/spell_reminders.lua"))("QUI", ns)
assert(ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:10060") == ns.Settings.Registry:GetFeature("spellRemindersPage"),
    "loading settings after the runtime must connect existing reminders to their layout route")
local coldFeature = ns.Settings.Registry:GetFeature("spellRemindersPage")
local name = ns.SpellReminderPresentation.Name
ns.SpellReminderPresentation.Name = function(config) return config.pi and "Z PI" or "A Innervate" end
local reminderMetatable = getmetatable(H.db.reminders)
setmetatable(H.db.reminders, { __index = function(_, key)
    assert(key ~= nil, "cold navigation must not resolve a missing selection through a nil table key")
end })
assert(#coldFeature.getNavigationTabs() == 4, "cold default navigation uses the first reminder alphabetically")
setmetatable(H.db.reminders, reminderMetatable)
ns.SpellReminderPresentation.Name = function(config) return config.pi and "A PI" or "Z Innervate" end
assert(#coldFeature.getNavigationTabs() == 7, "reading cold navigation must not pin an implicit reminder selection")
local coldBuilds = H.editorBuilds
assert(coldFeature.searchNavigate({surfaceTabKey = "appearance"}, {opts = {}})
    and H.editorBuilds == coldBuilds, "cold search selects its tab without mounting the editor")
ns.SpellReminderOptions.Build(content)
assert(descriptor.getActiveTab() == "appearance" and widgets["Reminder Label"],
    "first mount retains the requested cold tab")
assert(coldFeature.searchNavigate({}, {opts = {}}), "cold-selected editor can return through shared root selection")
assert(#descriptor.getTabs() == #coldFeature.getNavigationTabs() and descriptor.getActiveContext() == nil,
    "initial editor and cold navigation resolve the same alphabetically selected reminder")
ns.SpellReminderPresentation.Name = name
do
    local route = {tileId = "alternate_reminders", subPageIndex = 7, featureId = "spellRemindersPage",
        tabName = "Alternate Reminders", subTabName = "Relocated Spells"}
    GUI:SetSearchContext(route)
    ns.Settings.SearchRoute.With(route, ns.SpellReminderOptions.Build, content)
    local current = ns.SpellReminderOptions
    GUI:SetSearchContext({tileId = "unrelated", subPageIndex = 3})
    local before = H.editorBuilds
    assert(descriptor.selectTab("appearance") and H.editorBuilds == before + 1,
        "a different sidebar tab builds exactly once")
    assert(H.searchTile == route.tileId and H.searchPage == 7,
        "later reminder rebuilds must retain their registered host after its route scope exits")
    local page, editor = current.activeBody, current.activeBody:GetParent()
    editor:Hide(); editor:Show()
    assert(coldFeature.searchNavigate({surfaceTabKey = "appearance"}, {opts = {}})
        and current.activeBody == page and H.editorBuilds == before + 1,
        "returning to the current hidden/shown page must preserve its editor")
end
print("OK: spell reminder presets, editor controls, preview, deletion and search navigation")


-- Deleting the last mounted reminder returns to creation, including stale links.
do
    local ids = {}
    for id in pairs(H.db.reminders) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        descriptor.selectTab("timing", id)
        buttons["Delete Reminder"]()
        assert(H.confirmation.message:find(ns.SpellReminderPresentation.Name(H.R.Get(id)), 1, true),
            "deletion confirmation must identify the exact reminder")
        H.confirmation.onAccept()
    end
    assert(descriptor.getActiveTab() == "general" and descriptor.getActiveContext() == nil
        and #descriptor.getNavigationContexts() == 0 and widgets["New Spell ID"] and buttons["Add Spell"],
        "deleting the last reminder must show an actionable creation page")
    assert(not descriptor.selectTab("timing", ids[1]) and descriptor.getActiveTab() == "general",
        "a stale deleted reminder route must not edit another reminder")
    widgets["New Spell ID"]:Change("29166")
    buttons["Add Spell"]()
    assert(descriptor.getActiveContext() == 29166 and descriptor.getActiveTab() == "timing"
        and #descriptor.getNavigationContexts() == 1, "creation must work again after deleting every reminder")
end
print("OK: last-reminder deletion, named confirmation, stale routes, and recreation")
