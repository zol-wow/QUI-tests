-- tests/unit/aura_displays_preview_edit_test.lua
-- Run: lua tests/unit/aura_displays_preview_edit_test.lua
--
-- Source-text pins for editing-time preview interaction: while a display or
-- group is selected in the options panel, its on-screen preview is draggable
-- (committing Layout-Mode-shaped anchors) and group hosts wear bounding boxes
-- so the group's extent and nesting are visible. The executable drag-target
-- and commit coverage lives in aura_displays_test.lua.

local function read(p)
    local h = io.open(p, "rb")
    if not h then return nil end
    local s = h:read("*a")
    h:close()
    return s
end

local fails = 0
local function check(n, ok)
    if ok then print("  ok  " .. n) else fails = fails + 1; print("FAIL  " .. n) end
end

local runtime = read("modules/trackers/aura_displays.lua")
local content = read("modules/trackers/settings/aura_displays_content.lua")
check("runtime exists", runtime ~= nil)
check("content page exists", content ~= nil)
if not (runtime and content) then
    print(("%d failures"):format(fails + 1))
    os.exit(1)
end

-- Drag surface ----------------------------------------------------------------
check("runtime exposes the preview drag API",
    runtime:find("function AD.EnablePreviewDrag", 1, true) ~= nil
    and runtime:find("function AD.DisablePreviewDrag", 1, true) ~= nil)
check("dragging is blocked in combat",
    runtime:find("if not target or (InCombatLockdown and InCombatLockdown()) then return end", 1, true) ~= nil)
check("drag commits reapply through the shared anchor pipeline",
    runtime:find("QUI_ApplyFrameAnchor(target.key)", 1, true) ~= nil
    and runtime:find("QUI_LayoutModeSyncHandle(target.key)", 1, true) ~= nil)
check("secret rect reads abort the commit instead of writing garbage",
    runtime:find("ns.Helpers.SafeNumberOrNil(hx)", 1, true) ~= nil)
check("the overlay hints at Layout Mode for fine-tuning",
    runtime:find('ns.L["Drag to move. Fine-tune in Layout Mode."]', 1, true) ~= nil)

-- Group bounding boxes ---------------------------------------------------------
check("group hosts draw bounding boxes during single previews",
    runtime:find("local function UpdateGroupBox(host, groupName, mode)", 1, true) ~= nil
    and runtime:find("UpdateGroupBox(groupHost, groupName, PreviewBoxMode(groupName))", 1, true) ~= nil)
check("the selected group's box is brighter than related ones",
    runtime:find('mode == "selected" and 0.9 or 0.4', 1, true) ~= nil)
check("boxes stay out of Layout Mode's way",
    runtime:find("if previewActive then return nil end", 1, true) ~= nil)
check("boxes label the group by name",
    runtime:find("box.label:SetText(groupName)", 1, true) ~= nil)

-- Options wiring ---------------------------------------------------------------
check("selecting a display enables its preview drag",
    content:find('AD.EnablePreviewDrag("display", wantedID)', 1, true) ~= nil)
check("selecting a group enables its preview drag",
    content:find('AD.EnablePreviewDrag("group", wantedGroup)', 1, true) ~= nil)
check("leaving the page disables preview drag",
    content:find("if type(AD.DisablePreviewDrag) == \"function\" then AD.DisablePreviewDrag() end", 1, true) ~= nil)

if fails > 0 then
    print(("%d failures"):format(fails))
    os.exit(1)
end
print("OK: aura_displays_preview_edit_test")
