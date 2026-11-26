--[[
	ItemModels.luau
	Hand-made 3D models for items, built from Parts in code. Any item listed
	here shows this model when bought instead of a plain coloured block.

	Each builder is:  function(model, at, level) -> topHeight
	  model   an empty Model to put Parts into
	  at      function(x, y, z) -> CFrame, in the item's own space:
	            y = 0 is the ground, +Z faces the road (towards customers),
	            the slot is about 14 studs wide and 10 deep.
	  level   the item's level (1 if it can't be upgraded)
	  returns how tall the model is, so the name label floats above it.

	Want to add a model for another item? Add a function to `Builders` with
	the item's Id. Items without one keep using the block.
]]

local ItemModels = {}

-- Colours ------------------------------------------------------------------

local WOOD = Color3.fromRGB(160, 110, 65)
local DARK_WOOD = Color3.fromRGB(105, 70, 40)
local LEMON = Color3.fromRGB(255, 225, 60)
local LEMONADE = Color3.fromRGB(255, 240, 120)
local WHITE = Color3.fromRGB(245, 245, 245)
local PINK = Color3.fromRGB(255, 130, 180)
local LEAF = Color3.fromRGB(60, 150, 60)
local METAL = Color3.fromRGB(170, 175, 180)
local BLACK = Color3.fromRGB(30, 30, 30)

-- Helpers -------------------------------------------------------------------

