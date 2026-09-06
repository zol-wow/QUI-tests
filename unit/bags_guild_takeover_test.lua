-- tests/unit/bags_guild_takeover_test.lua
-- Run: lua tests/unit/bags_guild_takeover_test.lua
-- Guild bank session state machine: LoD-aware GuildBankFrame suppression
-- (OnHide suppression + reparent to a hidden holder), GUILDBANKFRAME_OPENED/
-- CLOSED routing (guild window + replaced bag globals; the scanner session
-- is owned by core/storage/collector.lua, not this file), and the
-- user-close -> CloseGuildBankFrame echo guard.
--
-- Blizzard_GuildBankUI is load-on-demand: GuildBankFrame does NOT exist at
-- login, so Init() with the addon unloaded must arm a pending state.
local loader = dofile("tests/helpers/load_bags_data.lua")
loader.InstallBaseStubs()

-- GuildBankFrame fake factory (the LoD addon can "load" mid-test, and the
-- already-loaded section needs a second pristine frame). Hide() checks
-- whether OnHide is still wired at hide time (ordering truth); SetParent
-- snapshots the hide count so hide-before-reparent is assertable on Revert.
local function makeGuildBankFrame()
    local frame = {
        _origScripts = {
            OnEvent = function() end, -- LIVE at load (OnLoad registers 11 events)
            OnShow = function() end,
            OnHide = function() end,  -- calls CloseGuildBankFrame()
        },
        _parent = "UIParent",
        _hideCount = 0,
        _hiddenWithLiveOnHide = false,
        _hideCountAtLastReparent = nil,
    }
    frame._scripts = {
        OnEvent = frame._origScripts.OnEvent,
        OnShow = frame._origScripts.OnShow,
        OnHide = frame._origScripts.OnHide,
    }
    function frame.GetScript(self, name) return self._scripts[name] end
    function frame.SetScript(self, name, fn) self._scripts[name] = fn end
    function frame.GetParent(self) return self._parent end
    function frame.SetParent(self, p)
        self._parent = p
        self._hideCountAtLastReparent = self._hideCount
    end
    function frame.Hide(self)
        self._hideCount = self._hideCount + 1
        if self._scripts.OnHide then self._hiddenWithLiveOnHide = true end
    end
    return frame
end

