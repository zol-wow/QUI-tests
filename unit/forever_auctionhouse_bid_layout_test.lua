local Harness = dofile("tests/helpers/character_chrome_harness.lua")
for _, forever in ipairs({ true, false }) do
    local h = Harness.Build()
    local skin, ns = h.SkinBase, h.ns
    ns.Client = { isForever = forever }
    h.profile.general.skinAuctionHouse = true
    local function frame(kind, parent)
        local f = h.NewFrame(kind or "Frame", nil, parent)
        f.RegisterForWidgetSet, f.DisabledTexture = false, false
        return f
    end
    local ah = frame()
    _G.AuctionHouseFrame = ah
    local panel = frame(nil, ah)
    ah.AuctionsFrame = panel
    panel.BackButton, panel.CancelAuctionButton = false, false
    local bid = frame(nil, panel)
    panel.BidFrame = bid
    bid.BidButton = frame("Button", bid)
    local money = frame(nil, bid)
    bid.BidAmount = money
    money:SetSize(167, 18)
    local nativeInput = function() error("must not submit a bid") end
    for index, key in ipairs({ "gold", "silver", "copper" }) do
        local field = frame("EditBox", money)
        money[key] = field
        field:SetSize(index == 1 and 61 or 48, 20)
        field.texture = field:CreateTexture()
        field.texture:SetAtlas("native-coin-" .. key)
        field:SetScript("OnEnterPressed", nativeInput)
    end
    money.gold:SetPoint("TOPLEFT", money, "TOPLEFT", 0, 0)
    money.silver:SetPoint("LEFT", money.gold, "RIGHT", 10, 0)
    money.copper:SetPoint("LEFT", money.silver, "RIGHT", 10, 0)
    bid.BidButton:SetPoint("LEFT", money, "RIGHT", 0, 0)
    bid.BidButton:SetScript("OnClick", nativeInput)
    local buttonAnchor = bid.BidButton.points[1]
    local list = frame(nil, panel)
    panel.AllAuctionsList = list
    list.ScrollBox = false
    list.LoadingSpinner = frame(nil, list)
    local label = list.LoadingSpinner:CreateFontString()
    list.LoadingSpinner.SearchingText = label
    label:SetFont("Native", 27, "")
    label:SetText("Searching...")
    label:SetTextColor(1, 0.81960791349411, 0, 0.8)
    _G.NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82352941176471, 0 end }
    ns.SafeCall = function(_, fn) fn() end
    skin.OnAddOnLoaded = function(_, fn) fn() end
    assert(loadfile(os.getenv("QUI_AUCTION_SOURCE") or "modules/skinning/frames/auctionhouse.lua"))("QUI", ns)
    local function inputRight()
        return select(4, money.gold:GetPoint(1)) + money.gold:GetWidth()
            + 10 + money.silver:GetWidth() + 10 + money.copper:GetWidth()
    end
    if forever then
        assert(inputRight() <= money:GetWidth() - 8, "Forever copper input must leave a gap before Bid")
        local firstOffset = select(4, money.gold:GetPoint(1))
        _G.QUI_RefreshAuctionHouseColors()
        assert(select(4, money.gold:GetPoint(1)) == firstOffset, "refresh must not accumulate offsets")
        money.gold:SetWidth(70)
        money.gold:Fire("OnSizeChanged", 70, 20)
        assert(inputRight() <= money:GetWidth() - 8, "native field resizing must keep inputs clear of Bid")
        assert(label.textColor[1] == 0.9 and label.textColor[4] == 0.8,
            "Forever quantized normal gold must receive neutral typography with native opacity")
    else
        assert(select(4, money.gold:GetPoint(1)) == 0 and not money.gold.hooks.OnSizeChanged,
            "Retail bid layout must remain unchanged")
        assert(label.textColor[1] == 1 and label.textColor[2] == 0.81960791349411,
            "Retail color matching must remain unchanged")
    end
    label:SetTextColor(1, 0, 0, 0.6)
    _G.QUI_RefreshAuctionHouseColors()
    assert(label.textColor[2] == 0 and label.textColor[4] == 0.6, "semantic error red must remain")
    local _, size = label:GetFont()
    assert(size == 27 and label:GetText() == "Searching...", "native message and size must remain")
    assert(bid.BidButton.points[1] == buttonAnchor and bid.BidButton:GetScript("OnClick") == nativeInput,
        "action geometry and native click handler must remain")
    for _, key in ipairs({ "gold", "silver", "copper" }) do
        assert(money[key].texture.atlas == "native-coin-" .. key
            and money[key]:GetScript("OnEnterPressed") == nativeInput, "native coins and input handlers must remain")
    end
end
print("OK: Forever bid fields fit, normal captions style, and Retail/native behavior remains")