local function part(model: Model, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	if props then
		for key, value in props do
			p[key] = value
		end
	end
	p.Parent = model
	return p
end

-- Roblox cylinders run along the X axis; this turns one upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- ...and this points one front-to-back (axle along Z).
local FRONT_TO_BACK = CFrame.Angles(0, math.rad(90), 0)

-- An upright cylinder (cups, tanks, tree trunks, poles).
local function cylinder(model, cframe, height, diameter, color, props)
	local p = props or {}
	p.Shape = Enum.PartType.Cylinder
	return part(model, cframe * UPRIGHT, Vector3.new(height, diameter, diameter), color, p)
end

-- A wheel. `axle` is "X" (wheels on the left/right sides) or "Z".
local function wheel(model, cframe, axle: string, diameter: number)
	local rotation = if axle == "Z" then FRONT_TO_BACK else CFrame.new()
	return part(model, cframe * rotation, Vector3.new(0.4, diameter, diameter), BLACK, { Shape = Enum.PartType.Cylinder })
end

local function ball(model, cframe, diameter, color, props)
	local p = props or {}
	p.Shape = Enum.PartType.Ball
	return part(model, cframe, Vector3.new(diameter, diameter, diameter), color, p)
end

-- Text painted on the +Z face of a part.
local function paintText(target: BasePart, text: string, textColor: Color3, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- in Roblox "Back" is the +Z side: the one facing the road
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	gui.Parent = target
end

-- A simple 4-legged table. Returns the height of its top surface.
local function tableAt(model, at, x, z, width, depth, height)
	local top = height
	part(model, at(x, top - 0.2, z), Vector3.new(width, 0.4, depth), WOOD)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			part(model, at(x + dx * (width / 2 - 0.4), (top - 0.4) / 2, z + dz * (depth / 2 - 0.4)), Vector3.new(0.4, top - 0.4, 0.4), DARK_WOOD)
		end
	end
	return top
end

-- A see-through drink dispenser with a white lid and tap.
local function dispenser(model, at, x, y, z, color)
	cylinder(model, at(x, y + 1.3, z), 2.6, 1.8, color, { Material = Enum.Material.Glass, Transparency = 0.25 })
	cylinder(model, at(x, y + 2.75, z), 0.3, 1.9, WHITE)
	part(model, at(x, y + 0.5, z + 1), Vector3.new(0.3, 0.3, 0.4), METAL) -- tap
	ball(model, at(x, y + 1.6, z), 0.7, LEMON) -- floating lemon slice
end

local function cups(model, at, x, y, z, count)
	for i = 1, count do
		cylinder(model, at(x + (i - (count + 1) / 2) * 0.6, y + 0.35, z), 0.7, 0.45, WHITE)
	end
end

-- A wooden booth with a striped canopy and a painted sign.
local function stand(model, at, canopyColor: Color3, signText: string)
	-- counter
	local counter = part(model, at(0, 1.9, 1), Vector3.new(10, 3.8, 3), WOOD)
	paintText(counter, signText, Color3.fromRGB(200, 60, 40), LEMONADE)
	part(model, at(0, 3.9, 1.2), Vector3.new(10.4, 0.3, 3.4), DARK_WOOD) -- countertop
	-- posts
	for _, dx in { -4.8, 4.8 } do
		part(model, at(dx, 4.5, -0.3), Vector3.new(0.4, 9, 0.4), DARK_WOOD)
	end
	-- striped canopy, tilted towards the customers
	for i = 0, 7 do
		local color = if i % 2 == 0 then canopyColor else WHITE
		part(model, at(-4.4 + i * 1.25, 9.2, 0.7) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(1.25, 0.3, 4.4), color)
	end
	-- stuff on the counter
	dispenser(model, at, -2.5, 4.05, 1.2, LEMONADE)
	cups(model, at, 1.5, 4.05, 1.6, 4)
	return 10.5
end

-- A cart with an umbrella on two wheels, facing the road.
local function bikeCart(model, at, x)
	local body = part(model, at(x, 2.4, 0), Vector3.new(4, 2.2, 2.6), LEMON)
	paintText(body, "🍋", Color3.new(1, 1, 1))
	for _, dx in { -2.2, 2.2 } do
		wheel(model, at(x + dx, 1, 0), "X", 2)
	end
	-- the bike part: a front wheel and handlebar
	part(model, at(x, 1.3, 2.4), Vector3.new(0.3, 0.3, 2), METAL)
	wheel(model, at(x, 1, 3.4), "X", 2)
	part(model, at(x, 2.6, 3.4), Vector3.new(1.6, 0.25, 0.25), METAL)
	-- umbrella
	cylinder(model, at(x, 5, 0), 3, 0.2, WHITE)
	cylinder(model, at(x, 6.5, 0), 0.3, 5, PINK)
	return 7
end

-- Builders: one per item Id --------------------------------------------------

local Builders = {}

-- Level 1: a small table with a lemonade dispenser. Each upgrade adds another.
Builders.lemon_pitcher = function(model, at, level)
	local top = tableAt(model, at, 0, 0, 11, 4, 3)
	for i = 1, level do
		dispenser(model, at, (i - (level + 1) / 2) * 2.2, top, -0.6, LEMONADE)
	end
	cups(model, at, 0, top, 1.3, math.min(2 + level, 7))
	return top + 3
end

Builders.lemon_table = function(model, at, _level)
	return stand(model, at, LEMON, "LEMONADE")
end

-- One lemon tree per level
Builders.lemon_tree = function(model, at, level)
	local rng = Random.new(level)
	for i = 1, level do
		local x = (i - (level + 1) / 2) * 4.5
		cylinder(model, at(x, 2.5, -1), 5, 0.9, DARK_WOOD)
		ball(model, at(x, 6, -1), 5, LEAF, { Material = Enum.Material.Grass })
		for _ = 1, 5 do
			local offset = Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-1, 1.6), rng:NextNumber(-1.8, 1.8))
			ball(model, at(x + offset.X, 6 + offset.Y, -1 + offset.Z), 0.8, LEMON)
		end
	end
	return 9
end

-- A chalkboard A-frame sign
Builders.lemon_sign = function(model, at, _level)
	for _, dz in { 0.6, -0.6 } do
		local tilt = if dz > 0 then -15 else 15
		local board = part(model, at(0, 2.4, dz) * CFrame.Angles(math.rad(tilt), 0, 0), Vector3.new(4, 4.5, 0.25), Color3.fromRGB(40, 45, 40))
		if dz > 0 then
			paintText(board, "FRESH\nLEMONADE\n50¢", WHITE)
		end
	end
	return 5
end

Builders.lemon_cooler = function(model, at, _level)
	part(model, at(0, 1.5, 0), Vector3.new(5, 3, 3), Color3.fromRGB(40, 110, 220))
	part(model, at(0, 3.25, 0), Vector3.new(5.2, 0.5, 3.2), WHITE)
	part(model, at(0, 3.7, 0), Vector3.new(2, 0.3, 0.4), WHITE) -- handle
	-- ice cubes spilling out next to it
	for i = 1, 4 do
		part(model, at(3.2 + (i % 2) * 0.8, 0.3, -0.5 + i * 0.4), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(200, 235, 255), { Material = Enum.Material.Ice, Transparency = 0.2 })
	end
	return 4.5
