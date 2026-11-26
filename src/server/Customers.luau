--[[
	Customers.luau
	NPC customers who walk onto your lot, line up at your lemonade stand,
	grab a cup, and walk off again. They come in small groups, and the more
	lemonade upgrades you own, the more often they come.

	They use Roblox's standard walking, idle and wave animations, and find
	their way around street lights and trees with PathfindingService.

	Every customer looks a bit different: tall or short, slim or broad, with
	their own skin tone, outfit (short or long sleeves, shorts or trousers),
	hair and sometimes a hat, glasses or a backpack.

	They're just for show: they don't change your money (yet!). If you want
	them to tip, Tycoon would be the place to add that.

	Tweak the numbers below to change how busy lots feel.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
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
	Color3.fromRGB(70, 110, 160),
	Color3.fromRGB(200, 180, 140),
}

local SHOE_COLORS = {
	Color3.fromRGB(30, 30, 30),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(120, 70, 40),
	Color3.fromRGB(200, 50, 50),
}

local HAIR_COLORS = {
	Color3.fromRGB(30, 20, 15),
	Color3.fromRGB(80, 50, 25),
	Color3.fromRGB(150, 100, 50),
	Color3.fromRGB(230, 190, 110),
	Color3.fromRGB(180, 70, 30),
	Color3.fromRGB(200, 200, 200),
}

local HAT_COLORS = {
	Color3.fromRGB(220, 60, 60),
	Color3.fromRGB(40, 60, 120),
	Color3.fromRGB(30, 30, 30),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(60, 160, 90),
	Color3.fromRGB(235, 225, 200),
}

-- Where the street lights stand on the sidewalk (lot z = 3), customers
-- walk on the road side of them instead.
local SIDEWALK_LANE_Z = 5.4

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

-- A small decoration part (hair, hat, glasses...) stuck to `attachTo`.
-- `offset` is from the centre of that part; `size` is in studs.
local function addPiece(rig: Model, attachTo: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: string?)
	local piece = Instance.new("Part")
	piece.Name = "Look"
	piece.Size = size
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.Massless = true
	piece.CollisionGroup = COLLISION_GROUP
	if shape == "sphere" then
		-- A squashed ball: a mesh lets it be any shape, not just round
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = piece
	elseif shape == "cylinder" then
		piece.Shape = Enum.PartType.Cylinder
	end
	piece.CFrame = attachTo.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = rig
	return piece
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder to stand up

-- Hair and hats. The head's front is its -Z side.
local function addHeadwear(rig: Model)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local w, h, d = head.Size.X, head.Size.Y, head.Size.Z
	local hair = pick(HAIR_COLORS)
	local style = rng:NextInteger(1, 4)
	if style == 1 then
		-- Short hair
		addPiece(rig, head, Vector3.new(w * 1.06, h * 0.55, d * 1.08), CFrame.new(0, h * 0.28, d * 0.05), hair, "sphere")
	elseif style == 2 then
		-- Long hair down the back
		addPiece(rig, head, Vector3.new(w * 1.08, h * 0.6, d * 1.1), CFrame.new(0, h * 0.26, d * 0.06), hair, "sphere")
		addPiece(rig, head, Vector3.new(w * 1.0, h * 0.95, d * 0.3), CFrame.new(0, -h * 0.1, d * 0.45), hair)
	elseif style == 3 then
		-- Tall puffy hair
		addPiece(rig, head, Vector3.new(w * 1.15, h * 0.85, d * 1.15), CFrame.new(0, h * 0.42, d * 0.05), hair, "sphere")
	end
	-- style 4: bald, or about to get a hat anyway

	local hat = rng:NextInteger(1, 6)
	local hatColor = pick(HAT_COLORS)
	if hat == 1 then
		-- Baseball cap with a brim at the front
		addPiece(rig, head, Vector3.new(w * 1.1, h * 0.45, d * 1.1), CFrame.new(0, h * 0.35, 0), hatColor, "sphere")
		addPiece(rig, head, Vector3.new(w * 0.85, 0.1, d * 0.5), CFrame.new(0, h * 0.3, -d * 0.62), hatColor)
	elseif hat == 2 then
		-- Woolly beanie
		addPiece(rig, head, Vector3.new(w * 1.12, h * 0.7, d * 1.12), CFrame.new(0, h * 0.36, 0), hatColor, "sphere")
		addPiece(rig, head, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, h * 0.72, 0), Color3.new(1, 1, 1), "sphere")
	elseif hat == 3 then
		-- Big sun hat
		addPiece(rig, head, Vector3.new(0.12, w * 2.1, w * 2.1), CFrame.new(0, h * 0.35, 0) * UPRIGHT, Color3.fromRGB(235, 215, 160), "cylinder")
		addPiece(rig, head, Vector3.new(h * 0.5, w * 1.05, w * 1.05), CFrame.new(0, h * 0.58, 0) * UPRIGHT, Color3.fromRGB(235, 215, 160), "cylinder")
	end
	-- hat 4..6: no hat

	if rng:NextNumber() < 0.3 then
		-- Sunglasses
		local glasses = Color3.fromRGB(20, 20, 25)
		addPiece(rig, head, Vector3.new(w * 0.32, h * 0.18, 0.08), CFrame.new(-w * 0.2, h * 0.08, -d * 0.52), glasses)
		addPiece(rig, head, Vector3.new(w * 0.32, h * 0.18, 0.08), CFrame.new(w * 0.2, h * 0.08, -d * 0.52), glasses)
		addPiece(rig, head, Vector3.new(w * 0.15, 0.06, 0.06), CFrame.new(0, h * 0.12, -d * 0.52), glasses)
	end
