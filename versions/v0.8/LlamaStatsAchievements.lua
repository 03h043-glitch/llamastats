local GOLD = "|cffffd700"
local SILVER = "|cffc7c7cf"
local COPPER = "|cffeda55f"
local YELLOW = "|cffffcc00"
local GREEN = "|cff1eff00"
local GRAY = "|cff888888"
local WHITE = "|cffffffff"
local RESET = "|r"

local BUTTON_WIDTH = 104
local BUTTON_HEIGHT = 20
local RETRY_INTERVAL = 0.1
local RETRY_LIMIT = 50

local goldMilestones = { 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000 }
local itemMilestones = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
local qualityMilestones = { 1, 5, 10, 25, 50, 100, 250 }
local damageMilestones = { 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000 }
local mobTypeMilestones = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
local limitedQuestLevels = { 5, 10, 20, 30, 40, 50, 60 }

local achievementFrame
local achievementContent
local retryFrame
local rows = {}

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "LlamaStats:" .. RESET .. " " .. tostring(msg))
    end
end

local function CurrentTime()
    if time then
        return time()
    end

    return math.floor(GetTime() or 0)
end

local function FormatNumber(n)
    n = tonumber(n) or 0

    if n >= 1000000 then
        return string.format("%.2fm", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fk", n / 1000)
    end

    return tostring(math.floor(n))
end

local function PlainMoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    if g > 0 then return g .. "g " .. s .. "s " .. c .. "c" end
    if s > 0 then return s .. "s " .. c .. "c" end
    return c .. "c"
end

local function EnsureAchievementDB()
    LlamaStatsDB = LlamaStatsDB or {}
    LlamaStatsDB.lifetime = LlamaStatsDB.lifetime or {}
    LlamaStatsDB.lifetime.mobTypes = LlamaStatsDB.lifetime.mobTypes or {}
    LlamaStatsDB.milestones = LlamaStatsDB.milestones or {}
    LlamaStatsDB.milestones.lifetime = LlamaStatsDB.milestones.lifetime or {}
    LlamaStatsDB.achievements = LlamaStatsDB.achievements or {}
    LlamaStatsDB.achievements.unlocked = LlamaStatsDB.achievements.unlocked or {}
end

local function IsMilestoneReached(key, threshold)
    EnsureAchievementDB()
    local group = LlamaStatsDB.milestones.lifetime[key]
    return group and group[threshold] == true
end

local function AchievementUnlocked(id)
    EnsureAchievementDB()
    return LlamaStatsDB.achievements.unlocked[id] ~= nil
end

local function UnlockAchievement(id, title)
    EnsureAchievementDB()

    if AchievementUnlocked(id) then
        return false
    end

    LlamaStatsDB.achievements.unlocked[id] = {
        title = title,
        completedAt = CurrentTime(),
    }

    Print("Achievement unlocked: " .. title)
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage("LlamaStats achievement: " .. title, 1, 0.82, 0, 1)
    end

    return true
end

local function AddDefinition(list, category, id, title, description, unlocked)
    table.insert(list, {
        category = category,
        id = id,
        title = title,
        description = description,
        unlocked = unlocked == true,
    })

    if unlocked then
        UnlockAchievement(id, title)
    end
end

local function AddMilestoneDefinitions(list, category, key, thresholds, label, formatter)
    for _, threshold in ipairs(thresholds) do
        local valueText = formatter and formatter(threshold) or FormatNumber(threshold)
        local id = "lifetime:" .. key .. ":" .. threshold
        local title = label .. " - " .. valueText
        AddDefinition(list, category, id, title, "Reach lifetime " .. string.lower(label) .. " of " .. valueText .. ".", IsMilestoneReached(key, threshold))
    end
end

local function AddMobTypeDefinitions(list)
    local knownTypes = {}

    for creatureType in pairs(LlamaStatsDB.lifetime.mobTypes or {}) do
        table.insert(knownTypes, creatureType)
    end

    for milestoneKey in pairs(LlamaStatsDB.milestones.lifetime or {}) do
        local creatureType = string.match(milestoneKey, "^mobType:(.+)$")
        if creatureType then
            local exists = false
            for _, knownType in ipairs(knownTypes) do
                if knownType == creatureType then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(knownTypes, creatureType)
            end
        end
    end

    table.sort(knownTypes)

    if #knownTypes == 0 then
        AddDefinition(list, "Mob Types", "mobtypes:none", "No mob type achievements yet", "Kill tracked creature types to reveal these achievements.", false)
        return
    end

    for _, creatureType in ipairs(knownTypes) do
        local milestoneKey = "mobType:" .. creatureType
        for _, threshold in ipairs(mobTypeMilestones) do
            local id = "lifetime:" .. milestoneKey .. ":" .. threshold
            local title = creatureType .. " kills - " .. FormatNumber(threshold)
            AddDefinition(list, "Mob Types", id, title, "Reach " .. FormatNumber(threshold) .. " lifetime " .. creatureType .. " kills.", IsMilestoneReached(milestoneKey, threshold))
        end
    end
end

local function CheckLimitedQuestAchievements(level)
    EnsureAchievementDB()
    level = tonumber(level) or (UnitLevel and UnitLevel("player")) or 0
    local questsCompleted = tonumber(LlamaStatsDB.lifetime.questsCompleted) or 0

    for _, requiredLevel in ipairs(limitedQuestLevels) do
        if level >= requiredLevel and questsCompleted < requiredLevel then
            local id = "limitedQuests:" .. requiredLevel
            UnlockAchievement(id, "Level " .. requiredLevel .. " with under " .. requiredLevel .. " quests")
        end
    end
end

local function BuildAchievementDefinitions()
    EnsureAchievementDB()
    CheckLimitedQuestAchievements()

    local list = {}
    AddMilestoneDefinitions(list, "Currency", "moneyLooted", goldMilestones, "Looted coin", PlainMoneyText)
    AddMilestoneDefinitions(list, "Loot", "itemsLooted", itemMilestones, "Items looted")
    AddMilestoneDefinitions(list, "Loot", "greenItems", qualityMilestones, "Green items")
    AddMilestoneDefinitions(list, "Loot", "blueItems", qualityMilestones, "Blue items")
    AddMilestoneDefinitions(list, "Loot", "purpleItems", qualityMilestones, "Purple items")
    AddMilestoneDefinitions(list, "Combat", "damageDealt", damageMilestones, "Damage dealt", FormatNumber)
    AddMobTypeDefinitions(list)

    for _, requiredLevel in ipairs(limitedQuestLevels) do
        local id = "limitedQuests:" .. requiredLevel
        AddDefinition(
            list,
            "Limited Questing",
            id,
            "Level " .. requiredLevel .. " with under " .. requiredLevel .. " quests",
            "Reach level " .. requiredLevel .. " while lifetime quests completed is less than " .. requiredLevel .. ".",
            AchievementUnlocked(id)
        )
    end

    table.sort(list, function(a, b)
        if a.category == b.category then
            if a.unlocked ~= b.unlocked then
                return a.unlocked and not b.unlocked
            end
            return a.title < b.title
        end
        return a.category < b.category
    end)

    return list
end

local function ClearRows()
    for _, row in ipairs(rows) do
        row:Hide()
        row:SetParent(nil)
    end
    rows = {}
end

local function CreateBorder(parent)
    local r, g, b, a = 0.75, 0.6, 0.25, 1

    local top = parent:CreateTexture(nil, "BORDER")
    top:SetColorTexture(r, g, b, a)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    top:SetHeight(1)

    local bottom = parent:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(r, g, b, a)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)

    local left = parent:CreateTexture(nil, "BORDER")
    left:SetColorTexture(r, g, b, a)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)

    local right = parent:CreateTexture(nil, "BORDER")
    right:SetColorTexture(r, g, b, a)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
