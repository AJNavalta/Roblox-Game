--[[
	Rewards.client.luau
	The three buttons stacked on the left side of the screen:
	  🎡 Spin    free prize wheel (waits grow 1 → 30 min)
	  🎁 Daily   daily reward with a 7-day streak
	  💰 Shop    buy cash with Robux
	  🏆 Badges  milestone badges for total cash earned

	This script only shows things. The server (src/server/Rewards.luau)
	picks the spin result and hands out all cash. Settings are in
	src/shared/RewardsConfig.luau.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local RewardsConfig = require(Shared:WaitForChild("RewardsConfig"))

local rewardsRequest = ReplicatedStorage:WaitForChild("RewardsRequest") :: RemoteFunction

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BG = Color3.fromRGB(20, 22, 30)
local PANEL = Color3.fromRGB(32, 35, 48)
local TEXT_DIM = Color3.fromRGB(170, 175, 195)
local GREEN = Color3.fromRGB(80, 220, 120)
local RED = Color3.fromRGB(240, 85, 85)
local GOLD = Color3.fromRGB(255, 205, 60)

-- UI helpers ------------------------------------------------------------------

local function make(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return make("TextLabel", props)
end

local function button(props, radius)
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.AutoButtonColor = true
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return make("TextButton", props, { corner(radius or 8) })
end

local function timeText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return ("%dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- Screen ------------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "RewardsGui",
	ResetOnSpawn = false,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Left-side button stack
local stack = make("Frame", {
	Name = "LeftButtons",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(150, 4 * 64 + 3 * 10),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local stackScale = make("UIScale", { Parent = stack })

local function sideButton(order: number, emoji: string, title: string, color: Color3)
	local b = button({
		Size = UDim2.fromOffset(150, 64),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.1,
		Text = "",
		LayoutOrder = order,
		Parent = stack,
	}, 14)
	make("UIStroke", { Color = color, Thickness = 2, Parent = b })
	label({ Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(48, 48), Text = emoji, Parent = b })
	label({
		Position = UDim2.fromOffset(58, 10),
		Size = UDim2.new(1, -64, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = b,
	})
	local sub = label({
		Position = UDim2.fromOffset(58, 34),
		Size = UDim2.new(1, -64, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextColor3 = TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = b,
	})
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = RED,
		Visible = false,
		Parent = b,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return b, sub, dot
end

local spinButton, spinSub, spinDot = sideButton(1, "🎡", "Spin", Color3.fromRGB(90, 160, 255))
local dailyButton, dailySub, dailyDot = sideButton(2, "🎁", "Daily", GREEN)
local shopButton, shopSub = sideButton(3, "💰", "Cash Shop", GOLD)
shopSub.Text = "Buy with R$"
local badgesButton, badgesSub = sideButton(4, "🏆", "Badges", Color3.fromRGB(200, 120, 255))
badgesSub.Text = "Milestones"

-- Shared window frame
local function window(name: string, width: number, height: number, title: string)
	local frame = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 30),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = BG,
		Visible = false,
		Parent = gui,
	}, { corner(16) })
	make("UIStroke", { Color = GOLD, Thickness = 2, Parent = frame })
	local scale = make("UIScale", { Parent = frame })
	label({
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -90, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = frame,
	})
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(40, 32),
		BackgroundColor3 = RED,
		Text = "X",
		Parent = frame,
	}, 8)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	return frame, scale, width, height
end

-- State -------------------------------------------------------------------------

local status = nil -- last answer from the server
local spinReadyAt = 0 -- os.clock() when the spin is ready
local dailyReadyAt = 0
local spinning = false

-- 🎡 Spin window ------------------------------------------------------------------

local spinWindow, spinScale, SPIN_W, SPIN_H = window("Spin", 440, 520, "🎡 Prize Spin")

local WHEEL = 320
local wheel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(WHEEL, WHEEL),
	BackgroundColor3 = Color3.fromRGB(40, 40, 50),
	ClipsDescendants = false,
	Parent = spinWindow,
}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
make("UIStroke", { Color = GOLD, Thickness = 6, Parent = wheel })

label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(40, 34),
	TextColor3 = GOLD,
	Text = "▼",
	ZIndex = 5,
	Parent = spinWindow,
})

