local path = os.getenv("QUI_LAYOUT_SOURCE") or "core/settings_layout_shared.lua"
local function frame()
    local f = {}
    function f:ClearAllPoints() end
    function f:SetPoint() end
    function f:SetHeight(h) self.height = h end
    function f:GetHeight() return self.height end
    return f
end
local ns = { QUI_Options = { PADDING = 15,
    CreateAccentDotLabel = function() return frame() end,
    CreateSettingsCardGroup = function() local f=frame(); f.height=40; return {frame=f,Finalize=function() end} end,
} }
assert(loadfile(path))("QUI", ns)
local content=frame()
local layout=ns.QUI_SettingsLayoutShared.MakeLayout(content)
layout.headerAt("First")
layout.closeSection(layout.sectionAt())
layout.relayoutSections()
assert(content:GetHeight()==86, "provider height must end ten pixels after its last card without reserving the next section gap")
layout.headerAt("Second")
layout.closeSection(layout.sectionAt())
layout.relayoutSections()
assert(content:GetHeight()==166, "inter-section spacing must be preserved while trailing spacing is removed")
print("OK: provider_trailing_space_test")
