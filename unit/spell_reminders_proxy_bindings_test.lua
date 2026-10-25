local handle = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = handle:read("*a")
handle:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI = QUI.GUI
local ns
for index = 1, math.huge do
    local name, value = debug.getupvalue(GUI.EnsureSearchCacheLoaded, index)
    if not name then break end
    if name == "ns" then ns = value; break end
end
assert(ns)
assert(loadfile("QUI_Options/search_cache.lua"))("QUI", ns)
assert(loadfile(os.getenv("QUI_REMINDER_OPTIONS_SOURCE") or "QUI_Reminders/spell_reminders/settings/spell_reminders.lua"))("QUI", ns)
assert(loadfile(os.getenv("QUI_REMINDER_TRACKING_SOURCE") or "QUI_Reminders/spell_reminders/settings/spell_reminder_tracking.lua"))("QUI", ns)
_G.C_Spell = { GetSpellInfo = function(id) return { name = "Buff " .. id } end }
local config = ns.SpellReminderModel.New(10060)
QUI.db.profile.spellReminders = { enabled = true, reminders = { [10060] = config } }
local refreshes, rebuilds = 0, 0
ns.SpellReminders.Refresh = function() refreshes = refreshes + 1 end
local pins = ns.Settings.Pins
local resolve, misses = pins.ResolveProfileTablePath, 0
function pins:ResolveProfileTablePath(target, db)
    local path = resolve(self, target, db)
    if path == nil then misses = misses + 1 end
    return path
end
local widgets, rows = {}, 0
local buildRow = ns.QUI_Options.BuildSettingRow
ns.QUI_Options.BuildSettingRow = function(parent, label, widget, ...)
    widgets[label], rows = widget, rows + 1
    return buildRow(parent, label, widget, ...)
end
local function Render()
    widgets, rows = {}, 0
    local host = CreateFrame("Frame")
    host:SetWidth(760)
    ns.SpellReminderOptions.RenderTab("buffs", host, config, function() rebuilds = rebuilds + 1 end)
    assert(misses == 0, "temporary buff controls must not search the saved profile for nonexistent pin paths: " .. misses)
end
Render()
assert(rows == 32 and widgets["Buff 51271  51271"] and widgets["Buff IDs"],
    "the optimized page must retain all catalog buffs and list controls")
local separate = widgets["Separate Buffs by Context"]
assert(separate._syncDBTable == config.pi and type(separate._quiPinBinding.path) == "string",
    "the saved context option must retain normal widget synchronization and pin binding")
widgets["Buff 51271  51271"].SetValue(false)
assert(config.pi.spells[51271] == false and refreshes == 1,
    "the shared-list proxy must still save and apply buff selection")
separate.SetValue(true)
assert(config.pi.separateBuffs and rebuilds == 1,
    "the real saved option must rebuild the context selector")
Render()
assert(rows == 33, "separate lists must expose their context selector")
widgets["Edit Buff List"].SetValue("raid")
assert(rebuilds == 2, "changing context must rebuild its buff controls")
Render()
widgets["Buff 51271  51271"].SetValue(true)
assert(config.pi.spells[51271] == false and config.pi.spellScopes[51271].raid == true,
    "context selection must write its override without changing the default list")
widgets["Buff IDs"].SetValue("12345, 12345, 67890")
assert(#config.pi.customSpells == 2 and config.pi.customSpells[1] == 12345 and config.pi.customSpells[2] == 67890,
    "custom buff IDs must still validate and deduplicate before saving")
assert(rebuilds == 3 and refreshes == 4 and misses == 0,
    "proxy callbacks must apply changes without triggering saved-profile path scans")
print("OK: Tracked Buffs retains controls and writes while avoiding transient profile-path scans")
