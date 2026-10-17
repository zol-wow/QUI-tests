local sources = {}
local function NativeMethod(path, owner, method)
    local source = sources[path]
    if not source then
        local file = assert(io.open(path))
        source = file:read("*a")
        file:close()
        sources[path] = source
    end
    local first = assert(source:find("function " .. owner .. ":" .. method .. "(", 1, true))
    local last = assert(source:find("\nend", first, true)) + 3
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    local target = {}
    local chunk = assert(loadstring(string.rep("\n", lines) .. source:sub(first, last), "@" .. path))
    setfenv(chunk, setmetatable({ [owner] = target }, { __index = _G }))
    chunk()
    return assert(target[method])
end

return function(selector, rows)
    local root = "tests/framexml/Interface/AddOns/Blizzard_SharedXML/Shared/"
    local scrollBox = {}
    selector.ScrollBox = scrollBox
    for _, method in ipairs({ "GetView", "HasView" }) do
        scrollBox[method] = NativeMethod(root .. "Scroll/ScrollBox.lua", "ScrollBoxBaseMixin", method)
    end
    for _, method in ipairs({ "ForEachFrame", "EnumerateFrames" }) do
        scrollBox[method] = NativeMethod(root .. "Scroll/ScrollBox.lua", "ScrollBoxListMixin", method)
    end
    selector.EnumerateButtons = NativeMethod(root .. "Selector/Blizzard_ScrollBoxSelector.lua", "ScrollBoxSelectorMixin", "EnumerateButtons")
    local view = { frames = rows }
    view.GetFrames = NativeMethod(root .. "Scroll/ScrollBoxView.lua", "ScrollBoxViewMixin", "GetFrames")
    for _, method in ipairs({ "ForEachFrame", "EnumerateFrames" }) do
        view[method] = NativeMethod(root .. "Scroll/ScrollBoxListView.lua", "ScrollBoxListViewMixin", method)
    end
    return view
end