end

local function CreateAchievementWindow()
    if achievementFrame then
        return
    end

    achievementFrame = CreateFrame("Frame", "LlamaStatsAchievementsFrame", UIParent)
    achievementFrame:SetSize(460, 520)
    achievementFrame:SetPoint("CENTER")
    achievementFrame:SetFrameStrata("DIALOG")
    achievementFrame:SetMovable(true)
    achievementFrame:EnableMouse(true)
    achievementFrame:RegisterForDrag("LeftButton")
    achievementFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    achievementFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    achievementFrame.bg = achievementFrame:CreateTexture(nil, "BACKGROUND")
    achievementFrame.bg:SetAllPoints(achievementFrame)
    achievementFrame.bg:SetColorTexture(0, 0, 0, 0.9)
    CreateBorder(achievementFrame)

    local title = achievementFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(YELLOW .. "LlamaStats Achievements" .. RESET)

    local close = CreateFrame("Button", nil, achievementFrame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    close:SetScript("OnClick", function() achievementFrame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "LlamaStatsAchievementsScrollFrame", achievementFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -38)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)

    achievementContent = CreateFrame("Frame", nil, scroll)
    achievementContent:SetSize(400, 1)
    scroll:SetScrollChild(achievementContent)

    achievementFrame:Hide()
