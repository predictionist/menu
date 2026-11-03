-- Halloween UI Library (recoded clean)

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local lp = Players.LocalPlayer

local GuiParent = (gethui and gethui()) or (cloneref and cloneref(CoreGui)) or CoreGui
local existing = GuiParent:FindFirstChild("menu")
if existing then existing:Destroy() end

-- ============================================================
-- LIBRARY
-- ============================================================
local Library = {
    Accent       = Color3.fromRGB(255, 119, 51),
    Inline       = Color3.fromRGB(21, 21, 21),
    Background   = Color3.fromRGB(15, 15, 15),
    Panel        = Color3.fromRGB(23, 23, 23),
    Text         = Color3.fromRGB(255, 255, 255),
    TextInactive = Color3.fromRGB(135, 135, 135),
    Border       = Color3.fromRGB(35, 35, 35),
    Risky        = Color3.fromRGB(255, 0, 0),

    FolderName   = "Celestial",
    Key          = Enum.KeyCode.End,
    Open         = true,

    Tabs = {}, RealTabs = {}, Sections = {},
    Connections = {}, Flags = {},
    Registry = {}, RegistryMap = {},

    Holder = nil, MainFrame = nil, CurrentColorpicker = nil,
    NotificationHolder = nil, LoadedConfig = nil, Dragging = false,
}

Library.__index = Library
Library.Tabs = {}
Library.Tabs.__index = Library.Tabs
Library.Sections = {}
Library.Sections.__index = Library.Sections

-- ============================================================
-- FOLDERS / FONT
-- ============================================================
if not isfolder(Library.FolderName) then makefolder(Library.FolderName) end
if not isfolder(Library.FolderName .. "/Configs") then makefolder(Library.FolderName .. "/Configs") end
if not isfolder(Library.FolderName .. "/Utilities") then makefolder(Library.FolderName .. "/Utilities") end

local Fonts = { Main = Font.fromEnum(Enum.Font.SourceSans) }
do
    local ttf = Library.FolderName .. "/Utilities/WindowsXPTahoma.ttf"
    if not isfile(ttf) then
        pcall(function()
            writefile(ttf, game:HttpGet(
                "https://raw.githubusercontent.com/sametexe001/luas/main/fonts/windows-xp-tahoma.ttf"
            ))
        end)
    end
    local ok, asset = pcall(getcustomasset, ttf)
    if ok and asset then
        local json = Library.FolderName .. "/Utilities/WindowsXPTahoma.font"
        pcall(function()
            writefile(json, HttpService:JSONEncode({
                name = "WindowsXPTahoma",
                faces = {{ name = "WindowsXPTahoma", weight = 400, style = "Regular", assetId = asset }},
            }))
        end)
        local ok2, f = pcall(function() return Font.new(getcustomasset(json)) end)
        if ok2 and f then Fonts.Main = f end
    end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function textStroke(obj)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(0, 0, 0)
    s.Thickness = 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    s.Parent = obj
    return s
end

-- Full 4-sided double border using manual frame lines.
-- Rendered at parent.ZIndex + 1 so it sits above the parent's background
-- but below any direct content (which sits at ZIndex 1 by default).
local function fourSideBorder(parent, colorKey)
    colorKey = colorKey or "Border"
    local z = 5   -- safely above background; content stays at ZIndex 1..4

    local function line(pos, size, color, zz)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.Position = pos
        f.Size = size
        f.ZIndex = zz or z
        f.BackgroundColor3 = color
        f.Parent = parent
        return f
    end

    local BLACK = Color3.fromRGB(0, 0, 0)
    local INNER = Library[colorKey]

    -- Outer black
    line(UDim2.new(0, 0, 0, 0),  UDim2.new(1, 0, 0, 1),  BLACK)
    line(UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1),  BLACK)
    line(UDim2.new(0, 0, 0, 0),  UDim2.new(0, 1, 1, 0),  BLACK)
    line(UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0),  BLACK)

    -- Inner color
    local a = line(UDim2.new(0, 1, 0, 1),  UDim2.new(1, -2, 0, 1),  INNER)
    local b = line(UDim2.new(0, 1, 1, -2), UDim2.new(1, -2, 0, 1),  INNER)
    local c = line(UDim2.new(0, 1, 0, 1),  UDim2.new(0, 1, 1, -2),  INNER)
    local d = line(UDim2.new(1, -2, 0, 1), UDim2.new(0, 1, 1, -2),  INNER)
    for _, f in {a, b, c, d} do
        Library:AddToRegistry(f, { BackgroundColor3 = colorKey })
    end
end

-- Partial border (e.g. tabs with no bottom)
local function partialBorder(parent, sides, colorKey)
    colorKey = colorKey or "Border"
    local z = 5
    local BLACK = Color3.fromRGB(0, 0, 0)
    local INNER = Library[colorKey]

    local function line(pos, size, color, reg)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.Position = pos
        f.Size = size
        f.ZIndex = z
        f.BackgroundColor3 = color
        f.Parent = parent
        if reg then Library:AddToRegistry(f, { BackgroundColor3 = colorKey }) end
        return f
    end

    if sides.top    then line(UDim2.new(0, 0, 0, 0),  UDim2.new(1, 0, 0, 1), BLACK) end
    if sides.bottom then line(UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), BLACK) end
    if sides.left   then line(UDim2.new(0, 0, 0, 0),  UDim2.new(0, 1, 1, 0), BLACK) end
    if sides.right  then line(UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), BLACK) end

    if sides.top    then line(UDim2.new(0, 1, 0, 1),  UDim2.new(1, -2, 0, 1), INNER, true) end
    if sides.bottom then line(UDim2.new(0, 1, 1, -2), UDim2.new(1, -2, 0, 1), INNER, true) end
    if sides.left   then line(UDim2.new(0, 1, 0, 1),  UDim2.new(0, 1, 1, -2), INNER, true) end
    if sides.right  then line(UDim2.new(1, -2, 0, 1), UDim2.new(0, 1, 1, -2), INNER, true) end
end

local function glow(parent, colorKey)
    colorKey = colorKey or "Accent"
    local s = Instance.new("UIShadow")
    s.BlurRadius = UDim.new(0, 16)
    s.Color = Library[colorKey]
    s.Spread = UDim2.new(0, 1, 0, 1)
    s.Parent = parent
    Library:AddToRegistry(s, { Color = colorKey })
    return s
end

local function makeLabel(parent, text, size, colorKey, xAlign, yAlign)
    local l = Instance.new("TextLabel")
    l.FontFace = Fonts.Main
    l.Text = text
    l.TextSize = size or 12
    l.TextColor3 = Library[colorKey or "Text"]
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.TextYAlignment = yAlign or Enum.TextYAlignment.Center
    l.ZIndex = 6
    l.Parent = parent
    textStroke(l)
    if colorKey then Library:AddToRegistry(l, { TextColor3 = colorKey }) end
    return l
end

