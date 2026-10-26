-- Independent set comparison used by the real-provider inventory and its
-- deletion mutations. Updating the reviewed baseline is an explicit action.
local M = {}
function M.Differences(required, observed)
    local changes = {}
    for key, value in pairs(required) do
        if observed[key] == nil then changes[#changes + 1] = "removed: " .. key
        elseif observed[key] ~= value then changes[#changes + 1] = "changed: " .. key end
    end
    for key in pairs(observed) do
        if required[key] == nil then changes[#changes + 1] = "unreviewed: " .. key end
    end
    table.sort(changes)
    return changes
end
function M.Missing(required, observed)
    local missing = {}
    for key in pairs(required) do if observed[key] == nil then missing[#missing + 1] = key end end
    table.sort(missing)
    return missing
end
function M.Save(path, rows)
    local keys = {}
    for key in pairs(rows) do keys[#keys + 1] = key end
    table.sort(keys)
    local file = assert(io.open(path, "w"))
    file:write("-- Reviewed real-provider inventory. Regenerate only with a reviewed control/route diff.\nreturn {\n")
    for _, key in ipairs(keys) do file:write(("    [%q] = %q,\n"):format(key, rows[key])) end
    file:write("}\n")
    file:close()
end
return M
