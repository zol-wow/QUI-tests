-- Exercise the real editor callbacks against the reminder runtime and a small
-- widget boundary. Search capture also executes these builders with QUI's UI.
local H = (dofile("tests/helpers/spell_reminders.lua"))({ deferRuntime = true })
local ns, widgets, buttons = H.ns, {}, {}
local createFrame = CreateFrame
_G.CreateFrame = function(...)
    local frame = createFrame(...)
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
    return CreateFrame("Button", nil, parent)
end
function GUI:SetSearchContext(context)
    self._searchContext = context
    if context.featureId == "spellRemindersPage" then
        H.searchPage, H.searchTile = context.subPageIndex, context.tileId
    end
end
function GUI:SetSearchSection() end
function GUI:TeardownFrameTree() end
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
ns.QUI_SettingsLayoutShared = {
    BuildNinePointAnchorOptions = function() return {} end,
    MakeLayout = function(host)
        local y = 0
        return {
            headerAt = function() y = y - 30 end,
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
                frame:SetPoint("TOPLEFT", host, "TOPLEFT", 15, y)
                frame:SetHeight(height)
                y = y - height
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
O.Build(content)
assert(not widgets["Enable Spell Reminders"] and not buttons["Power Infusion Preset"],
    "a disabled module shows guidance without exposing unavailable runtime actions")
assert(not ns.SpellReminderModel and not ns.SpellReminders, "opening options does not load the module")
H.LoadRuntime()
H.db.enabled = false
O.Build(content)
assert(#widgets.Reminder.options == 0, "an empty profile opens without adding reminders")
assert(widgets.Reminder.enabled == false and widgets.Reminder.placeholder == "No reminders yet",
    "an empty reminder selector must explain its empty state and disable selection")
widgets["Enable Spell Reminders"]:Change(true)
buttons["Power Infusion Preset"]()
assert(H.R.hosts[10060].sample.name.text == ns.L["PI Recipient"], "the first PI preset creates its preview label")
assert(H.R.Get(10060) and #H.tabs == 7 and H.activeTab == "timing")
assert(ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:10060") == H.feature,
    "dynamic reminders must resolve to the existing settings feature")
local routeHost = CreateFrame("Frame", nil, UIParent)
assert(H.feature.render.layout(routeHost, { providerKey = "spellReminder:10060" }) == 88
    and H.positionHost == routeHost and H.positionKey == "spellReminder:10060"
    and H.fullSettingsHost == routeHost and H.fullSettingsKey == "spellReminder:10060",
    "the real layout adapter must build anchoring controls and a settings link for the exact reminder")
assert(widgets.Reminder.enabled == true, "adding the first reminder must enable selection")
local body = O.activeBody
local editor = body.parent
local rootHeight, editorHeight = content:GetHeight(), editor:GetHeight()
body:SetHeight(body:GetHeight() + 200)
assert(editor:GetHeight() == editorHeight + 200 and content:GetHeight() == rootHeight + 200,
    "responsive controls must grow the editor and scroll extent without changing tabs")
local _, _, _, x, y = editor:GetPoint(1)
editor:ClearAllPoints()
editor:SetPoint("TOPLEFT", content, "TOPLEFT", x, y - 50)
body:SetHeight(body:GetHeight() - 100)
assert(content:GetHeight() == rootHeight + 150,
    "the scroll extent must use the editor's current offset after controls above it reflow")
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
buttons["Innervate Preset"]()
assert(not H.R.previews[10060], "adding a different preset ends the old preview")
assert(H.R.Get(29166) and #H.tabs == 4 and H.activeTab == "timing", "PI tabs cannot leak into another spell")
assert(#widgets.Reminder.options == 2)
H.feature.onNavigate("spellReminder:10060")
assert(#H.tabs == 7 and widgets.Reminder.displayedValue == 10060,
    "layout navigation must select the matching reminder in the editor and dropdown")
H.feature.onNavigate("spellReminder:999999")
H.feature.onNavigate("cdmCustom_10060")
assert(widgets.Reminder.displayedValue == 10060, "invalid layout routes must preserve selection")
local context = { opts = {} }
H.feature.searchNavigate({ surfaceTabKey = "requests" }, context)
assert(H.activeTab == "requests" and #H.tabs == 7 and context.opts.searchRoot == O.activeBody)
widgets["Enable Whisper Requests"]:Change(true)
assert(H.R.Get(10060).pi.whisper.enabled, "search navigation selects the PI reminder")
widgets.Reminder:Change(29166)
assert(H.activeTab == "timing" and #H.tabs == 4)
buttons["Delete Reminder"]()
assert(H.R.Get(29166), "deletion waits for the concrete confirmation")
H.confirmation.onAccept()
assert(not H.R.Get(29166) and #widgets.Reminder.options == 1)
assert(not ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:29166"),
    "deleting a reminder must remove its dynamic settings lookup")
local savedContext = { tileId = "other" }
GUI:SetSearchContext(savedContext)
O.CaptureSearch(content)
for label, widget in pairs(widgets) do
    assert(type(widget.description) == "string" and widget.description ~= "",
        "every reminder setting must explain its behavior: " .. label)
end
editor:ClearAllPoints()
local currentHeight = content:GetHeight()
body:SetHeight(body:GetHeight() + 1)
assert(content:GetHeight() == currentHeight, "late resize events from a retired editor must not change the active page")
assert(GUI._searchContext.tileId == "other" and H.R.Get(10060).pi.whisper.enabled,
    "search capture must preserve the real configuration and caller context")
ns.Settings.Registry:UnregisterLookupKey("spellRemindersPage", "spellReminder:10060")
assert(loadfile(os.getenv("QUI_REMINDER_OPTIONS_SOURCE") or "QUI_Reminders/spell_reminders/settings/spell_reminders.lua"))("QUI", ns)
assert(ns.Settings.Registry:GetFeatureByLookupKey("spellReminder:10060") == ns.Settings.Registry:GetFeature("spellRemindersPage"),
    "loading settings after the runtime must connect existing reminders to their layout route")
print("OK: spell reminder presets, editor controls, preview, deletion and search navigation")