-- The wheel is drawn from many thin bars (so it looks like pie slices).
-- We place them ourselves for any wheel angle, so spinning is smooth.
local prizes = RewardsConfig.SpinPrizes
local sliceAngle = 360 / #prizes
local BARS_PER_SLICE = 9
local bars = {}
local sliceLabels = {}
for index, prize in prizes do
	for b = 1, BARS_PER_SLICE do
		local offset = (b - 0.5) / BARS_PER_SLICE * sliceAngle
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(WHEEL * math.pi / (#prizes * BARS_PER_SLICE) + 3, WHEEL / 2 - 4),
			BackgroundColor3 = prize.Color,
			BorderSizePixel = 0,
			Parent = wheel,
		})
		table.insert(bars, { Frame = bar, Angle = (index - 1) * sliceAngle + offset })
	end
	sliceLabels[index] = {
		Angle = (index - 0.5) * sliceAngle,
		Label = label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(90, 22),
			TextStrokeTransparency = 0.3,
			Text = prize.Name,
			ZIndex = 3,
			Parent = wheel,
		}),
	}
end
make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = GOLD,
	ZIndex = 4,
	Parent = wheel,
}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local wheelAngle = 0

local function placeOnWheel(frame: GuiObject, angle: number, radius: number, rotate: number)
	local radians = math.rad(angle + wheelAngle)
	frame.Position = UDim2.fromOffset(WHEEL / 2 + math.sin(radians) * radius, WHEEL / 2 - math.cos(radians) * radius)
	frame.Rotation = angle + wheelAngle + rotate
end

local function drawWheel()
	for _, bar in bars do
		placeOnWheel(bar.Frame, bar.Angle, WHEEL / 4, 0)
	end
	for _, slice in sliceLabels do
		placeOnWheel(slice.Label, slice.Angle, WHEEL * 0.32, -90)
	end
end
drawWheel()

local spinGo = button({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 410),
	Size = UDim2.fromOffset(220, 50),
	BackgroundColor3 = Color3.fromRGB(40, 170, 80),
	Text = "SPIN!",
	Parent = spinWindow,
}, 12)
local spinMessage = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 468),
	Size = UDim2.new(1, -40, 0, 26),
	Font = Enum.Font.GothamMedium,
	TextColor3 = TEXT_DIM,
	Text = "Free spins! Short waits at first, then every 30 min. Prizes grow with your business!",
	Parent = spinWindow,
})

-- Slice labels show the cash amount once we know it
local function updateWheelLabels()
	if not status or not status.SpinAmounts then
		return
	end
	for index, slice in sliceLabels do
		slice.Label.Text = Format.money(status.SpinAmounts[index] or 0)
	end
end

local function animateTo(index: number, done)
	-- Turn the wheel so slice `index` ends under the arrow at the top, after 5 full spins
	local target = -((index - 0.5) * sliceAngle) + (math.random() - 0.5) * sliceAngle * 0.6
	local start = wheelAngle
	local finish = start + 360 * 5 + ((target - start) % 360)
	local duration = 4.5
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / duration, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		wheelAngle = start + (finish - start) * eased
		drawWheel()
		if t >= 1 then
			connection:Disconnect()
			wheelAngle %= 360
			done()
		end
	end)
end

-- 🎁 Daily window ------------------------------------------------------------------

local dailyWindow, dailyScale, DAILY_W, DAILY_H = window("Daily", 640, 330, "🎁 Daily Reward")

local dayRow = make("Frame", {
	Position = UDim2.fromOffset(18, 60),
	Size = UDim2.new(1, -36, 0, 150),
	BackgroundTransparency = 1,
	Parent = dailyWindow,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})

local dayCards = {}
for day = 1, #RewardsConfig.DailyMultipliers do
	local card = make("Frame", {
		Size = UDim2.fromOffset(78, 150),
		BackgroundColor3 = PANEL,
		LayoutOrder = day,
		Parent = dayRow,
	}, { corner(10) })
	local stroke = make("UIStroke", { Color = GOLD, Thickness = 3, Enabled = false, Parent = card })
	label({ Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 0, 20), Text = "Day " .. day, Parent = card })
	label({ Position = UDim2.fromOffset(4, 34), Size = UDim2.new(1, -8, 0, 46), Text = if day == 7 then "💎" else "💵", Parent = card })
	local amount = label({
		Position = UDim2.fromOffset(4, 90),
		Size = UDim2.new(1, -8, 0, 20),
		TextColor3 = GOLD,
		Text = "",
		Parent = card,
	})
	local tick = label({
		Position = UDim2.fromOffset(4, 116),
		Size = UDim2.new(1, -8, 0, 22),
		TextColor3 = GREEN,
		Text = "",
		Parent = card,
	})
	dayCards[day] = { Card = card, Stroke = stroke, Amount = amount, Tick = tick }
end

