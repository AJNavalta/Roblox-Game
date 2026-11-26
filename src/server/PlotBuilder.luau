--[[
	PlotBuilder.luau
	Builds each player's tycoon plot out of plain Parts, entirely from code,
	so you don't have to build anything in Studio to play.

	Layout of one plot (seen from above, the player spawns at the bottom):

	    [ WOWVidia GPUs       ]   row 5  (farthest from spawn)
	    [ Dropshipping Empire ]   row 4
	    [ Car Dealership      ]   row 3
	    [ Clothing Brand      ]   row 2
	    [ Lemonade Stand      ]   row 1
	      (Collector)  (Spawn)

	Each row has one slot per item. A glowing BUY BUTTON sits in front of
	each slot; once bought, a building block appears in the slot.

	Want fancier buildings? Later you can swap the block in addItemVisual
	for a Model you build in Studio (e.g. stored in ServerStorage).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local PlotBuilder = {}

local PLOT_WIDTH = 150
local FIRST_ROW_Z = 45 -- local Z of stage 1's row (spawn side is +Z)
local ROW_SPACING = 30
local SLOT_SPACING = 25
local SPAWN_Z = 72
local LAST_ROW_Z = FIRST_ROW_Z - (#Config.Stages - 1) * ROW_SPACING
local FLOOR_FRONT = SPAWN_Z + 10
local FLOOR_BACK = LAST_ROW_Z - 20

local plotsFolder = workspace:FindFirstChild("Plots")
if not plotsFolder then
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
end

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

-- Floating text above a part. Returns the TextLabel so it can be updated.
local function makeLabel(adornee: BasePart, text: string, heightAbove: number, color: Color3?, widthStuds: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(widthStuds or 10, 0, 3, 0)
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

local function slotPosition(stageIndex: number, itemIndex: number, itemCount: number)
	local x = (itemIndex - (itemCount + 1) / 2) * SLOT_SPACING
	local z = FIRST_ROW_Z - (stageIndex - 1) * ROW_SPACING
	return x, z
end

-- Public API ----------------------------------------------------------------

-- Where plot number `index` sits in the world. Plots form a ring around the
-- centre of the map, each one facing the middle.
function PlotBuilder.getOrigin(index: number): CFrame
	local angle = (index - 1) / Config.MaxPlots * math.pi * 2
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.PlotRingRadius
	-- lookAt points -Z at the centre, so the spawn (+Z) is on the outside edge.
	return CFrame.lookAt(position, Vector3.zero)
end

-- Builds an empty plot for `player`. Returns a table describing the plot.
function PlotBuilder.build(index: number, player: Player)
	local origin = PlotBuilder.getOrigin(index)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index .. "_" .. player.Name

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local plot = {
		Index = index,
		Origin = origin,
		Model = model,
		SpawnCFrame = at(0, 4, SPAWN_Z),
		Buttons = {}, -- [itemId] = { Part = BasePart, Label = TextLabel }
		StageLabels = {}, -- [stageIndex] = TextLabel
		Visuals = Instance.new("Folder"),
		ButtonsFolder = Instance.new("Folder"),
	}
	plot.Visuals.Name = "Buildings"
	plot.Visuals.Parent = model
	plot.ButtonsFolder.Name = "Buttons"
	plot.ButtonsFolder.Parent = model

	-- Floor
	local floorDepth = FLOOR_FRONT - FLOOR_BACK
	makePart({
		Name = "Floor",
		Size = Vector3.new(PLOT_WIDTH, 1, floorDepth),
		CFrame = at(0, 0.5, (FLOOR_FRONT + FLOOR_BACK) / 2),
		Color = Color3.fromRGB(70, 160, 80),
		Material = Enum.Material.Grass,
		Parent = model,
	})

	-- Spawn pad + owner sign
	local spawnPad = makePart({
		Name = "SpawnPad",
		Size = Vector3.new(12, 0.4, 12),
		CFrame = at(0, 1.2, SPAWN_Z),
		Color = Color3.fromRGB(240, 240, 240),
		CanCollide = false,
		Parent = model,
	})
	makeLabel(spawnPad, player.DisplayName .. "'s Empire", 9, Color3.fromRGB(255, 230, 120), 18)

	-- Cash collector
	local collector = makePart({
		Name = "Collector",
		Size = Vector3.new(10, 1, 10),
		CFrame = at(-30, 1.5, SPAWN_Z - 6),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	plot.Collector = collector
	plot.CollectorLabel = makeLabel(collector, "Cash Collector\n$0", 5, Color3.fromRGB(140, 255, 140), 12)

	-- Stage rows: a strip of floor, a sign, and a (hidden) buy button per item
	for stageIndex, stage in Config.Stages do
		local _, rowZ = slotPosition(stageIndex, 1, #stage.Items)

		makePart({
			Name = stage.Id .. "_Strip",
			Size = Vector3.new(PLOT_WIDTH - 10, 0.2, 22),
			CFrame = at(0, 1.1, rowZ),
			Color = stage.Color:Lerp(Color3.new(0.2, 0.2, 0.2), 0.55),
			CanCollide = false,
			Parent = model,
		})

		local signPost = makePart({
			Name = stage.Id .. "_Sign",
			Size = Vector3.new(1, 8, 1),
			CFrame = at(-PLOT_WIDTH / 2 + 4, 5, rowZ),
			Color = stage.Color,
			Parent = model,
		})
		plot.StageLabels[stageIndex] = makeLabel(signPost, stage.Name, 6, stage.Color, 16)

		for itemIndex, item in stage.Items do
			local x, z = slotPosition(stageIndex, itemIndex, #stage.Items)
			local button = makePart({
				Name = item.Id .. "_Button",
				Size = Vector3.new(7, 1, 5),
				CFrame = at(x, 1.5, z + 6),
				Color = Color3.fromRGB(220, 60, 60),
				Material = Enum.Material.Neon,
				Parent = nil, -- the Tycoon module decides when to show it
			})
			local priceText = item.Cost == 0 and "FREE" or Format.money(item.Cost)
			local label = makeLabel(button, item.Name .. "\n" .. priceText, 3, Color3.new(1, 1, 1), 10)
			plot.Buttons[item.Id] = { Part = button, Label = label }
		end
	end

	model.Parent = plotsFolder
	return plot
end

-- Puts a building block in the slot for a bought item.
-- `info` is an entry from Config.ItemsById.
function PlotBuilder.addItemVisual(plot, info)
	if plot.Visuals:FindFirstChild(info.Item.Id) then
		return
	end

	local stage = info.Stage
	local x, z = slotPosition(info.StageIndex, info.ItemIndex, #stage.Items)
	local height = info.Item.Height or (4 + info.ItemIndex * 2 + info.StageIndex)

	local block = makePart({
		Name = info.Item.Id,
		Size = Vector3.new(14, height, 10),
		CFrame = plot.Origin * CFrame.new(x, 1 + height / 2, z - 3),
		Color = stage.Color,
		Parent = plot.Visuals,
	})
	makeLabel(block, info.Item.Name .. "\n+" .. Format.money(info.Item.Income) .. "/s", height / 2 + 2, Color3.new(1, 1, 1), 12)
end

function PlotBuilder.destroy(plot)
	plot.Model:Destroy()
	for _, button in plot.Buttons do
		button.Part:Destroy() -- hidden buttons aren't inside the model
	end
end

return PlotBuilder
