local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
end

local function noop() end
local frames = {}
local methods = {}
function methods:GetSize() return self.width, self.height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
methods.ClearAllPoints = noop
methods.SetPoint = noop

local function newFrame()
    local frame = setmetatable({ width = 336, height = 444, shown = true, scripts = {}, events = {} }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end

local settings = { enabled = true, columns = 4, rows = 8 }
local reflows, refreshes = 0, 0
local inCombat = false
local env = setmetatable({
    QUI = {},
    MerchantFrame = newFrame(),
    MerchantNextPageButton = newFrame(),
    MerchantBuyBackItem = newFrame(),
    MerchantRepairItemButton = newFrame(),
    InCombatLockdown = function() return inCombat end,
    MerchantFrame_Update = function() refreshes = refreshes + 1 end,
    MerchantFrame_UpdateCurrencyAmounts = noop,
    UpdateUIPanelPositions = function() reflows = reflows + 1 end,
}, { __index = _G })
env._G = env
env.MerchantFrame.selectedTab = 1
env.MerchantRepairItemButton:Hide()
function env.CreateFrame(_, name)
    local frame = newFrame()
    if name then env[name] = frame end
    return frame
end
function env.hooksecurefunc(name, callback)
    local original = assert(env[name])
    env[name] = function(...)
        original(...)
        callback(...)
    end
end
for index = 1, 12 do env["MerchantItem" .. index] = newFrame() end

local function execute(source, name, ...)
    local chunk = assert(loadstring(source, name))
    setfenv(chunk, env)
    return chunk(...)
end

local native = readFile("tests/framexml/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua")
local nativeEvents = assert(native:match("(function MerchantFrame_OnEvent%(.+)\nfunction MerchantFrame_OnShow"))
execute(nativeEvents, "native merchant events")
execute(readFile(arg[1] or "modules/qol/merchant_grid.lua"), "merchant grid", "QUI", {
    Helpers = { CreateDBGetter = function() return function() return settings end end },
    WhenLoggedIn = function(callback) callback() end,
})

local function refreshFromPurchase()
    env.MerchantFrame_OnEvent(env.MerchantFrame, "MERCHANT_UPDATE")
    assert(env.MerchantFrame.update, "native merchant update must schedule its inventory refresh")
    env.MerchantFrame_OnUpdate(env.MerchantFrame, 0.016)
    env.MerchantFrame_OnEvent(env.MerchantFrame, "BAG_UPDATE", 0)
end

local function assertStablePurchase(message)
    local previousReflows, previousRefreshes = reflows, refreshes
    refreshFromPurchase()
    assert(refreshes == previousRefreshes + 2, message .. ": inventory refreshes must still run")
    assert(reflows == previousReflows, message .. ": unchanged vendor size must not reflow overlapping panels")
end

env.QUI.MerchantGrid.Refresh()
assert(env.MerchantFrame:GetWidth() == 666 and env.MerchantFrame:GetHeight() == 600, "initial grid dimensions")
assert(reflows == 1, "initial grid resize must update native panel layout")
assertStablePurchase("expanded grid purchase")
assertStablePurchase("repeated expanded grid purchase")

settings.columns = 3
env.QUI.MerchantGrid.Refresh()
assert(reflows == 2 and env.MerchantFrame:GetWidth() == 501, "column changes must reflow")
settings.rows = 7
env.QUI.MerchantGrid.Refresh()
assert(reflows == 3 and env.MerchantFrame:GetHeight() == 548, "row changes must reflow")
assertStablePurchase("resized grid purchase")

env.MerchantFrame.selectedTab = 2
env.MerchantFrame_Update()
assert(reflows == 4 and env.MerchantFrame:GetWidth() == 336 and env.MerchantFrame:GetHeight() == 444, "buyback must restore native size")
assertStablePurchase("buyback inventory refresh")
env.MerchantFrame.selectedTab = 1
env.MerchantFrame_Update()
assert(reflows == 5 and env.MerchantFrame:GetWidth() == 501, "returning to merchant tab must restore grid size")

settings.enabled = false
env.QUI.MerchantGrid.Refresh()
assert(reflows == 6 and env.MerchantFrame:GetWidth() == 336, "disabling grid must restore native size")
assertStablePurchase("disabled grid purchase after hook installation")
settings.enabled, settings.columns, settings.rows = true, 2, 5
env.QUI.MerchantGrid.Refresh()
assert(reflows == 6, "pixel-native grid must not reflow an unchanged panel")
assertStablePurchase("pixel-native grid purchase")

inCombat = true
settings.columns = 4
env.QUI.MerchantGrid.Refresh()
assert(reflows == 6 and env.MerchantFrame:GetWidth() == 666, "combat must defer panel layout after size change")
assertStablePurchase("combat purchase with pending resize")
inCombat = false
for _, frame in ipairs(frames) do
    if frame.events.PLAYER_REGEN_ENABLED then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end
end
assert(reflows == 7, "combat exit must preserve the pending size reconciliation")
for _, frame in ipairs(frames) do
    if frame.events.PLAYER_REGEN_ENABLED then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end
end
assert(reflows == 7, "completed combat reconciliation must not replay")
assertStablePurchase("purchase after combat reconciliation")

print("merchant grid panel reflow: PASS")
