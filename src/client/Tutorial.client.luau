--[[
	Tutorial.client.luau
	The how-to-play tutorial for new players. Glowing arrows on the ground
	lead you through the first steps, and a card at the top says what to do:

	  1. Claim a lot       (arrows to the nearest blue FOR SALE pad)
	  2. Open your stand   (arrows to the free first lemonade upgrade)
	  3. Collect money     (arrows to your stand once money is waiting)
	  4. Use your laptop   (arrows into your home, to the laptop)

	It shows once per save file. "Skip" ends it straight away. The server
	remembers it (src/server/Tutorial.luau) through the "TutorialDone"
	attribute, which is only set after you've picked a save.
]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local tutorialRequest = ReplicatedStorage:WaitForChild("TutorialRequest") :: RemoteEvent

local FIRST_ITEM_ID = Config.Stages[1].Items[1].Id -- the free first lemonade upgrade
local ARROW_GAP = 5 -- studs between arrows
local MAX_ARROWS = 40
local ARROW_COLOR = Color3.fromRGB(255, 220, 60)

local STEPS = {
	{
		Title = "Claim a lot",
		Text = "Follow the arrows to the nearest blue FOR SALE pad and step on it. That lot is yours!",
		Marker = "Step here!",
	},
	{
		Title = "Open your lemonade stand",
		Text = "Step on the glowing round pad by your stand to buy your first upgrade. It's free!",
		Marker = "Free upgrade!",
	},
	{
		Title = "Collect your money",
		Text = "Your stand earns money every second. When the 💵 shows above it, walk up to the stand (or press E).",
		Marker = "Collect here!",
	},
	{
		Title = "Use your laptop",
		Text = "Head inside your home and use the laptop. It has your bank, stocks, cars and new homes to buy.",
		Marker = "Your laptop",
	},
}

-- Progress ------------------------------------------------------------------------

local collected = false
local laptopUsed = false

-- Collecting makes "Pending" drop from something to nothing
local lastPending = player:GetAttribute("Pending") or 0
player:GetAttributeChangedSignal("Pending"):Connect(function()
	local pending = player:GetAttribute("Pending") or 0
	if lastPending >= 1 and pending < 1 and player:GetAttribute("HasLot") then
		collected = true
	end
	lastPending = pending
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player and prompt.Name == "WorkstationPrompt" then
		laptopUsed = true
	end
end)

local function myLot(): Instance?
	local lots = workspace:FindFirstChild("Lots")
	if not lots then
		return nil
	end
	for _, lot in lots:GetChildren() do
		if lot:GetAttribute("OwnerUserId") == player.UserId then
			return lot
		end
	end
	return nil
end

local function currentStep(): number
	if not player:GetAttribute("HasLot") then
		return 1
	end
	if (player:GetAttribute("Income") or 0) <= 0 then
		return 2
	end
	if not collected then
		return 3
	end
	if not laptopUsed then
		return 4
	end
	return 5 -- finished
end

-- Where the arrows should lead for a step
local function targetFor(step: number, root: BasePart): BasePart?
	if step == 1 then
		local lots = workspace:FindFirstChild("Lots")
		local best, bestDistance = nil, math.huge
		for _, lot in (if lots then lots:GetChildren() else {}) do
			local owner = lot:GetAttribute("OwnerUserId")
			local pad = lot:FindFirstChild("ClaimPad")
			if (owner == nil or owner == 0) and pad and pad:IsA("BasePart") then
				local distance = (pad.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = pad, distance
				end
			end
		end
		return best
	end
	local lot = myLot()
	if not lot then
		return nil
	end
	if step == 2 then
		local button = lot:FindFirstChild(FIRST_ITEM_ID .. "_Button", true)
		return if button and button:IsA("BasePart") then button else nil
	elseif step == 3 then
		local collector = lot:FindFirstChild("Collector")
		return if collector and collector:IsA("BasePart") then collector else nil
	elseif step == 4 then
		for _, laptop in CollectionService:GetTagged("Workstation") do
			if laptop:GetAttribute("OwnerUserId") == player.UserId and laptop:IsDescendantOf(lot) then
				if laptop:IsA("BasePart") then
					return laptop
				end
				return laptop:FindFirstChildWhichIsA("BasePart", true)
			end
		end
	end
	return nil
end

-- The step card at the top of the screen ---------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 84)
card.Size = UDim2.new(0.9, 0, 0, 96)
card.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
card.BackgroundTransparency = 0.1
card.Parent = gui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = ARROW_COLOR
	stroke.Thickness = 2
	stroke.Parent = card
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 96)
	limit.Parent = card
