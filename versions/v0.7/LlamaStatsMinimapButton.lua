local MINIMAP_BUTTON_RADIUS = 78
local RETRY_INTERVAL = 0.1
local RETRY_LIMIT = 50

local function EnsureMinimapDB()
    LlamaStatsDB = LlamaStatsDB or {}
    LlamaStatsDB.minimap = LlamaStatsDB.minimap or {}
    LlamaStatsDB.minimap.angle = LlamaStatsDB.minimap.angle or 220
end

local function GetMinimapButton()
    return _G.LlamaStatsMinimapButton
end

local function PositionMinimapButton(button)
    EnsureMinimapDB()
    button = button or GetMinimapButton()
    if not button or not Minimap then
        return
    end

    local angle = math.rad(LlamaStatsDB.minimap.angle or 220)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * MINIMAP_BUTTON_RADIUS, math.sin(angle) * MINIMAP_BUTTON_RADIUS)
end

local function FixMinimapButtonBorder(button)
    button = button or GetMinimapButton()
    if not button or not button.border then
        return
    end

    button.border:ClearAllPoints()
    button.border:SetPoint("CENTER", button, "CENTER", 10, -10)
end

local function GetCursorAngle()
    if not Minimap then
        return nil
    end

    local mapX, mapY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    if not mapX or not mapY or not cursorX or not cursorY or scale == 0 then
        return nil
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local deltaY = cursorY - mapY
    local deltaX = cursorX - mapX
    if math.atan2 then
        return math.atan2(deltaY, deltaX)
    end

    return math.atan(deltaY, deltaX)
end

local function UpdateMinimapButtonFromCursor(button)
    EnsureMinimapDB()
    local angle = GetCursorAngle()
    if not angle then
        return
    end

    LlamaStatsDB.minimap.angle = math.deg(angle)
    PositionMinimapButton(button)
end

local function AddDragTooltipLine(button)
    if not GameTooltip or not GameTooltip:IsOwned(button) then
        return
    end

    GameTooltip:AddLine("Drag: move button", 1, 1, 1)
    GameTooltip:Show()
end

local function MakeMinimapButtonMovable(button)
    if not button or button.llamaStatsMovableApplied then
        return
    end

    button.llamaStatsMovableApplied = true
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnDragStart", function(self)
        self.llamaStatsSuppressClick = true
        self:SetScript("OnUpdate", UpdateMinimapButtonFromCursor)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapButtonFromCursor(self)

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if self then
                    self.llamaStatsSuppressClick = nil
                end
            end)
        else
            self.llamaStatsSuppressClick = nil
        end
    end)

    local originalOnClick = button:GetScript("OnClick")
    button:SetScript("OnClick", function(self, buttonName, ...)
        if self.llamaStatsSuppressClick then
            return
        end

        if originalOnClick then
            originalOnClick(self, buttonName, ...)
        end
    end)

    local originalOnEnter = button:GetScript("OnEnter")
    button:SetScript("OnEnter", function(self, ...)
        if originalOnEnter then
            originalOnEnter(self, ...)
        end
        AddDragTooltipLine(self)
    end)
end

local function ApplyMinimapButtonAmendments()
    local button = GetMinimapButton()
    if not button then
        return false
    end

    FixMinimapButtonBorder(button)
    PositionMinimapButton(button)
    MakeMinimapButtonMovable(button)
    return true
end

local retryFrame = CreateFrame("Frame")
retryFrame.retries = 0
retryFrame.elapsed = 0

local function StartMinimapButtonRetry()
    retryFrame.retries = 0
    retryFrame.elapsed = 0
    retryFrame:Show()
end

retryFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < RETRY_INTERVAL then
        return
    end

    self.elapsed = 0
    self.retries = self.retries + 1

    if ApplyMinimapButtonAmendments() or self.retries >= RETRY_LIMIT then
        self:Hide()
    end
end)
retryFrame:Hide()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if not ApplyMinimapButtonAmendments() then
        StartMinimapButtonRetry()
    end
end)
