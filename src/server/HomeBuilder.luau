--[[
	HomeBuilder.luau
	Builds your home at the front of your lot. Everyone starts in a tiny
	Garden Shed and can buy bigger homes in the 🏠 Homes app on the laptop
	(prices and names are in src/shared/HomeConfig.luau).

	Seen from above (the street is at the bottom):

	   +---------------------------+-----------+
	   |  (stairs) desk+laptop  bed|  garage   |   <- bigger homes
	   |        sofa               |           |
	   +-----------[door]----------+--[door]---+
	              | path |               |driveway|
	              |      | (stand)       |  car   |
	  ================ sidewalk / street ===================

	Every home's front wall is at Z = FRONT_Z and its front door is at
	X = DOOR_X, so the front path and driveway never move.

	Each home is described by a "spec" in HOUSE_SPECS below: how wide and
	deep it is, how many floors, colours, roof type and extras like a porch,
	garage, balcony, pool or helipad. The Garden Shed is built by hand.

	Hooks other code can use (no need to require this module):
	  * Lot Model attribute "OwnerUserId": who owns the lot (0 = nobody).
	  * Model "Laptop", tagged "Workstation", with ProximityPrompt
	    "WorkstationPrompt" and its own "OwnerUserId" attribute. Every home
	    has one. The phone code opens the workstation screen when used.
	  * Part "CarSpawn", tagged "CarSpawn", on the driveway. Its LookVector
	    points down the driveway towards the street.
]]

local CollectionService = game:GetService("CollectionService")

local HomeBuilder = {}

-- Layout (lot space: X across, Z = 0 at the street, negative = deeper).
HomeBuilder.FRONT_Z = -46 -- every home's front wall
HomeBuilder.MAX_BACK_Z = -86 -- homes never go deeper than this
HomeBuilder.DRIVEWAY_X = 45
HomeBuilder.DRIVEWAY_WIDTH = 16
HomeBuilder.DOOR_X = -5
local GROUND_Y = 1 -- top of the lot's grass
local FLOOR_Y = 1.4 -- top of a home's ground floor
local WALL = 1 -- wall thickness

-- Colours used by lots of homes
local WHITE = Color3.fromRGB(245, 245, 245)
local GLASS = Color3.fromRGB(170, 215, 240)
local CONCRETE = Color3.fromRGB(190, 190, 185)
local WOOD = Color3.fromRGB(120, 80, 50)
local LIGHT_WOOD = Color3.fromRGB(170, 120, 75)
local DARK = Color3.fromRGB(40, 40, 45)
local LEAF = Color3.fromRGB(60, 150, 60)
local HEDGE = Color3.fromRGB(45, 120, 50)
local GOLD = Color3.fromRGB(230, 185, 60)
local WATER = Color3.fromRGB(60, 170, 230)

