--[[
	Customers.luau
	NPC customers who wander onto your lot, walk up to one of your lemonade
	stands, enjoy a drink, and leave. The more lemonade items you own, the
	more often they come.

	They're just for show: they don't change your money (yet!). If you want
	them to tip, Tycoon would be the place to add that.

	Tweak the numbers below to change how busy lots feel.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Tycoon = require(script.Parent.Tycoon)

local Customers = {}

local MAX_PER_LOT = 3 -- most customers on one lot at a time
local SLOWEST_GAP = 16 -- seconds between customers when you own 1 lemonade item
local FASTEST_GAP = 5 -- ...never more often than this
local DRINK_TIME = 3 -- seconds spent at the stand
local WALK_TIMEOUT = 10 -- give up on a walk after this long (if they get stuck)

-- Items customers can visit, in the order we prefer them
local SHOP_ITEMS = {
	"lemon_pitcher",
	"lemon_table",
	"lemon_stand2",
	"lemon_pink",
	"lemon_slushie",
	"lemon_bike",
	"lemon_truck",
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

-- One customer's whole visit: walk in, drink, walk out.
local function visit(lot, plot, info)
	local rig = makeRig()
	if not rig then
		return
	end

	-- Work in the lot's own space: X across, Z = 0 at the road, negative = deeper.
	local slot = plot.Origin:ToObjectSpace(PlotBuilder.getSlotCFrame(plot, info)).Position
	local walkwayX = PlotBuilder.getWalkwayX(info)
	local counterZ = slot.Z + 5.5 -- just in front of the stand
	local function world(x: number, z: number): Vector3
		return (plot.Origin * CFrame.new(x, 3, z)).Position
	end

	local entranceZ = 4 -- on the sidewalk in front of the lot
	local entryX = walkwayX + rng:NextNumber(-12, 12)
	rig:PivotTo(CFrame.lookAt(world(entryX, entranceZ), world(walkwayX, 0)))
	rig.Parent = folder
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil) -- the server moves them, so the server owns their physics
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	table.insert(lot.Active, rig)

	local route = {
		world(walkwayX, entranceZ),
		world(walkwayX, counterZ),
		world(slot.X + rng:NextNumber(-2.5, 2.5), counterZ),
	}
	for _, point in route do
		if not walkTo(rig, humanoid, point) then
			return
		end
	end

	-- Face the stand and enjoy a drink
	if root then
		local standPosition = world(slot.X, slot.Z)
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(standPosition.X, root.Position.Y, standPosition.Z))
	end
	humanoid.Jump = rng:NextNumber() < 0.3 -- some customers are extra excited
	local bubble = say(rig, pick(PHRASES))
	task.wait(DRINK_TIME)
	if bubble then
		bubble:Destroy()
	end

	-- Walk back out the way they came, then off along the sidewalk
	local exitX = walkwayX + (if rng:NextNumber() < 0.5 then -25 else 25)
	for _, point in { route[2], route[1], world(exitX, entranceZ) } do
		if not walkTo(rig, humanoid, point) then
			return
		end
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

local function ownedShops(owned)
	local shops = {}
	for _, itemId in SHOP_ITEMS do
		if (owned[itemId] or 0) > 0 then
			table.insert(shops, Config.ItemsById[itemId])
		end
	end
	return shops
end

function Customers.start()
	local lots = {} -- [plot] = { Active = {rigs}, NextVisit = time }

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
					lot = { Active = {}, NextVisit = now + rng:NextNumber(2, 5) }
					lots[plot] = lot
				end

				-- Forget customers who already left
				for i = #lot.Active, 1, -1 do
					if not lot.Active[i].Parent then
						table.remove(lot.Active, i)
					end
				end

				local owned = session.Data.Owned
				local shops = ownedShops(owned)
				if #shops > 0 and #lot.Active < MAX_PER_LOT and now >= lot.NextVisit then
					local gap = math.max(FASTEST_GAP, SLOWEST_GAP - lemonadeOwnedCount(owned))
					lot.NextVisit = now + gap + rng:NextNumber(0, 3)
					task.spawn(visit, lot, plot, pick(shops))
				end
			end

			-- Lot owner left: send their customers home
			for plot, lot in lots do
				if not activePlots[plot] then
					for _, rig in lot.Active do
						rig:Destroy()
					end
					lots[plot] = nil
				end
			end
		end
	end)
end

return Customers
