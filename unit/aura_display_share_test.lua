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

assert(loadfile("core/safecall.lua"))("QUI", ns)
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

-- Error surfaces ---------------------------------------------------------------

local ok, _, decodeErr = Share.Decode("AD1:not-a-real-string")
if ok or type(decodeErr) ~= "string" then fail("garbage strings must fail with a message") end

local ok2, _, prefixErr = Share.Decode("QUI1:whatever")
if ok2 or not prefixErr:find("QUI1", 1, true) then
    fail("foreign prefixes must produce a pointed error")
end

local ok3 = Share.Decode("")
if ok3 then fail("empty input must fail") end

-- Well-encoded but malformed payloads must come back as the advertised
-- "malformed" error, never as a Lua error escaping into the import button.
local function MalformedCase(label, payload)
    payload.type = payload.type or Share.PAYLOAD_TYPE
    payload.version = payload.version or Share.VERSION
    local encoded = Share.Encode(payload)
    if not encoded then fail(label .. ": test payload must encode") end
    local okCall, okDecode, _, err = pcall(Share.Decode, encoded)
    if not okCall then fail(label .. ": Decode must not raise: " .. tostring(okDecode)) end
    if okDecode or type(err) ~= "string" or not err:find("Malformed", 1, true) then
        fail(label .. ": must be rejected as malformed, got " .. tostring(err))
    end
    local okImport, summary, importErr = pcall(Share.ImportString, encoded)
    if not okImport then fail(label .. ": ImportString must not raise: " .. tostring(summary)) end
    if summary ~= nil or type(importErr) ~= "string" then
        fail(label .. ": ImportString must return nil plus the error")
    end
end
MalformedCase("non-table group entry", { groups = { 1 }, displays = {} })
MalformedCase("non-table display entry", { groups = {}, displays = { "Fade" } })
MalformedCase("group without a name", { groups = { { spacing = 2 } }, displays = {} })
MalformedCase("mistyped group field", { groups = { { name = "G", spacing = "wide" } }, displays = {} })
MalformedCase("mistyped group parent", { groups = { { name = "G", parent = 7 } }, displays = {} })
MalformedCase("mistyped display auras", { groups = {}, displays = { { name = "D", auras = 5 } } })
MalformedCase("mistyped display group", { groups = {}, displays = { { name = "D", group = { "G" } } } })
MalformedCase("bogus root kind", { root = { kind = "bogus" }, groups = {}, displays = { { name = "D" } } })
MalformedCase("non-table root", { root = "display", groups = {}, displays = { { name = "D" } } })

-- Graph identity: group names are identities, references must resolve.
MalformedCase("duplicate group names", { groups = { { name = "G" }, { name = "G" } }, displays = {} })
MalformedCase("unknown parent", { groups = { { name = "G", parent = "Nope" } }, displays = {} })
MalformedCase("self parent", { groups = { { name = "G", parent = "G" } }, displays = {} })
MalformedCase("parent cycle", { groups = { { name = "A", parent = "B" }, { name = "B", parent = "A" } }, displays = {} })
MalformedCase("display in unknown group", { groups = { { name = "G" } }, displays = { { name = "D", group = "Other" } } })
MalformedCase("root names unknown group", { root = { kind = "group", name = "Nope" }, groups = { { name = "G" } }, displays = {} })
MalformedCase("root names unknown display", { root = { kind = "display", name = "Nope" }, groups = {}, displays = { { name = "D" } } })

-- Nested records: anchors, layout, load and aura elements are type-checked.
MalformedCase("mistyped anchor offset", { groups = { { name = "G", anchor = { point = "TOP", offsetX = "far" } } }, displays = {} })
MalformedCase("mistyped layout spacing", { groups = {}, displays = { { name = "D", layout = { spacing = "wide" } } } })
MalformedCase("mistyped load classes", { groups = {}, displays = { { name = "D", load = { classes = "PRIEST" } } } })
MalformedCase("mistyped element iconSize", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 }, iconSize = "big" } } } } } } })
MalformedCase("non-numeric spell id", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { "Fade" } } } } } } } })
MalformedCase("tracked element without spells", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = {} } } } } } } })
MalformedCase("unknown element mode", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "weird" } } } } } } })
MalformedCase("mistyped element filterFlags", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "filterStrip", auraType = "HELPFUL", filterFlags = 5 } } } } } } })
MalformedCase("mistyped duration fontSize", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 },
        duration = { fontSize = "big" } } } } } } } })
