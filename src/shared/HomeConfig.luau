--[[
	HomeConfig.luau
	The homes you can buy in the 🏠 Homes app on your laptop. Everyone starts
	in the free Garden Shed. Buying a home moves you in straight away, and
	you can move back into any home you already own.

	Fields:
	  Id        saved in your data. Don't rename it after people have played.
	  Name      shown in the app.
	  Price     dollars.
	  Storeys   floors (just for the app's info line; the look is in HomeBuilder).
	  Bedrooms  just for the app's info line.
	  Blurb     the listing description in the app.

	What each home looks like is in src/server/HomeBuilder.luau (HOUSE_SPECS).
	Homes are just for show right now: they don't change your income.
]]

local HomeConfig = {}

HomeConfig.StartingHome = "shed"

HomeConfig.Homes = {
	{
		Id = "shed",
		Name = "Garden Shed",
		Price = 0,
		Storeys = 1,
		Bedrooms = 0,
		Blurb = "A tiny wooden shed with a desk, a laptop and a camp bed. Every billionaire starts somewhere!",
	},
	{
		Id = "cabin",
		Name = "Starter Cabin",
		Price = 2_500,
		Storeys = 1,
		Bedrooms = 1,
		Blurb = "A snug log cabin with a front porch and a stone chimney. Finally, a real roof!",
	},
	{
		Id = "bungalow",
		Name = "Cozy Bungalow",
		Price = 25_000,
		Storeys = 1,
		Bedrooms = 2,
		Blurb = "A bright one-storey bungalow with a covered porch and a carport for your first car.",
	},
	{
		Id = "twostorey",
		Name = "Two-Storey House",
		Price = 250_000,
		Storeys = 2,
		Bedrooms = 3,
		Blurb = "Stairs! A classic two-storey house with a garage and a balcony over the front door.",
	},
	{
		Id = "family",
		Name = "Big Family Home",
		Price = 1_500_000,
		Storeys = 2,
		Bedrooms = 4,
		Blurb = "A roomy brick home with a big porch, a double garage and hedges out front.",
	},
	{
		Id = "villa",
		Name = "Modern Villa",
		Price = 12_000_000,
		Storeys = 2,
		Bedrooms = 5,
		Blurb = "Glass walls, a flat roof and your very own swimming pool. Very fancy.",
	},
	{
		Id = "mansion",
		Name = "Grand Mansion",
		Price = 100_000_000,
		Storeys = 3,
		Bedrooms = 7,
		Blurb = "Three floors, tall white columns, a fountain and lamp-lit gardens.",
	},
	{
		Id = "megamansion",
		Name = "Billionaire Mega Mansion",
		Price = 750_000_000,
		Storeys = 3,
		Bedrooms = 10,
		Blurb = "Gold trim, an infinity pool, palm trees and a helipad on the roof. You've made it.",
	},
}

HomeConfig.HomesById = {}
for index, home in HomeConfig.Homes do
	home.Order = index
	HomeConfig.HomesById[home.Id] = home
end

return HomeConfig
