--!strict
-- MergeUI: Client UI for selecting pets, sending merge requests, and showing feedback/animations.
-- Lightweight per-frame work to keep 60 FPS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Logger"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MergeRequest: RemoteFunction = Remotes:WaitForChild("MergeRequest") :: RemoteFunction

-- Simple local state for selection (replace with your actual inventory UI)
local selectedA: string? = nil
local selectedB: string? = nil

local function setFeedback(text: string, isError: boolean)
	-- Hook to your UI elements; placeholder prints.
	if isError then
		warn("[MergeUI] " .. text)
	else
		print("[MergeUI] " .. text)
	end
	Logger.info("merge.ui.feedback", text, { error = isError })
end

local function playMergeAnimation()
	-- Lightweight 60 FPS animation using RenderStepped loop.
	local totalTime = 0.8
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= totalTime then
			if conn then
				conn:Disconnect()
				conn = nil
			end
			return
		end
		-- Per-frame minimal math only; no allocations.
	end)
end

local function requestMerge(petIdA: string, petIdB: string)
	setFeedback("Merging...", false)
	local ok, result = pcall(function()
		return MergeRequest:InvokeServer(petIdA, petIdB)
	end)
	if not ok then
		setFeedback("Network error. Please try again.", true)
		return
	end
	if not result.ok then
		setFeedback(result.reason or "Merge failed.", true)
		return
	end
	playMergeAnimation()
	setFeedback(result.message or "Merge complete!", false)
end

-- Public API (replace with your actual UI callbacks)
local MergeUI = {}

function MergeUI.selectPet(petId: string)
	if selectedA == nil then
		selectedA = petId
		setFeedback("Selected Pet A.", false)
	elseif selectedB == nil and petId ~= selectedA then
		selectedB = petId
		setFeedback("Selected Pet B.", false)
	else
		if petId == selectedA then
			selectedA = nil
			setFeedback("Unselected Pet A.", false)
		elseif petId == selectedB then
			selectedB = nil
			setFeedback("Unselected Pet B.", false)
		end
	end
end

function MergeUI.tryMerge()
	if not selectedA or not selectedB then
		setFeedback("Select two pets to merge.", true)
		return
	end
	local a, b = selectedA :: string, selectedB :: string
	selectedA, selectedB = nil, nil
	requestMerge(a, b)
end

return MergeUI