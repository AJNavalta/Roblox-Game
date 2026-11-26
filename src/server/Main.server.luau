--[[
	Main.server.luau
	The server's starting point. It wires the modules together:
	  player joins  -> load save -> give them a plot -> start their tycoon
	  every second  -> pay income
	  every minute  -> autosave
	  player leaves -> save -> clear their plot
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Tycoon = require(script.Parent.Tycoon)

-- The server uses this to send pop-up messages to a player's screen.
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "TycoonNotify"
notifyEvent.Parent = ReplicatedStorage
Tycoon.init(notifyEvent)

-- Plot bookkeeping ----------------------------------------------------------

local plotsInUse = {} -- [plotIndex] = Player
local plotOf = {} -- [Player] = plot

local function claimPlotIndex(player: Player): number?
	for index = 1, Config.MaxPlots do
		if not plotsInUse[index] then
			plotsInUse[index] = player
			return index
		end
	end
	return nil
end

-- Joining and leaving -------------------------------------------------------

local function onPlayerAdded(player: Player)
	local data = PlayerData.load(player)
	if not player.Parent then
		return -- they left while we were loading
	end

	local index = claimPlotIndex(player)
	if not index then
		player:Kick("This server is full, please join another one!")
		return
	end

	local plot = PlotBuilder.build(index, player)
	plotOf[player] = plot
	Tycoon.start(player, data, plot)

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

	local plot = plotOf[player]
	if plot then
		plotsInUse[plot.Index] = nil
		plotOf[player] = nil
		PlotBuilder.destroy(plot)
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