end

local function AddHeader(text, y)
    local header = achievementContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 4, y)
    header:SetText(YELLOW .. text .. RESET)
    table.insert(rows, header)
    return y - 24
end

local function AddAchievementRow(achievement, y)
    local title = achievementContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 12, y)
    title:SetWidth(365)
    title:SetJustifyH("LEFT")
    title:SetText((achievement.unlocked and GREEN or GRAY) .. (achievement.unlocked and "[Done] " or "[Locked] ") .. achievement.title .. RESET)
    table.insert(rows, title)

    local desc = achievementContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", 26, y - 15)
    desc:SetWidth(365)
    desc:SetJustifyH("LEFT")
    desc:SetText(achievement.description)
    table.insert(rows, desc)

    return y - 42
end

local function RefreshAchievementWindow()
    CreateAchievementWindow()
    ClearRows()

    local definitions = BuildAchievementDefinitions()
    local unlocked = 0
    for _, achievement in ipairs(definitions) do
        if achievement.unlocked then
            unlocked = unlocked + 1
        end
    end

    local summary = achievementContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", 4, -2)
    summary:SetText(WHITE .. "Unlocked: " .. unlocked .. " / " .. #definitions .. RESET)
    table.insert(rows, summary)

    local y = -30
    local currentCategory
    for _, achievement in ipairs(definitions) do
        if achievement.category ~= currentCategory then
            currentCategory = achievement.category
            y = AddHeader(currentCategory, y)
        end
        y = AddAchievementRow(achievement, y)
    end

    achievementContent:SetHeight(math.max(1, math.abs(y) + 20))
end

local function ToggleAchievementWindow()
    RefreshAchievementWindow()

    if achievementFrame:IsShown() then
        achievementFrame:Hide()
    else
        achievementFrame:Show()
    end
end

local function AddAchievementButton()
    local frame = _G.LlamaStatsFrame
    if not frame or frame.llamaStatsAchievementsButton then
        return false
    end

    local button = CreateFrame("Button", "LlamaStatsAchievementsButton", frame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
    button:SetText("Achieve")
    button:SetScript("OnClick", ToggleAchievementWindow)

    frame.llamaStatsAchievementsButton = button
    return true
end

local function StartRetry()
    retryFrame.retries = 0
    retryFrame.elapsed = 0
    retryFrame:Show()
end

retryFrame = CreateFrame("Frame")
retryFrame.retries = 0
retryFrame.elapsed = 0
retryFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + (elapsed or 0)
    if self.elapsed < RETRY_INTERVAL then
        return
    end

    self.elapsed = 0
    self.retries = self.retries + 1

    if AddAchievementButton() or self.retries >= RETRY_LIMIT then
        self:Hide()
    end
end)
retryFrame:Hide()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        CheckLimitedQuestAchievements(newLevel)
        if achievementFrame and achievementFrame:IsShown() then
            RefreshAchievementWindow()
        end
        return
    end

    EnsureAchievementDB()
    CheckLimitedQuestAchievements()
    if not AddAchievementButton() then
        StartRetry()
    end
end)
