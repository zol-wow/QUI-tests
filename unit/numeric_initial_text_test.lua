local source = os.getenv('QUI_LAYOUT_SOURCE') or 'core/settings_layout_shared.lua'
local ns = {}
assert(loadfile(source))('QUI', ns)
local Shared = ns.QUI_SettingsLayoutShared
assert(type(Shared.RefreshInitialEditText) == 'function', 'numeric controls need a settled-layout text refresh')
local function check(focused)
    local ready, layout = false, false
    local parent = { GetTop = function() return ready and 800 or nil end }
    local edit = { text = '50', rendered = '', scripts = {}, changes = 0 }
    function edit:SetScript(name, fn) self.scripts[name] = fn end
    function edit:HasFocus() return focused end
    function edit:GetText() return self.text end
    function edit:SetText(value)
        local changed = value ~= self.text
        self.text = value
        self.changes = self.changes + 1
        if changed and layout then self.rendered = value end
    end
    function edit:SetCursorPosition(pos) self.cursor = pos end
    Shared.RefreshInitialEditText(edit, parent)
    edit.scripts.OnUpdate(edit)
    assert(edit.changes == 0, 'must wait for parent bounds')
    ready = true
    edit.scripts.OnUpdate(edit)
    assert(edit.changes == 0, 'must allow layout to settle')
    layout = true
    edit.scripts.OnUpdate(edit)
    assert(edit.text == '50', 'must preserve the current value')
    assert(edit.scripts.OnUpdate == nil, 'must stop after one refresh')
    if focused then
        assert(edit.changes == 0, 'must preserve an active edit')
    else
        assert(edit.rendered == '50', 'offscreen-created text must render after layout')
        assert(edit.cursor == 0, 'must reset the text viewport')
    end
end
check(false)
check(true)
local f = assert(io.open('QUI_Options/framework.lua')); local text = f:read('*a'); f:close()
assert(text:find('ns.QUI_SettingsLayoutShared.RefreshInitialEditText(editBox, container)', 1, true), 'slider must use the shared refresh')
print('numeric initial text refresh passed')
