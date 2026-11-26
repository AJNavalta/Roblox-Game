--[[
	Tycoon.luau
	The game rules: buying and upgrading items, earning income, collecting
	cash, unlocking businesses. The server is the only one that changes
	money, so exploiters can't just give themselves cash.

	Each player who has claimed a lot has a "session":
	  session.Data    the saved stuff: Cash, Pending, Owned, Billionaire
	  session.Plot    their lot, from PlotBuilder
	  session.Income  dollars per second (worked out from Owned)

	The "what can I buy" rules live in src/shared/Progression.luau.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlotBuilder = require(script.Parent.PlotBuilder)

local Tycoon = {}

local sessions = {} -- [Player] = session
local notifyEvent: RemoteEvent? = nil

local AFFORDABLE_COLOR = Color3.fromRGB(60, 220, 90)
local TOO_EXPENSIVE_COLOR = Color3.fromRGB(220, 60, 60)
local NEEDS_COLOR = Color3.fromRGB(120, 120, 130)
local TOUCH_COOLDOWN = 1 -- seconds before the same pad reacts again

-- Helpers -------------------------------------------------------------------

local function notify(player: Player, text: string, kind: string?)
	if notifyEvent then
		notifyEvent:FireClient(player, text, kind or "info")
	end
end

-- Which player (if any) touched this part?
local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	return character and Players:GetPlayerFromCharacter(character)
end
Tycoon.playerFromHit = playerFromHit

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

local function unlockedStages(owned)
	local unlocked = {}
	for index = 1, #Config.Stages do
		unlocked[index] = Progression.isStageUnlocked(owned, index)
	end
	return unlocked
end

local function buttonText(info, status, detail, level): string
	local item = info.Item
	if status == "needs" then
		return item.Name .. "\nNeeds: " .. table.concat(detail, ", ")
	end
	local price = if detail == 0 then "FREE" else Format.money(detail)
	if level > 0 then
		return ("Upgrade %s → Lv%d\n%s"):format(item.Name, level + 1, price)
	elseif item.Choice then
		return "PICK ONE: " .. item.Name .. "\n" .. price
	end
	return item.Name .. "\n" .. price
end

-- Pushes the latest numbers to leaderstats, the HUD, signs and buttons.
local function refresh(session)
	local data = session.Data
	local owned = data.Owned
	local plot = session.Plot
	local player = session.Player

	session.CashValue.Value = math.floor(data.Cash)

	local stageIndex = Progression.highestUnlockedStage(owned)
	player:SetAttribute("Income", session.Income)
	player:SetAttribute("Pending", math.floor(data.Pending))
	player:SetAttribute("StageIndex", stageIndex)
	player:SetAttribute("StageName", Config.Stages[stageIndex].Name)

	plot.CollectorLabel.Text = "Cash Collector\n" .. Format.money(data.Pending)

	for index, stage in Config.Stages do
		local unlocked, have, need = Progression.stageUnlock(owned, index)
		local label = plot.StageLabels[index]
		if unlocked then
			label.Text = ("%s\n+%s/s"):format(stage.Name, Format.money(Progression.stageIncome(owned, stage)))
		else
			local fromStage = Config.Stages[Config.StageIndexById[stage.Unlock.Stage]]
			label.Text = ("🔒 %s\nOwn %d %s items (%d/%d)"):format(stage.Name, need, fromStage.Name, have, need)
		end
	end

	for itemId, button in plot.Buttons do
		local info = Config.ItemsById[itemId]
		local status, detail = Progression.status(owned, info)
		if status == "available" or status == "needs" then
			button.Part.Parent = plot.ButtonsFolder
			button.Label.Text = buttonText(info, status, detail, owned[itemId] or 0)
			if status == "needs" then
				button.Part.Color = NEEDS_COLOR
			else
				button.Part.Color = if data.Cash >= detail then AFFORDABLE_COLOR else TOO_EXPENSIVE_COLOR
			end
		else
			button.Part.Parent = nil
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

-- Hooks up a lot's buttons and collector once, when the server starts.
-- They only respond to the lot's current owner.
function Tycoon.attachPlot(plot)
	for itemId, button in plot.Buttons do
		button.Part.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local session = player and sessions[player]
			if session and plot.Owner == player and cooldownReady(session, itemId) then
				Tycoon.purchase(player, itemId)
			end
		end)
	end

	plot.Collector.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local session = player and sessions[player]
		if session and plot.Owner == player and cooldownReady(session, "collector") then
			Tycoon.collect(player)
		end
	end)
end

function Tycoon.purchase(player: Player, itemId: string)
	local session = sessions[player]
	local info = Config.ItemsById[itemId]
	if not session or not info then
		return
	end

	local data = session.Data
	local item = info.Item
	local status, detail = Progression.status(data.Owned, info)

	if status == "needs" then
		notify(player, "Buy " .. table.concat(detail, " and ") .. " first!", "error")
		return
	elseif status == "chosen_other" then
		notify(player, "You already picked " .. detail .. " instead.", "error")
		return
	elseif status ~= "available" then
		return
	end

	local cost = detail
	if data.Cash < cost then
		notify(player, "You need " .. Format.money(cost - data.Cash) .. " more for " .. item.Name, "error")
		return
	end

	local unlockedBefore = unlockedStages(data.Owned)
	local newLevel = (data.Owned[itemId] or 0) + 1

	data.Cash -= cost
	data.Owned[itemId] = newLevel
	session.Income = Progression.totalIncome(data.Owned)
	PlotBuilder.setItemVisual(session.Plot, info, newLevel)

	if newLevel > 1 then
		notify(player, ("Upgraded %s to Lv%d!"):format(item.Name, newLevel), "success")
	elseif item.Boost then
		notify(player, ("Bought %s! %s income x%g"):format(item.Name, info.Stage.Name, item.Boost), "success")
	else
		notify(player, "Bought " .. item.Name .. "! +" .. Format.money(item.Income) .. "/s", "success")
	end

	local unlockedAfter = unlockedStages(data.Owned)
	for index, stage in Config.Stages do
		if unlockedAfter[index] and not unlockedBefore[index] then
			notify(player, "New business unlocked: " .. stage.Name .. "!", "unlock")
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

-- Starts a player's tycoon on the lot they just claimed.
function Tycoon.start(player: Player, data, plot)
	local session = {
		Player = player,
		Data = data,
		Plot = plot,
		Income = Progression.totalIncome(data.Owned),
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
	for itemId, level in data.Owned do
		local info = Config.ItemsById[itemId]
		if info then
			PlotBuilder.setItemVisual(plot, info, level)
		end
	end

	player.CharacterAdded:Connect(function(character)
		if sessions[player] then
			moveCharacterToPlot(character, plot)
		end
	end)

	sessions[player] = session
	player:SetAttribute("HasLot", true)
	refresh(session)
end

function Tycoon.hasSession(player: Player): boolean
	return sessions[player] ~= nil
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
