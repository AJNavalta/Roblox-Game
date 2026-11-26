--[[
	Config.luau
	===========
	ALL the game's numbers live here. Want to rebalance the game, rename a
	business, or add a whole new item? Edit this file only.

	How progression works (it branches, you choose your path):
	  * Each business (stage) unlocks once you own enough items from the
	    business before it (see the stage's `Unlock`). You don't need all of them.
	  * Inside a business, items can need other items first (`Requires`).
	    Several buttons are usually open at once, so you pick what to buy next.
	  * Some items can be upgraded several times (`MaxLevel`).
	  * Items that share a `Choice` name are "pick one": buying one removes
	    the others for good.
	  * `Boost` items multiply the income of their whole business.

	Item fields:
	  Id        unique text id, used for saving. Don't rename it after people
	            have played or they'll lose that item.
	  Name      what players see.
	  Cost      price of level 1. Each extra level costs UpgradeCostMultiplier
	            times more than the one before.
	  Income    dollars per second per level.
	  MaxLevel  (optional, default 1) how many times it can be bought.
	  UpgradeCost (optional) price of level 2. Defaults to Cost x UpgradeCostMultiplier.
	  Requires  (optional) list of item Ids you must own first.
	  Choice    (optional) group name. You can only own one item per group.
	  Boost     (optional) multiplies this business's income, e.g. 1.5 = +50%.
	  Height    (optional) height of its building block, in studs.

	Note: "WOWVidia" is a made-up parody company. Any resemblance to a real
	chip maker is purely for laughs.
]]

local Config = {}

Config.GameName = "Become a Billionaire Tycoon"
Config.CityName = "Billionaire City"

-- Economy -------------------------------------------------------------------
Config.StartingCash = 0 -- the first item is free, so new players can start earning
Config.IncomeInterval = 1 -- seconds between income payouts
Config.BillionaireGoal = 1_000_000_000
Config.UpgradeCostMultiplier = 2.2 -- level 2 costs 2.2x level 1, level 3 costs 2.2x level 2...

-- Saving --------------------------------------------------------------------
-- Changing this name starts everyone fresh (handy while testing a rebalance).
Config.DataStoreName = "BillionaireTycoon_v1"
Config.AutosaveInterval = 60 -- seconds

-- City ----------------------------------------------------------------------
-- The city has two rows of lots facing a main avenue. Set your place's
-- Max Players (Game Settings > Places) to LotColumns * 2.
Config.LotColumns = 3

-- Stages --------------------------------------------------------------------
Config.Stages = {
	{
		Id = "lemonade",
		Name = "Lemonade Stand",
		Color = Color3.fromRGB(255, 221, 87),
		Items = {
			-- Everything here is part of ONE stand on your driveway that grows as you upgrade it.
			{ Id = "lemon_pitcher", Name = "Lemonade Tank", Cost = 0, Income = 1, MaxLevel = 5, UpgradeCost = 15 },
			{ Id = "lemon_table", Name = "Wooden Counter", Cost = 25, Income = 2, Requires = { "lemon_pitcher" } },
			{ Id = "lemon_tree", Name = "Backyard Lemon Tree", Cost = 60, Income = 3, MaxLevel = 3, Requires = { "lemon_pitcher" } },
			{ Id = "lemon_sign", Name = "Better Sign", Cost = 80, Income = 4, MaxLevel = 3, Requires = { "lemon_table" } },
			{ Id = "lemon_cooler", Name = "Ice Cooler", Cost = 220, Income = 8, Requires = { "lemon_table" } },
			{ Id = "lemon_recipe", Name = "Grandma's Secret Recipe", Cost = 400, Income = 0, Boost = 1.5, Requires = { "lemon_tree" } },
			{ Id = "lemon_stand2", Name = "Striped Canopy", Cost = 550, Income = 15, Requires = { "lemon_sign" } },
			-- Pick one: a big boost to everything, or a big flat income
			{ Id = "lemon_pink", Name = "Pink Lemonade Tank", Cost = 700, Income = 0, Boost = 1.75, Choice = "specialty", Requires = { "lemon_recipe" } },
			{ Id = "lemon_slushie", Name = "Slushie Machine", Cost = 700, Income = 35, Choice = "specialty", Requires = { "lemon_cooler" } },
			{ Id = "lemon_bike", Name = "Better Advertising", Cost = 900, Income = 22, MaxLevel = 3, Requires = { "lemon_sign" } },
			{ Id = "lemon_truck", Name = "Party Lights & Speakers", Cost = 2_000, Income = 45, Requires = { "lemon_stand2", "lemon_bike" } },
		},
	},
	{
		Id = "clothing",
		Name = "Clothing Brand",
		Color = Color3.fromRGB(255, 120, 190),
		Unlock = { Stage = "lemonade", ItemsOwned = 6 },
		Items = {
			{ Id = "cloth_rack", Name = "Thrift Rack", Cost = 2_500, Income = 30, MaxLevel = 3 },
			{ Id = "cloth_sewing", Name = "Sewing Machine", Cost = 8_000, Income = 70, Requires = { "cloth_rack" } },
			{ Id = "cloth_printer", Name = "T-Shirt Printer", Cost = 20_000, Income = 150, Requires = { "cloth_rack" } },
			{ Id = "cloth_boutique", Name = "Boutique Store", Cost = 50_000, Income = 320, Requires = { "cloth_sewing" } },
			{ Id = "cloth_line", Name = "Designer Fashion Line", Cost = 110_000, Income = 600, Requires = { "cloth_boutique", "cloth_printer" } },
		},
	},
	{
		Id = "cars",
		Name = "Car Dealership",
		Color = Color3.fromRGB(90, 160, 255),
		Unlock = { Stage = "clothing", ItemsOwned = 4 },
		Items = {
			{ Id = "car_lot", Name = "Used Car Lot", Cost = 150_000, Income = 1_000 },
			{ Id = "car_garage", Name = "Repair Garage", Cost = 350_000, Income = 2_000, Requires = { "car_lot" } },
			{ Id = "car_dealer", Name = "New Car Dealership", Cost = 800_000, Income = 4_000, Requires = { "car_lot" } },
			{ Id = "car_showroom", Name = "Sports Car Showroom", Cost = 2_000_000, Income = 8_500, Requires = { "car_dealer" } },
			{ Id = "car_luxury", Name = "Luxury Imports", Cost = 5_000_000, Income = 18_000, Requires = { "car_showroom", "car_garage" } },
		},
	},
	{
		Id = "dropship",
		Name = "Dropshipping Empire",
		Color = Color3.fromRGB(255, 150, 60),
		Unlock = { Stage = "cars", ItemsOwned = 4 },
		Items = {
			{ Id = "drop_store", Name = "Online Store", Cost = 12_000_000, Income = 35_000 },
			{ Id = "drop_ads", Name = "Viral Ad Campaign", Cost = 25_000_000, Income = 65_000, Requires = { "drop_store" } },
			{ Id = "drop_warehouse", Name = "Warehouse", Cost = 50_000_000, Income = 120_000, Requires = { "drop_store" } },
			{ Id = "drop_fleet", Name = "Delivery Van Fleet", Cost = 100_000_000, Income = 220_000, Requires = { "drop_warehouse" } },
			{ Id = "drop_fulfill", Name = "Mega Fulfillment Center", Cost = 200_000_000, Income = 400_000, Requires = { "drop_fleet", "drop_ads" } },
		},
	},
	{
		Id = "wowvidia",
		Name = "WOWVidia GPUs",
		Color = Color3.fromRGB(118, 255, 3),
		Unlock = { Stage = "dropship", ItemsOwned = 4 },
		Items = {
			{ Id = "gpu_lab", Name = "Garage Chip Lab", Cost = 400_000_000, Income = 750_000 },
			{ Id = "gpu_fab", Name = "Chip Factory", Cost = 700_000_000, Income = 1_300_000, Requires = { "gpu_lab" } },
			{ Id = "gpu_wowforce", Name = "WOWForce GPU Line", Cost = 1_200_000_000, Income = 2_300_000, Requires = { "gpu_fab" } },
			{ Id = "gpu_ai", Name = "AI Supercomputer", Cost = 2_000_000_000, Income = 4_000_000, Requires = { "gpu_fab" } },
			{ Id = "gpu_hq", Name = "WOWVidia Mega HQ", Cost = 3_500_000_000, Income = 7_500_000, Requires = { "gpu_wowforce", "gpu_ai" } },
		},
	},
}

-- Lookup tables built automatically. You never need to edit this part.
--   Config.ItemsById["lemon_table"] -> { Item, Stage, StageIndex, ItemIndex }
--   Config.StageIndexById["clothing"] -> 2
Config.ItemsById = {}
Config.StageIndexById = {}
for stageIndex, stage in Config.Stages do
	Config.StageIndexById[stage.Id] = stageIndex
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

-- Catch typos in Requires / Unlock early, with a clear message.
for _, stage in Config.Stages do
	if stage.Unlock then
		assert(Config.StageIndexById[stage.Unlock.Stage], stage.Id .. " unlocks from unknown stage " .. tostring(stage.Unlock.Stage))
	end
	for _, item in stage.Items do
		for _, requiredId in item.Requires or {} do
			assert(Config.ItemsById[requiredId], item.Id .. " requires unknown item " .. requiredId)
		end
	end
end

return Config
