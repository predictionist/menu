-- Halloween UI Library (converted from RoadToGlory studio export)

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
-- LIBRARY TABLE
-- ============================================================
local Library = {
    Accent       = Color3.fromRGB(255, 119, 51),
    Inline       = Color3.fromRGB(21, 21, 21),
    Background   = Color3.fromRGB(15, 15, 15),
    Text         = Color3.fromRGB(255, 255, 255),
    TextInactive = Color3.fromRGB(135, 135, 135),
    Border       = Color3.fromRGB(35, 35, 35),
    Risky        = Color3.fromRGB(255, 0, 0),

    FolderName   = "Celestial",

    Key          = Enum.KeyCode.End,
    Open         = true,

    Tabs         = {},
    RealTabs     = {},
    Sections     = {},
    Connections  = {},
    Flags        = {},
    Registry     = {},
    RegistryMap  = {},

    Holder             = nil,
    MainFrame          = nil,
    CurrentColorpicker = nil,
    NotificationHolder = nil,
    LoadedConfig       = nil,
    KeybindList        = nil,
    Watermark          = nil,

    Dragging = false,
}

Library.__index          = Library
Library.Tabs             = {}
Library.Tabs.__index     = Library.Tabs
Library.Sections         = {}
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
                faces = {{
                    name     = "WindowsXPTahoma",
                    weight   = 400,
                    style    = "Regular",
                    assetId  = asset,
                }},
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

local function doubleBorder(parent, colorKey)
    colorKey = colorKey or "Border"

    local outer = Instance.new("UIStroke")
    outer.Color = Color3.fromRGB(0, 0, 0)
    outer.Thickness = 1
    outer.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outer.LineJoinMode = Enum.LineJoinMode.Miter
    outer.Parent = parent

    local inner = Instance.new("UIStroke")
    inner.Color = Library[colorKey]
    inner.Thickness = 1
    inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    inner.BorderStrokePosition = Enum.BorderStrokePosition.Inner
    inner.LineJoinMode = Enum.LineJoinMode.Miter
    inner.Parent = parent

    Library:AddToRegistry(inner, { Color = colorKey })
    return outer, inner
end

local function glow(parent, colorKey)
    colorKey = colorKey or "Accent"
    local s = Instance.new("UIShadow")
    s.BlurRadius = UDim.new(0, 20)
    s.Color = Library[colorKey]
    s.Spread = UDim2.new(0, 2, 0, 2)
    s.Parent = parent
    Library:AddToRegistry(s, { Color = colorKey })
    return s
end

local function borderSides(parent, sides, colorKey)
    colorKey = colorKey or "Border"
    local function line(pos, size, z, isBlack)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.Position = pos
        f.Size = size
        f.ZIndex = z
        f.BackgroundColor3 = isBlack and Color3.fromRGB(0, 0, 0) or Library[colorKey]
        f.Parent = parent
        if not isBlack then
            Library:AddToRegistry(f, { BackgroundColor3 = colorKey })
        end
        return f
    end

    local z = (parent.ZIndex or 1) + 1
    if sides.top    then line(UDim2.new(0, 0, 0, 0),   UDim2.new(1, 0, 0, 1), z, true) end
    if sides.bottom then line(UDim2.new(0, 0, 1, -1),  UDim2.new(1, 0, 0, 1), z, true) end
    if sides.left   then line(UDim2.new(0, 0, 0, 0),   UDim2.new(0, 1, 1, 0), z, true) end
    if sides.right  then line(UDim2.new(1, -1, 0, 0),  UDim2.new(0, 1, 1, 0), z, true) end
    if sides.top    then line(UDim2.new(0, 1, 0, 1),   UDim2.new(1, -2, 0, 1), z) end
    if sides.bottom then line(UDim2.new(0, 1, 1, -2),  UDim2.new(1, -2, 0, 1), z) end
    if sides.left   then line(UDim2.new(0, 1, 0, 1),   UDim2.new(0, 1, 1, -2), z) end
    if sides.right  then line(UDim2.new(1, -2, 0, 1),  UDim2.new(0, 1, 1, -2), z) end
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
    l.Parent = parent
    textStroke(l)
    if colorKey then Library:AddToRegistry(l, { TextColor3 = colorKey }) end
    return l
end

