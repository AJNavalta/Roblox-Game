--[[
	Phone.client.luau
	The phone in the bottom-right corner (click it or press P).

	Apps:
	  🏦 Bank    your cash, money waiting at the collector, investments, net worth
	  📈 Stocks  opens the big Market window (Stocks, Crypto, NFTs, My Portfolio)
	  🪙 Crypto  same window, Crypto tab
	  🖼️ NFTs    same window, NFTs tab

	This script only SHOWS things and ASKS the server to trade. The server
	(src/server/Market.luau) moves the prices and does all the money math.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local MarketConfig = require(Shared:WaitForChild("MarketConfig"))

local marketRequest = ReplicatedStorage:WaitForChild("MarketRequest") :: RemoteFunction
local marketPrices = ReplicatedStorage:WaitForChild("MarketPrices") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local price = MarketConfig.formatPrice

-- Colors ----------------------------------------------------------------------
local BG = Color3.fromRGB(20, 22, 30)
local PANEL = Color3.fromRGB(32, 35, 48)
local PANEL_LIGHT = Color3.fromRGB(46, 50, 66)
local TEXT_DIM = Color3.fromRGB(170, 175, 195)
local GREEN = Color3.fromRGB(80, 220, 120)
local RED = Color3.fromRGB(240, 85, 85)
local GOLD = Color3.fromRGB(255, 205, 60)
local BLUE = Color3.fromRGB(70, 140, 255)

-- State ---------------------------------------------------------------------
local prices: { [string]: number } = {}
local history: { [string]: { number } } = {}
local portfolio: { [string]: { Shares: number, Cost: number } } = {}

-- Small UI helpers ----------------------------------------------------------

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
	local b = make("TextButton", props, { corner(radius or 8) })
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = b,
	})
	return b
end

local function signed(amount: number): string
	if amount >= 0 then
		return "+" .. price(amount)
	end
	return "-" .. price(-amount)
end

local function percentText(change: number): string
	return string.format("%s%.1f%%", if change >= 0 then "+" else "", change * 100)
end

local function getCash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function holdingValue(id: string): number
	local holding = portfolio[id]
	return if holding and prices[id] then holding.Shares * prices[id] else 0
end

local function investedTotals(): (number, number)
	local value, cost = 0, 0
	for id, holding in portfolio do
		value += holdingValue(id)
		cost += holding.Cost
	end
	return value, cost
end

-- Change since the oldest point on the chart
local function changeOf(id: string): number
	local list = history[id]
	if not list or #list < 2 or list[1] <= 0 then
		return 0
	end
	return list[#list] / list[1] - 1
end

-- Turns "1,500", "$2.5k", "3m" into numbers
local function parseAmount(text: string): number?
	local cleaned = text:lower():gsub("[%$,%s]", "")
	local multiplier = 1
	local suffix = cleaned:sub(-1)
	if suffix == "k" then
		multiplier = 1e3
	elseif suffix == "m" then
		multiplier = 1e6
	elseif suffix == "b" then
		multiplier = 1e9
	elseif suffix == "t" then
		multiplier = 1e12
	end
	if multiplier ~= 1 then
		cleaned = cleaned:sub(1, -2)
	end
	local number = tonumber(cleaned)
	if number and number == number and number > 0 then
		return number * multiplier
	end
	return nil
end

-- The ScreenGui ---------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "PhoneGui",
	ResetOnSpawn = false,
	DisplayOrder = 1, -- above the HUD's pop-ups
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Phones/tablets have the jump button in the bottom-right, so sit above it there
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local bottomGap = if touchOnly then 170 else 16

-- Toggle button -------------------------------------------------------------

local PHONE_W, PHONE_H = 250, 440

local toggle = button({
	Name = "PhoneToggle",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -bottomGap),
	Size = UDim2.fromOffset(120, 46),
	BackgroundColor3 = BG,
	Text = "📱 Phone",
	Parent = gui,
}, 23)
make("UIStroke", { Color = GOLD, Thickness = 2, Parent = toggle })

