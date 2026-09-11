local files = assert(io.popen("find QUI_CDM QUI_Debug/cdm_debug.lua QUI_Debug/cdm_taint_trace.lua -type f -name '*.lua'"))
local forbidden = {
    "CollectReadableAuras", "ReadAurasByInstanceID",
    "ReadAuraDurationByInstanceID", "ReadAuraApplicationDisplayCount",
    "GetCooldownAuraBySpellID", "ApplyCooldownFromAura",
    "AuraUtil.ForEachAura", "FilterStringUsable",
    "scanner.IsSpellActive", "scanner.IsItemActive",
}
for path in files:lines() do
    local handle = assert(io.open(path, "r"))
    local source = handle:read("*a")
    handle:close()
    local querySource = source:gsub("C_UnitAuras%.AddAuraSound", "NativeSoundRegistration")
        :gsub("C_UnitAuras%.RemoveAuraSound", "NativeSoundRemoval")
    assert(not querySource:find("C_UnitAuras[%.%[]"), path .. " retains direct aura API access")
    for _, name in ipairs(forbidden) do
        assert(not source:find(name, 1, true), path .. " retains addon aura dependency " .. name)
    end
end
files:close()

local baseLoadfile, baseLoadstring = loadfile, loadstring
for _, test in ipairs({
    "cdm_spelldata_ignores_learned_cast_to_aura_test.lua",
    "cdm_spelldata_aura_boundary_test.lua",
    "cdm_managed_aura_mirrors_test.lua",
    "cdm_bars_native_aura_test.lua",
    "cdm_custom_aura_runs_test.lua",
    "cdm_native_sound_registration_test.lua",
    "cdm_reanchor_runtime_aura_mirror_test.lua",
    "cdm_reanchor_native_buff_aura_test.lua",
    "aura_displays_hud_visibility_test.lua",
}) do
    local accesses, output = {}, {}
    local api = setmetatable({}, {
        __index = function(_, name)
            if name == "AddAuraSound" or name == "RemoveAuraSound" then return function() end end
            accesses[#accesses + 1] = name
            error("CDM accessed C_UnitAuras." .. tostring(name))
        end,
    })
    local env = {}
    for key, value in pairs(_G) do
        if key ~= "C_UnitAuras" then env[key] = value end
    end
    setmetatable(env, {
        __index = function(_, key)
            if key == "C_UnitAuras" then return api end
            return rawget(_G, key)
        end,
        __newindex = function(self, key, value)
            if key == "C_UnitAuras" then
                if type(value) == "table" then
                    for _, method in ipairs({ "AddAuraSound", "RemoveAuraSound" }) do
                        rawset(api, method, rawget(value, method))
                    end
                end
            else
                rawset(self, key, value)
            end
        end,
    })
    env._G = env
    env.print = function(...)
        local values = { ... }
        for i = 1, #values do values[i] = tostring(values[i]) end
        output[#output + 1] = table.concat(values, " ")
    end
    env.os = setmetatable({ exit = function(code) error("test exited: " .. tostring(code)) end }, { __index = os })
    env.loadfile = function(path)
        local chunk, err = baseLoadfile(path)
        return chunk and setfenv(chunk, env), err
    end
    env.loadstring = function(source, name)
        local chunk, err = baseLoadstring(source, name)
        return chunk and setfenv(chunk, env), err
    end
    env.dofile = function(path) return assert(env.loadfile(path))() end
    local ok, err = pcall(env.dofile, "tests/unit/" .. test)
    assert(#accesses == 0, test .. " accessed C_UnitAuras: " .. table.concat(accesses, ", "))
    assert(ok, test .. ": " .. tostring(err) .. "\n" .. table.concat(output, "\n"))
end

print("OK: cdm_no_unit_aura_api_test")
