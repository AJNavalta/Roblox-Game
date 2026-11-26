--[[
	Tycoon.luau
	The game rules: buying items, earning income, collecting cash, unlocking
	stages. The server is the only one that changes money, so exploiters
	can't just give themselves cash.

	Each player in the game has a "session":
	  session.Data    the saved stuff: Cash, Pending, Owned, Billionaire
	  session.Plot    their plot, from PlotBuilder
	  session.Income  dollars per second (worked out from Owned)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlotBuilder = require(script.Parent.PlotBuilder)

local Tycoon = {}

local sessions = {} -- [Player] = session
local notifyEvent: RemoteEvent? = nil

local AFFORDABLE_COLOR = Color3.fromRGB(60, 220, 90)
local TOO_EXPENSIVE_COLOR = Color3.fromRGB(220, 60, 60)
local TOUCH_COOLDOWN = 1 -- seconds before the same pad reacts again

-- Helpers -------------------------------------------------------------------

local function notify(player: Player, text: string, kind: string?)
	if notifyEvent then
		notifyEvent:FireClient(player, text, kind or "info")
	end
end

local function isStageComplete(data, stage): boolean
	for _, item in stage.Items do
		if not data.Owned[item.Id] then
			return false
		end
	end
	return true
end

local function isStageUnlocked(data, stageIndex: number): boolean
	if stageIndex <= 1 then
		return true
	end
	return isStageComplete(data, Config.Stages[stageIndex - 1])
end

local function currentStageIndex(data): number
	local index = 1
	for i = 2, #Config.Stages do
		if isStageUnlocked(data, i) then
			index = i
		else
			break
		end
	end
	return index
end

local function computeIncome(data): number
	local total = 0
	for itemId in data.Owned do
		local info = Config.ItemsById[itemId]
		if info then
			total += info.Item.Income
		end
	end
	return total
end

-- Which player (if any) touched this part?
local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character)
end

-- Stops a pad from firing 30 times a second while you stand on it.
local function cooldownReady(session, key: string): boolean
	local now = os.clock()
	local last = session.Cooldowns[key]
	if last and now - last < TOUCH_COOLDOWN then
		return false
	end
	session.Cooldowns[key] = now
	return true
end

local function moveCharacterToPlot(character: Model, plot)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		task.wait(0.1) -- let Roblox finish placing the character first
		if character.Parent then
			character:PivotTo(plot.SpawnCFrame)
		end
	end)
end

-- Pushes the latest numbers to leaderstats, the HUD, signs and buttons.
local function refresh(session)
	local data = session.Data
	local plot = session.Plot
	local player = session.Player

	session.CashValue.Value = math.floor(data.Cash)

	local stageIndex = currentStageIndex(data)
	player:SetAttribute("Income", session.Income)
	player:SetAttribute("Pending", math.floor(data.Pending))
	player:SetAttribute("StageIndex", stageIndex)
	player:SetAttribute("StageName", Config.Stages[stageIndex].Name)

	plot.CollectorLabel.Text = "Cash Collector\n" .. Format.money(data.Pending)

	for index, stage in Config.Stages do
		local unlocked = isStageUnlocked(data, index)
		local label = plot.StageLabels[index]
		if isStageComplete(data, stage) then
			label.Text = stage.Name .. "  ✔"
		elseif unlocked then
			label.Text = stage.Name
		else
			label.Text = "🔒 " .. stage.Name
		end

		for _, item in stage.Items do
			local button = plot.Buttons[item.Id]
			if unlocked and not data.Owned[item.Id] then
				button.Part.Parent = plot.ButtonsFolder
				button.Part.Color = if data.Cash >= item.Cost then AFFORDABLE_COLOR else TOO_EXPENSIVE_COLOR
			else
				button.Part.Parent = nil
			end
		end
	end
end

local function checkBillionaire(session)
	local data = session.Data
	if not data.Billionaire and data.Cash >= Config.BillionaireGoal then
		data.Billionaire = true
		for _, other in Players:GetPlayers() do
			notify(other, session.Player.DisplayName .. " just became a BILLIONAIRE! 🎉", "unlock")
		end
	end
end

-- Public API ----------------------------------------------------------------

function Tycoon.init(remote: RemoteEvent)
	notifyEvent = remote
end

function Tycoon.purchase(player: Player, itemId: string)
	local session = sessions[player]
	local info = Config.ItemsById[itemId]
	if not session or not info then
		return
	end

	local data = session.Data
	local item = info.Item
	if data.Owned[itemId] or not isStageUnlocked(data, info.StageIndex) then
		return
	end

	if data.Cash < item.Cost then
		notify(player, "You need " .. Format.money(item.Cost - data.Cash) .. " more for " .. item.Name, "error")
		return
	end

	data.Cash -= item.Cost
	data.Owned[itemId] = true
	session.Income = computeIncome(data)
	PlotBuilder.addItemVisual(session.Plot, info)
	notify(player, "Bought " .. item.Name .. "! +" .. Format.money(item.Income) .. "/s", "success")

	if isStageComplete(data, info.Stage) then
		local nextStage = Config.Stages[info.StageIndex + 1]
		if nextStage then
			notify(player, "New business unlocked: " .. nextStage.Name .. "!", "unlock")
		else
			notify(player, "You own every business. Absolute tycoon!", "unlock")
		end
	end

	refresh(session)
end

function Tycoon.collect(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	local data = session.Data
	local amount = math.floor(data.Pending)
	if amount < 1 then
		return
	end

	data.Pending -= amount
	data.Cash += amount
	notify(player, "+" .. Format.money(amount) .. " collected", "cash")
	checkBillionaire(session)
	refresh(session)
end

-- Called every Config.IncomeInterval seconds by Main.
function Tycoon.tick(deltaSeconds: number)
	for _, session in sessions do
		session.Data.Pending += session.Income * deltaSeconds
		refresh(session)
	end
end

-- Sets up a player who just joined: leaderstats, their owned buildings, and
-- the touch pads on their plot.
function Tycoon.start(player: Player, data, plot)
	local session = {
		Player = player,
		Data = data,
		Plot = plot,
		Income = computeIncome(data),
		Cooldowns = {},
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats" -- this exact name makes Roblox show it on the player list
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	leaderstats.Parent = player
	session.CashValue = cash

	-- Rebuild everything they bought in earlier visits
	for itemId in data.Owned do
		local info = Config.ItemsById[itemId]
		if info then
			PlotBuilder.addItemVisual(plot, info)
		end
	end

	for itemId, button in plot.Buttons do
		button.Part.Touched:Connect(function(hit)
			if playerFromHit(hit) == player and cooldownReady(session, itemId) then
				Tycoon.purchase(player, itemId)
			end
		end)
	end

	plot.Collector.Touched:Connect(function(hit)
		if playerFromHit(hit) == player and cooldownReady(session, "collector") then
			Tycoon.collect(player)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		moveCharacterToPlot(character, plot)
	end)
	if player.Character then
		moveCharacterToPlot(player.Character, plot)
	end

	sessions[player] = session
	refresh(session)
end

-- Removes the player's session and returns it (so Main can save + clean up).
function Tycoon.stop(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	return session
end

function Tycoon.getSessions()
	return sessions
end

return Tycoon
