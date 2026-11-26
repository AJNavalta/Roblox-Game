--[[
	Format.luau
	Turns big numbers into short, readable money text.
	  Format.money(950)        --> "$950"
	  Format.money(12_345)     --> "$12.3K"
	  Format.money(2_500_000)  --> "$2.50M"
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.money(amount: number): string
	local value = math.floor(math.max(amount, 0))
	if value < 1000 then
		return "$" .. tostring(value)
	end

	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local pattern
	if value >= 100 then
		pattern = "$%.0f%s"
	elseif value >= 10 then
		pattern = "$%.1f%s"
	else
		pattern = "$%.2f%s"
	end
	return string.format(pattern, value, SUFFIXES[index])
end

return Format
