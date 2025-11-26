local ESPHelper = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

local function NewText(color, size)
    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Color = color
    text.Size = size or 14
    return text
end

local BaseESP = {}
BaseESP.__index = BaseESP

function BaseESP.new(espType)
    local self = setmetatable({}, BaseESP)

    self.espType = espType or "Base"
    self._name = espType or "ESP"
    self._highlight = false
    self._highlightTransparency = 0
    self._highlightOutlineTransparency = 0
    self._fontSize = 14
    self._color = Color3.new(1, 1, 1)
    self._enable = false
    self._espDistance = 1000
    self._showDistance = true
    self._showHealth = false

    self.ActiveObjects = {}
    self.RenderConnections = {}

    return self
end

function BaseESP:__index(key)
    if key == "Name" then return self._name
    elseif key == "Highlight" then return self._highlight
    elseif key == "HighlightTransparency" then return self._highlightTransparency
    elseif key == "HighlightOutlineTransparency" then return self._highlightOutlineTransparency
    elseif key == "fontSize" then return self._fontSize
    elseif key == "Color" then return self._color
    elseif key == "Enable" then return self._enable
    elseif key == "espDistance" then return self._espDistance
    elseif key == "ShowDistance" then return self._showDistance
    elseif key == "ShowHealth" then return self._showHealth
    else return BaseESP[key]
    end
end

function BaseESP:__newindex(key, value)
    if key == "Name" then
        self._name = value
        self:_updateAllTexts()
    elseif key == "Highlight" then
        self._highlight = value
        self:_updateAllHighlights()
    elseif key == "HighlightTransparency" then
        self._highlightTransparency = value
        self:_updateAllHighlights()
    elseif key == "HighlightOutlineTransparency" then
        self._highlightOutlineTransparency = value
        self:_updateAllHighlights()
    elseif key == "fontSize" then
        self._fontSize = value
        self:_updateAllTexts()
    elseif key == "Color" then
        self._color = value
        self:_updateAllTexts()
        self:_updateAllHighlights()
    elseif key == "Enable" then
        self._enable = value
        self:_updateEnableState()
    elseif key == "espDistance" then
        self._espDistance = value
    elseif key == "ShowDistance" then
        self._showDistance = value
        self:_updateAllTexts()
    elseif key == "ShowHealth" then
        self._showHealth = value
        self:_updateAllTexts()
    else
        rawset(self, key, value)
    end
end

function BaseESP:_updateAllTexts()
    for obj, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Size = self._fontSize
            data.espText.Color = self._color
        end
    end
end

function BaseESP:_updateAllHighlights()
    for obj, data in pairs(self.ActiveObjects) do
        if data.highlight then
            data.highlight.FillColor = self._color
            data.highlight.OutlineColor = self._color
            data.highlight.FillTransparency = self._highlightTransparency
            data.highlight.OutlineTransparency = self._highlightOutlineTransparency
            data.highlight.Enabled = self._highlight and self._enable
        end
    end
end

function BaseESP:_startRenderLoop(obj, updateFunction)
    local renderName = "UpdateESP_" .. self.espType .. "_" .. tostring(obj):gsub("%W", "_")

    if self.RenderConnections[renderName] then
        RunService:UnbindFromRenderStep(renderName)
    end

    if self._enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, updateFunction)
    end
end

function BaseESP:_updateEnableState()

    for obj, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Visible = self._enable
        end
        if data.highlight then
            data.highlight.Enabled = self._highlight and self._enable
        end
    end

    for obj, data in pairs(self.ActiveObjects) do
        if data.updateFunction then
            self:_startRenderLoop(obj, data.updateFunction)
        end
    end

    if not self._enable then

        for name in pairs(self.RenderConnections) do
            RunService:UnbindFromRenderStep(name)
        end
        self.RenderConnections = {}
    end
end

function BaseESP:Remove(obj)
    if self.ActiveObjects[obj] then
        local data = self.ActiveObjects[obj]

        if data.espText then
            data.espText:Remove()
        end

        if data.highlight then
            data.highlight:Destroy()
        end

        local renderName = "UpdateESP_" .. self.espType .. "_" .. tostring(obj):gsub("%W", "_")
        if self.RenderConnections[renderName] then
            RunService:UnbindFromRenderStep(renderName)
            self.RenderConnections[renderName] = nil
        end

        self.ActiveObjects[obj] = nil
    end
end

function BaseESP:ClearAll()
    for obj in pairs(self.ActiveObjects) do
        self:Remove(obj)
    end
    self.ActiveObjects = {}
