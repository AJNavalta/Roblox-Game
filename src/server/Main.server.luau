--[[
	Main.server.luau
	The server's starting point. It wires the modules together:
	  server starts -> build the city and the empty lots
	  player joins  -> load their save, spawn them in the plaza
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

-- Joining and leaving -------------------------------------------------------

local function onPlayerAdded(player: Player)
	local data = PlayerData.load(player)
	if not player.Parent then
		return -- they left while we were loading
	end
	loadedData[player] = data

	notifyEvent:FireClient(player, "Welcome to " .. Config.CityName .. "! Walk to a blue FOR SALE pad to claim a lot.", "info")
	if not PlayerData.isSaving(player) then
		notifyEvent:FireClient(player, "Saving is off right now. See the README to turn it on in Studio.", "error")
	end
end

local function onPlayerRemoving(player: Player)
	local session = Tycoon.stop(player)
	if session then
		PlayerData.save(player, session.Data)
	end
	PlayerData.forget(player)
	loadedData[player] = nil

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
