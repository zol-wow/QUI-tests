-- tests/unit/aura_display_share_test.lua
-- Run: LUA=luajit lua tests/unit/aura_display_share_test.lua
--
-- Round-trips the aura display export/import strings through the REAL
-- vendored AceSerializer + LibDeflate: exporting a group carries its nested
-- subtree, importing renames colliding names WeakAuras-style, re-links
-- parents, restores the root's screen anchor, and re-mints element ids.

local function fail(msg)
    print("FAIL: aura_display_share_test - " .. msg)
    os.exit(1)
end

-- WoW string aliases the vendored libs expect.
strmatch = string.match
strfind = string.find
strsub = string.sub
strrep = string.rep
strbyte = string.byte
strchar = string.char
strjoin = function(d, ...) return table.concat({ ... }, d) end
format = string.format
gsub = string.gsub
tconcat = table.concat
wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

dofile("libs/LibStub/LibStub.lua")
dofile("libs/AceSerializer-3.0.lua")
dofile("libs/LibDeflate/LibDeflate.lua")

local profile = {}
local ns = {}
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.Helpers = {
    GetProfile = function() return profile end,
    GetModuleSettings = function(name, defaults)
        if not profile[name] then
            profile[name] = {}
            for k, v in pairs(defaults or {}) do profile[name][k] = v end
        end
        return profile[name]
    end,
}

assert(loadfile("core/aura_elements.lua"))("QUI", ns)
assert(loadfile("modules/trackers/aura_displays.lua"))("QUI", ns)
assert(loadfile("modules/trackers/aura_display_share.lua"))("QUI", ns)

local AD = ns.QUI_AuraDisplays
local E = ns.AuraElements
local Share = ns.QUI_AuraDisplayShare
if type(Share) ~= "table" then fail("share module must export ns.QUI_AuraDisplayShare") end

-- Build a nested source tree: Pack (root) > Pack Child, plus an ungrouped
-- display with its own anchor.
local pack = AD.GetGroup("Pack", true)
pack.spacing = 9
pack.growDirection = "DOWN"
pack.scale = 1.25
local child = AD.GetGroup("Pack Child", true)
child.sort = 1
assert(AD.SetGroupParent("Pack Child", "Pack"))

local alpha = AD.NewDisplay("Alpha", "Pack")
alpha.unit = "target"
E.EnsureSeeded(alpha.auras, function()
    return { E.NewTrackedElement({ 115151 }, "icon") }
end)
local alphaElementID = alpha.auras.elements["*"][1].id
if not alphaElementID then fail("source element must carry an id") end

local beta = AD.NewDisplay("Beta", "Pack Child")
beta.visibility = "always"

local solo = AD.NewDisplay("Solo")
profile.frameAnchoring = {
    [AD.GroupAnchorKey("Pack", true)] = { point = "TOP", relative = "TOP", offsetX = 5, offsetY = -80 },
    [AD.ANCHOR_PREFIX .. solo.id] = { point = "LEFT", relative = "LEFT", offsetX = 42, offsetY = 0 },
}

-- Group export/import ---------------------------------------------------------

local groupString = Share.ExportGroupString("Pack")
if type(groupString) ~= "string" or groupString:sub(1, 4) ~= "AD1:" then
    fail("group export must produce an AD1 string")
end

local summary, err = Share.ImportString(groupString)
if not summary then fail("group import must succeed, got: " .. tostring(err)) end
if summary.groups ~= 2 or summary.displays ~= 2 then
    fail(("group import must recreate 2 groups + 2 displays, got %s/%s")
        :format(tostring(summary.groups), tostring(summary.displays)))
end
if summary.rootKind ~= "group" or summary.rootName ~= "Pack 2" then
    fail("colliding root group must be renamed to 'Pack 2', got " .. tostring(summary.rootName))
end
if summary.renamed < 4 then
    fail("all four colliding names must be renamed, got " .. tostring(summary.renamed))
end

local importedPack = AD.GetGroup("Pack 2", false)
if not importedPack then fail("imported root group must exist") end
if importedPack.spacing ~= 9 or importedPack.growDirection ~= "DOWN"
    or importedPack.scale ~= 1.25 then
    fail("group layout settings must survive the round trip")
end
if AD.GroupParent("Pack Child 2") ~= "Pack 2" then
    fail("imported child group must be re-linked to the renamed parent")
end

local importedAnchor = profile.frameAnchoring[AD.GroupAnchorKey("Pack 2", false)]
if not importedAnchor or importedAnchor.offsetY ~= -80 then
    fail("imported root group must receive the exported screen anchor")
end

local importedAlpha, importedBeta
for _, display in ipairs(AD.OrderedDisplays()) do
    if display.name == "Alpha 2" then importedAlpha = display end
    if display.name == "Beta 2" then importedBeta = display end
end
if not importedAlpha or importedAlpha.group ~= "Pack 2" or importedAlpha.unit ~= "target" then
    fail("imported display must land in the renamed group with its settings")
end
if not importedBeta or importedBeta.group ~= "Pack Child 2"
    or importedBeta.visibility ~= "always" then
    fail("nested display must land in the renamed child group")
end

local importedElements = importedAlpha.auras and importedAlpha.auras.elements
    and importedAlpha.auras.elements["*"]
if not importedElements or importedElements[1].id ~= nil then
    fail("exported elements must arrive without ids so EnsureSeeded re-mints them")