local KEY_NAMES = {
    [Enum.UserInputType.MouseButton1] = "MB1", [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3", [Enum.UserInputType.MouseWheel]   = "MW",
    [Enum.KeyCode.LeftShift] = "LS", [Enum.KeyCode.RightShift] = "RS",
    [Enum.KeyCode.LeftControl] = "LC", [Enum.KeyCode.RightControl] = "RC",
    [Enum.KeyCode.LeftAlt] = "LA", [Enum.KeyCode.RightAlt] = "RA",
    [Enum.KeyCode.CapsLock] = "CAP", [Enum.KeyCode.Backspace] = "BKSP",
    [Enum.KeyCode.Return] = "ENT", [Enum.KeyCode.Escape] = "ESC",
    [Enum.KeyCode.Space] = "SPC", [Enum.KeyCode.Up] = "UP", [Enum.KeyCode.Down] = "DN",
    [Enum.KeyCode.Left] = "LT", [Enum.KeyCode.Right] = "RT",
    [Enum.KeyCode.Insert] = "INS", [Enum.KeyCode.Delete] = "DEL",
    [Enum.KeyCode.Home] = "HOM", [Enum.KeyCode.End] = "END",
    [Enum.KeyCode.PageUp] = "PGU", [Enum.KeyCode.PageDown] = "PGD",
    [Enum.KeyCode.Tab] = "TAB",
    [Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3",
    [Enum.KeyCode.Four] = "4", [Enum.KeyCode.Five] = "5", [Enum.KeyCode.Six] = "6",
    [Enum.KeyCode.Seven] = "7", [Enum.KeyCode.Eight] = "8", [Enum.KeyCode.Nine] = "9",
    [Enum.KeyCode.Zero] = "0",
}

local function keyToString(k)
    if not k then return "NONE" end
    if KEY_NAMES[k] then return KEY_NAMES[k] end
    if typeof(k) == "EnumItem" then
        local name = k.Name
        name = name:gsub("^KeyCode%.", ""):gsub("^UserInputType%.", "")
        if #name > 4 then name = name:sub(1, 4) end
        return name
    end
    return tostring(k)
end

-- ============================================================
-- LIBRARY METHODS
-- ============================================================
function Library:Connect(Signal, Callback)
    local c = Signal:Connect(Callback)
    table.insert(self.Connections, c)
    return c
end

function Library:SetOpen(Bool)
    if Library.MainFrame then Library.MainFrame.Visible = Bool end
    Library.Open = Bool
end

function Library:Round(Number, Float) return Float * math.floor(Number / Float) end

function Library:AddToRegistry(Instance, Properties)
    local Data = { Instance = Instance, Properties = Properties }
    table.insert(Library.Registry, Data)
    Library.RegistryMap[Instance] = Data
    for Property, ColorIdx in next, Properties do
        if type(ColorIdx) == 'string' then
            Instance[Property] = Library[ColorIdx]
        elseif type(ColorIdx) == 'function' then
            Instance[Property] = ColorIdx()
        end
    end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance]
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx)
            end
        end
        Library.RegistryMap[Instance] = nil
    end
end

function Library:UpdateTheme()
    for _, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:Notify(Text, Duration, Color)
    if not Library.NotificationHolder then return end
    local box = Instance.new("Frame")
    box.Name = "notification"
    box.Size = UDim2.new(0, 0, 0, 20)
    box.BorderSizePixel = 0
    box.BackgroundColor3 = Library.Background
    box.ClipsDescendants = true
    box.ZIndex = 100
    box.Parent = Library.NotificationHolder
    fourSideBorder(box, "Border")
    Library:AddToRegistry(box, { BackgroundColor3 = "Background" })

    local liner = Instance.new("Frame")
    liner.Size = UDim2.new(0, 2, 1, -2)
    liner.Position = UDim2.new(0, 1, 0, 1)
    liner.BorderSizePixel = 0
    liner.ZIndex = 6
    liner.BackgroundColor3 = Color or Library.Accent
    liner.Parent = box

    local lbl = makeLabel(box, Text, 11, "Text")
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.TextTransparency = 1

    task.spawn(function()
        local t1 = TweenService:Create(box, TweenInfo.new(0.26), { Size = UDim2.new(0, lbl.TextBounds.X + 16, 0, 20) })
        t1:Play(); t1.Completed:Wait()
        local t2 = TweenService:Create(lbl, TweenInfo.new(0.26), { TextTransparency = 0 })
        t2:Play(); t2.Completed:Wait()
        task.wait(Duration or 3)
        local t3 = TweenService:Create(box, TweenInfo.new(0.26), { Size = UDim2.new(0, 0, 0, 20) })
        t3:Play(); t3.Completed:Wait()
        Library:RemoveFromRegistry(box)
        box:Destroy()
    end)
end

function Library:GetConfig()
    local Config = {}
    for Index, Value in self.Flags do
        if typeof(Value) == "table" then
            if Value.Value ~= nil then
                Config[Index] = Value.Value
            elseif Value.Color then
                Config[Index] = { Color = { R = Value.Color.R, G = Value.Color.G, B = Value.Color.B }, Transparency = Value.Transparency }
            elseif rawget(Value, "Key") and rawget(Value, "Name") then
                Config[Index] = { Name = Value.Key.Name }
            else
                Config[Index] = Value.Value
            end
        end
    end
    return Config, HttpService:JSONEncode(Config)
end

function Library:SaveConfig(ConfigName)
    local _, Encoded = Library:GetConfig()
    if ConfigName and type(ConfigName) == "string" then
        writefile(Library.FolderName .. "/Configs/" .. ConfigName .. ".json", Encoded)
    end
end

function Library:LoadConfig(Config)
    if not Config then
        Library:Notify("Config not found", 3, Color3.fromRGB(255, 0, 0))
        return
    end
    local Decoded = HttpService:JSONDecode(Config)
    for Index, Value in Decoded do
        task.spawn(function()
            local ToLib = Library.Flags[Index]
            if not ToLib then return end
            pcall(function()
                if rawget(ToLib, "Key") and type(Value) ~= "boolean" then
                    ToLib:Set(Value, true)
                elseif rawget(ToLib, "Color") then
                    ToLib:Set({ Color = Color3.new(Value.Color.R, Value.Color.G, Value.Color.B), Transparency = Value.Transparency })
                else
                    ToLib:Set(Value)
                end
            end)
        end)
    end
end

function Library:DeleteConfig(ConfigName)
    local path = Library.FolderName .. "/Configs/" .. ConfigName .. ".json"
    if isfile(path) then delfile(path) end
end

-- ============================================================
-- SCREEN
-- ============================================================
local Screen = Instance.new("ScreenGui")
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Screen.Name = "menu"
Screen.Parent = GuiParent
Screen.ResetOnSpawn = false
Screen.IgnoreGuiInset = true
Library.Holder = Screen

Library:Connect(UserInputService.InputBegan, function(input)
    if not Library.Key then return end
    if input.KeyCode == Library.Key then
        Library:SetOpen(not Library.Open)
    end
end)

