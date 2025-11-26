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

local HumanoidESP = {}
HumanoidESP.__index = HumanoidESP

function HumanoidESP.new(name)
    local self = setmetatable({}, HumanoidESP)

    self.Name = name or "Mob"
    self.Highlight = false
    self.HighlightTransparency = 0
    self.HighlightOutlineTransparency = 0
    self.fontSize = 14
    self.Color = Color3.new(1, 1, 1)
    self.Enable = false
    self.espDistance = 1000
    self.ShowDistance = true
    self.ShowHealth = true

    self.ActiveObjects = {}

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


    local espText = NewText(self.Color, self.fontSize)

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

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        humanoid = humanoid,
        rootPart = rootPart,
        modelName = model.Name
    }

    local function UpdateESP()
        if not self.Enable or not model or not model.Parent then
            self:Remove(model)
            return
        end

        local player = Players.LocalPlayer
        local char = player.Character
        if not char then 
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
            return 
        end

        local playerRoot = char:FindFirstChild("HumanoidRootPart")
        if not playerRoot then 
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
            return 
        end

        local distance = (rootPart.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

        if distance <= self.espDistance and onScreen then
            local displayName = model:GetAttribute("CharacterName") or model.Name

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
                highlight.Enabled = self.Highlight
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    local renderName = "MobESP_" .. tostring(model):gsub("%W", "_")

    self.ActiveObjects[model].renderName = renderName

    if self.Enable then
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

function HumanoidESP:Remove(obj)
    if self.ActiveObjects[obj] then
        local data = self.ActiveObjects[obj]

        if data.espText then
            data.espText:Remove()
        end

        if data.highlight then
            data.highlight:Destroy()
        end

        if data.renderName then
            RunService:UnbindFromRenderStep(data.renderName)
        end

        self.ActiveObjects[obj] = nil
    end
end

function HumanoidESP:ClearAll()
    for obj, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText:Remove()
        end
        if data.highlight then
            data.highlight:Destroy()
        end
        if data.renderName then
            RunService:UnbindFromRenderStep(data.renderName)
        end
    end
    self.ActiveObjects = {}
end

function HumanoidESP:SetEnabled(state)
    self.Enable = state

    for model, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Visible = state
        end
        if data.highlight then
            data.highlight.Enabled = self.Highlight and state
        end

        if state and data.renderName then

            local renderName = data.renderName
            local modelRef = model
            local rootPart = data.rootPart
            local humanoid = data.humanoid
            local espText = data.espText
            local highlight = data.highlight

            local function UpdateESP()
                if not self.Enable or not modelRef or not modelRef.Parent then
                    self:Remove(modelRef)
                    return
                end

                local player = Players.LocalPlayer
                local char = player.Character
                if not char then 
                    espText.Visible = false
                    if highlight then highlight.Enabled = false end
                    return 
                end

                local playerRoot = char:FindFirstChild("HumanoidRootPart")
                if not playerRoot then 
                    espText.Visible = false
                    if highlight then highlight.Enabled = false end
                    return 
                end

                local distance = (rootPart.Position - playerRoot.Position).Magnitude
                local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

                if distance <= self.espDistance and onScreen then
                    local displayName = modelRef:GetAttribute("CharacterName") or modelRef.Name

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
                        highlight.Enabled = self.Highlight
                    end
                else
                    espText.Visible = false
                    if highlight then
                        highlight.Enabled = false
                    end
                end
            end

            RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)
        elseif not state and data.renderName then
            RunService:UnbindFromRenderStep(data.renderName)
        end
    end
end

function HumanoidESP:SetColor(color)
    self.Color = color
    for _, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Color = color
        end
        if data.highlight then
            data.highlight.FillColor = color
            data.highlight.OutlineColor = color
        end
    end
end

function HumanoidESP:SetFontSize(size)
    self.fontSize = size
    for _, data in pairs(self.ActiveObjects) do
        if data.espText then
            data.espText.Size = size
        end
    end
end

function HumanoidESP:SetHighlight(enabled)
    self.Highlight = enabled
    for _, data in pairs(self.ActiveObjects) do
        if data.highlight then
            data.highlight.Enabled = enabled and self.Enable
        end
    end
end

function ESPHelper.CreateHumanoidESP(name)
    return HumanoidESP.new(name)
end

return ESPHelper
