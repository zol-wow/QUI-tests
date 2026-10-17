local source=arg and arg[1] or "modules/skinning/frames/auctionhouse.lua"
arg={source,"auctions"}
dofile("tests/unit/auctionhouse_item_buy_controls_test.lua")