-- ============================================================
-- WINDOW
-- ============================================================
function Library:Window(Data)
    local Window = { Name = Data.Name, Objects = {} }
    local Objects = {}

    Objects["main"] = Instance.new("Frame")
    Objects["main"].Name = "Holder"
    Objects["main"].Position = UDim2.new(0.5, -280, 0.5, -269)
    Objects["main"].Size = UDim2.new(0, 560, 0, 538)
    Objects["main"].BackgroundColor3 = Library.Inline
    Objects["main"].BorderSizePixel = 0
    Objects["main"].ZIndex = 1
    Objects["main"].Parent = Library.Holder
    fourSideBorder(Objects["main"], "Border")
    Library:AddToRegistry(Objects["main"], { BackgroundColor3 = "Inline" })
    Library.MainFrame = Objects["main"]

    -- Title row (left/right aligned to 8px inset)
    local ROW_Y = 6
    Objects["title"] = makeLabel(Objects["main"], Window.Name, 14, "Accent")
    Objects["title"].Position = UDim2.new(0, 8, 0, ROW_Y)
    Objects["title"].Size = UDim2.new(0, 200, 0, 18)

    Objects["gametitle"] = makeLabel(Objects["main"],
        "[" .. tostring(game.GameId) .. "] " .. game.Name, 14, "TextInactive",
        Enum.TextXAlignment.Right, Enum.TextYAlignment.Center)
    Objects["gametitle"].Position = UDim2.new(1, -208, 0, ROW_Y)
    Objects["gametitle"].Size = UDim2.new(0, 200, 0, 18)
    Library:RemoveFromRegistry(Objects["gametitle"])
    Library:AddToRegistry(Objects["gametitle"], { TextColor3 = "TextInactive" })

    -- Divider
    Objects["line"] = Instance.new("Frame")
    Objects["line"].Position = UDim2.new(0, 8, 0, ROW_Y + 22)
    Objects["line"].Size = UDim2.new(1, -16, 0, 1)
    Objects["line"].BorderSizePixel = 0
    Objects["line"].ZIndex = 6
    Objects["line"].BackgroundColor3 = Library.Accent
    Objects["line"].Parent = Objects["main"]
    Library:AddToRegistry(Objects["line"], { BackgroundColor3 = "Accent" })
    glow(Objects["line"], "Accent")

    -- Tab buttons strip (sits flush on top of tabholder)
    local TAB_H = 24
    local TAB_Y = ROW_Y + 30
    local HOLDER_Y = TAB_Y + TAB_H

    Objects["tabs"] = Instance.new("Frame")
    Objects["tabs"].Name = "Tabs"
    Objects["tabs"].Position = UDim2.new(0, 8, 0, TAB_Y)
    Objects["tabs"].Size = UDim2.new(1, -16, 0, TAB_H)
    Objects["tabs"].BackgroundTransparency = 1
    Objects["tabs"].ZIndex = 20
    Objects["tabs"].Parent = Objects["main"]

    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 4)
    tl.SortOrder = Enum.SortOrder.LayoutOrder
    tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
    tl.Parent = Objects["tabs"]

    Objects["tabholder"] = Instance.new("Frame")
    Objects["tabholder"].Name = "Tab Holder"
    Objects["tabholder"].Position = UDim2.new(0, 8, 0, HOLDER_Y)
    Objects["tabholder"].Size = UDim2.new(1, -16, 1, -(HOLDER_Y + 8))
    Objects["tabholder"].BackgroundColor3 = Library.Panel
    Objects["tabholder"].BorderSizePixel = 0
    Objects["tabholder"].ZIndex = 1
    Objects["tabholder"].Parent = Objects["main"]
    fourSideBorder(Objects["tabholder"], "Border")
    Library:AddToRegistry(Objects["tabholder"], { BackgroundColor3 = "Panel" })

    Objects["content"] = Instance.new("ScrollingFrame")
    Objects["content"].Name = "Content"
    Objects["content"].Position = UDim2.new(0, 6, 0, 6)
    Objects["content"].Size = UDim2.new(1, -12, 1, -12)
    Objects["content"].BackgroundTransparency = 1
    Objects["content"].BorderSizePixel = 0
    Objects["content"].CanvasSize = UDim2.new(0, 0, 0, 0)
    Objects["content"].AutomaticCanvasSize = Enum.AutomaticSize.Y
    Objects["content"].ScrollBarThickness = 2
    Objects["content"].ScrollBarImageColor3 = Library.Accent
    Objects["content"].ScrollBarImageTransparency = 0.4
    Objects["content"].ZIndex = 2
    Objects["content"].Parent = Objects["tabholder"]
    Library:AddToRegistry(Objects["content"], { ScrollBarImageColor3 = "Accent" })

    Window.Objects = { Tabs = Objects["tabs"], Content = Objects["content"], Main = Objects["main"] }

    -- Drag
    do
        local dragging, dragStart, startPos
        Objects["main"].InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Objects["main"].Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local dx = input.Position.X - dragStart.X
                local dy = input.Position.Y - dragStart.Y
                Objects["main"].Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + dx,
                    startPos.Y.Scale, startPos.Y.Offset + dy
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    return setmetatable(Window, Library)
end

-- ============================================================
-- TAB
-- ============================================================
function Library:Tab(Data)
    local Tab = { Window = self, Name = Data.Name, Active = false, Objects = {} }
    local Objects = {}

    Objects["button"] = Instance.new("TextButton")
    Objects["button"].FontFace = Fonts.Main
    Objects["button"].Text = Tab.Name
    Objects["button"].TextColor3 = Library.TextInactive
    Objects["button"].TextSize = 13
    Objects["button"].AutoButtonColor = false
    Objects["button"].Size = UDim2.new(0, 84, 0, 24)
    Objects["button"].BackgroundColor3 = Library.Panel
    Objects["button"].BorderSizePixel = 0
    Objects["button"].Name = Tab.Name
    Objects["button"].ZIndex = 20
    Objects["button"].Parent = Tab.Window.Objects.Tabs
    partialBorder(Objects["button"], { top = true, left = true, right = true }, "Border")
    Library:AddToRegistry(Objects["button"], { BackgroundColor3 = "Panel" })
    Library:AddToRegistry(Objects["button"], { TextColor3 = "TextInactive" })

    Objects["content"] = Instance.new("ScrollingFrame")
    Objects["content"].Name = Tab.Name
    Objects["content"].Size = UDim2.new(1, 0, 1, 0)
    Objects["content"].BackgroundTransparency = 1
    Objects["content"].BorderSizePixel = 0
    Objects["content"].CanvasSize = UDim2.new(0, 0, 0, 0)
    Objects["content"].AutomaticCanvasSize = Enum.AutomaticSize.Y
    Objects["content"].ScrollBarThickness = 2
    Objects["content"].ScrollBarImageColor3 = Library.Accent
    Objects["content"].Visible = false
    Objects["content"].ZIndex = 2
    Objects["content"].Parent = Tab.Window.Objects.Content
    Library:AddToRegistry(Objects["content"], { ScrollBarImageColor3 = "Accent" })

    Objects["left"] = Instance.new("Frame")
    Objects["left"].Name = "Left"
    Objects["left"].BackgroundTransparency = 1
    Objects["left"].Position = UDim2.new(0, 0, 0, 0)
    Objects["left"].Size = UDim2.new(0.5, -4, 1, 0)
    Objects["left"].ZIndex = 3
    Objects["left"].Parent = Objects["content"]
    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 8)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = Objects["left"]

    Objects["right"] = Instance.new("Frame")
    Objects["right"].AnchorPoint = Vector2.new(1, 0)
    Objects["right"].Name = "Right"
    Objects["right"].BackgroundTransparency = 1
    Objects["right"].Position = UDim2.new(1, 0, 0, 0)
    Objects["right"].Size = UDim2.new(0.5, -4, 1, 0)
    Objects["right"].ZIndex = 3
    Objects["right"].Parent = Objects["content"]
    local rl = Instance.new("UIListLayout")
    rl.Padding = UDim.new(0, 8)
    rl.SortOrder = Enum.SortOrder.LayoutOrder
    rl.Parent = Objects["right"]

    Tab.Objects = { Left = Objects["left"], Right = Objects["right"], Button = Objects["button"], Content = Objects["content"] }

    function Tab:Switch(Bool)
        Tab.Active = Bool
        Objects["content"].Visible = Bool
        Library:RemoveFromRegistry(Objects["button"])
        Library:AddToRegistry(Objects["button"], { TextColor3 = Bool and "Accent" or "TextInactive" })
        TweenService:Create(Objects["button"], TweenInfo.new(0.13), {
            TextColor3 = Bool and Library.Accent or Library.TextInactive,
        }):Play()
    end

    Library:Connect(Objects["button"].MouseButton1Down, function()
        for _, t in Library.RealTabs do t:Switch(t == Tab) end
    end)

    table.insert(Library.RealTabs, Tab)
    if #Library.RealTabs == 1 then
        task.defer(function() Tab:Switch(true) end)
    end

    return setmetatable(Tab, Library.Tabs)
end

