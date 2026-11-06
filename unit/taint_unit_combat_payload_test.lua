local Analyzer = dofile("tests/taint/analyzer.lua")
local Registry = dofile("tests/taint/registry.lua")
local Config = dofile("tests/taint/config.lua")
local IndexLoad = dofile("tests/taint/index_load.lua")

local cfg = Config.loadFromFile("tests/.taintrc.lua")
local cases = {
    {
        name = "amount arithmetic",
        body = "local value = amount + 1",
        count = 1,
    },
    {
        name = "readable payload neighbors",
        body = [[
            if unitTarget == "player" then end
            if combatEvent == "WOUND" then end
            if flagText == "CRITICAL" then end
            local school = schoolMask + 1
        ]],
        count = 0,
    },
    {
        name = "aura restriction bail cannot clear amount",
        body = [[
            if C_Secrets.ShouldAurasBeSecret() then return end
            local value = amount + 1
        ]],
        count = 1,
    },
    {
        name = "negative aura restriction branch cannot clear amount",
        body = [[
            if not C_Secrets.ShouldAurasBeSecret() then
                local value = amount + 1
            end
        ]],
        count = 1,
    },
}

for _, indexPath in ipairs({
    "tests/api-docs/api-index.lua",
    "tests/clients/forever/api-docs/api-index.lua",
}) do
    local registry = Registry.new()
    IndexLoad.populate(registry, dofile(indexPath), cfg)
    for eventName, params in pairs(cfg.event_payload_params) do
        registry:addSecretPayloadEvent(eventName, params)
    end
    for _, case in ipairs(cases) do
        local source = [[
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("UNIT_COMBAT")
            frame:SetScript("OnEvent", function(self, event, unitTarget, combatEvent, flagText, amount, schoolMask)
        ]] .. case.body .. [[
            end)
        ]]
        local findings, err = Analyzer.analyze(source, "modules/unit_combat.lua", registry, cfg)
        assert(findings, err)
        assert(#findings == case.count, indexPath .. ": " .. case.name
            .. ": expected " .. case.count .. " findings, got " .. #findings)
        if case.count > 0 then
            assert(findings[1].sink == "<arith>", case.name .. ": expected amount arithmetic finding")
            assert(findings[1].severity == "strict", case.name .. ": expected strict finding")
        end
    end
end

print("taint_unit_combat_payload_test: passed")
