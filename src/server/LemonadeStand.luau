--[[
	LemonadeStand.luau
	Your ONE lemonade stand, at the end of your driveway. Every Lemonade item
	you buy upgrades this same stand instead of building a new one:

	  Lemonade Tank (Lv1-5)    a folding table with a tank; each level adds a tank
	  Wooden Counter           swaps the folding table for a proper wooden booth
	  Better Sign (Lv1-3)      painted board -> big colourful sign -> neon sign
	  Ice Cooler               a cooler beside the stand
	  Grandma's Secret Recipe  a glowing recipe book on the counter
	  Striped Canopy           a striped roof over the stand
	  Pink Lemonade Tank       a big glowing pink tank (pick-one)
	  Slushie Machine          a slushie machine next to the stand (pick-one)
	  Better Advertising (1-3) street sign -> balloons -> giant lemon balloon
	  Party Lights & Speakers  string lights and speakers
	  Backyard Lemon Tree (1-3) trees in the side yard (not on the stand)

	The whole stand is rebuilt from scratch whenever something changes, so
	each piece below only has to know how to draw itself.

	Stand space: X across, Y up from the ground, +Z towards the street.
]]

local LemonadeStand = {}

-- Where things go, in lot space (see HomeBuilder for the house layout)
LemonadeStand.STAND_X = 25
LemonadeStand.STAND_Z = -10
local TREE_SPOTS = { { -58, -55 }, { -66, -66 }, { -56, -76 } }

-- Spots where customers stand to order, in stand space
LemonadeStand.CUSTOMER_SPOTS = {
	Vector3.new(-3, 0, 5),
	Vector3.new(0, 0, 5),
	Vector3.new(3, 0, 5),
	Vector3.new(-4.5, 0, 8.5),
	Vector3.new(-1.5, 0, 8.5),
	Vector3.new(1.5, 0, 8.5),
	Vector3.new(4.5, 0, 8.5),
}

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
local CARDBOARD = Color3.fromRGB(200, 165, 115)

-- Helpers -------------------------------------------------------------------

local function part(model: Instance, cframe: CFrame, size: Vector3, color: Color3, props: { [string]: any }?)
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

local function cylinder(model, cframe, height, diameter, color, props)
	local p = props or {}
	p.Shape = Enum.PartType.Cylinder
	return part(model, cframe * UPRIGHT, Vector3.new(height, diameter, diameter), color, p)
end

local function ball(model, cframe, diameter, color, props)
	local p = props or {}
	p.Shape = Enum.PartType.Ball
	return part(model, cframe, Vector3.new(diameter, diameter, diameter), color, p)
end