-- ============================================================
-- SECTION
-- ============================================================
function Library.Tabs:Section(Data)
    local Section = { Tab = self, Name = Data.Name, Side = Data.Side or "Left", Objects = {} }
    local Objects = {}

    Objects["section"] = Instance.new("Frame")
    Objects["section"].Name = "Section"
    Objects["section"].Size = UDim2.new(1, 0, 0, 20)
    Objects["section"].BorderSizePixel = 0
    Objects["section"].AutomaticSize = Enum.AutomaticSize.Y
    Objects["section"].BackgroundColor3 = Library.Panel
    Objects["section"].ZIndex = 3
    Objects["section"].Parent = (Section.Side:lower() == "left" and Section.Tab.Objects.Left)
        or (Section.Side:lower() == "right" and Section.Tab.Objects.Right)
        or Section.Tab.Objects.Left
    fourSideBorder(Objects["section"], "Border")
    Library:AddToRegistry(Objects["section"], { BackgroundColor3 = "Panel" })

    -- Accent line across the top edge (replaces top border visually)
    Objects["liner"] = Instance.new("Frame")
    Objects["liner"].Name = "Section Line"
    Objects["liner"].Size = UDim2.new(1, -2, 0, 1)
    Objects["liner"].Position = UDim2.new(0, 1, 0, 1)
    Objects["liner"].BorderSizePixel = 0
    Objects["liner"].ZIndex = 7
    Objects["liner"].BackgroundColor3 = Library.Accent
    Objects["liner"].Parent = Objects["section"]
    Library:AddToRegistry(Objects["liner"], { BackgroundColor3 = "Accent" })
    glow(Objects["liner"], "Accent")

    -- Centered title straddling the accent line
    Objects["text"] = Instance.new("TextLabel")
    Objects["text"].FontFace = Fonts.Main
    Objects["text"].Text = Section.Name
    Objects["text"].TextSize = 12
    Objects["text"].TextColor3 = Library.Text
    Objects["text"].BackgroundColor3 = Library.Panel
    Objects["text"].BackgroundTransparency = 0
    Objects["text"].BorderSizePixel = 0
    Objects["text"].AutomaticSize = Enum.AutomaticSize.X
    Objects["text"].Size = UDim2.new(0, 40, 0, 13)
    Objects["text"].AnchorPoint = Vector2.new(0.5, 0.5)
    Objects["text"].Position = UDim2.new(0.5, 0, 0, 1)
    Objects["text"].ZIndex = 8
    Objects["text"].Parent = Objects["section"]
    textStroke(Objects["text"])
    Library:AddToRegistry(Objects["text"], { TextColor3 = "Text", BackgroundColor3 = "Panel" })

    Objects["content"] = Instance.new("Frame")
    Objects["content"].Name = "Content"
    Objects["content"].BackgroundTransparency = 1
    Objects["content"].Position = UDim2.new(0, 8, 0, 14)
    Objects["content"].Size = UDim2.new(1, -16, 0, 0)
    Objects["content"].AutomaticSize = Enum.AutomaticSize.Y
    Objects["content"].ZIndex = 4
    Objects["content"].Parent = Objects["section"]

    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 6)
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Parent = Objects["content"]

    local cp = Instance.new("UIPadding")
    cp.PaddingBottom = UDim.new(0, 8)
    cp.Parent = Objects["content"]

    Section.Objects = { Main = Objects["content"] }
    return setmetatable(Section, Library.Sections)
end

-- ============================================================
-- TOGGLE
-- ============================================================
function Library.Sections:Toggle(Data)
    local Toggle = {
        Section = self, Name = Data.Name, Flag = Data.Flag,
        Callback = Data.Callback or function() end,
        State = Data.Default, Value = false, Risky = Data.Risky or false,
    }
    local Objects = {}

    Objects["toggle"] = Instance.new("TextButton")
    Objects["toggle"].FontFace = Fonts.Main
    Objects["toggle"].Text = ""
    Objects["toggle"].BackgroundTransparency = 1
    Objects["toggle"].Name = Toggle.Name
    Objects["toggle"].Size = UDim2.new(1, 0, 0, 16)
    Objects["toggle"].BorderSizePixel = 0
    Objects["toggle"].AutoButtonColor = false
    Objects["toggle"].ZIndex = 4
    Objects["toggle"].Parent = Toggle.Section.Objects.Main

    Objects["indicator"] = Instance.new("Frame")
    Objects["indicator"].Name = "indicator"
    Objects["indicator"].Size = UDim2.new(0, 14, 0, 14)
    Objects["indicator"].Position = UDim2.new(0, 0, 0, 1)
    Objects["indicator"].BorderSizePixel = 0
    Objects["indicator"].ZIndex = 6
    Objects["indicator"].BackgroundColor3 = Library.Panel
    Objects["indicator"].Parent = Objects["toggle"]
    fourSideBorder(Objects["indicator"], "Border")
    Library:AddToRegistry(Objects["indicator"], { BackgroundColor3 = "Panel" })

    Objects["text"] = makeLabel(Objects["toggle"], Toggle.Name, 12, "Text")
    Objects["text"].Position = UDim2.new(0, 22, 0, 0)
    Objects["text"].Size = UDim2.new(1, -30, 1, 0)
    Objects["text"].TextTransparency = 0.4

    if Toggle.Risky then
        Library:RemoveFromRegistry(Objects["text"])
        Library:AddToRegistry(Objects["text"], { TextColor3 = "Risky" })
    end

    function Toggle:Set(Value)
        Toggle.Value = Value
        Library:RemoveFromRegistry(Objects["indicator"])
        Library:AddToRegistry(Objects["indicator"], { BackgroundColor3 = Value and "Accent" or "Panel" })
        TweenService:Create(Objects["indicator"], TweenInfo.new(0.13, Enum.EasingStyle.Sine),
            { BackgroundColor3 = Value and Library.Accent or Library.Panel }):Play()
        TweenService:Create(Objects["text"], TweenInfo.new(0.13, Enum.EasingStyle.Sine),
            { TextTransparency = Value and 0 or 0.4 }):Play()
        if Toggle.Callback then Toggle.Callback(Value) end
    end

    function Toggle:Get() return Toggle.Value end
    function Toggle:SetVisibility(Boolean) Objects["toggle"].Visible = Boolean end

    Library:Connect(Objects["toggle"].MouseButton1Down, function() Toggle:Set(not Toggle.Value) end)

    function Toggle:Keybind(Data)
        local Keybind = {
            Section = self, Name = Data.Name, Flag = Data.Flag,
            Mode = Data.Mode or "Toggle", Value = false,
            Callback = Data.Callback or function() end,
            IsBeingSelected = false, Default = Data.Default, AbKey = "NONE",
        }
        local Sub = {}

        Sub["key"] = Instance.new("TextButton")
        Sub["key"].FontFace = Fonts.Main
        Sub["key"].Text = "[NONE]"
        Sub["key"].TextColor3 = Library.Text
        Sub["key"].TextSize = 12
        Sub["key"].AnchorPoint = Vector2.new(1, 0.5)
        Sub["key"].Position = UDim2.new(1, 0, 0.5, 0)
        Sub["key"].AutomaticSize = Enum.AutomaticSize.X
        Sub["key"].Size = UDim2.new(0, 0, 0, 14)
        Sub["key"].BackgroundTransparency = 1
        Sub["key"].BorderSizePixel = 0
        Sub["key"].AutoButtonColor = false
        Sub["key"].ZIndex = 6
        Sub["key"].Parent = Objects["toggle"]
        textStroke(Sub["key"])

        function Keybind:Set(Key, IsMouse)
            if IsMouse then
                Keybind.Key = (type(Key) == "table") and Enum.UserInputType[Key.Name] or Key
                local short = "M?"
                if Keybind.Key == Enum.UserInputType.MouseButton1 then short = "M1"
                elseif Keybind.Key == Enum.UserInputType.MouseButton2 then short = "M2"
                elseif Keybind.Key == Enum.UserInputType.MouseButton3 then short = "M3"
                elseif Keybind.Key == Enum.UserInputType.MouseWheel then short = "M4" end
                Keybind.AbKey = short
                Sub["key"].Text = "[" .. short .. "]"
            else
                if Key and Key.Name then
                    Keybind.Key = (type(Key) == "table") and Enum.KeyCode[Key.Name] or Key
                    Keybind.AbKey = keyToString(Keybind.Key)
                    Sub["key"].Text = "[" .. Keybind.AbKey .. "]"
                end
            end
        end

        Library:Connect(Sub["key"].MouseButton1Down, function()
            task.wait(0.1)
            Keybind.IsBeingSelected = true
            Sub["key"].Text = "[...]"
            local c
            c = Library:Connect(UserInputService.InputBegan, function(Input)
                if not Keybind.IsBeingSelected then c:Disconnect(); return end
                if Input.UserInputType == Enum.UserInputType.Keyboard then
                    Keybind:Set(Input.KeyCode)
                elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    Keybind:Set(Enum.UserInputType.MouseButton1, true)
                elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Keybind:Set(Enum.UserInputType.MouseButton2, true)
                elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then
                    Keybind:Set(Enum.UserInputType.MouseButton3, true)
                elseif Input.UserInputType == Enum.UserInputType.MouseWheel then
                    Keybind:Set(Enum.UserInputType.MouseWheel, true)
                else return end
                Keybind.IsBeingSelected = false
                c:Disconnect()
            end)
        end)

        Library:Connect(UserInputService.InputBegan, function(Input)
            if Keybind.IsBeingSelected then return end
            if Input.KeyCode == Keybind.Key or Input.UserInputType == Keybind.Key then
                if Keybind.Mode == "Toggle" then
                    Keybind.Value = not Keybind.Value
                    Keybind.Callback(Keybind.Value)
                elseif Keybind.Mode == "Hold" then
                    Keybind.Value = true
                    Keybind.Callback(Keybind.Value)
                elseif Keybind.Mode == "Press" then
                    Keybind.Callback(Keybind.Value)
                end
            end
        end)

        Library:Connect(UserInputService.InputEnded, function(Input)
            if Keybind.IsBeingSelected then return end
            if (Input.KeyCode == Keybind.Key or Input.UserInputType == Keybind.Key) and Keybind.Mode == "Hold" then
                Keybind.Value = false
                Keybind.Callback(Keybind.Value)
            end
        end)

        function Keybind:Get() return Keybind.Value end
        if Keybind.Default then Keybind:Set(Keybind.Default) end
        Library.Flags[Keybind.Flag] = Keybind
        return Keybind
    end

    if Toggle.State then Toggle:Set(Toggle.State) end
    Library.Flags[Toggle.Flag] = Toggle
    return Toggle
