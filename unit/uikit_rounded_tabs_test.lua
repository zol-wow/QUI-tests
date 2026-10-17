local f = assert(io.open(os.getenv("QUI_TAB_SOURCE") or "core/uikit.lua"))
local source = f:read("*a")
f:close()
local first = assert(source:find("function UIKit.CreateTabButton(", 1, true))
local last = assert(source:find("function UIKit.CreateObjectPool(", first, true))
local function noop() end
local label = {SetPoint=noop, SetText=noop, SetTextColor=noop, GetStringWidth=function() return 80 end}
local button = {SetHeight=noop, SetWidth=noop, CreateFontString=function() return label end,
    SetScript=function(self, event, fn) self[event]=fn end}
local fill, border, rounded
local UIKit = {
    GetAccentColor=function() return 1, 0.5, 0.2 end,
    ApplyPixelBackdrop=function() error("tabs must use shared rounded surfaces") end,
    CreateRoundedSurface=function(_, opts)
        rounded = opts.radius
        return {
            background={
                SetColorTexture=function(_, ...) fill={...} end,
                GetVertexColor=function() return unpack(fill) end,
            },
            SetColors=function(_, b, bg) border, fill=b, bg end,
        }
    end,
}
local env = setmetatable({UIKit=UIKit, CreateFrame=function() return button end,
    max=math.max}, {__index=_G})
local chunk = assert(loadstring(source:sub(first, last-1)))
setfenv(chunk, env)()
local tab = UIKit.CreateTabButton({}, {})
assert(rounded == 5, "tabs must use the shared five-pixel rounded surface")
tab:SetActive(true)
assert(border[1] == 1 and fill[1] == 0.15, "selection must update rounded chrome")
tab:SetActive(false)
tab.OnEnter(tab)
assert(border[1] == 0.7, "hover must update rounded border")
tab.OnLeave(tab)
assert(border[4] == 1, "leave must restore idle border")
print("OK: uikit_rounded_tabs_test")