end

local function label(props): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = card
	return text
end

local stepLabel = label({
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -120, 0, 16),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = ARROW_COLOR,
	Text = "",
})
local titleLabel = label({
	Position = UDim2.fromOffset(16, 25),
	Size = UDim2.new(1, -32, 0, 24),
	Font = Enum.Font.FredokaOne,
	TextSize = 22,
	Text = "",
})
local textLabel = label({
	Position = UDim2.fromOffset(16, 51),
	Size = UDim2.new(1, -32, 0, 38),
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(205, 210, 225),
	Text = "",
})

local skipButton = Instance.new("TextButton")
skipButton.AnchorPoint = Vector2.new(1, 0)
skipButton.Position = UDim2.new(1, -10, 0, 8)
skipButton.Size = UDim2.fromOffset(96, 22)
skipButton.BackgroundColor3 = Color3.fromRGB(70, 74, 92)
skipButton.TextColor3 = Color3.new(1, 1, 1)
skipButton.Font = Enum.Font.GothamBold
skipButton.TextSize = 12
skipButton.Text = "Skip tutorial"
skipButton.Parent = card
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = skipButton
end

-- Arrows on the ground --------------------------------------------------------

local arrowFolder = Instance.new("Folder")
arrowFolder.Name = "TutorialArrows"
arrowFolder.Parent = workspace

-- A chevron (>) made of two glowing bars, pointing along its LookVector
local function makeArrow(): Model
	local model = Instance.new("Model")
	model.Name = "Arrow"
	local function bar(x: number, angle: number)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = ARROW_COLOR
		part.Size = Vector3.new(0.5, 0.15, 2)
		part.CFrame = CFrame.new(x, 0, -0.15) * CFrame.Angles(0, angle, 0)
		part.Parent = model
		return part
	end
	model.PrimaryPart = bar(-0.53, math.rad(-45))
	bar(0.53, math.rad(45))
	model:PivotTo(CFrame.new(0, -500, 0))
	model.Parent = arrowFolder
	return model
end

local arrows: { Model } = {}
for i = 1, MAX_ARROWS do
	arrows[i] = makeArrow()
end
local arrowCount = 0

local function hideArrows()
	for _, arrow in arrows do
		arrow:PivotTo(CFrame.new(0, -500, 0))
	end
	arrowCount = 0
end

-- Lays arrows along a path made of points
local function layArrows(points: { Vector3 })
	local placed = 0
	local carry = 3 -- the first arrow goes a few studs ahead of you
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = b - a
		local length = segment.Magnitude
		if length > 0.01 then
			local direction = segment.Unit
			local flat = Vector3.new(direction.X, 0, direction.Z)
			if flat.Magnitude < 0.01 then
				flat = Vector3.new(0, 0, -1)
			end
			local distance = carry
			while distance < length and placed < MAX_ARROWS do
				local position = a + direction * distance
				placed += 1
				arrows[placed]:PivotTo(CFrame.lookAt(position, position + flat.Unit) + Vector3.new(0, 0.2, 0))
				distance += ARROW_GAP
			end
			carry = distance - length
		end
	end
	for i = placed + 1, arrowCount do
		arrows[i]:PivotTo(CFrame.new(0, -500, 0))
	end
	arrowCount = placed
end

