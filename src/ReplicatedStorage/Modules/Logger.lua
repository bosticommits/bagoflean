--!strict
-- Logger: Structured, batched logging (client/server-safe).
-- Prints JSON batches; hook into your telemetry sink in production.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

export type LogLevel = "debug" | "info" | "warn" | "error"

type LogItem = {
	ts: number,
	level: LogLevel,
	event: string,
	message: string?,
	data: { [string]: any }?,
}

local Logger = {}
Logger._queue = {} :: { LogItem }
Logger._flushing = false
Logger._batchIntervalSec = 0.25
Logger._enabled = true

local function nowMs(): number
	return math.floor(os.clock() * 1000)
end

local function push(level: LogLevel, event: string, message: string?, data: { [string]: any }?)
	if not Logger._enabled then
		return
	end
	table.insert(Logger._queue, {
		ts = nowMs(),
		level = level,
		event = event,
		message = message,
		data = data,
	})
	if not Logger._flushing then
		Logger._flushing = true
		task.delay(Logger._batchIntervalSec, function()
			local batch = Logger._queue
			Logger._queue = {}
			Logger._flushing = false
			if #batch > 0 then
				local ok, encoded = pcall(HttpService.JSONEncode, HttpService, batch)
				if ok then
					if RunService:IsServer() then
						print("[Server][Logs] " .. encoded)
					else
						print("[Client][Logs] " .. encoded)
					end
				else
					warn("[Logger] Failed to JSON encode batch")
				end
			end
		end)
	end
end

function Logger.debug(event: string, message: string?, data: { [string]: any }?)
	push("debug", event, message, data)
end

function Logger.info(event: string, message: string?, data: { [string]: any }?)
	push("info", event, message, data)
end

function Logger.warn(event: string, message: string?, data: { [string]: any }?)
	push("warn", event, message, data)
end

function Logger.error(event: string, message: string?, data: { [string]: any }?)
	push("error", event, message, data)
end

function Logger.setEnabled(enabled: boolean)
	Logger._enabled = enabled
end

function Logger.setBatchInterval(seconds: number)
	Logger._batchIntervalSec = math.max(0.05, seconds)
end

return Logger