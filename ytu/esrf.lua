-- Robust Roblox Client-Side UI Layout Manager (Fixed + Improved)
-- SeasonPassUI deep-scanning + nested frame resizing + bigger SeasonPass UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.2
local UI_SCALE = 0.76
local SCROLL_PAUSE_TIME = 1.2

local function debug(...) end

-------------------------------------------------------
-- FIND & REGISTER UI
-------------------------------------------------------

local foundUIs = {}

local function tryAddUI(ui)
	for _, name in ipairs(UI_NAMES) do
		if ui.Name == name then
			if not table.find(foundUIs, ui) then
				table.insert(foundUIs, ui)

				if ui:IsA("ScreenGui") then
					ui.Enabled = true
					ui.ResetOnSpawn = false
					ui.IgnoreGuiInset = false
				end

				debug("Added UI:", ui.Name)
			end
		end
	end
end

for _, name in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(name)
	if ui then tryAddUI(ui) end
end

playerGui.ChildAdded:Connect(function(c)
	tryAddUI(c)
end)

-------------------------------------------------------
-- UI CORNER POSITIONS
-------------------------------------------------------

local cornerPositions = {
	{anchor = Vector2.new(0, 0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)},
	{anchor = Vector2.new(1, 0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)},
	{anchor = Vector2.new(0, 1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)},
	{anchor = Vector2.new(1, 1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)},
}

-------------------------------------------------------
-- DEEP LAYOUT FOR ALL NESTED CHILDREN (IMPORTANT FIX)
-------------------------------------------------------

local function applyLayoutToDescendants(ui, corner, uiWidth, uiHeight)
	local extraScale = 1
	if ui.Name == "SeasonPassUI" then
		extraScale = 1.7 -- make SeasonPass UI 70% larger
	end

	for _, obj in ipairs(ui:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("ImageLabel") or obj:IsA("ScrollingFrame") then
			obj.Visible = true
			obj.AnchorPoint = corner.anchor
			obj.Position = corner.position
			obj.Size = UDim2.new(0, uiWidth, 0, uiHeight)

			local sc = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", obj)
			sc.Scale = UI_SCALE * extraScale
		end
	end
end

-------------------------------------------------------
-- ARRANGE UI WINDOWS
-------------------------------------------------------

local function arrangeUIs()
	local cam = workspace.CurrentCamera
	if not cam then return end

	local viewport = cam.ViewportSize
	local uiWidth = math.floor(viewport.X * 0.35)
	local uiHeight = math.floor(viewport.Y * 0.45)

	for idx, ui in ipairs(foundUIs) do
		local corner = cornerPositions[((idx - 1) % #cornerPositions) + 1]
		applyLayoutToDescendants(ui, corner, uiWidth, uiHeight)
	end
end

arrangeUIs()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)

-------------------------------------------------------
-- MANAGED SCROLL FRAMES
-------------------------------------------------------

local managedFrames = {}

local function addFrame(sf)
	for _, e in ipairs(managedFrames) do
		if e.frame == sf then return end
	end

	local layout = sf:FindFirstChildOfClass("UIListLayout") or sf:FindFirstChildOfClass("UIPageLayout")

	table.insert(managedFrames, {
		frame = sf,
		listLayout = layout
	})

	sf.ScrollingEnabled = true
	sf.ScrollBarThickness = 8

	debug("Added ScrollingFrame:", sf:GetFullName())
end

-------------------------------------------------------
-- RESCAN ALL (FOR SEASONPASS NESTED FIX)
-------------------------------------------------------

local function rescanAll()
	for _, ui in ipairs(foundUIs) do
		for _, obj in ipairs(ui:GetDescendants()) do
			if obj:IsA("ScrollingFrame") then
				addFrame(obj)
			end
		end
	end
end

rescanAll()

task.spawn(function()
	while true do
		rescanAll()
		task.wait(1)
	end
end)

-------------------------------------------------------
-- AUTO SCROLL LOGIC
-------------------------------------------------------

local function getContentHeight(entry)
	local f = entry.frame
	if not f then return 0 end

	if entry.listLayout then
		return entry.listLayout.AbsoluteContentSize.Y
	end

	local off = f.CanvasSize.Y.Offset or 0
	local sc = f.CanvasSize.Y.Scale or 0
	return off + sc * f.AbsoluteSize.Y
end

local function getMaxScroll(entry)
	local f = entry.frame
	if not f then return 0 end
	if f.AbsoluteSize.Y <= 0 then return 0 end
	return math.max(0, getContentHeight(entry) - f.AbsoluteSize.Y)
end

local function progressToY(progress, entry)
	local maxScroll = getMaxScroll(entry)
	if maxScroll <= 0 then return 0 end
	progress = math.clamp(progress, 0, 1)
	return math.floor(maxScroll * progress)
end

local scrollDirection = 1
local scrollProgress = 0
local isPaused = false
local pauseTimer = 0

RunService.RenderStepped:Connect(function(dt)
	if #managedFrames == 0 then return end

	if isPaused then
		pauseTimer += dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			isPaused = false
			pauseTimer = 0
			scrollDirection *= -1
		else
			return
		end
	end

	local spd = SCROLL_SPEED * 0.25
	scrollProgress += dt * scrollDirection * spd

	if scrollProgress >= 1 then
		scrollProgress = 1
		isPaused = true
	elseif scrollProgress <= 0 then
		scrollProgress = 0
		isPaused = true
	end

	for _, entry in ipairs(managedFrames) do
		local f = entry.frame
		if f and f.Parent and f.AbsoluteSize.Y > 0 then
			local maxScroll = getMaxScroll(entry)
			if maxScroll > 0 then
				local y = progressToY(scrollProgress, entry)
				f.CanvasPosition = Vector2.new(0, y)
			end
		end
	end
end)

debug("UI Auto-scroll manager loaded.")