MalformedCase("mistyped bar thickness", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "bar", spells = { 1 },
        bar = { thickness = "thick", length = 48 } } } } } } } })
MalformedCase("non-numeric color channel", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "square", spells = { 1 },
        color = { "red", 0, 0 } } } } } } } })
MalformedCase("non-table element bucket", { groups = {}, displays = { { name = "D", auras = { elements = { ["*"] = 5 } } } } })
do
    local deep = { groups = {}, displays = {} }
    for i = 1, AD.MAX_GROUP_DEPTH + 1 do
        deep.groups[i] = { name = "L" .. i, parent = i > 1 and ("L" .. (i - 1)) or nil }
    end
    MalformedCase("nesting deeper than the runtime limit", deep)
    local fits = { groups = {}, displays = {}, type = Share.PAYLOAD_TYPE, version = Share.VERSION }
    for i = 1, AD.MAX_GROUP_DEPTH do
        fits.groups[i] = { name = "M" .. i, parent = i > 1 and ("M" .. (i - 1)) or nil }
    end
    local fitsSummary, fitsErr = Share.ImportString(Share.Encode(fits))
    if not fitsSummary or fitsSummary.groups ~= AD.MAX_GROUP_DEPTH then
        fail("a chain at the runtime limit must import: " .. tostring(fitsErr))
    end
    local lastName = "M" .. AD.MAX_GROUP_DEPTH
    if AD.GroupParent(lastName) ~= "M" .. (AD.MAX_GROUP_DEPTH - 1) then
        fail("every level of the deepest allowed chain must be linked")
    end
end

-- Root topology: a declared root must own the whole payload.
MalformedCase("second root group beside the declared root",
    { root = { kind = "group", name = "R" }, groups = { { name = "R" }, { name = "Other" } }, displays = {} })
MalformedCase("ungrouped display under a group root",
    { root = { kind = "group", name = "R" }, groups = { { name = "R" } }, displays = { { name = "Loose" } } })
MalformedCase("display root with groups",
    { root = { kind = "display", name = "D" }, groups = { { name = "G" } }, displays = { { name = "D" } } })
MalformedCase("display root with a second display",
    { root = { kind = "display", name = "D" }, groups = {}, displays = { { name = "D" }, { name = "E" } } })
MalformedCase("display root naming a grouped display",
    { root = { kind = "display", name = "D" }, groups = { { name = "G" } }, displays = { { name = "D", group = "G" } } })

-- Enum-like strings must be values the editor can produce.
MalformedCase("bogus element anchor", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 }, anchor = "BOGUS" } } } } } } })
MalformedCase("bogus aura type", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 }, auraType = "NEUTRAL" } } } } } } })
MalformedCase("bogus display type", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "hologram", spells = { 1 } } } } } } } })
MalformedCase("bogus duration anchor", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 },
        duration = { anchor = "BOGUS" } } } } } } } })
MalformedCase("bogus bar orientation", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "bar", spells = { 1 },
        bar = { orientation = "DIAGONAL" } } } } } } } })
MalformedCase("bogus strip sort rule", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "filterStrip", auraType = "HELPFUL", sortRule = "RANDOM" } } } } } } })
MalformedCase("bogus group growth", { groups = { { name = "G", growDirection = "DIAGONAL" } }, displays = {} })
MalformedCase("bogus display visibility", { groups = {}, displays = { { name = "D", visibility = "sometimes" } } })
MalformedCase("bogus display unit mode", { groups = {}, displays = { { name = "D", unitMode = "guess" } } })
MalformedCase("bogus layout direction", { groups = {}, displays = { { name = "D", layout = { direction = "SIDEWAYS" } } } })
MalformedCase("bogus anchor point", { groups = { { name = "G", anchor = { point = "MIDDLE", offsetX = 1 } } }, displays = {} })