--[[
	What each home looks like. X values are in lot space (the door is at -5,
	the driveway at 37..53). Depth is measured back from FRONT_Z.
]]
local HOUSE_SPECS = {
	cabin = {
		Left = -22, Right = 12, Depth = 24, Storeys = 1, StoreyHeight = 11,
		WallColor = Color3.fromRGB(140, 95, 60), WallMaterial = Enum.Material.WoodPlanks,
		TrimColor = Color3.fromRGB(90, 60, 35),
		Roof = "gable", RoofColor = Color3.fromRGB(60, 95, 60), RoofMaterial = Enum.Material.Slate,
		FloorColor = LIGHT_WOOD,
		Porch = { Width = 14, Depth = 6, Columns = 2, ColumnColor = Color3.fromRGB(90, 60, 35) },
		Chimney = Color3.fromRGB(130, 130, 125),
	},
	bungalow = {
		Left = -30, Right = 22, Depth = 30, Storeys = 1, StoreyHeight = 12,
		WallColor = Color3.fromRGB(150, 190, 220), WallMaterial = Enum.Material.SmoothPlastic,
		TrimColor = WHITE,
		Roof = "gable", RoofColor = Color3.fromRGB(85, 85, 95), RoofMaterial = Enum.Material.Slate,
		FloorColor = LIGHT_WOOD,
		Porch = { Width = 18, Depth = 7, Columns = 3, ColumnColor = WHITE },
		Carport = true,
		Hedges = true,
	},
	twostorey = {
		Left = -38, Right = 30, Depth = 34, Storeys = 2, StoreyHeight = 12,
		WallColor = Color3.fromRGB(235, 220, 190), WallMaterial = Enum.Material.SmoothPlastic,
		TrimColor = WHITE,
		Roof = "gable", RoofColor = Color3.fromRGB(130, 60, 45), RoofMaterial = Enum.Material.Slate,
		FloorColor = LIGHT_WOOD,
		Porch = { Width = 12, Depth = 5, Columns = 2, ColumnColor = WHITE },
		Garage = true,
		Balcony = true,
		Chimney = Color3.fromRGB(150, 70, 60),
	},
	family = {
		Left = -50, Right = 30, Depth = 38, Storeys = 2, StoreyHeight = 12,
		WallColor = Color3.fromRGB(165, 80, 60), WallMaterial = Enum.Material.Brick,
		TrimColor = WHITE,
		Roof = "gable", RoofColor = Color3.fromRGB(55, 55, 65), RoofMaterial = Enum.Material.Slate,
		FloorColor = Color3.fromRGB(150, 100, 60),
		Porch = { Width = 24, Depth = 8, Columns = 4, ColumnColor = WHITE },
		Garage = true,
		Balcony = true,
		Chimney = Color3.fromRGB(120, 60, 50),
		Hedges = true,
		Lamps = true,
	},
	villa = {
		Left = -56, Right = 30, Depth = 40, Storeys = 2, StoreyHeight = 13,
		WallColor = Color3.fromRGB(240, 240, 238), WallMaterial = Enum.Material.SmoothPlastic,
		TrimColor = Color3.fromRGB(140, 95, 60), -- wood accents
		Roof = "flat", RoofColor = Color3.fromRGB(60, 60, 65),
		FloorColor = Color3.fromRGB(220, 215, 205),
		BigWindows = true,
		Garage = true,
		Balcony = true,
		Pool = true,
		Lamps = true,
	},
	mansion = {
		Left = -62, Right = 30, Depth = 40, Storeys = 3, StoreyHeight = 12,
		WallColor = Color3.fromRGB(240, 230, 205), WallMaterial = Enum.Material.Marble,
		TrimColor = WHITE,
		Roof = "gable", RoofColor = Color3.fromRGB(70, 75, 90), RoofMaterial = Enum.Material.Slate,
		FloorColor = Color3.fromRGB(230, 225, 215),
		Porch = { Width = 26, Depth = 9, Columns = 4, ColumnColor = WHITE, Height = 24 },
		Garage = true,
		Balcony = true,
		Chimney = Color3.fromRGB(200, 195, 185),
		Hedges = true,
		Lamps = true,
		Fountain = true,
	},
	megamansion = {
		Left = -66, Right = 30, Depth = 40, Storeys = 3, StoreyHeight = 13,
		WallColor = Color3.fromRGB(250, 250, 248), WallMaterial = Enum.Material.Marble,
		TrimColor = GOLD, TrimMaterial = Enum.Material.Metal,
		Roof = "flat", RoofColor = Color3.fromRGB(45, 45, 50),
		FloorColor = Color3.fromRGB(240, 240, 240),
		BigWindows = true,
		Porch = { Width = 26, Depth = 9, Columns = 4, ColumnColor = GOLD, Height = 26 },
		Garage = true,
		Balcony = true,
		Hedges = true,
		Lamps = true,
		Pool = true,
		Palms = true,
		Helipad = true,
	},
}

-- Basic part maker ------------------------------------------------------------

