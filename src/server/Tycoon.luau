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

	-- The 💵 icon over the lemonade stand shows what's waiting to be collected
	local waiting = math.floor(data.Pending)
	plot.CollectorLabel.Text = Format.money(waiting)
	plot.CollectorIcon.Enabled = waiting >= 1
	plot.CollectorPrompt:SetAttribute("Active", waiting >= 1)
	plot.BuyPrompt:SetAttribute("Active", Tycoon.hasStand(owned))

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

	-- Collect money by walking up to the lemonade stand, or pressing E there
	plot.Collector.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local session = player and sessions[player]
		if session and plot.Owner == player and cooldownReady(session, "collector") then
			Tycoon.collect(player)
		end
	end)
	plot.CollectorPrompt.Triggered:Connect(function(player)
		if sessions[player] and plot.Owner == player then
			Tycoon.collect(player)
		end
	end)

	-- Real players buying a cup at someone else's stand
	plot.BuyPrompt.Triggered:Connect(function(buyer)
		Tycoon.buyLemonade(buyer, plot)
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

-- Real players as customers ---------------------------------------------------
-- Any player can walk up to the front of someone else's lemonade stand and
-- buy a cup. They pay a small price, the stand's owner gets double that as a
-- "real customer" bonus, and the buyer gets a lemon speed rush.

local CUP_COOLDOWN = 15 -- seconds before you can buy at the same stand again
local RUSH_SPEED = 24 -- walk speed during a lemon rush (normal is 16)
local RUSH_TIME = 20 -- seconds

function Tycoon.hasStand(owned): boolean
	return (owned.lemon_pitcher or 0) > 0 or (owned.lemon_table or 0) > 0
end

-- The price of a cup goes up as the stand gets fancier: $5 + $5 per lemonade item
function Tycoon.cupPrice(owned): number
	local count = 0
	for _, item in Config.Stages[1].Items do
		if (owned[item.Id] or 0) > 0 then
			count += 1
		end
	end
	return 5 + 5 * count
end

local function lemonRush(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hand = character and character:FindFirstChild("RightHand")
	if not humanoid then
		return
	end
	if hand and not character:FindFirstChild("LemonadeCup") then
		local cup = Instance.new("Part")
		cup.Name = "LemonadeCup"
		cup.Shape = Enum.PartType.Cylinder
		cup.Size = Vector3.new(0.8, 0.5, 0.5)
		cup.Color = Color3.fromRGB(255, 240, 120)
		cup.CanCollide = false
		cup.Massless = true
		cup.CFrame = hand.CFrame * CFrame.new(0, -0.4, -0.2) * CFrame.Angles(0, 0, math.rad(90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = cup
		weld.Parent = cup
		cup.Parent = character
		task.delay(RUSH_TIME, function()
			cup:Destroy()
		end)
	end
	local token = os.clock()
	player:SetAttribute("LemonRush", token)
	humanoid.WalkSpeed = RUSH_SPEED
	task.delay(RUSH_TIME, function()
		-- Only end the rush if they didn't start a newer one
		if player:GetAttribute("LemonRush") == token and humanoid.Parent then
			humanoid.WalkSpeed = 16
		end
	end)
end

function Tycoon.buyLemonade(buyer: Player, plot)
	local owner = plot.Owner
	local buyerSession = sessions[buyer]
	local ownerSession = owner and sessions[owner]
	if not ownerSession or owner == buyer then
		return
	end
	if not Tycoon.hasStand(ownerSession.Data.Owned) then
		return
	end
	if not buyerSession then
		notify(buyer, "Claim a lot first so you have money to spend!", "error")
		return
	end
	local key = "cup_" .. plot.Index
	local last = buyerSession.Cooldowns[key]
	if last and os.clock() - last < CUP_COOLDOWN then
		notify(buyer, "You're still sipping! Try again in a few seconds.", "info")
		return
	end

	local price = Tycoon.cupPrice(ownerSession.Data.Owned)
	if buyerSession.Data.Cash < price then
		notify(buyer, "A cup costs " .. Format.money(price) .. ".", "error")
		return
	end
	buyerSession.Cooldowns[key] = os.clock()

	buyerSession.Data.Cash -= price
	ownerSession.Data.Cash += price * 2
	lemonRush(buyer)
	notify(buyer, "🍋 You bought a lemonade from " .. owner.DisplayName .. "! Lemon rush: run faster for " .. RUSH_TIME .. "s.", "success")
	notify(owner, "🍋 " .. buyer.DisplayName .. " bought a lemonade! +" .. Format.money(price * 2) .. " (real customer bonus)", "cash")
	checkBillionaire(ownerSession)
	refresh(buyerSession)
	refresh(ownerSession)
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

	-- Reuse the cash display if they already had one (switching save slots),
	-- so the HUD and phone keep working
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats" -- this exact name makes Roblox show it on the player list
		leaderstats.Parent = player
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("NumberValue")
		cash.Name = "Cash"
		cash.Parent = leaderstats
	end
	session.CashValue = cash

	-- Rebuild everything they bought in earlier visits
	for itemId, level in data.Owned do
		local info = Config.ItemsById[itemId]
		if info then
			PlotBuilder.setItemVisual(plot, info, level)
		end
	end

	session.CharacterConnection = player.CharacterAdded:Connect(function(character)
		if sessions[player] == session then
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
	if session and session.CharacterConnection then
		session.CharacterConnection:Disconnect()
	end
	return session
end

function Tycoon.getSessions()
	return sessions
end

function Tycoon.getSession(player: Player)
	return sessions[player]
end

-- Adds (or with a negative amount, takes away) cash. Used by the phone's
-- Market app. Callers must check the player can afford it first.
function Tycoon.changeCash(player: Player, amount: number)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.Cash = math.max(0, session.Data.Cash + amount)
	checkBillionaire(session)
	refresh(session)
end

return Tycoon
