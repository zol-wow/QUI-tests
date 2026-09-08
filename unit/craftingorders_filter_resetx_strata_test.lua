-- tests/unit/craftingorders_filter_resetx_strata_test.lua
-- Run: lua tests/unit/craftingorders_filter_resetx_strata_test.lua
--
-- Regression guard: the crafting-orders filter dropdown's reset "X"
-- (ResetButton) must be revalidated after QUI enables its expansion filter.

local function readFile(path)
    local fh = assert(io.open(path, "rb"), "failed to open " .. path)
    local text = fh:read("*a")
    fh:close()
    return text
end

local source = readFile("modules/qol/qol.lua")
local setupSource = assert(source:match("(local coHooked = false.-)\n\nqolFrame:RegisterEvent"),
    "failed to extract crafting-order filter setup")

local timers = {}
C_Timer = {
    After = function(_, callback)
        timers[#timers + 1] = callback
    end,
}

Enum = {
    AuctionHouseFilter = {
        CurrentExpansionOnly = "CurrentExpansionOnly",
    },
}

GetSettings = function()
    return { craftingOrderExpansionFilter = true }
end

local validateCount = 0
local filterDropdown = {
    filters = {},
    ValidateResetState = function(self)
        assert(self.filters.CurrentExpansionOnly == true,
            "reset-X state must be validated after the expansion filter is enabled")
        validateCount = validateCount + 1
    end,
}

local browseOrders = {
    SearchBar = { FilterDropdown = filterDropdown },
    HookScript = function(self, scriptName, callback)
        self[scriptName] = callback
    end,
}

ProfessionsCustomerOrdersFrame = { BrowseOrders = browseOrders }

local SetupCraftingOrderFilter = assert((loadstring or load)(
    setupSource .. "\nreturn SetupCraftingOrderFilter", "craftingorders_filter_resetx"))()

SetupCraftingOrderFilter()
assert(#timers == 1, "crafting-order filter setup must schedule its initial refresh")
timers[1]()
assert(validateCount == 1, "initial expansion-filter application must refresh the reset X")

filterDropdown.filters.CurrentExpansionOnly = false
browseOrders.OnShow()
assert(#timers == 2, "reopening crafting orders must schedule the expansion filter")
timers[2]()
assert(validateCount == 2, "reopening crafting orders must refresh the reset X")

print("OK: craftingorders_filter_resetx_strata_test")
