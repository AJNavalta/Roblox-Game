--[[
	Tutorial.luau
	The server side of the how-to-play tutorial (the steps and arrows are in
	src/client/Tutorial.client.luau).

	It only remembers whether you've finished (or skipped) the tutorial, per
	save file, and tells your screen through the "TutorialDone" attribute.
	New saves start with the tutorial. Saves that already bought something
	count as done, so experienced players aren't sent back to the start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = {}

local dataOf: { [Player]: any } = {}

-- Main calls this whenever a save file is loaded for a player
function Tutorial.onLoaded(player: Player, data)
	dataOf[player] = data
	player:SetAttribute("TutorialDone", data.TutorialDone == true)
end

function Tutorial.init()
	local request = Instance.new("RemoteEvent")
	request.Name = "TutorialRequest"
	request.OnServerEvent:Connect(function(player, action)
		local data = dataOf[player]
		if not data then
			return
		end
		if action == "done" then
			data.TutorialDone = true
			player:SetAttribute("TutorialDone", true)
		elseif action == "restart" then
			data.TutorialDone = false
			player:SetAttribute("TutorialDone", false)
		end
	end)
	request.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		dataOf[player] = nil
	end)
end

return Tutorial
