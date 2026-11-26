--[[
	RewardsConfig.luau
	==================
	Settings for the three buttons on the left side of the screen:
	  🎡 Spin          free prize wheel spins, waits grow 1 → 30 min
	  🎁 Daily Reward  come back every day for a bigger reward (7-day streak)
	  💰 Cash Shop     buy cash with Robux (Developer Products)

	Rewards grow as you grow. Most of them are "X minutes of your income"
	plus a bit for every upgrade level you own, so they're useful at
	$10/s and at $1M/s.
	  upgrades = total levels of everything you've bought on your lot
	  reward   = income per second * Seconds + upgrades * PerUpgrade
	  (never less than Min)
]]

local RewardsConfig = {}

-- 🎡 Hourly spin ----------------------------------------------------------------
-- Wait after each spin, in minutes. The 1st spin is free right away, then
-- 1 min, 2, 5, 10, 15, then 30 min for every spin after that (the last
-- number repeats). It starts over each time the player joins the game.
RewardsConfig.SpinCooldowns = { 1, 2, 5, 10, 15, 30 }

function RewardsConfig.spinCooldown(spinsSoFar: number): number
	local list = RewardsConfig.SpinCooldowns
	return list[math.clamp(spinsSoFar, 1, #list)] * 60 -- seconds
end

-- The wheel's slices, clockwise from the top. Weight = how likely it is
-- (bigger = more common). They don't need to add up to anything.
RewardsConfig.SpinPrizes = {
	{ Name = "Small Cash", Seconds = 60, PerUpgrade = 40, Min = 50, Weight = 30, Color = Color3.fromRGB(90, 160, 255) },
	{ Name = "Cash", Seconds = 180, PerUpgrade = 80, Min = 120, Weight = 24, Color = Color3.fromRGB(80, 200, 120) },
	{ Name = "Small Cash", Seconds = 60, PerUpgrade = 40, Min = 50, Weight = 30, Color = Color3.fromRGB(90, 160, 255) },
	{ Name = "Big Cash", Seconds = 600, PerUpgrade = 200, Min = 400, Weight = 12, Color = Color3.fromRGB(255, 170, 40) },
	{ Name = "Cash", Seconds = 180, PerUpgrade = 80, Min = 120, Weight = 24, Color = Color3.fromRGB(80, 200, 120) },
	{ Name = "Mega Cash", Seconds = 1800, PerUpgrade = 500, Min = 1_000, Weight = 6, Color = Color3.fromRGB(200, 80, 220) },
	{ Name = "Cash", Seconds = 180, PerUpgrade = 80, Min = 120, Weight = 24, Color = Color3.fromRGB(80, 200, 120) },
	{ Name = "JACKPOT", Seconds = 7200, PerUpgrade = 2_000, Min = 5_000, Weight = 2, Color = Color3.fromRGB(255, 215, 0) },
}

-- 🎁 Daily reward ----------------------------------------------------------------
RewardsConfig.DailyCooldown = 20 * 60 * 60 -- can claim again 20 hours after the last claim
RewardsConfig.DailyStreakWindow = 48 * 60 * 60 -- miss more than this and the streak starts over
RewardsConfig.DailyBase = { Seconds = 300, PerUpgrade = 100, Min = 100 } -- day 1's reward
RewardsConfig.DailyMultipliers = { 1, 1.5, 2, 3, 4, 5, 10 } -- day 1..7 (day 7+ stays at the last one)

-- 💰 Cash shop (Robux) ------------------------------------------------------------
--[[
	These are Developer Products. Roblox only sells them after YOU create
	them on the Creator Dashboard and paste their IDs here:
	  1. Publish the game (File > Publish to Roblox).
	  2. Go to create.roblox.com > Creations > your game > Monetization >
	     Developer Products > Create a Developer Product.
	  3. Give it a name and a Robux price, save, and copy its Product ID.
	  4. Paste the ID below in place of the 0.
	A product with ProductId = 0 shows "Coming soon" and can't be bought.

	Cash given = income per second * Seconds (never less than Min), worked
	out when they buy, so it's always worth it.
]]
RewardsConfig.Products = {
	{ ProductId = 0, Name = "Bag of Cash", Emoji = "💵", Robux = 25, Seconds = 15 * 60, Min = 1_000 },
	{ ProductId = 0, Name = "Briefcase of Cash", Emoji = "💼", Robux = 75, Seconds = 60 * 60, Min = 5_000 },
	{ ProductId = 0, Name = "Vault of Cash", Emoji = "🏦", Robux = 199, Seconds = 4 * 60 * 60, Min = 25_000 },
	{ ProductId = 0, Name = "Billionaire Stack", Emoji = "💎", Robux = 499, Seconds = 12 * 60 * 60, Min = 100_000 },
}

-- 🏆 Milestone badges -------------------------------------------------------------
--[[
	Unlocked by total cash EARNED (spending doesn't count against you).
	They always show in the in-game 🏆 Badges panel. To also give players
	a real Roblox badge (shows on their profile):
	  1. Publish the game.
	  2. create.roblox.com > Creations > your game > Associated Items >
	     Badges > Create a Badge. Upload a square image, name it, Create.
	     (Roblox lets you make a few badges free each day; after that each
	     one costs Robux. Check the page for the current numbers.)
	  3. Copy the Badge ID and paste it below in place of the 0.
	Keep each Key the same forever: it's what's saved.
]]
RewardsConfig.Milestones = {
	{ Key = "start", Name = "Getting Started", Emoji = "🍋", Earned = 0, BadgeId = 0, Text = "Claim your first lot" },
	{ Key = "1k", Name = "First Thousand", Emoji = "💵", Earned = 1_000, BadgeId = 0 },
	{ Key = "10k", Name = "Ten Grand", Emoji = "💸", Earned = 10_000, BadgeId = 0 },
	{ Key = "100k", Name = "Six Figures", Emoji = "💰", Earned = 100_000, BadgeId = 0 },
	{ Key = "500k", Name = "Half a Million", Emoji = "🏦", Earned = 500_000, BadgeId = 0 },
	{ Key = "1m", Name = "Millionaire", Emoji = "🎩", Earned = 1_000_000, BadgeId = 0 },
	{ Key = "10m", Name = "Multi-Millionaire", Emoji = "🛥️", Earned = 10_000_000, BadgeId = 0 },
	{ Key = "100m", Name = "Hundred Millionaire", Emoji = "🏝️", Earned = 100_000_000, BadgeId = 0 },
	{ Key = "500m", Name = "Half a Billion", Emoji = "🚁", Earned = 500_000_000, BadgeId = 0 },
	{ Key = "1b", Name = "BILLIONAIRE", Emoji = "👑", Earned = 1_000_000_000, BadgeId = 0 },
}

-- Works out a "minutes of income + upgrades" reward
function RewardsConfig.amount(reward, incomePerSecond: number, upgrades: number, multiplier: number?): number
	local value = incomePerSecond * (reward.Seconds or 0) + upgrades * (reward.PerUpgrade or 0)
	value = math.max(value, reward.Min or 0) * (multiplier or 1)
	return math.floor(value)
end

function RewardsConfig.dailyMultiplier(day: number): number
	local list = RewardsConfig.DailyMultipliers
	return list[math.clamp(day, 1, #list)]
end

return RewardsConfig