-- The phone itself -------------------------------------------------------------

local phone = make("Frame", {
	Name = "Phone",
	AnchorPoint = Vector2.new(1, 1),
	Size = UDim2.fromOffset(PHONE_W, PHONE_H),
	BackgroundColor3 = Color3.fromRGB(10, 10, 12),
	Visible = false,
	Parent = gui,
}, { corner(30) })
make("UIStroke", { Color = Color3.fromRGB(80, 80, 90), Thickness = 2, Parent = phone })
local phoneScale = make("UIScale", { Parent = phone })

local OPEN_POS = UDim2.new(1, -16, 1, -(bottomGap + 46 + 10))
local CLOSED_POS = UDim2.new(1, -16, 1, PHONE_H + 20)
phone.Position = CLOSED_POS

local screen = make("Frame", {
	Name = "Screen",
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -20, 1, -20),
	BackgroundColor3 = Color3.fromRGB(28, 30, 60),
	ClipsDescendants = true,
	Parent = phone,
}, {
	corner(22),
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(60, 50, 140), Color3.fromRGB(15, 20, 40)),
	}),
})

-- Status bar: clock + notch
local clock = label({
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.fromOffset(60, 16),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "9:41",
	Parent = screen,
})
make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(70, 18),
	BackgroundColor3 = Color3.fromRGB(10, 10, 12),
	Parent = screen,
}, { corner(9) })
label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 6),
	Size = UDim2.fromOffset(60, 16),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "📶 🔋",
	Parent = screen,
})

-- Home bar at the bottom of the phone returns to the home screen
local homeBar = button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.fromOffset(90, 6),
	BackgroundColor3 = Color3.fromRGB(230, 230, 240),
	Text = "",
	Parent = screen,
}, 3)

local function page(name: string)
	return make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
end

-- Home screen -------------------------------------------------------------------

local homePage = page("Home")
homePage.Visible = true

label({
	Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "9:41",
	Name = "BigClock",
	Parent = homePage,
})
label({
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 0, 16),
	Font = Enum.Font.Gotham,
	TextColor3 = TEXT_DIM,
	Text = "Billionaire City",
	Parent = homePage,
})

local appGrid = make("Frame", {
	Position = UDim2.fromOffset(14, 84),
	Size = UDim2.new(1, -28, 0, 220),
	BackgroundTransparency = 1,
	Parent = homePage,
}, {
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(92, 92),
		CellPadding = UDim2.fromOffset(16, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local function appIcon(order: number, emoji: string, name: string, color: Color3)
	local holder = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Parent = appGrid })
	local icon = button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = color,
		Text = emoji,
		Parent = holder,
	}, 16)
	label({
		Position = UDim2.new(0, 0, 0, 68),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamMedium,
		Text = name,
		Parent = holder,
	})
	return icon
end

local bankIcon = appIcon(1, "🏦", "Bank", Color3.fromRGB(40, 160, 90))
local stocksIcon = appIcon(2, "📈", "Stocks", BLUE)
local cryptoIcon = appIcon(3, "🪙", "Crypto", Color3.fromRGB(240, 160, 30))
local nftIcon = appIcon(4, "🖼️", "NFTs", Color3.fromRGB(190, 70, 210))

-- Bank app ------------------------------------------------------------------

local bankPage = page("Bank")

label({
	Position = UDim2.fromOffset(12, 4),
	Size = UDim2.new(1, -24, 0, 24),
	Text = "🏦 Billionaire Bank",
	Parent = bankPage,
})

local cashCard = make("Frame", {
	Position = UDim2.fromOffset(12, 36),
	Size = UDim2.new(1, -24, 0, 84),
	BackgroundColor3 = Color3.fromRGB(30, 120, 70),
	Parent = bankPage,
}, {
	corner(14),
	make("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new(Color3.fromRGB(50, 180, 100), Color3.fromRGB(20, 90, 60)),
	}),
})
label({
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 16),
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Cash balance",
	Parent = cashCard,
})
local bankCash = label({
	Position = UDim2.fromOffset(12, 28),
	Size = UDim2.new(1, -24, 0, 44),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "$0",
	Parent = cashCard,
})

