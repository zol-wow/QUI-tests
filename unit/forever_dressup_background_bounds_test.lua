local Harness = dofile("tests/helpers/character_chrome_harness.lua")
for _, forever in ipairs({ true, false }) do
    local h = Harness.Build()
    h.ns.Client = { isForever = forever }
    h.profile.general.skinDressUp = true
    local function Frame(kind, parent)
        local frame = h.NewFrame(kind or "Frame", nil, parent)
        setmetatable(frame, { __index = function(_, key)
            if key:match("^Get") or key:match("^Set[A-Z]") then return function() end end
        end })
        return frame
    end
    local frame = Frame()
    _G.DressUpFrame = frame
    frame.CustomSetDetailsPanel = Frame(nil, frame)
    frame.SetSelectionPanel = Frame(nil, frame)
    local scene = Frame("ModelScene", frame)
    frame.ModelScene = scene
    scene:SetSize(434, 454)
    scene:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -63)
    scene:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -9, 28)
    for _, key in ipairs({ "BGTopLeft", "BGTopRight", "BGBottomLeft", "BGBottomRight" }) do
        local texture = scene:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture("native-race-art-" .. key)
        texture:SetHeight(key:find("Top") and 348 or 175)
        texture:SetWidth(key:find("Right") and 85 or 349)
        scene[key] = texture
    end
    local click = function() end
    scene:SetScript("OnMouseDown", click)
    h.SkinBase.OnAddOnLoaded = function(_, callback) callback() end
    assert(loadfile(os.getenv("QUI_MISC_SOURCE") or "modules/skinning/frames/misc_frames.lua"))("QUI", h.ns)
    local function Check(width, height)
        assert(scene:GetWidth() == width and scene:GetHeight() == height, "skin must retain native model size")
        assert(scene.points[1][5] == -63 and scene.points[2][5] == 28, "model anchors must remain native")
        assert(scene:GetScript("OnMouseDown") == click, "model interaction must remain native")
        local total = scene.BGTopLeft:GetHeight() + scene.BGBottomLeft:GetHeight()
        if forever then
            assert(math.abs(total - height) < 0.001, "Forever race art must fit the preview without spilling into the footer")
            assert(scene.BGTopRight:GetHeight() == scene.BGTopLeft:GetHeight(), "upper tiles must meet")
            assert(scene.BGBottomRight:GetHeight() == scene.BGBottomLeft:GetHeight(), "lower tiles must meet")
            assert(math.abs(scene.BGTopRight:GetWidth() + scene.BGTopLeft.points[2][4]) < 0.001,
                "left and right artwork tiles must meet without a gap")
        else
            assert(total == 523 and scene.BGTopRight:GetWidth() == 85, "Retail artwork geometry must stay unchanged")
        end
        for _, key in ipairs({ "BGTopLeft", "BGTopRight", "BGBottomLeft", "BGBottomRight" }) do
            assert(scene[key].texture == "native-race-art-" .. key and scene[key]:GetAlpha() == 1,
                "retain the native race artwork")
        end
    end
    Check(434, 454)
    scene:SetSize(318, 332)
    scene:Fire("OnSizeChanged", 318, 332)
    Check(318, 332)
    scene:SetSize(434, 454)
    scene:Fire("OnSizeChanged", 434, 454)
    Check(434, 454)
end
print("OK: Forever Dressing Room artwork follows native preview bounds; Retail and model controls remain unchanged")
