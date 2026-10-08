local file = assert(io.open("tools/generate_search_cache.lua", "rb"))
local source = file:read("*a")
file:close()
local marker = assert(source:find('local frame = create_stub_node("Frame", nil, false)', 1, true))
assert(loadstring(source:sub(1, marker - 1)))()
local GUI = QUI.GUI
local function Upvalue(callback, wanted, replacement, replace)
    for index = 1, math.huge do
        local name, value = debug.getupvalue(callback, index)
        if not name then break end
        if name == wanted then
            if replace then debug.setupvalue(callback, index, replacement) end
            return value
        end
    end
    error("missing upvalue: " .. wanted)
end
local ns = Upvalue(GUI.EnsureSearchCacheLoaded, "ns")
local create = CreateFrame
_G.CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    frame._scripts = {}
    frame.SetScript = function(self, event, callback) self._scripts[event] = callback end
    frame.HookScript = function(self, event, callback)
        local previous = self._scripts[event]
        self._scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    frame.IsVisible = function(self)
        local parent = self:GetParent()
        return self:IsShown() and (not parent or parent:IsVisible())
    end
    local function Toggle(self, shown)
        local previous = {}
        local function Save(node)
            previous[node] = node:IsVisible()
            for _, child in ipairs({ node:GetChildren() }) do Save(child) end
        end
        Save(self)
        self._shown = shown
        local function Notify(node)
            local visible = node:IsVisible()
            local callback = node._scripts and node._scripts[visible and "OnShow" or "OnHide"]
            if previous[node] ~= visible and callback then callback(node) end
            for _, child in ipairs({ node:GetChildren() }) do Notify(child) end
        end
        Notify(self)
    end
    frame.Show = function(self) Toggle(self, true) end
    frame.Hide = function(self) Toggle(self, false) end
    frame.SetShown = function(self, shown) Toggle(self, not not shown) end
    if kind == "Slider" then
        local thumb = frame:CreateTexture()
        frame.GetThumbTexture = function() return thumb end
    end
    return frame
end
ns.QUI_Options.CreateScrollableContent = function(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local body = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(body)
    return scroll, body
end
_G.C_Timer.After = function() end
local AD = ns.QUI_AuraDisplays
QUI.QUICore.db.profile.auraDisplays = { enabled = true, displays = {}, order = {}, groups = {} }
local display = assert(AD.NewDisplay("Preview lifecycle"))
local shows, hides, drags = {}, {}, {}
AD.ShowPreviewFor = function(id) shows[#shows + 1] = id end
AD.HidePreviewFor = function(id) hides[#hides + 1] = id end
AD.EnablePreviewDrag = function(kind, id) drags[#drags + 1] = { kind, id } end
AD.DisablePreviewDrag = function() end
local build = ns.QUI_AuraDisplaysOptions.BuildAuraDisplaysContent
Upvalue(build, "selectedID", display.id, true)
local page = CreateFrame("Frame")
page:Hide()
local body = CreateFrame("Frame", nil, page)
assert(body:IsShown() and not body:IsVisible(), "warmed bodies retain their own shown flag")
assert(build(body) > 300, "the native display list and selected detail editor mount")
assert(#shows == 0 and #drags == 0, "a selected display must not activate preview or dragging during hidden construction")
page:Show()
assert(#shows == 1 and shows[1] == display.id and drags[1][2] == display.id,
    "actual ancestor visibility restores the selected display preview and dragging")
page:Hide()
assert(#hides == 1 and hides[1] == display.id, "leaving the owner page clears its preview")
page:Show()
assert(#shows == 2 and shows[2] == display.id, "the cached detail editor restores its selected preview")
local other = assert(AD.NewDisplay("Other selected display"))
Upvalue(build, "selectedID", other.id, true)
local nextPage = CreateFrame("Frame")
nextPage:Hide()
assert(build(CreateFrame("Frame", nil, nextPage)) > 300, "a new hidden owner can mount the retained selection")
assert(#shows == 2 and #hides == 2 and hides[2] == display.id,
    "warming a replacement owner hides the old preview without activating the replacement")
nextPage:Show()
assert(#shows == 3 and shows[3] == other.id, "showing the replacement owner restores only its current selection")
nextPage:Hide()
local groupShows, groupHides = {}, {}
AD.ShowPreviewForGroup = function(name) groupShows[#groupShows + 1] = name end
AD.HidePreviewForGroup = function(name) groupHides[#groupHides + 1] = name end
assert(AD.GetGroup("Preview group", true))
Upvalue(build, "selectedID", nil, true)
Upvalue(build, "selectedGroup", "Preview group", true)
local groupPage = CreateFrame("Frame")
groupPage:Hide()
assert(build(CreateFrame("Frame", nil, groupPage)) > 300, "the native group layout editor mounts while hidden")
assert(#groupShows == 0, "hidden group selection does not activate its preview")
groupPage:Show()
assert(#groupShows == 1 and groupShows[1] == "Preview group" and drags[#drags][1] == "group",
    "visible group layout restores the group preview and drag context")
groupPage:Hide()
assert(#groupHides == 1 and groupHides[1] == "Preview group", "leaving group layout clears its preview")
print("options_aura_display_preview_warm_test: ok")
