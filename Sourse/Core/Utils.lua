-- ============================================================
-- CORNUI CORE UTILITIES
-- UI Construction + Helpers
-- ============================================================

local Services = require(script.Parent.Services)

local Utils = {}

local TweenService = Services.TweenService


-- ============================================================
-- INSTANCE CREATOR
-- ============================================================

function Utils.create(className, properties, children)
	local instance = Instance.new(className)

	if properties then
		for property, value in pairs(properties) do
			pcall(function()
				instance[property] = value
			end)
		end
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end

	return instance
end


-- ============================================================
-- UI CORNER
-- ============================================================

function Utils.corner(radius)
	return Utils.create("UICorner", {
		CornerRadius = UDim.new(0, radius or 8)
	})
end


-- ============================================================
-- UI STROKE
-- ============================================================

function Utils.stroke(color, thickness, transparency)
	return Utils.create("UIStroke", {
		Color = color or Color3.new(1,1,1),
		Thickness = thickness or 1,
		Transparency = transparency or 0
	})
end


-- ============================================================
-- UI PADDING
-- ============================================================

function Utils.padding(value)
	return Utils.create("UIPadding", {
		PaddingTop = UDim.new(0,value),
		PaddingBottom = UDim.new(0,value),
		PaddingLeft = UDim.new(0,value),
		PaddingRight = UDim.new(0,value)
	})
end


-- ============================================================
-- TWEEN WRAPPER
-- ============================================================

function Utils.tween(instance, properties, duration, style, direction)

	if not instance then
		return
	end

	local info = TweenInfo.new(
		duration or 0.25,
		style or Enum.EasingStyle.Quint,
		direction or Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(
		instance,
		info,
		properties
	)

	tween:Play()

	return tween
end


-- ============================================================
-- DEEP COPY
-- ============================================================

function Utils.deepCopy(tbl)

	local copy = {}

	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = Utils.deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end


-- ============================================================
-- TABLE MERGE
-- ============================================================

function Utils.merge(target, source)

	for key, value in pairs(source) do
		
		if type(value) == "table"
		and type(target[key]) == "table" then

			Utils.merge(target[key], value)

		else
			target[key] = value
		end

	end

	return target
end


-- ============================================================
-- SAFE CALL
-- ============================================================

function Utils.safeCall(callback, ...)
	
	if type(callback) ~= "function" then
		return
	end

	local success, result = pcall(callback, ...)

	if not success then
		warn("[CornUi] Callback Error:", result)
	end

	return result
end


-- ============================================================
-- CLAMP
-- ============================================================

function Utils.clamp(value, min, max)

	if value < min then
		return min
	end

	if value > max then
		return max
	end

	return value
end


-- ============================================================
-- GENERATE ID
-- ============================================================

function Utils.generateID(prefix)

	return (prefix or "CornUi")
		.. "_"
		.. tostring(math.random(100000,999999))
end


return Utils