local dailyClaim = button({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 224),
	Size = UDim2.fromOffset(240, 48),
	BackgroundColor3 = Color3.fromRGB(40, 170, 80),
	Text = "CLAIM",
	Parent = dailyWindow,
}, 12)
local dailyMessage = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 282),
	Size = UDim2.new(1, -40, 0, 24),
	Font = Enum.Font.GothamMedium,
	TextColor3 = TEXT_DIM,
	Text = "Come back every day. Miss two days and the streak starts over.",
	Parent = dailyWindow,
})

local function updateDailyCards()
	if not status or not status.DailyAmounts then
		return
	end
	local current = status.DailyDay or 1
	local shown = math.clamp(current, 1, #dayCards)
	local ready = dailyReadyAt <= os.clock()
	for day, card in dayCards do
		card.Amount.Text = Format.money(status.DailyAmounts[day] or 0)
		card.Stroke.Enabled = day == shown
		-- Days before today's are already claimed (when you're mid-streak)
		card.Tick.Text = if day < shown or (day == shown and not ready) then "✓" else ""
		card.Card.BackgroundColor3 = if day == shown then Color3.fromRGB(60, 70, 110) else PANEL
	end
end

-- 💰 Shop window ------------------------------------------------------------------

local shopWindow, shopScale, SHOP_W, SHOP_H = window("Shop", 640, 320, "💰 Cash Shop")

local productRow = make("Frame", {
	Position = UDim2.fromOffset(18, 60),
	Size = UDim2.new(1, -36, 0, 200),
	BackgroundTransparency = 1,
	Parent = shopWindow,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})

local productCards = {}
for index, product in RewardsConfig.Products do
	local card = make("Frame", {
		Size = UDim2.fromOffset(140, 200),
		BackgroundColor3 = PANEL,
		LayoutOrder = index,
		Parent = productRow,
	}, { corner(12) })
	label({ Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 0, 54), Text = product.Emoji, Parent = card })
	label({ Position = UDim2.fromOffset(6, 66), Size = UDim2.new(1, -12, 0, 20), Text = product.Name, Parent = card })
	local amount = label({
		Position = UDim2.fromOffset(6, 92),
		Size = UDim2.new(1, -12, 0, 26),
		TextColor3 = GREEN,
		Text = "",
		Parent = card,
	})
	local buy = button({
		Position = UDim2.fromOffset(10, 140),
		Size = UDim2.new(1, -20, 0, 44),
		BackgroundColor3 = if product.ProductId ~= 0 then Color3.fromRGB(40, 170, 80) else Color3.fromRGB(80, 80, 90),
		Text = if product.ProductId ~= 0 then ("R$ %d"):format(product.Robux) else "Coming soon",
		Parent = card,
	}, 10)
	buy.Activated:Connect(function()
		if product.ProductId == 0 then
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
	end)
	productCards[index] = { Amount = amount }
end

label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 272),
	Size = UDim2.new(1, -40, 0, 24),
	Font = Enum.Font.GothamMedium,
	TextColor3 = TEXT_DIM,
	Text = "The bigger your business, the more cash each pack gives.",
	Parent = shopWindow,
})

local function updateShop()
	if not status or not status.ProductAmounts then
		return
	end
	for index, card in productCards do
		card.Amount.Text = "+" .. Format.money(status.ProductAmounts[index] or 0)
	end
end

-- 🏆 Badges window -----------------------------------------------------------------

local milestones = RewardsConfig.Milestones
local badgesWindow, badgesScale, BADGES_W, BADGES_H = window("Badges", 640, 440, "🏆 Milestone Badges")

local earnedLabel = label({
	Position = UDim2.fromOffset(18, 48),
	Size = UDim2.new(1, -36, 0, 22),
	Font = Enum.Font.GothamMedium,
	TextColor3 = TEXT_DIM,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = badgesWindow,
})

local badgeGrid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(18, 80),
	Size = UDim2.new(1, -36, 1, -96),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = badgesWindow,
}, {
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(110, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local badgeCards = {}
for index, milestone in milestones do
	local card = make("Frame", {
		BackgroundColor3 = PANEL,
		LayoutOrder = index,
		Parent = badgeGrid,
	}, { corner(12) })
	local stroke = make("UIStroke", { Color = GOLD, Thickness = 2, Enabled = false, Parent = card })
	local icon = label({ Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 0, 48), Text = milestone.Emoji, Parent = card })
	label({ Position = UDim2.fromOffset(6, 60), Size = UDim2.new(1, -12, 0, 32), TextWrapped = true, Text = milestone.Name, Parent = card })
	label({
		Position = UDim2.fromOffset(6, 96),
		Size = UDim2.new(1, -12, 0, 16),
		Font = Enum.Font.GothamMedium,
		TextColor3 = TEXT_DIM,
		Text = milestone.Text or ("Earn " .. Format.money(milestone.Earned)),
		Parent = card,
	})
	local barBack = make("Frame", {
		Position = UDim2.fromOffset(10, 122),
		Size = UDim2.new(1, -20, 0, 12),
		BackgroundColor3 = BG,
		Parent = card,
	}, { corner(6) })
	local barFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, Parent = barBack }, { corner(6) })
	badgeCards[milestone.Key] = { Card = card, Stroke = stroke, Icon = icon, Fill = barFill, Milestone = milestone }