-- Numeric fields must be finite and sane.
MalformedCase("infinite iconSize", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 }, iconSize = 1 / 0 } } } } } } })
MalformedCase("NaN group scale", { groups = { { name = "G", scale = 0 / 0 } }, displays = {} })
MalformedCase("negative group scale", { groups = { { name = "G", scale = -1 } }, displays = {} })
MalformedCase("absurd anchor offset", { groups = { { name = "G", anchor = { point = "TOP", offsetX = 1e9 } } }, displays = {} })
MalformedCase("out-of-range color channel", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "square", spells = { 1 }, color = { 5, 0, 0 } } } } } } } })
MalformedCase("huge duration font", { groups = {}, displays = { { name = "D",
    auras = { elements = { ["*"] = { { mode = "tracked", displayType = "icon", spells = { 1 },
        duration = { fontSize = 9000 } } } } } } } })

-- Byte caps: oversized input is refused before decompression or
-- deserialization can do any real work.
do
    local tooLong = "AD1:" .. string.rep("A", 256 * 1024 + 1)
    local okBig, _, bigErr = Share.Decode(tooLong)
    if okBig or not (bigErr or ""):find("too large", 1, true) then
        fail("oversized encoded strings must be refused up front")
    end
    local bloated = Share.Encode({ type = Share.PAYLOAD_TYPE, version = Share.VERSION, groups = {},
        displays = { { name = "D", auras = { elements = { ["*"] = { {
            mode = "filterStrip", auraType = "HELPFUL", filterFlags = { [string.rep("x", 2 * 1024 * 1024 + 64)] = true },
        } } } } } } })
    if not bloated or #bloated > 256 * 1024 then fail("bloat fixture must compress under the encoded cap") end
    local okBloat, _, bloatErr = Share.Decode(bloated)
    if okBloat or not (bloatErr or ""):find("too large", 1, true) then
        fail("payloads that decompress past the cap must be refused before deserialization")
    end
end

-- Colliding maximum-length names stay within MAX_NAME_LENGTH after renaming.
do
    local longName = string.rep("N", 120)
    local existing = AD.NewDisplay(longName)
    if #existing.name ~= 120 then fail("fixture must create a maximum-length display name") end
    local collide = Share.Encode({ type = Share.PAYLOAD_TYPE, version = Share.VERSION,
        groups = {}, displays = { { name = longName } } })
    local collideSummary, collideErr = Share.ImportString(collide)
    if not collideSummary or collideSummary.renamed ~= 1 then
        fail("colliding maximum-length import must rename: " .. tostring(collideErr))
    end
    local renamed = AD.GetDisplay(collideSummary.rootID or "") or nil
    local found
    for _, d in ipairs(AD.OrderedDisplays()) do
        if d.name ~= longName and d.name:sub(1, 100) == string.rep("N", 100) then found = d end
    end
    if not found or #found.name > 120 or not found.name:find(" 2$") then
        fail("renamed name must fit the limit with its suffix, got " .. tostring(found and #found.name))
    end
    local reexport = Share.ExportDisplayString(found.id)
    local okRe = Share.Decode(reexport)
    if not okRe then fail("a renamed maximum-length display must re-export and decode") end
end

-- Import is public: a caller bypassing Decode gets the same rejection.
local direct, directErr = Share.Import({ type = Share.PAYLOAD_TYPE, version = 1, groups = { 1 }, displays = {} })
if direct ~= nil or type(directErr) ~= "string" then fail("Import must reject malformed payloads itself") end

-- A well-formed payload with only optional fields still imports.
local minimal = Share.Encode({ type = Share.PAYLOAD_TYPE, version = Share.VERSION,
    groups = {}, displays = { { name = "Minimal" } } })
local minimalSummary, minimalErr = Share.ImportString(minimal)
if not minimalSummary or minimalSummary.displays ~= 1 then
    fail("minimal well-formed payload must import: " .. tostring(minimalErr))
end

print("OK: aura_display_share_test")