end

-- A glowing book on a pedestal
Builders.lemon_recipe = function(model, at, _level)
	part(model, at(0, 1.5, 0), Vector3.new(2.5, 3, 2.5), Color3.fromRGB(200, 200, 205), { Material = Enum.Material.Marble })
	local book = part(model, at(0, 3.3, 0) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(2, 0.4, 1.5), Color3.fromRGB(170, 40, 40))
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = LEMON
	sparkles.Parent = book
	local light = Instance.new("PointLight")
	light.Color = LEMON
	light.Range = 10
	light.Parent = book
	return 4.5
end

Builders.lemon_stand2 = function(model, at, _level)
	return stand(model, at, PINK, "LEMONADE #2")
end

-- A big glowing pink dispenser on its own table
Builders.lemon_pink = function(model, at, _level)
	local top = tableAt(model, at, 0, 0, 6, 4, 3)
	cylinder(model, at(0, top + 2, 0), 4, 2.8, PINK, { Material = Enum.Material.Glass, Transparency = 0.15 })
	cylinder(model, at(0, top + 4.2, 0), 0.4, 3, WHITE)
	local glow = ball(model, at(0, top + 2, 0), 1.2, PINK, { Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = PINK
	light.Range = 12
	light.Parent = glow
	return top + 5
end

-- A slushie machine with two spinning-colour tanks
Builders.lemon_slushie = function(model, at, _level)
	part(model, at(0, 2.5, 0), Vector3.new(5, 5, 3), METAL, { Material = Enum.Material.Metal })
	part(model, at(0, 0.6, 1.55), Vector3.new(5, 0.4, 0.1), LEMON, { Material = Enum.Material.Neon })
	for i, color in { Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 80, 80) } do
		local x = if i == 1 then -1.2 else 1.2
		part(model, at(x, 6.3, 0.5), Vector3.new(2, 2.6, 2), color, { Material = Enum.Material.Glass, Transparency = 0.2 })
		part(model, at(x, 3.4, 1.7), Vector3.new(0.4, 0.4, 0.5), BLACK) -- tap
	end
	return 8
end

-- One bike cart per level
Builders.lemon_bike = function(model, at, level)
	for i = 1, level do
		bikeCart(model, at, (i - (level + 1) / 2) * 4.6)
	end
	return 7
end

-- A food truck, side-on to the road with its serving window facing customers
Builders.lemon_truck = function(model, at, _level)
	local body = part(model, at(-1.5, 4, 0), Vector3.new(9, 6, 6), LEMON)
	paintText(body, "LEMON TRUCK", Color3.fromRGB(200, 60, 40))
	part(model, at(-1.5, 4.8, 3.05), Vector3.new(5, 2, 0.1), Color3.fromRGB(40, 40, 40)) -- serving window
	part(model, at(-1.5, 3.6, 3.6), Vector3.new(5, 0.3, 1.2), METAL) -- serving ledge
	part(model, at(5, 3, 0), Vector3.new(4, 4, 6), WHITE) -- cab
	part(model, at(6.05, 4, 0), Vector3.new(0.1, 1.8, 5), Color3.fromRGB(150, 200, 230), { Material = Enum.Material.Glass, Transparency = 0.3 })
	for _, x in { -4.5, 4.5 } do
		for _, z in { -3, 3 } do
			wheel(model, at(x, 1, z), "Z", 2)
		end
	end
	ball(model, at(-1.5, 8.2, 0), 2.4, LEMON) -- giant lemon on the roof
	return 9.5
end

-- Public API ----------------------------------------------------------------

function ItemModels.has(itemId: string): boolean
	return Builders[itemId] ~= nil
end

-- Builds the model for an item. `base` is the CFrame of the slot's centre
-- on the ground. Returns the Model and its height.
function ItemModels.build(itemId: string, base: CFrame, level: number): (Model, number)
	local model = Instance.new("Model")
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local height = Builders[itemId](model, at, level)

	-- An invisible box covering the model, used as its centre and label anchor
	local root = part(model, base * CFrame.new(0, height / 2, 0), Vector3.new(12, height, 8), WHITE, {
		Name = "Root",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	model.PrimaryPart = root
	return model, height
end

return ItemModels