end

local function makeRig(): Model?
	local description = Instance.new("HumanoidDescription")
	-- Body shape: tall or short, slim or broad
	description.HeightScale = rng:NextNumber(0.85, 1.1)
	description.WidthScale = rng:NextNumber(0.75, 1.0)
	description.DepthScale = rng:NextNumber(0.85, 1.0)
	description.HeadScale = rng:NextNumber(0.95, 1.0)
	description.BodyTypeScale = rng:NextNumber(0, 0.6)
	description.ProportionScale = rng:NextNumber(0, 1)

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Customers] Couldn't make a customer:", rig)
		return nil
	end

	-- Outfit: we colour each body part ourselves, so sleeves and shorts work
	local bodyColors = rig:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	local skin = pick(SKIN_TONES)
	local shirt = pick(SHIRT_COLORS)
	local pants = pick(PANTS_COLORS)
	local shoes = pick(SHOE_COLORS)
	local longSleeves = rng:NextNumber() < 0.4
	local shorts = rng:NextNumber() < 0.35
	local colors = {
		Head = skin,
		UpperTorso = shirt,
		LowerTorso = pants,
		LeftUpperArm = shirt,
		RightUpperArm = shirt,
		LeftLowerArm = if longSleeves then shirt else skin,
		RightLowerArm = if longSleeves then shirt else skin,
		LeftHand = skin,
		RightHand = skin,
		LeftUpperLeg = pants,
		RightUpperLeg = pants,
		LeftLowerLeg = if shorts then skin else pants,
		RightLowerLeg = if shorts then skin else pants,
		LeftFoot = shoes,
		RightFoot = shoes,
	}
	for partName, color in colors do
		local part = rig:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
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

	addHeadwear(rig)
	local torso = rig:FindFirstChild("UpperTorso") :: BasePart?
	if torso and rng:NextNumber() < 0.25 then
		-- A backpack on their back (+Z is behind them)
		local size = torso.Size
		addPiece(rig, torso, Vector3.new(size.X * 0.7, size.Y * 0.85, 0.6), CFrame.new(0, 0, size.Z / 2 + 0.3), pick(HAT_COLORS))
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

-- Walks to a point the smart way: PathfindingService plans a route around
-- street lights, trees and signs. If no route is found, walk straight there.
local function goTo(rig: Model, humanoid: Humanoid, position: Vector3): boolean
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return walkTo(rig, humanoid, position)
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, position)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return walkTo(rig, humanoid, position)
	end
	local waypoints = path:GetWaypoints()
	for index = 2, #waypoints do
		if not walkTo(rig, humanoid, waypoints[index].Position) then
			return false
		end
	end
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
		return (plot.Origin * CFrame.new(LemonadeStand.STAND_X + offset, 3, SIDEWALK_LANE_Z)).Position
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

	if goTo(rig, humanoid, spot.Position + Vector3.new(0, 2, 0)) then
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
	if goTo(rig, humanoid, sidewalk(rng:NextNumber(-8, 8))) then
		goTo(rig, humanoid, sidewalk(if rng:NextNumber() < 0.5 then -45 else 45))
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
