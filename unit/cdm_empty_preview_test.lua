local path = os.getenv('QUI_CDM_COMPOSER_SOURCE') or 'QUI_CDM/cdm/settings/composer.lua'
local f = assert(io.open(path)); local source = f:read('*a'); f:close()
local body = assert(source:match('(local function UpdatePreviewEmptyState%(container%).-\nend)\n'), 'Missing empty-preview state')
local frames
local ns = { CDMComposerPreview = { GetContentFrames = function() return frames end } }
local fn = assert(loadstring(body .. '\nreturn UpdatePreviewEmptyState'))
setfenv(fn, setmetatable({ns=ns}, {__index=_G}))
local update = fn()
local label = {SetShown=function(self, value) self.shown=value end}
local container = {_emptyPreviewText=label}
update(container); assert(label.shown, 'Missing driver data must explain empty preview')
frames={}; update(container); assert(label.shown, 'Empty container must explain empty preview')
frames={{}}; update(container); assert(not label.shown, 'Populated preview must hide empty text')
frames={}; update(container); assert(label.shown, 'Switching back to empty must restore hint')
update(nil); update({})
assert(source:find('UpdatePreviewEmptyState(container)', source:find('local function ResizePreviewToContent'), true), 'Preview refresh must update empty state')
assert(source:find('container._emptyPreviewText = emptyText', 1, true), 'Preview must own its hint')
print('CDM empty preview state passed')
