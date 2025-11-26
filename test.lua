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
    self.Highlight = false
    self.HighlightTransparency = 0
    self.HighlightOutlineTransparency = 0
    self.fontSize = 14
    self.Color = Color3.new(1, 1, 1)
    self.Enable = false
    self.espDistance = 1000
    self.ShowDistance = true

    self.ActiveObjects = {}
    self.RenderConnections = {} 

    return self
end

function BaseESP:UpdateAllTexts()
    for _, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Size = self.fontSize
            data.espText.Color = self.Color
        end
    end
end

function BaseESP:UpdateAllHighlights()
    for _, data in pairs(self.ActiveObjects) do
        if data.highlight then
            data.highlight.FillColor = self.Color
            data.highlight.OutlineColor = self.Color
            data.highlight.FillTransparency = self.HighlightTransparency
            data.highlight.OutlineTransparency = self.HighlightOutlineTransparency
            data.highlight.Enabled = self.Highlight and self.Enable
        end
    end
end

function BaseESP:StartAllRenderLoops()
    for obj, data in pairs(self.ActiveObjects) do
        if data.updateFunction and not self.RenderConnections[data.renderName] then
            self.RenderConnections[data.renderName] = true
            RunService:BindToRenderStep(data.renderName, Enum.RenderPriority.Camera.Value + 1, data.updateFunction)
        end
    end
end

function BaseESP:StopAllRenderLoops()
    for name in pairs(self.RenderConnections) do
        RunService:UnbindFromRenderStep(name)
    end
    self.RenderConnections = {}
end

function BaseESP:UpdateEnableState()
    if self.Enable then
        self:StartAllRenderLoops()
        for _, data in pairs(self.ActiveObjects) do
            if data.espText then
                data.espText.Visible = true
            end
            if data.highlight then
                data.highlight.Enabled = self.Highlight
            end
        end
    else
        self:StopAllRenderLoops()
        for _, data in pairs(self.ActiveObjects) do
            if data.espText then
                data.espText.Visible = false
            end
            if data.highlight then
                data.highlight.Enabled = false
            end
        end
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

        if data.renderName and self.RenderConnections[data.renderName] then
            RunService:UnbindFromRenderStep(data.renderName)
            self.RenderConnections[data.renderName] = nil
        end

        self.ActiveObjects[obj] = nil
    end
end

function BaseESP:ClearAll()
    for obj, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText:Remove()
        end
        if data.highlight then
            data.highlight:Destroy()
        end
    end
    self:StopAllRenderLoops()
    self.ActiveObjects = {}
end

function BaseESP:SetHighlight(value)
    self.Highlight = value
    self:UpdateAllHighlights()
end

function BaseESP:SetHighlightTransparency(value)
    self.HighlightTransparency = value
    self:UpdateAllHighlights()
end

function BaseESP:SetHighlightOutlineTransparency(value)
    self.HighlightOutlineTransparency = value
    self:UpdateAllHighlights()
end

function BaseESP:SetFontSize(value)
    self.fontSize = value
    self:UpdateAllTexts()
end

function BaseESP:SetColor(value)
    self.Color = value
    self:UpdateAllTexts()
    self:UpdateAllHighlights()
end

function BaseESP:SetEnable(value)
    self.Enable = value
    self:UpdateEnableState()
end

function BaseESP:SetEspDistance(value)
    self.espDistance = value
end

function BaseESP:SetShowDistance(value)
    self.ShowDistance = value
end

local HumanoidESP = setmetatable({}, {__index = BaseESP})
HumanoidESP.__index = HumanoidESP

function HumanoidESP.new()
    local self = setmetatable(BaseESP.new("Humanoid"), HumanoidESP)
    self.ShowHealth = true
    return self
end

function HumanoidESP:SetShowHealth(value)
    self.ShowHealth = value
end

function HumanoidESP:CreateUpdateFunction(model, data)
    return function()
        if not self.Enable or not model or not model.Parent then
            self:Remove(model)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then 
            data.espText.Visible = false
            if data.highlight then data.highlight.Enabled = false end
            return 
        end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then 
            data.espText.Visible = false
            if data.highlight then data.highlight.Enabled = false end
            return 
        end

        local distance = (data.rootPart.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(data.rootPart.Position)

        if distance <= self.espDistance and onScreen then
            local displayName = model:GetAttribute("CharacterName") or model.Name

            local text = displayName
            if self.ShowDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end
            if self.ShowHealth and data.humanoid and data.humanoid.MaxHealth > 0 then
                local healthPercent = math.floor((data.humanoid.Health / data.humanoid.MaxHealth) * 100)
                text = text .. string.format(" [HP: %d%%]", healthPercent)
            end

            data.espText.Text = text
            data.espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            data.espText.Visible = true

            if data.highlight then
                data.highlight.Enabled = self.Highlight
            end
        else
            data.espText.Visible = false
            if data.highlight then
                data.highlight.Enabled = false
            end
        end
    end
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

    local espText = NewText(self.Color, self.fontSize)
    espText.Visible = self.Enable

    local highlight = nil
    if self.Highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.FillColor = self.Color
        highlight.OutlineColor = self.Color
        highlight.FillTransparency = self.HighlightTransparency
        highlight.OutlineTransparency = self.HighlightOutlineTransparency
        highlight.Enabled = self.Highlight and self.Enable
    end

    local renderName = "HumanoidESP_" .. tostring(model):gsub("%W", "_")

    local data = {
        espText = espText,
        highlight = highlight,
        humanoid = humanoid,
        rootPart = rootPart,
        modelName = model.Name,
        renderName = renderName
    }

    data.updateFunction = self:CreateUpdateFunction(model, data)

    self.ActiveObjects[model] = data

    if self.Enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, data.updateFunction)
    end

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

