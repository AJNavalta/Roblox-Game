--[[
	Garage.luau
	The phone's 🚗 Cars app: buying vehicles and spawning them on your driveway.

	  * Vehicles are bought once and saved in data.Vehicles ([id] = true).
	  * Each player can have one vehicle out at a time. Spawning a new one
	    removes the old one, and leaving the game removes it too.
	  * Cars spawn on the "CarSpawn" part of the lot you own (the lot Model in
	    workspace.Lots whose OwnerUserId attribute is your UserId). If there's
	    no such spot, the car appears in front of you instead.

	Want nicer-looking cars? Put a drivable car Model from the Toolbox into
	ServerStorage > Vehicles in Studio and name it after the car's Id or Name
	(e.g. "sedan" or "Family Sedan"). The shop then spawns your model instead
	of the built-in block car. See the README ("Better-looking cars").
	If a model faces the wrong way, give it a number attribute SpawnRotation
	(try 180 or 90).

	How the built-in cars work: a body block, a VehicleSeat, and four wheels on
	HingeConstraints. The back wheels are motors (gas), the front wheels
	turn on servo hinges (steering). Sit in the seat and drive with
	W A S D (or the thumbstick on mobile). Jump to get out.

	Talking to the phone:
	  GarageRequest  RemoteFunction  "owned", "buy", "spawn", "despawn"
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local VehicleConfig = require(ReplicatedStorage.Shared.VehicleConfig)

local Garage = {}

local Tycoon = nil -- set in Garage.init
local activeCars: { [Player]: Model } = {}
local drivers = {} -- [Model] = { Seat, Motors, Servos, Def, Radius }

local STEER_ANGLE = 30 -- degrees the front wheels turn
local COAST_TORQUE = 300 -- how hard the wheels slow down when you let go of gas

-- Building a vehicle --------------------------------------------------------

local function part(props)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- Makes an attachment whose hinge axis points along `axis`
local function attachment(parent: BasePart, position: Vector3, axis: Vector3, secondary: Vector3)
	local a = Instance.new("Attachment")
	a.Position = position
	a.Axis = axis
	a.SecondaryAxis = secondary
	a.Parent = parent
	return a
end

local function build(def, cframe: CFrame): (Model, any)
	local model = Instance.new("Model")
	model.Name = def.Name

	local radius = def.WheelSize / 2
	local size = def.Body
	local bodyY = radius * 0.7 + size.Y / 2 -- height of the body's center above the ground
	local bodyCFrame = cframe * CFrame.new(0, bodyY, 0)

	local body = part({
		Name = "Body",
		Size = size,
		CFrame = bodyCFrame,
		Color = def.Color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	model.PrimaryPart = body

	if def.Cabin then
		local cabin = part({
			Name = "Cabin",
			Size = def.Cabin,
			CFrame = bodyCFrame * CFrame.new(0, size.Y / 2 + def.Cabin.Y / 2, size.Z / 2 - def.Cabin.Z / 2 - 1.5),
			Color = Color3.fromRGB(150, 200, 230),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			CanCollide = false,
			Massless = true,
			Parent = model,
		})
		weld(body, cabin)
	end

	-- Headlights and tail lights
	for _, side in { -1, 1 } do
		local head = part({
			Size = Vector3.new(math.min(1.2, size.X / 4), 0.6, 0.2),
			CFrame = bodyCFrame * CFrame.new(side * size.X * 0.3, 0.2, -size.Z / 2 - 0.1),
			Color = Color3.fromRGB(255, 250, 210),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Massless = true,
			Parent = model,
		})
		weld(body, head)
		local tail = head:Clone()
		tail.CFrame = bodyCFrame * CFrame.new(side * size.X * 0.3, 0.2, size.Z / 2 + 0.1)
		tail.Color = Color3.fromRGB(255, 40, 40)
		tail.Parent = model
		weld(body, tail)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.CFrame = bodyCFrame * CFrame.new(if def.Bike then 0 else -size.X / 4, size.Y / 2 + 0.3, if def.Cabin then size.Z / 2 - def.Cabin.Z / 2 - 1.5 else 0.5)
	seat.Color = Color3.fromRGB(40, 40, 45)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.MaxSpeed = def.Speed
	seat.Massless = true
	seat.Parent = model
	weld(body, seat)

	-- Wheels. Bikes get wide hidden "training wheels" plus two visible wheels in the middle.
	local track = if def.Bike then 3 else size.X / 2 + 0.5
	local wheelbase = size.Z / 2 - radius - 0.3
	local wheelY = radius - bodyY -- wheel centers, relative to the body
	local grip = PhysicalProperties.new(0.7, 2, 0, 100, 1)
	local motors, servos = {}, {}

	for _, z in { -wheelbase, wheelbase } do
		local isFront = z < 0 -- the front of the car is -Z
		for _, side in { -1, 1 } do
			local position = Vector3.new(side * track, wheelY, z)
			local wheel = part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder, -- a cylinder's round sides face along X, like a wheel
				Size = Vector3.new(if def.Bike then 0.6 else 1.2, def.WheelSize, def.WheelSize),
				CFrame = bodyCFrame * CFrame.new(position),
				Color = Color3.fromRGB(30, 30, 30),
				Transparency = if def.Bike then 1 else 0,
				CustomPhysicalProperties = grip,
				Parent = model,
			})

			local holder: BasePart = body
			local holderPosition = position
			if isFront then
				-- A little invisible knuckle that turns left/right (steering)
				local knuckle = part({
					Name = "Knuckle",
					Size = Vector3.new(0.4, 0.4, 0.4),
					CFrame = bodyCFrame * CFrame.new(position),
					Transparency = 1,
					CanCollide = false,
					Parent = model,
				})
				local steer = Instance.new("HingeConstraint")
				steer.ActuatorType = Enum.ActuatorType.Servo
				steer.ServoMaxTorque = 1e6
				steer.AngularSpeed = 5
				steer.LimitsEnabled = true
				steer.LowerAngle = -STEER_ANGLE
				steer.UpperAngle = STEER_ANGLE
				steer.Attachment0 = attachment(body, position, Vector3.yAxis, Vector3.xAxis)
				steer.Attachment1 = attachment(knuckle, Vector3.zero, Vector3.yAxis, Vector3.xAxis)
				steer.Parent = knuckle
				table.insert(servos, steer)
				holder = knuckle
				holderPosition = Vector3.zero
			end

			local hinge = Instance.new("HingeConstraint")
			hinge.Attachment0 = attachment(holder, holderPosition, Vector3.xAxis, Vector3.yAxis)
			hinge.Attachment1 = attachment(wheel, Vector3.zero, Vector3.xAxis, Vector3.yAxis)
			if not isFront then
				hinge.ActuatorType = Enum.ActuatorType.Motor
				hinge.MotorMaxTorque = COAST_TORQUE
				table.insert(motors, hinge)
			end
			hinge.Parent = wheel
		end

		if def.Bike then
			-- The wheel you actually see, welded on (just for looks)
			local visible = part({
				Name = "BikeWheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, def.WheelSize, def.WheelSize),
				CFrame = bodyCFrame * CFrame.new(0, wheelY, z),
				Color = Color3.fromRGB(30, 30, 30),
				CanCollide = false,
				Massless = true,
				Parent = model,
			})
			weld(body, visible)
		end
	end

	return model, { Seat = seat, Motors = motors, Servos = servos, Def = def, Radius = radius, Body = body }
end

-- Where to put a player's car -------------------------------------------------

local function findCarSpawn(player: Player): CFrame?
	local lots = workspace:FindFirstChild("Lots")
	if lots then
		for _, lot in lots:GetChildren() do
			if lot:GetAttribute("OwnerUserId") == player.UserId then
				local spot = lot:FindFirstChild("CarSpawn", true)
				if spot and spot:IsA("BasePart") then
					return spot.CFrame
				end
			end
		end
	end
	for _, spot in CollectionService:GetTagged("CarSpawn") do
		local lot = spot:FindFirstAncestorWhichIsA("Model")
		while lot and lot:GetAttribute("OwnerUserId") == nil do
			lot = lot.Parent and lot.Parent:FindFirstAncestorWhichIsA("Model")
		end
		if lot and lot:GetAttribute("OwnerUserId") == player.UserId and spot:IsA("BasePart") then
			return spot.CFrame
		end
	end
	return nil
end

-- Fallback: on the ground, a few steps in front of the player
local function spotInFront(player: Player): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local ahead = root.Position + look * 14
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ahead + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3
	local position = Vector3.new(ahead.X, groundY + 0.1, ahead.Z)
	-- Sideways to the player, so they can walk straight to the door
	return CFrame.lookAt(position, position + look:Cross(Vector3.yAxis))
end

-- Driving -------------------------------------------------------------------

local function setOwner(model: Model, player: Player?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(player)
			end)
		end
	end
end

local function removeCar(player: Player)
	local car = activeCars[player]
	activeCars[player] = nil
	if car then
		drivers[car] = nil
		car:Destroy()
	end
end

-- Toolbox cars ----------------------------------------------------------------

-- Finds a car Model AJ put in ServerStorage > Vehicles for this vehicle
local function findCustomModel(def): Model?
	local folder = ServerStorage:FindFirstChild("Vehicles")
	if not folder then
		return nil
	end
	local wanted = { def.Id:lower(), def.Name:lower() }
	for _, child in folder:GetChildren() do
		local name = child.Name:lower()
		if child:IsA("Model") and (name == wanted[1] or name == wanted[2]) then
			return child
		end
	end
	return nil
end

-- Copies the Toolbox car and parks it with its wheels on the spot
local function placeCustomModel(template: Model, cframe: CFrame): Model
	local car = template:Clone()
	local rotation = car:GetAttribute("SpawnRotation")
	local turn = if type(rotation) == "number" then math.rad(rotation) else 0

	local boxCFrame, boxSize = car:GetBoundingBox()
	local pivotFromBox = boxCFrame:ToObjectSpace(car:GetPivot())
	local target = cframe * CFrame.Angles(0, turn, 0) * CFrame.new(0, boxSize.Y / 2 + 0.3, 0)
	car:PivotTo(target * pivotFromBox)

	local hasScript = false
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			hasScript = true
			break
		end
	end
	if not hasScript then
		warn(("[Garage] '%s' in ServerStorage.Vehicles has no scripts, so it probably can't drive. Pick a Toolbox car that says it's drivable (like an A-Chassis car)."):format(template.Name))
	end
	return car
end

local function spawnCar(player: Player, def)
	local cframe = findCarSpawn(player) or spotInFront(player)
	if not cframe then
		return false, "Spawn your character first."
	end

	removeCar(player)

	local template = findCustomModel(def)
	if template then
		local ok, car = pcall(placeCustomModel, template, cframe)
		if ok then
			car:SetAttribute("OwnerUserId", player.UserId)
			car.Parent = workspace
			activeCars[player] = car -- it drives with its own scripts
			return true, def.Emoji .. " " .. def.Name .. " is waiting on your driveway!"
		end
		warn("[Garage] Couldn't spawn the Toolbox model for " .. def.Name .. ", using the built-in car:", car)
	end
	local model, info = build(def, cframe)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = workspace
	activeCars[player] = model
	drivers[model] = info

	-- Whoever drives controls the physics, so driving feels smooth for them
	info.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = info.Seat.Occupant
		local driver = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
		if model.Parent then
			setOwner(model, driver)
		end
	end)
	return true, def.Emoji .. " " .. def.Name .. " is waiting on your driveway!"
end

RunService.Heartbeat:Connect(function()
	for model, info in drivers do
		local seat = info.Seat
		local throttle = seat.ThrottleFloat
		local steer = seat.SteerFloat
		local spin = info.Def.Speed / info.Radius -- wheel turn speed for top speed
		for _, motor in info.Motors do
			-- The car's front is -Z; spinning the wheels "negative" around X drives it forward
			motor.AngularVelocity = -throttle * spin
			motor.MotorMaxTorque = if throttle ~= 0 then info.Body.AssemblyMass * 600 else COAST_TORQUE
		end
		for _, servo in info.Servos do
			servo.TargetAngle = -steer * STEER_ANGLE
		end
	end
end)

-- Requests from the phone ---------------------------------------------------

local function ownedList(data)
	local owned = {}
	for id in data.Vehicles or {} do
		owned[id] = true
	end
	return owned
end

local function handleRequest(player: Player, action, vehicleId)
	local session = Tycoon.getSession(player)
	if action == "owned" then
		local car = activeCars[player]
		return {
			Owned = if session then ownedList(session.Data) else {},
			Active = car and car:GetAttribute("VehicleId"),
		}
	end
	if action == "despawn" then
		removeCar(player)
		return { Ok = true, Message = "Car parked away." }
	end

	if not session then
		return { Ok = false, Message = "Claim a lot first." }
	end
	local def = type(vehicleId) == "string" and VehicleConfig.ById[vehicleId]
	if not def then
		return { Ok = false, Message = "That car doesn't exist." }
	end
	local data = session.Data
	data.Vehicles = data.Vehicles or {}

	if action == "buy" then
		if data.Vehicles[def.Id] then
			return { Ok = false, Message = "You already own this!" }
		end
		if data.Cash < def.Price then
			return { Ok = false, Message = "You need " .. Format.money(def.Price - data.Cash) .. " more." }
		end
		data.Vehicles[def.Id] = true
		Tycoon.changeCash(player, -def.Price)
		return { Ok = true, Message = "You bought a " .. def.Name .. "! Press SPAWN to drive it.", Owned = ownedList(data) }
	elseif action == "spawn" then
		if not data.Vehicles[def.Id] then
			return { Ok = false, Message = "Buy it first." }
		end
		local ok, message = spawnCar(player, def)
		local car = activeCars[player]
		if car then
			car:SetAttribute("VehicleId", def.Id)
		end
		return { Ok = ok, Message = message, Active = if ok then def.Id else nil }
	end
	return { Ok = false, Message = "Unknown action." }
end

-- Public API ----------------------------------------------------------------

function Garage.init(tycoonModule)
	Tycoon = tycoonModule

	local request = Instance.new("RemoteFunction")
	request.Name = "GarageRequest"
	request.Parent = ReplicatedStorage

	local lastRequest = {}
	request.OnServerInvoke = function(player, action, vehicleId)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 0.5 and action ~= "owned" then
			return { Ok = false, Message = "Slow down!" }
		end
		lastRequest[player] = now
		local ok, result = pcall(handleRequest, player, action, vehicleId)
		if ok then
			return result
		end
		warn("[Garage] Request failed:", result)
		return { Ok = false, Message = "Something went wrong. Try again." }
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		removeCar(player)
	end)
end

return Garage