end

local function updateBadges()
	if not status or not status.Milestones then
		return
	end
	local earned = status.TotalEarned or 0
	local count = 0
	for key, card in badgeCards do
		local unlocked = status.Milestones[key] == true
		if unlocked then
			count += 1
		end
		card.Stroke.Enabled = unlocked
		card.Icon.TextTransparency = if unlocked then 0 else 0.7
		card.Card.BackgroundColor3 = if unlocked then Color3.fromRGB(60, 55, 30) else PANEL
		local goal = card.Milestone.Earned
		local progress = if unlocked or goal <= 0 then 1 else math.clamp(earned / goal, 0, 1)
		card.Fill.Size = UDim2.fromScale(progress, 1)
		card.Fill.BackgroundColor3 = if unlocked then GREEN else GOLD
	end
	earnedLabel.Text = ("Total cash earned: %s   ·   %d / %d unlocked"):format(Format.money(earned), count, #milestones)
end

-- Big pop-up when a badge unlocks
local popup = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -200),
	Size = UDim2.fromOffset(360, 110),
	BackgroundColor3 = BG,
	Visible = false, -- only shown while a badge pop-up is playing
	ZIndex = 10,
	Parent = gui,
}, { corner(16) })
make("UIStroke", { Color = GOLD, Thickness = 3, Parent = popup })
local popupIcon = label({ Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(80, 80), Text = "🏆", ZIndex = 11, Parent = popup })
label({
	Position = UDim2.fromOffset(100, 16),
	Size = UDim2.new(1, -112, 0, 22),
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "BADGE UNLOCKED!",
	ZIndex = 11,
	Parent = popup,
})
local popupName = label({
	Position = UDim2.fromOffset(100, 44),
	Size = UDim2.new(1, -112, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	ZIndex = 11,
	Parent = popup,
})

local popupQueue = {}
local popupBusy = false
local function showNextPopup()
	if popupBusy or #popupQueue == 0 then
		return
	end
	popupBusy = true
	local milestone = table.remove(popupQueue, 1)
	popupIcon.Text = milestone.Emoji
	popupName.Text = milestone.Name
	popup.Position = UDim2.new(0.5, 0, 0, -200)
	popup.Visible = true
	local slide = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(popup, slide, { Position = UDim2.new(0.5, 0, 0, 120) }):Play() -- below the cash bar
	task.delay(3.5, function()
		TweenService:Create(popup, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -200) }):Play()
		task.wait(0.4)
		popup.Visible = false
		popupBusy = false
		showNextPopup()
	end)
end

local milestoneEvent = ReplicatedStorage:WaitForChild("MilestoneUnlocked") :: RemoteEvent

-- Talking to the server ----------------------------------------------------------

local function applyStatus(result)
	if type(result) ~= "table" or not result.Ok or result.SpinIn == nil then
		return
	end
	status = result
	spinReadyAt = os.clock() + result.SpinIn
	dailyReadyAt = os.clock() + result.DailyIn
	if not spinning then
		updateWheelLabels()
	end
	updateDailyCards()
	updateShop()
	updateBadges()
end

local noLot = true

local function refreshStatus()
	local ok, result = pcall(function()
		return rewardsRequest:InvokeServer("status")
	end)
	if ok and type(result) == "table" then
		noLot = result.NoLot == true
		applyStatus(result)
	end
end

local function ask(action: string)
	local ok, result = pcall(function()
		return rewardsRequest:InvokeServer(action)
	end)
	if not ok or type(result) ~= "table" then
		return { Ok = false, Message = "Couldn't reach the server. Try again." }
	end
	return result
end

local windows = { spinWindow, dailyWindow, shopWindow, badgesWindow }
local function open(which)
	for _, w in windows do
		w.Visible = w == which and not w.Visible
	end
	task.spawn(refreshStatus)
end

spinButton.Activated:Connect(function()
	open(spinWindow)
end)
dailyButton.Activated:Connect(function()
	open(dailyWindow)
end)
shopButton.Activated:Connect(function()
	open(shopWindow)
end)
badgesButton.Activated:Connect(function()
	open(badgesWindow)
end)

