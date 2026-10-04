-- Creates the remotes and routes client requests to registered actions.
-- Every action returns `ok, result` where result is an error string on failure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(className: string, name: string)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local action = make("RemoteFunction", "Action") :: RemoteFunction
Remotes.Sync = make("RemoteEvent", "Sync") :: RemoteEvent
Remotes.Notify = make("RemoteEvent", "Notify") :: RemoteEvent
Remotes.Market = make("RemoteEvent", "Market") :: RemoteEvent

folder.Parent = ReplicatedStorage

local MAX_REQUESTS_PER_SECOND = 20

local handlers = {}
local rate = {}

function Remotes.register(name: string, handler: (Player, ...any) -> (boolean, any))
	handlers[name] = handler
end

function Remotes.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

action.OnServerInvoke = function(player: Player, name: any, ...)
	if type(name) ~= "string" then
		return false, "Bad request"
	end
	local handler = handlers[name]
	if not handler then
		return false, "Unknown action"
	end

	local now = os.clock()
	local bucket = rate[player]
	if not bucket or now - bucket.start >= 1 then
		bucket = { start = now, count = 0 }
		rate[player] = bucket
	end
	bucket.count += 1
	if bucket.count > MAX_REQUESTS_PER_SECOND then
		return false, "Slow down!"
	end

	local ok, success, result = pcall(handler, player, ...)
	if not ok then
		warn(`[Remotes] {name} failed for {player.Name}: {success}`)
		return false, "Something went wrong"
	end
	return success, result
end

Players.PlayerRemoving:Connect(function(player)
	rate[player] = nil
end)

return Remotes
