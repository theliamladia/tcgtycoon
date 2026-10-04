local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Grading = require(ReplicatedStorage.Shared.Config.Grading)
local Money = require(ReplicatedStorage.Shared.Money)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local GradingService = {}

local rng = Random.new()

local function rollGrade(condition: number): number
	local score = condition / 10 + (rng:NextNumber() - 0.5) * Grading.Noise
	return math.clamp(math.floor(score + 0.5), 1, 10)
end

local function finish(player: Player, data, card)
	local grade = rollGrade(card.condition)
	card.grade = grade
	card.location = "inventory"
	card.gradeTier = nil
	card.gradeDoneAt = nil
	data.stats.cardsGraded += 1

	local def = Cards.ById[card.cardId]
	local name = if def then def.name else "Card"
	local label = Grading.Grades[grade].label
	if grade == 10 then
		data.stats.gemMints += 1
		Remotes.notify(player, `💎 {name} graded {Grading.CompanyName} 10 {label}!`, "gem")
	else
		Remotes.notify(player, `{name} graded {Grading.CompanyName} {grade} {label}`, "info")
	end
end

function GradingService.init()
	Remotes.register("Grade", function(player, uid, tierId)
		local data = DataService.get(player)
		if not data then
			return false, "Still loading your save..."
		end
		local tier = Grading.TiersById[tierId]
		local card = type(uid) == "string" and data.cards[uid]
		if not tier or not card then
			return false, "Invalid request"
		end
		if card.location ~= "inventory" then
			return false, "That card is busy"
		end
		if card.grade then
			return false, "Already graded"
		end
		if DataService.countAt(data, "grading") >= Grading.MaxInQueue then
			return false, `Grading queue is full ({Grading.MaxInQueue} max)`
		end
		if data.cash < tier.fee then
			return false, "Not enough cash"
		end

		data.cash = Money.round(data.cash - tier.fee)
		card.location = "grading"
		card.gradeTier = tier.id
		card.gradeDoneAt = workspace:GetServerTimeNow() + tier.duration
		DataService.markDirty(player)
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			for player, data in DataService.getAll() do
				local changed = false
				for _, card in data.cards do
					if card.location == "grading" and (card.gradeDoneAt or 0) <= now then
						finish(player, data, card)
						changed = true
					end
				end
				if changed then
					DataService.markDirty(player)
				end
			end
		end
	end)
end

return GradingService
