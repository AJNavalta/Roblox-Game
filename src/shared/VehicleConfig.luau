--[[
	VehicleConfig.luau
	==================
	Every vehicle in the phone's 🚗 Cars app. Buy it once, keep it forever
	(it's saved), and spawn it on your driveway any time.

	Fields:
	  Id         unique id, used for saving. Don't rename it after people own it.
	  Name       what players see.
	  Price      one-time price.
	  Speed      top speed in studs per second (a running player is about 16).
	  Color      body color.
	  Body       size of the main body block: Vector3.new(width, height, length).
	  Cabin      (optional) size of the roof/cabin block on top.
	  WheelSize  wheel diameter in studs.
	  Bike       (optional) true for two-wheelers: the side wheels are hidden
	             "training wheels" so it can't fall over.
	  Emoji      icon in the phone.
]]

local VehicleConfig = {}

VehicleConfig.Vehicles = {
	{ Id = "bicycle", Name = "Bicycle", Emoji = "🚲", Price = 500, Speed = 30, Color = Color3.fromRGB(220, 50, 50), Body = Vector3.new(1, 1, 5), WheelSize = 2.6, Bike = true },
	{ Id = "scooter", Name = "Moped Scooter", Emoji = "🛵", Price = 4_000, Speed = 42, Color = Color3.fromRGB(80, 200, 230), Body = Vector3.new(1.6, 1.4, 5), WheelSize = 2, Bike = true },
	{ Id = "sedan", Name = "Family Sedan", Emoji = "🚗", Price = 30_000, Speed = 60, Color = Color3.fromRGB(60, 110, 200), Body = Vector3.new(6, 2, 12), Cabin = Vector3.new(5.4, 2, 6), WheelSize = 2.6 },
	{ Id = "pickup", Name = "Pickup Truck", Emoji = "🛻", Price = 90_000, Speed = 58, Color = Color3.fromRGB(200, 120, 40), Body = Vector3.new(6.5, 2.4, 13), Cabin = Vector3.new(6, 2.4, 4.5), WheelSize = 3.2 },
	{ Id = "van", Name = "Delivery Van", Emoji = "🚐", Price = 200_000, Speed = 52, Color = Color3.fromRGB(240, 240, 240), Body = Vector3.new(6.5, 2.4, 13), Cabin = Vector3.new(6.3, 4, 10), WheelSize = 3 },
	{ Id = "sports", Name = "Sports Car", Emoji = "🏎️", Price = 2_500_000, Speed = 95, Color = Color3.fromRGB(240, 40, 40), Body = Vector3.new(6, 1.6, 12), Cabin = Vector3.new(5, 1.4, 4.5), WheelSize = 2.6 },
	{ Id = "limo", Name = "Stretch Limo", Emoji = "🚘", Price = 40_000_000, Speed = 70, Color = Color3.fromRGB(20, 20, 24), Body = Vector3.new(6.5, 2, 20), Cabin = Vector3.new(6, 2, 14), WheelSize = 2.8 },
	{ Id = "hyper", Name = "Gold Hypercar", Emoji = "✨", Price = 750_000_000, Speed = 140, Color = Color3.fromRGB(255, 200, 40), Body = Vector3.new(6.4, 1.4, 12.5), Cabin = Vector3.new(5, 1.3, 4), WheelSize = 2.8 },
}

-- Lookup table built automatically: VehicleConfig.ById["sedan"]
VehicleConfig.ById = {}
for order, vehicle in VehicleConfig.Vehicles do
	assert(VehicleConfig.ById[vehicle.Id] == nil, "Duplicate vehicle Id: " .. vehicle.Id)
	vehicle.Order = order
	VehicleConfig.ById[vehicle.Id] = vehicle
end

return VehicleConfig
