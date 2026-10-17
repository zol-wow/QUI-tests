-- tests/unit/cdm_composer_preview_auto_height_test.lua
-- Run: lua tests/unit/cdm_composer_preview_auto_height_test.lua

local function read(path)
    local handle = assert(io.open(path, "rb"))
    local source = handle:read("*a")
    handle:close()
    return source
end

local composer = read(os.getenv("QUI_COMPOSER_SOURCE") or "QUI_CDM/cdm/settings/composer.lua")
local driver = read("QUI_CDM/cdm/settings/composer_preview_driver.lua")
local page = read("QUI_CDM/cdm/settings/containers_page.lua")

local previewStart = assert(composer:find("local function BuildPreviewSection(", 1, true))
local backdropStart = assert(composer:find("    local _bpsBR", previewStart, true))
local backdropEnd = assert(composer:find("    local title =", backdropStart, true))
local style = assert((loadstring or load)("return function(container, autoHeightOptions, GetChromeBgSubpanel, GetChromeBorder, SetSimpleBackdrop)\n"
    .. composer:sub(backdropStart, backdropEnd - 1) .. "\nend"))()
local backdropCalls = 0
local function color() return 0.2, 0.2, 0.2 end
local function backdrop() backdropCalls = backdropCalls + 1 end
style({}, {outer = {}}, color, color, backdrop)
assert(backdropCalls == 0, "inline CDM preview must not draw a second border inside its rounded card")
style({}, {}, color, color, backdrop)
assert(backdropCalls == 1, "standalone CDM preview must retain its own surface")
local failures = 0
local function check(name, ok)
    if ok then
        print("  ok  " .. name)
    else
        failures = failures + 1
        print("FAIL  " .. name)
    end
end

check("composer measures only driver-owned icon or bar roots",
    composer:find("local function MeasurePreviewContentHeight", 1, true) ~= nil
    and composer:find("driver.GetContentFrames", 1, true) ~= nil
    and driver:find("function CDMComposerPreview.GetContentFrames", 1, true) ~= nil)

check("fit includes outsetting borders and vertical breathing room",
    composer:find("IncludePreviewBounds(frame.Border, bounds, true)", 1, true) ~= nil
    and composer:find("IncludePreviewBounds(frame.BorderContainer, bounds, true)", 1, true) ~= nil
    and composer:find("PREVIEW_CONTENT_VERTICAL_PADDING * 2", 1, true) ~= nil)

check("fit runs after refreshed frame bounds settle",
    composer:find("local function RequestPreviewAutoHeight", 1, true) ~= nil
    and composer:find("C_Timer.After(0, Apply)", 1, true) ~= nil
    and composer:find("RequestPreviewAutoHeight(previewFrame)", 1, true) ~= nil)

check("fit resizes the configured outer pane and recenters content",
    composer:find("outer:SetHeight(desiredHeight)", 1, true) ~= nil
    and composer:find("driver.Relayout()", 1, true) ~= nil
    and driver:find("function CDMComposerPreview.Relayout", 1, true) ~= nil)

check("standalone composer sections follow the fitted preview",
    composer:find('entrySection:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)', 1, true) ~= nil
    and composer:find('preview:HookScript("OnSizeChanged", Relayout)', 1, true) ~= nil
    and composer:find("frame._composerNaturalHeight = previewHeight", 1, true) ~= nil
    and composer:find("local PREVIEW_H", 1, true) == nil)

check("pinned composer preview fits its outer surface pane",
    page:find("outer = pv", 1, true) ~= nil
    and page:find("outerChromeHeight = leftCol:GetHeight() + 12", 1, true) ~= nil
    and composer:find("container._previewChromeHeight + PREVIEW_MIN_CONTENT_HEIGHT", 1, true) ~= nil)

check("preview scale slider is removed and its space is reclaimed",
    composer:find('ns.L["Preview Scale:"]', 1, true) == nil
    and composer:find("local sliderTrack", 1, true) == nil
    and composer:find('gridArea:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -8, 8)', 1, true) ~= nil
    and composer:find("local PREVIEW_INNER_CHROME_HEIGHT = 32", 1, true) ~= nil)

check("rebuilt preview hosts rebind the singleton driver grid",
    driver:find("state.gridArea = gridArea", 1, true) ~= nil
    and driver:find("state.ticker:SetParent(gridArea)", 1, true) ~= nil)

if failures > 0 then
    print(("%d failures"):format(failures))
    os.exit(1)
end

local resizeStart = assert(composer:find("local function UpdatePreviewEmptyState(container)", 1, true))
local resizeEnd = assert(composer:find("local function RequestPreviewAutoHeight", resizeStart, true))
local resize = assert(loadstring([[
local ns = {}
local math_floor, math_max, math_abs = math.floor, math.max, math.abs
local PREVIEW_INNER_CHROME_HEIGHT, PREVIEW_MIN_CONTENT_HEIGHT = 32, 60
local function MeasurePreviewContentHeight() return 20 end
]] .. composer:sub(resizeStart, resizeEnd - 1) .. "return ResizePreviewToContent"))()
local outer = { height = 230, _quiPreviewChromeHeight = 40 }
function outer:SetHeight(value) self.height = value end
function outer:GetHeight() return self.height end
local container = {
    _previewAutoHeight = true,
    _previewOuter = outer,
    _previewChromeHeight = 94,
    _previewMinHeight = 154,
    _previewMinHeightFixed = false,
}
resize(container)
assert(outer.height == 132, "measured CDM autoheight uses current narrow/short header instead of stale initial chrome")
outer._quiPreviewChromeHeight = 72
resize(container)
assert(outer.height == 164, "wrapped CDM header reserves its actual extra height")
outer._quiPreviewChromeHeight = 40
resize(container)
assert(outer.height == 132, "unwrapping CDM header releases height without drift")
container._previewMinHeightFixed, container._previewMinHeight = true, 180
resize(container)
assert(outer.height == 180, "explicit preview minimum remains stable across responsive chrome")
print("cdm_composer_preview_auto_height_test: all checks passed")
