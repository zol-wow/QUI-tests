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
    MakeLayout = function(host)
        local y = 0
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
                local layout = realLayoutNS.QUI_SettingsLayoutShared.MakeLayout(host, nil, y)
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
assert(#H.feature.getNavigationTabs() == 0, "cold navigation cannot expose tabs without a reminder")
O.Build(content)
assert(#widgets.Reminder.options == 0, "an empty profile opens without adding reminders")
assert(widgets.Reminder.enabled == false and widgets.Reminder.placeholder == "No reminders yet",
    "an empty reminder selector must explain its empty state and disable selection")
widgets["Enable Spell Reminders"]:Change(true)
buttons["Power Infusion Preset"]()
assert(H.R.hosts[10060].sample.name.text == ns.L["PI Recipient"], "the first PI preset creates its preview label")
assert(H.R.Get(10060) and #H.tabs == 8 and H.activeTab == "general",
    "adding a preset stays on its general page, with a fallback route back to General")
assert(ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:10060") == H.feature,
    "dynamic reminders must resolve to the existing settings feature")
local routeHost = CreateFrame("Frame", nil, UIParent)
assert(H.feature.render.layout(routeHost, { providerKey = "spellReminder:10060" }) == 88
    and H.positionHost == routeHost and H.positionKey == "spellReminder:10060"
    and H.fullSettingsHost == routeHost and H.fullSettingsKey == "spellReminder:10060",
    "the real layout adapter must build anchoring controls and a settings link for the exact reminder")
assert(widgets.Reminder.enabled == true, "adding the first reminder must enable selection")
assert(not widgets["Allow Estimated Early Alerts"], "general controls do not embed the timing page")
H.selectTab("timing")
assert(not widgets.Reminder and not widgets["Enable Spell Reminders"] and not buttons["Add Spell"],
    "child tabs must not retain the root's general controls above their settings")
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
assert(H.R.Get(29166) and #H.tabs == 5 and H.activeTab == "general", "PI tabs cannot leak into another spell")
assert(#widgets.Reminder.options == 2)
H.feature.onNavigate("spellReminder:10060")
assert(#H.tabs == 8 and H.activeTab == "general" and widgets.Reminder.db.value == 10060,
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
    and context.opts.searchRoot == O.activeBody and widgets.Reminder,
    "searching a general setting must leave the active child tab and expose the root controls")
widgets.Reminder:Change(29166)
assert(H.activeTab == "general" and #H.tabs == 5)
buttons["Delete Reminder"]()
assert(H.R.Get(29166), "deletion waits for the concrete confirmation")
H.confirmation.onAccept()
assert(not H.R.Get(29166) and #widgets.Reminder.options == 1)
assert(not ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:29166"),
    "deleting a reminder must remove its dynamic settings lookup")
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
assert(descriptor.getActiveTab() == "general" and widgets.Reminder and widgets["Enable Spell Reminders"],
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
assert(not widgets.Reminder and not widgets["New Spell ID"] and not widgets["Enable Spell Reminders"]
    and not buttons["Add Spell"] and not buttons["Delete Reminder"],
    "Appearance cannot retain general controls or reminder management actions")
local appearance = descriptor.getPage("appearance")
assert(#appearance._sections == 3 and appearance._sections[2].id == "Glow and Animation",
    "Appearance navigation must expose its actual sections, including Glow and Animation")
assert(descriptor.selectRoot() and descriptor.getActiveTab() == "general"
    and descriptor.getPage("general") == O.activeBody and not descriptor.getPage("appearance")
    and widgets.Reminder and not widgets["Icon Glow"],
    "clicking the parent returns to general controls and retires Appearance")
appearance:ClearAllPoints()
local generalHeight = content:GetHeight()
appearance:SetHeight(appearance:GetHeight() + 1)
assert(content:GetHeight() == generalHeight, "a retired child page cannot resize or break the active root page")
assert(not descriptor.selectRoot(), "reselecting the root must not rebuild it")
assert(H.feature.searchNavigate({ surfaceTabKey = "appearance" }, context)
    and descriptor.getActiveTab() == "appearance" and widgets["Icon Glow"] and widgets.Animation
    and context.opts.searchRoot == O.activeBody and not widgets.Reminder,
    "Appearance search results open the child settings without the general controls")
H.feature.onNavigate("spellReminder:10060")
assert(descriptor.getActiveTab() == "general" and widgets.Reminder.db.value == 10060,
    "a layout link for the already selected reminder must still return to its general page")
assert(descriptor.selectTab("sounds") and descriptor.getActiveTab() == "sounds"
    and descriptor.getPage("sounds")._contentBody == O.activeBody and descriptor.getPage("timing") == nil,
    "sidebar navigation renders the requested tab and retires previous section frames")
assert(not descriptor.selectTab("sounds") and not descriptor.selectTab("missing"),
    "current and unavailable navigation destinations must not rebuild the editor")
assert(descriptor.selectTab("general") and widgets.Reminder,
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
    local setPoint, show, hide = currentEditor.SetPoint, currentEditor.Show, currentEditor.Hide
    function currentEditor:SetPoint(...)
        setPoint(self, ...)
        lostBounds, repairs = persistentLoss, repairs + 1
    end
    function currentEditor:Show()
        local wasShown = self:IsShown()
        show(self)
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function currentEditor:Hide()
        local wasShown = self:IsShown()
        hide(self)
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
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
    assert(#currentEditor.points == 1 and currentEditor:GetWidth() == 655,
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
        assert(currentEditor:GetWidth() == width - 30,
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
ns.SpellReminderOptions.Build(content)
assert(#descriptor.getTabs() == #coldFeature.getNavigationTabs() and widgets.Reminder.db.value == 10060,
    "initial editor and cold navigation resolve the same alphabetically selected reminder")
ns.SpellReminderPresentation.Name = name
print("OK: spell reminder presets, editor controls, preview, deletion and search navigation")
