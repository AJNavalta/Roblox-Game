--[[
	PlotBuilder.luau
	Builds the lots in the city that players can claim, entirely from code.

	The city has two rows of lots facing a main avenue (see CityBuilder).
	One lot, seen from above, with the avenue at the bottom:

	    [ WOWVidia GPUs       ]   (backyard, farthest from the road)
	    [ Dropshipping Empire ]
	    [ Car Dealership      ]
	    [ Clothing Brand      ]
	    [   house    | garage ]   (HomeBuilder)
	    lemonade   path  stand  driveway
	    buttons    (claim pad)
	  ======== main avenue ========

	Your home is at the front. The Lemonade Stand is ONE stand by the
	driveway that upgrades in place (LemonadeStand.luau); its buttons are on
	the front lawn. The later businesses are in the backyard: each item gets
	a slot with a glowing BUY BUTTON in front of it, and once bought, a
	building block appears in the slot. Upgrading makes the block taller.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local HomeBuilder = require(script.Parent.HomeBuilder)
local LemonadeStand = require(script.Parent.LemonadeStand)

local PlotBuilder = {}

-- Layout numbers (studs). CityBuilder reads these too.
PlotBuilder.LOT_WIDTH = 150
PlotBuilder.STREET_WIDTH = 24 -- side streets between lots
PlotBuilder.AVENUE_WIDTH = 56 -- main road the lots face

local SLOTS_PER_ROW = 5
local SLOT_SPACING = 27
local ROW_SPACING = 26
local ZONE_GAP = 8
local FIRST_ZONE_Z = -100 -- local Z: 0 is the lot's front edge, negative is deeper in (behind the house)
local CLAIM_Z = -10

-- Lemonade buttons sit in a grid on the front lawn, left of the path
local LAWN_COLUMNS = { -64, -48, -32 }
local LAWN_FIRST_ROW_Z = -9
local LAWN_ROW_SPACING = 9

-- Work out where every item's slot goes, once.
-- The Lemonade Stand (stage 1) has no slots: everything goes on one stand.
local slotZ = {} -- [stageIndex][itemIndex] = z
local slotX = {}
local buttonPos = {} -- [stageIndex][itemIndex] = { x, z } of the buy button
local zoneBounds = {} -- [stageIndex] = { Front = z, Back = z }
do
	slotX[1], slotZ[1], buttonPos[1] = {}, {}, {}
	for itemIndex = 1, #Config.Stages[1].Items do
		local column = (itemIndex - 1) % #LAWN_COLUMNS + 1
		local row = math.floor((itemIndex - 1) / #LAWN_COLUMNS)
		buttonPos[1][itemIndex] = { LAWN_COLUMNS[column], LAWN_FIRST_ROW_Z - row * LAWN_ROW_SPACING }
	end

	local z = FIRST_ZONE_Z
	for stageIndex = 2, #Config.Stages do
		local stage = Config.Stages[stageIndex]
		slotZ[stageIndex], slotX[stageIndex], buttonPos[stageIndex] = {}, {}, {}
		local rows = math.ceil(#stage.Items / SLOTS_PER_ROW)
		zoneBounds[stageIndex] = { Front = z + 12, Back = z - (rows - 1) * ROW_SPACING - 11 }
		for itemIndex = 1, #stage.Items do
			local row = math.floor((itemIndex - 1) / SLOTS_PER_ROW)
			local column = (itemIndex - 1) % SLOTS_PER_ROW
			local itemsInRow = math.min(SLOTS_PER_ROW, #stage.Items - row * SLOTS_PER_ROW)
			slotX[stageIndex][itemIndex] = (column - (itemsInRow - 1) / 2) * SLOT_SPACING
			slotZ[stageIndex][itemIndex] = z - row * ROW_SPACING
			buttonPos[stageIndex][itemIndex] = { slotX[stageIndex][itemIndex], slotZ[stageIndex][itemIndex] + 7 }
		end
		z -= rows * ROW_SPACING + ZONE_GAP
	end
	PlotBuilder.LOT_DEPTH = -(z + ZONE_GAP) + 14
end

PlotBuilder.LotCount = Config.LotColumns * 2

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Lots"
plotsFolder.Parent = workspace

-- Small helpers -------------------------------------------------------------

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			part[key] = value
		end
	end
	part.Parent = props.Parent -- parent last, it's faster
	return part
end
PlotBuilder.makePart = makePart

-- Floating text above a part. Returns the TextLabel so it can be updated.
local function makeLabel(adornee: BasePart, text: string, heightAbove: number, color: Color3?, widthStuds: number?, heightStuds: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(widthStuds or 10, 0, heightStuds or 3, 0)
	gui.StudsOffset = Vector3.new(0, heightAbove, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui

	gui.Parent = adornee
	return label
end
PlotBuilder.makeLabel = makeLabel

-- Public API ----------------------------------------------------------------

-- Where lot number `index` sits. Lots 1..LotColumns are north of the avenue,
-- the rest are south. Each lot's front edge touches the avenue, and its
-- local -Z points away from the road.
function PlotBuilder.getOrigin(index: number): CFrame
	local columns = Config.LotColumns
	local column = (index - 1) % columns
	local north = index <= columns
	local x = (column - (columns - 1) / 2) * (PlotBuilder.LOT_WIDTH + PlotBuilder.STREET_WIDTH)
	local side = if north then 1 else -1
	local position = Vector3.new(x, 0, side * PlotBuilder.AVENUE_WIDTH / 2)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, side))
end

-- Builds an empty, unclaimed lot. Returns a table describing it.
function PlotBuilder.build(index: number)
	local origin = PlotBuilder.getOrigin(index)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Lot" .. index

	local plot = {
		Index = index,
		Origin = origin,
		Model = model,
		Owner = nil :: Player?,
		SpawnCFrame = at(HomeBuilder.DOOR_X, 4, -24), -- on the front path
		Levels = {}, -- [itemId] = level, for what's shown on this lot
		Buttons = {}, -- [itemId] = { Part = BasePart, Label = TextLabel }
		StageLabels = {}, -- [stageIndex] = TextLabel
		Visuals = Instance.new("Folder"),
		ButtonsFolder = Instance.new("Folder"),
	}
	plot.Visuals.Name = "Buildings"
	plot.Visuals.Parent = model
	plot.ButtonsFolder.Name = "Buttons"
	plot.ButtonsFolder.Parent = model

	local depth = PlotBuilder.LOT_DEPTH
	makePart({
		Name = "Ground",
		Size = Vector3.new(PlotBuilder.LOT_WIDTH, 1, depth),
		CFrame = at(0, 0.5, -depth / 2),
		Color = Color3.fromRGB(70, 160, 80),
		Material = Enum.Material.Grass,
		Parent = model,
	})

	-- Low fence on three sides, open towards the avenue
	local fenceColor = Color3.fromRGB(235, 235, 235)
	for _, sideX in { -1, 1 } do
		makePart({
			Name = "Fence",
			Size = Vector3.new(1, 3, depth),
			CFrame = at(sideX * (PlotBuilder.LOT_WIDTH / 2 - 0.5), 2.5, -depth / 2),
			Color = fenceColor,
			Parent = model,
		})
	end
	makePart({
		Name = "Fence",
		Size = Vector3.new(PlotBuilder.LOT_WIDTH, 3, 1),
		CFrame = at(0, 2.5, -depth + 0.5),
		Color = fenceColor,
		Parent = model,
	})

	-- The house, driveway, garage, and the laptop workstation inside
	local home = HomeBuilder.build(model, at)
	plot.Laptop = home.Laptop
	plot.CarSpawn = home.CarSpawn

	-- Claim pad: step on it to make this lot yours
	local claimPad = makePart({
		Name = "ClaimPad",
		Size = Vector3.new(10, 0.6, 10),
		CFrame = at(HomeBuilder.DOOR_X, 1.3, CLAIM_Z),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	plot.ClaimPad = claimPad
	plot.ClaimLabel = makeLabel(claimPad, "", 7, nil, 18, 4)

	-- Cash collector
	local collector = makePart({
		Name = "Collector",
		Size = Vector3.new(8, 1, 8),
		CFrame = at(8, 1.5, CLAIM_Z),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	plot.Collector = collector
	plot.CollectorLabel = makeLabel(collector, "", 5, Color3.fromRGB(140, 255, 140), 12)

	-- Lemonade: a sign post beside its buttons on the front lawn
	local lemonade = Config.Stages[1]
	local lemonadeSign = makePart({
		Name = lemonade.Id .. "_Sign",
		Size = Vector3.new(1, 6, 1),
		CFrame = at(-PlotBuilder.LOT_WIDTH / 2 + 3, 4, -20),
		Color = lemonade.Color,
		Parent = model,
	})
	plot.StageLabels[1] = makeLabel(lemonadeSign, lemonade.Name, 6, lemonade.Color, 16, 4.5)

	-- The other businesses: one coloured zone each in the backyard, with a sign
	for stageIndex = 2, #Config.Stages do
		local stage = Config.Stages[stageIndex]
		local bounds = zoneBounds[stageIndex]
		local zoneDepth = bounds.Front - bounds.Back
		makePart({
			Name = stage.Id .. "_Zone",
			Size = Vector3.new(PlotBuilder.LOT_WIDTH - 12, 0.2, zoneDepth),
			CFrame = at(0, 1.1, (bounds.Front + bounds.Back) / 2),
			Color = stage.Color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.55),
			CanCollide = false,
			Parent = model,
		})

		local signPost = makePart({
			Name = stage.Id .. "_Sign",
			Size = Vector3.new(1, 8, 1),
			CFrame = at(-PlotBuilder.LOT_WIDTH / 2 + 4, 5, (bounds.Front + bounds.Back) / 2),
			Color = stage.Color,
			Parent = model,
		})
		plot.StageLabels[stageIndex] = makeLabel(signPost, stage.Name, 7, stage.Color, 18, 5)
	end

	-- A hidden buy button for every item (Tycoon decides when to show them)
	for stageIndex, stage in Config.Stages do
		for itemIndex, item in stage.Items do
			local pos = buttonPos[stageIndex][itemIndex]
			local button = makePart({
				Name = item.Id .. "_Button",
				Size = Vector3.new(8, 1, 5),
				CFrame = at(pos[1], 1.5, pos[2]),
				Material = Enum.Material.Neon,
				Parent = nil,
			})
			local label = makeLabel(button, item.Name, 3.5, Color3.new(1, 1, 1), 11, 3.5)
			plot.Buttons[item.Id] = { Part = button, Label = label }
		end
	end

	PlotBuilder.setOwner(plot, nil)
	model.Parent = plotsFolder
	return plot
end

-- CFrame of the lemonade stand's centre on the ground, facing the street.
function PlotBuilder.getStandCFrame(plot): CFrame
	return LemonadeStand.getCFrame(plot)
end

-- Shows (or replaces) the building for an item at the given level.
-- `info` is an entry from Config.ItemsById.
function PlotBuilder.setItemVisual(plot, info, level: number)
	plot.Levels[info.Item.Id] = if level > 0 then level else nil

	-- Every Lemonade item is part of the one stand, so rebuild the stand
	if info.StageIndex == 1 then
		LemonadeStand.rebuild(plot, plot.Levels)
		return
	end

	local old = plot.Visuals:FindFirstChild(info.Item.Id)
	if old then
		old:Destroy()
	end
	if level <= 0 then
		return
	end

	local item = info.Item
	local stage = info.Stage
	local x = slotX[info.StageIndex][info.ItemIndex]
	local z = slotZ[info.StageIndex][info.ItemIndex]
	-- A plain coloured block that gets taller with each level
	local height = (item.Height or (4 + info.ItemIndex + info.StageIndex * 2)) + (level - 1) * 3
	local labelAnchor = makePart({
		Name = item.Id,
		Size = if item.Boost then Vector3.new(8, height, 8) else Vector3.new(14, height, 10),
		CFrame = plot.Origin * CFrame.new(x, 1 + height / 2, z - 3),
		Color = stage.Color,
		Material = if item.Boost then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Parent = plot.Visuals,
	})

	local title = item.Name
	if (item.MaxLevel or 1) > 1 then
		title ..= " Lv" .. level
	end
	local perks = {}
	if item.Income > 0 then
		table.insert(perks, "+" .. Format.money(item.Income * level) .. "/s")
	end
	if item.Boost then
		table.insert(perks, ("x%g %s income"):format(item.Boost, stage.Name))
	end
	makeLabel(labelAnchor, title .. "\n" .. table.concat(perks, "  "), height / 2 + 2.5, Color3.new(1, 1, 1), 13, 3.5)
end

-- Gives the lot to `player`, or frees it up again when `player` is nil.
function PlotBuilder.setOwner(plot, player: Player?)
	plot.Owner = player
	-- Other code (the phone's car shop and laptop) reads these to find your lot
	local ownerId = if player then player.UserId else 0
	plot.Model:SetAttribute("OwnerUserId", ownerId)
	plot.Laptop:SetAttribute("OwnerUserId", ownerId)
	if player then
		plot.ClaimPad.Color = Color3.fromRGB(245, 245, 245)
		plot.ClaimLabel.Text = player.DisplayName .. "'s Empire"
		plot.ClaimLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
		plot.Model.Name = "Lot" .. plot.Index .. "_" .. player.Name
	else
		plot.ClaimPad.Color = Color3.fromRGB(60, 170, 255)
		plot.ClaimLabel.Text = "FOR SALE\nStep here to claim this lot!"
		plot.ClaimLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
		plot.Model.Name = "Lot" .. plot.Index
		plot.Visuals:ClearAllChildren()
		plot.Levels = {}
		for _, button in plot.Buttons do
			button.Part.Parent = nil
		end
		plot.CollectorLabel.Text = "Cash Collector"
		for stageIndex, stage in Config.Stages do
			plot.StageLabels[stageIndex].Text = stage.Name
		end
	end
end

return PlotBuilder
