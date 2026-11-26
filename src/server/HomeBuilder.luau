--[[
	HomeBuilder.luau
	Builds the house at the front of every lot: walls with windows and a
	door, a garage, a driveway, a front path, and furniture inside, including
	a desk with a LAPTOP that works as your workstation.

	Seen from above (the street is at the bottom):

	   +--------------------------+-----------+
	   |  desk+laptop      bed    |  garage   |
	   |        sofa              |           |
	   +-----------[door]---------+--[door]---+
	              | path |               |driveway|
	   (buttons)  |      | (stand)       |  car   |
	  ================ sidewalk / street ===================

	Hooks other code can use (no need to require this module):
	  * Lot Model attribute "OwnerUserId": who owns the lot (0 = nobody).
	  * Model "Laptop", tagged "Workstation", with ProximityPrompt
	    "WorkstationPrompt" and its own "OwnerUserId" attribute. The phone
	    code opens the workstation screen when the owner uses it.
	  * Part "CarSpawn", tagged "CarSpawn", on the driveway. Its LookVector
	    points down the driveway towards the street.
]]

local CollectionService = game:GetService("CollectionService")

local HomeBuilder = {}

-- Layout (lot space: X across, Z = 0 at the street, negative = deeper).
-- PlotBuilder reads these so the yard stuff doesn't overlap the house.
HomeBuilder.HOUSE_LEFT = -40
HomeBuilder.HOUSE_RIGHT = 30 -- the garage starts here
HomeBuilder.GARAGE_RIGHT = 60
HomeBuilder.FRONT_Z = -46
HomeBuilder.BACK_Z = -80
HomeBuilder.DRIVEWAY_X = 45
HomeBuilder.DRIVEWAY_WIDTH = 16
HomeBuilder.DOOR_X = -5
HomeBuilder.FLOOR_Y = 1.4 -- top of the house floor
local WALL_HEIGHT = 14
local WALL = 1 -- wall thickness

