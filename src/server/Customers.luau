--[[
	Customers.luau
	NPC customers who walk onto your lot, line up at your lemonade stand,
	grab a cup, and walk off again. They come in small groups, and the more
	lemonade upgrades you own, the more often they come.

	They use Roblox's standard walking, idle and wave animations.

	They're just for show: they don't change your money (yet!). If you want
	them to tip, Tycoon would be the place to add that.

	Tweak the numbers below to change how busy lots feel.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LemonadeStand = require(script.Parent.LemonadeStand)
local Tycoon = require(script.Parent.Tycoon)

local Customers = {}

local SLOWEST_GAP = 14 -- seconds between groups when you own 1 lemonade item
local FASTEST_GAP = 4 -- ...never more often than this
local MAX_GROUP = 3 -- up to this many customers arrive together
local DRINK_TIME = 4 -- seconds spent at the stand
local WALK_TIMEOUT = 10 -- give up on a walk after this long (if they get stuck)
-- (the most customers at once is the number of spots in LemonadeStand.CUSTOMER_SPOTS)

-- Roblox's own default R15 animations
local ANIMATIONS = {
	Walk = "rbxassetid://507777826",
	Idle = "rbxassetid://507766388",
	Wave = "rbxassetid://507770239",
	Cheer = "rbxassetid://507770677",
}

local PHRASES = {
	"Mmm, lemonade! 🍋",
	"So refreshing!",
	"One more please!",
	"Best lemonade in the city!",
	"Ahh, perfect on a hot day",
	"Sour... but good!",
	"Wow, cheap too!",
	"🍋🍋🍋",
}

local SKIN_TONES = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(90, 56, 37),
}

local SHIRT_COLORS = {
	Color3.fromRGB(220, 60, 60),
	Color3.fromRGB(60, 120, 220),
	Color3.fromRGB(60, 180, 90),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(150, 80, 200),
	Color3.fromRGB(240, 140, 50),
	Color3.fromRGB(240, 240, 240),
}

local PANTS_COLORS = {
	Color3.fromRGB(40, 50, 90),
	Color3.fromRGB(30, 30, 30),
	Color3.fromRGB(110, 90, 70),
	Color3.fromRGB(80, 80, 85),
}

local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "Customers"
folder.Parent = workspace

-- Customers walk through each other instead of getting jammed up
local COLLISION_GROUP = "Customers"
pcall(function()
	if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function makeRig(): Model?
	local description = Instance.new("HumanoidDescription")
	local skin = pick(SKIN_TONES)
	local shirt = pick(SHIRT_COLORS)
	local pants = pick(PANTS_COLORS)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Customers] Couldn't make a customer:", rig)
		return nil
	end

	rig.Name = "Customer"
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = rng:NextNumber(8, 12)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = COLLISION_GROUP
		end
	end
	return rig
end

-- A speech bubble over the customer's head
local function say(rig: Model, text: string)
	local head = rig:FindFirstChild("Head")
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 1.6)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.TextColor3 = Color3.new(0.1, 0.1, 0.1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = head
	return gui
end

-- Loads the walk/idle animations and switches between them as they move.
-- Returns a function that plays a one-off animation like "Wave".
local function animate(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local tracks = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok then
			tracks[name] = track
		end
	end
	if tracks.Walk then
		tracks.Walk.Looped = true
		tracks.Walk.Priority = Enum.AnimationPriority.Movement
	end
	if tracks.Idle then
		tracks.Idle.Looped = true
		tracks.Idle.Priority = Enum.AnimationPriority.Idle
		tracks.Idle:Play()
	end

	humanoid.Running:Connect(function(speed)
		local walk = tracks.Walk
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
			end
			walk:AdjustSpeed(speed / 12)
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)

	return function(name: string)
		local track = tracks[name]
		if track then
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.1)
		end
	end
end

-- Puts a cup of lemonade in the customer's right hand
local function giveCup(rig: Model)
	local hand = rig:FindFirstChild("RightHand")
	if not hand then
		return
	end
	local cup = Instance.new("Part")
	cup.Name = "Cup"
	cup.Shape = Enum.PartType.Cylinder
	cup.Size = Vector3.new(0.8, 0.5, 0.5)
	cup.Color = Color3.fromRGB(255, 240, 120)
	cup.Material = Enum.Material.SmoothPlastic
	cup.CanCollide = false
	cup.Massless = true
	cup.CFrame = hand.CFrame * CFrame.new(0, -0.4, -0.2) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = cup
	weld.Parent = cup
	cup.Parent = rig
end

-- Walks to a point, waiting until they arrive (or give up). Returns false if
-- the customer was removed on the way.
local function walkTo(rig: Model, humanoid: Humanoid, position: Vector3): boolean
	if not rig.Parent then
		return false
	end
	local arrived = false
	local connection = humanoid.MoveToFinished:Connect(function()
		arrived = true
	end)
	humanoid:MoveTo(position)
	local started = os.clock()
	while not arrived and rig.Parent and os.clock() - started < WALK_TIMEOUT do
		task.wait(0.1)
	end
	connection:Disconnect()
	return rig.Parent ~= nil
end

-- One customer's whole visit: walk in, order, drink, walk out.
-- `spotIndex` is which spot in front of the stand they've been given.
local function visit(lot, plot, spotIndex: number)
	local rig = makeRig()
	if not rig then
		lot.Spots[spotIndex] = nil
		return
	end
	lot.Spots[spotIndex] = rig

	local standCFrame = LemonadeStand.getCFrame(plot)
	local spot = standCFrame * CFrame.new(LemonadeStand.CUSTOMER_SPOTS[spotIndex])
	-- A point on the sidewalk in front of the lot, `offset` studs along it
	local function sidewalk(offset: number): Vector3
		return (plot.Origin * CFrame.new(LemonadeStand.STAND_X + offset, 3, 3)).Position
	end

	local start = sidewalk(rng:NextNumber(-25, 25))
	rig:PivotTo(CFrame.lookAt(start, Vector3.new(spot.X, start.Y, spot.Z)))
	rig.Parent = folder
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil) -- the server moves them, so the server owns their physics
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local playAction = animate(humanoid)

	if walkTo(rig, humanoid, spot.Position + Vector3.new(0, 2, 0)) then
		-- Face the stand, order, and enjoy a drink
		if root then
			local standPosition = standCFrame.Position
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(standPosition.X, root.Position.Y, standPosition.Z))
			root.Anchored = true -- stand still while drinking
		end
		task.wait(rng:NextNumber(0.3, 1))
		giveCup(rig)
		playAction(if rng:NextNumber() < 0.5 then "Wave" else "Cheer")
		local bubble = say(rig, pick(PHRASES))
		task.wait(DRINK_TIME)
		if bubble then
			bubble:Destroy()
		end
		if root then
			root.Anchored = false
		end
	end
	lot.Spots[spotIndex] = nil -- free the spot for the next customer

	-- Walk off along the sidewalk, then disappear
	if walkTo(rig, humanoid, sidewalk(rng:NextNumber(-8, 8))) then
		walkTo(rig, humanoid, sidewalk(if rng:NextNumber() < 0.5 then -45 else 45))
	end
	rig:Destroy()
