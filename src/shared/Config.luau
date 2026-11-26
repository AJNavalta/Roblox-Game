--[[
	Config.luau
	===========
	ALL the game's numbers live here. Want to rebalance the game, rename a
	business, or add a whole new stage? Edit this file only.

	How progression works:
	  * Stages unlock in order. Stage 1 is open from the start.
	  * Inside an unlocked stage you can buy its items in any order.
	  * Buy EVERY item in a stage to unlock the next stage.
	  * Each item adds "Income" dollars per second, which piles up in your
	    Cash Collector. Step on the collector to bank it.

	Item fields:
	  Id      unique text id, used for saving. Don't rename it after
	          people have played or they'll lose that item.
	  Name    what players see.
	  Cost    price in dollars.
	  Income  dollars per second it adds.
	  Height  (optional) how tall its building block is, in studs.

	Note: "WOWVidia" is a made-up parody company. Any resemblance to a real
	chip maker is purely for laughs.
]]

local Config = {}

Config.GameName = "Become a Billionaire Tycoon"

-- Economy -------------------------------------------------------------------
Config.StartingCash = 0 -- the first item is free, so new players can start earning
Config.IncomeInterval = 1 -- seconds between income payouts
Config.BillionaireGoal = 1_000_000_000

-- Saving --------------------------------------------------------------------
-- Changing this name starts everyone fresh (handy while testing a rebalance).
Config.DataStoreName = "BillionaireTycoon_v1"
Config.AutosaveInterval = 60 -- seconds

-- World ---------------------------------------------------------------------
Config.MaxPlots = 6 -- set your place's Max Players to this in Game Settings
Config.PlotRingRadius = 300 -- how far each plot sits from the middle of the map

-- Stages --------------------------------------------------------------------
Config.Stages = {
	{
		Id = "lemonade",
		Name = "Lemonade Stand",
		Color = Color3.fromRGB(255, 221, 87),
		Items = {
			{ Id = "lemon_pitcher", Name = "Lemonade Pitcher", Cost = 0, Income = 1 },
			{ Id = "lemon_table", Name = "Folding Table", Cost = 25, Income = 2 },
			{ Id = "lemon_sign", Name = "Hand-Painted Sign", Cost = 80, Income = 4 },
			{ Id = "lemon_cooler", Name = "Ice Cooler", Cost = 220, Income = 8 },
			{ Id = "lemon_stand2", Name = "Second Stand", Cost = 550, Income = 15 },
		},
	},
	{
		Id = "clothing",
		Name = "Clothing Brand",
		Color = Color3.fromRGB(255, 120, 190),
		Items = {
			{ Id = "cloth_rack", Name = "Thrift Rack", Cost = 1_500, Income = 30 },
			{ Id = "cloth_sewing", Name = "Sewing Machine", Cost = 4_000, Income = 60 },
			{ Id = "cloth_printer", Name = "T-Shirt Printer", Cost = 10_000, Income = 120 },
			{ Id = "cloth_boutique", Name = "Boutique Store", Cost = 25_000, Income = 250 },
			{ Id = "cloth_line", Name = "Designer Fashion Line", Cost = 60_000, Income = 500 },
		},
	},
	{
		Id = "cars",
		Name = "Car Dealership",
		Color = Color3.fromRGB(90, 160, 255),
		Items = {
			{ Id = "car_lot", Name = "Used Car Lot", Cost = 150_000, Income = 1_000 },
			{ Id = "car_garage", Name = "Repair Garage", Cost = 350_000, Income = 2_000 },
			{ Id = "car_dealer", Name = "New Car Dealership", Cost = 800_000, Income = 4_000 },
			{ Id = "car_showroom", Name = "Sports Car Showroom", Cost = 2_000_000, Income = 8_500 },
			{ Id = "car_luxury", Name = "Luxury Imports", Cost = 5_000_000, Income = 18_000 },
		},
	},
	{
		Id = "dropship",
		Name = "Dropshipping Empire",
		Color = Color3.fromRGB(255, 150, 60),
		Items = {
			{ Id = "drop_store", Name = "Online Store", Cost = 12_000_000, Income = 35_000 },
			{ Id = "drop_ads", Name = "Viral Ad Campaign", Cost = 25_000_000, Income = 65_000 },
			{ Id = "drop_warehouse", Name = "Warehouse", Cost = 50_000_000, Income = 120_000 },
			{ Id = "drop_fleet", Name = "Delivery Van Fleet", Cost = 100_000_000, Income = 220_000 },
			{ Id = "drop_fulfill", Name = "Mega Fulfillment Center", Cost = 200_000_000, Income = 400_000 },
		},
	},
	{
		Id = "wowvidia",
		Name = "WOWVidia GPUs",
		Color = Color3.fromRGB(118, 255, 3),
		Items = {
			{ Id = "gpu_lab", Name = "Garage Chip Lab", Cost = 400_000_000, Income = 750_000 },
			{ Id = "gpu_fab", Name = "Chip Factory", Cost = 700_000_000, Income = 1_300_000 },
			{ Id = "gpu_wowforce", Name = "WOWForce GPU Line", Cost = 1_200_000_000, Income = 2_300_000 },
			{ Id = "gpu_ai", Name = "AI Supercomputer", Cost = 2_000_000_000, Income = 4_000_000 },
			{ Id = "gpu_hq", Name = "WOWVidia Mega HQ", Cost = 3_500_000_000, Income = 7_500_000 },
		},
	},
}

-- Lookup table built automatically: Config.ItemsById["lemon_table"] -> info.
-- You never need to edit this part.
Config.ItemsById = {}
for stageIndex, stage in Config.Stages do
	for itemIndex, item in stage.Items do
		assert(Config.ItemsById[item.Id] == nil, "Duplicate item Id in Config: " .. item.Id)
		Config.ItemsById[item.Id] = {
			Item = item,
			Stage = stage,
			StageIndex = stageIndex,
			ItemIndex = itemIndex,
		}
	end
end

return Config
