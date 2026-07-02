local YELLOW = "|cffffcc00"
local GREEN = "|cff1eff00"
local GRAY = "|cff888888"
local WHITE = "|cffffffff"
local RESET = "|r"

local BUTTON_WIDTH = 104
local BUTTON_HEIGHT = 20
local RETRY_INTERVAL = 0.1
local RETRY_LIMIT = 50
local TOAST_HOLD_SECONDS = 1
local TOAST_FADE_SECONDS = 0.6
local MATERIAL_THRESHOLDS = { 50, 100, 200, 500, 1000 }
local MATERIAL_FAMILIES = { "Cloth", "Leather", "Ore", "Herb" }

local milestoneSets = {
    { category = "Currency", key = "moneyLooted", label = "Looted coin", thresholds = { 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000 }, money = true },
    { category = "Loot", key = "itemsLooted", label = "Items looted", thresholds = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 } },
    { category = "Loot", key = "greenItems", label = "Green items", thresholds = { 1, 5, 10, 25, 50, 100, 250 } },
    { category = "Loot", key = "blueItems", label = "Blue items", thresholds = { 1, 5, 10, 25, 50, 100, 250 } },
    { category = "Loot", key = "purpleItems", label = "Purple items", thresholds = { 1, 5, 10, 25, 50, 100, 250 } },
    { category = "Combat", key = "damageDealt", label = "Damage dealt", thresholds = { 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000 } },
}
local mobTypeMilestones = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
local limitedQuestLevels = { 5, 10, 20, 30, 40, 50, 60 }

local achievementFrame
local achievementContent
local achievementToast
local retryFrame
local rows = {}
local liveCheckQueued = false

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "LlamaStats:" .. RESET .. " " .. tostring(msg))
    end
end

local function CurrentTime()
    if time then return time() end
    return math.floor(GetTime() or 0)
end

local function FormatNumber(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format("%.2fm", n / 1000000) end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
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
    LlamaStatsDB.achievements.materialLoot = LlamaStatsDB.achievements.materialLoot or {}

    for _, family in ipairs(MATERIAL_FAMILIES) do
        LlamaStatsDB.achievements.materialLoot[family] = LlamaStatsDB.achievements.materialLoot[family] or {}
    end
end

local function AchievementUnlocked(id)
    EnsureAchievementDB()
    return LlamaStatsDB.achievements.unlocked[id] ~= nil
end

local function IsMilestoneReached(key, threshold)
    EnsureAchievementDB()
    local group = LlamaStatsDB.milestones.lifetime[key]
    return group and group[threshold] == true
end

local function SendAchievementChat(title, difficulty)
    if not SendChatMessage then return end
    local message = "LlamaStats achievement unlocked: " .. title
    local inGroup = false

    if IsInGroup then
        inGroup = IsInGroup()
    elseif GetNumGroupMembers then
        inGroup = (GetNumGroupMembers() or 0) > 0
    end

    if inGroup then
        SendChatMessage(message, "PARTY")
    end

    if difficulty == "guild" and IsInGuild and IsInGuild() then
        SendChatMessage(message, "GUILD")
    end
end

local function CreateBorder(parent)
    local top = parent:CreateTexture(nil, "BORDER")
    top:SetColorTexture(0.75, 0.6, 0.25, 1)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    top:SetHeight(1)

    local bottom = parent:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(0.75, 0.6, 0.25, 1)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)

    local left = parent:CreateTexture(nil, "BORDER")
    left:SetColorTexture(0.75, 0.6, 0.25, 1)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)

    local right = parent:CreateTexture(nil, "BORDER")
    right:SetColorTexture(0.75, 0.6, 0.25, 1)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
end