end

local function lemonadeOwnedCount(owned): number
	local count = 0
	for _, item in Config.Stages[1].Items do
		if (owned[item.Id] or 0) > 0 then
			count += 1
		end
	end
	return count
end

local function freeSpots(lot)
	local free = {}
	for index = 1, #LemonadeStand.CUSTOMER_SPOTS do
		if not lot.Spots[index] then
			table.insert(free, index)
		end
	end
	return free
end

function Customers.start()
	local lots = {} -- [plot] = { Spots = { [spotIndex] = rig }, NextVisit = time }

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			local activePlots = {}

			for _, session in Tycoon.getSessions() do
				local plot = session.Plot
				activePlots[plot] = true
				local lot = lots[plot]
				if not lot then
					lot = { Spots = {}, NextVisit = now + rng:NextNumber(2, 4) }
					lots[plot] = lot
				end

				local owned = session.Data.Owned
				local hasStand = (owned.lemon_pitcher or 0) > 0 or (owned.lemon_table or 0) > 0
				local free = freeSpots(lot)
				if hasStand and #free > 0 and now >= lot.NextVisit then
					local count = lemonadeOwnedCount(owned)
					lot.NextVisit = now + math.max(FASTEST_GAP, SLOWEST_GAP - count) + rng:NextNumber(0, 3)

					-- A small group arrives, one after another
					local groupSize = math.min(#free, rng:NextInteger(1, math.min(MAX_GROUP, 1 + math.floor(count / 3))))
					for i = 1, groupSize do
						local spotIndex = table.remove(free, rng:NextInteger(1, #free))
						lot.Spots[spotIndex] = true -- reserved until the customer appears
						task.delay((i - 1) * rng:NextNumber(0.6, 1.4), visit, lot, plot, spotIndex)
					end
				end
			end

			-- Lot owner left: send their customers home
			for plot, lot in lots do
				if not activePlots[plot] then
					for _, rig in lot.Spots do
						if typeof(rig) == "Instance" then
							rig:Destroy()
						end
					end
					lots[plot] = nil
				end
			end
		end
	end)
end

return Customers
