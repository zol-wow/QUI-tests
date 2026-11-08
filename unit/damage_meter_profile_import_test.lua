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

for _, deleted in ipairs({ true, false }) do
    local native = h.db.profile.damageMeter.native
    native.defaultWindowDeleted = deleted or nil
    native.windows = deleted and {} or { [1] = { damageMeterType = 4 } }
    native.windowCount = deleted and 0 or 1
    local exported = assert(core:ExportProfileToString())
    local selected = assert(core:ExportProfileSelectionToString({ "damageMeter" }))

    for _, selectionOnly in ipairs({ false, true }) do
        native = h.db.profile.damageMeter.native
        native.defaultWindowDeleted = not deleted
        native.windows = deleted and { [1] = { damageMeterType = 0 } } or {}
        local ok, err
        if selectionOnly then
            ok, err = core:ImportProfileSelectionFromString(selected, { "damageMeter" })
        else
            ok, err = core:ImportProfileFromString(exported, "MeterImport")
        end
        assert(ok, tostring(err))
        native = h.db.profile.damageMeter.native
        assert((native.defaultWindowDeleted == true) == deleted,
            "full and selected imports must replace the target's default-window deletion marker")
        if deleted then
            assert(next(native.windows) == nil and native.windowCount == 0,
                "full and selected imports must preserve an intentionally empty window collection")
        else
            assert(native.windows[1].damageMeterType == 4 and native.windowCount == 1,
                "an unmarked imported window must replace the target's deleted default window")
        end
    end
end

print("OK damage_meter_profile_import_test")
