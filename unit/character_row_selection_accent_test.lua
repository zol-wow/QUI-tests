local env = dofile("tests/helpers/character_chrome_harness.lua").Build()
local file = assert(io.open("modules/skinning/frames/character.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function IsRowSelected(", 1, true))
local last = assert(source:find("local function HookRowHover(", first, true))
local bars = {}
local scope = setmetatable({
    SkinBase = env.SkinBase, rowAccentBars = bars,
    Helpers = { GetProfile = function() return { general = {} } end },
    UIKit = { DisablePixelSnap = function() end },
    RowToken = function() return {1,1,1,1} end,
}, {__index = _G})
scope.SkinBase.GetPixelSize = function() return .5 end
scope.SkinBase.GetSkinColors = function() return .8,.1,.2,1 end
local chunk = assert(loadstring(source:sub(first, last - 1) .. "\nreturn SyncRowSelection"))
setfenv(chunk, scope)
local sync = chunk()
local row = env.NewFrame("Button")
row.SelectedBar = row:CreateTexture()
row.Check = row:CreateTexture()
row.Check.SetDesaturated = function(self, value) self.desaturated = value end
row.text = row:CreateFontString()
local click = function() end
row:SetScript("OnClick", click)
sync(row)
assert(bars[row]:GetWidth() == .5, "row selection uses one physical pixel")
assert(row.Check.desaturated, "native gold check is desaturated before accent tint")
assert(row.Check.vertex[1] == .8 and row.Check.vertex[2] == .1,
    "selection uses border accent without the text luminance floor")
assert(bars[row]:IsShown(), "native selected state shows the selection line")
row.SelectedBar:Hide()
sync(row)
assert(not bars[row]:IsShown(), "recycled unselected row clears the line")
assert(row:GetScript("OnClick") == click, "native title/set action remains intact")
print("OK: character_row_selection_accent_test")
scope.skinnedEntries = {}
scope.CJKFont = function() end
scope.GetFontPath = function() return "font.ttf" end
scope.HookRowHover = function() end
scope.SyncRowSelection = sync
local entryFirst = assert(source:find("local function HideTitleRowArt(", 1, true))
local entryLast = assert(source:find("local function SkinTitleManagerPane(", entryFirst, true))
local entryChunk = assert(loadstring(source:sub(entryFirst, entryLast - 1) .. "\nreturn SkinTitleEntry, RefreshTitleEntry"))
setfenv(entryChunk, scope)
local entrySkin, refresh = entryChunk()
local nativeHover = row:CreateTexture()
row.GetHighlightTexture = function() return nativeHover end
entrySkin(row)
refresh(row)
assert(nativeHover:GetAlpha() == 0, "native blue title gradient must stay suppressed")
assert(scope.SkinBase.GetFrameData(row, "qRowHighlight"), "title hover feedback remains available")
