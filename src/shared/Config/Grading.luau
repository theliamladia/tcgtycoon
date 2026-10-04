-- Pristine Grading Service (PGS). Graded cards replace the raw condition
-- multiplier with a grade multiplier.

local Grading = {}

Grading.CompanyName = "PGS"

Grading.Tiers = {
	{ id = "value", name = "Value", fee = 5, duration = 180 },
	{ id = "regular", name = "Regular", fee = 15, duration = 60 },
	{ id = "express", name = "Express", fee = 50, duration = 15 },
}

Grading.TiersById = {}
for _, tier in Grading.Tiers do
	Grading.TiersById[tier.id] = tier
end

Grading.MaxInQueue = 10

Grading.Grades = {
	[10] = { label = "Gem Mint", multiplier = 6 },
	[9] = { label = "Mint", multiplier = 2.5 },
	[8] = { label = "NM-MT", multiplier = 1.5 },
	[7] = { label = "Near Mint", multiplier = 1.15 },
	[6] = { label = "EX-MT", multiplier = 0.9 },
	[5] = { label = "Excellent", multiplier = 0.75 },
	[4] = { label = "VG-EX", multiplier = 0.6 },
	[3] = { label = "Very Good", multiplier = 0.5 },
	[2] = { label = "Good", multiplier = 0.4 },
	[1] = { label = "Poor", multiplier = 0.3 },
}

-- Raw (ungraded) condition buckets. Condition is a hidden 1-100 score.
Grading.Conditions = {
	{ min = 95, label = "Mint", short = "M", multiplier = 1.2 },
	{ min = 85, label = "Near Mint", short = "NM", multiplier = 1.0 },
	{ min = 70, label = "Excellent", short = "EX", multiplier = 0.8 },
	{ min = 40, label = "Played", short = "PL", multiplier = 0.55 },
	{ min = 0, label = "Damaged", short = "DMG", multiplier = 0.3 },
}

-- Graders see more than the eye: the grade is condition/10 plus some noise.
Grading.Noise = 1.6

return Grading
