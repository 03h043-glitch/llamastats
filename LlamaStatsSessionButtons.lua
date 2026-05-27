local BUTTON_SPACE = 38
local BUTTON_WIDTH = 116
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 8

local adjustingHeight = false

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage('|cffffcc00LlamaStats:|r ' .. tostring(msg))
    end
end

local function CurrentTime()
    if time then
        return time()
    end

    return math.floor(GetTime() or 0)
end

local function ResetSessionData()
    LlamaStatsDB = LlamaStatsDB or {}
    LlamaStatsDB.session = {
        startedAt = CurrentTime(),
        questsCompleted = 0,
        mobsKilled = 0,
        moneyLooted = 0,
        moneyQuestRewards = 0,
        vendorValueLooted = 0,
        itemsLooted = 0,
        greenItems = 0,
        blueItems = 0,
        purpleItems = 0,
        damageDealt = 0,
        experienceGained = 0,
    }

    LlamaStatsDB.milestones = LlamaStatsDB.milestones or {}
    LlamaStatsDB.milestones.session = {}
end

local function ForceRefresh(frame)
    if not frame then return end

    local onUpdate = frame:GetScript('OnUpdate')
    if onUpdate then
        onUpdate(frame, 1)
    end
end

local function ResetThroughAddon()
    if SlashCmdList and SlashCmdList.LLAMASTATS then
        SlashCmdList.LLAMASTATS('reset session')
    else
        ResetSessionData()
        Print('Session stats reset.')
    end

    ForceRefresh(_G.LlamaStatsFrame)
end

local function StartNewSession(mode)
    ResetThroughAddon()

    if mode == 'end' then
        Print('Previous session ended. New session started.')
    end
end

local function ReserveButtonSpace(frame)
    if not hooksecurefunc or frame.llamaStatsSessionButtonsHeightHooked then return end

    frame.llamaStatsSessionButtonsHeightHooked = true
    hooksecurefunc(frame, 'SetHeight', function(self, height)
        if adjustingHeight or not self.llamaStatsSessionButtons then
            return
        end

        adjustingHeight = true
        self:SetHeight((tonumber(height) or self:GetHeight() or 0) + BUTTON_SPACE)
        adjustingHeight = false
    end)
end

local function ExpandForButtons(frame)
    adjustingHeight = true
    frame:SetHeight((frame:GetHeight() or 0) + BUTTON_SPACE)
    adjustingHeight = false
end

local function CreateSessionButton(parent, name, label, point, relativePoint, xOffset)
    local button = CreateFrame('Button', name, parent, 'UIPanelButtonTemplate')
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetPoint(point, parent, relativePoint, xOffset, 10)
    button:SetText(label)
    return button
end

local function AddSessionButtons()
    local frame = _G.LlamaStatsFrame
    if not frame or frame.llamaStatsSessionButtons then
        return false
    end

    local firstX = -((BUTTON_WIDTH + BUTTON_GAP) / 2)
    local secondX = (BUTTON_WIDTH + BUTTON_GAP) / 2

    local newSession = CreateSessionButton(frame, 'LlamaStatsNewSessionButton', 'New Session', 'BOTTOM', 'BOTTOM', firstX)
    newSession:SetScript('OnClick', function()
        StartNewSession('new')
    end)

    local endSession = CreateSessionButton(frame, 'LlamaStatsEndSessionButton', 'End Session', 'BOTTOM', 'BOTTOM', secondX)
    endSession:SetScript('OnClick', function()
        StartNewSession('end')
    end)

    frame.llamaStatsSessionButtons = {
        newSession = newSession,
        endSession = endSession,
    }

    ReserveButtonSpace(frame)
    ExpandForButtons(frame)
    return true
end

local function AddButtonsWhenReady()
    if AddSessionButtons() then return end

    local waiter = CreateFrame('Frame')
    local elapsed = 0
    waiter:SetScript('OnUpdate', function(self, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed < 0.1 then return end

        elapsed = 0
        if AddSessionButtons() then
            self:SetScript('OnUpdate', nil)
        end
    end)
end

local eventFrame = CreateFrame('Frame')
eventFrame:RegisterEvent('PLAYER_LOGIN')
eventFrame:SetScript('OnEvent', function()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, AddButtonsWhenReady)
    else
        AddButtonsWhenReady()
    end
end)
