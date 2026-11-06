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
function M.Partition(features, baseline, count)
    assert(type(count) == "number" and count >= 1 and count % 1 == 0, "shard count must be a positive integer")
    local sharedPreview = {aurasGroupPage = "groupFramesPage"}
    local weights, ordered, loads, assignments, groups = {}, {}, {}, {}, {}
    for key in pairs(baseline) do
        local feature = key:match("^control|[^|]*|[^|]*|([^|]+)|")
        feature = sharedPreview[feature] or feature
        if feature then weights[feature] = (weights[feature] or 0) + 1 end
    end
    for _, feature in ipairs(features) do
        local group = sharedPreview[feature] or feature
        if not groups[group] then
            groups[group] = {}
            ordered[#ordered + 1] = group
        end
        groups[group][#groups[group] + 1] = feature
    end
    table.sort(ordered, function(a, b)
        local left, right = weights[a] or 1, weights[b] or 1
        if left == right then return a < b end
        return left > right
    end)
    for shard = 1, count do loads[shard] = 0 end
    for _, feature in ipairs(ordered) do
        local shard = 1
        for candidate = 2, count do
            if loads[candidate] < loads[shard] then shard = candidate end
        end
        for _, member in ipairs(groups[feature]) do assignments[member] = shard end
        loads[shard] = loads[shard] + (weights[feature] or 1)
    end
    return assignments
end

function M.Merge(reports, count)
    local merged = {expected = {}, sourceRows = {}, sourceKeysBySearchID = {}, failures = {}, destinations = 0, contexts = 0}
    local seen = {}
    for _, report in ipairs(reports) do
        assert(report.shards == count, "inconsistent shard count")
        assert(type(report.shard) == "number" and report.shard >= 1 and report.shard <= count and report.shard % 1 == 0, "invalid shard number")
        assert(not seen[report.shard], "duplicate shard " .. report.shard)
        seen[report.shard] = true
        for _, name in ipairs({"expected", "sourceRows", "sourceKeysBySearchID"}) do
            for key, value in pairs(report[name]) do
                assert(merged[name][key] == nil, "overlapping " .. name .. ": " .. key)
                merged[name][key] = value
            end
        end
        for _, err in ipairs(report.failures) do merged.failures[#merged.failures + 1] = err end
        merged.destinations = merged.destinations + report.destinations
        merged.contexts = merged.contexts + report.contexts
    end
    for shard = 1, count do assert(seen[shard], "missing shard " .. shard) end
    return merged
end

function M.Identity(context,label,path,key)
    return table.concat({context.tileId or "",tostring(context.subPageIndex or ""),context.featureId or "",

        label or "",path or "",tostring(key or "")},"|")
end
function M.Options(value)
    local parts={}
    for _,o in ipairs(value or {}) do parts[#parts+1]=tostring(o.value)..":"..tostring(o.text) end
    return table.concat(parts,";")
end

function M.Verify(report, cache, baseline)
    cache = cache or dofile("tests/helpers/search_cache.lua")(os.getenv("QUI_SETTINGS_CACHE"))
    baseline = baseline or dofile("tests/fixtures/settings_controls_inventory.lua")
    local expected, actual, failures = report.expected, {}, report.failures
    local sourceRows, sourceKeysBySearchID = report.sourceRows, report.sourceKeysBySearchID
    local destinations, contexts = report.destinations, report.contexts
    local inventory, Identity, Options = M, M.Identity, M.Options
    for _,entry in ipairs(cache.settings) do
        local d=entry.widgetDescriptor or {}
        actual[Identity(entry,entry.label,d.dbPath,d.dbKey)]=entry
    end
    local missing, count = {},0
    for id,entry in pairs(expected) do
        count=count+1
        if not actual[id] then missing[#missing+1]=id.." ["..entry.constructor.."]" end
    end
    table.sort(missing)
    print("DESTINATIONS "..destinations.." CONTEXTS "..contexts.." CONTROLS "..count.." MISSING "..#missing.." ERRORS "..#failures)
    for _,err in ipairs(failures) do print("RENDER ERROR "..err) end
    for _,id in ipairs(missing) do print("MISSING "..id) end

    local extra={}
    for id in pairs(actual) do if not expected[id] then extra[#extra+1]=id end end
    table.sort(extra)
    print("UNOBSERVED "..#extra)
    for _,id in ipairs(extra) do print("UNOBSERVED "..id) end

    local mismatches={}
    for id,e in pairs(expected) do
        local got=actual[id]
        if got then
            if (e.path and got.widgetType~=e.kind) or (not e.path and not e.kinds[got.widgetType]) then mismatches[#mismatches+1]=id.." kind "..tostring(got.widgetType).." expected "..e.kind end
            local d=got.widgetDescriptor
            if e.path then
                if e.kind=="slider" then
                    for _,k in ipairs({"min","max","step"}) do if not d or d[k]~=e[k] then mismatches[#mismatches+1]=id.." "..k end end
                elseif e.kind=="dropdown" and (not d or Options(d.options)~=e.options) then
                    mismatches[#mismatches+1]=id.." options"
                end
            end
        end
    end
    table.sort(mismatches)
    print("MISMATCHES "..#mismatches)
    for _,id in ipairs(mismatches) do print("MISMATCH "..id) end
    assert(#missing==0 and #failures==0 and #mismatches==0,"actual provider inventory differs from generated search")

    assert(#extra==0,"generated search contains controls not observed in actual supported providers")
    local function Copy(values)
        local result={}
        for key,value in pairs(values) do result[key]=value end
        return result
    end
    local output=os.getenv("QUI_SETTINGS_BASELINE_OUTPUT")
    if output then inventory.Save(output,sourceRows) end
    local changes=inventory.Differences(baseline,sourceRows)
    assert(#changes==0,"reviewed control baseline changed:\n"..table.concat(changes,"\n"))
    -- Mutation checks use this run's actual provider inventory. A simultaneous
    -- source and cache deletion must fail even though the two reduced sets agree.
    local searchID=next(expected)
    local chosen=assert(next(sourceKeysBySearchID[searchID]))
    local removed=Copy(sourceRows)
    for key in pairs(sourceKeysBySearchID[searchID]) do removed[key]=nil end
    local reducedSource=Copy(expected); reducedSource[searchID]=nil
    local reducedIndex=Copy(actual); reducedIndex[searchID]=nil
    assert(#inventory.Missing(expected,actual)==0,"every actual control requires an index entry")
    assert(#inventory.Missing(expected,reducedIndex)==1,"index deletion must fail the independent control comparison")
    assert(#inventory.Missing(reducedSource,reducedIndex)==0,"the simultaneous deletion defeats a two-way comparison alone")
    assert(#inventory.Differences(baseline,removed)>0,"reviewed baseline must detect simultaneous source+cache deletion")
    local modified=Copy(sourceRows); modified[chosen]=modified[chosen].."|changed"
    assert(#inventory.Differences(baseline,modified)>0,"baseline must detect changed control contract")
    local added=Copy(sourceRows); added["destination|unreviewed|1|unknown"]="registered"
    assert(#inventory.Differences(baseline,added)>0,"baseline must require review of new destinations")
    print("OK: reviewed source inventory and deletion mutations across "..destinations.." destinations and "..contexts.." contexts")
end
return M