end
E.EnsureSeeded(importedAlpha.auras, AD.DefaultBucket)
if importedElements[1].id == nil then fail("EnsureSeeded must re-mint element ids") end
if importedElements[1].spells[1] ~= 115151 then
    fail("tracked spells must survive the round trip")
end

-- Display export/import --------------------------------------------------------

local soloString = Share.ExportDisplayString(solo.id)
local soloSummary = Share.ImportString(soloString)
if not soloSummary or soloSummary.rootKind ~= "display"
    or soloSummary.rootName ~= "Solo 2" then
    fail("colliding display import must rename to 'Solo 2'")
end
local importedSolo = AD.GetDisplay(soloSummary.rootID)
if not importedSolo or importedSolo.group ~= nil then
    fail("imported ungrouped display must stay ungrouped")
end
local soloAnchor = profile.frameAnchoring[AD.ANCHOR_PREFIX .. importedSolo.id]
if not soloAnchor or soloAnchor.offsetX ~= 42 then
    fail("imported ungrouped display must receive the exported anchor")
end

local legacyGroup = AD.GetGroup("Legacy Anchors", true)
legacyGroup.layoutEnabled = false
local legacyMember = AD.NewDisplay("Legacy Member", "Legacy Anchors")
profile.frameAnchoring[AD.ANCHOR_PREFIX .. legacyMember.id] = {
    point = "RIGHT", relative = "RIGHT", offsetX = -37, offsetY = 11,
}
local legacySummary = Share.ImportString(Share.ExportGroupString("Legacy Anchors"))
if not legacySummary or legacySummary.rootName ~= "Legacy Anchors 2" then
    fail("legacy group import must succeed with a renamed root")
end
local importedLegacy
for _, display in ipairs(AD.OrderedDisplays()) do
    if display.name == "Legacy Member 2" then importedLegacy = display end
end
local legacyAnchor = importedLegacy
    and profile.frameAnchoring[AD.ANCHOR_PREFIX .. importedLegacy.id]
if not importedLegacy or AD.GroupUsesLayout(importedLegacy.group)
    or not legacyAnchor or legacyAnchor.offsetX ~= -37 or legacyAnchor.offsetY ~= 11 then
    fail("legacy grouped displays must preserve their individual anchors")
end

-- Error surfaces ---------------------------------------------------------------

local ok, _, decodeErr = Share.Decode("AD1:not-a-real-string")
if ok or type(decodeErr) ~= "string" then fail("garbage strings must fail with a message") end

local ok2, _, prefixErr = Share.Decode("QUI1:whatever")
if ok2 or not prefixErr:find("QUI1", 1, true) then
    fail("foreign prefixes must produce a pointed error")
end

local ok3 = Share.Decode("")
if ok3 then fail("empty input must fail") end

local function expectMalformed(payload, label)
    local encoded = Share.Encode(payload)
    local callOK, decoded, _, malformedErr = pcall(Share.Decode, encoded)
    if not callOK or decoded or malformedErr ~= "Malformed aura display string." then
        fail(label .. " must return a malformed-string error")
    end
end

local payloadBase = {
    type = Share.PAYLOAD_TYPE,
    version = Share.VERSION,
    root = { kind = "group", name = "Broken" },
    groups = { { name = "Broken" } },
    displays = {},
}
expectMalformed({
    type = payloadBase.type, version = payloadBase.version, root = payloadBase.root,
    groups = { 1 }, displays = {},
}, "non-table group")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version,
    root = { kind = "display", name = "Broken" },
    groups = {}, displays = { 1 },
}, "non-table display")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version, root = 1,
    groups = payloadBase.groups, displays = {},
}, "non-table root")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version,
    root = { kind = "display", name = "Broken" },
    groups = {}, displays = { {
        name = "Broken",
        auras = { elements = { ["*"] = { 1 } }, elementsSeeded = true },
    } },
}, "non-table aura element")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version,
    root = { kind = "display", name = "Broken" },
    groups = {}, displays = { {
        name = "Broken",
        auras = { elements = { ["*"] = { {
            mode = "filterStrip", auraType = "HELPFUL", filterFlags = 1,
        } } } },
    } },
}, "malformed nested aura field")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version,
    root = { kind = "display", name = "Broken" },
    groups = {}, displays = { {
        name = "Broken",
        auras = { elements = { ["*"] = { {
            mode = "tracked", auraType = {}, displayType = "icon", spells = { 1 },
        } } } },
    } },
}, "malformed tracked polarity")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version,
    root = { kind = "group", name = "Broken" },
    groups = { { name = "Broken", growDirection = {} } }, displays = {},
}, "malformed group setting")
expectMalformed({
    type = payloadBase.type, version = payloadBase.version,
    root = { kind = "display", name = "Broken" },
    groups = {}, displays = { { name = "Broken", anchor = { point = {} } } },
}, "malformed anchor")

local longName = string.rep("x", 120)
AD.GetGroup(longName, true)
local longSummary = Share.ImportString(Share.Encode({
    type = Share.PAYLOAD_TYPE,
    version = Share.VERSION,
    root = { kind = "group", name = longName },
    groups = { { name = longName } },
    displays = {},
}))
if not longSummary or #longSummary.rootName > 120 then
    fail("collision suffixes must stay within the import name limit")
end

print("OK: aura_display_share_test")
