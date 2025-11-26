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

local function CreateBaseESP(espType)
    local BaseESP = {}
    BaseESP.__index = BaseESP

    function BaseESP.new()
        local self = setmetatable({}, BaseESP)

        self.espType = espType or "Base"
        self._highlight = false
        self._highlightTransparency = 0
        self._highlightOutlineTransparency = 0
        self._fontSize = 14
        self._color = Color3.new(1, 1, 1)
        self._enable = false
        self._espDistance = 1000
        self._showDistance = true

        self.ActiveObjects = {}

        return self
    end

    function BaseESP:__index(key)
        if key == "Highlight" then return self._highlight
        elseif key == "HighlightTransparency" then return self._highlightTransparency
        elseif key == "HighlightOutlineTransparency" then return self._highlightOutlineTransparency
        elseif key == "fontSize" then return self._fontSize
        elseif key == "Color" then return self._color
        elseif key == "Enable" then return self._enable
        elseif key == "espDistance" then return self._espDistance
        elseif key == "ShowDistance" then return self._showDistance
        else return BaseESP[key]
        end
    end

    function BaseESP:__newindex(key, value)
        if key == "Highlight" then
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
        else
            rawset(self, key, value)
        end
    end

    function BaseESP:_updateAllTexts()
        for _, data in pairs(self.ActiveObjects) do
            if data.espText then
                data.espText.Size = self._fontSize
                data.espText.Color = self._color
            end
        end
    end

    function BaseESP:_updateAllHighlights()
        for _, data in pairs(self.ActiveObjects) do
            if data.highlight then
                data.highlight.FillColor = self._color
                data.highlight.OutlineColor = self._color
                data.highlight.FillTransparency = self._highlightTransparency
                data.highlight.OutlineTransparency = self._highlightOutlineTransparency
                data.highlight.Enabled = self._highlight and self._enable
            end
        end
    end

    function BaseESP:_updateEnableState()
        for _, data in pairs(self.ActiveObjects) do
            if data.espText then
                data.espText.Visible = self._enable
            end
            if data.highlight then
                data.highlight.Enabled = self._highlight and self._enable
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

            if data.renderName then
                RunService:UnbindFromRenderStep(data.renderName)
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
            if data.renderName then
                RunService:UnbindFromRenderStep(data.renderName)
            end
        end
        self.ActiveObjects = {}
    end

    return BaseESP
end

local HumanoidESP = setmetatable({}, {__index = CreateBaseESP("Humanoid")})
HumanoidESP.__index = HumanoidESP

function HumanoidESP.new()
    local self = setmetatable(CreateBaseESP("Humanoid").new(), HumanoidESP)
    self._showHealth = true
    return self
end

function HumanoidESP:__index(key)
    if key == "ShowHealth" then return self._showHealth
    else return getmetatable(HumanoidESP).__index[key] or HumanoidESP[key]
    end
end

function HumanoidESP:__newindex(key, value)
    if key == "ShowHealth" then
        self._showHealth = value
    else
        getmetatable(HumanoidESP).__newindex(self, key, value)
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

    local espText = NewText(self._color, self._fontSize)
    espText.Visible = self._enable

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

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        humanoid = humanoid,
        rootPart = rootPart,
        modelName = model.Name
    }

    local function UpdateESP()
        if not self._enable or not model or not model.Parent then
            self:Remove(model)
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

        if distance <= self._espDistance and onScreen then
            local displayName = model:GetAttribute("CharacterName") or model.Name

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
                highlight.Enabled = self._highlight
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    local renderName = "HumanoidESP_" .. tostring(model):gsub("%W", "_")
    self.ActiveObjects[model].renderName = renderName
    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)

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

local PartESP = setmetatable({}, {__index = CreateBaseESP("Part")})
PartESP.__index = PartESP

function PartESP.new()
    local self = setmetatable(CreateBaseESP("Part").new(), PartESP)
    return self
end

function PartESP:Set(part)
    if not part or not part:IsA("BasePart") or self.ActiveObjects[part] then
        return false
    end

    local espText = NewText(self._color, self._fontSize)
    espText.Visible = self._enable

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

    self.ActiveObjects[part] = {
        espText = espText,
        highlight = highlight,
        part = part
    }

    local function UpdateESP()
        if not self._enable or not part or not part.Parent then
            self:Remove(part)
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

        local distance = (part.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)

        if distance <= self._espDistance and onScreen then
            local displayName = part.Name

            local text = displayName
            if self._showDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = self._highlight
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    local renderName = "PartESP_" .. tostring(part):gsub("%W", "_")
    self.ActiveObjects[part].renderName = renderName
    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)

    part.AncestryChanged:Connect(function(_, parent)
        if not parent then
            self:Remove(part)
        end
    end)

    return true
end

local PivotESP = setmetatable({}, {__index = CreateBaseESP("Pivot")})
PivotESP.__index = PivotESP

function PivotESP.new()
    local self = setmetatable(CreateBaseESP("Pivot").new(), PivotESP)
    return self
end

function PivotESP:Set(model)
    if not model or not model:IsA("Model") or self.ActiveObjects[model] then
        return false
    end

    local espText = NewText(self._color, self._fontSize)
    espText.Visible = self._enable

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

    self.ActiveObjects[model] = {
        espText = espText,
        highlight = highlight,
        model = model
    }

    local function UpdateESP()
        if not self._enable or not model or not model.Parent then
            self:Remove(model)
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

        local pivot = model:GetPivot()
        local distance = (pivot.Position - playerRoot.Position).Magnitude
        local screenPos, onScreen = Camera:WorldToViewportPoint(pivot.Position)

        if distance <= self._espDistance and onScreen then
            local displayName = model.Name

            local text = displayName
            if self._showDistance then
                text = text .. string.format(" [%.1fm]", distance)
            end

            espText.Text = text
            espText.Position = Vector2.new(screenPos.X, screenPos.Y)
            espText.Visible = true

            if highlight then
                highlight.Enabled = self._highlight
            end
        else
            espText.Visible = false
            if highlight then
                highlight.Enabled = false
            end
        end
    end

    local renderName = "PivotESP_" .. tostring(model):gsub("%W", "_")
    self.ActiveObjects[model].renderName = renderName
    RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, UpdateESP)

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
