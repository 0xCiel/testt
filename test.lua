local ESPHelper = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

local BaseESP = {}
BaseESP.__index = BaseESP

function BaseESP.new(espType)
    local self = setmetatable({}, BaseESP)

    self.espType = espType or "Base"
    self.Name = espType or "ESP"
    self.Highlight = false
    self.HighlightTransparency = 0
    self.HighlightOutlineTransparency = 0
    self.fontSize = 14
    self.Color = Color3.new(1, 1, 1)
    self.Enable = false
    self.espDistance = 1000
    self.ShowDistance = true
    self.ShowHealth = false

    self.ActiveObjects = {}
    self.ESPObjects = {}
    self.RenderConnections = {}

    return self
end

function BaseESP:UpdateProperties()
    for obj, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Size = self.fontSize
            data.espText.Color = self.Color
        end

        if data.highlight then
            data.highlight.FillColor = self.Color
            data.highlight.OutlineColor = self.Color
            data.highlight.FillTransparency = self.HighlightTransparency
            data.highlight.OutlineTransparency = self.HighlightOutlineTransparency
            data.highlight.Enabled = self.Highlight and self.Enable
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
    self.ESPObjects = {}
end

function BaseESP:SetEnabled(state)
    self.Enable = state
    self:UpdateProperties()

    if not state then

        for name in pairs(self.RenderConnections) do
            RunService:UnbindFromRenderStep(name)
        end
        self.RenderConnections = {}
    end
end

local HumanoidESP = setmetatable({}, {__index = BaseESP})
HumanoidESP.__index = HumanoidESP

function HumanoidESP.new(name)
    local self = setmetatable(BaseESP.new("Humanoid"), HumanoidESP)
    self.Name = name or "Humanoid"
    self.ShowHealth = true
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

    local espText = Drawing.new("Text")
    espText.Visible = false
    espText.Size = self.fontSize
    espText.Color = self.Color
    espText.Center = true
    espText.Outline = true

    local highlight = nil
    if self.Highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.FillColor = self.Color
        highlight.OutlineColor = self.Color
        highlight.FillTransparency = self.HighlightTransparency
        highlight.OutlineTransparency = self.HighlightOutlineTransparency
        highlight.Enabled = self.Enable
    end

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        humanoid = humanoid,
        rootPart = rootPart
    }

    local renderName = "UpdateESP_" .. self.espType .. "_" .. tostring(model):gsub("%W", "_")

    local function UpdateESP()
        if not self.Enable or not model or not model.Parent then
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

        if distance <= self.espDistance and onScreen then
            local displayName = model:GetAttribute("CharacterName") or self.Name or model.Name

            local text = displayName
            if self.ShowDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end
            if self.ShowHealth and humanoid and humanoid.MaxHealth > 0 then
                local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
                text = text .. string.format(" [HP: %d%%]", healthPercent)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = true
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    if self.Enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)
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

function PartESP.new(name)
    local self = setmetatable(BaseESP.new("Part"), PartESP)
    self.Name = name or "Part"
    return self
end

function PartESP:Set(part)
    if not part or not part:IsA("BasePart") or self.ActiveObjects[part] then
        return false
    end

    local espText = Drawing.new("Text")
    espText.Visible = false
    espText.Size = self.fontSize
    espText.Color = self.Color
    espText.Center = true
    espText.Outline = true

    local highlight = nil
    if self.Highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = part
        highlight.FillColor = self.Color
        highlight.OutlineColor = self.Color
        highlight.FillTransparency = self.HighlightTransparency
        highlight.OutlineTransparency = self.HighlightOutlineTransparency
        highlight.Enabled = self.Enable
    end

    self.ActiveObjects[part] = {
        espText = espText,
        highlight = highlight,
        part = part
    }

    local renderName = "UpdateESP_" .. self.espType .. "_" .. tostring(part):gsub("%W", "_")

    local function UpdateESP()
        if not self.Enable or not part or not part.Parent then
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

        if distance <= self.espDistance and onScreen then
            local displayName = self.Name or part.Name

            local text = displayName
            if self.ShowDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = true
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    if self.Enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)
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

function PivotESP.new(name)
    local self = setmetatable(BaseESP.new("Pivot"), PivotESP)
    self.Name = name or "Pivot"
    return self
end

function PivotESP:Set(model)
    if not model or not model:IsA("Model") or self.ActiveObjects[model] then
        return false
    end

    local pivot = model:GetPivot()

    local espText = Drawing.new("Text")
    espText.Visible = false
    espText.Size = self.fontSize
    espText.Color = self.Color
    espText.Center = true
    espText.Outline = true

    local highlight = nil
    if self.Highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.FillColor = self.Color
        highlight.OutlineColor = self.Color
        highlight.FillTransparency = self.HighlightTransparency
        highlight.OutlineTransparency = self.HighlightOutlineTransparency
        highlight.Enabled = self.Enable
    end

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        model = model
    }

    local renderName = "UpdateESP_" .. self.espType .. "_" .. tostring(model):gsub("%W", "_")

    local function UpdateESP()
        if not self.Enable or not model or not model.Parent then
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

        if distance <= self.espDistance and onScreen then
            local displayName = self.Name or model.Name

            local text = displayName
            if self.ShowDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = true
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    if self.Enable then
        self.RenderConnections[renderName] = true
        RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)
    end

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
