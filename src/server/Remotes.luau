--!strict
-- One place that creates every RemoteEvent. The client waits for the folder (bounded) and then
-- finds events by name. Remotes carry requests and results, never authoritative values.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local events: { [string]: RemoteEvent? } = {}

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	local existing = events[name]
	if existing ~= nil then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	events[name] = event
	return event
end

-- Server-wide banner (Masterpiece premieres, Legend and Icon pulls).
function Remotes.announce(text: string)
	Remotes.get("Announce"):FireAllClients(text)
end

-- Call once after every module has created its events.
function Remotes.publish()
	Remotes.get("Announce") -- created up front so clients can wait for it
	folder.Parent = ReplicatedStorage
end

return Remotes