local WALL_COLOR = Color3.fromRGB(235, 225, 205)
local TRIM_COLOR = Color3.fromRGB(250, 250, 250)
local ROOF_COLOR = Color3.fromRGB(110, 60, 50)
local FLOOR_COLOR = Color3.fromRGB(170, 120, 75)
local GLASS_COLOR = Color3.fromRGB(170, 215, 240)
local CONCRETE = Color3.fromRGB(190, 190, 185)
local WOOD = Color3.fromRGB(120, 80, 50)
local FABRIC_BLUE = Color3.fromRGB(70, 100, 160)

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
	Builds the house into `lotModel`. `at(x, y, z)` turns lot coordinates into
	a world CFrame. Returns { CarSpawn = Part, Laptop = Model }.
]]
function HomeBuilder.build(lotModel: Model, at: (number, number, number) -> CFrame)
	local home = Instance.new("Model")
	home.Name = "Home"

	-- Box from two corners (lot space), between heights y1 and y2
	local function box(x1, z1, x2, z2, y1, y2, color, props)
		local size = Vector3.new(math.abs(x2 - x1), y2 - y1, math.abs(z2 - z1))
		return newPart(home, at((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), size, color, props)
	end

	local floorY = HomeBuilder.FLOOR_Y
	local top = floorY + WALL_HEIGHT
	local left, right, garageRight = HomeBuilder.HOUSE_LEFT, HomeBuilder.HOUSE_RIGHT, HomeBuilder.GARAGE_RIGHT
	local front, back = HomeBuilder.FRONT_Z, HomeBuilder.BACK_Z

	--[[
		A wall running along X at depth z, from x1 to x2, with openings.
		Each opening is { x1, x2, bottom, top, glass? } (heights above the floor).
	]]
	local function wallAlongX(z, x1, x2, openings)
		table.sort(openings, function(a, b)
			return a[1] < b[1]
		end)
		local x = x1
		for _, o in openings do
			if o[1] > x then
				box(x, z, o[1], z - WALL, floorY, top, WALL_COLOR)
			end
			if o[3] > 0 then
				box(o[1], z, o[2], z - WALL, floorY, floorY + o[3], WALL_COLOR)
			end
			box(o[1], z, o[2], z - WALL, floorY + o[4], top, WALL_COLOR)
			if o[5] then
				box(o[1], z - 0.3, o[2], z - 0.7, floorY + o[3], floorY + o[4], GLASS_COLOR, {
					Material = Enum.Material.Glass,
					Transparency = 0.5,
				})
			end
			x = o[2]
		end
		if x < x2 then
			box(x, z, x2, z - WALL, floorY, top, WALL_COLOR)
		end
	end

	-- Same thing for a wall running along Z at position x
	local function wallAlongZ(x, z1, z2, openings)
		-- z1 is the front (bigger), z2 the back (smaller)
		local z = z1
		table.sort(openings, function(a, b)
			return a[1] > b[1]
		end)
		for _, o in openings do
			if o[1] < z then
				box(x, z, x + WALL, o[1], floorY, top, WALL_COLOR)
			end
			box(x, o[1], x + WALL, o[2], floorY, floorY + o[3], WALL_COLOR)
			box(x, o[1], x + WALL, o[2], floorY + o[4], top, WALL_COLOR)
			box(x + 0.3, o[1], x + 0.7, o[2], floorY + o[3], floorY + o[4], GLASS_COLOR, {
				Material = Enum.Material.Glass,
				Transparency = 0.5,
			})
			z = o[2]
		end
		if z > z2 then
			box(x, z, x + WALL, z2, floorY, top, WALL_COLOR)
		end
	end

	-- Floors
	box(left, front, right, back, 1, floorY, FLOOR_COLOR, { Material = Enum.Material.WoodPlanks })
	box(right, front, garageRight, back, 1, floorY, CONCRETE, { Material = Enum.Material.Concrete })

	-- House walls: front has the door and two windows
	local doorX = HomeBuilder.DOOR_X
	wallAlongX(front, left, right, {
		{ doorX - 3, doorX + 3, 0, 9 }, -- front door opening
		{ -32, -20, 4, 10, true },
		{ 8, 20, 4, 10, true },
	})
	wallAlongX(back + WALL, left, right, {
		{ -20, -8, 4, 10, true },
		{ 5, 17, 4, 10, true },
	})
	wallAlongZ(left, front, back, { { -56, -68, 4, 10 } })
	wallAlongZ(right - WALL, front, back, {}) -- between house and garage

	-- Garage walls and its big door (closed, it's decoration)
	local driveX, driveHalf = HomeBuilder.DRIVEWAY_X, HomeBuilder.DRIVEWAY_WIDTH / 2
	wallAlongX(front, right, garageRight, { { driveX - driveHalf + 1, driveX + driveHalf - 1, 0, 11 } })
	box(driveX - driveHalf + 1, front - 0.2, driveX + driveHalf - 1, front - 0.8, floorY, floorY + 11, TRIM_COLOR)
	for i = 1, 4 do -- panel lines on the garage door
		box(driveX - driveHalf + 1.5, front - 0.1, driveX + driveHalf - 1.5, front - 0.25, floorY + i * 2.2, floorY + i * 2.2 + 0.2, Color3.fromRGB(200, 200, 200))
	end
	wallAlongX(back + WALL, right, garageRight, {})
	wallAlongZ(garageRight - WALL, front, back, {})

	-- Roof with an overhang, plus a chimney
	box(left - 2, front + 2, garageRight + 2, back - 2, top, top + 1, ROOF_COLOR)
	box(left + 2, front - 2, right - 2, back + 2, top + 1, top + 3, ROOF_COLOR)
	box(-30, -70, -26, -74, top + 3, top + 8, Color3.fromRGB(150, 70, 60), { Material = Enum.Material.Brick })

	-- Front door frame and step
	box(doorX - 3.5, front + 0.3, doorX + 3.5, front - 0.2, floorY + 9, floorY + 9.6, TRIM_COLOR)
	box(doorX - 4, front + 2.5, doorX + 4, front, 1, floorY, CONCRETE)

	-- Driveway (from the street to the garage) and the front path
	box(driveX - driveHalf, 0, driveX + driveHalf, front, 1, 1.2, CONCRETE, { Material = Enum.Material.Concrete })
	box(doorX - 3, 0, doorX + 3, front + 2.5, 1, 1.15, Color3.fromRGB(205, 190, 165), { Material = Enum.Material.Pavement })

	-- Ceiling light
	local lamp = box(-6, -62, -4, -64, top - 0.4, top, Color3.fromRGB(255, 245, 220), { Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 1.2
	light.Parent = lamp

	-- Furniture ----------------------------------------------------------------

	-- Rug and sofa in the living room
	box(-24, -52, -6, -64, floorY, floorY + 0.1, Color3.fromRGB(180, 70, 70), { Material = Enum.Material.Fabric, CanCollide = false })
	box(-24, -64, -6, -67, floorY, floorY + 2, FABRIC_BLUE, { Material = Enum.Material.Fabric }) -- seat
	box(-24, -66, -6, -67.5, floorY, floorY + 4.5, FABRIC_BLUE, { Material = Enum.Material.Fabric }) -- back
	for _, x in { -24.75, -5.25 } do
		box(x - 0.75, -64, x + 0.75, -67.5, floorY, floorY + 3, FABRIC_BLUE, { Material = Enum.Material.Fabric })
	end

	-- Bed in the corner
	box(12, -66, 22, -78.5, floorY, floorY + 1.5, WOOD)
	box(12.3, -66.3, 21.7, -78.2, floorY + 1.5, floorY + 2.6, TRIM_COLOR, { Material = Enum.Material.Fabric })
	box(12.3, -66.3, 21.7, -72, floorY + 2.6, floorY + 2.8, Color3.fromRGB(90, 150, 210), { Material = Enum.Material.Fabric })
	box(14, -76, 20, -78, floorY + 2.6, floorY + 3.4, TRIM_COLOR, { Material = Enum.Material.Fabric }) -- pillow

	-- A plant by the door
	box(-1, -48, 1, -50, floorY, floorY + 2, Color3.fromRGB(160, 90, 60))
	local leaves = box(-1.5, -47.5, 1.5, -50.5, floorY + 2, floorY + 5, Color3.fromRGB(60, 150, 60), { Material = Enum.Material.Grass })
	leaves.Shape = Enum.PartType.Ball

	-- Work desk against the back wall --------------------------------------------
	local deskX, deskZ = -28, -76
	local deskTop = floorY + 3.5
	box(deskX - 5, deskZ + 1.8, deskX + 5, deskZ - 1.8, deskTop - 0.4, deskTop, WOOD)
	for _, dx in { -4.6, 4.6 } do
		box(deskX + dx - 0.3, deskZ + 1.5, deskX + dx + 0.3, deskZ - 1.5, floorY, deskTop - 0.4, Color3.fromRGB(60, 60, 65))
	end
	-- Chair
	box(deskX - 1.5, deskZ + 3, deskX + 1.5, deskZ + 6, floorY + 2, floorY + 2.5, Color3.fromRGB(40, 40, 45))
	box(deskX - 1.5, deskZ + 5.7, deskX + 1.5, deskZ + 6, floorY + 2.5, floorY + 6, Color3.fromRGB(40, 40, 45))
	box(deskX - 0.2, deskZ + 4.3, deskX + 0.2, deskZ + 4.7, floorY, floorY + 2, Color3.fromRGB(120, 120, 125))
	-- Desk lamp
	box(deskX + 3.5, deskZ - 0.5, deskX + 4.1, deskZ - 1.1, deskTop, deskTop + 2.2, Color3.fromRGB(40, 40, 45))
	local bulb = box(deskX + 3.2, deskZ - 0.2, deskX + 4.4, deskZ - 1.4, deskTop + 2.2, deskTop + 2.8, Color3.fromRGB(255, 240, 200), { Material = Enum.Material.Neon })
	local deskLight = Instance.new("PointLight")
	deskLight.Range = 10
	deskLight.Parent = bulb

	-- The laptop (the workstation the phone code hooks into)
	local laptop = Instance.new("Model")
	laptop.Name = "Laptop"
	laptop:SetAttribute("OwnerUserId", 0)
	local base = newPart(laptop, at(deskX, deskTop + 0.1, deskZ + 0.3), Vector3.new(3.2, 0.2, 2.2), Color3.fromRGB(50, 50, 55), { Name = "Base", Material = Enum.Material.Metal })
	-- keyboard area
	newPart(laptop, at(deskX, deskTop + 0.22, deskZ + 0.5), Vector3.new(2.8, 0.05, 1.2), Color3.fromRGB(25, 25, 28), { Name = "Keyboard", CanCollide = false })
	-- screen, tilted back a little, glowing on the side facing the chair (+Z)
	local screen = newPart(
		laptop,
		at(deskX, deskTop + 1.25, deskZ - 0.85) * CFrame.Angles(math.rad(-15), 0, 0),
		Vector3.new(3.2, 2.1, 0.12),
		Color3.fromRGB(50, 50, 55),
		{ Name = "Screen", Material = Enum.Material.Metal }
	)
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Back -- +Z side, towards the chair
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
	laptop.Parent = home

	-- Where cars bought on the phone appear: on the driveway, facing the street
	local carSpawn = newPart(
		home,
		at(driveX, 1.2, -24) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(12, 0.05, 20),
		Color3.new(1, 1, 1),
		{ Name = "CarSpawn", Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
	)
	CollectionService:AddTag(carSpawn, "CarSpawn")

	home.Parent = lotModel
	return { CarSpawn = carSpawn, Laptop = laptop }
end

return HomeBuilder