end

-- ============================================================
-- BUTTON
-- ============================================================
function Library.Sections:Button(Data)
    local Button = { Section = self, Name = Data.Name, Callback = Data.Callback or function() end }
    local Objects = {}

    Objects["button"] = Instance.new("TextButton")
    Objects["button"].FontFace = Fonts.Main
    Objects["button"].Text = ""
    Objects["button"].AutoButtonColor = false
    Objects["button"].Size = UDim2.new(1, 0, 0, 18)
    Objects["button"].BorderSizePixel = 0
    Objects["button"].BackgroundColor3 = Library.Panel
    Objects["button"].ZIndex = 4
    Objects["button"].Parent = Button.Section.Objects.Main
    fourSideBorder(Objects["button"], "Border")
    Library:AddToRegistry(Objects["button"], { BackgroundColor3 = "Panel" })

    Objects["text"] = makeLabel(Objects["button"], Button.Name, 12, "Text",
        Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    Objects["text"].Size = UDim2.new(1, 0, 1, 0)

    Library:Connect(Objects["button"].MouseButton1Down, function()
        TweenService:Create(Objects["button"], TweenInfo.new(0.1), { BackgroundColor3 = Library.Accent }):Play()
        task.wait(0.1)
        TweenService:Create(Objects["button"], TweenInfo.new(0.1), { BackgroundColor3 = Library.Panel }):Play()
        pcall(Button.Callback)
    end)

    function Button:Sub(Data)
        local SubButton = { Name = Data.Name, Callback = Data.Callback or function() end }
        Objects["button"].Size = UDim2.new(0.5, -3, 0, 18)

        local s = Instance.new("TextButton")
        s.Text = ""
        s.AutoButtonColor = false
        s.Position = UDim2.new(1, 6, 0, 0)
        s.Size = UDim2.new(1, 0, 1, 0)
        s.BorderSizePixel = 0
        s.ZIndex = 4
        s.BackgroundColor3 = Library.Panel
        s.Parent = Objects["button"]
        fourSideBorder(s, "Border")

        local st = makeLabel(s, SubButton.Name, 12, "Text",
            Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
        st.Size = UDim2.new(1, 0, 1, 0)

        Library:Connect(s.MouseButton1Down, function() pcall(SubButton.Callback) end)
        return SubButton
    end

    return Button
end

-- ============================================================
-- SLIDER
-- ============================================================
function Library.Sections:Slider(Data)
    local Slider = {
        Section = self, Name = Data.Name,
        Min = Data.Min or 0, Max = Data.Max or 100, Suffix = Data.Sub or "",
        State = Data.Default, Flag = Data.Flag, Value = 0,
        Decimals = Data.Decimals or 1,
        Callback = Data.Callback or function() end,
    }
    local Objects = {}

    Objects["slider"] = Instance.new("Frame")
    Objects["slider"].BackgroundTransparency = 1
    Objects["slider"].Size = UDim2.new(1, 0, 0, 26)
    Objects["slider"].ZIndex = 4
    Objects["slider"].Parent = Slider.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["slider"], Slider.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 0, 14)

    Objects["realslider"] = Instance.new("TextButton")
    Objects["realslider"].AnchorPoint = Vector2.new(0, 1)
    Objects["realslider"].Position = UDim2.new(0, 0, 1, 0)
    Objects["realslider"].Size = UDim2.new(1, 0, 0, 8)
    Objects["realslider"].BorderSizePixel = 0
    Objects["realslider"].BackgroundColor3 = Library.Panel
    Objects["realslider"].Text = ""
    Objects["realslider"].AutoButtonColor = false
    Objects["realslider"].ZIndex = 4
    Objects["realslider"].Parent = Objects["slider"]
    fourSideBorder(Objects["realslider"], "Border")
    Library:AddToRegistry(Objects["realslider"], { BackgroundColor3 = "Panel" })

    Objects["indicator"] = Instance.new("Frame")
    Objects["indicator"].Size = UDim2.new(0, 0, 1, -2)
    Objects["indicator"].Position = UDim2.new(0, 1, 0, 1)
    Objects["indicator"].BorderSizePixel = 0
    Objects["indicator"].ZIndex = 6
    Objects["indicator"].BackgroundColor3 = Library.Accent
    Objects["indicator"].Parent = Objects["realslider"]
    Library:AddToRegistry(Objects["indicator"], { BackgroundColor3 = "Accent" })

    Objects["value"] = makeLabel(Objects["realslider"], "0", 11, "Text",
        Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    Objects["value"].Size = UDim2.new(1, 0, 1, 0)

    local function set(value)
        value = math.clamp(Library:Round(value, Slider.Decimals), Slider.Min, Slider.Max)
        local t = (value - Slider.Min) / (Slider.Max - Slider.Min)
        Objects["indicator"].Size = UDim2.new(t, -2 * t, 1, -2)
        Objects["value"].Text = string.format("%.14g", value) .. Slider.Suffix
        Slider.Value = value
        if Slider.Callback then Slider.Callback(value) end
    end

    function Slider:Set(v) set(v) end
    function Slider:Get() return Slider.Value end
    function Slider:SetVisibility(b) Objects["slider"].Visible = b end

    local sliding = false
    local function inputSlide(input)
        local rel = (input.Position.X - Objects["realslider"].AbsolutePosition.X) / Objects["realslider"].AbsoluteSize.X
        set(Slider.Min + (Slider.Max - Slider.Min) * rel)
    end

    Library:Connect(Objects["realslider"].InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true; inputSlide(i)
        end
    end)
    Library:Connect(Objects["realslider"].InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    Library:Connect(UserInputService.InputChanged, function(i)
        if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then inputSlide(i) end
    end)

    if Slider.State then set(Slider.State) else set(Slider.Min) end
    Library.Flags[Slider.Flag] = Slider
    return Slider
end

-- ============================================================
-- DROPDOWN
-- ============================================================
function Library.Sections:Dropdown(Data)
    local Dropdown = {
        Section = self, Flag = Data.Flag, Name = Data.Name or "Dropdown",
        Default = Data.Default, Options = {},
        Callback = Data.Callback or function() end, Value = nil,
    }
    local Objects = {}

    Objects["dropdown"] = Instance.new("Frame")
    Objects["dropdown"].BackgroundTransparency = 1
    Objects["dropdown"].Size = UDim2.new(1, 0, 0, 32)
    Objects["dropdown"].ZIndex = 4
    Objects["dropdown"].Parent = Dropdown.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["dropdown"], Dropdown.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 0, 14)

    Objects["realdropdown"] = Instance.new("Frame")
    Objects["realdropdown"].AnchorPoint = Vector2.new(0, 1)
    Objects["realdropdown"].Position = UDim2.new(0, 0, 1, 0)
    Objects["realdropdown"].Size = UDim2.new(1, 0, 0, 16)
    Objects["realdropdown"].BorderSizePixel = 0
    Objects["realdropdown"].BackgroundColor3 = Library.Panel
    Objects["realdropdown"].ZIndex = 4
    Objects["realdropdown"].Parent = Objects["dropdown"]
    fourSideBorder(Objects["realdropdown"], "Border")
    Library:AddToRegistry(Objects["realdropdown"], { BackgroundColor3 = "Panel" })

    Objects["value"] = makeLabel(Objects["realdropdown"], "...", 12, "Text")
    Objects["value"].Size = UDim2.new(1, -22, 1, 0)
    Objects["value"].Position = UDim2.new(0, 6, 0, 0)

    Objects["open2"] = makeLabel(Objects["realdropdown"], "+", 12, "Text",
        Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    Objects["open2"].AnchorPoint = Vector2.new(1, 0.5)
    Objects["open2"].Position = UDim2.new(1, -4, 0.5, 0)
    Objects["open2"].Size = UDim2.new(0, 15, 1, 0)

    Objects["open1"] = Instance.new("TextButton")
    Objects["open1"].Text = ""
    Objects["open1"].BackgroundTransparency = 1
    Objects["open1"].Size = UDim2.new(1, 0, 1, 0)
    Objects["open1"].AutoButtonColor = false
    Objects["open1"].ZIndex = 6
    Objects["open1"].Parent = Objects["realdropdown"]

    Objects["optionholder"] = Instance.new("Frame")
    Objects["optionholder"].Visible = false
    Objects["optionholder"].Position = UDim2.new(0, 0, 1, 2)
    Objects["optionholder"].Size = UDim2.new(1, 0, 0, 0)
    Objects["optionholder"].AutomaticSize = Enum.AutomaticSize.Y
    Objects["optionholder"].BackgroundColor3 = Library.Panel
    Objects["optionholder"].BorderSizePixel = 0
    Objects["optionholder"].ZIndex = 50
    Objects["optionholder"].Parent = Objects["dropdown"]
    fourSideBorder(Objects["optionholder"], "Border")
    Library:AddToRegistry(Objects["optionholder"], { BackgroundColor3 = "Panel" })

    local ol = Instance.new("UIListLayout")
    ol.SortOrder = Enum.SortOrder.LayoutOrder
    ol.Padding = UDim.new(0, 1)
    ol.Parent = Objects["optionholder"]
    local op = Instance.new("UIPadding")
    op.PaddingTop = UDim.new(0, 3)
    op.PaddingBottom = UDim.new(0, 3)
    op.Parent = Objects["optionholder"]

    function Dropdown:Toggle()
        Objects["optionholder"].Visible = not Objects["optionholder"].Visible
        Objects["open2"].Text = Objects["optionholder"].Visible and "-" or "+"
        for _, d in Objects["optionholder"]:GetDescendants() do
            if d:IsA("GuiObject") then
                d.ZIndex = math.max(d.ZIndex, 51)
            end
        end
    end

    Library:Connect(Objects["open1"].MouseButton1Down, function() Dropdown:Toggle() end)

    function Dropdown:Set(Value)
        if Dropdown.Options[Value] then
            Dropdown.Value = Value
            Objects["value"].Text = tostring(Value)
            for n, opt in pairs(Dropdown.Options) do
                local isSel = (n == Value)
                opt.IsSelected = isSel
                opt.Text.TextColor3 = isSel and Library.Accent or Library.Text
            end
        end
        if Dropdown.Callback then Dropdown.Callback(Dropdown.Value) end
    end

    function Dropdown:Get() return Dropdown.Value end
    function Dropdown:SetVisibility(b) Objects["dropdown"].Visible = b end

    function Dropdown:AddOption(Name)
        local ob = Instance.new("TextButton")
        ob.Text = ""
        ob.BackgroundTransparency = 1
        ob.Size = UDim2.new(1, 0, 0, 16)
        ob.AutoButtonColor = false
        ob.ZIndex = 51
        ob.Parent = Objects["optionholder"]

        local t = makeLabel(ob, Name, 12, "Text")
        t.Position = UDim2.new(0, 6, 0, 0)
        t.Size = UDim2.new(1, -6, 1, 0)
        t.ZIndex = 52

        local Option = { Name = Name, IsSelected = false, Text = t, Button = ob }
        Library:Connect(ob.MouseButton1Down, function() Dropdown:Set(Name) end)
        Dropdown.Options[Name] = Option
        return Option
    end

    function Dropdown:RemoveOption(Name)
        if Dropdown.Options[Name] then
            Dropdown.Options[Name].Button:Destroy()
            Dropdown.Options[Name] = nil
        end
    end

    for _, v in ipairs(Data.Options) do Dropdown:AddOption(v) end
    Dropdown:Set(Dropdown.Default or Data.Options[1])

    Library.Flags[Dropdown.Flag] = Dropdown
    return Dropdown
end

-- ============================================================
-- KEYBIND
-- ============================================================
function Library.Sections:Keybind(Data)
    local Keybind = {
        Section = self, Name = Data.Name, Flag = Data.Flag,
        Mode = Data.Mode or "Toggle", Value = false,
        Callback = Data.Callback or function() end,
        IsBeingSelected = false, Default = Data.Default, AbKey = "NONE",
    }
    local Objects = {}

    Objects["keybind"] = Instance.new("Frame")
    Objects["keybind"].BackgroundTransparency = 1
    Objects["keybind"].Size = UDim2.new(1, 0, 0, 16)
    Objects["keybind"].ZIndex = 4
    Objects["keybind"].Parent = Keybind.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["keybind"], Keybind.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 1, 0)

    Objects["key"] = makeLabel(Objects["keybind"], "[NONE]", 12, "Text",
        Enum.TextXAlignment.Right, Enum.TextYAlignment.Center)
    Objects["key"].AnchorPoint = Vector2.new(1, 0.5)
    Objects["key"].Position = UDim2.new(1, 0, 0.5, 0)
    Objects["key"].AutomaticSize = Enum.AutomaticSize.X
    Objects["key"].Size = UDim2.new(0, 0, 1, 0)
    Objects["key"].BackgroundTransparency = 1

    Objects["hit"] = Instance.new("TextButton")
    Objects["hit"].Text = ""
    Objects["hit"].BackgroundTransparency = 1
    Objects["hit"].Size = UDim2.new(1, 0, 1, 0)
    Objects["hit"].AutoButtonColor = false
    Objects["hit"].ZIndex = 6
    Objects["hit"].Parent = Objects["keybind"]

    function Keybind:Set(Key, IsMouse)
        if IsMouse then
            Keybind.Key = (type(Key) == "table") and Enum.UserInputType[Key.Name] or Key
            local short = "M?"
            if Keybind.Key == Enum.UserInputType.MouseButton1 then short = "M1"
            elseif Keybind.Key == Enum.UserInputType.MouseButton2 then short = "M2"
            elseif Keybind.Key == Enum.UserInputType.MouseButton3 then short = "M3"
            elseif Keybind.Key == Enum.UserInputType.MouseWheel then short = "M4" end
            Keybind.AbKey = short
            Objects["key"].Text = "[" .. short .. "]"
        else
            if Key and Key.Name then
                Keybind.Key = (type(Key) == "table") and Enum.KeyCode[Key.Name] or Key
                Keybind.AbKey = keyToString(Keybind.Key)
                Objects["key"].Text = "[" .. Keybind.AbKey .. "]"
            end
        end
    end

    Library:Connect(Objects["hit"].MouseButton1Down, function()
        task.wait(0.1)
        Keybind.IsBeingSelected = true
        Objects["key"].Text = "[...]"
        local c
        c = Library:Connect(UserInputService.InputBegan, function(Input)
            if not Keybind.IsBeingSelected then c:Disconnect(); return end
            if Input.UserInputType == Enum.UserInputType.Keyboard then
                Keybind:Set(Input.KeyCode)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Keybind:Set(Enum.UserInputType.MouseButton1, true)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                Keybind:Set(Enum.UserInputType.MouseButton2, true)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then
                Keybind:Set(Enum.UserInputType.MouseButton3, true)
            elseif Input.UserInputType == Enum.UserInputType.MouseWheel then
                Keybind:Set(Enum.UserInputType.MouseWheel, true)
            else return end
            Keybind.IsBeingSelected = false
            c:Disconnect()
        end)
    end)

    Library:Connect(UserInputService.InputBegan, function(Input)
        if Keybind.IsBeingSelected then return end
        if Input.KeyCode == Keybind.Key or Input.UserInputType == Keybind.Key then
            if Keybind.Mode == "Toggle" then
                Keybind.Value = not Keybind.Value
                Keybind.Callback(Keybind.Value)
            elseif Keybind.Mode == "Hold" then
                Keybind.Value = true
                Keybind.Callback(Keybind.Value)
            elseif Keybind.Mode == "Press" then
                Keybind.Callback(Keybind.Value)
            end
        end
    end)

    Library:Connect(UserInputService.InputEnded, function(Input)
        if Keybind.IsBeingSelected then return end
        if (Input.KeyCode == Keybind.Key or Input.UserInputType == Keybind.Key) and Keybind.Mode == "Hold" then
            Keybind.Value = false
            Keybind.Callback(Keybind.Value)
        end
    end)

    function Keybind:Get() return Keybind.Value end
    function Keybind:SetVisibility(b) Objects["keybind"].Visible = b end

    if Keybind.Default then Keybind:Set(Keybind.Default) end
    Library.Flags[Keybind.Flag] = Keybind
    return Keybind
end

-- ============================================================
-- COLORPICKER
-- ============================================================
function Library.Sections:Colorpicker(Data)
    local Colorpicker = {
        Section = self, Name = Data.Name, Flag = Data.Flag,
        Default = Data.Default or Color3.fromRGB(255, 255, 255),
        Alpha = Data.Alpha or 0,
        Callback = Data.Callback or function() end,
    }
    local Picker = { Color = Colorpicker.Default, Transparency = Colorpicker.Alpha, IsOpen = false }
    local Objects = {}

    Objects["colorpicker"] = Instance.new("Frame")
    Objects["colorpicker"].BackgroundTransparency = 1
    Objects["colorpicker"].Size = UDim2.new(1, 0, 0, 16)
    Objects["colorpicker"].ZIndex = 4
    Objects["colorpicker"].Parent = Colorpicker.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["colorpicker"], Colorpicker.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, -30, 1, 0)

    Objects["button"] = Instance.new("TextButton")
    Objects["button"].Text = ""
    Objects["button"].AutoButtonColor = false
    Objects["button"].AnchorPoint = Vector2.new(1, 0.5)
    Objects["button"].Position = UDim2.new(1, 0, 0.5, 0)
    Objects["button"].Size = UDim2.new(0, 20, 0, 12)
    Objects["button"].BorderSizePixel = 0
    Objects["button"].ZIndex = 4
    Objects["button"].BackgroundColor3 = Colorpicker.Default
    Objects["button"].Parent = Objects["colorpicker"]
    fourSideBorder(Objects["button"], "Border")

    Objects["window"] = Instance.new("Frame")
    Objects["window"].Visible = false
    Objects["window"].Position = UDim2.new(1, 7, 0, 0)
    Objects["window"].Size = UDim2.new(0, 200, 0, 165)
    Objects["window"].BorderSizePixel = 0
    Objects["window"].ZIndex = 200
    Objects["window"].BackgroundColor3 = Library.Background
    Objects["window"].Parent = Library.MainFrame
    fourSideBorder(Objects["window"], "Border")

    Objects["palette"] = Instance.new("TextButton")
    Objects["palette"].Text = ""
    Objects["palette"].AutoButtonColor = false
    Objects["palette"].Position = UDim2.new(0, 6, 0, 7)
    Objects["palette"].Size = UDim2.new(0, 160, 0, 150)
    Objects["palette"].BorderSizePixel = 0
    Objects["palette"].ZIndex = 201
    Objects["palette"].BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    Objects["palette"].Parent = Objects["window"]
    fourSideBorder(Objects["palette"], "Border")

    Objects["sat"] = Instance.new("ImageLabel")
    Objects["sat"].BackgroundTransparency = 1
    Objects["sat"].Size = UDim2.new(1, 0, 1, 0)
    Objects["sat"].ZIndex = 201
    Objects["sat"].Image = "rbxassetid://130624743341203"
    Objects["sat"].Parent = Objects["palette"]

    Objects["val"] = Instance.new("ImageLabel")
    Objects["val"].BackgroundTransparency = 1
    Objects["val"].Size = UDim2.new(1, 0, 1, 0)
    Objects["val"].ZIndex = 202
    Objects["val"].Image = "rbxassetid://96192970265863"
    Objects["val"].Parent = Objects["palette"]

    Objects["pdrag"] = Instance.new("Frame")
    Objects["pdrag"].Size = UDim2.new(0, 3, 0, 3)
    Objects["pdrag"].AnchorPoint = Vector2.new(0.5, 0.5)
    Objects["pdrag"].ZIndex = 203
    Objects["pdrag"].BackgroundColor3 = Color3.new(1, 1, 1)
    Objects["pdrag"].Parent = Objects["palette"]
    local pds = Instance.new("UIStroke"); pds.Color = Color3.new(0, 0, 0); pds.Parent = Objects["pdrag"]

    Objects["hue"] = Instance.new("ImageButton")
    Objects["hue"].AutoButtonColor = false
    Objects["hue"].AnchorPoint = Vector2.new(1, 0)
    Objects["hue"].Image = "rbxassetid://133334110106525"
    Objects["hue"].Position = UDim2.new(1, -8, 0, 7)
    Objects["hue"].Size = UDim2.new(0, 17, 0, 150)
    Objects["hue"].BorderSizePixel = 0
    Objects["hue"].ZIndex = 201
    Objects["hue"].Parent = Objects["window"]
    fourSideBorder(Objects["hue"], "Border")

    Objects["hdrag"] = Instance.new("Frame")
    Objects["hdrag"].Size = UDim2.new(1, 0, 0, 1)
    Objects["hdrag"].ZIndex = 203
    Objects["hdrag"].BackgroundColor3 = Color3.new(1, 1, 1)
    Objects["hdrag"].Parent = Objects["hue"]
    local hds = Instance.new("UIStroke"); hds.Color = Color3.new(0, 0, 0); hds.Parent = Objects["hdrag"]

    local Colors = { h = 0, s = 1, v = 1 }
    local Mouse = lp:GetMouse()

    local function getColor() return Color3.fromHSV(Colors.h, Colors.s, Colors.v) end
    local function refresh()
        local c = getColor()
        Objects["button"].BackgroundColor3 = c
        Objects["palette"].BackgroundColor3 = Color3.fromHSV(Colors.h, 1, 1)
        Objects["pdrag"].Position = UDim2.new(1 - Colors.s, 0, 1 - Colors.v, 0)
        Objects["hdrag"].Position = UDim2.new(0, 0, 1 - Colors.h, 0)
    end

    function Picker:Set(v)
        local NColor = v.Color or v
        Picker.Color = NColor
        Picker.Transparency = v.Transparency or 0
        Colors.h, Colors.s, Colors.v = NColor:ToHSV()
        refresh()
        if Colorpicker.Callback then pcall(Colorpicker.Callback, getColor()) end
    end

    function Picker:Get() return getColor() end
    function Colorpicker:Close() Objects["window"].Visible = false; Picker.IsOpen = false end
    function Colorpicker:Toggle()
        Picker.IsOpen = not Picker.IsOpen
        if Picker.IsOpen then
            if Library.CurrentColorpicker and Library.CurrentColorpicker ~= Colorpicker then
                Library.CurrentColorpicker:Close()
            end
            Library.CurrentColorpicker = Colorpicker
            Objects["window"].Visible = true
        else
            Objects["window"].Visible = false
        end
    end
    function Colorpicker:SetVisibility(b) Objects["colorpicker"].Visible = b end

    Library:Connect(Objects["button"].MouseButton1Down, function() Colorpicker:Toggle() end)

    Library:Connect(Objects["palette"].MouseButton1Down, function()
        local function upd()
            local x = math.clamp(Mouse.X - Objects["palette"].AbsolutePosition.X, 0, Objects["palette"].AbsoluteSize.X)
            local y = math.clamp(Mouse.Y - Objects["palette"].AbsolutePosition.Y, 0, Objects["palette"].AbsoluteSize.Y)
            Colors.s = 1 - (x / Objects["palette"].AbsoluteSize.X)
            Colors.v = 1 - (y / Objects["palette"].AbsoluteSize.Y)
            refresh()
            if Colorpicker.Callback then pcall(Colorpicker.Callback, getColor()) end
        end
        upd()
        local mc = Mouse.Move:Connect(upd)
        local rc
        rc = Library:Connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                mc:Disconnect(); rc:Disconnect(); upd()
            end
        end)
    end)

    Library:Connect(Objects["hue"].MouseButton1Down, function()
        local function upd()
            local y = math.clamp(Mouse.Y - Objects["hue"].AbsolutePosition.Y, 0, Objects["hue"].AbsoluteSize.Y)
            Colors.h = 1 - (y / Objects["hue"].AbsoluteSize.Y)
            refresh()
            if Colorpicker.Callback then pcall(Colorpicker.Callback, getColor()) end
        end
        upd()
        local mc = Mouse.Move:Connect(upd)
        local rc
        rc = Library:Connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                mc:Disconnect(); rc:Disconnect(); upd()
            end
        end)
    end)

    Picker:Set({ Color = Colorpicker.Default, Transparency = Colorpicker.Alpha })
    Library.Flags[Colorpicker.Flag] = Picker
    return Colorpicker