local bankRows = make("Frame", {
	Position = UDim2.fromOffset(12, 130),
	Size = UDim2.new(1, -24, 0, 170),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Parent = bankPage,
}, {
	corner(12),
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
})

local function bankRow(order: number, name: string)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order, Parent = bankRows })
	label({
		Size = UDim2.new(0.55, 0, 0, 18),
		Position = UDim2.fromOffset(0, 6),
		Font = Enum.Font.GothamMedium,
		TextColor3 = TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
		Parent = row,
	})
	return label({
		Size = UDim2.new(0.45, 0, 0, 18),
		Position = UDim2.new(0.55, 0, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "$0",
		Parent = row,
	})
end

local bankPending = bankRow(1, "At collector")
local bankInvested = bankRow(2, "Investments")
local bankProfit = bankRow(3, "Profit / loss")
local bankIncome = bankRow(4, "Income")
local bankNetWorth = bankRow(5, "Net worth")
bankNetWorth.TextColor3 = GOLD

local bankMarketButton = button({
	Position = UDim2.fromOffset(12, 312),
	Size = UDim2.new(1, -24, 0, 40),
	BackgroundColor3 = BLUE,
	Text = "📈 Open Market",
	Parent = bankPage,
}, 12)

-- Market window ----------------------------------------------------------------

local WIN_W, WIN_H = 800, 480
local LIST_W = 360
local CHART_W, CHART_H = 362, 120

local market = make("Frame", {
	Name = "Market",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 40),
	Size = UDim2.fromOffset(WIN_W, WIN_H),
	BackgroundColor3 = BG,
	Visible = false,
	ZIndex = 2, -- in front of the phone
	Parent = gui,
}, { corner(16) })
make("UIStroke", { Color = BLUE, Thickness = 2, Parent = market })
local marketScale = make("UIScale", { Parent = market })

label({
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.fromOffset(330, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "📈 Billionaire Exchange",
	Parent = market,
})
local marketCash = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -64, 0, 14),
	Size = UDim2.fromOffset(300, 24),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = GREEN,
	Text = "Cash: $0",
	Parent = market,
})
local closeMarket = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(40, 32),
	BackgroundColor3 = RED,
	Text = "X",
	Parent = market,
}, 8)

-- Tabs
local tabBar = make("Frame", {
	Position = UDim2.fromOffset(18, 50),
	Size = UDim2.new(1, -36, 0, 34),
	BackgroundTransparency = 1,
	Parent = market,
}, {
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local TABS = {
	{ Id = "stocks", Name = "📊 Stocks" },
	{ Id = "crypto", Name = "🪙 Crypto" },
	{ Id = "nfts", Name = "🖼️ NFTs" },
	{ Id = "portfolio", Name = "💼 My Portfolio" },
}
local tabButtons = {}
for order, tab in TABS do
	tabButtons[tab.Id] = button({
		Size = UDim2.fromOffset(if tab.Id == "portfolio" then 170 else 120, 34),
		BackgroundColor3 = PANEL,
		Text = tab.Name,
		LayoutOrder = order,
		Parent = tabBar,
	}, 8)
end

-- Left side: the list of assets
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(18, 94),
	Size = UDim2.fromOffset(LIST_W, WIN_H - 112),
	BackgroundColor3 = PANEL,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	BorderSizePixel = 0,
	Parent = market,
}, {
	corner(10),
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 12),
	}),
})

local emptyNote = label({
	Size = UDim2.new(1, 0, 0, 60),
	Font = Enum.Font.GothamMedium,
	TextColor3 = TEXT_DIM,
	TextWrapped = true,
	Text = "You don't own anything yet.\nPick a stock, coin or NFT and invest!",
	LayoutOrder = 0,
	Visible = false,
	Parent = list,
})

