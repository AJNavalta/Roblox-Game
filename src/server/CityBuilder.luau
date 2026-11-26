--[[
	CityBuilder.luau
	Builds "Billionaire City" around the lots: a main avenue with a spawn
	plaza in the middle, side streets between lots, sidewalks, street
	lights and a skyline of background buildings.

	It's all plain Parts made from code. If you'd rather build the city by
	hand in Studio later, you can delete this module's call in Main and build
	your own; just keep the lots where PlotBuilder.getOrigin puts them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlotBuilder = require(script.Parent.PlotBuilder)

local makePart = PlotBuilder.makePart
local makeLabel = PlotBuilder.makeLabel

local CityBuilder = {}

local ROAD_COLOR = Color3.fromRGB(45, 45, 50)
local SIDEWALK_COLOR = Color3.fromRGB(175, 175, 170)
local LINE_COLOR = Color3.fromRGB(255, 210, 60)

local function streetLight(folder: Instance, position: Vector3)
	makePart({
		Name = "LightPole",
		Size = Vector3.new(1, 16, 1),
		Position = position + Vector3.new(0, 8, 0),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	local lamp = makePart({
		Name = "Lamp",
		Size = Vector3.new(3, 1, 3),
		Position = position + Vector3.new(0, 16.5, 0),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = lamp
end

function CityBuilder.build()
	local city = Instance.new("Folder")
	city.Name = "City"

	local lotWidth = PlotBuilder.LOT_WIDTH
	local street = PlotBuilder.STREET_WIDTH
	local avenue = PlotBuilder.AVENUE_WIDTH
	local depth = PlotBuilder.LOT_DEPTH
	local columns = Config.LotColumns

	-- Total width of all lots + the streets between and around them
	local cityHalfWidth = (columns * lotWidth + (columns + 1) * street) / 2
	local cityHalfDepth = avenue / 2 + depth

	-- Main avenue (east-west) with a dashed centre line
	makePart({
		Name = "Avenue",
		Size = Vector3.new(cityHalfWidth * 2, 1, avenue),
		Position = Vector3.new(0, 0.5, 0),
		Color = ROAD_COLOR,
		Material = Enum.Material.Asphalt,
		Parent = city,
	})
	for x = -cityHalfWidth + 10, cityHalfWidth - 10, 20 do
		if math.abs(x) > 34 then -- leave the plaza clear
			makePart({
				Name = "LaneLine",
				Size = Vector3.new(8, 0.1, 1),
				Position = Vector3.new(x, 1.05, 0),
				Color = LINE_COLOR,
				CanCollide = false,
				Parent = city,
			})
		end
	end

	-- Sidewalks along both sides of the avenue, with street lights
	for _, side in { -1, 1 } do
		local z = side * (avenue / 2 - 3)
		makePart({
			Name = "Sidewalk",
			Size = Vector3.new(cityHalfWidth * 2, 1.4, 6),
			Position = Vector3.new(0, 0.7, z),
			Color = SIDEWALK_COLOR,
			Material = Enum.Material.Concrete,
			Parent = city,
		})
		for x = -cityHalfWidth + 12, cityHalfWidth - 12, 48 do
			streetLight(city, Vector3.new(x, 1.4, z))
		end
	end

	-- Side streets (north-south) between and around the lots
	for i = 0, columns do
		local x = -cityHalfWidth + street / 2 + i * (lotWidth + street)
		for _, side in { -1, 1 } do
			makePart({
				Name = "SideStreet",
				Size = Vector3.new(street, 1, depth),
				Position = Vector3.new(x, 0.5, side * (avenue / 2 + depth / 2)),
				Color = ROAD_COLOR,
				Material = Enum.Material.Asphalt,
				Parent = city,
			})
		end
	end

	-- Spawn plaza in the middle of the avenue
	makePart({
		Name = "Plaza",
		Size = Vector3.new(64, 1.2, avenue - 12),
		Position = Vector3.new(0, 0.6, 0),
		Color = Color3.fromRGB(215, 200, 170),
		Material = Enum.Material.Pavement,
		Parent = city,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field bubble
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1.7, 0)
	spawn.Color = Color3.fromRGB(255, 200, 40)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = city
	makeLabel(spawn, Config.CityName, 14, Color3.fromRGB(255, 220, 90), 30, 5)
	makeLabel(spawn, "Find a blue FOR SALE pad to claim your lot", 9, Color3.new(1, 1, 1), 30, 2.5)

	-- Turn off any other spawn (like the Baseplate template's) for this play
	-- session, so everyone starts in the plaza. This doesn't change your place file.
	for _, other in workspace:GetDescendants() do
		if other:IsA("SpawnLocation") and other ~= spawn then
			other.Enabled = false
			other.Transparency = 1
			other.CanCollide = false
			local decal = other:FindFirstChildOfClass("Decal")
			if decal then
				decal.Transparency = 1
			end
		end
	end

	-- Skyline: background towers behind the lots and at both ends of the avenue
	local rng = Random.new(2026) -- fixed seed so the city looks the same every time
	local towerColors = {
		Color3.fromRGB(120, 140, 170),
		Color3.fromRGB(90, 100, 120),
		Color3.fromRGB(160, 170, 185),
		Color3.fromRGB(70, 80, 100),
	}
	local function tower(position: Vector3)
		local width = rng:NextInteger(18, 30)
		local height = rng:NextInteger(40, 140)
		makePart({
			Name = "Tower",
			Size = Vector3.new(width, height, width),
			Position = position + Vector3.new(0, height / 2, 0),
			Color = towerColors[rng:NextInteger(1, #towerColors)],
			Material = Enum.Material.Glass,
			Reflectance = 0.1,
			Parent = city,
		})
	end
	for x = -cityHalfWidth, cityHalfWidth, 40 do
		for _, side in { -1, 1 } do
			tower(Vector3.new(x + rng:NextInteger(-6, 6), 0, side * (cityHalfDepth + 30)))
		end
	end
	for z = -cityHalfDepth, cityHalfDepth, 45 do
		for _, side in { -1, 1 } do
			tower(Vector3.new(side * (cityHalfWidth + 30), 0, z + rng:NextInteger(-6, 6)))
		end
	end

	city.Parent = workspace
	return spawn
end

return CityBuilder
