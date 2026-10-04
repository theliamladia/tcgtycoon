-- Card value and buyer demand math, shared by server and client so the
-- UI shows exactly what the server uses.

local Config = script.Parent:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Grading = require(Config:WaitForChild("Grading"))
local Money = require(script.Parent:WaitForChild("Money"))

local Valuation = {}

function Valuation.condition(condition: number)
	for _, bucket in Grading.Conditions do
		if condition >= bucket.min then
			return bucket
		end
	end
	return Grading.Conditions[#Grading.Conditions]
end

function Valuation.multiplier(card): number
	if card.grade then
		local grade = Grading.Grades[card.grade]
		return if grade then grade.multiplier else 1
	end
	return Valuation.condition(card.condition or 0).multiplier
end

-- `trends` maps cardId -> market trend multiplier (1 = normal).
function Valuation.value(card, trends: { [string]: number }?): number
	local def = Cards.ById[card.cardId]
	if not def then
		return 0
	end
	local trend = if trends then trends[card.cardId] or 1 else 1
	return math.max(0.01, Money.round(def.value * Valuation.multiplier(card) * trend))
end

-- How keen a buyer is at a given price/value ratio. 1 at market value,
-- up to 2 when underpriced, falling to 0 at `tolerance`.
function Valuation.demand(ratio: number, tolerance: number): number
	if ratio >= tolerance then
		return 0
	elseif ratio <= 1 then
		return math.min(2, 1 + (1 - ratio) * 2)
	end
	return (tolerance - ratio) / (tolerance - 1)
end

function Valuation.describe(card): string
	if card.grade then
		local grade = Grading.Grades[card.grade]
		return string.format("%s %d %s", Grading.CompanyName, card.grade, if grade then grade.label else "")
	end
	return Valuation.condition(card.condition or 0).label
end

return Valuation
