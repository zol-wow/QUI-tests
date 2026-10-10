local path = os.getenv('QUI_IMPORT_SOURCE') or 'core/settings/content/import_export_content.lua'
local file = assert(io.open(path, 'r'))
local source = file:read('*a')
file:close()
local block = assert(source:match('(local pasteHint = GUI:CreateLabel.-pasteHint:SetPoint%b())'))
local label = { right = 210 }
local header = { right = 1000, _label = label }
local hint = {}
function hint:SetPoint(point, relative, relativePoint, offset)
    self.left = relative.right + offset
end
local env = {
    GUI = { CreateLabel = function() return hint end },
    postExportContainer = {},
    ns = { L = setmetatable({}, { __index = function(_, key) return key end }) },
    C = {},
    importHeader = header,
}
local chunk = assert(loadstring('return function(importHeader) ' .. block .. ' end'))
setfenv(chunk, env)
chunk()(header)
assert(hint.left == 222, 'paste hint must follow the title text within the section bounds')
print('import_hint_anchor_test: passed')