local function ToastOnUpdate(self)
    if self.hovered then return end

    local now = GetTime()
    if now < (self.holdUntil or 0) then return end

    self.fadeStartedAt = self.fadeStartedAt or now
    local progress = math.min(1, (now - self.fadeStartedAt) / TOAST_FADE_SECONDS)
    self:SetAlpha(1 - progress)

    if progress >= 1 then
        self:Hide()
        self:SetScript("OnUpdate", nil)
    end
end

local function CreateAchievementToast()
    if achievementToast then return end

    achievementToast = CreateFrame("Frame", "LlamaStatsAchievementToast", UIParent)
    achievementToast:SetSize(340, 74)
    achievementToast:SetPoint("TOP", UIParent, "TOP", 0, -120)
    achievementToast:SetFrameStrata("FULLSCREEN_DIALOG")
    achievementToast:EnableMouse(true)
    achievementToast:Hide()

    achievementToast.bg = achievementToast:CreateTexture(nil, "BACKGROUND")
    achievementToast.bg:SetAllPoints(achievementToast)
    achievementToast.bg:SetColorTexture(0, 0, 0, 0.88)
    CreateBorder(achievementToast)

    achievementToast.icon = achievementToast:CreateTexture(nil, "ARTWORK")
    achievementToast.icon:SetSize(36, 36)
    achievementToast.icon:SetPoint("LEFT", 14, 0)
    achievementToast.icon:SetTexture("Interface\\Icons\\Achievement_General")

    achievementToast.header = achievementToast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    achievementToast.header:SetPoint("TOPLEFT", 62, -13)
    achievementToast.header:SetText(YELLOW .. "Achievement unlocked" .. RESET)

    achievementToast.title = achievementToast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    achievementToast.title:SetPoint("TOPLEFT", 62, -35)
    achievementToast.title:SetPoint("RIGHT", -12, 0)
    achievementToast.title:SetJustifyH("LEFT")

    achievementToast:SetScript("OnEnter", function(self)
        self.hovered = true
        self:SetAlpha(1)
    end)

    achievementToast:SetScript("OnLeave", function(self)
        self.hovered = false
        self.fadeStartedAt = GetTime()
    end)
end

local function ShowAchievementToast(title)
    CreateAchievementToast()
    achievementToast.title:SetText(WHITE .. title .. RESET)
    achievementToast.hovered = false
    achievementToast.holdUntil = GetTime() + TOAST_HOLD_SECONDS
    achievementToast.fadeStartedAt = nil
    achievementToast:SetAlpha(1)
    achievementToast:Show()
    achievementToast:SetScript("OnUpdate", ToastOnUpdate)
end

local function UnlockAchievement(id, title, difficulty, live)
    EnsureAchievementDB()
    if AchievementUnlocked(id) then return false end

    LlamaStatsDB.achievements.unlocked[id] = {
        title = title,
        completedAt = CurrentTime(),
        difficulty = difficulty or "normal",
    }

    if live then
        Print("Achievement unlocked: " .. title)
        ShowAchievementToast(title)
        SendAchievementChat(title, difficulty)
    end

    return true
end

local function AddDefinition(list, category, id, title, description, unlocked, difficulty)
    table.insert(list, {
        category = category,
        id = id,
        title = title,
        description = description,
        unlocked = unlocked == true,
        difficulty = difficulty or "normal",
    })
end