local function newPart(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
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
	p.Parent = parent
	return p
end

--[[
	A little toolkit bound to one model and the lot's `at(x, y, z)`.
	All positions are lot space, so homes can be described with plain numbers.
]]
local function toolkit(model: Instance, at: (number, number, number) -> CFrame)
	local kit = {}

	-- Box between two corners (x1, z1)-(x2, z2), from height y1 to y2
	function kit.box(x1, z1, x2, z2, y1, y2, color, props)
		local size = Vector3.new(math.abs(x2 - x1), y2 - y1, math.abs(z2 - z1))
		if size.X <= 0.01 or size.Y <= 0.01 or size.Z <= 0.01 then
			return nil
		end
		return newPart(model, at((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), size, color, props)
	end

	-- Upright cylinder centred on (x, z) from height y1 to y2
	function kit.cylinder(x, z, y1, y2, diameter, color, props)
		local p = props or {}
		p.Shape = Enum.PartType.Cylinder
		return newPart(model, at(x, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y2 - y1, diameter, diameter), color, p)
	end

	function kit.ball(x, y, z, diameter, color, props)
		local p = props or {}
		p.Shape = Enum.PartType.Ball
		return newPart(model, at(x, y, z), Vector3.new(diameter, diameter, diameter), color, p)
	end

	function kit.light(target: BasePart, range: number, color: Color3?)
		local light = Instance.new("PointLight")
		light.Range = range
		light.Brightness = 1.2
		light.Color = color or Color3.fromRGB(255, 240, 210)
		light.Parent = target
	end

	--[[
		A wall along X at depth z (it is WALL thick, going deeper from z),
		from x1 to x2 and height yBase to yBase + height, with openings.
		Each opening is { x1, x2, bottom, top, glass? } (heights above yBase).
	]]
	function kit.wallAlongX(z, x1, x2, yBase, height, openings, color, material)
		local props = { Material = material }
		table.sort(openings, function(a, b)
			return a[1] < b[1]
		end)
		local x = x1
		for _, o in openings do
			kit.box(x, z, o[1], z - WALL, yBase, yBase + height, color, table.clone(props))
			kit.box(o[1], z, o[2], z - WALL, yBase, yBase + o[3], color, table.clone(props))
			kit.box(o[1], z, o[2], z - WALL, yBase + o[4], yBase + height, color, table.clone(props))
			if o[5] then
				kit.box(o[1], z - 0.35, o[2], z - 0.65, yBase + o[3], yBase + o[4], GLASS, {
					Material = Enum.Material.Glass,
					Transparency = 0.45,
				})
			end
			x = o[2]
		end
		kit.box(x, z, x2, z - WALL, yBase, yBase + height, color, table.clone(props))
	end

	-- A wall along Z at x (WALL thick, going right from x), from zFront down
	-- to zBack, with glass openings { zFront, zBack, bottom, top }.
	function kit.wallAlongZ(x, zFront, zBack, yBase, height, openings, color, material)
		local props = { Material = material }
		table.sort(openings, function(a, b)
			return a[1] > b[1]
		end)
		local z = zFront
		for _, o in openings do
			kit.box(x, z, x + WALL, o[1], yBase, yBase + height, color, table.clone(props))
			kit.box(x, o[1], x + WALL, o[2], yBase, yBase + o[3], color, table.clone(props))
			kit.box(x, o[1], x + WALL, o[2], yBase + o[4], yBase + height, color, table.clone(props))
			kit.box(x + 0.35, o[1], x + 0.65, o[2], yBase + o[3], yBase + o[4], GLASS, {
				Material = Enum.Material.Glass,
				Transparency = 0.45,
			})
			z = o[2]
		end
		kit.box(x, z, x + WALL, zBack, yBase, yBase + height, color, table.clone(props))
	end

	--[[
		A triangular gable roof over x1..x2, z front..back, starting at height
		y, with its ridge running left-right. Roblox wedges are tall at their
		+Z side and slope down to -Z, so the front half is turned around.
	]]
	function kit.gableRoof(x1, x2, zFront, zBack, y, rise, overhang, color, material, endColor)
		local width = (x2 - x1) + overhang * 2
		local depth = zFront - zBack
		local ridgeZ = (zFront + zBack) / 2
		local half = depth / 2 + overhang
		local cx = (x1 + x2) / 2
		local function wedge(cframe, size, c, m)
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.Size = size
			w.CFrame = cframe
			w.Color = c
			w.Material = m or Enum.Material.SmoothPlastic
			w.TopSurface = Enum.SurfaceType.Smooth
			w.BottomSurface = Enum.SurfaceType.Smooth
			w.Parent = model
			return w
		end
		local flip = CFrame.Angles(0, math.pi, 0)
		-- Roof slopes
		wedge(at(cx, y + rise / 2, ridgeZ + half / 2) * flip, Vector3.new(width, rise, half), color, material)
		wedge(at(cx, y + rise / 2, ridgeZ - half / 2), Vector3.new(width, rise, half), color, material)
		-- Triangle ends filling the gaps under the roof at each side wall
		for _, x in { x1 + WALL / 2, x2 - WALL / 2 } do
			wedge(at(x, y + rise / 2, ridgeZ + depth / 4) * flip, Vector3.new(WALL, rise, depth / 2), endColor)
			wedge(at(x, y + rise / 2, ridgeZ - depth / 4), Vector3.new(WALL, rise, depth / 2), endColor)
		end
	end

	-- The work desk with the LAPTOP (the hook the phone code uses).
	-- Placed against a back wall at (x, z), facing the front (+Z).
	function kit.desk(x, z, floorY)
		local deskTop = floorY + 3.5
		kit.box(x - 4, z + 1.6, x + 4, z - 1.6, deskTop - 0.4, deskTop, WOOD)
		for _, dx in { -3.6, 3.6 } do
			kit.box(x + dx - 0.3, z + 1.3, x + dx + 0.3, z - 1.3, floorY, deskTop - 0.4, DARK)
		end
		-- Chair
		kit.box(x - 1.5, z + 3, x + 1.5, z + 6, floorY + 2, floorY + 2.5, DARK)
		kit.box(x - 1.5, z + 5.7, x + 1.5, z + 6, floorY + 2.5, floorY + 6, DARK)
		kit.box(x - 0.2, z + 4.3, x + 0.2, z + 4.7, floorY, floorY + 2, Color3.fromRGB(120, 120, 125))
		-- Desk lamp
		kit.box(x + 2.8, z - 0.4, x + 3.3, z - 0.9, deskTop, deskTop + 2, DARK)
		local bulb = kit.box(x + 2.5, z - 0.1, x + 3.6, z - 1.2, deskTop + 2, deskTop + 2.5, Color3.fromRGB(255, 240, 200), { Material = Enum.Material.Neon })
		kit.light(bulb, 10)

		local laptop = Instance.new("Model")
		laptop.Name = "Laptop"
		laptop:SetAttribute("OwnerUserId", 0)
		local base = newPart(laptop, at(x, deskTop + 0.1, z + 0.3), Vector3.new(3.2, 0.2, 2.2), Color3.fromRGB(50, 50, 55), { Name = "Base", Material = Enum.Material.Metal })
		newPart(laptop, at(x, deskTop + 0.22, z + 0.5), Vector3.new(2.8, 0.05, 1.2), Color3.fromRGB(25, 25, 28), { Name = "Keyboard", CanCollide = false })
		-- Screen, tilted back a little, glowing on the side facing the chair (+Z)
		local screen = newPart(
			laptop,
			at(x, deskTop + 1.25, z - 0.85) * CFrame.Angles(math.rad(-15), 0, 0),
			Vector3.new(3.2, 2.1, 0.12),
			Color3.fromRGB(50, 50, 55),
			{ Name = "Screen", Material = Enum.Material.Metal }
		)
		local screenGui = Instance.new("SurfaceGui")
		screenGui.Face = Enum.NormalId.Back -- in Roblox "Back" is the +Z side
		screenGui.LightInfluence = 0
		screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		screenGui.PixelsPerStud = 60
		local display = Instance.new("TextLabel")
		display.Size = UDim2.fromScale(1, 1)
		display.BackgroundColor3 = Color3.fromRGB(20, 40, 80)
		display.TextColor3 = Color3.fromRGB(150, 255, 150)
		display.Font = Enum.Font.Code
		display.TextScaled = true
		display.Text = "💻 WORKSTATION\n$ ready"
		display.Parent = screenGui
		screenGui.Parent = screen

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WorkstationPrompt"
		prompt.ActionText = "Use Laptop"
		prompt.ObjectText = "Workstation"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = screen

		laptop.PrimaryPart = base
		CollectionService:AddTag(laptop, "Workstation")
		laptop.Parent = model
		return laptop
	end

	function kit.bed(x1, z1, x2, z2, floorY, blanket: Color3)
		kit.box(x1, z1, x2, z2, floorY, floorY + 1.5, WOOD)
		kit.box(x1 + 0.3, z1 - 0.3, x2 - 0.3, z2 + 0.3, floorY + 1.5, floorY + 2.6, WHITE, { Material = Enum.Material.Fabric })
		local blanketBack = z2 + (z1 - z2) * 0.45
		kit.box(x1 + 0.3, z1 - 0.3, x2 - 0.3, blanketBack, floorY + 2.6, floorY + 2.8, blanket, { Material = Enum.Material.Fabric })
		kit.box(x1 + 1, z2 + 2.2, x2 - 1, z2 + 0.4, floorY + 2.6, floorY + 3.4, WHITE, { Material = Enum.Material.Fabric }) -- pillow
	end

	function kit.sofa(x1, x2, z, floorY, color)
		-- Faces the front (+Z); z is its front edge
		local props = function()
			return { Material = Enum.Material.Fabric }
		end
		kit.box(x1, z - 1, x2, z - 4, floorY, floorY + 2, color, props())
		kit.box(x1, z - 3, x2, z - 4.5, floorY, floorY + 4.5, color, props())
		kit.box(x1, z - 1, x1 + 1.5, z - 4.5, floorY, floorY + 3, color, props())
		kit.box(x2 - 1.5, z - 1, x2, z - 4.5, floorY, floorY + 3, color, props())
	end

	function kit.plant(x, z, floorY)
		kit.box(x - 1, z - 1, x + 1, z + 1, floorY, floorY + 2, Color3.fromRGB(160, 90, 60))
		kit.ball(x, floorY + 3.5, z, 3, LEAF, { Material = Enum.Material.Grass })
	end

	function kit.palm(x, z)
		local trunk = Color3.fromRGB(140, 105, 70)
		for i = 0, 5 do
			kit.cylinder(x + i * 0.3, z, GROUND_Y + i * 2.5, GROUND_Y + (i + 1) * 2.5, 1.4 - i * 0.1, trunk, { Material = Enum.Material.Wood })
		end
		local topX, topY = x + 1.8, GROUND_Y + 15.5
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2
			newPart(
				model,
				at(topX, topY, z) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.6, -3) * CFrame.Angles(math.rad(-20), 0, 0),
				Vector3.new(1.6, 0.3, 6.5),
				LEAF,
				{ Material = Enum.Material.Grass }
			)
		end
		kit.ball(topX, topY, z, 1.6, Color3.fromRGB(110, 80, 40))
	end

	function kit.lampPost(x, z)
		kit.cylinder(x, z, GROUND_Y, GROUND_Y + 8, 0.5, DARK, { Material = Enum.Material.Metal })
		local lamp = kit.ball(x, GROUND_Y + 8.6, z, 1.4, Color3.fromRGB(255, 240, 200), { Material = Enum.Material.Neon })
		kit.light(lamp, 18)
	end

	return kit
end

-- Grounds: the driveway, path and car spawn (never change) -------------------

function HomeBuilder.buildGrounds(lotModel: Model, at: (number, number, number) -> CFrame)
	local grounds = Instance.new("Model")
	grounds.Name = "Grounds"
	local kit = toolkit(grounds, at)

	local driveX, driveHalf = HomeBuilder.DRIVEWAY_X, HomeBuilder.DRIVEWAY_WIDTH / 2
	kit.box(driveX - driveHalf, 0, driveX + driveHalf, HomeBuilder.FRONT_Z, GROUND_Y, GROUND_Y + 0.2, CONCRETE, { Material = Enum.Material.Concrete })
	local doorX = HomeBuilder.DOOR_X
	kit.box(doorX - 3, 0, doorX + 3, HomeBuilder.FRONT_Z + 0.5, GROUND_Y, GROUND_Y + 0.15, Color3.fromRGB(205, 190, 165), { Material = Enum.Material.Pavement })

	-- Where cars bought on the phone appear: on the driveway, facing the street
	local carSpawn = newPart(
		grounds,
		at(driveX, GROUND_Y + 0.2, -24) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(12, 0.05, 20),
		Color3.new(1, 1, 1),
		{ Name = "CarSpawn", Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
	)
	CollectionService:AddTag(carSpawn, "CarSpawn")

	grounds.Parent = lotModel
	return { CarSpawn = carSpawn }
end

-- The Garden Shed (everyone's free starter home) -----------------------------

local function buildShed(kit)
	local left, right = -12, 2
	local front, back = HomeBuilder.FRONT_Z, HomeBuilder.FRONT_Z - 12
	local height = 8.5
	local planks = Color3.fromRGB(150, 110, 70)
	local mat = Enum.Material.WoodPlanks
	local doorX = HomeBuilder.DOOR_X

	kit.box(left, front, right, back, GROUND_Y, FLOOR_Y, LIGHT_WOOD, { Material = mat })
	kit.wallAlongX(front, left, right, FLOOR_Y, height, { { doorX - 2.5, doorX + 2.5, 0, 7 } }, planks, mat)
	kit.wallAlongX(back + WALL, left, right, FLOOR_Y, height, {}, planks, mat)
	kit.wallAlongZ(left, front, back, FLOOR_Y, height, { { front - 4, front - 8, 3, 6 } }, planks, mat)
	kit.wallAlongZ(right - WALL, front, back, FLOOR_Y, height, {}, planks, mat)
	-- Corrugated metal roof
	kit.gableRoof(left, right, front, back, FLOOR_Y + height, 3, 1, Color3.fromRGB(150, 160, 165), Enum.Material.CorrodedMetal, planks)
	-- Door trim and a hand-painted sign
	kit.box(doorX - 3, front + 0.2, doorX + 3, front - 0.2, FLOOR_Y + 7, FLOOR_Y + 7.4, Color3.fromRGB(90, 60, 35))
	local sign = kit.box(-11, front + 0.3, -8.5, front, FLOOR_Y + 4, FLOOR_Y + 6, Color3.fromRGB(230, 210, 160))
	if sign then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.PermanentMarker
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(60, 40, 20)
		text.Text = "HQ"
		text.Parent = gui
		gui.Parent = sign
	end

	-- Inside: desk + laptop on the back wall, a camp bed, a lantern
	local laptop = kit.desk(-7.5, back + 2.6, FLOOR_Y)
	kit.box(-1, front - 1.5, 1, back + 1.5, FLOOR_Y, FLOOR_Y + 1.2, Color3.fromRGB(90, 110, 70), { Material = Enum.Material.Fabric })
	local lantern = kit.box(-11, back + 2, -10.4, back + 1.4, FLOOR_Y + height - 2, FLOOR_Y + height - 1.2, Color3.fromRGB(255, 220, 140), { Material = Enum.Material.Neon })
	kit.light(lantern, 14)
	-- A plant pot by the door
	kit.plant(doorX + 4.5, front + 2, GROUND_Y)
	return laptop
end

-- Everything else is built from a spec -------------------------------------------

local function buildFromSpec(kit, spec)
	local L, R = spec.Left, spec.Right
	local F = HomeBuilder.FRONT_Z
	local B = F - spec.Depth
	local H = spec.StoreyHeight
	local n = spec.Storeys
	local wallColor, wallMat = spec.WallColor, spec.WallMaterial
	local trim, trimMat = spec.TrimColor, spec.TrimMaterial or Enum.Material.SmoothPlastic
	local doorX = HomeBuilder.DOOR_X
	local top = FLOOR_Y + n * H
	local windowWidth = if spec.BigWindows then 11 else 7
	local windowBottom = if spec.BigWindows then 1 else 3.5
	local windowTop = if spec.BigWindows then H - 1.5 else 9

	-- Windows spread along a stretch of wall, skipping `avoid` ranges
	local function windows(a, b, avoid)
		local list = {}
		local count = math.floor((b - a) / (windowWidth + 6))
		if count < 1 then
			return list
		end
		local step = (b - a) / count
		for i = 1, count do
			local centre = a + step * (i - 0.5)
			local x1, x2 = centre - windowWidth / 2, centre + windowWidth / 2
			local clear = true
			for _, range in avoid do
				if x2 > range[1] - 1.5 and x1 < range[2] + 1.5 then
					clear = false
				end
			end
			if clear then
				table.insert(list, { x1, x2, windowBottom, windowTop, true })
			end
		end
		return list
	end

	-- Stairs (homes with more than one floor) run along the left wall.
	-- Flight k goes from floor k-1 up to floor k; flights alternate lanes and
	-- directions so they stack neatly.
	local STEP_RUN = 1.5
	local stairFront = F - 4
	local stairBack = stairFront - STEP_RUN * H
	local function laneX(k)
		local x1 = L + WALL + 0.5 + ((k - 1) % 2) * 4.5
		return x1, x1 + 4
	end

	for storey = 0, n - 1 do
		local yBase = FLOOR_Y + storey * H

		-- Floor (with a hole over the stairs coming up from below)
		if storey == 0 then
			kit.box(L, F, R, B, GROUND_Y, FLOOR_Y, spec.FloorColor, { Material = Enum.Material.WoodPlanks })
		else
			local hx1, hx2 = laneX(storey)
			local floorProps = function()
				return { Material = Enum.Material.WoodPlanks }
			end
			local y1, y2 = yBase - 0.6, yBase
			kit.box(L + WALL, F - WALL, hx1, B + WALL, y1, y2, spec.FloorColor, floorProps())
			kit.box(hx2, F - WALL, R - WALL, B + WALL, y1, y2, spec.FloorColor, floorProps())
			kit.box(hx1, F - WALL, hx2, stairFront, y1, y2, spec.FloorColor, floorProps())
			kit.box(hx1, stairBack, hx2, B + WALL, y1, y2, spec.FloorColor, floorProps())
			-- A trim band between floors on the outside
			kit.box(L - 0.3, F + 0.3, R + 0.3, F - 0.2, yBase - 0.8, yBase, trim, { Material = trimMat })
		end

		-- Front wall: the door (ground floor) or a balcony door (upper floors)
		local frontOpenings
		local avoid
		if storey == 0 then
			frontOpenings = { { doorX - 3, doorX + 3, 0, 9.5 } }
			avoid = { { doorX - 3, doorX + 3 } }
		elseif spec.Balcony and storey == 1 then
			frontOpenings = { { doorX - 3, doorX + 3, 0, 9.5, true } }
			avoid = { { doorX - 3, doorX + 3 } }
		else
			frontOpenings = {}
			avoid = {}
		end
		for _, w in windows(L + 3, R - 3, avoid) do
			table.insert(frontOpenings, w)
		end
		kit.wallAlongX(F, L, R, yBase, H, frontOpenings, wallColor, wallMat)
		kit.wallAlongX(B + WALL, L, R, yBase, H, windows(L + 12, R - 3, {}), wallColor, wallMat)

		-- Side walls, each with a window in the middle
		local sideWindow = { { F - spec.Depth / 2 + 4, F - spec.Depth / 2 - 4, windowBottom, windowTop } }
		kit.wallAlongZ(L, F, B, yBase, H, if n > 1 then {} else sideWindow, wallColor, wallMat)
		kit.wallAlongZ(R - WALL, F, B, yBase, H, if spec.Garage then {} else sideWindow, wallColor, wallMat)

		-- Ceiling light
		local lamp = kit.box((L + R) / 2 - 1, (F + B) / 2 + 1, (L + R) / 2 + 1, (F + B) / 2 - 1, yBase + H - 1.2, yBase + H - 0.8, Color3.fromRGB(255, 245, 220), { Material = Enum.Material.Neon })
		kit.light(lamp, 40)

		-- Stairs up to the next floor
		if storey < n - 1 then
			local k = storey + 1
			local x1, x2 = laneX(k)
			for j = 1, H do
				local zMid = if k % 2 == 1 then stairFront - (j - 0.5) * STEP_RUN else stairBack + (j - 0.5) * STEP_RUN
				kit.box(x1, zMid + STEP_RUN / 2, x2, zMid - STEP_RUN / 2, yBase, yBase + j, LIGHT_WOOD, { Material = Enum.Material.Wood })
			end
		end
	end

	-- Roof
	if spec.Roof == "gable" then
		kit.box(L - 1, F + 1, R + 1, B - 1, top, top + 0.6, trim, { Material = trimMat })
		kit.gableRoof(L, R, F, B, top + 0.6, spec.Depth * 0.3, 2, spec.RoofColor, spec.RoofMaterial, wallColor)
	else
		kit.box(L - 3, F + 3, R + 3, B - 3, top, top + 1.2, spec.RoofColor)
		kit.box(L - 3, F + 3, R + 3, F + 2.4, top - 0.4, top + 1.6, trim, { Material = trimMat }) -- front fascia
		-- Low wall around the roof edge
		local edge = { Material = trimMat }
		kit.box(L - 3, F + 3, R + 3, F + 2.2, top + 1.2, top + 3.5, trim, table.clone(edge))
		kit.box(L - 3, B - 2.2, R + 3, B - 3, top + 1.2, top + 3.5, trim, table.clone(edge))
		kit.box(L - 3, F + 3, L - 2.2, B - 3, top + 1.2, top + 3.5, trim, table.clone(edge))
		kit.box(R + 2.2, F + 3, R + 3, B - 3, top + 1.2, top + 3.5, trim, table.clone(edge))
	end

	if spec.Chimney then
		kit.box(L + 5, B + 9, L + 9, B + 5, top, top + spec.Depth * 0.3 + 4, spec.Chimney, { Material = Enum.Material.Brick })
	end

	-- Porch: a covered deck in front of the door with columns
	if spec.Porch then
		local p = spec.Porch
		local x1, x2 = doorX - p.Width / 2, doorX + p.Width / 2
		local porchTop = FLOOR_Y + (p.Height or 10)
		kit.box(x1, F + p.Depth, x2, F, GROUND_Y, FLOOR_Y, CONCRETE, { Material = Enum.Material.Concrete })
		kit.box(x1 - 0.5, F + p.Depth + 0.5, x2 + 0.5, F, porchTop, porchTop + 0.8, trim, { Material = trimMat })
		for i = 0, p.Columns - 1 do
			local cx = x1 + 0.8 + i * (p.Width - 1.6) / math.max(p.Columns - 1, 1)
			kit.cylinder(cx, F + p.Depth - 0.8, FLOOR_Y, porchTop, if p.Height then 1.6 else 0.9, p.ColumnColor, { Material = trimMat })
		end
	end

	-- Balcony over the front door on the first upper floor. A normal porch
	-- roof doubles as the balcony floor; otherwise it gets its own slab.
	if spec.Balcony and n > 1 then
		local x1, x2, depth, floorTop
		if spec.Porch and not spec.Porch.Height then
			x1, x2 = doorX - spec.Porch.Width / 2, doorX + spec.Porch.Width / 2
			depth = spec.Porch.Depth
			floorTop = FLOOR_Y + 10.8
		else
			x1, x2, depth = doorX - 7, doorX + 7, 5
			floorTop = FLOOR_Y + H
			kit.box(x1, F + depth, x2, F, floorTop - 0.6, floorTop, trim, { Material = trimMat })
		end
		local function railProps()
			return if spec.BigWindows then { Material = Enum.Material.Glass, Transparency = 0.4 } else { Material = trimMat }
		end
		local railColor = if spec.BigWindows then GLASS else trim
		kit.box(x1, F + depth, x2, F + depth - 0.3, floorTop, floorTop + 3, railColor, railProps())
		kit.box(x1, F + depth, x1 + 0.3, F, floorTop, floorTop + 3, railColor, railProps())
		kit.box(x2 - 0.3, F + depth, x2, F, floorTop, floorTop + 3, railColor, railProps())
	end

	-- Garage on the right, over the end of the driveway
	if spec.Garage then
		local gx1, gx2 = R, 60
		local gDepth = math.min(spec.Depth, 32)
		local gB = F - gDepth
		local gH = 12
		local driveX, driveHalf = HomeBuilder.DRIVEWAY_X, HomeBuilder.DRIVEWAY_WIDTH / 2
		kit.box(gx1, F, gx2, gB, GROUND_Y, FLOOR_Y, CONCRETE, { Material = Enum.Material.Concrete })
		kit.wallAlongX(F, gx1, gx2, FLOOR_Y, gH, { { driveX - driveHalf + 1, driveX + driveHalf - 1, 0, 10 } }, wallColor, wallMat)
		kit.box(driveX - driveHalf + 1, F - 0.2, driveX + driveHalf - 1, F - 0.8, FLOOR_Y, FLOOR_Y + 10, WHITE)
		for i = 1, 4 do
			kit.box(driveX - driveHalf + 1.5, F - 0.1, driveX + driveHalf - 1.5, F - 0.25, FLOOR_Y + i * 2, FLOOR_Y + i * 2 + 0.2, Color3.fromRGB(200, 200, 200))
		end
		kit.wallAlongX(gB + WALL, gx1, gx2, FLOOR_Y, gH, {}, wallColor, wallMat)
		kit.wallAlongZ(gx2 - WALL, F, gB, FLOOR_Y, gH, {}, wallColor, wallMat)
		kit.box(gx1, F + 1, gx2 + 1, gB - 1, FLOOR_Y + gH, FLOOR_Y + gH + 1, spec.RoofColor)
		kit.box(gx1, F + 1, gx2 + 1, F + 0.4, FLOOR_Y + gH - 0.4, FLOOR_Y + gH + 1.2, trim, { Material = trimMat })
	end

	-- Carport: a roof on posts over the driveway
	if spec.Carport then
		local x1, x2 = HomeBuilder.DRIVEWAY_X - 8.5, HomeBuilder.DRIVEWAY_X + 8.5
		for _, x in { x1 + 0.5, x2 - 0.5 } do
			for _, z in { F - 0.5, F + 16 } do
				kit.box(x - 0.4, z + 0.4, x + 0.4, z - 0.4, GROUND_Y, FLOOR_Y + 10, trim)
			end
		end
		kit.box(x1, F + 17, x2, F - 1, FLOOR_Y + 10, FLOOR_Y + 10.6, spec.RoofColor)
	end

	-- Garden extras -------------------------------------------------------------
	if spec.Hedges then
		local porchHalf = if spec.Porch then spec.Porch.Width / 2 + 1 else 5
		kit.box(L + 2, F + 3, doorX - porchHalf, F + 1, GROUND_Y, GROUND_Y + 3, HEDGE, { Material = Enum.Material.Grass })
		kit.box(doorX + porchHalf, F + 3, math.min(R - 2, 8), F + 1, GROUND_Y, GROUND_Y + 3, HEDGE, { Material = Enum.Material.Grass })
	end

	if spec.Lamps then
		for _, z in { -18, -32 } do
			kit.lampPost(doorX - 5, z)
			kit.lampPost(doorX + 5, z)
		end
	end

	if spec.Pool then
		local x1, x2, z1, z2 = -68, -40, -16, -38
		kit.box(x1, z1, x2, z2, GROUND_Y, GROUND_Y + 0.3, Color3.fromRGB(230, 225, 210), { Material = Enum.Material.Pavement })
		kit.box(x1 + 1, z1 - 1, x2 - 1, z1 - 2, GROUND_Y, GROUND_Y + 1.6, WHITE)
		kit.box(x1 + 1, z2 + 2, x2 - 1, z2 + 1, GROUND_Y, GROUND_Y + 1.6, WHITE)
		kit.box(x1 + 1, z1 - 1, x1 + 2, z2 + 1, GROUND_Y, GROUND_Y + 1.6, WHITE)
		kit.box(x2 - 2, z1 - 1, x2 - 1, z2 + 1, GROUND_Y, GROUND_Y + 1.6, WHITE)
		kit.box(x1 + 2, z1 - 2, x2 - 2, z2 + 2, GROUND_Y + 0.3, GROUND_Y + 1.3, WATER, {
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
		})
		-- Two sun loungers
		for i, x in { -64, -58 } do
			local color = if i == 1 then Color3.fromRGB(240, 120, 90) else Color3.fromRGB(90, 160, 230)
			kit.box(x, -10, x + 3, -15, GROUND_Y, GROUND_Y + 1.2, color)
		end
		if spec.Palms then
			kit.palm(-70, -12)
			kit.palm(-36, -40)
		end
	end

	if spec.Fountain then
		local fx, fz = -44, -24
		kit.cylinder(fx, fz, GROUND_Y, GROUND_Y + 1.8, 13, Color3.fromRGB(220, 220, 215), { Material = Enum.Material.Marble })
		kit.cylinder(fx, fz, GROUND_Y + 1.8, GROUND_Y + 2, 11.5, WATER, { Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
		kit.cylinder(fx, fz, GROUND_Y, GROUND_Y + 6, 1.4, Color3.fromRGB(220, 220, 215), { Material = Enum.Material.Marble })
		kit.cylinder(fx, fz, GROUND_Y + 6, GROUND_Y + 6.6, 5, Color3.fromRGB(220, 220, 215), { Material = Enum.Material.Marble })
		local spout = kit.ball(fx, GROUND_Y + 7.3, fz, 1.4, WATER, { Material = Enum.Material.Neon })
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = WATER
		sparkle.Parent = spout
	end

	if spec.Helipad then
		local hx, hz = (L + R) / 2 + 10, (F + B) / 2
		local y = top + 1.2
		kit.cylinder(hx, hz, y, y + 0.2, 26, DARK)
		kit.cylinder(hx, hz, y + 0.2, y + 0.25, 24, Color3.fromRGB(255, 200, 40), { Material = Enum.Material.Neon })
		kit.cylinder(hx, hz, y + 0.25, y + 0.3, 23, DARK)
		kit.box(hx - 4, hz + 5, hx - 2.5, hz - 5, y + 0.3, y + 0.35, WHITE)
		kit.box(hx + 2.5, hz + 5, hx + 4, hz - 5, y + 0.3, y + 0.35, WHITE)
		kit.box(hx - 2.5, hz + 0.75, hx + 2.5, hz - 0.75, y + 0.3, y + 0.35, WHITE)
	end

	-- Furniture --------------------------------------------------------------------
	local stairsWidth = if n > 1 then 11 else 0
	-- Desk + laptop on the back wall of the ground floor, right of the stairs
	local laptop = kit.desk(L + stairsWidth + 7, B + WALL + 2.2, FLOOR_Y)
	-- Living room: rug and sofa in the middle, facing the door
	local midX = (L + stairsWidth + R) / 2
	if n > 1 then
		kit.box(midX - 8, F - 6, midX + 8, F - 16, FLOOR_Y, FLOOR_Y + 0.1, Color3.fromRGB(180, 70, 70), { Material = Enum.Material.Fabric, CanCollide = false })
		kit.sofa(midX - 7, midX + 7, F - 16, FLOOR_Y, Color3.fromRGB(70, 100, 160))
	else
		-- Small homes: sofa in the front left corner, out of the way
		kit.sofa(L + 2, L + 13, F - 3, FLOOR_Y, Color3.fromRGB(70, 100, 160))
	end
	kit.plant(R - 3, F - 3, FLOOR_Y)
	-- Bedrooms: upstairs if there is one, otherwise the back right corner
	local bedFloor = if n > 1 then FLOOR_Y + H else FLOOR_Y
	kit.bed(R - 13, B + 13, R - 3, B + WALL + 0.5, bedFloor, Color3.fromRGB(90, 150, 210))
	if n > 2 then
		kit.bed(R - 13, B + 13, R - 3, B + WALL + 0.5, FLOOR_Y + H * 2, Color3.fromRGB(200, 90, 140))
	end
	if n > 1 then
		kit.bed(midX - 5, B + 13, midX + 5, B + WALL + 0.5, bedFloor, Color3.fromRGB(110, 180, 110))
	end

	return laptop
end

-- Public API ------------------------------------------------------------------

--[[
	Builds a home. `homeId` is an Id from HomeConfig. Returns the Model
	(not parented yet, so the caller decides where it goes) and its Laptop.
]]
function HomeBuilder.buildHouse(homeId: string, at: (number, number, number) -> CFrame)
	local model = Instance.new("Model")
	model.Name = "Home"
	model:SetAttribute("HomeId", homeId)
	local kit = toolkit(model, at)

	local laptop
	local spec = HOUSE_SPECS[homeId]
	if spec then
		laptop = buildFromSpec(kit, spec)
	else
		laptop = buildShed(kit)
	end
	return model, laptop
end

return HomeBuilder