end

local HumanoidESP = setmetatable({}, {__index = BaseESP})
HumanoidESP.__index = HumanoidESP

function HumanoidESP.new(name)
    local self = setmetatable(BaseESP.new("Humanoid"), HumanoidESP)
    self._name = name or "Humanoid"
    self._showHealth = true
    return self
end

function HumanoidESP:Set(model)
    if not model or not model:IsA("Model") or self.ActiveObjects[model] then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")

    if not (humanoid and rootPart) then
        return false
    end

    local espText = NewText(self._color, self._fontSize)

    local highlight = nil
    if self._highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.FillColor = self._color
        highlight.OutlineColor = self._color
        highlight.FillTransparency = self._highlightTransparency
        highlight.OutlineTransparency = self._highlightOutlineTransparency
        highlight.Enabled = self._highlight and self._enable
    end

    local function UpdateESP()
        if not self._enable or not model or not model.Parent then
            self:Remove(model)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then return end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        local distance = (rootPart.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

        if distance <= self._espDistance and onScreen then
            local displayName = model:GetAttribute("CharacterName") or self._name or model.Name

            local text = displayName
            if self._showDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end
            if self._showHealth and humanoid and humanoid.MaxHealth > 0 then
                local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
                text = text .. string.format(" [HP: %d%%]", healthPercent)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = self._highlight and self._enable
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        humanoid = humanoid,
        rootPart = rootPart,
        updateFunction = UpdateESP
    }

    self:_startRenderLoop(model, UpdateESP)

    model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:Remove(model)
        end
    end)

    humanoid.Died:Connect(function()
        self:Remove(model)
    end)

    return true
end

local PartESP = setmetatable({}, {__index = BaseESP})
PartESP.__index = PartESP

function PartESP.new(name)
    local self = setmetatable(BaseESP.new("Part"), PartESP)
    self._name = name or "Part"
    return self
end

function PartESP:Set(part)
    if not part or not part:IsA("BasePart") or self.ActiveObjects[part] then
        return false
    end

    local espText = NewText(self._color, self._fontSize)

    local highlight = nil
    if self._highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = part
        highlight.FillColor = self._color
        highlight.OutlineColor = self._color
        highlight.FillTransparency = self._highlightTransparency
        highlight.OutlineTransparency = self._highlightOutlineTransparency
        highlight.Enabled = self._highlight and self._enable
    end

    local function UpdateESP()
        if not self._enable or not part or not part.Parent then
            self:Remove(part)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then return end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        local distance = (part.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)

        if distance <= self._espDistance and onScreen then
            local displayName = self._name or part.Name

            local text = displayName
            if self._showDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = self._highlight and self._enable
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    self.ActiveObjects[part] = {
        espText = espText,
        highlight = highlight,
        part = part,
        updateFunction = UpdateESP
    }

    self:_startRenderLoop(part, UpdateESP)

    part.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:Remove(part)
        end
    end)

    return true
end

local PivotESP = setmetatable({}, {__index = BaseESP})
PivotESP.__index = PivotESP

function PivotESP.new(name)
    local self = setmetatable(BaseESP.new("Pivot"), PivotESP)
    self._name = name or "Pivot"
    return self
end

function PivotESP:Set(model)
    if not model or not model:IsA("Model") or self.ActiveObjects[model] then
        return false
    end

    local espText = NewText(self._color, self._fontSize)

    local highlight = nil
    if self._highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.FillColor = self._color
        highlight.OutlineColor = self._color
        highlight.FillTransparency = self._highlightTransparency
        highlight.OutlineTransparency = self._highlightOutlineTransparency
        highlight.Enabled = self._highlight and self._enable
    end

    local function UpdateESP()
        if not self._enable or not model or not model.Parent then
            self:Remove(model)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then return end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        local pivot = model:GetPivot()
        local distance = (pivot.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(pivot.Position)

        if distance <= self._espDistance and onScreen then
            local displayName = self._name or model.Name

            local text = displayName
            if self._showDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = self._highlight and self._enable
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        model = model,
        updateFunction = UpdateESP
    }

    self:_startRenderLoop(model, UpdateESP)

    model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:Remove(model)
        end
    end)

    return true
end

function ESPHelper.CreateHumanoidESP(name)
    return HumanoidESP.new(name)
end

function ESPHelper.CreatePartESP(name)
    return PartESP.new(name)
end

function ESPHelper.CreatePivotESP(name)
    return PivotESP.new(name)
end

return ESPHelper
