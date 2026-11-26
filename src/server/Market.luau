--[[
	Market.luau
	The stock market, crypto and NFTs from the phone.

	The server owns everything here:
	  * it moves the prices (players can't fake a price),
	  * it checks every buy and sell against the player's real cash,
	  * holdings live in the player's save as data.Portfolio:
	        Portfolio["SQZY"] = { Shares = 12.5, Cost = 150 }
	    Shares = how much they own, Cost = dollars they paid for it
	    (used to show profit or loss).

	Talking to the phone (both live in ReplicatedStorage):
	  MarketRequest  RemoteFunction  client asks: "snapshot", "buy", "sell"
	  MarketPrices   RemoteEvent     server tells everyone the new prices
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketConfig = require(ReplicatedStorage.Shared.MarketConfig)

local Market = {}

local Tycoon = nil -- set in Market.init (passed in to avoid a require loop)
local notifyEvent: RemoteEvent? = nil

local prices: { [string]: number } = {}
local history: { [string]: { number } } = {}
local lastTrade: { [Player]: number } = {}

local TRADE_COOLDOWN = 0.15 -- seconds between trades, stops spam
local DUST = 1e-9 -- holdings smaller than this count as zero

-- Prices --------------------------------------------------------------------

-- A random number from a bell curve (most steps small, a few big).
local rng = Random.new()
local function gaussian(): number
	local u1 = math.max(rng:NextNumber(), 1e-12)
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function pushHistory(id: string, price: number)
	local list = history[id]
	table.insert(list, price)
	if #list > MarketConfig.HistoryLength then
		table.remove(list, 1)
	end
end

local function startPrices()
	for _, asset in MarketConfig.AssetList do
		-- Start each server somewhere near the Base price, so it feels different each time
		local price = asset.Base * math.exp(gaussian() * asset.Vol * 4)
		prices[asset.Id] = price
		history[asset.Id] = {}
		-- Fill the chart with some made-up recent history so it's not empty at first
		local back = price
		local fake = {}
		for _ = 1, MarketConfig.HistoryLength - 1 do
			table.insert(fake, 1, back)
			back *= math.exp(gaussian() * asset.Vol)
		end
		for _, p in fake do
			pushHistory(asset.Id, p)
		end
		pushHistory(asset.Id, price)
	end
end

local function announce(text: string)
	if notifyEvent then
		for _, player in Players:GetPlayers() do
			notifyEvent:FireClient(player, text, "info")
		end
	end
end

local function step()
	for _, asset in MarketConfig.AssetList do
		local id = asset.Id
		local logPrice = math.log(prices[id])
		local logBase = math.log(asset.Base)

		-- Random wiggle + gentle pull back toward the normal price
		logPrice += MarketConfig.PullBack * (logBase - logPrice) + asset.Vol * gaussian()

		-- Breaking news!
		if rng:NextNumber() < MarketConfig.NewsChance then
			local jump = rng:NextNumber(0.15, 0.45)
			if rng:NextNumber() < 0.5 then
				logPrice += math.log(1 + jump)
				announce(("📰 %s soars %d%%!"):format(asset.Name, math.floor(jump * 100)))
			else
				logPrice += math.log(1 - jump * 0.7)
				announce(("📰 %s crashes %d%%!"):format(asset.Name, math.floor(jump * 70)))
			end
		end

		local price = math.exp(logPrice)
		price = math.clamp(price, asset.Base * MarketConfig.MinMultiplier, asset.Base * MarketConfig.MaxMultiplier)
		prices[id] = price
		pushHistory(id, price)
	end
end

-- Helpers -------------------------------------------------------------------

local function portfolioOf(data)
	if type(data.Portfolio) ~= "table" then
		data.Portfolio = {}
	end
	return data.Portfolio
end

-- Copy of the portfolio that's safe to send to the client
local function portfolioSnapshot(data)
	local copy = {}
	for id, holding in portfolioOf(data) do
		copy[id] = { Shares = holding.Shares, Cost = holding.Cost }
	end
	return copy
end

local function isGoodNumber(value): boolean
	return type(value) == "number" and value == value and value > 0 -- value == value is false for NaN
end

-- Trading -------------------------------------------------------------------

local function buy(player: Player, session, asset, amount: number)
	local data = session.Data
	local price = prices[asset.Id]
	local shares, cost

	if asset.Kind == "whole" then
		local count = math.floor(amount)
		if count < 1 then
			return false, "Pick how many to buy."
		end
		local affordable = math.floor(data.Cash / price)
		count = math.min(count, affordable)
		if count < 1 then
			return false, "You need " .. MarketConfig.formatPrice(price) .. " to buy one."
		end
		shares, cost = count, count * price
	else
		cost = math.min(math.floor(amount), math.floor(data.Cash))
		if cost < MarketConfig.MinTrade then
			return false, if data.Cash < MarketConfig.MinTrade then "You don't have any cash to invest." else "Enter an amount to invest."
		end
		shares = cost / price
	end

	local portfolio = portfolioOf(data)
	local holding = portfolio[asset.Id] or { Shares = 0, Cost = 0 }
	holding.Shares += shares
	holding.Cost += cost
	portfolio[asset.Id] = holding

	Tycoon.changeCash(player, -cost)
	if asset.Kind == "whole" then
		return true, ("Bought %d %s for %s"):format(shares, asset.Name, MarketConfig.formatPrice(cost))
	end
	return true, ("Invested %s in %s"):format(MarketConfig.formatPrice(cost), asset.Name)
end

-- amount = dollars to sell (fractional) or how many to sell (whole), or "all"
local function sell(player: Player, session, asset, amount)
	local data = session.Data
	local portfolio = portfolioOf(data)
	local holding = portfolio[asset.Id]
	if not holding or holding.Shares <= DUST then
		return false, "You don't own any " .. asset.Name .. "."
	end

	local price = prices[asset.Id]
	local shares
	if amount == "all" then
		shares = holding.Shares
	elseif asset.Kind == "whole" then
		shares = math.min(math.floor(amount), holding.Shares)
	else
		shares = math.min(amount / price, holding.Shares)
	end
	if shares <= 0 then
		return false, "Enter an amount to sell."
	end

	local fraction = shares / holding.Shares
	local proceeds = shares * price
	holding.Cost -= holding.Cost * fraction
	holding.Shares -= shares
	if holding.Shares * price < 0.01 or holding.Shares <= DUST then
		portfolio[asset.Id] = nil -- sold everything (or just crumbs left)
	end

	Tycoon.changeCash(player, proceeds)
	return true, ("Sold %s for %s"):format(asset.Name, MarketConfig.formatPrice(proceeds))
end

local function handleRequest(player: Player, action, assetId, amount)
	if action == "snapshot" then
		local session = Tycoon.getSession(player)
		return {
			Prices = prices,
			History = history,
			Portfolio = if session then portfolioSnapshot(session.Data) else {},
			Interval = MarketConfig.TickInterval,
		}
	end

	if action ~= "buy" and action ~= "sell" then
		return { Ok = false, Message = "Unknown action." }
	end

	local session = Tycoon.getSession(player)
	if not session then
		return { Ok = false, Message = "Claim a lot first, then you can invest." }
	end

	local asset = type(assetId) == "string" and MarketConfig.AssetsById[assetId]
	if not asset then
		return { Ok = false, Message = "That doesn't exist." }
	end
	if not (amount == "all" and action == "sell") and not isGoodNumber(amount) then
		return { Ok = false, Message = "Enter an amount." }
	end

	local now = os.clock()
	if lastTrade[player] and now - lastTrade[player] < TRADE_COOLDOWN then
		return { Ok = false, Message = "Slow down!" }
	end
	lastTrade[player] = now

	local ok, message
	if action == "buy" then
		ok, message = buy(player, session, asset, amount)
	else
		ok, message = sell(player, session, asset, amount)
	end
	return { Ok = ok, Message = message, Portfolio = portfolioSnapshot(session.Data) }
end

-- Public API ----------------------------------------------------------------

-- Total value of everything a player owns in the market, at today's prices.
function Market.portfolioValue(data): number
	local total = 0
	for id, holding in portfolioOf(data) do
		local price = prices[id]
		if price then
			total += holding.Shares * price
		end
	end
	return total
end

function Market.init(tycoonModule, remote: RemoteEvent)
	Tycoon = tycoonModule
	notifyEvent = remote

	local request = Instance.new("RemoteFunction")
	request.Name = "MarketRequest"
	request.Parent = ReplicatedStorage

	local pricesEvent = Instance.new("RemoteEvent")
	pricesEvent.Name = "MarketPrices"
	pricesEvent.Parent = ReplicatedStorage

	startPrices()

	request.OnServerInvoke = function(player, action, assetId, amount)
		local ok, result = pcall(handleRequest, player, action, assetId, amount)
		if ok then
			return result
		end
		warn("[Market] Request failed:", result)
		return { Ok = false, Message = "Something went wrong. Try again." }
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTrade[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(MarketConfig.TickInterval)
			step()
			pricesEvent:FireAllClients(prices)
		end
	end)
end

return Market
