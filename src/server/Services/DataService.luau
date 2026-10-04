-- Loads, saves and replicates player data.
--
-- Every card a player owns lives in `data.cards[uid]`. Its `location`
-- says where it is: "inventory", "grading", "store", "online" or "show".

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cards = require(ReplicatedStorage.Shared.Config.Cards)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(script.Parent.Remotes)

local DataService = {}

local KEY_PREFIX = "player_"
local AUTOSAVE_INTERVAL = 120
local SYNC_INTERVAL = 0.2

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local loadedCallbacks = {}

local dataStore: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("TCGTycoon_PlayerData_v1")
	end)
	if ok then
		dataStore = result
	else
		warn("[DataService] DataStores unavailable, progress will not save:", result)
	end
end

local function defaultData()
	return {
		cash = Economy.StartingCash,
		reputation = 0,
		nextCardId = 1,
		storeLevel = 1,
		cards = {},
		discovered = {},
		stats = {
			packsOpened = 0,
			cardsSold = 0,
			totalEarned = 0,
			cardsGraded = 0,
			gemMints = 0,
			bestSale = 0,
		},
	}
end

local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

-- Shows don't survive a server hop: bring those cards home. Cards from
-- sets that were removed from the game are dropped.
local function normalize(data)
	for uid, card in data.cards do
		if not Cards.ById[card.cardId] then
			data.cards[uid] = nil
			continue
		end
		if card.location == "show" then
			card.location = "inventory"
			card.price = nil
		end
	end
	data.show = nil
end

local function load(player: Player)
	if not dataStore then
		return defaultData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (dataStore :: DataStore):GetAsync(KEY_PREFIX .. player.UserId)
		end)
		if ok then
			local data = if type(result) == "table" then result else defaultData()
			reconcile(data, defaultData())
			normalize(data)
			return data, true
		end
		warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {result}`)
		task.wait(attempt)
	end
	return defaultData(), false
end

local function save(player: Player)
	local data = profiles[player]
	if not data or not canSave[player] or not dataStore then
		return
	end
	local ok, err = pcall(function()
		(dataStore :: DataStore):UpdateAsync(KEY_PREFIX .. player.UserId, function()
			return data
		end)
	end)
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	end
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.getAll()
	return profiles
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, data in profiles do
		task.spawn(callback, player, data)
	end
end

function DataService.countCards(data): number
	local count = 0
	for _ in data.cards do
		count += 1
	end
	return count
end

function DataService.countAt(data, location: string): number
	local count = 0
	for _, card in data.cards do
		if card.location == location then
			count += 1
		end
	end
	return count
end

function DataService.newCard(data, cardId: string, condition: number)
	local uid = "c" .. data.nextCardId
	data.nextCardId += 1
	local card = {
		uid = uid,
		cardId = cardId,
		condition = condition,
		location = "inventory",
		obtainedAt = os.time(),
	}
	data.cards[uid] = card
	data.discovered[cardId] = true
	return card
end

local function onPlayerAdded(player: Player)
	local data, ok = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = data
	canSave[player] = ok
	dirty[player] = true
	if not ok then
		Remotes.notify(player, "Couldn't load your save. Progress this session won't be saved.", "error")
	end
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	save(player)
	profiles[player] = nil
	canSave[player] = nil
	dirty[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < SYNC_INTERVAL then
			return
		end
		elapsed = 0
		for player in dirty do
			local data = profiles[player]
			if data then
				Remotes.Sync:FireClient(player, data)
			end
		end
		table.clear(dirty)
	end)

	Remotes.register("RequestSync", function(player)
		dirty[player] = true
		return true
	end)
end

return DataService
