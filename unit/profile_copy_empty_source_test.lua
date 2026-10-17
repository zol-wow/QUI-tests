local path = os.getenv("QUI_PROFILE_SOURCE") or "core/settings/content/profiles_content.lua"
local file = assert(io.open(path))
local source = file:read("*a")
file:close()
local first = assert(source:find("    local function RefreshSources()", 1, true))
local last = assert(source:find("    sourceCell = Shared.BuildSettingRow", first, true)
    or source:find("    local sourceCell = Shared.BuildSettingRow", first, true))
local build = assert((loadstring or load)("return function(GetCore, sourceDropdown, sourceCell, sourceState, RefreshPinState)\n"
    .. source:sub(first, last - 1) .. "\nreturn RefreshSources end"))()
local profiles, active = {"Only"}, "Only"
local db = {}
function db:GetProfiles() return profiles end
function db:GetCurrentProfile() return active end
local dropdown, cell, state = {}, {}, {selected = ""}
function dropdown.SetOptions(options) dropdown.options = options end
function dropdown:SetValue(value) self.value = value end
function cell:SetEnabled(enabled) self.enabled = enabled end
local refresh = build(function() return {db = db} end, dropdown, cell, state, function() end)
refresh()
assert(cell.enabled == false and #dropdown.options == 0 and dropdown.value == "",
    "source profile row must disable when only the active profile exists")
profiles = {"Only", "Other"}
refresh()
assert(cell.enabled == true and dropdown.value == "Other",
    "source profile row must re-enable when another profile becomes available")
profiles = {"Only"}
refresh()
assert(cell.enabled == false and dropdown.value == "",
    "removing the source profile must clear selection and disable the row")
print("OK: empty source profile availability")
