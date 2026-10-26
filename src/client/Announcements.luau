--!strict
-- The server-wide banner (plan section 22): one slim strip under the HUD top stack that shows, one
-- at a time from a queue, the plain announcements (Masterpieces, sequels, festival winners...) and
-- the rare-pull news (Superstar and up, Legend and Icon also from other servers) in the tier color.
-- Waits while the casting reveal is open (never covers the card), slides below the special-event
-- banner when that one is up, and merges a burst of 3+ pulls into one line. The puller only gets a
-- chat line: they already have the reveal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Actors = require(ReplicatedStorage.Shared.Actors)
local PullNews = require(ReplicatedStorage.Shared.PullNews)
local SpecialEventsUi = require(script.Parent.SpecialEventsUi)
local UiKit = require(script.Parent.UiKit)

local TOP = 168 -- under the HUD top stack, where the old banner sat
local HEIGHT = 36
local GAP = 6
local QUEUE_MAX = 8
local HOLD = { news = 5, pull = 3.5 }

type Item = { text: string, kind: string, tier: string?, name: string? }

local Announcements = {}

function Announcements.start(gui: ScreenGui, remotes: Instance)
	local queue: { Item } = {}
	local wake = Instance.new("BindableEvent")

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Size = UDim2.new(0.9, 0, 0, HEIGHT)
	banner.Position = UDim2.new(0.5, 0, 0, TOP)
	banner.Visible = false
	banner.ZIndex = 9 -- over the special-event banner (7), under the casting reveal (10)
	banner.Parent = gui
	UiKit.corner(banner, 12)
	local stroke = UiKit.border(banner, 3, UiKit.GOLD)
	local rainbow = Instance.new("UIGradient")
	rainbow.Color = UiKit.RAINBOW
	rainbow.Parent = stroke
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, HEIGHT)
	limit.Parent = banner
	local pop = Instance.new("UIScale")
	pop.Parent = banner
	local label = UiKit.makeTitle(banner, "", UiKit.WHITE, UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	label.ZIndex = 10
	UiKit.textConstraint(label, 24)

	local function push(item: Item)
		if #queue >= QUEUE_MAX then
			table.remove(queue, 1)
		end
		table.insert(queue, item)
		wake:Fire()
	end

	local function revealOpen(): boolean
		local reveal = gui:FindFirstChild("Reveal")
		return reveal ~= nil and reveal:IsA("GuiObject") and reveal.Visible
	end

	-- Below the special-event banner when the two would overlap (it sits at 30% of the height).
	local function place()
		local y = TOP
		local event = gui:FindFirstChild("SpecialEvent")
		if event ~= nil and event:IsA("GuiObject") and event.Visible then
			local top = event.AbsolutePosition.Y - gui.AbsolutePosition.Y
			local bottom = top + event.AbsoluteSize.Y
			if top < TOP + HEIGHT and bottom > TOP then
				y = bottom + GAP
			end
		end
		banner.Position = UDim2.new(0.5, 0, 0, y)
	end

	local function show(item: Item)
		local tier = if item.tier ~= nil then Actors.getTier(item.tier) else nil
		label.Text = item.text
		if tier ~= nil then
			banner.BackgroundColor3 = tier.color:Lerp(UiKit.NAVY, 0.45)
			stroke.Color = if tier.id == "Icon" then UiKit.WHITE else tier.color
			rainbow.Enabled = tier.id == "Icon"
		else
			banner.BackgroundColor3 = UiKit.RED
			stroke.Color = UiKit.GOLD
			rainbow.Enabled = false
		end
		place()
		pop.Scale = 0.6
		banner.Visible = true
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.wait(HOLD[item.kind] or 4)
		local out = TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		out:Play()
		out.Completed:Wait()
		banner.Visible = false
	end

	task.spawn(function()
		while true do
			if #queue == 0 then
				wake.Event:Wait()
			end
			while revealOpen() do
				task.wait(0.25)
			end
			-- A burst: every waiting pull becomes one line.
			local pulls: { PullNews.Entry } = {}
			for _, item in queue do
				if item.kind == "pull" and item.name ~= nil and item.tier ~= nil then
					table.insert(pulls, { name = item.name, tier = item.tier })
				end
			end
			if #pulls >= 3 then
				local text, best = PullNews.merge(pulls)
				for index = #queue, 1, -1 do
					if queue[index].kind == "pull" then
						table.remove(queue, index)
					end
				end
				show({ text = text, kind = "pull", tier = best })
			else
				show(table.remove(queue, 1) :: Item)
			end
		end
	end)

	local announce = remotes:WaitForChild("Announce", 10)
	if announce ~= nil and announce:IsA("RemoteEvent") then
		announce.OnClientEvent:Connect(function(text)
			if type(text) == "string" then
				push({ text = text, kind = "news" })
			end
		end)
	end

	local rarePull = remotes:WaitForChild("RarePull", 10)
	if rarePull == nil or not rarePull:IsA("RemoteEvent") then
		warn("[Announcements] RarePull remote never arrived")
		return
	end
	rarePull.OnClientEvent:Connect(function(userId, name, actorId, variantId, global)
		if type(userId) ~= "number" or type(name) ~= "string" or type(actorId) ~= "string" or type(variantId) ~= "string" then
			return
		end
		local actor, variant = Actors.getActor(actorId), Actors.getVariant(variantId)
		if actor == nil or variant == nil then
			return
		end
		local isGlobal = global == true
		local mine = userId == Players.LocalPlayer.UserId
		SpecialEventsUi.chat(PullNews.text(if mine then nil else name, actor, variant, isGlobal))
		if not mine or isGlobal then
			push({ text = PullNews.text(name, actor, variant, isGlobal), kind = "pull", tier = actor.tier, name = name })
		end
	end)
end

return Announcements
