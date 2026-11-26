--[[
	Rewards.luau
	The left-side buttons: 🎡 hourly spin, 🎁 daily reward, 💰 Robux cash shop.
	Numbers live in src/shared/RewardsConfig.luau.

	Everything is decided here on the server: the spin result, whether a
	reward is ready, and how much cash a Robux purchase gives. Saved fields
	(in the player's save slot):
	  (spin timers aren't saved: the 1, 2, 5... minute ladder restarts each visit)
	  LastDaily    os.time() of their last daily claim
	  DailyStreak  how many days in a row they've claimed
	  Receipts     IDs of Robux purchases already paid out (so a purchase
	               is never given twice)

	  TotalEarned  all cash ever earned, for 🏆 milestone badges
	  Milestones   badges unlocked: [key] = true

	Talking to the client:
	  RewardsRequest      RemoteFunction  "status", "spin", "daily"
	  MilestoneUnlocked   RemoteEvent     server -> client, shows the badge pop-up
]]

local BadgeService = game:GetService("BadgeService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RewardsConfig = require(ReplicatedStorage.Shared.RewardsConfig)
local PlayerData = require(script.Parent.PlayerData)

local Rewards = {}

local Tycoon = nil
local notifyEvent: RemoteEvent? = nil
local rng = Random.new()
local spinsThisVisit = {} -- [Player] = spins since they joined
local nextSpinAt = {} -- [Player] = os.time() when their next spin is ready

local MAX_RECEIPTS = 50 -- how many past purchase IDs we remember per save
local milestoneEvent: RemoteEvent? = nil

local function notify(player: Player, text: string, kind: string)
	if notifyEvent then
		notifyEvent:FireClient(player, text, kind)
	end
end

-- Total levels of everything bought on the lot
local function upgradeCount(data): number
	local total = 0
	for _, level in data.Owned or {} do
		if type(level) == "number" then
			total += level
		end
	end
	return total
end

local function incomeOf(session): number
	return session.Income or 0
end

local function streakDayFor(data, now: number): number
	local last = data.LastDaily or 0
	if last > 0 and now - last <= RewardsConfig.DailyStreakWindow then
		return (data.DailyStreak or 0) + 1
	end
	return 1
end

local function status(session)
	local data = session.Data
	local now = os.time()
	local income = incomeOf(session)
	local upgrades = upgradeCount(data)

	local spinAmounts = {}
	for index, prize in RewardsConfig.SpinPrizes do
		spinAmounts[index] = RewardsConfig.amount(prize, income, upgrades)
	end

	local day = streakDayFor(data, now)
	local dailyAmounts = {}
	for d = 1, #RewardsConfig.DailyMultipliers do
		dailyAmounts[d] = RewardsConfig.amount(RewardsConfig.DailyBase, income, upgrades, RewardsConfig.dailyMultiplier(d))
	end

	local productAmounts = {}
	for index, product in RewardsConfig.Products do
		productAmounts[index] = RewardsConfig.amount(product, income, upgrades)
	end

	local milestones = {}
	for _, milestone in RewardsConfig.Milestones do
		milestones[milestone.Key] = (data.Milestones or {})[milestone.Key] == true
	end

	return {
		Ok = true,
		TotalEarned = data.TotalEarned or 0,
		Milestones = milestones,
		SpinIn = math.max(0, (nextSpinAt[session.Player] or 0) - now),
		DailyIn = math.max(0, (data.LastDaily or 0) + RewardsConfig.DailyCooldown - now),
		DailyDay = day, -- the day they'd be claiming next
		SpinAmounts = spinAmounts,
		DailyAmounts = dailyAmounts,
		ProductAmounts = productAmounts,
	}
end

local function pickPrize(): number
	local total = 0
	for _, prize in RewardsConfig.SpinPrizes do
		total += prize.Weight
	end
	local roll = rng:NextNumber() * total
	for index, prize in RewardsConfig.SpinPrizes do
		roll -= prize.Weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

local function spin(player: Player, session)
	local data = session.Data
	local now = os.time()
	local wait = (nextSpinAt[player] or 0) - now
	if wait > 0 then
		return { Ok = false, Message = "Next spin in " .. math.ceil(wait / 60) .. " min." }
	end

	local index = pickPrize()
	local prize = RewardsConfig.SpinPrizes[index]
	local amount = RewardsConfig.amount(prize, incomeOf(session), upgradeCount(data))
	local count = (spinsThisVisit[player] or 0) + 1
	spinsThisVisit[player] = count
	nextSpinAt[player] = now + RewardsConfig.spinCooldown(count)
	Tycoon.changeCash(player, amount)

	local result = status(session)
	result.Index = index
	result.Amount = amount
	result.Message = ("%s! +%s"):format(prize.Name, Format.money(amount))
	return result
end

local function claimDaily(player: Player, session)
	local data = session.Data
	local now = os.time()
	local wait = (data.LastDaily or 0) + RewardsConfig.DailyCooldown - now
	if wait > 0 then
		return { Ok = false, Message = ("Come back in %dh %dm."):format(wait // 3600, (wait % 3600) // 60) }
	end

	local day = streakDayFor(data, now)
	local amount = RewardsConfig.amount(RewardsConfig.DailyBase, incomeOf(session), upgradeCount(data), RewardsConfig.dailyMultiplier(day))
	data.DailyStreak = day
	data.LastDaily = now
	Tycoon.changeCash(player, amount)
	notify(player, ("🎁 Day %d reward: +%s"):format(day, Format.money(amount)), "cash")

	local result = status(session)
	result.Amount = amount
	result.Day = day
	result.Message = ("Day %d claimed! +%s"):format(day, Format.money(amount))
	return result
end

-- Robux purchases ---------------------------------------------------------------

local productsById = {}
for _, product in RewardsConfig.Products do
	if product.ProductId ~= 0 then
		productsById[product.ProductId] = product
	end
end

-- Roblox calls this for every Developer Product purchase, and keeps calling
-- (even when they rejoin later) until we answer PurchaseGranted. So we only
-- say "granted" once the cash is safely in their save.
local function processReceipt(receipt)
	local product = productsById[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and Tycoon.getSession(player)
	if not product or not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- try again when they're in-game with a lot
	end

	local data = session.Data
	data.Receipts = data.Receipts or {}

	if not table.find(data.Receipts, receipt.PurchaseId) then
		local amount = RewardsConfig.amount(product, incomeOf(session), upgradeCount(data))
		table.insert(data.Receipts, receipt.PurchaseId)
		while #data.Receipts > MAX_RECEIPTS do
			table.remove(data.Receipts, 1)
		end
		Tycoon.changeCash(player, amount)
		notify(player, ("%s Thanks! +%s from %s"):format(product.Emoji, Format.money(amount), product.Name), "unlock")
	end

	-- Save right away. If saving is switched off (Studio without API access),
	-- there's nothing to wait for.
	if PlayerData.isSaving(player) and not PlayerData.save(player, data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- 🏆 Milestone badges ---------------------------------------------------------------

local function giveRobloxBadge(player: Player, badgeId: number)
	if badgeId == 0 then
		return -- not set up on the Creator Dashboard yet
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				BadgeService:AwardBadge(player.UserId, badgeId)
			end
		end)
		if not ok then
			warn("[Rewards] Couldn't award badge " .. badgeId .. ":", err)
		end
	end)
end

local seen = {} -- [Player] = { Data = the save table we're watching, Cash = cash last check }

local function checkMilestones(player: Player, session)
	local data = session.Data
	data.Milestones = data.Milestones or {}
	data.TotalEarned = data.TotalEarned or 0

	-- Count cash going UP as earnings (spending isn't subtracted)
	local last = seen[player]
	if not last and data.TotalEarned < data.Cash then
		data.TotalEarned = data.Cash -- older saves: count the cash they already have
	end
	if last and last.Data == data then
		local gained = data.Cash - last.Cash
		if gained > 0 then
			data.TotalEarned += gained
		end
	end
	seen[player] = { Data = data, Cash = data.Cash }

	for _, milestone in RewardsConfig.Milestones do
		if not data.Milestones[milestone.Key] and data.TotalEarned >= milestone.Earned then
			data.Milestones[milestone.Key] = true
			giveRobloxBadge(player, milestone.BadgeId)
			if milestoneEvent then
				milestoneEvent:FireClient(player, milestone.Key)
			end
		end
	end
end

-- Public API ----------------------------------------------------------------

function Rewards.init(tycoonModule, remote: RemoteEvent)
	Tycoon = tycoonModule
	notifyEvent = remote

	MarketplaceService.ProcessReceipt = processReceipt

	milestoneEvent = Instance.new("RemoteEvent")
	milestoneEvent.Name = "MilestoneUnlocked"
	milestoneEvent.Parent = ReplicatedStorage

	-- Every couple of seconds: add up earnings and unlock milestones
	task.spawn(function()
		while true do
			task.wait(2)
			for player, session in Tycoon.getSessions() do
				local ok, err = pcall(checkMilestones, player, session)
				if not ok then
					warn("[Rewards] Milestone check failed:", err)
				end
			end
		end
	end)

	-- Hand out real badges they unlocked before the badge IDs were set up
	Players.PlayerAdded:Connect(function(player)
		task.delay(15, function()
			local session = player.Parent and Tycoon.getSession(player)
			if session then
				for _, milestone in RewardsConfig.Milestones do
					if (session.Data.Milestones or {})[milestone.Key] then
						giveRobloxBadge(player, milestone.BadgeId)
					end
				end
			end
		end)
	end)

	local request = Instance.new("RemoteFunction")
	request.Name = "RewardsRequest"
	request.Parent = ReplicatedStorage

	local lastRequest = {}
	request.OnServerInvoke = function(player, action)
		local session = Tycoon.getSession(player)
		if not session then
			return { Ok = false, NoLot = true, Message = "Claim a lot first!" }
		end
		local now = os.clock()
		if action ~= "status" and lastRequest[player] and now - lastRequest[player] < 1 then
			return { Ok = false, Message = "Slow down!" }
		end
		local ok, result = pcall(function()
			if action == "status" then
				return status(session)
			end
			lastRequest[player] = now
			if action == "spin" then
				return spin(player, session)
			elseif action == "daily" then
				return claimDaily(player, session)
			end
			return { Ok = false, Message = "Unknown action." }
		end)
		if ok then
			return result
		end
		warn("[Rewards] Request failed:", result)
		return { Ok = false, Message = "Something went wrong. Try again." }
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		seen[player] = nil
		spinsThisVisit[player] = nil
		nextSpinAt[player] = nil
	end)
end

return Rewards
