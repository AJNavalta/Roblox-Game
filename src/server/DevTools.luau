--[[
	DevTools.luau
	A testing cheat: free money, but ONLY for the game's developer.

	Who can use it:
	  * the Roblox accounts listed in DEVELOPERS below, and
	  * anyone in a Roblox Studio test (Play / Clients and Servers), since
	    that's only ever you.
	Everyone else gets nothing, even if they type the command. The server
	checks every request, so it can't be faked from a player's computer.

	How to use it:
	  * Type in chat:  /money 1m   (also works with 500, 25k, 2.5b ...)
	  * Or click the "+$1M" / "+$1B" buttons that appear for developers
	    under the cash bar (see Hud.client.luau).
	The money goes straight into your cash.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Format = require(ReplicatedStorage.Shared.Format)

local DevTools = {}

-- Roblox usernames allowed to use the money cheat. Add friends who help test here.
local DEVELOPERS = { "Monsky" }

local MAX_PER_USE = 1e12 -- the most you can add in one go ($1 trillion)
local BUTTON_AMOUNTS = { [1_000_000] = true, [1_000_000_000] = true }

local Tycoon = nil
local notifyEvent: RemoteEvent? = nil
local developerIds: { [number]: boolean } = {}

local function notify(player: Player, text: string, kind: string)
	if notifyEvent then
		notifyEvent:FireClient(player, text, kind)
	end
end

local function isDeveloper(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if developerIds[player.UserId] then
		return true
	end
	for _, name in DEVELOPERS do
		if player.Name:lower() == name:lower() then
			return true
		end
	end
	return false
end

-- "1m" -> 1000000, "2.5k" -> 2500, "500" -> 500
local SUFFIXES = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
local function parseAmount(text: string?): number?
	if type(text) ~= "string" then
		return nil
	end
	local number, suffix = text:lower():match("^%s*%$?([%d%.]+)%s*([kmbt]?)%s*$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	if suffix and suffix ~= "" then
		value *= SUFFIXES[suffix]
	end
	return math.floor(value)
end

local lastUse: { [Player]: number } = {}

local function giveMoney(player: Player, amount: number?)
	if not isDeveloper(player) then
		return -- not allowed: say nothing
	end
	if not amount or amount < 1 or amount ~= amount then
		notify(player, "Try: /money 1m", "error")
		return
	end
	-- The chat command can arrive twice in some chat setups; ignore the echo
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < 0.3 then
		return
	end
	lastUse[player] = now

	if not Tycoon.getSession(player) then
		notify(player, "Pick a save and claim a lot first, then try again.", "error")
		return
	end
	amount = math.min(amount, MAX_PER_USE)
	Tycoon.changeCash(player, amount)
	notify(player, "🛠️ Dev money: +" .. Format.money(amount), "cash")
end

local function handleChat(player: Player, message: string)
	local amountText = message:match("^/money%s+(.+)$") or message:match("^/cash%s+(.+)$")
	if amountText then
		giveMoney(player, parseAmount(amountText))
	end
end

function DevTools.init(tycoon, remote: RemoteEvent)
	Tycoon = tycoon
	notifyEvent = remote

	-- Look up the developers' account ids, so it keeps working if they rename
	task.spawn(function()
		for _, name in DEVELOPERS do
			local ok, userId = pcall(function()
				return Players:GetUserIdFromNameAsync(name)
			end)
			if ok and userId then
				developerIds[userId] = true
			end
		end
	end)

	-- The dev buttons under the cash bar
	local devRequest = Instance.new("RemoteEvent")
	devRequest.Name = "DevRequest"
	devRequest.OnServerEvent:Connect(function(player, action, amount)
		if action == "money" and type(amount) == "number" and BUTTON_AMOUNTS[amount] then
			giveMoney(player, amount)
		end
	end)
	devRequest.Parent = ReplicatedStorage

	-- Chat command: new chat (TextChatService) ...
	local command = Instance.new("TextChatCommand")
	command.Name = "DevMoneyCommand"
	command.PrimaryAlias = "/money"
	command.SecondaryAlias = "/cash"
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			handleChat(player, text)
		end
	end)
	command.Parent = TextChatService

	-- ... and old chat, just in case
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			handleChat(player, message)
		end)
		-- Tells this player's screen to show the dev buttons
		task.delay(3, function()
			if player.Parent and isDeveloper(player) then
				player:SetAttribute("IsDeveloper", true)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return DevTools
