--[[
	Hud.client.luau
	The on-screen display: cash, income per second, current business,
	a "road to $1B" bar, and pop-up messages from the server.

	This script only SHOWS numbers. All money changes happen on the server
	(see src/server/Tycoon.luau).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local player = Players.LocalPlayer

-- Build the UI --------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function textLabel(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		label[key] = value
	end
	return label
end

local panel = Instance.new("Frame")
panel.Name = "Stats"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 8)
panel.Size = UDim2.fromOffset(320, 118)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
panel.BackgroundTransparency = 0.15
panel.Parent = gui
corner(panel, 12)

local cashLabel = textLabel({
	Name = "Cash",
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 40),
	TextColor3 = Color3.fromRGB(120, 255, 140),
	Text = "$0",
	Parent = panel,
})

local incomeLabel = textLabel({
	Name = "Income",
	Position = UDim2.fromOffset(12, 48),
	Size = UDim2.new(1, -24, 0, 18),
	Font = Enum.Font.Gotham,
	Text = "+$0/s",
	Parent = panel,
})

local stageLabel = textLabel({
	Name = "Stage",
	Position = UDim2.fromOffset(12, 68),
	Size = UDim2.new(1, -24, 0, 18),
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(255, 230, 120),
	Text = "",
	Parent = panel,
})

local barBack = Instance.new("Frame")
barBack.Name = "GoalBar"
barBack.Position = UDim2.fromOffset(12, 92)
barBack.Size = UDim2.new(1, -24, 0, 16)
barBack.BackgroundColor3 = Color3.fromRGB(50, 52, 62)
barBack.Parent = panel
corner(barBack, 8)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
barFill.Parent = barBack
corner(barFill, 8)

textLabel({
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	Text = "Road to " .. Format.money(Config.BillionaireGoal),
	ZIndex = 2,
	Parent = barBack,
})

-- Pop-up messages stack at the bottom of the screen
local toastArea = Instance.new("Frame")
toastArea.Name = "Toasts"
toastArea.AnchorPoint = Vector2.new(0.5, 1)
toastArea.Position = UDim2.new(0.5, 0, 1, -110)
toastArea.Size = UDim2.fromOffset(420, 200)
toastArea.BackgroundTransparency = 1
toastArea.Parent = gui

local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastArea

gui.Parent = player:WaitForChild("PlayerGui")

-- Keep it up to date --------------------------------------------------------

local function getCash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function update()
	local cash = getCash()
	local income = player:GetAttribute("Income") or 0
	local pending = player:GetAttribute("Pending") or 0
	local stageIndex = player:GetAttribute("StageIndex") or 1
	local stageName = player:GetAttribute("StageName") or Config.Stages[1].Name

	cashLabel.Text = Format.money(cash)
	incomeLabel.Text = ("+%s/s   ·   %s waiting at your collector"):format(Format.money(income), Format.money(pending))
	if player:GetAttribute("HasLot") then
		stageLabel.Text = ("Business %d/%d: %s"):format(stageIndex, #Config.Stages, stageName)
	else
		stageLabel.Text = "Step on a blue FOR SALE pad to claim a lot!"
	end

	-- Log scale so the bar moves early on instead of sitting at 0% for ages
	local progress = math.clamp(math.log10(cash + 1) / math.log10(Config.BillionaireGoal), 0, 1)
	barFill.Size = UDim2.fromScale(progress, 1)
end

for _, attribute in { "Income", "Pending", "StageIndex", "StageName", "HasLot" } do
	player:GetAttributeChangedSignal(attribute):Connect(update)
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	cash.Changed:Connect(update)
	update()
end)
update()

-- Pop-ups -------------------------------------------------------------------

local TOAST_COLORS = {
	info = Color3.fromRGB(60, 64, 80),
	success = Color3.fromRGB(40, 140, 70),
	cash = Color3.fromRGB(150, 120, 20),
	unlock = Color3.fromRGB(120, 60, 200),
	error = Color3.fromRGB(170, 50, 50),
}

local toastCount = 0

local function showToast(text: string, kind: string)
	toastCount += 1
	local toast = textLabel({
		Size = UDim2.fromOffset(400, 34),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
		Font = Enum.Font.GothamBold,
		Text = text,
		LayoutOrder = toastCount,
		Parent = toastArea,
	})
	corner(toast, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = toast

	task.delay(3, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.5)
		toast:Destroy()
	end)
end

local notifyEvent = ReplicatedStorage:WaitForChild("TycoonNotify")
notifyEvent.OnClientEvent:Connect(showToast)