local rows = {} -- [assetId] = { Frame, Price, Change, Sub }
for order, asset in MarketConfig.AssetList do
	local row = button({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = PANEL_LIGHT,
		Text = "",
		LayoutOrder = order,
		Visible = false,
		Parent = list,
	}, 8)
	local title = (asset.Icon and asset.Icon .. " " or "") .. asset.Name
	label({
		Size = UDim2.new(0.6, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = row,
	})
	local sub = label({
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(0.6, 0, 0, 14),
		Font = Enum.Font.Gotham,
		TextColor3 = TEXT_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = asset.Id,
		Parent = row,
	})
	local priceLabel = label({
		Position = UDim2.new(0.6, 0, 0, 0),
		Size = UDim2.new(0.4, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = row,
	})
	local changeLabel = label({
		Position = UDim2.new(0.6, 0, 0, 20),
		Size = UDim2.new(0.4, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = row,
	})
	rows[asset.Id] = { Frame = row, Price = priceLabel, Change = changeLabel, Sub = sub }
end

-- Right side: details, chart and trade buttons for the picked asset
local detail = make("Frame", {
	Position = UDim2.fromOffset(18 + LIST_W + 14, 94),
	Size = UDim2.fromOffset(WIN_W - LIST_W - 50, WIN_H - 112),
	BackgroundColor3 = PANEL,
	Parent = market,
}, { corner(10) })

local detailName = label({
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Pick something from the list",
	Parent = detail,
})
local detailPrice = label({
	Position = UDim2.fromOffset(14, 38),
	Size = UDim2.fromOffset(200, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = detail,
})
local detailChange = label({
	Position = UDim2.fromOffset(220, 44),
	Size = UDim2.new(1, -234, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
	Parent = detail,
})

local chart = make("Frame", {
	Position = UDim2.fromOffset(14, 74),
	Size = UDim2.fromOffset(CHART_W, CHART_H),
	BackgroundColor3 = BG,
	ClipsDescendants = true,
	Parent = detail,
}, { corner(8) })
local segments = {}
for i = 1, MarketConfig.HistoryLength - 1 do
	segments[i] = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Visible = false,
		Parent = chart,
	})
end

local detailHolding = label({
	Position = UDim2.fromOffset(14, 202),
	Size = UDim2.new(1, -28, 0, 36),
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = detail,
})

local amountBox = make("TextBox", {
	Position = UDim2.fromOffset(14, 246),
	Size = UDim2.fromOffset(130, 36),
	BackgroundColor3 = BG,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	PlaceholderText = "$ amount",
	PlaceholderColor3 = TEXT_DIM,
	Text = "",
	ClearTextOnFocus = false,
	Parent = detail,
}, {
	corner(8),
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
})

local quickButtons = {}
for i = 1, 4 do
	quickButtons[i] = button({
		Position = UDim2.fromOffset(152 + (i - 1) * 56, 246),
		Size = UDim2.fromOffset(50, 36),
		BackgroundColor3 = PANEL_LIGHT,
		Text = "",
		Parent = detail,
	}, 8)
end

local buyButton = button({
	Position = UDim2.fromOffset(14, 292),
	Size = UDim2.fromOffset(114, 42),
	BackgroundColor3 = Color3.fromRGB(40, 170, 80),
	Text = "BUY",
	Parent = detail,
}, 10)
local sellButton = button({
	Position = UDim2.fromOffset(138, 292),
	Size = UDim2.fromOffset(114, 42),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60),
	Text = "SELL",
	Parent = detail,
}, 10)
local sellAllButton = button({
	Position = UDim2.fromOffset(262, 292),
	Size = UDim2.fromOffset(114, 42),
	BackgroundColor3 = Color3.fromRGB(130, 40, 40),
	Text = "SELL ALL",
	Parent = detail,
}, 10)

local feedback = label({
	Position = UDim2.fromOffset(14, 340),
	Size = UDim2.new(1, -28, 0, 20),
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = detail,
})

-- Showing data ----------------------------------------------------------------

local currentTab = "stocks"
local selectedId: string? = nil

local function drawChart(id: string)
	local points = history[id] or {}
	local low, high = math.huge, -math.huge
	for _, p in points do
		low = math.min(low, p)
		high = math.max(high, p)
	end
	local span = high - low
	if span <= 0 then
		span = 1
	end
	local color = if changeOf(id) >= 0 then GREEN else RED
	local count = #points
	local pad = 8
	for i, segment in segments do
		local a, b = points[i], points[i + 1]
		if a and b then
			local x1 = pad + (i - 1) / (count - 1) * (CHART_W - pad * 2)
			local x2 = pad + i / (count - 1) * (CHART_W - pad * 2)
			local y1 = CHART_H - pad - (a - low) / span * (CHART_H - pad * 2)
			local y2 = CHART_H - pad - (b - low) / span * (CHART_H - pad * 2)
			local dx, dy = x2 - x1, y2 - y1
			segment.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
			segment.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 3)
			segment.Rotation = math.deg(math.atan2(dy, dx))
			segment.BackgroundColor3 = color
			segment.Visible = true
		else
			segment.Visible = false
		end
	end
end

local function setQuickButtons(asset)
	local labels = if asset and asset.Kind == "whole" then { "1", "5", "10", "MAX" } else { "25%", "50%", "75%", "MAX" }
	for i, quick in quickButtons do
		quick.Text = labels[i]
	end
	amountBox.PlaceholderText = if asset and asset.Kind == "whole" then "how many" else "$ amount"
end

local function updateDetail()
	local asset = selectedId and MarketConfig.AssetsById[selectedId]
	for _, thing in { detailPrice, detailChange, chart, detailHolding, amountBox, buyButton, sellButton, sellAllButton } do
		thing.Visible = asset ~= nil
	end
	for _, quick in quickButtons do
		quick.Visible = asset ~= nil
	end
	if not asset then
		detailName.Text = "Pick something from the list"
		return
	end

	local id = asset.Id
	local current = prices[id] or asset.Base
	local change = changeOf(id)
	detailName.Text = (asset.Icon and asset.Icon .. " " or "") .. asset.Name .. "  (" .. id .. ")"
	detailPrice.Text = price(current) .. (if asset.Kind == "whole" then " each" else "")
	detailChange.Text = percentText(change) .. " recently"
	detailChange.TextColor3 = if change >= 0 then GREEN else RED
	drawChart(id)

	local holding = portfolio[id]
	if holding then
		local value = holdingValue(id)
		local profit = value - holding.Cost
		local owned = if asset.Kind == "whole"
			then ("You own %d (worth %s)"):format(math.floor(holding.Shares + 0.5), price(value))
			else ("You own %s worth of %s"):format(price(value), id)
		detailHolding.Text = ("%s\nProfit: %s"):format(owned, signed(profit))
		detailHolding.TextColor3 = if profit >= 0 then GREEN else RED
	else
		detailHolding.Text = if asset.Kind == "whole"
			then "You don't own any yet. NFTs are bought one at a time at the floor price."
			else "You don't own any yet. Invest any amount, sell any time."
		detailHolding.TextColor3 = TEXT_DIM
	end
	sellButton.Visible = holding ~= nil
	sellAllButton.Visible = holding ~= nil
end

local function updateRows()
	local anyShown = false
	for _, asset in MarketConfig.AssetList do
		local id = asset.Id
		local row = rows[id]
		local holding = portfolio[id]
		local show = if currentTab == "portfolio" then holding ~= nil else asset.Category == currentTab
		row.Frame.Visible = show
		row.Frame.BackgroundColor3 = if id == selectedId then Color3.fromRGB(60, 80, 140) else PANEL_LIGHT
		if show then
			anyShown = true
			if currentTab == "portfolio" then
				local value = holdingValue(id)
				local profit = value - holding.Cost
				row.Sub.Text = if asset.Kind == "whole" then ("Own %d"):format(math.floor(holding.Shares + 0.5)) else id
				row.Price.Text = price(value)
				row.Change.Text = signed(profit)
				row.Change.TextColor3 = if profit >= 0 then GREEN else RED
			else
				local change = changeOf(id)
				row.Sub.Text = if holding then id .. "  •  you own some" else id
				row.Price.Text = price(prices[id] or asset.Base)
				row.Change.Text = percentText(change)
				row.Change.TextColor3 = if change >= 0 then GREEN else RED
			end
		end
	end
	emptyNote.Visible = not anyShown
end

local function updateBank()
	local cash = getCash()
	local pending = player:GetAttribute("Pending") or 0
	local value, cost = investedTotals()
	bankCash.Text = Format.money(cash)
	bankPending.Text = Format.money(pending)
	bankInvested.Text = Format.money(value)
	bankProfit.Text = signed(value - cost)
	bankProfit.TextColor3 = if value - cost >= 0 then GREEN else RED
	bankIncome.Text = "+" .. Format.money(player:GetAttribute("Income") or 0) .. "/s"
	bankNetWorth.Text = Format.money(cash + pending + value)
	marketCash.Text = "Cash: " .. Format.money(cash)
end

local function refreshAll()
	updateBank()
	if market.Visible then
		updateRows()
		updateDetail()
	end
end

local function selectTab(tabId: string)
	currentTab = tabId
	for id, tabButton in tabButtons do
		tabButton.BackgroundColor3 = if id == tabId then BLUE else PANEL
	end
	-- Pick the first thing in this tab so the right side isn't empty
	local selected = selectedId and MarketConfig.AssetsById[selectedId]
	local fits = selected and (if tabId == "portfolio" then portfolio[selected.Id] ~= nil else selected.Category == tabId)
	if not fits then
		selectedId = nil
		for _, asset in MarketConfig.AssetList do
			if (tabId == "portfolio" and portfolio[asset.Id]) or asset.Category == tabId then
				selectedId = asset.Id
				break
			end
		end
	end
	setQuickButtons(selectedId and MarketConfig.AssetsById[selectedId])
	list.CanvasPosition = Vector2.zero
	feedback.Text = ""
	updateRows()
	updateDetail()
end

for id, tabButton in tabButtons do
	tabButton.Activated:Connect(function()
		selectTab(id)
	end)
end

for id, row in rows do
	row.Frame.Activated:Connect(function()
		selectedId = id
		amountBox.Text = ""
		feedback.Text = ""
		setQuickButtons(MarketConfig.AssetsById[id])
		updateRows()
		updateDetail()
	end)
end

-- Trading -------------------------------------------------------------------

local busy = false

local function trade(action: string, amount)
	if busy or not selectedId then
		return
	end
	if amount == nil then
		feedback.Text = "Type an amount first."
		feedback.TextColor3 = RED
		return
	end
	busy = true
	feedback.Text = "..."
	feedback.TextColor3 = TEXT_DIM
	local ok, result = pcall(function()
		return marketRequest:InvokeServer(action, selectedId, amount)
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		feedback.Text = "Couldn't reach the market. Try again."
		feedback.TextColor3 = RED
		return
	end
	if result.Portfolio then
		portfolio = result.Portfolio
	end
	feedback.Text = result.Message or ""
	feedback.TextColor3 = if result.Ok then GREEN else RED
	if result.Ok then
		amountBox.Text = ""
	end
	refreshAll()
end

buyButton.Activated:Connect(function()
	trade("buy", parseAmount(amountBox.Text))
end)
sellButton.Activated:Connect(function()
	trade("sell", parseAmount(amountBox.Text))
end)
sellAllButton.Activated:Connect(function()
	trade("sell", "all")
end)

for i, quick in quickButtons do
	quick.Activated:Connect(function()
		local asset = selectedId and MarketConfig.AssetsById[selectedId]
		if not asset then
			return
		end
		local cash = getCash()
		if asset.Kind == "whole" then
			local maxCount = math.floor(cash / (prices[asset.Id] or asset.Base))
			local counts = { 1, 5, 10, maxCount }
			amountBox.Text = tostring(math.max(counts[i], 0))
		else
			local fractions = { 0.25, 0.5, 0.75, 1 }
			amountBox.Text = tostring(math.floor(cash * fractions[i]))
		end
	end)
end

-- Opening and closing ---------------------------------------------------------

local phoneOpen = false
local slide = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function showPage(which)
	for _, p in { homePage, bankPage } do
		p.Visible = p == which
	end
	refreshAll()
end

local function setPhoneOpen(open: boolean)
	phoneOpen = open
	toggle.Text = if open then "⬇ Close" else "📱 Phone"
	if open then
		phone.Visible = true
		refreshAll()
	end
	local tween = TweenService:Create(phone, slide, { Position = if open then OPEN_POS else CLOSED_POS })
	tween:Play()
	if not open then
		tween.Completed:Once(function()
			if not phoneOpen then
				phone.Visible = false
			end
		end)
	end
end

local function openMarket(tabId: string)
	market.Visible = true
	selectTab(tabId)
	refreshAll()
end

toggle.Activated:Connect(function()
	setPhoneOpen(not phoneOpen)
end)
homeBar.Activated:Connect(function()
	showPage(homePage)
end)
bankIcon.Activated:Connect(function()
	showPage(bankPage)
end)
stocksIcon.Activated:Connect(function()
	openMarket("stocks")
end)
cryptoIcon.Activated:Connect(function()
	openMarket("crypto")
end)
nftIcon.Activated:Connect(function()
	openMarket("nfts")
end)
bankMarketButton.Activated:Connect(function()
	openMarket("portfolio")
end)
closeMarket.Activated:Connect(function()
	market.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- typing in chat or a text box
	end
	if input.KeyCode == Enum.KeyCode.P then
		setPhoneOpen(not phoneOpen)
	end
end)

-- Shrink everything on small screens so it always fits
local function rescale()
	local viewport = camera.ViewportSize
	phoneScale.Scale = math.clamp((viewport.Y - bottomGap - 70) / PHONE_H, 0.5, 1)
	marketScale.Scale = math.clamp(math.min((viewport.X - 20) / WIN_W, (viewport.Y - 100) / WIN_H), 0.4, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

gui.Parent = player:WaitForChild("PlayerGui")

-- Live data -------------------------------------------------------------------

local function loadSnapshot()
	local ok, snapshot = pcall(function()
		return marketRequest:InvokeServer("snapshot")
	end)
	if ok and type(snapshot) == "table" then
		prices = snapshot.Prices or prices
		history = snapshot.History or history
		portfolio = snapshot.Portfolio or portfolio
		refreshAll()
	end
end

marketPrices.OnClientEvent:Connect(function(newPrices)
	for id, value in newPrices do
		prices[id] = value
		local points = history[id]
		if not points then
			points = {}
			history[id] = points
		end
		table.insert(points, value)
		if #points > MarketConfig.HistoryLength then
			table.remove(points, 1)
		end
	end
	refreshAll()
end)

-- Your holdings load from your save once you claim a lot
player:GetAttributeChangedSignal("HasLot"):Connect(loadSnapshot)
for _, attribute in { "Pending", "Income" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateBank)
end
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	leaderstats:WaitForChild("Cash").Changed:Connect(updateBank)
	updateBank()
end)

-- Phone clock shows the real time where the player is
task.spawn(function()
	while true do
		local now = os.date("*t")
		local hour = now.hour % 12
		local text = ("%d:%02d"):format(if hour == 0 then 12 else hour, now.min)
		clock.Text = text
		homePage.BigClock.Text = text
		task.wait(5)
	end
end)

selectTab("stocks")
loadSnapshot()