local KEY_NAMES = {
    [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3",
    [Enum.UserInputType.MouseWheel]   = "MW",
    [Enum.KeyCode.LeftShift]   = "LS",
    [Enum.KeyCode.RightShift]  = "RS",
    [Enum.KeyCode.LeftControl] = "LC",
    [Enum.KeyCode.RightControl]= "RC",
    [Enum.KeyCode.LeftAlt]     = "LA",
    [Enum.KeyCode.RightAlt]    = "RA",
    [Enum.KeyCode.CapsLock]    = "CAP",
    [Enum.KeyCode.Backspace]   = "BKSP",
    [Enum.KeyCode.Return]      = "ENT",
    [Enum.KeyCode.Escape]      = "ESC",
    [Enum.KeyCode.Space]       = "SPC",
    [Enum.KeyCode.Up]          = "UP",
    [Enum.KeyCode.Down]        = "DN",
    [Enum.KeyCode.Left]        = "LT",
    [Enum.KeyCode.Right]       = "RT",
    [Enum.KeyCode.Insert]      = "INS",
    [Enum.KeyCode.Delete]      = "DEL",
    [Enum.KeyCode.Home]        = "HOM",
    [Enum.KeyCode.End]         = "END",
    [Enum.KeyCode.PageUp]      = "PGU",
    [Enum.KeyCode.PageDown]    = "PGD",
    [Enum.KeyCode.Tab]         = "TAB",
    [Enum.KeyCode.One]         = "1",
    [Enum.KeyCode.Two]         = "2",
    [Enum.KeyCode.Three]       = "3",
    [Enum.KeyCode.Four]        = "4",
    [Enum.KeyCode.Five]        = "5",
    [Enum.KeyCode.Six]         = "6",
    [Enum.KeyCode.Seven]       = "7",
    [Enum.KeyCode.Eight]       = "8",
    [Enum.KeyCode.Nine]        = "9",
    [Enum.KeyCode.Zero]        = "0",
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

function Library:Disconnect(Signal)
    Signal:Disconnect()
    table.remove(self.Connections, table.find(self.Connections, Signal))
end

function Library:SetOpen(Bool)
    if Library.MainFrame then Library.MainFrame.Visible = Bool end
    Library.Open = Bool
end

function Library:Round(Number, Float)
    return Float * math.floor(Number / Float)
end

function Library:AddToRegistry(Instance, Properties)
    local Data = { Instance = Instance, Properties = Properties, Idx = #Library.Registry + 1 }
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
    box.Size = UDim2.new(0, 0, 0, 18)
    box.BorderSizePixel = 0
    box.BackgroundColor3 = Library.Background
    box.ClipsDescendants = true
    box.Parent = Library.NotificationHolder
    doubleBorder(box, "Border")

    local liner = Instance.new("Frame")
    liner.Size = UDim2.new(0, 1, 1, 0)
    liner.BorderSizePixel = 0
    liner.BackgroundColor3 = Color or Library.Accent
    liner.Parent = box

    local lbl = makeLabel(box, Text, 11, "Text")
    lbl.Position = UDim2.new(0, 7, 0, 0)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.TextTransparency = 1

    task.spawn(function()
        local t1 = TweenService:Create(box, TweenInfo.new(0.26), { Size = UDim2.new(0, lbl.TextBounds.X + 14, 0, 18) })
        t1:Play(); t1.Completed:Wait()
        local t2 = TweenService:Create(lbl, TweenInfo.new(0.26), { TextTransparency = 0 })
        t2:Play(); t2.Completed:Wait()
        task.wait(Duration or 3)
        local t3 = TweenService:Create(box, TweenInfo.new(0.26), { Size = UDim2.new(0, 0, 0, 18) })
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
                elseif rawget(ToLib, "Value") and not rawget(ToLib, "Color") and not rawget(ToLib, "Key") then
                    ToLib:Set(Value)
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

-- Menu key
Library:Connect(UserInputService.InputBegan, function(input)
    if not Library.Key then return end
    if input.KeyCode == Library.Key then
        Library:SetOpen(not Library.Open)
    end
end)

-- ============================================================
-- WINDOW (matches your studio layout)
-- ============================================================
function Library:Window(Data)
    local Window = { Name = Data.Name, Objects = {} }
    local Objects = {}

    -- Main holder
    Objects["main"] = Instance.new("Frame")
    Objects["main"].Name = "Holder"
    Objects["main"].Position = UDim2.new(0.5, -280, 0.5, -269)
    Objects["main"].Size = UDim2.new(0, 561, 0, 538)
    Objects["main"].BackgroundColor3 = Library.Inline
    Objects["main"].BorderSizePixel = 0
    Objects["main"].Parent = Library.Holder
    doubleBorder(Objects["main"], "Border")
    Library:AddToRegistry(Objects["main"], { BackgroundColor3 = "Inline" })
    Library.MainFrame = Objects["main"]

    -- Title
    Objects["title"] = makeLabel(Objects["main"], Window.Name, 14, "Accent")
    Objects["title"].Position = UDim2.new(0.035, 0, 0.007, 0)
    Objects["title"].Size = UDim2.new(0, 100, 0, 16)

    -- Accent line under title
    Objects["line"] = Instance.new("Frame")
    Objects["line"].Position = UDim2.new(0.0107, 0, 0.0483, 0)
    Objects["line"].Size = UDim2.new(0, 548, 0, 2)
    Objects["line"].BorderSizePixel = 0
    Objects["line"].BackgroundColor3 = Library.Accent
    Objects["line"].Parent = Objects["main"]
    Library:AddToRegistry(Objects["line"], { BackgroundColor3 = "Accent" })
    glow(Objects["line"], "Accent")

    -- Game title (right side)
    Objects["gametitle"] = makeLabel(Objects["main"], "[" .. tostring(game.GameId) .. "] " .. game.Name, 14, "TextInactive",
        Enum.TextXAlignment.Right, Enum.TextYAlignment.Center)
    Objects["gametitle"].Position = UDim2.new(1, -200, 0.004, 0)
    Objects["gametitle"].Size = UDim2.new(0, 190, 0, 19)
    Library:RemoveFromRegistry(Objects["gametitle"])
    Library:AddToRegistry(Objects["gametitle"], { TextColor3 = "TextInactive" })

    -- Tab button holder
    Objects["tabholder"] = Instance.new("Frame")
    Objects["tabholder"].Name = "Tab Holder"
    Objects["tabholder"].Position = UDim2.new(0.0107, 0, 0.1245, 0)
    Objects["tabholder"].Size = UDim2.new(0, 548, 0, 464)
    Objects["tabholder"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["tabholder"].BorderSizePixel = 0
    Objects["tabholder"].Parent = Objects["main"]
    doubleBorder(Objects["tabholder"], "Border")
    Library:AddToRegistry(Objects["tabholder"], { BackgroundColor3 = "Inline" })

    -- Tab button row (top)
    Objects["tabs"] = Instance.new("Frame")
    Objects["tabs"].Name = "Tabs"
    Objects["tabs"].Position = UDim2.new(0, 0, 0, -34)
    Objects["tabs"].Size = UDim2.new(1, 0, 0, 27)
    Objects["tabs"].BackgroundTransparency = 1
    Objects["tabs"].Parent = Objects["tabholder"]

    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 8)
    tl.SortOrder = Enum.SortOrder.LayoutOrder
    tl.VerticalAlignment = Enum.VerticalAlignment.Center
    tl.Parent = Objects["tabs"]

    -- Tab content (scrolling)
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
    Objects["content"].Parent = Objects["tabholder"]
    Library:AddToRegistry(Objects["content"], { ScrollBarImageColor3 = "Accent" })

    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 8)
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Parent = Objects["content"]

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
    Objects["button"].Text = " " .. Tab.Name
    Objects["button"].TextColor3 = Library.TextInactive
    Objects["button"].TextSize = 14
    Objects["button"].AutoButtonColor = false
    Objects["button"].Size = UDim2.new(0, 80, 0, 27)
    Objects["button"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["button"].BorderSizePixel = 0
    Objects["button"].Name = Tab.Name
    Objects["button"].Parent = Tab.Window.Objects.Tabs
    borderSides(Objects["button"], { top = true, left = true, right = true }, "Border")
    Library:AddToRegistry(Objects["button"], { BackgroundColor3 = "Inline" })
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
    Objects["content"].Parent = Tab.Window.Objects.Content
    Library:AddToRegistry(Objects["content"], { ScrollBarImageColor3 = "Accent" })

    Objects["left"] = Instance.new("Frame")
    Objects["left"].Name = "Left"
    Objects["left"].BackgroundTransparency = 1
    Objects["left"].Position = UDim2.new(0, 0, 0, 0)
    Objects["left"].Size = UDim2.new(0.49, 0, 1, 0)
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
    Objects["right"].Size = UDim2.new(0.49, 0, 1, 0)
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
        TweenService:Create(Objects["button"], TweenInfo.new(0.13), { TextColor3 = Bool and Library.Accent or Library.TextInactive }):Play()
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
    Objects["section"].Size = UDim2.new(1, 0, 0, 25)
    Objects["section"].BorderSizePixel = 0
    Objects["section"].AutomaticSize = Enum.AutomaticSize.Y
    Objects["section"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["section"].Parent = (Section.Side:lower() == "left" and Section.Tab.Objects.Left)
        or (Section.Side:lower() == "right" and Section.Tab.Objects.Right)
        or Section.Tab.Objects.Left
    doubleBorder(Objects["section"], "Border")
    Library:AddToRegistry(Objects["section"], { BackgroundColor3 = "Inline" })

    Objects["liner"] = Instance.new("Frame")
    Objects["liner"].Name = "Section Line"
    Objects["liner"].Size = UDim2.new(1, 0, 0, 1)
    Objects["liner"].BorderSizePixel = 0
    Objects["liner"].BackgroundColor3 = Library.Accent
    Objects["liner"].Parent = Objects["section"]
    Library:AddToRegistry(Objects["liner"], { BackgroundColor3 = "Accent" })
    glow(Objects["liner"], "Accent")

    Objects["text"] = makeLabel(Objects["section"], Section.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(0, 50, 0, 13)
    Objects["text"].Position = UDim2.new(0, 10, 0, -7)
    Objects["text"].AutomaticSize = Enum.AutomaticSize.X
    Objects["text"].BackgroundColor3 = Library.Inline
    Objects["text"].BackgroundTransparency = 0
    Objects["text"].ZIndex = 2
    Library:AddToRegistry(Objects["text"], { TextColor3 = "Text", BackgroundColor3 = "Inline" })

    Objects["content"] = Instance.new("Frame")
    Objects["content"].Name = "Content"
    Objects["content"].BackgroundTransparency = 1
    Objects["content"].Position = UDim2.new(0, 6, 0, 10)
    Objects["content"].Size = UDim2.new(1, -12, 1, -4)
    Objects["content"].AutomaticSize = Enum.AutomaticSize.Y
    Objects["content"].Parent = Objects["section"]

    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 6)
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Parent = Objects["content"]

    Section.Objects = { Main = Objects["content"] }
    return setmetatable(Section, Library.Sections)
end

-- ============================================================
-- TOGGLE (+ chained :Keybind / :Colorpicker)
-- ============================================================
function Library.Sections:Toggle(Data)
    local Toggle = {
        Section = self,
        Name = Data.Name,
        Flag = Data.Flag,
        Callback = Data.Callback or function() end,
        State = Data.Default,
        Value = false,
        Pickers = 0,
        Risky = Data.Risky or false,
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
    Objects["toggle"].Parent = Toggle.Section.Objects.Main

    Objects["indicator"] = Instance.new("Frame")
    Objects["indicator"].Name = "indicator"
    Objects["indicator"].Size = UDim2.new(0, 16, 0, 16)
    Objects["indicator"].BorderSizePixel = 0
    Objects["indicator"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["indicator"].Parent = Objects["toggle"]
    doubleBorder(Objects["indicator"], "Border")
    Library:AddToRegistry(Objects["indicator"], { BackgroundColor3 = "Inline" })

    Objects["text"] = makeLabel(Objects["toggle"], Toggle.Name, 12, "Text")
    Objects["text"].Position = UDim2.new(0, 24, 0, 0)
    Objects["text"].Size = UDim2.new(1, -60, 1, 0)
    Objects["text"].TextTransparency = 0.4

    if Toggle.Risky then
        Library:RemoveFromRegistry(Objects["text"])
        Library:AddToRegistry(Objects["text"], { TextColor3 = "Risky" })
    end

    function Toggle:Set(Value)
        Toggle.Value = Value
        Library:RemoveFromRegistry(Objects["indicator"])
        Library:AddToRegistry(Objects["indicator"], { BackgroundColor3 = Value and "Accent" or "Inline" })
        TweenService:Create(Objects["indicator"], TweenInfo.new(0.13, Enum.EasingStyle.Sine),
            { BackgroundColor3 = Value and Library.Accent or Color3.fromRGB(23, 23, 23) }):Play()
        TweenService:Create(Objects["text"], TweenInfo.new(0.13, Enum.EasingStyle.Sine),
            { TextTransparency = Value and 0 or 0.4 }):Play()
        if Toggle.Callback then Toggle.Callback(Value) end
    end

    function Toggle:Get() return Toggle.Value end
    function Toggle:SetVisibility(Boolean) Objects["toggle"].Visible = Boolean end

    Library:Connect(Objects["toggle"].MouseButton1Down, function() Toggle:Set(not Toggle.Value) end)

    -- Chained keybind
    function Toggle:Keybind(Data)
        local Keybind = {
            Section = self,
            Name = Data.Name,
            Flag = Data.Flag,
            Mode = Data.Mode or "Toggle",
            Value = false,
            Callback = Data.Callback or function() end,
            IsBeingSelected = false,
            Default = Data.Default,
            AbKey = "NONE",
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
        Sub["key"].Parent = Objects["toggle"]
        textStroke(Sub["key"])

        local keyObj
        if Library.KeybindList then
            keyObj = Library.KeybindList:AddNewKey("None", Keybind.Name)
        end

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
            if keyObj then keyObj:Set(Keybind.AbKey, Keybind.Name) end
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
                else
                    return
                end
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
-- BUTTON (+ chained :Sub)
-- ============================================================
function Library.Sections:Button(Data)
    local Button = { Section = self, Name = Data.Name, Callback = Data.Callback or function() end }
    local Objects = {}

    Objects["button"] = Instance.new("TextButton")
    Objects["button"].FontFace = Fonts.Main
    Objects["button"].Text = ""
    Objects["button"].AutoButtonColor = false
    Objects["button"].Size = UDim2.new(1, 0, 0, 16)
    Objects["button"].BorderSizePixel = 0
    Objects["button"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["button"].Parent = Button.Section.Objects.Main
    local bs = doubleBorder(Objects["button"], "Border")
    Library:AddToRegistry(Objects["button"], { BackgroundColor3 = "Inline" })

    Objects["text"] = makeLabel(Objects["button"], Button.Name, 12, "Text",
        Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    Objects["text"].Size = UDim2.new(1, 0, 1, 0)

    Library:Connect(Objects["button"].MouseButton1Down, function()
        if bs then TweenService:Create(bs, TweenInfo.new(0.1), { Color = Library.Accent }):Play() end
        task.wait(0.1)
        if bs then TweenService:Create(bs, TweenInfo.new(0.1), { Color = Library.Border }):Play() end
        pcall(Button.Callback)
    end)

    function Button:Sub(Data)
        local SubButton = { Name = Data.Name, Callback = Data.Callback or function() end }
        Objects["button"].Size = UDim2.new(0.48, 0, 0, 16)

        local s = Instance.new("TextButton")
        s.Text = ""
        s.AutoButtonColor = false
        s.Position = UDim2.new(1, 5, 0, 0)
        s.Size = UDim2.new(1, 0, 1, 0)
        s.BorderSizePixel = 0
        s.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
        s.Parent = Objects["button"]
        doubleBorder(s, "Border")

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
        Section = self,
        Name = Data.Name,
        Min = Data.Min or 0,
        Max = Data.Max or 100,
        Suffix = Data.Sub or "",
        State = Data.Default,
        Flag = Data.Flag,
        Value = 0,
        Decimals = Data.Decimals or 1,
        Callback = Data.Callback or function() end,
    }
    local Objects = {}

    Objects["slider"] = Instance.new("Frame")
    Objects["slider"].BackgroundTransparency = 1
    Objects["slider"].Size = UDim2.new(1, 0, 0, 26)
    Objects["slider"].Parent = Slider.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["slider"], Slider.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 0, 14)

    Objects["realslider"] = Instance.new("TextButton")
    Objects["realslider"].AnchorPoint = Vector2.new(0, 1)
    Objects["realslider"].Position = UDim2.new(0, 0, 1, 0)
    Objects["realslider"].Size = UDim2.new(1, 0, 0, 8)
    Objects["realslider"].BorderSizePixel = 0
    Objects["realslider"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["realslider"].Text = ""
    Objects["realslider"].AutoButtonColor = false
    Objects["realslider"].Parent = Objects["slider"]
    doubleBorder(Objects["realslider"], "Border")
    Library:AddToRegistry(Objects["realslider"], { BackgroundColor3 = "Inline" })

    Objects["indicator"] = Instance.new("Frame")
    Objects["indicator"].Size = UDim2.new(0, 0, 1, 0)
    Objects["indicator"].BorderSizePixel = 0
    Objects["indicator"].BackgroundColor3 = Library.Accent
    Objects["indicator"].Parent = Objects["realslider"]
    Library:AddToRegistry(Objects["indicator"], { BackgroundColor3 = "Accent" })

    Objects["value"] = makeLabel(Objects["realslider"], "0", 11, "Text",
        Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    Objects["value"].Size = UDim2.new(1, 0, 1, 0)

    local function set(value)
        value = math.clamp(Library:Round(value, Slider.Decimals), Slider.Min, Slider.Max)
        local t = (value - Slider.Min) / (Slider.Max - Slider.Min)
        Objects["indicator"].Size = UDim2.new(t, 0, 1, 0)
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
        Section = self,
        Flag = Data.Flag,
        Name = Data.Name or "Dropdown",
        Default = Data.Default,
        Options = {},
        Callback = Data.Callback or function() end,
        Value = nil,
    }
    local Objects = {}

    Objects["dropdown"] = Instance.new("Frame")
    Objects["dropdown"].BackgroundTransparency = 1
    Objects["dropdown"].Size = UDim2.new(1, 0, 0, 32)
    Objects["dropdown"].Parent = Dropdown.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["dropdown"], Dropdown.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 0, 14)

    Objects["realdropdown"] = Instance.new("Frame")
    Objects["realdropdown"].AnchorPoint = Vector2.new(0, 1)
    Objects["realdropdown"].Position = UDim2.new(0, 0, 1, 0)
    Objects["realdropdown"].Size = UDim2.new(1, 0, 0, 15)
    Objects["realdropdown"].BorderSizePixel = 0
    Objects["realdropdown"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["realdropdown"].Parent = Objects["dropdown"]
    doubleBorder(Objects["realdropdown"], "Border")
    Library:AddToRegistry(Objects["realdropdown"], { BackgroundColor3 = "Inline" })

    Objects["value"] = makeLabel(Objects["realdropdown"], "...", 12, "Text")
    Objects["value"].Size = UDim2.new(1, -20, 1, 0)
    Objects["value"].Position = UDim2.new(0, 5, 0, 0)

    Objects["open2"] = makeLabel(Objects["realdropdown"], "+", 12, "Text",
        Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    Objects["open2"].AnchorPoint = Vector2.new(1, 0.5)
    Objects["open2"].Position = UDim2.new(1, -2, 0.5, 0)
    Objects["open2"].Size = UDim2.new(0, 15, 1, 0)

    Objects["open1"] = Instance.new("TextButton")
    Objects["open1"].Text = ""
    Objects["open1"].BackgroundTransparency = 1
    Objects["open1"].Size = UDim2.new(1, 0, 1, 0)
    Objects["open1"].AutoButtonColor = false
    Objects["open1"].Parent = Objects["realdropdown"]

    Objects["optionholder"] = Instance.new("Frame")
    Objects["optionholder"].Visible = false
    Objects["optionholder"].Position = UDim2.new(0, 0, 1, 4)
    Objects["optionholder"].Size = UDim2.new(1, 0, 0, 15)
    Objects["optionholder"].AutomaticSize = Enum.AutomaticSize.Y
    Objects["optionholder"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["optionholder"].BorderSizePixel = 0
    Objects["optionholder"].ZIndex = 50
    Objects["optionholder"].Parent = Objects["dropdown"]
    doubleBorder(Objects["optionholder"], "Border")
    Library:AddToRegistry(Objects["optionholder"], { BackgroundColor3 = "Inline" })

    local ol = Instance.new("UIListLayout")
    ol.SortOrder = Enum.SortOrder.LayoutOrder
    ol.Parent = Objects["optionholder"]

    function Dropdown:Toggle()
        Objects["optionholder"].Visible = not Objects["optionholder"].Visible
        Objects["open2"].Text = Objects["optionholder"].Visible and "-" or "+"
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
        ob.Size = UDim2.new(1, 0, 0, 15)
        ob.AutoButtonColor = false
        ob.ZIndex = 51
        ob.Parent = Objects["optionholder"]

        local t = makeLabel(ob, Name, 12, "Text")
        t.Position = UDim2.new(0, 5, 0, 0)
        t.Size = UDim2.new(1, -5, 1, 0)
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
-- KEYBIND (standalone)
-- ============================================================
function Library.Sections:Keybind(Data)
    local Keybind = {
        Section = self,
        Name = Data.Name,
        Flag = Data.Flag,
        Mode = Data.Mode or "Toggle",
        Value = false,
        Callback = Data.Callback or function() end,
        IsBeingSelected = false,
        Default = Data.Default,
        AbKey = "NONE",
    }
    local Objects = {}

    Objects["keybind"] = Instance.new("Frame")
    Objects["keybind"].BackgroundTransparency = 1
    Objects["keybind"].Size = UDim2.new(1, 0, 0, 16)
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
            else
                return
            end
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
-- COLORPICKER (standalone)
-- ============================================================
function Library.Sections:Colorpicker(Data)
    local Colorpicker = {
        Section = self,
        Name = Data.Name,
        Flag = Data.Flag,
        Default = Data.Default or Color3.fromRGB(255, 255, 255),
        Alpha = Data.Alpha or 0,
        Callback = Data.Callback or function() end,
    }
    local Picker = { Color = Colorpicker.Default, Transparency = Colorpicker.Alpha, IsOpen = false }
    local Objects = {}

    Objects["colorpicker"] = Instance.new("Frame")
    Objects["colorpicker"].BackgroundTransparency = 1
    Objects["colorpicker"].Size = UDim2.new(1, 0, 0, 16)
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
    Objects["button"].BackgroundColor3 = Colorpicker.Default
    Objects["button"].Parent = Objects["colorpicker"]
    doubleBorder(Objects["button"], "Border")

    Objects["window"] = Instance.new("Frame")
    Objects["window"].Visible = false
    Objects["window"].Position = UDim2.new(1, 7, 0, 0)
    Objects["window"].Size = UDim2.new(0, 200, 0, 165)
    Objects["window"].BorderSizePixel = 0
    Objects["window"].BackgroundColor3 = Library.Background
    Objects["window"].Parent = Library.MainFrame
    doubleBorder(Objects["window"], "Border")

    Objects["palette"] = Instance.new("TextButton")
    Objects["palette"].Text = ""
    Objects["palette"].AutoButtonColor = false
    Objects["palette"].Position = UDim2.new(0, 6, 0, 7)
    Objects["palette"].Size = UDim2.new(0, 160, 0, 150)
    Objects["palette"].BorderSizePixel = 0
    Objects["palette"].BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    Objects["palette"].Parent = Objects["window"]
    doubleBorder(Objects["palette"], "Border")

    Objects["sat"] = Instance.new("ImageLabel")
    Objects["sat"].BackgroundTransparency = 1
    Objects["sat"].Size = UDim2.new(1, 0, 1, 0)
    Objects["sat"].Image = "rbxassetid://130624743341203"
    Objects["sat"].Parent = Objects["palette"]

    Objects["val"] = Instance.new("ImageLabel")
    Objects["val"].BackgroundTransparency = 1
    Objects["val"].Size = UDim2.new(1, 0, 1, 0)
    Objects["val"].Image = "rbxassetid://96192970265863"
    Objects["val"].Parent = Objects["palette"]

    Objects["pdrag"] = Instance.new("Frame")
    Objects["pdrag"].Size = UDim2.new(0, 3, 0, 3)
    Objects["pdrag"].AnchorPoint = Vector2.new(0.5, 0.5)
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
    Objects["hue"].Parent = Objects["window"]
    doubleBorder(Objects["hue"], "Border")

    Objects["hdrag"] = Instance.new("Frame")
    Objects["hdrag"].Size = UDim2.new(1, 0, 0, 1)
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
        Section = self,
        Name = Data.Name,
        Flag = Data.Flag,
        Default = Data.Default,
        Callback = Data.Callback or function() end,
        Compact = Data.Compact or false,
        Placeholder = Data.Placeholder or "",
        Value = nil,
    }
    local Objects = {}

    Objects["textbox"] = Instance.new("Frame")
    Objects["textbox"].BackgroundTransparency = 1
    Objects["textbox"].Size = UDim2.new(1, 0, 0, 32)
    Objects["textbox"].Parent = Textbox.Section.Objects.Main

    Objects["text"] = makeLabel(Objects["textbox"], Textbox.Name, 12, "Text")
    Objects["text"].Size = UDim2.new(1, 0, 0, 14)

    Objects["background"] = Instance.new("Frame")
    Objects["background"].AnchorPoint = Vector2.new(0, 1)
    Objects["background"].Position = UDim2.new(0, 0, 1, 0)
    Objects["background"].Size = UDim2.new(1, 0, 0, 15)
    Objects["background"].BorderSizePixel = 0
    Objects["background"].BackgroundColor3 = Color3.fromRGB(23, 23, 23)
    Objects["background"].Parent = Objects["textbox"]
    doubleBorder(Objects["background"], "Border")
    Library:AddToRegistry(Objects["background"], { BackgroundColor3 = "Inline" })

    Objects["realbox"] = Instance.new("TextBox")
    Objects["realbox"].Text = ""
    Objects["realbox"].PlaceholderText = Textbox.Placeholder
    Objects["realbox"].ClearTextOnFocus = false
    Objects["realbox"].TextSize = 12
    Objects["realbox"].FontFace = Fonts.Main
    Objects["realbox"].TextColor3 = Library.Text
    Objects["realbox"].BackgroundTransparency = 1
    Objects["realbox"].TextXAlignment = Enum.TextXAlignment.Left
    Objects["realbox"].Position = UDim2.new(0, 3, 0, 0)
    Objects["realbox"].Size = UDim2.new(1, -6, 1, -1)
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
        Objects["textbox"].Size = UDim2.new(1, 0, 0, 15)
    end

    if Textbox.Default then Textbox:Set(Textbox.Default) end
    Library.Flags[Textbox.Flag] = Textbox
    return Textbox
end

-- ============================================================
-- WATERMARK
-- ============================================================
function Library:Watermark(Data)
    local Watermark = {}
    local Objects = {}

    Objects["watermark"] = Instance.new("Frame")
    Objects["watermark"].AnchorPoint = Vector2.new(0.5, 0)
    Objects["watermark"].Position = UDim2.new(0.5, 0, 0, 20)
    Objects["watermark"].Size = UDim2.new(0, 300, 0, 25)
    Objects["watermark"].BorderSizePixel = 0
    Objects["watermark"].BackgroundColor3 = Library.Background
    Objects["watermark"].Parent = Library.Holder
    doubleBorder(Objects["watermark"], "Border")
    Library:AddToRegistry(Objects["watermark"], { BackgroundColor3 = "Background" })

    Objects["text"] = makeLabel(Objects["watermark"], Data.Name, 12, "Text")
    Objects["text"].Position = UDim2.new(0, 8, 0, 0)
    Objects["text"].Size = UDim2.new(0, 0, 1, 0)
    Objects["text"].AutomaticSize = Enum.AutomaticSize.X

    Objects["accent"] = Instance.new("Frame")
    Objects["accent"].Size = UDim2.new(1, 0, 0, 1)
    Objects["accent"].BorderSizePixel = 0
    Objects["accent"].BackgroundColor3 = Library.Accent
    Objects["accent"].Parent = Objects["watermark"]
    Library:AddToRegistry(Objects["accent"], { BackgroundColor3 = "Accent" })

    function Watermark:SetVisiblity(b) Objects["watermark"].Visible = b end

    task.spawn(function()
        Objects["watermark"].Size = UDim2.new(0, Objects["text"].TextBounds.X + 20, 0, 25)
        local frameTime = tick()
        local frameCount = 0
        local fps = 60
        RunService.RenderStepped:Connect(function()
            frameCount += 1
            if (tick() - frameTime) >= 1 then
                fps = frameCount
                frameTime = tick()
                frameCount = 0
            end
            Objects["text"].Text = ("%s  |  %d fps  |  %d ms"):format(
                Data.Name,
                math.floor(fps),
                math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
            )
            Objects["watermark"].Size = UDim2.new(0, Objects["text"].TextBounds.X + 20, 0, 25)
        end)
    end)

    Library.Watermark = Watermark
    return Watermark
end

-- ============================================================
-- KEYBIND LIST
-- ============================================================
function Library:KeybindList()
    local KeyList = {}
    local Objects = {}

    Objects["keybindlist"] = Instance.new("Frame")
    Objects["keybindlist"].AnchorPoint = Vector2.new(0, 0.5)
    Objects["keybindlist"].Position = UDim2.new(0, 20, 0.5, 0)
    Objects["keybindlist"].Size = UDim2.new(0, 100, 0, 18)
    Objects["keybindlist"].AutomaticSize = Enum.AutomaticSize.XY
    Objects["keybindlist"].BorderSizePixel = 0
    Objects["keybindlist"].BackgroundColor3 = Library.Background
    Objects["keybindlist"].Parent = Library.Holder
    doubleBorder(Objects["keybindlist"], "Border")
    Library:AddToRegistry(Objects["keybindlist"], { BackgroundColor3 = "Background" })

    Objects["title"] = makeLabel(Objects["keybindlist"], "Keybinds", 12, "Text")
    Objects["title"].Position = UDim2.new(0, 6, 0, 2)
    Objects["title"].Size = UDim2.new(1, -12, 0, 16)

    Objects["accent"] = Instance.new("Frame")
    Objects["accent"].Size = UDim2.new(1, 0, 0, 1)
    Objects["accent"].Position = UDim2.new(0, 0, 1, -1)
    Objects["accent"].BorderSizePixel = 0
    Objects["accent"].BackgroundColor3 = Library.Accent
    Objects["accent"].Parent = Objects["keybindlist"]
    Library:AddToRegistry(Objects["accent"], { BackgroundColor3 = "Accent" })

    Objects["content"] = Instance.new("Frame")
    Objects["content"].BackgroundTransparency = 1
    Objects["content"].Position = UDim2.new(0, 6, 0, 20)
    Objects["content"].Size = UDim2.new(1, -12, 0, 0)
    Objects["content"].AutomaticSize = Enum.AutomaticSize.XY
    Objects["content"].Parent = Objects["keybindlist"]

    local cl = Instance.new("UIListLayout")
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Parent = Objects["content"]

    function KeyList:SetVisibility(b) Objects["keybindlist"].Visible = b end

    function KeyList:AddNewKey(Key, Name)
        local lbl = makeLabel(Objects["content"], ("[%s]: %s"):format(Key, Name), 12, "Accent")
        lbl.Size = UDim2.new(0, 100, 0, 16)
        lbl.AutomaticSize = Enum.AutomaticSize.X
        local NewKey = {}
        function NewKey:SetVisiblity(b) lbl.Visible = b end
        function NewKey:Set(k, n) lbl.Text = ("[%s]: %s"):format(k, n) end
        return NewKey
    end

    Library.KeybindList = KeyList
    return KeyList
end

return Library
