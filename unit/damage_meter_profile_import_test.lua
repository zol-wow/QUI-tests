local env = dofile("tools/_addon_env.lua")
local h = env.BuildHarness()
local core = h.QUICore

for _, meterType in ipairs({ 0, 4, false }) do
    h.ns.Client = { flavor = "retail" }
    h.db.profile.damageMeter.native.windows[1].mythicStartDMType = meterType
    local exported = assert(core:ExportProfileToString())
    local selected = assert(core:ExportProfileSelectionToString({ "damageMeter" }))

    for _, flavor in ipairs({ "retail", "forever" }) do
        h.ns.Client = { flavor = flavor }
        local ok, detail = core:AnalyzeProfileImportString(exported)
        assert(ok, "valid M+ meter choice must pass analysis on " .. flavor .. ": "
            .. tostring(type(detail) == "table" and detail.summary or detail))
        local sanitized, payload, _, stripped, err = core:SanitizeProfileImportString(exported)
        assert(sanitized and #stripped == 0, "valid meter choice must not be stripped: " .. tostring(err))
        assert(payload.damageMeter.native.windows[1].mythicStartDMType == meterType,
            "sanitization must preserve numeric meter choices and Off")

        h.db.profile.damageMeter.native.windows[1].mythicStartDMType = 9
        ok, err = core:ImportProfileFromString(exported, "MeterImport")
        assert(ok, tostring(err))
        assert(h.db.profile.damageMeter.native.windows[1].mythicStartDMType == meterType,
            "full import must preserve the M+ meter choice")

        h.db.profile.damageMeter.native.windows[1].mythicStartDMType = 9
        ok, err = core:ImportProfileSelectionFromString(selected, { "damageMeter" })
        assert(ok, tostring(err))
        assert(h.db.profile.damageMeter.native.windows[1].mythicStartDMType == meterType,
            "selected import must preserve the M+ meter choice")
    end
end

local before = h.db:GetCurrentProfile()
for _, window in ipairs({
    { mythicStartDMType = "4" },
    { mythicStartDMType = {} },
    { mythicStartDMType = 4, hideTimer = 1 },
    { mythicStartDMType = 4, autoCurrentOnCombat = 1 },
}) do
    local ok, err = core:ImportProfileFromValidatedPayload({
        damageMeter = { native = { windows = { [1] = window } } },
    }, "InvalidMeter")
    assert(not ok and err:find("incompatible setting types", 1, true),
        "the meter exception must still reject invalid types and unrelated boolean fields")
    assert(h.db:GetCurrentProfile() == before, "invalid settings must not switch profiles")
end

print("OK damage_meter_profile_import_test")
