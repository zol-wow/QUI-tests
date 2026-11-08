local function Quote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end
local temporary = os.tmpname()
local interpreter, marker, log = temporary .. "' lua", temporary .. ".merged", temporary .. ".log"
local script = [=[#!/usr/bin/env bash
case "$2" in
    --shard)
        [ "${QUI_INVENTORY_RUNNER_TEST:-}" = fail ] && exit 7
        [ "${QUI_INVENTORY_RUNNER_TEST:-}" = missing ] && exit 0
        printf 'return {}\n' > "$5"
        ;;
    --merge)
        [ "${QUI_INVENTORY_RUNNER_TEST:-}" = merge-fail ] && exit 9
        count="$3"
        shift 3
        [ "$#" = "$count" ] || exit 10
        for report in "$@"; do [ -s "$report" ] || exit 11; done
        printf '%s' "$count" > MARKER
        ;;
    *) exit 12 ;;
esac
]=]
local file = assert(io.open(interpreter, "w"))
file:write((script:gsub("MARKER", function() return Quote(marker) end)))
file:close()
assert(os.execute("chmod +x " .. Quote(interpreter)) == 0)
local ok, err = pcall(function()
    for _, case in ipairs({{"", 1, true}, {"", 4, true}, {"", 32, true}, {"fail", 4, false},
        {"missing", 4, false}, {"merge-fail", 4, false}, {"", 0, false}}) do
        os.remove(marker)
        local result = os.execute("QUI_INVENTORY_RUNNER_TEST=" .. Quote(case[1]) .. " LUA=" .. Quote(interpreter)
            .. " JOBS=" .. case[2] .. " bash tools/test_settings_inventory.sh >" .. Quote(log) .. " 2>&1")
        assert((result == 0) == case[3], "runner must propagate worker/report/merge failures: " .. case[1])
        local merged = io.open(marker)
        if case[3] then
            assert(merged and merged:read("*a") == tostring(math.min(case[2], 4)), "worker count must honor JOBS and cap at four")
        else
            assert(not merged, "failed/incomplete workers must not produce a successful merge")
        end
        if merged then merged:close() end
    end
    local previous = arg
    arg = {[-1] = interpreter}
    local launched, launchError = pcall(dofile, "tests/unit/settings_controls_inventory_test.lua")
    arg = previous
    assert(launched, "default entrypoint must quote interpreter paths: " .. tostring(launchError))
end)
for _, path in ipairs({temporary, interpreter, marker, log}) do os.remove(path) end
assert(ok, err)
print("OK: inventory process count, failure propagation, and interpreter quoting")
