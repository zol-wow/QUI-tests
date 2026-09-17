local ns = { Client = { restrictedExecutionUnavailable = true } }
local chunk = assert(loadfile("modules/qol/quicksalvage.lua"))
setfenv(chunk, setmetatable({}, {
    __index = function(_, key) error("unsupported salvage startup accessed " .. key) end,
}))
chunk("QUI", ns)
assert(ns.QuickSalvage == nil, "unsupported secure salvage button must not initialize")
print("OK forever_quicksalvage_guard_test")
