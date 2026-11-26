--[[
	Main.server.luau
	The server's starting point. It wires the modules together:
	  server starts -> build the city and the empty lots
	  player joins  -> they pick a save slot, we load it (see "Save slots")
	  claims a lot  -> start their tycoon on it
	  every second  -> pay income
	  every minute  -> autosave
	  every 3 sec   -> stock prices move (see Market.luau)
	  player leaves -> save, put their lot back up for sale
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CityBuilder = require(script.Parent.CityBuilder)
local Customers = require(script.Parent.Customers)
local DevTools = require(script.Parent.DevTools)
local Garage = require(script.Parent.Garage)
local Homes = require(script.Parent.Homes)
local Market = require(script.Parent.Market)
local PlayerData = require(script.Parent.PlayerData)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Tycoon = require(script.Parent.Tycoon)

-- The server uses this to send pop-up messages to a player's screen.
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "TycoonNotify"
notifyEvent.Parent = ReplicatedStorage
Tycoon.init(notifyEvent)
Market.init(Tycoon, notifyEvent) -- the phone's stock market, crypto and NFTs
Garage.init(Tycoon) -- the phone's car shop
Homes.init(Tycoon, notifyEvent) -- the laptop's Homes app: buy and move into homes
DevTools.init(Tycoon, notifyEvent) -- testing cheat: /money for the developer only

-- Build the world -----------------------------------------------------------

CityBuilder.build()

local loadedData = {} -- [Player] = save data, from join until they leave
local plotOf = {} -- [Player] = the lot they claimed

local function claim(player: Player, plot)
	if plot.Owner or plotOf[player] or not loadedData[player] then
		return -- lot taken, they already have one, or their save is still loading
	end

	PlotBuilder.setOwner(plot, player)
	plotOf[player] = plot
	Tycoon.start(player, loadedData[player], plot)
	notifyEvent:FireClient(player, "This lot is yours! Step on the buttons to build your empire.", "unlock")
end

local plots = {}
for index = 1, PlotBuilder.LotCount do
	local plot = PlotBuilder.build(index)
	plots[index] = plot
	Tycoon.attachPlot(plot)
	plot.ClaimPad.Touched:Connect(function(hit)
		local player = Tycoon.playerFromHit(hit)
		if player then
			claim(player, plot)
		end
	end)
end

-- NPC customers who visit players' lemonade stands
Customers.start()

-- Joining and leaving -------------------------------------------------------

-- Save slots ------------------------------------------------------------------
-- Each player has 3 save files. The "choose a save" screen
-- (src/client/SaveSlots.client.luau) asks this RemoteFunction:
--   ("list")         -> { Saving, Current, Slots = { [slot] = summary or false } }
--   ("choose", slot) -> { Ok, Message, Current }
-- Choosing another slot mid-game saves the current one first, then loads
-- the new one onto the same lot.

local Progression = require(ReplicatedStorage.Shared.Progression)
local HomeConfig = require(ReplicatedStorage.Shared.HomeConfig)

local switching: { [Player]: boolean } = {}

local function summarize(data)
	local items = 0
	for _ in data.Owned do
		items += 1
	end
	local home = HomeConfig.HomesById[data.Home]
	return {
		Cash = data.Cash + data.Pending,
		Stage = Config.Stages[Progression.highestUnlockedStage(data.Owned)].Name,
		Home = if home then home.Name else "",
		Items = items,
	}
end

local function chooseSlot(player: Player, slot: number)
	if switching[player] then
		return { Ok = false, Message = "Hang on, still loading..." }
	end
	if PlayerData.getSlot(player) == slot and loadedData[player] then
		return { Ok = true, Current = slot }
	end
	switching[player] = true

	-- Save and pack up the current game, if there is one
	local plot = plotOf[player]
	local session = Tycoon.stop(player)
	if session then
		PlayerData.save(player, session.Data)
	end
	if plot then
		plotOf[player] = nil
		PlotBuilder.setOwner(plot, nil)
		player:SetAttribute("HasLot", false)
	end
	loadedData[player] = nil

	local data = PlayerData.load(player, slot)
	switching[player] = nil
	if not player.Parent then
		return { Ok = false } -- they left while we were loading
	end
	loadedData[player] = data
	player:SetAttribute("SaveSlot", slot)

	if plot and not plot.Owner then
		claim(player, plot) -- straight back onto the same lot
	else
		notifyEvent:FireClient(player, "Save " .. slot .. " loaded! Walk to a blue FOR SALE pad to claim a lot.", "info")
	end
	if not PlayerData.isSaving(player) then
		notifyEvent:FireClient(player, "Saving is off right now. See the README to turn it on in Studio.", "error")
	end
	return { Ok = true, Current = slot }
end

local saveRequest = Instance.new("RemoteFunction")
saveRequest.Name = "SaveRequest"
saveRequest.OnServerInvoke = function(player, action, slot)
	if action == "list" then
		local stored = PlayerData.peek(player)
		local current = PlayerData.getSlot(player)
		local slots = {}
		for index = 1, PlayerData.SLOT_COUNT do
			local data = stored and stored[index]
			-- The slot you're playing right now: show the live numbers
			if index == current and loadedData[player] then
				data = loadedData[player]
			end
			slots[index] = if data then summarize(data) else false
		end
		return { Saving = stored ~= nil, Current = current, Slots = slots }
	elseif action == "choose" then
		if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > PlayerData.SLOT_COUNT then
			return { Ok = false, Message = "That save doesn't exist." }
		end
		local ok, result = pcall(chooseSlot, player, slot)
		if not ok then
			switching[player] = nil
			warn("[SaveSlots]", result)
			return { Ok = false, Message = "Something went wrong, try again." }
		end
		return result
	end
	return { Ok = false }
end
saveRequest.Parent = ReplicatedStorage

local function onPlayerAdded(player: Player)
	-- Nothing loads until they pick a save slot on the "choose a save" screen
	notifyEvent:FireClient(player, "Welcome to " .. Config.CityName .. "! Pick a save file to start.", "info")
end

local function onPlayerRemoving(player: Player)
	local session = Tycoon.stop(player)
	if session then
		PlayerData.save(player, session.Data)
	end
	PlayerData.forget(player)
	loadedData[player] = nil
	switching[player] = nil

	local plot = plotOf[player]
	if plot then
		plotOf[player] = nil
		PlotBuilder.setOwner(plot, nil) -- back up for sale
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- In Studio the first player can join before this script runs.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- When the server shuts down, save everyone before it closes.
game:BindToClose(function()
	local pending = 0
	for player, session in Tycoon.getSessions() do
		pending += 1
		task.spawn(function()
			PlayerData.save(player, session.Data)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)

-- Income loop ---------------------------------------------------------------

task.spawn(function()
	while true do
		local dt = task.wait(Config.IncomeInterval)
		Tycoon.tick(dt)
	end
end)

-- Autosave loop -------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for player, session in Tycoon.getSessions() do
			task.spawn(PlayerData.save, player, session.Data)
		end
	end
end)
