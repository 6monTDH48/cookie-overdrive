-- Petit kit UI : création d'instances + composants « chunky » style Roblox simulator
local K = {}

K.colors = {
	bg = Color3.fromHex("#0b0620"), panel = Color3.fromHex("#160b34"), panel2 = Color3.fromHex("#22124a"),
	ink = Color3.fromHex("#fff6fe"), muted = Color3.fromHex("#b3a6dd"), stroke = Color3.fromHex("#1a0b33"),
	hot = Color3.fromHex("#ff2bd6"), cyan = Color3.fromHex("#1ff4ff"), lime = Color3.fromHex("#b6ff3b"),
	gold = Color3.fromHex("#ffc93c"), red = Color3.fromHex("#ff4d6d"), violet = Color3.fromHex("#8a5cff"),
	green = Color3.fromHex("#2bdc6a"),
}
local Cc = K.colors

K.DISPLAY = Enum.Font.FredokaOne
K.BODY = Enum.Font.GothamMedium
K.BOLD = Enum.Font.GothamBold

function K.new(class, props, children)
	local o = Instance.new(class)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in children or {} do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end
local new = K.new

function K.corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 12) }) end
function K.stroke(color, th) return new("UIStroke", { Color = color or Cc.stroke, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
function K.textStroke(color, th) return new("UIStroke", { Color = color or Cc.stroke, Thickness = th or 2 }) end
function K.pad(p) return new("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) }) end
function K.list(pad, dir, align)
	return new("UIListLayout", { Padding = UDim.new(0, pad or 6), FillDirection = dir or Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Center })
end

-- Texte « Roblox » : gros, blanc, contour sombre
function K.label(text, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, Font = K.DISPLAY, TextSize = size or 20,
		TextColor3 = Cc.ink, Size = UDim2.new(1, 0, 0, (size or 20) + 6), TextWrapped = true,
	}, { K.textStroke() })
	for k, v in props or {} do l[k] = v end
	return l
end

function K.small(text, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, Font = K.BODY, TextSize = size or 14,
		TextColor3 = Cc.muted, Size = UDim2.new(1, 0, 0, (size or 14) + 4), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for k, v in props or {} do l[k] = v end
	return l
end

-- Bouton 3D (ombre dessous) ; color = Color3
function K.button(text, color, props, onClick)
	local b = new("TextButton", {
		Text = text, Font = K.DISPLAY, TextSize = 18, TextColor3 = Cc.ink,
		BackgroundColor3 = color or Cc.green, AutoButtonColor = true, Size = UDim2.new(0, 120, 0, 40),
	}, { K.corner(10), K.stroke(Cc.stroke, 3), K.textStroke(Cc.stroke, 2) })
	for k, v in props or {} do b[k] = v end
	if onClick then
		b.MouseButton1Click:Connect(function()
			local s = b.Size
			b.Size = UDim2.new(s.X.Scale * 0.95, s.X.Offset * 0.95, s.Y.Scale * 0.95, s.Y.Offset * 0.95)
			task.delay(0.08, function() b.Size = s end)
			onClick(b)
		end)
	end
	return b
end

function K.card(props, children)
	local f = new("Frame", { BackgroundColor3 = Cc.panel2, Size = UDim2.new(1, 0, 0, 70) }, { K.corner(12), K.stroke(Cc.stroke, 2), K.pad(8) })
	for k, v in props or {} do f[k] = v end
	for _, c in children or {} do c.Parent = f end
	return f
end

function K.rgb(t, off)
	return Color3.fromHSV(((t or os.clock()) * 0.12 + (off or 0)) % 1, 0.85, 1)
end

function K.fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then return string.format("%dh%02d", sec // 3600, (sec % 3600) // 60) end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

return K
