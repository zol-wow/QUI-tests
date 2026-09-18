local file = assert(io.open("QUI_DamageMeter/damage_meter/damage_meter.lua", "rb"))
local src = file:read("*a")
file:close()
local chunk = assert(src:match("(function Window:_ApplyFonts%(%).-\nend)"))

local function fontString()
    return {
        SetFont = function(self, path, size, outline)
            self.font = { path, size, outline }
            self.shadowColor = nil
            self.shadowOffset = nil
        end,
        SetShadowColor = function(self, ...)
            self.shadowColor = { ... }
        end,
        SetShadowOffset = function(self, ...)
            self.shadowOffset = { ... }
        end,
    }
end

local function row()
    return { Name = fontString(), Value = fontString() }
end

local slots = { header = "", rowName = "", rowValue = "" }
local Window = {}
local ns = { Helpers = {} }
local loader = assert(loadstring(chunk))
setfenv(loader, {
    Window = Window,
    ns = ns,
    ResolveAppearance = function(_, _, slot) return slots[slot] end,
    ResolveFontSlot = function(outline) return "test.ttf", 11, outline end,
})
loader()

local window = {
    rows = { row(), row() },
    stickyRow = row(),
    TypeLabel = fontString(),
    SessionTimer = fontString(),
    SegmentButton = { text = fontString() },
}

local function check(fs, outline)
    local shadow = outline == "" and 1 or 0
    assert(fs.font[3] == outline, "outline must be preserved")
    assert(fs.shadowColor and fs.shadowColor[1] == 0
        and fs.shadowColor[2] == 0 and fs.shadowColor[3] == 0
        and fs.shadowColor[4] == shadow, "black shadow must follow outline selection")
    assert(fs.shadowOffset and fs.shadowOffset[1] == shadow
        and fs.shadowOffset[2] == -shadow, "shadow must be one pixel or cleared")
end

for _, useFallback in ipairs({ false, true }) do
    ns.Helpers.ApplyFontWithFallback = useFallback and function(fs, ...)
        fs:SetFont(...)
    end or nil
    for _, outline in ipairs({ "", "OUTLINE", "THICKOUTLINE", "" }) do
        slots.rowName = outline
        slots.rowValue = outline == "" and "OUTLINE" or ""
        Window._ApplyFonts(window)
        for _, r in ipairs({ window.rows[1], window.rows[2], window.stickyRow }) do
            check(r.Name, slots.rowName)
            check(r.Value, slots.rowValue)
        end
        check(window.TypeLabel, slots.header)
        check(window.SessionTimer, slots.header)
        check(window.SegmentButton.text, slots.header)
    end
end

print("OK: damage_meter_font_shadow_test")