milestoneEvent.OnClientEvent:Connect(function(key)
	for _, milestone in milestones do
		if milestone.Key == key then
			table.insert(popupQueue, milestone)
		end
	end
	showNextPopup()
	task.spawn(refreshStatus)
end)

spinGo.Activated:Connect(function()
	if spinning then
		return
	end
	if noLot then
		spinMessage.Text = "Claim a lot first!"
		spinMessage.TextColor3 = RED
		return
	end
	spinning = true
	spinMessage.Text = "..."
	spinMessage.TextColor3 = TEXT_DIM
	local result = ask("spin")
	if not result.Ok or not result.Index then
		spinning = false
		spinMessage.Text = result.Message or "Not ready yet."
		spinMessage.TextColor3 = RED
		return
	end
	-- Show this spin's amounts on the wheel, then spin to the prize
	if result.SpinAmounts then
		for index, slice in sliceLabels do
			slice.Label.Text = Format.money(result.SpinAmounts[index] or 0)
		end
	end
	spinMessage.Text = "Spinning..."
	animateTo(result.Index, function()
		spinning = false
		spinMessage.Text = "🎉 " .. (result.Message or "")
		spinMessage.TextColor3 = GREEN
		applyStatus(result)
	end)
end)

dailyClaim.Activated:Connect(function()
	if noLot then
		dailyMessage.Text = "Claim a lot first!"
		dailyMessage.TextColor3 = RED
		return
	end
	local result = ask("daily")
	dailyMessage.Text = result.Message or ""
	dailyMessage.TextColor3 = if result.Ok then GREEN else RED
	applyStatus(result)
end)

-- Timers on the buttons ----------------------------------------------------------

local function updateTimers()
	if noLot then
		spinSub.Text = "Claim a lot"
		dailySub.Text = "Claim a lot"
		spinDot.Visible = false
		dailyDot.Visible = false
		return
	end
	local now = os.clock()
	local spinLeft = spinReadyAt - now
	local dailyLeft = dailyReadyAt - now
	spinSub.Text = if spinLeft <= 0 then "Ready!" else timeText(spinLeft)
	spinSub.TextColor3 = if spinLeft <= 0 then GREEN else TEXT_DIM
	spinDot.Visible = spinLeft <= 0
	dailySub.Text = if dailyLeft <= 0 then "Ready!" else timeText(dailyLeft)
	dailySub.TextColor3 = if dailyLeft <= 0 then GREEN else TEXT_DIM
	dailyDot.Visible = dailyLeft <= 0
	if not spinning then
		spinGo.Text = if spinLeft <= 0 then "SPIN!" else "Next spin " .. timeText(spinLeft)
		spinGo.BackgroundColor3 = if spinLeft <= 0 then Color3.fromRGB(40, 170, 80) else Color3.fromRGB(80, 80, 90)
	end
	dailyClaim.Text = if dailyLeft <= 0 then "CLAIM" else "Next reward " .. timeText(dailyLeft)
	dailyClaim.BackgroundColor3 = if dailyLeft <= 0 then Color3.fromRGB(40, 170, 80) else Color3.fromRGB(80, 80, 90)
end

-- Fit small screens
local function rescale()
	local viewport = camera.ViewportSize
	stackScale.Scale = math.clamp(viewport.Y / 720, 0.6, 1)
	spinScale.Scale = math.clamp(math.min((viewport.X - 20) / SPIN_W, (viewport.Y - 80) / SPIN_H), 0.4, 1)
	dailyScale.Scale = math.clamp(math.min((viewport.X - 20) / DAILY_W, (viewport.Y - 80) / DAILY_H), 0.4, 1)
	badgesScale.Scale = math.clamp(math.min((viewport.X - 20) / BADGES_W, (viewport.Y - 80) / BADGES_H), 0.4, 1)
	shopScale.Scale = math.clamp(math.min((viewport.X - 20) / SHOP_W, (viewport.Y - 80) / SHOP_H), 0.4, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

gui.Parent = player:WaitForChild("PlayerGui")

player:GetAttributeChangedSignal("HasLot"):Connect(refreshStatus)

task.spawn(function()
	local sinceRefresh = 0
	while true do
		updateTimers()
		task.wait(1)
		sinceRefresh += 1
		-- Amounts change as income grows, so refresh now and then
		if sinceRefresh >= 30 then
			sinceRefresh = 0
			task.spawn(refreshStatus)
		end
	end
end)

refreshStatus()
updateTimers()
