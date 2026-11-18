--!nocheck
--[[
	Fecurity UI Library
	Single-file Roblox UI library. No uploaded images are required: every icon is drawn in code.

	Quick start (ModuleScript, or anything that gives you the returned table):

		local Library = require(path.to.Fecurity)

		local Window = Library:CreateWindow({
			ToggleKey = Enum.KeyCode.RightShift, -- optional
			Scale = 0.8,                         -- optional, 0.5 to 2
		})

		local Tab = Window:Tab({ Name = "VISUALS", Icon = "Target" })
		local Panel = Tab:Panel("PLAYERS")      -- up to 3 panels per tab

		local Enabled = Panel:Toggle({
			Name = "Enabled",
			Description = "Optional second line",
			Default = false,
			Flag = "PlayersEnabled",
			Callback = function(value) print(value) end,
		})

		Panel:Slider({ Name = "Maximum Distance", Min = 0, Max = 500, Default = 114, Decimals = 0, Suffix = " feets" })
		Panel:Section("PLANTED C4")
		Panel:Dropdown({ Name = "Display type", Description = "Select type to display", Options = { "Box", "Text" } })
		Panel:Dropdown({ Name = "Display info", Options = { "Timer", "Damage" }, Multi = true })

		Library:Notify({ Title = "FECURITY", Text = "This is how a notification looks.", Duration = 10 })

		Library:Demo()  -- builds the complete reference layout

	Every control returns an object with :Set(value), :Get() and .Value.
	Built-in icons: Skull, Target, Gear, Pencil, Code, Folder. An "rbxassetid://..." string also works.
	Library:GetConfig() returns all flags. Library:LoadConfig(table) applies them.
	Scale resizes everything, text and icons included. 1 is the exact size of the reference image, and the default is 0.8.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Library = {
	Flags = {},
	Elements = {},
	Windows = {},
	Icons = {},
	Theme = {
		Font = "rbxassetid://12187365364", -- Inter
		Accent = Color3.fromRGB(116, 111, 246),
		Window = Color3.fromRGB(18, 18, 18),
		Sidebar = Color3.fromRGB(20, 20, 20),
		TabActive = Color3.fromRGB(30, 30, 30),
		Panel = Color3.fromRGB(20, 20, 20),
		Border = Color3.fromRGB(77, 77, 77),
		Divider = Color3.fromRGB(64, 64, 64),
		ControlOff = Color3.fromRGB(38, 38, 38),
		KnobOff = Color3.fromRGB(94, 94, 94),
		SliderTrack = Color3.fromRGB(61, 61, 61),
		Dropdown = Color3.fromRGB(44, 44, 44),
		DropdownHover = Color3.fromRGB(52, 52, 52),
		Icon = Color3.fromRGB(150, 150, 150),
		TextOn = Color3.fromRGB(255, 255, 255),
		TextOff = Color3.fromRGB(183, 183, 183),
		TextDim = Color3.fromRGB(176, 176, 176),
		TextTab = Color3.fromRGB(176, 176, 176),
		TextTabHover = Color3.fromRGB(220, 220, 220),
		TextDropdown = Color3.fromRGB(204, 204, 204),
		Chevron = Color3.fromRGB(135, 135, 135),
		Notification = Color3.fromRGB(20, 20, 20),
		NotificationTrack = Color3.fromRGB(38, 38, 38),
	},
}

-- Every measurement in one place, written at Scale 1. Controls read the scaled copy in Metrics.
local DEFAULT_SCALE = 0.8
local Design = {
	Pad = 23,              -- window edge to panel, and panel to panel
	SidebarW = 105,
	PanelW = 320,
	PanelH = 613,
	Inset = 21,            -- panel inner edge to content

	LogoY = 29,
	TabsY = 103,
	TabH = 88,
	TabIconY = 17,
	TabTextY = 56,

	TitleH = 26,
	TitleGap = 31,         -- panel title to first item
	SectionAbove = 32,     -- previous item to a section heading
	SectionBelow = 27,     -- section heading to next item
	ItemGap = 25,          -- between ordinary items

	RowH = 26,
	RowTallH = 33,
	SliderH = 40,
	DropdownH = 82,

	ToggleW = 44,
	ToggleH = 26,
	KnobInset = 3,
	ToggleGap = 8,

	SliderTrackH = 3,
	SliderTrackY = 32,
	SliderHitPad = 4,

	DropdownBoxY = 45,
	DropdownBoxH = 37,
	DropdownInset = 15,
	DropdownRowH = 33,
	DropdownTextY = 10,
	DropdownTextH = 18,
	ChevronW = 12,
	ChevronY = 15,
	ChevronSpace = 21,
	PopupGap = 4,
	PopupTextY = 8,

	ScrollbarW = 2,
	ThumbMin = 24,
	GripW = 10,

	NotifyW = 385,
	NotifyH = 101,
	NotifyGap = 17,
	NotifyTextX = 25,
	NotifyTimeInset = 20,
	NotifyBarInset = 13,
	NotifyBarH = 3,
	NotifyTitleY = 18,
	NotifyTitleH = 22,
	NotifyBodyY = 46,
	NotifyBodyH = 20,
	NotifyTimeW = 60,

	IconSize = 29,
	LogoImageY = 38,
	TabTextH = 18,

	CaptionY = -2,         -- name line of a two-line item
	CaptionH = 20,
	DescriptionY = 21,
	DescriptionH = 18,
	RowTextY = 5,          -- name line of a one-line item
	TitleTextY = 5,
	SectionTextY = 4,
	ValueY = -1,
	ValueW = 90,

	FontLabel = 17,
	FontTitle = 16,
	FontDescription = 15,
	FontValue = 16,
	FontTab = 14,
	FontDropdown = 15,
	FontNotifyTitle = 17,
	FontNotifyBody = 15,
}

local Metrics = {}

local function applyScale(scale)
	local function px(value)
		return math.floor(value * scale + 0.5)
	end

	for key, value in Design do
		Metrics[key] = px(value)
	end
	Metrics.Scale = scale
	Metrics.DropdownMaxRows = 6
	Metrics.ScrollbarInset = 1
	Metrics.ScrollbarW = math.max(2, Metrics.ScrollbarW)
	Metrics.SliderTrackH = math.max(2, Metrics.SliderTrackH)
	Metrics.NotifyBarH = math.max(2, Metrics.NotifyBarH)

	-- Sizes that must stay in step are derived, so rounding can never make the padding uneven.
	Metrics.ContentW = Metrics.PanelW - 2 - Metrics.Inset * 2
	Metrics.WindowW = Metrics.SidebarW + 1 + Metrics.Pad * 4 + Metrics.PanelW * 3
	Metrics.WindowH = Metrics.PanelH + Metrics.Pad * 2
	Metrics.Knob = Metrics.ToggleH - Metrics.KnobInset * 2

	local knob = px(17)
	if (knob - Metrics.SliderTrackH) % 2 ~= 0 then
		knob += 1 -- the same parity as the track keeps the knob exactly centred on it
	end
	Metrics.SliderKnob = knob
	Metrics.SliderKnobY = Metrics.SliderTrackY - (knob - Metrics.SliderTrackH) / 2
end

applyScale(DEFAULT_SCALE)

local FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tween(object, info, goal)
	local animation = TweenService:Create(object, info, goal)
	animation:Play()
	return animation
end

local function new(class, properties)
	local object = Instance.new(class)
	local parent = properties.Parent
	properties.Parent = nil
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function fontOf(weight)
	return Font.new(Library.Theme.Font, weight)
end

local function frame(parent, x, y, w, h, color, extra)
	local properties = {
		Parent = parent,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BorderSizePixel = 0,
		BackgroundColor3 = color or Color3.new(),
		BackgroundTransparency = color and 0 or 1,
	}
	if extra then
		for key, value in extra do
			properties[key] = value
		end
	end
	return new("Frame", properties)
end

-- Text is always top-left aligned on whole pixels unless a control asks otherwise, which keeps it sharp.
local function label(parent, x, y, w, h, text, size, weight, color, extra)
	local properties = {
		Parent = parent,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextSize = size,
		FontFace = fontOf(weight),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	if extra then
		for key, value in extra do
			properties[key] = value
		end
	end
	return new("TextLabel", properties)
end

local function hitbox(parent, x, y, w, h)
	return new("TextButton", {
		Parent = parent,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
	})
end

local function pill(object)
	new("UICorner", { Parent = object, CornerRadius = UDim.new(1, 0) })
	return object
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function contains(object, point)
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	return point.X >= position.X and point.X < position.X + size.X and point.Y >= position.Y and point.Y < position.Y + size.Y
end

local function fire(callback, ...)
	if callback then
		task.spawn(callback, ...)
	end
end

----------------------------------------------------------------------------------------------------
-- Icons: small vector shapes turned into antialiased runs of 1px-tall frames.
----------------------------------------------------------------------------------------------------

local SAMPLES = 4

local function bounds(points, pad)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for index = 1, #points, 2 do
		minX, maxX = math.min(minX, points[index]), math.max(maxX, points[index])
		minY, maxY = math.min(minY, points[index + 1]), math.max(maxY, points[index + 1])
	end
	return minX - pad, minY - pad, maxX + pad, maxY + pad
end

local function circle(x, y, radius)
	local squared = radius * radius
	return {
		MinX = x - radius, MinY = y - radius, MaxX = x + radius, MaxY = y + radius,
		Test = function(px, py)
			return (px - x) ^ 2 + (py - y) ^ 2 <= squared
		end,
	}
end

local function ring(x, y, radius, width)
	local inner, outer = (radius - width / 2) ^ 2, (radius + width / 2) ^ 2
	return {
		MinX = x - radius - width, MinY = y - radius - width, MaxX = x + radius + width, MaxY = y + radius + width,
		Test = function(px, py)
			local distance = (px - x) ^ 2 + (py - y) ^ 2
			return distance >= inner and distance <= outer
		end,
	}
end

local function path(width, closed, points)
	local limit = (width / 2) ^ 2
	local minX, minY, maxX, maxY = bounds(points, width / 2)
	local count = #points
	local segments = closed and count / 2 or count / 2 - 1
	return {
		MinX = minX, MinY = minY, MaxX = maxX, MaxY = maxY,
		Test = function(px, py)
			for segment = 0, segments - 1 do
				local ax, ay = points[segment * 2 + 1], points[segment * 2 + 2]
				local nextIndex = (segment + 1) * 2 % count
				local bx, by = points[nextIndex + 1], points[nextIndex + 2]
				local dx, dy = bx - ax, by - ay
				local t = math.clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
				if (px - ax - dx * t) ^ 2 + (py - ay - dy * t) ^ 2 <= limit then
					return true
				end
			end
			return false
		end,
	}
end

local function polygon(points, cut)
	local minX, minY, maxX, maxY = bounds(points, 0)
	local count = #points
	return {
		Cut = cut,
		MinX = minX, MinY = minY, MaxX = maxX, MaxY = maxY,
		Test = function(px, py)
			local inside = false
			local jx, jy = points[count - 1], points[count]
			for index = 1, count, 2 do
				local ix, iy = points[index], points[index + 1]
				if (iy > py) ~= (jy > py) and px < (jx - ix) * (py - iy) / (jy - iy) + ix then
					inside = not inside
				end
				jx, jy = ix, iy
			end
			return inside
		end,
	}
end

local function gearOutline(centre, teeth, outer, root)
	local points = {}
	for tooth = 0, teeth - 1 do
		local angle = math.rad(tooth * 360 / teeth - 90)
		for _, corner in { { -30, root }, { -15, outer }, { 15, outer }, { 30, root } } do
			local a = angle + math.rad(corner[1])
			table.insert(points, centre + math.cos(a) * corner[2])
			table.insert(points, centre + math.sin(a) * corner[2])
		end
	end
	return points
end

local function icon(width, height, shapes)
	return { Width = width, Height = height, Shapes = shapes }
end

Library.Icons.Logo = icon(50, 47, {
	polygon({ 22.5,1, 22.8,10.4, 32.4,13.6, 36.5,18.3, 48.4,21.7, 44.9,30.8, 29.6,33.9, 33.1,45.4, 17.8,35.3, 1,46, 4.3,31.8, 1.8,32, 5.9,19.8, 8.4,16.4 }),
	polygon({ 23.7,15.3, 30.9,17.3, 29.6,18.6, 26.2,18.9 }, true),
	polygon({ 17.8,37.3, 28.7,46, 6.5,46 }),
})

Library.Icons.Skull = icon(29, 29, {
	path(2.4, true, { 8.5,20.5, 7.2,17.5, 6.3,14, 6.2,11, 7,8, 9,5.6, 11.5,4.3, 14.5,3.9, 17.5,4.3, 20,5.6, 22,8, 22.8,11, 22.7,14, 21.8,17.5, 20.5,20.5, 20.3,23, 18.5,24.7, 10.5,24.7, 8.7,23 }),
	circle(11.8, 12.8, 2.3),
	circle(17.8, 12.8, 2.3),
	circle(14.5, 16.7, 1.1),
	path(1.7, false, { 12,20, 17.5,20 }),
})

Library.Icons.Target = icon(29, 29, {
	ring(14.5, 14.5, 10.7, 2.6),
	ring(14.5, 14.5, 3.5, 2.4),
})

Library.Icons.Gear = icon(29, 29, {
	path(2, true, gearOutline(14.5, 6, 10.4, 7.6)),
	ring(14.5, 14.5, 3.1, 1.9),
})

Library.Icons.Pencil = icon(29, 29, {
	path(2.2, true, { 3.7,25.2, 4.7,19.2, 17.2,6.9, 22.1,11.7, 9.5,24.2 }),
	path(2.2, false, { 20.4,3.9, 24.9,8.5 }),
})

Library.Icons.Code = icon(29, 29, {
	path(2, false, { 14.7,4.7, 14.7,24.3 }),
	path(2, false, { 10.4,10.4, 4.7,14.7, 10.4,19.7 }),
	path(2, false, { 18.3,10.4, 24.4,14.7, 18.3,19.7 }),
})

Library.Icons.Folder = icon(29, 29, {
	path(2.4, true, { 6.5,5.9, 10.7,5.9, 13.7,8.9, 22.5,8.9, 24.5,10.9, 24.5,21, 22.5,23, 6.5,23, 4.5,21, 4.5,7.9 }),
})

Library.Icons.ChevronDown = icon(13, 8, { path(2, false, { 1.2,1.2, 6.5,6.3, 11.8,1.2 }) })
Library.Icons.ChevronUp = icon(13, 8, { path(2, false, { 1.2,6.8, 6.5,1.7, 11.8,6.8 }) })

local function iconPixels(size)
	return math.ceil(size * Metrics.Scale)
end

local function bake(definition)
	local scale = Metrics.Scale
	if definition.Runs and definition.RunsScale == scale then
		return definition.Runs
	end
	local runs = {}
	local shapes = definition.Shapes
	local step = 1 / SAMPLES
	local width, height = iconPixels(definition.Width), iconPixels(definition.Height)
	for py = 0, height - 1 do
		local start, level = 0, 0
		for px = 0, width do
			local hits = 0
			if px < width then
				for sy = 0, SAMPLES - 1 do
					local y = (py + (sy + 0.5) * step) / scale
					for sx = 0, SAMPLES - 1 do
						local x = (px + (sx + 0.5) * step) / scale
						local inside = false
						for _, shape in shapes do
							if x >= shape.MinX and x <= shape.MaxX and y >= shape.MinY and y <= shape.MaxY and shape.Test(x, y) then
								inside = not shape.Cut
							end
						end
						if inside then
							hits += 1
						end
					end
				end
			end
			if hits ~= level then
				if level > 0 then
					table.insert(runs, { start, py, px - start, 1 - level / (SAMPLES * SAMPLES) })
				end
				start, level = px, hits
			end
		end
	end
	definition.Runs, definition.RunsScale = runs, scale
	return runs
end

-- Returns a handle with .Frame and :SetColor(color, animated).
local function drawIcon(parent, source, x, y, color)
	if type(source) == "string" and source:find("rbxasset") then
		local image = new("ImageLabel", {
			Parent = parent,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(Metrics.IconSize, Metrics.IconSize),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = source,
			ImageColor3 = color,
		})
		return {
			Frame = image,
			SetColor = function(_, value, animated)
				if animated then
					tween(image, FAST, { ImageColor3 = value })
				else
					image.ImageColor3 = value
				end
			end,
		}
	end

	local definition = type(source) == "table" and source or Library.Icons[source]
	assert(definition and definition.Shapes, "Unknown icon: " .. tostring(source))
	local holder = frame(parent, x, y, iconPixels(definition.Width), iconPixels(definition.Height))
	local pixels = {}
	for _, run in bake(definition) do
		table.insert(pixels, frame(holder, run[1], run[2], run[3], 1, color, { BackgroundTransparency = run[4] }))
	end
	return {
		Frame = holder,
		SetColor = function(_, value, animated)
			for _, pixel in pixels do
				if animated then
					tween(pixel, FAST, { BackgroundColor3 = value })
				else
					pixel.BackgroundColor3 = value
				end
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Shared runtime: ScreenGui, pointer, hover, dropdown popups, notifications.
----------------------------------------------------------------------------------------------------

local Runtime = { Connections = {}, Hover = {}, Notifications = {}, Popup = nil, Swallow = false }

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Runtime.Connections, connection)
	return connection
end

local function pointer()
	local mouse = UserInputService:GetMouseLocation()
	local origin = Runtime.Gui.AbsolutePosition
	return Vector2.new(mouse.X + origin.X, mouse.Y + origin.Y)
end

local function addHover(object, callback)
	local entry = { Object = object, Callback = callback, Inside = false }
	Runtime.Hover[entry] = true
	return entry
end

local function closePopup()
	local popup = Runtime.Popup
	if popup then
		Runtime.Popup = nil
		popup.OnClose()
	end
end

local function swallowClick()
	Runtime.Swallow = true
	task.delay(0.05, function()
		Runtime.Swallow = false
	end)
end

local function blocked()
	return Runtime.Swallow or Runtime.Popup ~= nil
end

local function ensureRuntime(parent)
	if Runtime.Gui then
		return
	end
	Runtime.Gui = new("ScreenGui", {
		Name = "Fecurity",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Runtime.Overlay = frame(Runtime.Gui, 0, 0, 0, 0, nil, { ZIndex = 50 })
	Runtime.Holder = new("Frame", {
		Parent = Runtime.Gui,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Metrics.Pad, 0, Metrics.Pad),
		Size = UDim2.fromOffset(Metrics.NotifyW, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 60,
	})
	Library.NotificationHolder = Runtime.Holder

	connect(UserInputService.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and next(Runtime.Hover) then
			local point = pointer()
			for entry in Runtime.Hover do
				local inside = entry.Object.Visible and contains(entry.Object, point)
				if inside ~= entry.Inside then
					entry.Inside = inside
					entry.Callback(inside)
				end
			end
		end
	end)

	connect(UserInputService.InputBegan, function(input)
		local popup = Runtime.Popup
		if popup and isPress(input) then
			local point = pointer()
			if not contains(popup.Frame, point) and not contains(popup.Owner, point) then
				closePopup()
				swallowClick()
			end
		end
	end)
end

local function notifyTarget(index)
	return UDim2.fromOffset(0, (index - 1) * (Metrics.NotifyH + Metrics.NotifyGap))
end

local function restackNotifications()
	for index, notification in Runtime.Notifications do
		tween(notification.Frame, SLIDE, { Position = notifyTarget(index) })
	end
end

local function dismissNotification(notification)
	local list = Runtime.Notifications
	local index = table.find(list, notification)
	if not index then
		return
	end
	table.remove(list, index)
	restackNotifications()
	local gone = UDim2.fromOffset(notification.Offscreen, notification.Frame.Position.Y.Offset)
	local animation = tween(notification.Frame, SLIDE, { Position = gone })
	animation.Completed:Connect(function()
		notification.Frame:Destroy()
	end)
end

local function stepNotifications(dt)
	local list = Runtime.Notifications
	for index = #list, 1, -1 do
		local notification = list[index]
		notification.Remaining = math.max(0, notification.Remaining - dt)
		local text = string.format("%.1f", notification.Remaining)
		if text ~= notification.Time.Text then
			notification.Time.Text = text
		end
		local width = math.floor(notification.Remaining / notification.Duration * notification.BarWidth + 0.5)
		if width ~= notification.Fill.Size.X.Offset then
			notification.Fill.Size = UDim2.fromOffset(width, Metrics.NotifyBarH)
		end
		if notification.Remaining <= 0 then
			dismissNotification(notification)
		end
	end
	if #list == 0 and Runtime.NotifyLoop then
		Runtime.NotifyLoop:Disconnect()
		Runtime.NotifyLoop = nil
	end
end

--[[ Library:Notify({ Title = string, Text = string, Duration = seconds }) ]]
function Library:Notify(options)
	ensureRuntime(options.Parent)
	local M, T = Metrics, Library.Theme
	local duration = options.Duration or 5
	local viewportWidth = Runtime.Gui.AbsoluteSize.X
	local offscreen = math.max(M.NotifyW, viewportWidth - Runtime.Holder.AbsolutePosition.X) + 16

	local card = frame(Runtime.Holder, offscreen, 0, M.NotifyW, M.NotifyH, T.Notification)
	local textW = M.NotifyW - M.NotifyTextX - M.NotifyTimeInset
	label(card, M.NotifyTextX, M.NotifyTitleY, textW - M.NotifyTimeW, M.NotifyTitleH, options.Title or "Notification", M.FontNotifyTitle, Enum.FontWeight.SemiBold, T.TextOn)
	label(card, M.NotifyTextX, M.NotifyBodyY, textW, M.NotifyBodyH, options.Text or "", M.FontNotifyBody, Enum.FontWeight.Medium, T.TextOff)
	local time = label(card, M.NotifyW - M.NotifyTimeInset - M.NotifyTimeW, M.NotifyTitleY, M.NotifyTimeW, M.NotifyTitleH, string.format("%.1f", duration), M.FontNotifyTitle, Enum.FontWeight.SemiBold, T.Accent, {
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local track = frame(card, M.NotifyBarInset, M.NotifyH - M.NotifyBarInset - M.NotifyBarH, M.NotifyW - M.NotifyBarInset * 2, M.NotifyBarH, T.NotificationTrack)
	local barWidth = M.NotifyW - M.NotifyBarInset * 2
	local fill = frame(track, 0, 0, barWidth, M.NotifyBarH, T.Accent)

	local notification = { Frame = card, Time = time, Fill = fill, BarWidth = barWidth, Duration = duration, Remaining = duration, Offscreen = offscreen }
	table.insert(Runtime.Notifications, 1, notification)
	restackNotifications()
	if not Runtime.NotifyLoop then
		Runtime.NotifyLoop = connect(RunService.RenderStepped, stepNotifications)
	end

	return {
		Frame = card,
		Dismiss = function()
			dismissNotification(notification)
		end,
	}
end

--[[ Library:SetScale(number): call before creating a window. 1 is the reference size, 0.5 to 2 is allowed. ]]
function Library:SetScale(scale)
	assert(type(scale) == "number" and scale >= 0.5 and scale <= 2, "Scale must be a number from 0.5 to 2")
	if scale == Metrics.Scale then
		return
	end
	assert(#Library.Windows == 0 and #Runtime.Notifications == 0, "Set the scale before creating a window or notification")
	applyScale(scale)
	if Runtime.Holder then
		Runtime.Holder.Size = UDim2.fromOffset(Metrics.NotifyW, 0)
		if Runtime.Holder.AnchorPoint.X == 1 then
			Runtime.Holder.Position = UDim2.new(1, -Metrics.Pad, 0, Metrics.Pad)
		end
	end
end

function Library:SetNotificationPosition(x, y)
	ensureRuntime()
	Runtime.Holder.AnchorPoint = Vector2.new(0, 0)
	Runtime.Holder.Position = UDim2.fromOffset(x, y)
end

----------------------------------------------------------------------------------------------------
-- Panel controls
----------------------------------------------------------------------------------------------------

local Panel = {}
Panel.__index = Panel

local function register(control, flag)
	control.Flag = flag
	if flag then
		Library.Elements[flag] = control
		Library.Flags[flag] = control.Value
	end
end

local function publish(control)
	if control.Flag then
		Library.Flags[control.Flag] = control.Value
	end
end

function Panel:_place(height, gap)
	local y = self.Cursor + (gap or self.NextGap or Metrics.ItemGap)
	self.NextGap = nil
	self.Cursor = y + height
	self:_refresh()
	return y
end

function Panel:_refresh()
	local M = Metrics
	local viewH = self.Scroller.AbsoluteSize.Y
	if viewH <= 0 then
		viewH = M.PanelH - 2
	end
	local canvasH = self.Cursor + M.Inset
	self.Scroller.CanvasSize = UDim2.fromOffset(0, canvasH)
	local overflow = canvasH > viewH
	self.Thumb.Visible = overflow
	if overflow then
		local trackH = viewH - M.ScrollbarInset * 2
		local thumbH = math.max(M.ThumbMin, math.floor(trackH * viewH / canvasH))
		local progress = math.clamp(self.Scroller.CanvasPosition.Y / (canvasH - viewH), 0, 1)
		self.Thumb.Size = UDim2.fromOffset(M.ScrollbarW, thumbH)
		self.Thumb.Position = UDim2.fromOffset(M.PanelW - 2 - M.ScrollbarInset - M.ScrollbarW, M.ScrollbarInset + math.floor((trackH - thumbH) * progress))
	end
end

function Panel:_item(height, gap)
	local y = self:_place(height, gap)
	return frame(self.Scroller, Metrics.Inset, y, Metrics.ContentW, height)
end

local function addCaption(item, options, width)
	local M, T = Metrics, Library.Theme
	local name
	if options.Description then
		name = label(item, 0, M.CaptionY, width, M.CaptionH, options.Name, M.FontLabel, Enum.FontWeight.Medium, T.TextOn)
		label(item, 0, M.DescriptionY, width, M.DescriptionH, options.Description, M.FontDescription, Enum.FontWeight.Regular, T.TextDim)
	else
		name = label(item, 0, M.RowTextY, width, M.CaptionH, options.Name, M.FontLabel, Enum.FontWeight.Medium, T.TextOn)
	end
	return name
end

--[[ Panel:Section("HEADING") ]]
function Panel:Section(text)
	local M, T = Metrics, Library.Theme
	local y = self:_place(M.TitleH, M.SectionAbove)
	label(self.Scroller, M.Inset, y + M.SectionTextY, M.ContentW, M.CaptionH, text, M.FontTitle, Enum.FontWeight.Medium, T.TextDim)
	self.NextGap = M.SectionBelow
end

--[[ Panel:Spacer(pixels): extra empty space at the end of the panel, given at Scale 1. ]]
function Panel:Spacer(pixels)
	self.Cursor += math.floor(pixels * Metrics.Scale + 0.5)
	self:_refresh()
end

--[[ Panel:Toggle({ Name, Description?, Default?, Flag?, Callback? }) ]]
function Panel:Toggle(options)
	local M, T = Metrics, Library.Theme
	local height = options.Description and M.RowTallH or M.RowH
	local item = self:_item(height)
	local name = addCaption(item, options, M.ContentW - M.ToggleW - M.ToggleGap)
	local trackY = math.ceil((height - M.ToggleH) / 2)
	local track = pill(frame(item, M.ContentW - M.ToggleW, trackY, M.ToggleW, M.ToggleH, T.ControlOff))
	local knob = pill(frame(track, M.KnobInset, M.KnobInset, M.Knob, M.Knob, T.KnobOff))
	local button = hitbox(item, 0, 0, M.ContentW, height)

	local control = { Value = options.Default == true }

	local function paint(animated)
		local value = control.Value
		local x = value and M.ToggleW - M.KnobInset - M.Knob or M.KnobInset
		local knobGoal = { Position = UDim2.fromOffset(x, M.KnobInset), BackgroundColor3 = value and T.Accent or T.KnobOff }
		local textColor = value and T.TextOn or T.TextOff
		if animated then
			tween(knob, FAST, knobGoal)
			tween(name, FAST, { TextColor3 = textColor })
		else
			knob.Position = knobGoal.Position
			knob.BackgroundColor3 = knobGoal.BackgroundColor3
			name.TextColor3 = textColor
		end
	end

	function control:Set(value, silent)
		value = value == true
		if value == control.Value then
			return
		end
		control.Value = value
		publish(control)
		paint(true)
		if not silent then
			fire(options.Callback, value)
		end
	end

	function control:Get()
		return control.Value
	end

	button.MouseButton1Click:Connect(function()
		if not blocked() then
			control:Set(not control.Value)
		end
	end)

	paint(false)
	register(control, options.Flag)
	return control
end

--[[ Panel:Slider({ Name, Min, Max, Default?, Decimals?, Suffix?, Flag?, Callback? }) ]]
function Panel:Slider(options)
	local M, T = Metrics, Library.Theme
	local item = self:_item(M.SliderH)
	local minimum, maximum = options.Min or 0, options.Max or 100
	local decimals = options.Decimals or 0
	local suffix = options.Suffix or ""
	local step = 10 ^ -decimals

	label(item, 0, M.CaptionY, M.ContentW - M.ValueW, M.CaptionH, options.Name, M.FontLabel, Enum.FontWeight.Medium, T.TextOn)
	local valueText = label(item, M.ContentW - M.ValueW, M.ValueY, M.ValueW, M.CaptionH, "", M.FontValue, Enum.FontWeight.Medium, T.TextOn, {
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local track = frame(item, 0, M.SliderTrackY, M.ContentW, M.SliderTrackH, T.SliderTrack)
	local fill = frame(track, 0, 0, 0, M.SliderTrackH, T.Accent)
	local knob = pill(frame(item, 0, M.SliderKnobY, M.SliderKnob, M.SliderKnob, T.Accent))
	local button = hitbox(item, 0, M.SliderKnobY - M.SliderHitPad, M.ContentW, M.SliderKnob + M.SliderHitPad * 2)

	local control = { Value = nil }
	local travel = M.ContentW - M.SliderKnob

	local function clean(value)
		value = math.clamp(value, minimum, maximum)
		value = math.floor((value - minimum) / step + 0.5) * step + minimum
		value = tonumber(string.format("%." .. decimals .. "f", value))
		return math.clamp(value, minimum, maximum)
	end

	local function paint()
		local ratio = maximum > minimum and (control.Value - minimum) / (maximum - minimum) or 0
		local x = math.floor(ratio * travel + 0.5)
		knob.Position = UDim2.fromOffset(x, M.SliderKnobY)
		fill.Size = UDim2.fromOffset(x + math.floor(M.SliderKnob / 2), M.SliderTrackH)
		valueText.Text = string.format("%." .. decimals .. "f", control.Value) .. suffix
	end

	function control:Set(value, silent)
		value = clean(value)
		if value == control.Value then
			return
		end
		control.Value = value
		publish(control)
		paint()
		if not silent then
			fire(options.Callback, value)
		end
	end

	function control:Get()
		return control.Value
	end

	local function fromPointer(x)
		local ratio = math.clamp((x - track.AbsolutePosition.X - M.SliderKnob / 2) / travel, 0, 1)
		control:Set(minimum + (maximum - minimum) * ratio)
	end

	local dragging = false
	button.InputBegan:Connect(function(input)
		if isPress(input) and not blocked() then
			dragging = true
			fromPointer(input.Position.X)
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			fromPointer(input.Position.X)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragging = false
		end
	end)

	control.Value = clean(options.Default or minimum)
	paint()
	register(control, options.Flag)
	return control
end

--[[ Panel:Dropdown({ Name, Description?, Options, Default?, Multi?, Placeholder?, Flag?, Callback? })
	Single selection: Value is a string or nil. Multi selection: Value is an array of strings. ]]
function Panel:Dropdown(options)
	local M, T = Metrics, Library.Theme
	local description = options.Description or " "
	local item = self:_item(M.DropdownH)
	label(item, 0, M.CaptionY, M.ContentW, M.CaptionH, options.Name, M.FontLabel, Enum.FontWeight.Medium, T.TextOn)
	label(item, 0, M.DescriptionY, M.ContentW, M.DescriptionH, description, M.FontDescription, Enum.FontWeight.Regular, T.TextDim)

	local box = new("TextButton", {
		Parent = item,
		Position = UDim2.fromOffset(0, M.DropdownBoxY),
		Size = UDim2.fromOffset(M.ContentW, M.DropdownBoxH),
		BackgroundColor3 = T.Dropdown,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
	})
	local placeholder = options.Placeholder or "Not selected"
	local shown = label(box, M.DropdownInset, M.DropdownTextY, M.ContentW - M.DropdownInset * 2 - M.ChevronSpace, M.DropdownTextH, placeholder, M.FontDropdown, Enum.FontWeight.Regular, T.TextDropdown)
	local chevronX = M.ContentW - M.DropdownInset - M.ChevronW
	local down = drawIcon(box, "ChevronDown", chevronX, M.ChevronY, T.Chevron)
	local up = drawIcon(box, "ChevronUp", chevronX, M.ChevronY, T.Chevron)
	up.Frame.Visible = false

	local multi = options.Multi == true
	local control = { Value = multi and {} or nil, Options = options.Options or {} }
	local rows = {}

	local function isSelected(option)
		if multi then
			return table.find(control.Value, option) ~= nil
		end
		return control.Value == option
	end

	local function paintRows()
		for _, row in rows do
			row.Text.TextColor3 = isSelected(row.Option) and T.Accent or T.TextDropdown
		end
	end

	local function paint()
		if multi then
			shown.Text = #control.Value > 0 and table.concat(control.Value, ", ") or placeholder
		else
			shown.Text = control.Value or placeholder
		end
		paintRows()
	end

	local function commit(silent)
		publish(control)
		paint()
		if not silent then
			fire(options.Callback, control.Value)
		end
	end

	function control:Set(value, silent)
		if multi then
			control.Value = {}
			for _, option in value or {} do
				if table.find(control.Options, option) then
					table.insert(control.Value, option)
				end
			end
		else
			control.Value = table.find(control.Options, value) and value or nil
		end
		commit(silent)
	end

	function control:Get()
		return control.Value
	end

	function control:SetOptions(list)
		closePopup()
		control.Options = list
		control:Set(control.Value, true)
	end

	local function choose(option)
		if multi then
			local index = table.find(control.Value, option)
			if index then
				table.remove(control.Value, index)
			else
				local ordered = {}
				for _, candidate in control.Options do
					if candidate == option or table.find(control.Value, candidate) then
						table.insert(ordered, candidate)
					end
				end
				control.Value = ordered
			end
			commit()
		else
			control.Value = option
			commit()
			swallowClick()
			closePopup()
		end
	end

	local function open()
		local count = #control.Options
		local visibleRows = math.min(count, M.DropdownMaxRows)
		local height = visibleRows * M.DropdownRowH
		local origin = Runtime.Gui.AbsolutePosition
		local position = box.AbsolutePosition
		local popupY = position.Y - origin.Y + M.DropdownBoxH + M.PopupGap
		if popupY + height > Runtime.Gui.AbsoluteSize.Y then
			popupY = position.Y - origin.Y - M.PopupGap - height
		end
		local popup = new("ScrollingFrame", {
			Parent = Runtime.Overlay,
			Position = UDim2.fromOffset(position.X - origin.X, popupY),
			Size = UDim2.fromOffset(M.ContentW, height),
			CanvasSize = UDim2.fromOffset(0, count * M.DropdownRowH),
			BackgroundColor3 = T.Dropdown,
			BorderSizePixel = 0,
			ScrollBarThickness = count > M.DropdownMaxRows and M.ScrollbarW or 0,
			ScrollBarImageColor3 = T.Accent,
			Active = true,
		})
		new("UIStroke", { Parent = popup, Color = T.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

		local hovers = {}
		rows = {}
		for index, option in control.Options do
			local row = new("TextButton", {
				Parent = popup,
				Position = UDim2.fromOffset(0, (index - 1) * M.DropdownRowH),
				Size = UDim2.fromOffset(M.ContentW, M.DropdownRowH),
				BackgroundColor3 = T.DropdownHover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				Active = true,
			})
			local text = label(row, M.DropdownInset, M.PopupTextY, M.ContentW - M.DropdownInset * 2, M.DropdownTextH, option, M.FontDropdown, Enum.FontWeight.Regular, T.TextDropdown)
			table.insert(rows, { Option = option, Text = text })
			table.insert(hovers, addHover(row, function(inside)
				row.BackgroundTransparency = inside and 0 or 1
			end))
			row.MouseButton1Click:Connect(function()
				if not Runtime.Swallow then
					choose(option)
				end
			end)
		end
		paintRows()
		down.Frame.Visible, up.Frame.Visible = false, true

		Runtime.Popup = {
			Frame = popup,
			Owner = box,
			OnClose = function()
				for _, entry in hovers do
					Runtime.Hover[entry] = nil
				end
				rows = {}
				popup:Destroy()
				down.Frame.Visible, up.Frame.Visible = true, false
			end,
		}
	end

	addHover(box, function(inside)
		tween(box, FAST, { BackgroundColor3 = inside and T.DropdownHover or T.Dropdown })
	end)

	box.MouseButton1Click:Connect(function()
		if Runtime.Swallow then
			return
		end
		local current = Runtime.Popup
		if current and current.Owner == box then
			closePopup()
		elseif not current then
			open()
		end
	end)

	if options.Default ~= nil then
		control:Set(options.Default, true)
	end
	paint()
	register(control, options.Flag)
	return control
end

----------------------------------------------------------------------------------------------------
-- Tabs and windows
----------------------------------------------------------------------------------------------------

local Tab = {}
Tab.__index = Tab

--[[ Tab:Panel("TITLE"): adds the next of up to three columns. ]]
function Tab:Panel(title)
	local M, T = Metrics, Library.Theme
	local column = #self.Panels
	assert(column < 3, "A tab can hold at most 3 panels")

	local x = M.SidebarW + 1 + M.Pad + column * (M.PanelW + M.Pad)
	local shell = frame(self.Content, x + 1, M.Pad + 1, M.PanelW - 2, M.PanelH - 2, T.Panel)
	new("UIStroke", { Parent = shell, Color = T.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	local scroller = new("ScrollingFrame", {
		Parent = shell,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 0,
	})

	local thumb = frame(shell, 0, 0, M.ScrollbarW, M.ThumbMin, T.Accent, { ZIndex = 5, Visible = false })
	new("UIGradient", {
		Parent = thumb,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})

	local panel = setmetatable({
		Shell = shell,
		Scroller = scroller,
		Thumb = thumb,
		Cursor = M.Inset + M.TitleH,
		NextGap = M.TitleGap,
	}, Panel)

	label(scroller, M.Inset, M.Inset + M.TitleTextY, M.ContentW, M.CaptionH, title, M.FontTitle, Enum.FontWeight.Medium, T.TextDim)
	panel:_refresh()

	connect(scroller:GetPropertyChangedSignal("CanvasPosition"), function()
		closePopup()
		panel:_refresh()
	end)

	-- The thumb is a thin frame, so a wider invisible strip handles dragging it.
	local grip = hitbox(shell, M.PanelW - 2 - M.GripW, 0, M.GripW, M.PanelH - 2)
	grip.ZIndex = 6
	local dragStart, canvasStart
	grip.InputBegan:Connect(function(input)
		if isPress(input) and thumb.Visible and not blocked() then
			dragStart, canvasStart = input.Position.Y, scroller.CanvasPosition.Y
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragStart and isMove(input) then
			local viewH = scroller.AbsoluteSize.Y
			local canvasH = scroller.CanvasSize.Y.Offset
			local trackH = viewH - M.ScrollbarInset * 2
			local thumbH = thumb.Size.Y.Offset
			local scale = (canvasH - viewH) / math.max(1, trackH - thumbH)
			local y = math.clamp(canvasStart + (input.Position.Y - dragStart) * scale, 0, canvasH - viewH)
			scroller.CanvasPosition = Vector2.new(0, math.floor(y))
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragStart = nil
		end
	end)

	table.insert(self.Panels, panel)
	return panel
end

local Window = {}
Window.__index = Window

--[[ Window:Tab({ Name, Icon }): Icon is a built-in name or an "rbxassetid://..." string. ]]
function Window:Tab(options)
	local M, T = Metrics, Library.Theme
	local index = #self.Tabs
	local button = hitbox(self.TabList, 0, index * M.TabH, M.SidebarW, M.TabH)
	local background = frame(button, 0, 0, M.SidebarW, M.TabH, T.TabActive, { BackgroundTransparency = 1 })
	local iconHandle = drawIcon(button, options.Icon or "Target", math.floor((M.SidebarW - M.IconSize) / 2), M.TabIconY, T.Icon)
	local text = label(button, 0, M.TabTextY, M.SidebarW, M.TabTextH, options.Name, M.FontTab, Enum.FontWeight.Medium, T.TextTab, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	self.TabList.CanvasSize = UDim2.fromOffset(0, (index + 1) * M.TabH)

	local content = frame(self.Root, 0, 0, M.WindowW, M.WindowH, nil, { Visible = false })
	local tab = setmetatable({
		Window = self,
		Name = options.Name,
		Button = button,
		Background = background,
		Icon = iconHandle,
		Text = text,
		Content = content,
		Panels = {},
	}, Tab)

	addHover(button, function(inside)
		if self.Active ~= tab then
			tween(text, FAST, { TextColor3 = inside and T.TextTabHover or T.TextTab })
		end
	end)
	button.MouseButton1Click:Connect(function()
		if not blocked() then
			self:SelectTab(tab)
		end
	end)

	table.insert(self.Tabs, tab)
	if not self.Active then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(target)
	local T = Library.Theme
	if type(target) == "string" then
		for _, tab in self.Tabs do
			if tab.Name == target then
				target = tab
				break
			end
		end
	end
	assert(type(target) == "table", "Unknown tab")
	if self.Active == target then
		return
	end
	closePopup()
	local previous = self.Active
	if previous then
		previous.Content.Visible = false
		tween(previous.Background, FAST, { BackgroundTransparency = 1 })
		tween(previous.Text, FAST, { TextColor3 = T.TextTab })
		previous.Icon:SetColor(T.Icon, true)
	end
	self.Active = target
	target.Content.Visible = true
	tween(target.Background, FAST, { BackgroundTransparency = 0 })
	tween(target.Text, FAST, { TextColor3 = T.Accent })
	target.Icon:SetColor(T.Accent, true)
end

function Window:SetVisible(state)
	closePopup()
	self.Root.Visible = state
end

function Window:Toggle()
	self:SetVisible(not self.Root.Visible)
end

--[[ Library:CreateWindow({ Position?, ToggleKey?, Logo?, Parent?, Scale? }) ]]
function Library:CreateWindow(options)
	options = options or {}
	if options.Scale then
		Library:SetScale(options.Scale)
	end
	ensureRuntime(options.Parent)
	local M, T = Metrics, Library.Theme

	-- Centred by hand: an anchor of 0.5 lands on a half pixel whenever the sizes are odd, which blurs text.
	local screen = Runtime.Gui.AbsoluteSize
	local centred = UDim2.fromOffset(math.floor((screen.X - M.WindowW) / 2), math.floor((screen.Y - M.WindowH) / 2))

	local root = new("Frame", {
		Parent = Runtime.Gui,
		Position = options.Position or centred,
		Size = UDim2.fromOffset(M.WindowW, M.WindowH),
		BackgroundColor3 = T.Window,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 10,
	})

	frame(root, 0, 0, M.SidebarW, M.WindowH, T.Sidebar)
	frame(root, M.SidebarW, 0, 1, M.WindowH, T.Divider)

	local logo = options.Logo or "Logo"
	if type(logo) == "string" and logo:find("rbxasset") then
		drawIcon(root, logo, math.floor((M.SidebarW - M.IconSize) / 2), M.LogoImageY, T.Accent)
	else
		local definition = type(logo) == "table" and logo or Library.Icons[logo]
		drawIcon(root, definition, math.floor((M.SidebarW - iconPixels(definition.Width)) / 2), M.LogoY, T.Accent)
	end

	local tabList = new("ScrollingFrame", {
		Parent = root,
		Position = UDim2.fromOffset(0, M.TabsY),
		Size = UDim2.fromOffset(M.SidebarW, M.WindowH - M.TabsY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 0,
		ZIndex = 2,
	})

	local window = setmetatable({ Root = root, TabList = tabList, Tabs = {}, Active = nil }, Window)

	-- Dragging starts only on empty window space, never on a tab or inside a panel.
	local function overControl(point)
		for _, tab in window.Tabs do
			if contains(tab.Button, point) then
				return true
			end
		end
		if window.Active then
			for _, panel in window.Active.Panels do
				if contains(panel.Shell, point) then
					return true
				end
			end
		end
		return false
	end

	local dragStart, frameStart
	root.InputBegan:Connect(function(input)
		if isPress(input) and not blocked() and not overControl(pointer()) then
			local position = root.AbsolutePosition
			local origin = Runtime.Gui.AbsolutePosition
			dragStart = input.Position
			frameStart = Vector2.new(position.X - origin.X, position.Y - origin.Y)
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragStart and isMove(input) then
			local x = frameStart.X + input.Position.X - dragStart.X
			local y = frameStart.Y + input.Position.Y - dragStart.Y
			root.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragStart = nil
		end
	end)

	local toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
	connect(UserInputService.InputBegan, function(input, processed)
		if not processed and input.KeyCode == toggleKey then
			window:Toggle()
		end
	end)

	table.insert(Library.Windows, window)
	return window
end

function Library:GetConfig()
	local config = {}
	for flag, control in Library.Elements do
		config[flag] = control.Value
	end
	return config
end

function Library:LoadConfig(config)
	for flag, value in config do
		local control = Library.Elements[flag]
		if control then
			control:Set(value)
		end
	end
end

function Library:Destroy()
	closePopup()
	for _, connection in Runtime.Connections do
		connection:Disconnect()
	end
	if Runtime.Gui then
		Runtime.Gui:Destroy()
	end
	Runtime = { Connections = {}, Hover = {}, Notifications = {}, Popup = nil, Swallow = false }
	Library.Windows, Library.Elements, Library.Flags = {}, {}, {}
end

----------------------------------------------------------------------------------------------------
-- Demo: the complete reference layout.
----------------------------------------------------------------------------------------------------

function Library:Demo(options)
	options = options or {}
	local window = Library:CreateWindow(options)

	local assist = window:Tab({ Name = "ASSIST", Icon = "Skull" })
	local visuals = window:Tab({ Name = "VISUALS", Icon = "Target" })
	local misc = window:Tab({ Name = "MISC", Icon = "Gear" })
	local colors = window:Tab({ Name = "COLORS", Icon = "Pencil" })
	local trial = window:Tab({ Name = "TRIAL", Icon = "Code" })
	local configs = window:Tab({ Name = "CONFIGS", Icon = "Folder" })

	for _, tab in { assist, misc, colors, trial, configs } do
		tab:Panel(tab.Name):Toggle({ Name = "Enabled", Default = true })
	end

	local players = visuals:Panel("PLAYERS")
	players:Toggle({ Name = "Enabled" })
	players:Toggle({ Name = "Enemy only" })
	players:Toggle({ Name = "Box", Description = "Draw player box" })
	players:Toggle({ Name = "Box Outline", Default = true })
	players:Slider({ Name = "Expand Box", Min = 0, Max = 10, Default = 3, Decimals = 1, Suffix = "PPI" })
	players:Toggle({ Name = "Health", Default = true })
	players:Toggle({ Name = "Corpses", Description = "Show dead players", Default = true })
	players:Toggle({ Name = "Skeleton", Description = "Draw skeleton" })
	players:Slider({ Name = "Skeleton Thickness", Min = 0, Max = 9, Default = 1, Decimals = 2, Suffix = "PPI" })
	players:Slider({ Name = "Maximum Distance", Min = 0, Max = 5000, Default = 1312, Suffix = " feets" })
	players:Toggle({ Name = "Name", Description = "Draw player name" })
	players:Toggle({ Name = "Weapon", Description = "Draw held weapon" })

	local weapons = visuals:Panel("DROPPED WEAPONS")
	weapons:Toggle({ Name = "Enabled", Default = true })
	weapons:Toggle({ Name = "Box", Description = "Draw bound box", Default = true })
	weapons:Toggle({ Name = "Name", Default = true })
	weapons:Toggle({ Name = "Show Ammo", Default = true })
	weapons:Toggle({ Name = "Show Distance", Default = true })
	weapons:Slider({ Name = "Maximum Distance", Min = 0, Max = 500, Default = 114, Suffix = " feets" })

	local grenades = visuals:Panel("GRENADES")
	grenades:Toggle({ Name = "Enabled", Default = true })
	grenades:Toggle({ Name = "Box", Description = "Draw bound box", Default = true })
	grenades:Toggle({ Name = "Name", Default = true })
	grenades:Toggle({ Name = "Show Distance", Default = true })
	grenades:Slider({ Name = "Maximum Distance", Min = 0, Max = 500, Default = 200, Suffix = " feets" })
	grenades:Section("PLANTED C4")
	grenades:Dropdown({ Name = "Display type", Description = "Select type to display", Options = { "Box", "Text", "Icon" } })
	grenades:Toggle({ Name = "Box", Description = "Draw bound box", Default = true })
	grenades:Dropdown({ Name = "Display info", Description = "Select info to display", Options = { "Timer", "Damage", "Distance" }, Multi = true })
	grenades:Spacer(8)

	window:SelectTab(visuals)

	if options.Notifications ~= false then
		task.spawn(function()
			for _, entry in { { 0, 11 }, { 3.5, 10 }, { 3.24, 9.36 } } do
				if entry[1] > 0 then
					task.wait(entry[1])
				end
				Library:Notify({ Title = "FECURITY", Text = "This is how a notification looks.", Duration = entry[2] })
			end
		end)
	end

	return window
end

return Library
