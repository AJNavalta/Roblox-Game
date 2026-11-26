--[[
	Progression.luau
	The rules for "what can I buy right now, and how much do I earn?".
	Pure functions with no Roblox objects, so both the server and the HUD
	can use them, and they're easy to test.

	`owned` is always a table of { [itemId] = level }, e.g.
	  { lemon_pitcher = 3, lemon_table = 1 }
]]

local Config = require(script.Parent.Config)

local Progression = {}

function Progression.level(owned, itemId: string): number
	return owned[itemId] or 0
end

function Progression.maxLevel(item): number
	return item.MaxLevel or 1
end

-- Price of the NEXT level, given the level you have now (0 = not owned yet).
function Progression.nextCost(item, currentLevel: number): number
	if currentLevel <= 0 then
		return item.Cost
	end
	local multiplier = Config.UpgradeCostMultiplier
	local levelTwoCost = item.UpgradeCost or (item.Cost * multiplier)
	return math.floor(levelTwoCost * multiplier ^ (currentLevel - 1))
end

-- How many different items in this stage you own (any level).
function Progression.ownedCount(owned, stage): number
	local count = 0
	for _, item in stage.Items do
		if (owned[item.Id] or 0) > 0 then
			count += 1
		end
	end
	return count
end

-- Returns unlocked, have, need. `have`/`need` describe the unlock goal.
function Progression.stageUnlock(owned, stageIndex: number): (boolean, number, number)
	local stage = Config.Stages[stageIndex]
	local rule = stage.Unlock
	if not rule then
		return true, 0, 0
	end
	local fromIndex = Config.StageIndexById[rule.Stage]
	-- The stage you unlock from has to be unlocked itself, too
	if not Progression.stageUnlock(owned, fromIndex) then
		return false, 0, rule.ItemsOwned
	end
	local have = Progression.ownedCount(owned, Config.Stages[fromIndex])
	return have >= rule.ItemsOwned, have, rule.ItemsOwned
end

function Progression.isStageUnlocked(owned, stageIndex: number): boolean
	return (Progression.stageUnlock(owned, stageIndex))
end

-- The furthest business the player has opened.
function Progression.highestUnlockedStage(owned): number
	local highest = 1
	for index = 1, #Config.Stages do
		if Progression.isStageUnlocked(owned, index) then
			highest = index
		end
	end
	return highest
end

--[[
	What's the state of one item's button? Returns status, detail:
	  "stage_locked"  the business isn't open yet
	  "maxed"         fully bought / upgraded
	  "chosen_other"  you picked another item in its Choice group (detail = that item's Name)
	  "needs"         missing requirements (detail = list of item Names)
	  "available"     can be bought (detail = price)
]]
function Progression.status(owned, info): (string, any)
	local item = info.Item
	if not Progression.isStageUnlocked(owned, info.StageIndex) then
		return "stage_locked", nil
	end

	local level = owned[item.Id] or 0
	if level >= Progression.maxLevel(item) then
		return "maxed", nil
	end

	if item.Choice and level == 0 then
		for _, other in info.Stage.Items do
			if other.Id ~= item.Id and other.Choice == item.Choice and (owned[other.Id] or 0) > 0 then
				return "chosen_other", other.Name
			end
		end
	end

	local missing = {}
	for _, requiredId in item.Requires or {} do
		if (owned[requiredId] or 0) == 0 then
			table.insert(missing, Config.ItemsById[requiredId].Item.Name)
		end
	end
	if #missing > 0 then
		return "needs", missing
	end

	return "available", Progression.nextCost(item, level)
end

-- Income per second from one business, boosts included.
function Progression.stageIncome(owned, stage): number
	local base = 0
	local boost = 1
	for _, item in stage.Items do
		local level = owned[item.Id] or 0
		if level > 0 then
			base += item.Income * level
			if item.Boost then
				boost *= item.Boost
			end
		end
	end
	return base * boost
end

function Progression.totalIncome(owned): number
	local total = 0
	for _, stage in Config.Stages do
		total += Progression.stageIncome(owned, stage)
	end
	return total
end

return Progression
