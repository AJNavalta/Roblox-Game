--[[
	PlayerData.luau
	Loads and saves each player's progress with DataStoreService.

	Testing in Studio? Saving only works when:
	  1. the place is published to Roblox (File > Publish to Roblox), and
	  2. Game Settings > Security > "Enable Studio Access to API Services" is ON.
	If either is missing, the game still runs, it just won't remember you.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MarketConfig = require(ReplicatedStorage.Shared.MarketConfig)

local PlayerData = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable, progress won't save:", result)
	end
end

-- Players whose data loaded correctly. We never save for anyone else, so a
-- hiccup while loading can't wipe out their real save with a blank one.
local canSave: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function defaultData()
	return {
		Cash = Config.StartingCash,
		Pending = 0,
		Owned = {},
		Billionaire = false,
		Portfolio = {}, -- stocks, crypto and NFTs: [assetId] = { Shares, Cost }
	}
end

-- Never trust what comes out of storage blindly: fill in anything missing
-- and drop items that no longer exist in Config.
local function sanitize(raw)
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.Cash) == "number" then
		data.Cash = math.max(0, raw.Cash)
	end
	if type(raw.Pending) == "number" then
		data.Pending = math.max(0, raw.Pending)
	end
	if type(raw.Owned) == "table" then
		for itemId, level in raw.Owned do
			local info = Config.ItemsById[itemId]
			if info then
				-- Older saves stored `true` instead of a level number
				if level == true then
					level = 1
				end
				if type(level) == "number" and level >= 1 then
					data.Owned[itemId] = math.min(math.floor(level), info.Item.MaxLevel or 1)
				end
			end
		end
	end
	data.Billionaire = raw.Billionaire == true
	if type(raw.Portfolio) == "table" then
		for assetId, holding in raw.Portfolio do
			if MarketConfig.AssetsById[assetId] and type(holding) == "table"
				and type(holding.Shares) == "number" and holding.Shares > 0 and holding.Shares < math.huge
			then
				local cost = if type(holding.Cost) == "number" and holding.Cost >= 0 then holding.Cost else 0
				data.Portfolio[assetId] = { Shares = holding.Shares, Cost = cost }
			end
		end
	end
	return data
end

function PlayerData.load(player: Player)
	if not store then
		canSave[player] = false
		return defaultData()
	end

	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			canSave[player] = true
			return sanitize(result)
		end
		warn(("[PlayerData] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end

	canSave[player] = false
	warn("[PlayerData] Giving up loading " .. player.Name .. "; this session won't be saved.")
	return defaultData()
end

function PlayerData.isSaving(player: Player): boolean
	return canSave[player] == true
end

function PlayerData.save(player: Player, data): boolean
	if not store or not canSave[player] then
		return false
	end

	local payload = {
		Cash = data.Cash,
		Pending = data.Pending,
		Owned = data.Owned,
		Billionaire = data.Billionaire,
		Portfolio = data.Portfolio,
	}

	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), payload, { player.UserId })
	end)
	if not ok then
		warn("[PlayerData] Save failed for " .. player.Name .. ":", err)
	end
	return ok
end

function PlayerData.forget(player: Player)
	canSave[player] = nil
end

return PlayerData
