--[[
	MarketConfig.luau
	=================
	Everything players can invest in from the phone's Market app:
	30 stocks, a few cryptocurrencies, and NFT collections.

	ALL of these are made up. They are parodies for a game, not real
	companies or coins.

	How prices move (see src/server/Market.luau):
	  * Every TickInterval seconds each price takes a random step.
	  * Prices are gently pulled back toward their Base price, so a crash
	    usually recovers and a spike usually cools off. Buy low, sell high!
	  * Sometimes there's breaking news: one asset jumps or crashes.
	  * Prices are the same for everyone in a server. They are not saved:
	    a new server starts fresh around each Base price.

	Asset fields:
	  Id        unique id, used for saving. Don't rename it after people have
	            invested, or they'll lose those holdings.
	  Name      what players see.
	  Base      the "normal" price the market drifts around.
	  Vol       how wild it is: how big each random step is.
	                0.01 = calm, 0.03 = jumpy, 0.07 = rollercoaster.
]]

local MarketConfig = {}

MarketConfig.TickInterval = 3 -- seconds between price changes
MarketConfig.PullBack = 0.01 -- how strongly prices drift back toward Base (0 = never)
MarketConfig.MinMultiplier = 0.05 -- a price can't fall below 5% of Base...
MarketConfig.MaxMultiplier = 20 -- ...or climb above 20x Base
MarketConfig.NewsChance = 0.001 -- chance per asset per tick of a big news jump (about once a minute overall)
MarketConfig.HistoryLength = 60 -- price points kept for the little charts
MarketConfig.MinTrade = 1 -- smallest buy, in dollars

-- Vol presets so the lists below are easy to read
local CALM, NORMAL, JUMPY = 0.012, 0.02, 0.032