-- A bouncing marker over the target
local marker = Instance.new("BillboardGui")
marker.Name = "TutorialMarker"
marker.Size = UDim2.fromOffset(160, 70)
marker.AlwaysOnTop = true
marker.LightInfluence = 0
marker.Enabled = false
marker.Parent = gui
local markerArrow = Instance.new("TextLabel")
markerArrow.Size = UDim2.new(1, 0, 0.55, 0)
markerArrow.Position = UDim2.fromScale(0, 0.45)
markerArrow.BackgroundTransparency = 1
markerArrow.Font = Enum.Font.FredokaOne
markerArrow.TextScaled = true
markerArrow.TextColor3 = ARROW_COLOR
markerArrow.TextStrokeTransparency = 0.2
markerArrow.Text = "⬇"
markerArrow.Parent = marker
local markerText = Instance.new("TextLabel")
markerText.Size = UDim2.new(1, 0, 0.45, 0)
markerText.BackgroundTransparency = 1
markerText.Font = Enum.Font.FredokaOne
markerText.TextScaled = true
markerText.TextColor3 = Color3.new(1, 1, 1)
markerText.TextStrokeTransparency = 0.2
markerText.Text = ""
markerText.Parent = marker

-- Arrows gently pulse forward, like they're flowing toward the target
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local t = os.clock()
	for i = 1, arrowCount do
		local glow = (math.sin(t * 6 - i * 0.7) + 1) / 2
		for _, part in arrows[i]:GetChildren() do
			(part :: BasePart).Transparency = 0.1 + 0.55 * (1 - glow)
		end
	end
	marker.StudsOffset = Vector3.new(0, 5 + math.sin(t * 4) * 0.5, 0)
end)

-- Running it ----------------------------------------------------------------------

local finished = false

local function finish(skipped: boolean)
	if finished then
		return
	end
	finished = true
	hideArrows()
	marker.Enabled = false
	tutorialRequest:FireServer("done")
	if skipped then
		gui.Enabled = false
		return
	end
	stepLabel.Text = "HOW TO PLAY · DONE"
	titleLabel.Text = "🎉 You're all set!"
	textLabel.Text = "Keep upgrading your stand, collect your money, and work your way to a billion dollars."
	skipButton.Visible = false
	task.delay(6, function()
		gui.Enabled = false
	end)
end

skipButton.Activated:Connect(function()
	finish(true)
end)

local function shouldRun(): boolean
	return player:GetAttribute("TutorialDone") == false and not finished
end

local function onTutorialAttribute()
	if player:GetAttribute("TutorialDone") == false then
		-- A fresh save (or switched to one): start over
		finished = false
		collected = false
		laptopUsed = false
		skipButton.Visible = true
		gui.Enabled = true
	elseif not finished then
		gui.Enabled = false
		hideArrows()
	end
end
player:GetAttributeChangedSignal("TutorialDone"):Connect(onTutorialAttribute)
onTutorialAttribute()

-- Every so often: work out the step, find a walking route and lay the arrows
task.spawn(function()
	local lastTarget: BasePart? = nil
	local lastFrom = Vector3.zero
	local lastPathTime = 0
	while true do
		task.wait(0.25)
		if not shouldRun() then
			continue
		end
		local step = currentStep()
		if step > #STEPS then
			finish(false)
			continue
		end

		local info = STEPS[step]
		stepLabel.Text = ("HOW TO PLAY · STEP %d OF %d"):format(step, #STEPS)
		titleLabel.Text = info.Title
		textLabel.Text = info.Text

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local target = root and targetFor(step, root)
		if not root or not target then
			hideArrows()
			marker.Enabled = false
			continue
		end
		marker.Adornee = target
		markerText.Text = info.Marker
		marker.Enabled = true

		-- Close enough: no arrows needed
		local from = root.Position - Vector3.new(0, 2.5, 0) -- your feet
		if (target.Position - root.Position).Magnitude < 8 then
			hideArrows()
			continue
		end

		-- Only re-plan the route when you've moved or the target changed
		local now = os.clock()
		if target == lastTarget and (from - lastFrom).Magnitude < 3 and now - lastPathTime < 3 then
			continue
		end
		lastTarget, lastFrom, lastPathTime = target, from, now

		local points = { from, target.Position }
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(root.Position, target.Position)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, waypoint.Position)
			end
		end
		if shouldRun() then
			layArrows(points)
		end
	end
end)
