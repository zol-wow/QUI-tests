-- tests/unit/cdm_viewer_addon_test.lua
-- Run: lua tests/unit/cdm_viewer_addon_test.lua
local ns = {}
local loadChunk = dofile("tests/helpers/load_cdm_consolidated_chunk.lua")
loadChunk("QUI_CDM/cdm/cdm_shared.lua", "cdm_viewer_addon.lua")("QUI", ns)

local A = assert(ns.CDMCooldownViewerAddon, "CDMCooldownViewerAddon should be exported")

assert(A.PRIMARY == "Blizzard_CooldownViewer", "primary addon name is Blizzard_CooldownViewer")
assert(A.IsViewerAddon("Blizzard_CooldownViewer"), "recognizes the current viewer addon")
assert(not A.IsViewerAddon("Blizzard_CooldownManager"), "does not recognize stale manager addon")
assert(not A.IsViewerAddon("Blizzard_Test"), "rejects unrelated addons")
assert(A.Load == nil, "QUI_CDM must not expose a Blizzard Cooldown Viewer loader")

local file = assert(io.open("QUI_CDM/cdm/cdm_spelldata.lua", "rb"))
local source = file:read("*a")
file:close()
assert(not source:find("ForceLoadCDM", 1, true),
    "QUI_CDM must wait for Blizzard_CooldownViewer instead of force-loading it")
assert(not source:find('LoadAddOn("Blizzard_CooldownViewer")', 1, true),
    "QUI_CDM must not load Blizzard_CooldownViewer from addon execution")

file = assert(io.open("QUI_CDM/cdm/cdm_containers.lua", "rb"))
source = file:read("*a")
file:close()
assert(source:find('eventFrame:RegisterEvent("ADDON_LOADED")', 1, true),
    "QUI_CDM must wait for Blizzard addon loading")
assert(source:find('event == "ADDON_LOADED" and cooldownViewerLoaded', 1, true),
    "QUI_CDM must initialize native viewer hooks from ADDON_LOADED")

print("OK: cdm_viewer_addon_test")
