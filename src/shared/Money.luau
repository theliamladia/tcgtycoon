local Money = {}

function Money.round(amount: number): number
	return math.floor(amount * 100 + 0.5) / 100
end

local function commas(whole: number): string
	local s = tostring(whole)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Money.format(amount: number): string
	local negative = amount < 0
	local cents = math.floor(math.abs(amount) * 100 + 0.5)
	local whole = cents // 100
	local text = "$" .. commas(whole) .. string.format(".%02d", cents % 100)
	return if negative then "-" .. text else text
end

function Money.isValid(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

return Money
