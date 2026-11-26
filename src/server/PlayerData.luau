--[[
	PlayerData.luau
	Loads and saves each player's progress with DataStoreService.

	Testing in Studio? Saving only works when:
	  1. the place is published to Roblox (File > Publish to Roblox), and
	  2. Game Settings > Security > "Enable Studio Access to API Services" is ON.
	If either is missing, the game still runs, it just won't remember you.

	Save slots: every player has PlayerData.SLOT_COUNT separate save files.
	Slot 1 uses the same key as before slots existed, so old saves show up
	there.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HomeConfig = require(ReplicatedStorage.Shared.HomeConfig)
local MarketConfig = require(ReplicatedStorage.Shared.MarketConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.VehicleConfig)

local PlayerData = {}

PlayerData.SLOT_COUNT = 3

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
local slotOf: { [Player]: number } = {} -- which save slot each player is playing

local function keyFor(player: Player, slot: number): string
	if slot == 1 then
		return "player_" .. player.UserId -- the original key, so old saves land in slot 1
	end
	return "player_" .. player.UserId .. "_slot" .. slot
end

local function defaultData()
	return {
		Cash = Config.StartingCash,
		Pending = 0,
		Owned = {},
		Billionaire = false,
		Portfolio = {}, -- stocks, crypto and NFTs: [assetId] = { Shares, Cost }
		Vehicles = {}, -- cars bought in the phone: [vehicleId] = true
		Home = HomeConfig.StartingHome, -- the home you live in (see HomeConfig)
		Homes = { [HomeConfig.StartingHome] = true }, -- homes you own: [homeId] = true
		LastSpin = 0, -- 🎡 os.time() of the last hourly spin (see Rewards.luau)
		LastDaily = 0, -- 🎁 os.time() of the last daily reward
		DailyStreak = 0, -- 🎁 days in a row
		Receipts = {}, -- 💰 Robux purchase IDs already paid out
		TotalEarned = 0, -- 🏆 all cash ever earned (for milestone badges)
		Milestones = {}, -- 🏆 badges unlocked: [key] = true
		TutorialDone = false, -- finished or skipped the how-to-play tutorial
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
	-- Older saves that already bought something don't need the tutorial
	data.TutorialDone = raw.TutorialDone == true or next(data.Owned) ~= nil
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
	if type(raw.Homes) == "table" then
		for homeId, owned in raw.Homes do
			if HomeConfig.HomesById[homeId] and owned == true then
				data.Homes[homeId] = true
			end
		end
	end
	if type(raw.Home) == "string" and data.Homes[raw.Home] then
		data.Home = raw.Home
	end
	if type(raw.Milestones) == "table" then
		for key, unlocked in raw.Milestones do
			if type(key) == "string" and unlocked == true then
				data.Milestones[key] = true
			end
		end
	end
	for _, field in { "LastSpin", "LastDaily", "DailyStreak", "TotalEarned" } do
		local value = raw[field]
		if type(value) == "number" and value == value and value >= 0 and value < math.huge then
			data[field] = math.floor(value)
		end
	end
	if type(raw.Receipts) == "table" then
		for _, purchaseId in raw.Receipts do
			if type(purchaseId) == "string" then
				table.insert(data.Receipts, purchaseId)
			end
		end
	end
	if type(raw.Vehicles) == "table" then
		for vehicleId, owned in raw.Vehicles do
			if VehicleConfig.ById[vehicleId] and owned == true then
				data.Vehicles[vehicleId] = true
			end
		end
	end
	return data
end

-- A quick look at every save slot, for the "choose a save" screen.
-- Returns { [slot] = data or false (empty) }, or nil if saving is off.
function PlayerData.peek(player: Player)
	if not store then
		return nil
	end
	local slots = {}
	for slot = 1, PlayerData.SLOT_COUNT do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player, slot))
		end)
		slots[slot] = if ok and result ~= nil then sanitize(result) else false
	end
	return slots
end

function PlayerData.getSlot(player: Player): number?
	return slotOf[player]
end

function PlayerData.load(player: Player, slot: number)
	slotOf[player] = slot
	if not store then
		canSave[player] = false
		return defaultData()
	end

	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player, slot))
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
	local slot = slotOf[player]
	if not store or not canSave[player] or not slot then
		return false
	end

	local payload = {
		Cash = data.Cash,
		Pending = data.Pending,
		Owned = data.Owned,
		Billionaire = data.Billionaire,
		Portfolio = data.Portfolio,
		Vehicles = data.Vehicles,
		Home = data.Home,
		Homes = data.Homes,
		LastSpin = data.LastSpin,
		LastDaily = data.LastDaily,
		DailyStreak = data.DailyStreak,
		Receipts = data.Receipts,
		TotalEarned = data.TotalEarned,
		Milestones = data.Milestones,
		TutorialDone = data.TutorialDone,
	}

	local ok, err = pcall(function()
		store:SetAsync(keyFor(player, slot), payload, { player.UserId })
	end)
	if not ok then
		warn("[PlayerData] Save failed for " .. player.Name .. ":", err)
	end
	return ok
end

function PlayerData.forget(player: Player)
	canSave[player] = nil
	slotOf[player] = nil
end

return PlayerData
