--[[
	Homes.luau
	The server side of the laptop's 🏠 Homes app: buying homes and moving
	between the ones you own. The list of homes and prices is in
	src/shared/HomeConfig.luau, and how they look is in HomeBuilder.luau.

	  * Everyone owns the free Garden Shed.
	  * Buying a home moves you in straight away.
	  * You can move back into any home you already own, for free.

	Talking to the app:
	  HomeRequest  RemoteFunction
	    ("list")          -> { Current = homeId, Owned = { [homeId] = true } }
	    ("buy", homeId)   -> { Ok, Message, Current, Owned }
	    ("move", homeId)  -> { Ok, Message, Current, Owned }

	It also builds a small copy of every home into
	ReplicatedStorage.HomePreviews, which the app shows as the listing photos.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local HomeConfig = require(ReplicatedStorage.Shared.HomeConfig)
local HomeBuilder = require(script.Parent.HomeBuilder)
local PlotBuilder = require(script.Parent.PlotBuilder)

local Homes = {}

local Tycoon = nil
local notifyEvent: RemoteEvent? = nil

local function notify(player: Player, text: string, kind: string)
	if notifyEvent then
		notifyEvent:FireClient(player, text, kind)
	end
end

-- Builds the listing "photos": a copy of each home on a patch of lawn.
local function buildPreviews()
	local folder = Instance.new("Folder")
	folder.Name = "HomePreviews"
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end

	for _, home in HomeConfig.Homes do
		local model, laptop = HomeBuilder.buildHouse(home.Id, at)
		model.Name = home.Id
		-- The preview is only for looking at: no prompts, no tags
		CollectionService:RemoveTag(laptop, "Workstation")
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("ProximityPrompt") or descendant:IsA("Light") then
				descendant:Destroy()
			end
		end

		-- Lawn, driveway and path under the home so the photo looks like a lot
		local lawn = Instance.new("Part")
		lawn.Anchored = true
		lawn.Size = Vector3.new(150, 1, 96)
		lawn.CFrame = CFrame.new(-5, 0.5, -44)
		lawn.Color = Color3.fromRGB(80, 165, 85)
		lawn.Material = Enum.Material.Grass
		lawn.Parent = model
		local driveway = Instance.new("Part")
		driveway.Anchored = true
		driveway.Size = Vector3.new(HomeBuilder.DRIVEWAY_WIDTH, 0.2, 46)
		driveway.CFrame = CFrame.new(HomeBuilder.DRIVEWAY_X, 1.1, -23)
		driveway.Color = Color3.fromRGB(190, 190, 185)
		driveway.Parent = model
		model.PrimaryPart = lawn

		model.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function state(data)
	return { Current = data.Home, Owned = data.Homes }
end

-- Puts the player's home on their lot and walks them out the front door,
-- so nobody gets stuck inside a wall of the new house.
local function moveIn(player: Player, session, homeId: string)
	session.Data.Home = homeId
	PlotBuilder.setHome(session.Plot, homeId)
	local character = player.Character
	if character then
		character:PivotTo(session.Plot.SpawnCFrame)
	end
end

local function handle(player: Player, action: string, homeId: string?)
	local session = Tycoon.getSession(player)
	if not session then
		return { Ok = false, Message = "Claim a lot first!" }
	end
	local data = session.Data

	if action == "list" then
		return state(data)
	end

	local home = type(homeId) == "string" and HomeConfig.HomesById[homeId]
	if not home then
		return { Ok = false, Message = "That home doesn't exist." }
	end

	if action == "move" or (action == "buy" and data.Homes[home.Id]) then
		if not data.Homes[home.Id] then
			return { Ok = false, Message = "You don't own that home yet." }
		end
		moveIn(player, session, home.Id)
		notify(player, "Welcome home! You moved into your " .. home.Name .. ".", "success")
		local result = state(data)
		result.Ok = true
		return result
	end

	if action == "buy" then
		if data.Cash < home.Price then
			return { Ok = false, Message = "You need " .. Format.money(home.Price - data.Cash) .. " more." }
		end
		Tycoon.changeCash(player, -home.Price)
		data.Homes[home.Id] = true
		moveIn(player, session, home.Id)
		notify(player, "🏠 You bought the " .. home.Name .. "! Welcome home.", "unlock")
		local result = state(data)
		result.Ok = true
		return result
	end

	return { Ok = false, Message = "Unknown action." }
end

function Homes.init(tycoon, remote: RemoteEvent)
	Tycoon = tycoon
	notifyEvent = remote

	buildPreviews()

	local request = Instance.new("RemoteFunction")
	request.Name = "HomeRequest"
	request.OnServerInvoke = function(player, action, homeId)
		local ok, result = pcall(handle, player, action, homeId)
		if not ok then
			warn("[Homes]", result)
			return { Ok = false, Message = "Something went wrong, try again." }
		end
		return result
	end
	request.Parent = ReplicatedStorage

	-- When someone claims a lot, put their own home on it
	local function watch(player: Player)
		player:GetAttributeChangedSignal("HasLot"):Connect(function()
			local session = Tycoon.getSession(player)
			if session and player:GetAttribute("HasLot") then
				PlotBuilder.setHome(session.Plot, session.Data.Home or HomeConfig.StartingHome)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Homes