end

-- ============================================================
-- TEXTBOX
-- ============================================================
function Library.Sections:Textbox(Data)
    local Textbox = {
        Section = self, Name = Data.Name, Flag = Data.Flag,
        Default = Data.Default, Callback = Data.Callback or function() end,
        Compact = Data.Compact or false,
        Placeholder = Data.Placeholder or "", Value = nil,
    }
    local Objects = {}

    Objects["textbox"] = Instance.new("Frame")
    Objects["textbox"].BackgroundTransparency = 1
    Objects["textbox"].Size = UDim2.new(1, 0, 0, 32)
    Objects["textbox"].ZIndex = 4
    Objects["textbox"].Parent = Textbox.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["textbox"], Textbox.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 0, 14)

    Objects["background"] = Instance.new("Frame")
    Objects["background"].AnchorPoint = Vector2.new(0, 1)
    Objects["background"].Position = UDim2.new(0, 0, 1, 0)
    Objects["background"].Size = UDim2.new(1, 0, 0, 16)
    Objects["background"].BorderSizePixel = 0
    Objects["background"].ZIndex = 4
    Objects["background"].BackgroundColor3 = Library.Panel
    Objects["background"].Parent = Objects["textbox"]
    fourSideBorder(Objects["background"], "Border")
    Library:AddToRegistry(Objects["background"], { BackgroundColor3 = "Panel" })

    Objects["realbox"] = Instance.new("TextBox")
    Objects["realbox"].Text = ""
    Objects["realbox"].PlaceholderText = Textbox.Placeholder
    Objects["realbox"].ClearTextOnFocus = false
    Objects["realbox"].TextSize = 12
    Objects["realbox"].FontFace = Fonts.Main
    Objects["realbox"].TextColor3 = Library.Text
    Objects["realbox"].BackgroundTransparency = 1
    Objects["realbox"].TextXAlignment = Enum.TextXAlignment.Left
    Objects["realbox"].Position = UDim2.new(0, 5, 0, 0)
    Objects["realbox"].Size = UDim2.new(1, -10, 1, 0)
    Objects["realbox"].ZIndex = 6
    Objects["realbox"].Parent = Objects["background"]
    textStroke(Objects["realbox"])
    Library:AddToRegistry(Objects["realbox"], { TextColor3 = "Text" })

    function Textbox:Get() return Textbox.Value end
    function Textbox:Set(v)
        Textbox.Value = v
        Objects["realbox"].Text = v
    end
    function Textbox:SetVisibility(b) Objects["textbox"].Visible = b end

    Library:Connect(Objects["realbox"].Focused, function()
        TweenService:Create(Objects["realbox"], TweenInfo.new(0.13), { TextColor3 = Library.Accent }):Play()
    end)
    Library:Connect(Objects["realbox"].FocusLost, function()
        TweenService:Create(Objects["realbox"], TweenInfo.new(0.13), { TextColor3 = Library.Text }):Play()
        Textbox:Set(Objects["realbox"].Text)
        if Textbox.Callback then Textbox.Callback(Textbox.Value) end
    end)

    if Textbox.Compact then
        Objects["text"]:Destroy()
        Objects["textbox"].Size = UDim2.new(1, 0, 0, 16)
    end

    if Textbox.Default then Textbox:Set(Textbox.Default) end
    Library.Flags[Textbox.Flag] = Textbox
    return Textbox
end

return Library