local function glow(target: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Parent = target
end

-- Text painted on the side of a part that faces the street (+Z).
local function paintText(target: BasePart, text: string, textColor: Color3, background: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- in Roblox "Back" is the +Z side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(1, 1, 1)
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	gui.Parent = target
	return label
end

local function dispenser(model, at, x, y, z, color, size: number?)
	local s = size or 1
	cylinder(model, at(x, y + 1.3 * s, z), 2.6 * s, 1.7 * s, color, { Material = Enum.Material.Glass, Transparency = 0.25 })
	cylinder(model, at(x, y + 2.75 * s, z), 0.3, 1.8 * s, WHITE)
	part(model, at(x, y + 0.5, z + 0.95 * s), Vector3.new(0.3, 0.3, 0.4), METAL) -- tap
	ball(model, at(x, y + 1.6 * s, z), 0.7 * s, LEMON) -- floating lemon slice
end

-- Pieces of the stand ---------------------------------------------------------

-- The table or booth at the heart of the stand. Returns the counter's top height.
local function buildBase(model, at, levels)
	if (levels.lemon_table or 0) > 0 then
		-- Wooden Counter: a proper booth
		local counter = part(model, at(0, 1.9, 0), Vector3.new(10, 3.8, 3), WOOD, { Material = Enum.Material.WoodPlanks })
		paintText(counter, "LEMONADE", Color3.fromRGB(200, 60, 40), LEMONADE)
		part(model, at(0, 3.95, 0.1), Vector3.new(10.4, 0.3, 3.4), DARK_WOOD)
		return 4.1
	end

	-- Starter folding table with a cardboard sign taped to the front
	local top = 3
	part(model, at(0, top - 0.2, 0), Vector3.new(9, 0.4, 3), WHITE)
	for _, dx in { -4.1, 4.1 } do
		for _, dz in { -1.1, 1.1 } do
			part(model, at(dx, (top - 0.4) / 2, dz), Vector3.new(0.3, top - 0.4, 0.3), METAL)
		end
	end
	local cardboard = part(model, at(0, 1.9, 1.55) * CFrame.Angles(0, 0, math.rad(-3)), Vector3.new(4, 1.6, 0.1), CARDBOARD)
	paintText(cardboard, "Lemonade 25¢", Color3.fromRGB(60, 60, 200), nil, Enum.Font.PermanentMarker)
	return top
end

-- Corner posts that hold up the sign and canopy
local function buildPosts(model, at)
	for _, dx in { -4.8, 4.8 } do
		part(model, at(dx, 5.5, -1.3), Vector3.new(0.4, 11, 0.4), DARK_WOOD)
	end
end

local function buildSign(model, at, level)
	if level == 1 then
		-- Hand-painted wooden board
		local board = part(model, at(0, 10.2, -1.3), Vector3.new(7, 1.8, 0.3), WOOD, { Material = Enum.Material.WoodPlanks })
		paintText(board, "Lemonade 50¢", WHITE, nil, Enum.Font.PermanentMarker)
	elseif level == 2 then
		-- Big bright sign with lemons on the corners
		local board = part(model, at(0, 10.6, -1.3), Vector3.new(10, 2.8, 0.4), LEMON)
		paintText(board, "🍋 FRESH LEMONADE 🍋", Color3.fromRGB(200, 60, 40), nil, Enum.Font.FredokaOne)
		for _, dx in { -5.2, 5.2 } do
			ball(model, at(dx, 10.6, -1.3), 1.4, LEMON)
		end
	else
		-- Neon sign: dark board, glowing border and lettering
		local board = part(model, at(0, 10.8, -1.3), Vector3.new(11, 3.2, 0.4), Color3.fromRGB(25, 20, 35))
		local label = paintText(board, "LEMONADE", Color3.fromRGB(255, 240, 90), nil, Enum.Font.Bangers)
		label.TextStrokeColor3 = Color3.fromRGB(255, 120, 0)
		label.TextStrokeTransparency = 0
		local neonColor = Color3.fromRGB(255, 80, 200)
		part(model, at(0, 12.45, -1.05), Vector3.new(11.2, 0.25, 0.2), neonColor, { Material = Enum.Material.Neon })
		part(model, at(0, 9.15, -1.05), Vector3.new(11.2, 0.25, 0.2), neonColor, { Material = Enum.Material.Neon })
		for _, dx in { -5.55, 5.55 } do
			part(model, at(dx, 10.8, -1.05), Vector3.new(0.25, 3.5, 0.2), neonColor, { Material = Enum.Material.Neon })
		end
		glow(board, Color3.fromRGB(255, 200, 120), 16)
	end
end

local function buildCanopy(model, at)
	for i = 0, 7 do
		local color = if i % 2 == 0 then LEMON else WHITE
		part(model, at(-4.4 + i * 1.25, 8.4, 0.3) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(1.25, 0.3, 4.4), color)
	end
end

local function buildCooler(model, at)
	part(model, at(-8.5, 1.5, 0.5), Vector3.new(4, 3, 3), Color3.fromRGB(40, 110, 220))
	part(model, at(-8.5, 3.25, 0.5), Vector3.new(4.2, 0.5, 3.2), WHITE)
	part(model, at(-8.5, 3.7, 0.5), Vector3.new(1.6, 0.3, 0.4), WHITE) -- handle
	for i = 1, 3 do
		part(model, at(-10.8 + i * 0.7, 0.3, 2.6), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(200, 235, 255), {
			Material = Enum.Material.Ice,
			Transparency = 0.2,
		})
	end
end

local function buildRecipe(model, at, top)
	local book = part(model, at(3.6, top + 0.3, 0.6) * CFrame.Angles(math.rad(-20), math.rad(15), 0), Vector3.new(1.6, 0.35, 1.2), Color3.fromRGB(170, 40, 40))
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = LEMON
	sparkles.Parent = book
	glow(book, LEMON, 8)
end

local function buildPinkTank(model, at)
	cylinder(model, at(-8.5, 2.6, -3.5), 5, 3, PINK, { Material = Enum.Material.Glass, Transparency = 0.15 })
	cylinder(model, at(-8.5, 5.3, -3.5), 0.4, 3.2, WHITE)
	local core = ball(model, at(-8.5, 2.6, -3.5), 1.4, PINK, { Material = Enum.Material.Neon })
	glow(core, PINK, 12)
end

local function buildSlushie(model, at)
	part(model, at(8.5, 2.5, -0.5), Vector3.new(4, 5, 3), METAL, { Material = Enum.Material.Metal })
	part(model, at(8.5, 0.6, 1.05), Vector3.new(4, 0.4, 0.1), LEMON, { Material = Enum.Material.Neon })
	for i, color in { Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 80, 80) } do
		local x = 8.5 + (if i == 1 then -1 else 1)
		part(model, at(x, 6.3, 0), Vector3.new(1.8, 2.6, 1.8), color, { Material = Enum.Material.Glass, Transparency = 0.2 })
		part(model, at(x, 3.4, 1.2), Vector3.new(0.4, 0.4, 0.5), BLACK) -- tap
	end
end

local function buildAdvertising(model, at, level)
	-- Level 1: a sandwich board out by the sidewalk
	for _, dz in { 0.5, -0.5 } do
		local tilt = if dz > 0 then -12 else 12
		local board = part(model, at(-12, 2.2, 9 + dz) * CFrame.Angles(math.rad(tilt), 0, 0), Vector3.new(3.5, 4, 0.2), Color3.fromRGB(40, 45, 40))
		if dz > 0 then
			paintText(board, "ICE COLD\nLEMONADE\n→", WHITE)
		end
	end

	-- Level 2: a bunch of balloons tied to each post
	if level >= 2 then
		local colors = { Color3.fromRGB(255, 80, 80), LEMON, Color3.fromRGB(80, 170, 255), PINK }
		for _, dx in { -4.8, 4.8 } do
			for i, color in colors do
				local offset = Vector3.new((i - 2.5) * 0.9, 3 + (i % 2) * 0.8, 0)
				part(model, at(dx + offset.X / 2, 11 + offset.Y / 2, -1.3), Vector3.new(0.05, offset.Y, 0.05), WHITE, { CanCollide = false })
				ball(model, at(dx + offset.X, 11 + offset.Y, -1.3), 1.4, color, { CanCollide = false })
			end
		end
	end

	-- Level 3: a giant lemon balloon floating over the stand, with a banner
	if level >= 3 then
		part(model, at(0, 16, -2.5), Vector3.new(0.08, 10, 0.08), WHITE, { CanCollide = false }) -- string
		local lemon = ball(model, at(0, 24, -2.5), 7, LEMON, { CanCollide = false })
		for _, dx in { -3.6, 3.6 } do -- pointy lemon ends
			ball(model, at(dx, 24, -2.5), 1.8, Color3.fromRGB(240, 210, 40), { CanCollide = false })
		end
		part(model, at(0, 27.8, -2.5), Vector3.new(0.6, 1.5, 0.6), LEAF, { CanCollide = false })
		glow(lemon, LEMON, 20)
	end
end

local function buildPartyLights(model, at)
	-- A string of coloured bulbs along the front of the canopy
	local colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 255, 120), Color3.fromRGB(80, 170, 255), LEMON, PINK }
	for i = 0, 10 do
		local x = -5 + i
		local sag = math.sin(i / 10 * math.pi) * 0.5
		local bulb = ball(model, at(x, 7.6 - sag, 2.4), 0.45, colors[i % #colors + 1], { Material = Enum.Material.Neon, CanCollide = false })
		if i % 3 == 0 then
			glow(bulb, bulb.Color, 6)
		end
	end
	-- Speakers on either side
	for _, dx in { -6.2, 6.2 } do
		part(model, at(dx, 1.6, -3.2), Vector3.new(1.6, 3.2, 1.4), BLACK)
		for _, dy in { 0.9, 2.3 } do
			cylinder(model, at(dx, dy, -2.45) * CFrame.Angles(math.rad(90), 0, 0), 0.1, 0.9 + dy * 0.15, Color3.fromRGB(70, 70, 75))
		end
	end
end

local function buildTrees(model, lotAt, level)
	local rng = Random.new(7)
	for i = 1, math.min(level, #TREE_SPOTS) do
		local x, z = TREE_SPOTS[i][1], TREE_SPOTS[i][2]
		cylinder(model, lotAt(x, 3.5, z), 5, 1, DARK_WOOD)
		ball(model, lotAt(x, 7.5, z), 6, LEAF, { Material = Enum.Material.Grass })
		for _ = 1, 6 do
			local offset = Vector3.new(rng:NextNumber(-2.2, 2.2), rng:NextNumber(-1.2, 2), rng:NextNumber(-2.2, 2.2))
			ball(model, lotAt(x + offset.X, 7.5 + offset.Y, z + offset.Z), 0.9, LEMON)
		end
	end
end

-- Public API ----------------------------------------------------------------

-- CFrame of the stand's centre on the ground, facing the street.
function LemonadeStand.getCFrame(plot): CFrame
	return plot.Origin * CFrame.new(LemonadeStand.STAND_X, 1, LemonadeStand.STAND_Z)
end

-- Throws away the old stand and builds it again from `levels`
-- ({ [itemId] = level } for the Lemonade items). Returns the new Model.
function LemonadeStand.rebuild(plot, levels)
	local old = plot.Visuals:FindFirstChild("LemonadeStand")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "LemonadeStand"
	local standCFrame = LemonadeStand.getCFrame(plot)
	local function at(x: number, y: number, z: number): CFrame
		return standCFrame * CFrame.new(x, y, z)
	end
	local function lotAt(x: number, y: number, z: number): CFrame
		return plot.Origin * CFrame.new(x, y + 1, z)
	end

	local function level(itemId: string): number
		return levels[itemId] or 0
	end

	if level("lemon_pitcher") > 0 or level("lemon_table") > 0 then
		local top = buildBase(model, at, levels)

		-- Lemonade tanks along the back of the counter, one per level
		local tanks = math.max(level("lemon_pitcher"), 1)
		for i = 1, tanks do
			dispenser(model, at, (i - (tanks + 1) / 2) * 1.85, top, -0.5, LEMONADE)
		end
		-- Cups at the front
		for i = 1, 4 do
			cylinder(model, at(-2.4 + i * 0.65, top + 0.35, 1), 0.7, 0.45, WHITE)
		end

		if level("lemon_sign") > 0 or level("lemon_stand2") > 0 or level("lemon_truck") > 0 then
			buildPosts(model, at)
		end
		if level("lemon_sign") > 0 then
			buildSign(model, at, level("lemon_sign"))
		end
		if level("lemon_stand2") > 0 then
			buildCanopy(model, at)
		end
		if level("lemon_recipe") > 0 then
			buildRecipe(model, at, top)
		end
	end

	if level("lemon_cooler") > 0 then
		buildCooler(model, at)
	end
	if level("lemon_pink") > 0 then
		buildPinkTank(model, at)
	end
	if level("lemon_slushie") > 0 then
		buildSlushie(model, at)
	end
	if level("lemon_bike") > 0 then
		buildAdvertising(model, at, level("lemon_bike"))
	end
	if level("lemon_truck") > 0 then
		buildPartyLights(model, at)
	end
	if level("lemon_tree") > 0 then
		buildTrees(model, lotAt, level("lemon_tree"))
	end

	model.Parent = plot.Visuals
	return model
end

return LemonadeStand
