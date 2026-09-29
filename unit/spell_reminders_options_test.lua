-- Exercise the real editor callbacks against the reminder runtime and a small
-- widget boundary. Search capture also executes these builders with QUI's UI.
local H = (dofile("tests/helpers/spell_reminders.lua"))({ deferRuntime = true })
local ns, widgets, buttons = H.ns, {}, {}
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
function GUI:CreateFormCheckbox(parent, _, key, db, change) return Widget(parent, key, db, change) end
function GUI:CreateFormEditBox(parent, _, key, db, change) return Widget(parent, key, db, change) end
function GUI:CreateFormDropdown(parent, _, options, key, db, change)
    local widget = Widget(parent, key, db, change)
    widget.options = options
    return widget
end
function GUI:CreateFormSlider(parent, _, _, _, _, key, db, change) return Widget(parent, key, db, change) end
function GUI:CreateFormColorPicker(parent, _, key, db, change) return Widget(parent, key, db, change) end
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
            placeCustom = function(_, height) y = y - height end,
            getY = function() return y end,
            finish = function() host:SetHeight(-y); return -y end,
        }
    end,
}
ns.Settings = {
    Util = { ShallowCopy = Copy },
    Registry = { RegisterFeature = function(_, feature) H.feature = feature end },
    Schema = { Feature = function(value) return value end, Section = function(value) return value end },
    FullSurface = { CreateTabStrip = function(parent)
        return CreateFrame("Frame", nil, parent), function(tabs, active, callback)
            H.tabs, H.activeTab, H.selectTab = tabs, active, callback
        end
    end },
}
assert(loadfile("QUI_Reminders/spell_reminders/settings/spell_reminders.lua"))("QUI", ns)
assert(loadfile("QUI_Reminders/spell_reminders/settings/spell_reminder_tracking.lua"))("QUI", ns)
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
widgets["Enable Spell Reminders"]:Change(true)
buttons["Power Infusion Preset"]()
assert(H.R.hosts[10060].sample.name.text == ns.L["PI Recipient"], "the first PI preset creates its preview label")
assert(H.R.Get(10060) and #H.tabs == 7 and H.activeTab == "timing")
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
local savedContext = { tileId = "other" }
GUI:SetSearchContext(savedContext)
O.CaptureSearch(content)
assert(GUI._searchContext.tileId == "other" and H.R.Get(10060).pi.whisper.enabled,
    "search capture must preserve the real configuration and caller context")
print("OK: spell reminder presets, editor controls, preview, deletion and search navigation")