MarketConfig.Categories = {
	{
		Id = "stocks",
		Name = "Stocks",
		Kind = "fractional", -- invest any dollar amount
		Assets = {
			{ Id = "SQZY", Name = "Squeezy Lemon Co", Base = 12, Vol = NORMAL },
			{ Id = "THRD", Name = "ThreadHead Apparel", Base = 45, Vol = NORMAL },
			{ Id = "TRBO", Name = "Turbo Motors", Base = 180, Vol = NORMAL },
			{ Id = "BOXD", Name = "BoxDrop Shipping", Base = 60, Vol = JUMPY },
			{ Id = "WOWV", Name = "WOWVidia", Base = 900, Vol = JUMPY },
			{ Id = "PXPZ", Name = "Pixel Pizza", Base = 25, Vol = CALM },
			{ Id = "BRGB", Name = "Burger Barn", Base = 38, Vol = CALM },
			{ Id = "KCKZ", Name = "Kickz Sneakers", Base = 72, Vol = NORMAL },
			{ Id = "SKYL", Name = "SkyLaunch Aerospace", Base = 310, Vol = JUMPY },
			{ Id = "CLDN", Name = "CloudNest Software", Base = 220, Vol = NORMAL },
			{ Id = "GMRZ", Name = "Gamerz Gear", Base = 55, Vol = NORMAL },
			{ Id = "FRSH", Name = "FreshFarm Foods", Base = 30, Vol = CALM },
			{ Id = "SPRK", Name = "SunSpark Energy", Base = 85, Vol = JUMPY },
			{ Id = "GVLT", Name = "Golden Vault Bank", Base = 140, Vol = CALM },
			{ Id = "FZPP", Name = "FizzPop Soda", Base = 18, Vol = CALM },
			{ Id = "PAWZ", Name = "Pawsome Pets", Base = 42, Vol = NORMAL },
			{ Id = "POPC", Name = "Popcorn Pictures", Base = 65, Vol = NORMAL },
			{ Id = "RBTL", Name = "RoboButler Robotics", Base = 260, Vol = JUMPY },
			{ Id = "CHOP", Name = "ChipChop Snacks", Base = 22, Vol = CALM },
			{ Id = "DDSH", Name = "DigiDash Delivery", Base = 48, Vol = NORMAL },
			{ Id = "CZYH", Name = "Cozy Castle Homes", Base = 120, Vol = CALM },
			{ Id = "GLTR", Name = "Glitter Gold Mining", Base = 95, Vol = NORMAL },
			{ Id = "PKPH", Name = "Pocket Phone Co", Base = 400, Vol = NORMAL },
			{ Id = "BASS", Name = "Bass Boost Music", Base = 33, Vol = NORMAL },
			{ Id = "BRNY", Name = "Brainy Books", Base = 15, Vol = CALM },
			{ Id = "TOYT", Name = "ToyTopia", Base = 28, Vol = NORMAL },
			{ Id = "STRF", Name = "Starfruit Space", Base = 150, Vol = JUMPY },
			{ Id = "DNOP", Name = "Dino Park Resorts", Base = 75, Vol = NORMAL },
			{ Id = "WAVR", Name = "WaveRider Surf", Base = 20, Vol = NORMAL },
			{ Id = "SGRR", Name = "Sugar Rush Candy", Base = 10, Vol = JUMPY },
		},
	},
	{
		Id = "crypto",
		Name = "Crypto",
		Kind = "fractional",
		Assets = {
			-- BitBucks is a made-up parody of Bitcoin.
			{ Id = "BUX", Name = "BitBucks", Base = 42_000, Vol = 0.04 },
			{ Id = "BYTG", Name = "ByteGold", Base = 2_400, Vol = 0.05 },
			{ Id = "LAMBO", Name = "Lambo Token", Base = 3.5, Vol = 0.07 },
			{ Id = "MPUP", Name = "MoonPup Coin", Base = 0.25, Vol = 0.09 },
		},
	},
	{
		Id = "nfts",
		Name = "NFTs",
		Kind = "whole", -- buy and sell one at a time, at the collection's floor price
		Assets = {
			{ Id = "NFT_PICKLE", Name = "Pixel Pickles", Base = 500, Vol = 0.05, Icon = "🥒" },
			{ Id = "NFT_GOBLIN", Name = "Grumpy Goblins", Base = 2_500, Vol = 0.05, Icon = "👺" },
			{ Id = "NFT_HAMSTER", Name = "Laser Hamsters", Base = 12_000, Vol = 0.055, Icon = "🐹" },
			{ Id = "NFT_CACTUS", Name = "Sad Cactus Society", Base = 60_000, Vol = 0.055, Icon = "🌵" },
			{ Id = "NFT_DUCK", Name = "Rich Duck Club", Base = 250_000, Vol = 0.06, Icon = "🦆" },
			{ Id = "NFT_GECKO", Name = "Golden Gecko Gang", Base = 2_000_000, Vol = 0.06, Icon = "🦎" },
			{ Id = "NFT_DRAGON", Name = "Diamond Dragons", Base = 25_000_000, Vol = 0.065, Icon = "🐉" },
		},
	},
}

-- Lookup tables built automatically. You never need to edit this part.
--   MarketConfig.AssetsById["BUX"] -> the asset, plus .Category and .Kind
--   MarketConfig.AssetList         -> every asset in display order
MarketConfig.AssetsById = {}
MarketConfig.AssetList = {}
for _, category in MarketConfig.Categories do
	for _, asset in category.Assets do
		assert(MarketConfig.AssetsById[asset.Id] == nil, "Duplicate asset Id in MarketConfig: " .. asset.Id)
		asset.Category = category.Id
		asset.Kind = category.Kind
		MarketConfig.AssetsById[asset.Id] = asset
		table.insert(MarketConfig.AssetList, asset)
	end
end

-- Shows prices with cents when they're small: $0.25, $12.40, $42.0K
function MarketConfig.formatPrice(value: number): string
	if value >= 10_000 then
		local suffixes = { "", "K", "M", "B", "T", "Qa" }
		local index = 1
		while value >= 1000 and index < #suffixes do
			value /= 1000
			index += 1
		end
		return string.format(if value >= 100 then "$%.0f%s" elseif value >= 10 then "$%.1f%s" else "$%.2f%s", value, suffixes[index])
	elseif value >= 1 then
		return string.format("$%.2f", value)
	end
	return string.format("$%.4f", value)
end

return MarketConfig