function PartESP.new()
    local self = setmetatable(BaseESP.new("Part"), PartESP)
    return self
end

function PartESP:CreateUpdateFunction(part, data)
    return function()
        if not self.Enable or not part or not part.Parent then
            self:Remove(part)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then 
            data.espText.Visible = false
            if data.highlight then data.highlight.Enabled = false end
            return 
        end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then 
            data.espText.Visible = false
            if data.highlight then data.highlight.Enabled = false end
            return 
        end

        local distance = (part.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)

        if distance <= self.espDistance and onScreen then
            local displayName = part.Name

            local text = displayName
            if self.ShowDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            data.espText.Text = text
            data.espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            data.espText.Visible = true

            if data.highlight then
                data.highlight.Enabled = self.Highlight
            end
        else
            data.espText.Visible = false
            if data.highlight then
                data.highlight.Enabled = false
            end
        end
    end
end

function PartESP:Set(part)
    if not part or not part:IsA("BasePart") or self.ActiveObjects[part] then
        return false
    end

    local espText = NewText(self.Color, self.fontSize)
    espText.Visible = self.Enable

    local highlight = nil
    if self.Highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = part
        highlight.FillColor = self.Color
        highlight.OutlineColor = self.Color
        highlight.FillTransparency = self.HighlightTransparency
        highlight.OutlineTransparency = self.HighlightOutlineTransparency
        highlight.Enabled = self.Highlight and self.Enable
    end

    local renderName = "PartESP_" .. tostring(part):gsub("%W", "_")

    local data = {
        espText = espText,
        highlight = highlight,
        part = part,
        renderName = renderName
    }

    data.updateFunction = self:CreateUpdateFunction(part, data)

    self.ActiveObjects[part] = data

    if self.Enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, data.updateFunction)
    end

    part.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:Remove(part)
        end
    end)

    return true
end

local PivotESP = setmetatable({}, {__index = BaseESP})
PivotESP.__index = PivotESP

function PivotESP.new()
    local self = setmetatable(BaseESP.new("Pivot"), PivotESP)
    return self
end

function PivotESP:CreateUpdateFunction(model, data)
    return function()
        if not self.Enable or not model or not model.Parent then
            self:Remove(model)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then 
            data.espText.Visible = false
            if data.highlight then data.highlight.Enabled = false end
            return 
        end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then 
            data.espText.Visible = false
            if data.highlight then data.highlight.Enabled = false end
            return 
        end

        local pivot = model:GetPivot()
        local distance = (pivot.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(pivot.Position)

        if distance <= self.espDistance and onScreen then
            local displayName = model.Name

            local text = displayName
            if self.ShowDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            data.espText.Text = text
            data.espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            data.espText.Visible = true

            if data.highlight then
                data.highlight.Enabled = self.Highlight
            end
        else
            data.espText.Visible = false
            if data.highlight then
                data.highlight.Enabled = false
            end
        end
    end
end

function PivotESP:Set(model)
    if not model or not model:IsA("Model") or self.ActiveObjects[model] then
        return false
    end

    local espText = NewText(self.Color, self.fontSize)
    espText.Visible = self.Enable

    local highlight = nil
    if self.Highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.FillColor = self.Color
        highlight.OutlineColor = self.Color
        highlight.FillTransparency = self.HighlightTransparency
        highlight.OutlineTransparency = self.HighlightOutlineTransparency
        highlight.Enabled = self.Highlight and self.Enable
    end

    local renderName = "PivotESP_" .. tostring(model):gsub("%W", "_")

    local data = {
        espText = espText,
        highlight = highlight,
        model = model,
        renderName = renderName
    }

    data.updateFunction = self:CreateUpdateFunction(model, data)

    self.ActiveObjects[model] = data

    if self.Enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, data.updateFunction)
    end

    model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:Remove(model)
        end
    end)

    return true
end

function ESPHelper.CreateHumanoidESP()
    return HumanoidESP.new()
end

function ESPHelper.CreatePartESP()
    return PartESP.new()
end

function ESPHelper.CreatePivotESP()
    return PivotESP.new()
end

return ESPHelper