-- Hidden-holder factory: record every holder created so reparent targets
-- and holder reuse are assertable.
local holders = {}
_G.CreateFrame = function()
    local holder = {
        _shown = true,
        SetSize = function() end,
        SetPoint = function() end,
        Hide = function(self) self._shown = false end,
        Show = function(self) self._shown = true end,
    }
    holders[#holders + 1] = holder
    return holder
end

-- C_AddOns.IsAddOnLoaded stub: controllable + records queried names.
local addonLoaded = false
local isLoadedQueries = {}
_G.C_AddOns = _G.C_AddOns or {}
_G.C_AddOns.IsAddOnLoaded = function(name)
    isLoadedQueries[#isLoadedQueries + 1] = name
    return name == "Blizzard_GuildBankUI" and addonLoaded
end

local sessionLog = {}
local openLog, closeLog = {}, {}

local closeGuildBankCalls = 0
_G.CloseGuildBankFrame = function() closeGuildBankCalls = closeGuildBankCalls + 1 end

local ns = loader.LoadAll()

-- Takeover internal open/close API (guild routes through it, NOT the
-- Blizzard-owned globals): log the GetName() of the opener argument AND
-- feed a shared ordered session log (pump-before-window ordering is
-- load-bearing).
ns.Bags.Takeover = {
    OpenForFrame = function(frame)
        openLog[#openLog + 1] = frame and frame.GetName and frame:GetName() or "<no-name>"
        sessionLog[#sessionLog + 1] = "openallbags"
    end,
    CloseForFrame = function(frame)
        closeLog[#closeLog + 1] = frame and frame.GetName and frame:GetName() or "<no-name>"
        sessionLog[#sessionLog + 1] = "closeallbags"
    end,
}

-- Scanner + window stubs share the ordered session log.
ns.Storage.ScanGuild = {
    OnGuildBankOpened = function() sessionLog[#sessionLog + 1] = "scan-open" end,
    OnGuildBankClosed = function() sessionLog[#sessionLog + 1] = "scan-close" end,
}
ns.Bags.GuildWindow = {
    ShowLive = function() sessionLog[#sessionLog + 1] = "window-showlive" end,
    OnBankClosed = function() sessionLog[#sessionLog + 1] = "window-onbankclosed" end,
}

assert(loadfile("QUI_Bags/bags/takeover_shared.lua"))("QUI", ns)
local chunk = assert(loadfile("QUI_Bags/bags/guild_takeover.lua"))
chunk("QUI", ns)
local GuildTakeover = ns.Bags.GuildTakeover

-- Test 1: Init with the LoD addon NOT loaded -> NO suppression (the frame
-- does not even exist), pending armed. A wrong-name ADDON_LOADED (bags.lua
-- forwards every arg1 verbatim) must not act. The matching ADDON_LOADED
-- must preserve Blizzard's native scripts until the bank opens.
_G.GuildBankFrame = nil
GuildTakeover.Init()
assert(isLoadedQueries[#isLoadedQueries] == "Blizzard_GuildBankUI",
    "Init must query IsAddOnLoaded for Blizzard_GuildBankUI")
assert(#holders == 0, "no holder may be created while the LoD addon is unloaded")
GuildTakeover.OnAddonLoaded("Blizzard_SomeOtherUI")
assert(#holders == 0, "a non-matching ADDON_LOADED must not suppress")

local frame1 = makeGuildBankFrame()
_G.GuildBankFrame = frame1
GuildTakeover.OnAddonLoaded("Blizzard_GuildBankUI")
assert(frame1:GetScript("OnEvent") == frame1._origScripts.OnEvent,
    "ADDON_LOADED must leave native OnEvent active before the bank opens")
assert(frame1:GetScript("OnShow") == frame1._origScripts.OnShow,
    "ADDON_LOADED must leave native OnShow active before the bank opens")
assert(frame1:GetScript("OnHide") == frame1._origScripts.OnHide,
    "ADDON_LOADED must not suppress OnHide before the bank opens")
assert(frame1._parent == "UIParent", "ADDON_LOADED must not reparent before open")
GuildTakeover.OnOpened()
assert(frame1:GetScript("OnEvent") == frame1._origScripts.OnEvent,
    "suppression must preserve Blizzard's native OnEvent")
assert(frame1:GetScript("OnShow") == frame1._origScripts.OnShow,
    "suppression must preserve Blizzard's native OnShow")
assert(frame1:GetScript("OnHide") == nil, "suppression must clear only OnHide")
assert(frame1._hideCount == 0, "opening suppression must not Hide the native frame")
assert(#holders == 1, "exactly one hidden holder")
assert(holders[1]._shown == false, "the holder must be hidden")
assert(frame1._parent == holders[1], "GuildBankFrame must be reparented to the holder")
-- Idempotence: neither a repeat ADDON_LOADED (pending already consumed) nor
-- a direct SuppressNow may re-capture (capturing the now-nil scripts would
-- destroy Revert) or act again.
GuildTakeover.OnAddonLoaded("Blizzard_GuildBankUI")
GuildTakeover.SuppressNow()
assert(#holders == 1, "idempotent suppression must not create a second holder")
assert(frame1._hideCount == 0, "idempotent suppression must not Hide")
assert(GuildTakeover.IsLive() == true, "OnOpened must mark the guild bank live")
GuildTakeover.OnClosed()
sessionLog, openLog, closeLog = {}, {}, {}

-- Test 2: fresh module instance + pristine frame, addon ALREADY loaded at
-- Init (e.g. enable-after-visit or a /reload at the vault) -> no early
-- suppression. This instance carries the session
-- machine tests below.
addonLoaded = true
local frame2 = makeGuildBankFrame()
_G.GuildBankFrame = frame2
chunk("QUI", ns)
GuildTakeover = ns.Bags.GuildTakeover
GuildTakeover.Init()
assert(frame2:GetScript("OnEvent") == frame2._origScripts.OnEvent,
    "loaded-at-Init must preserve native OnEvent")
assert(frame2:GetScript("OnShow") == frame2._origScripts.OnShow,
    "loaded-at-Init must preserve native OnShow")
assert(frame2:GetScript("OnHide") == frame2._origScripts.OnHide,
    "loaded-at-Init must preserve native OnHide until open")
assert(#holders == 1, "loaded-at-Init must not create a hidden holder")
assert(frame2._parent == "UIParent", "loaded-at-Init must not reparent")

-- Test 3: GUILDBANKFRAME_OPENED -> live; the window shows, then bags
-- auto-open. The scanner session is owned by the core collection driver
-- (core/storage/collector.lua), which hears the same GuildBanker interaction
-- edge — guild_takeover.lua no longer pumps the scanner itself.
sessionLog = {}
GuildTakeover.OnOpened()
assert(GuildTakeover.IsLive() == true, "OPENED must set live")
assert(frame2:GetScript("OnEvent") == frame2._origScripts.OnEvent,
    "OPENED must leave Blizzard's guild-bank event handler active")
assert(frame2:GetScript("OnShow") == frame2._origScripts.OnShow,
    "OPENED must leave Blizzard's guild-bank setup handler active")
assert(frame2:GetScript("OnHide") == nil, "OPENED must suppress only native OnHide")
assert(frame2._parent == holders[2], "OPENED must hide the native frame by reparenting")
assert(sessionLog[1] == "window-showlive", "the window shows on open")
assert(sessionLog[2] == "openallbags", "bags auto-open after the window")
assert(sessionLog[1] ~= "scan-open" and sessionLog[2] ~= "scan-open",
    "guild_takeover must NOT pump the scanner (the collector owns the session)")
assert(#openLog == 1 and openLog[1] == "QUI_GuildBankWindow",
    "OpenForFrame must receive a QUI_GuildBankWindow-named opener (policy key + opener tracking)")

-- Test 3b: OnOpened is LATCHED — the session open now has two triggers
-- (PLAYER_INTERACTION_MANAGER_FRAME_SHOW GuildBanker routing, the retail
-- path, plus legacy GUILDBANKFRAME_OPENED kept as a redundant trigger), so
-- a build where both fire must not double-pump/double-show.
GuildTakeover.OnOpened()
assert(#sessionLog == 2, "a second OnOpened while live must be a no-op (latch)")
assert(#openLog == 1, "a second OnOpened while live must not re-OpenAllBags")

-- Test 4: GUILDBANKFRAME_CLOSED (server-driven) -> live cleared; window
-- notified; CloseAllBags with the proxy; the server already closed, so
-- CloseGuildBankFrame must NOT be called. The scanner session is closed by
-- the collector on the interaction-HIDE edge, not here.
sessionLog = {}
GuildTakeover.OnClosed()
assert(GuildTakeover.IsLive() == false, "CLOSED must clear live")
assert(sessionLog[1] == "window-onbankclosed", "CLOSED must notify the guild window")
assert(sessionLog[2] == "closeallbags", "CLOSED must close the auto-opened bags")
assert(sessionLog[1] ~= "scan-close",
    "guild_takeover must NOT close the scanner session (the collector owns it)")
assert(#closeLog == 1 and closeLog[1] == "QUI_GuildBankWindow",
    "CloseForFrame must receive the QUI_GuildBankWindow-named opener")
assert(closeGuildBankCalls == 0, "a server-driven close must NOT call CloseGuildBankFrame")
assert(frame2:GetScript("OnHide") == frame2._origScripts.OnHide,
    "CLOSED must restore native OnHide for the next session")
assert(frame2._parent == "UIParent", "CLOSED must restore the native frame parent")
-- Test 4b: OnClosed is latched on live too (CLOSED + interaction HIDE can
-- both arrive): a close while not live must not re-run the close chain.
sessionLog = {}
GuildTakeover.OnClosed()
assert(#sessionLog == 0, "OnClosed while not live must be a no-op (latch)")
assert(#closeLog == 1, "OnClosed while not live must not re-CloseAllBags")

-- Test 5: user-close while live -> CloseGuildBankFrame EXACTLY once; the
-- chassis onClose fires on ANY hide, so a re-entrant call must be swallowed
-- by the closing latch; the echoed CLOSED resets the latch for the next
-- session; user-close while NOT live is a no-op.
GuildTakeover.OnOpened()
GuildTakeover.UserClosedWindow()
assert(closeGuildBankCalls == 1, "user close must call CloseGuildBankFrame exactly once")
GuildTakeover.UserClosedWindow()
assert(closeGuildBankCalls == 1, "the closing latch must swallow a re-entrant user close")
GuildTakeover.OnClosed() -- the server echo of our CloseGuildBankFrame
assert(closeGuildBankCalls == 1, "the echoed CLOSED must not re-call CloseGuildBankFrame")
assert(GuildTakeover.IsLive() == false, "echoed CLOSED must clear live")
-- next session: the latch must have reset
GuildTakeover.OnOpened()
GuildTakeover.UserClosedWindow()
assert(closeGuildBankCalls == 2, "the closing latch must reset once the close lands")
GuildTakeover.OnClosed()
-- not live -> no-op
assert(GuildTakeover.IsLive() == false, "precondition: not live")
GuildTakeover.UserClosedWindow()
assert(closeGuildBankCalls == 2, "user close while not live must NOT call CloseGuildBankFrame")

-- Test 6: Revert. Belt-and-braces: a still-live session with no close in
-- flight must be ended server-side (the restored Blizzard frame is hidden;
-- its OnHide close would never fire). Scripts + parent restored EXACTLY,
-- with the defensive Hide running BEFORE the reparent and while OnHide is
-- still cleared. Idempotent. With a close already in flight (closing
-- latch), Revert must NOT double-send.
GuildTakeover.OnOpened()
local callsBeforeLiveRevert = closeGuildBankCalls
local hidesBeforeRevert = frame2._hideCount
GuildTakeover.Revert()
assert(closeGuildBankCalls == callsBeforeLiveRevert + 1,
    "Revert with a live session must call CloseGuildBankFrame")
assert(GuildTakeover.IsLive() == false, "Revert must clear live")
assert(frame2._hideCount == hidesBeforeRevert + 1,
    "Revert must defensively Hide (ShowUIPanel may have set the shown flag while suppressed)")
assert(frame2._hiddenWithLiveOnHide == false,
    "Revert's Hide must run while the scripts are still cleared")
assert(frame2._hideCountAtLastReparent == frame2._hideCount,
    "Revert must Hide BEFORE reparenting (a shown frame on a live parent would pop open)")
assert(frame2:GetScript("OnEvent") == frame2._origScripts.OnEvent,
    "Revert must restore the exact OnEvent")
assert(frame2:GetScript("OnShow") == frame2._origScripts.OnShow,
    "Revert must restore the exact OnShow")
assert(frame2:GetScript("OnHide") == frame2._origScripts.OnHide,
    "Revert must restore the exact OnHide")
assert(frame2._parent == "UIParent", "Revert must restore the original parent")
-- idempotence
GuildTakeover.Revert()
assert(frame2._hideCount == hidesBeforeRevert + 1, "second Revert must be a no-op")
assert(frame2:GetScript("OnShow") == frame2._origScripts.OnShow,
    "second Revert must not clobber scripts")
assert(frame2._parent == "UIParent", "second Revert must not touch the parent")
-- close already in flight: no double-send
GuildTakeover.SuppressNow()
GuildTakeover.OnOpened()
GuildTakeover.UserClosedWindow() -- close in flight: closing latched
local callsBeforeLatchedRevert = closeGuildBankCalls
GuildTakeover.Revert()
assert(closeGuildBankCalls == callsBeforeLatchedRevert,
    "Revert must not re-send a close already in flight (closing latch)")
assert(GuildTakeover.IsLive() == false, "Revert must clear live even with a close in flight")
-- a full re-Suppress/Revert cycle still works after Revert (holder reused)
GuildTakeover.SuppressNow()
assert(frame2:GetScript("OnShow") == frame2._origScripts.OnShow,
    "re-suppress after Revert must preserve OnShow")
assert(frame2:GetScript("OnHide") == nil, "re-suppress after Revert must clear OnHide")
assert(frame2._parent == holders[2], "re-suppress must reuse the cached holder")
assert(#holders == 2, "no new holder on re-suppress")
GuildTakeover.Revert()
assert(frame2:GetScript("OnShow") == frame2._origScripts.OnShow,
    "second cycle must restore scripts")
assert(frame2._parent == "UIParent", "second cycle must restore the parent")

-- Test 7: Revert must clear the PENDING state too: a module disabled while
-- still waiting for the LoD addon must not suppress when the addon loads
-- later (fresh instance: Init with the addon unloaded arms pending; Revert
-- disarms; the matching ADDON_LOADED must then do nothing).
addonLoaded = false
local frame3 = makeGuildBankFrame()
_G.GuildBankFrame = nil
chunk("QUI", ns)
GuildTakeover = ns.Bags.GuildTakeover
GuildTakeover.Init() -- addon unloaded -> pending armed
GuildTakeover.Revert() -- disabled before the vault was ever visited
_G.GuildBankFrame = frame3
GuildTakeover.OnAddonLoaded("Blizzard_GuildBankUI")
assert(frame3:GetScript("OnEvent") == frame3._origScripts.OnEvent,
    "a reverted (disabled) takeover must not suppress on a late ADDON_LOADED")
assert(frame3._parent == "UIParent", "a reverted takeover must not reparent")
assert(#holders == 2, "a reverted takeover must not create a holder")

-- Test 8: legacy-global fallback — with C_AddOns absent, Init must consult
-- the legacy IsAddOnLoaded global (client-drift guard: the module promises
-- `(C_AddOns and C_AddOns.IsAddOnLoaded and ...) or (IsAddOnLoaded and ...)`).
local savedCAddOns = _G.C_AddOns
_G.C_AddOns = nil
local legacyLoadedQuery
_G.IsAddOnLoaded = function(name)
    legacyLoadedQuery = name
    return name == "Blizzard_GuildBankUI"
end
local frame4 = makeGuildBankFrame()
_G.GuildBankFrame = frame4
chunk("QUI", ns)
GuildTakeover = ns.Bags.GuildTakeover
GuildTakeover.Init()
assert(legacyLoadedQuery == "Blizzard_GuildBankUI",
    "Init must fall back to the legacy IsAddOnLoaded global when C_AddOns is absent")
assert(frame4:GetScript("OnEvent") == frame4._origScripts.OnEvent,
    "legacy loaded-at-Init path must preserve native OnEvent")
assert(frame4._parent == "UIParent", "legacy loaded-at-Init path must wait for open")
GuildTakeover.OnOpened()
assert(frame4:GetScript("OnHide") == nil, "legacy fallback must suppress on open")
assert(frame4._parent == holders[#holders], "legacy fallback must reparent on open")
GuildTakeover.Revert()
_G.C_AddOns = savedCAddOns
_G.IsAddOnLoaded = nil

print("OK: bags_guild_takeover_test")