local function ExtractItemLink(msg)
    msg = msg or ""
    local link = msg:match("(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
    if link then return link end
    return msg:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
end

local function ExtractQuantity(msg)
    local qty = tonumber((msg or ""):match("x(%d+)"))
    if qty and qty > 0 then return qty end
    return 1
end

local function ShouldCountLootMessage(msg)
    msg = string.lower(msg or "")
    return string.find(msg, "you receive loot") ~= nil
end

local function ClassifyMaterial(itemName, itemType, itemSubType)
    local name = string.lower(itemName or "")
    local subType = string.lower(itemSubType or "")

    if subType == "cloth" or string.find(name, "cloth") then return "Cloth" end
    if subType == "leather" or string.find(name, "leather") or string.find(name, "hide") then return "Leather" end
    if subType == "herb" then return "Herb" end
    if string.find(name, "ore") then return "Ore" end

    return nil
end

local function TrackMaterialLoot(msg, retrying)
    if not ShouldCountLootMessage(msg) then return false end

    local itemLink = ExtractItemLink(msg)
    if not itemLink or not GetItemInfo then return false end

    local itemName, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if not itemName then
        if not retrying and C_Timer and C_Timer.After then
            C_Timer.After(0.3, function()
                if TrackMaterialLoot(msg, true) then
                    ScheduleLiveAchievementCheck()
                end
            end)
        end
        return false
    end

    local family = ClassifyMaterial(itemName, itemType, itemSubType)
    if not family then return false end

    EnsureAchievementDB()
    local quantity = ExtractQuantity(msg)
    LlamaStatsDB.achievements.materialLoot[family][itemName] = (LlamaStatsDB.achievements.materialLoot[family][itemName] or 0) + quantity
    return true
end

local function AddMilestoneDefinitions(list)
    for _, set in ipairs(milestoneSets) do
        for _, threshold in ipairs(set.thresholds) do
            local valueText = set.money and PlainMoneyText(threshold) or FormatNumber(threshold)
            local id = "lifetime:" .. set.key .. ":" .. threshold
            local title = set.label .. " - " .. valueText
            AddDefinition(list, set.category, id, title, "Reach lifetime " .. string.lower(set.label) .. " of " .. valueText .. ".", IsMilestoneReached(set.key, threshold))
        end
    end
end

local function AddMaterialDefinitions(list)
    local anyMaterials = false

    for _, family in ipairs(MATERIAL_FAMILIES) do
        local materials = LlamaStatsDB.achievements.materialLoot[family] or {}
        local names = {}

        for itemName in pairs(materials) do
            table.insert(names, itemName)
        end

        table.sort(names)

        for _, itemName in ipairs(names) do
            anyMaterials = true
            local count = tonumber(materials[itemName]) or 0
            for _, threshold in ipairs(MATERIAL_THRESHOLDS) do
                local id = "material:" .. family .. ":" .. itemName .. ":" .. threshold
                local title = itemName .. " looted - " .. threshold
                AddDefinition(list, "Materials - " .. family, id, title, "Loot " .. threshold .. " total " .. itemName .. ". Current: " .. count .. ".", count >= threshold)
            end
        end
    end

    if not anyMaterials then
        AddDefinition(list, "Materials", "materials:none", "No material achievements yet", "Loot cloth, leather, ore, or herbs to reveal material achievements.", false)
    end
end

local function AddMobTypeDefinitions(list)
    local knownTypes = {}
    local seen = {}

    for creatureType in pairs(LlamaStatsDB.lifetime.mobTypes or {}) do
        if not seen[creatureType] then
            seen[creatureType] = true
            table.insert(knownTypes, creatureType)
        end
    end

    for milestoneKey in pairs(LlamaStatsDB.milestones.lifetime or {}) do
        local creatureType = string.match(milestoneKey, "^mobType:(.+)$")
        if creatureType and not seen[creatureType] then
            seen[creatureType] = true
            table.insert(knownTypes, creatureType)
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

local function CheckLimitedQuestAchievements(level, live)
    EnsureAchievementDB()
    level = tonumber(level) or (UnitLevel and UnitLevel("player")) or 0
    local questsCompleted = tonumber(LlamaStatsDB.lifetime.questsCompleted) or 0

    for _, requiredLevel in ipairs(limitedQuestLevels) do
        if level >= requiredLevel and questsCompleted < requiredLevel then
            UnlockAchievement("limitedQuests:" .. requiredLevel, "Level " .. requiredLevel .. " with under " .. requiredLevel .. " quests", "guild", live)
        end
    end
end

local function BuildAchievementDefinitions()
    EnsureAchievementDB()
    local list = {}

    AddMilestoneDefinitions(list)
    AddMaterialDefinitions(list)
    AddMobTypeDefinitions(list)

    for _, requiredLevel in ipairs(limitedQuestLevels) do
        local id = "limitedQuests:" .. requiredLevel
        AddDefinition(list, "Limited Questing", id, "Level " .. requiredLevel .. " with under " .. requiredLevel .. " quests", "Reach level " .. requiredLevel .. " while lifetime quests completed is less than " .. requiredLevel .. ".", AchievementUnlocked(id), "guild")
    end

    table.sort(list, function(a, b)
        if a.category == b.category then
            if AchievementUnlocked(a.id) ~= AchievementUnlocked(b.id) then
                return AchievementUnlocked(a.id) and not AchievementUnlocked(b.id)
            end
            return a.title < b.title
        end
        return a.category < b.category
    end)

    return list
end

local function SyncAchievementUnlocks(live)
    CheckLimitedQuestAchievements(nil, live)

    for _, achievement in ipairs(BuildAchievementDefinitions()) do
        if achievement.unlocked then
            UnlockAchievement(achievement.id, achievement.title, achievement.difficulty, live)
        end
    end
end

local function ClearRows()
    for _, row in ipairs(rows) do
        row:Hide()
        row:SetParent(nil)
    end
    rows = {}
end

local function CreateAchievementWindow()
    if achievementFrame then return end

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
    local unlocked = AchievementUnlocked(achievement.id)
    local title = achievementContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 12, y)
    title:SetWidth(365)
    title:SetJustifyH("LEFT")
    title:SetText((unlocked and GREEN or GRAY) .. (unlocked and "[Done] " or "[Locked] ") .. achievement.title .. RESET)
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
    SyncAchievementUnlocks(false)
    ClearRows()

    local definitions = BuildAchievementDefinitions()
    local unlockedCount = 0
    for _, achievement in ipairs(definitions) do
        if AchievementUnlocked(achievement.id) then
            unlockedCount = unlockedCount + 1
        end
    end

    local summary = achievementContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", 4, -2)
    summary:SetText(WHITE .. "Unlocked: " .. unlockedCount .. " / " .. #definitions .. RESET)
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
    if achievementFrame:IsShown() then achievementFrame:Hide() else achievementFrame:Show() end
end

local function AddAchievementButton()
    local frame = _G.LlamaStatsFrame
    if not frame or frame.llamaStatsAchievementsButton then return false end

    local button = CreateFrame("Button", "LlamaStatsAchievementsButton", frame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
    button:SetText("Achieve")
    button:SetScript("OnClick", ToggleAchievementWindow)
    frame.llamaStatsAchievementsButton = button
    return true
end

function ScheduleLiveAchievementCheck()
    if liveCheckQueued then return end
    liveCheckQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            liveCheckQueued = false
            SyncAchievementUnlocks(true)
            if achievementFrame and achievementFrame:IsShown() then RefreshAchievementWindow() end
        end)
    else
        liveCheckQueued = false
        SyncAchievementUnlocks(true)
        if achievementFrame and achievementFrame:IsShown() then RefreshAchievementWindow() end
    end
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
    if self.elapsed < RETRY_INTERVAL then return end
    self.elapsed = 0
    self.retries = self.retries + 1
    if AddAchievementButton() or self.retries >= RETRY_LIMIT then self:Hide() end
end)
retryFrame:Hide()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("CHAT_MSG_MONEY")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureAchievementDB()
        SyncAchievementUnlocks(false)
        if not AddAchievementButton() then StartRetry() end
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        CheckLimitedQuestAchievements(newLevel, true)
        if achievementFrame and achievementFrame:IsShown() then RefreshAchievementWindow() end
        return
    end

    if event == "CHAT_MSG_LOOT" then
        TrackMaterialLoot(...)
    end

    ScheduleLiveAchievementCheck()
end)
