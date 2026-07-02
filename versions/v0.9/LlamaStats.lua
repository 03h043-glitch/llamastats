print("LlamaStats loaded")

LlamaStatsDB = LlamaStatsDB or {}

local GOLD = "|cffffd700"
local SILVER = "|cffc7c7cf"
local COPPER = "|cffeda55f"
local WHITE = "|cffffffff"
local YELLOW = "|cffffcc00"
local GREEN = "|cff1eff00"
local BLUE = "|cff0070dd"
local PURPLE = "|cffa335ee"
local RESET = "|r"

local frame
local minimapButton
local settingsPanel
local settingsCategory
local rows = {}
local displayEntries = {}
local fontStrings = {}
local lastXP
local lastXPMax
local lastLevel
local uiTick = 0
local knownMobTypes = {}

local goldMilestones = { 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000 }
local itemMilestones = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
local qualityMilestones = { 1, 5, 10, 25, 50, 100, 250 }
local damageMilestones = { 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000 }
local mobTypeMilestones = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }

local defaults = {
    lifetime = {
        questsCompleted = 0,
        mobsKilled = 0,
        mobTypes = {},
        moneyLooted = 0,
        moneyQuestRewards = 0,
        vendorValueLooted = 0,
        deaths = 0,
        itemsLooted = 0,
        greenItems = 0,
        blueItems = 0,
        purpleItems = 0,
        highestVendorItemName = "None",
        highestVendorItemValue = 0,
        damageDealt = 0,
        experienceGained = 0,
    },
    session = {
        startedAt = 0,
        questsCompleted = 0,
        mobsKilled = 0,
        mobTypes = {},
        moneyLooted = 0,
        moneyQuestRewards = 0,
        vendorValueLooted = 0,
        itemsLooted = 0,
        greenItems = 0,
        blueItems = 0,
        purpleItems = 0,
        damageDealt = 0,
        experienceGained = 0,
    },
    mobs = {},
    milestones = {
        lifetime = {},
        session = {},
    },
    minimap = {
        angle = 220,
        hide = false,
    },
    window = {
        opacity = 0.85,
        scale = 1,
        textSize = 11,
        display = {
            questsCompleted = true,
            mobsKilled = true,
            topMobType = true,
            damageDealt = true,
            moneyLooted = true,
            moneyQuestRewards = true,
            vendorValueLooted = true,
            deaths = true,
            itemsLooted = true,
            greenItems = true,
            blueItems = true,
            purpleItems = true,
            highestVendorItemName = true,
            highestVendorItemValue = true,
            sessionLength = true,
            sessionQuests = true,
            sessionKills = true,
            sessionTopMobType = true,
            sessionDamage = true,
            sessionExperience = true,
            sessionExpPerHour = true,
            sessionMoney = true,
            sessionQuestGold = true,
            sessionGoldPerHour = true,
            sessionVendorValue = true,
            sessionItems = true,
            sessionGreens = true,
            sessionBlues = true,
            sessionPurples = true,
        },
    },
}

local lifetimeDisplayOptions = {
    { key = "questsCompleted", label = "Lifetime quests" },
    { key = "mobsKilled", label = "Lifetime kills" },
    { key = "topMobType", label = "Lifetime top mob type" },
    { key = "damageDealt", label = "Lifetime damage" },
    { key = "moneyLooted", label = "Lifetime looted coin" },
    { key = "moneyQuestRewards", label = "Lifetime quest gold" },
    { key = "vendorValueLooted", label = "Lifetime vendor value" },
    { key = "deaths", label = "Lifetime deaths" },
    { key = "itemsLooted", label = "Lifetime items" },
    { key = "greenItems", label = "Lifetime greens" },
    { key = "blueItems", label = "Lifetime blues" },
    { key = "purpleItems", label = "Lifetime purples" },
    { key = "highestVendorItemName", label = "Lifetime best item" },
    { key = "highestVendorItemValue", label = "Lifetime best value" },
}

local sessionDisplayOptions = {
    { key = "sessionLength", label = "Session length" },
    { key = "sessionQuests", label = "Session quests" },
    { key = "sessionKills", label = "Session kills" },
    { key = "sessionTopMobType", label = "Session top mob type" },
    { key = "sessionDamage", label = "Session damage" },
    { key = "sessionExperience", label = "Session XP" },
    { key = "sessionExpPerHour", label = "Session XP/hour" },
    { key = "sessionMoney", label = "Session looted coin" },
    { key = "sessionQuestGold", label = "Session quest gold" },
    { key = "sessionGoldPerHour", label = "Session gold/hour" },
    { key = "sessionVendorValue", label = "Session vendor value" },
    { key = "sessionItems", label = "Session items" },
    { key = "sessionGreens", label = "Session greens" },
    { key = "sessionBlues", label = "Session blues" },
    { key = "sessionPurples", label = "Session purples" },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "LlamaStats:" .. RESET .. " " .. tostring(msg))
end

local function Popup(msg, r, g, b)
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(msg, r or 1, g or 0.82, b or 0, 1)
    end

    Print(msg)
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

local function MoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)

    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    local parts = {}

    if g > 0 then
        table.insert(parts, GOLD .. g .. "g" .. RESET)
    end

    if s > 0 or g > 0 then
        table.insert(parts, SILVER .. s .. "s" .. RESET)
    end

    table.insert(parts, COPPER .. c .. "c" .. RESET)

    return table.concat(parts, " ")
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

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, secs)
    end

    return string.format("%dm %02ds", minutes, secs)
end

local function FormatPerHour(value, elapsed)
    value = tonumber(value) or 0
    elapsed = math.max(1, tonumber(elapsed) or 0)
    return FormatNumber((value * 3600) / elapsed)
end

local function MoneyPerHourText(copper, elapsed)
    copper = tonumber(copper) or 0
    elapsed = math.max(1, tonumber(elapsed) or 0)
    return MoneyText((copper * 3600) / elapsed)
end

local function GetSessionElapsedSeconds()
    local startedAt = LlamaStatsDB.session and LlamaStatsDB.session.startedAt or CurrentTime()
    return math.max(0, CurrentTime() - (startedAt or CurrentTime()))
end

local function GetSessionGoldGained()
    local s = LlamaStatsDB.session or {}
    return (s.moneyLooted or 0) + (s.moneyQuestRewards or 0)
end

local function RefreshExperienceSnapshot()
    if UnitXP then
        lastXP = UnitXP("player") or 0
    else
        lastXP = 0
    end

    if UnitXPMax then
        lastXPMax = UnitXPMax("player") or 0
    else
        lastXPMax = 0
    end

    if UnitLevel then
        lastLevel = UnitLevel("player") or 0
    else
        lastLevel = 0
    end
end

local function NormalizeMobType(creatureType)
    creatureType = creatureType or ""
    if creatureType == "" or creatureType == "Not specified" then
        return "Unknown"
    end

    return creatureType
end

local function RememberUnitMobType(unit)
    if not unit or not UnitGUID or not UnitCreatureType then return end
    if not UnitExists or not UnitExists(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    knownMobTypes[guid] = NormalizeMobType(UnitCreatureType(unit))
end

local function RememberVisibleMobTypes()
    RememberUnitMobType("target")
    RememberUnitMobType("mouseover")
    RememberUnitMobType("focus")

    for i = 1, 40 do
        RememberUnitMobType("nameplate" .. i)
    end
end

local function GetMobTypeForGuid(guid)
    if guid and knownMobTypes[guid] then
        return knownMobTypes[guid]
    end

    RememberVisibleMobTypes()
    return (guid and knownMobTypes[guid]) or "Unknown"
end

local function GetTopMobTypeText(mobTypes)
    local topType = nil
    local topCount = 0

    for creatureType, count in pairs(mobTypes or {}) do
        count = tonumber(count) or 0
        if count > topCount then
            topType = creatureType
            topCount = count
        end
    end

    if not topType then
        return "None"
    end

    return topType .. " (" .. topCount .. ")"
end

local function ApplyTextSize()
    local size = LlamaStatsDB.window.textSize or 11
    local font = "Fonts\\FRIZQT__.TTF"

    for _, fs in ipairs(fontStrings) do
        if fs then
            fs:SetFont(font, size, "OUTLINE")
        end
    end
end

local function ApplyWindowScale()
    if frame then
        frame:SetScale(LlamaStatsDB.window.scale or 1)
    end
end

local function ResetSession()
    LlamaStatsDB.session = {
        startedAt = CurrentTime(),
        questsCompleted = 0,
        mobsKilled = 0,
        mobTypes = {},
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
    RefreshExperienceSnapshot()
end

local function ApplyWindowOpacity()
    if not frame or not frame.bg then return end
    local opacity = LlamaStatsDB.window.opacity or 0.85
    frame.bg:SetColorTexture(0, 0, 0, opacity)
end

local function IsDisplayEnabled(key)
    LlamaStatsDB.window.display = LlamaStatsDB.window.display or {}
    return LlamaStatsDB.window.display[key] ~= false
end

local function SectionHasVisibleRows(section)
    for _, entry in ipairs(displayEntries) do
        if entry.type == "row" and entry.section == section and IsDisplayEnabled(entry.key) then
            return true
        end
    end

    return false
end

local function ApplyStatsDisplay()
    if not frame then return end

    local y = -38
    local anyVisible = false

    for _, entry in ipairs(displayEntries) do
        if entry.type == "section" then
            entry.visible = SectionHasVisibleRows(entry.key)

            if entry.visible then
                if anyVisible then
                    y = y - 14
                end

                entry.fs:ClearAllPoints()
                entry.fs:SetPoint("TOPLEFT", 12, y)
                entry.fs:Show()
                y = y - 24
                anyVisible = true
            else
                entry.fs:Hide()
            end
        elseif entry.type == "row" then
            local visible = IsDisplayEnabled(entry.key)

            if visible then
                entry.left:ClearAllPoints()
                entry.right:ClearAllPoints()
                entry.left:SetPoint("TOPLEFT", 14, y)
                entry.right:SetPoint("TOPRIGHT", -14, y)
                entry.left:Show()
                entry.right:Show()
                y = y - 18
            else
                entry.left:Hide()
                entry.right:Hide()
            end
        end
    end

    frame:SetHeight(math.max(82, math.abs(y) + 22))
end

local function UpdateUI()
    if not rows.questsCompleted then return end

    local l = LlamaStatsDB.lifetime
    local s = LlamaStatsDB.session
    local elapsed = GetSessionElapsedSeconds()

    rows.questsCompleted:SetText(l.questsCompleted or 0)
    rows.mobsKilled:SetText(l.mobsKilled or 0)
    rows.topMobType:SetText(GetTopMobTypeText(l.mobTypes))
    rows.damageDealt:SetText(FormatNumber(l.damageDealt or 0))
    rows.moneyLooted:SetText(MoneyText(l.moneyLooted or 0))
    rows.moneyQuestRewards:SetText(MoneyText(l.moneyQuestRewards or 0))
    rows.vendorValueLooted:SetText(MoneyText(l.vendorValueLooted or 0))
    rows.deaths:SetText(l.deaths or 0)
    rows.itemsLooted:SetText(l.itemsLooted or 0)
    rows.greenItems:SetText(GREEN .. (l.greenItems or 0) .. RESET)
    rows.blueItems:SetText(BLUE .. (l.blueItems or 0) .. RESET)
    rows.purpleItems:SetText(PURPLE .. (l.purpleItems or 0) .. RESET)
    rows.highestVendorItemName:SetText(l.highestVendorItemName or "None")
    rows.highestVendorItemValue:SetText(MoneyText(l.highestVendorItemValue or 0))

    rows.sessionLength:SetText(FormatDuration(elapsed))
    rows.sessionQuests:SetText(s.questsCompleted or 0)
    rows.sessionKills:SetText(s.mobsKilled or 0)
    rows.sessionTopMobType:SetText(GetTopMobTypeText(s.mobTypes))
    rows.sessionDamage:SetText(FormatNumber(s.damageDealt or 0))
    rows.sessionExperience:SetText(FormatNumber(s.experienceGained or 0))
    rows.sessionExpPerHour:SetText(FormatPerHour(s.experienceGained or 0, elapsed))
    rows.sessionMoney:SetText(MoneyText(s.moneyLooted or 0))
    rows.sessionQuestGold:SetText(MoneyText(s.moneyQuestRewards or 0))
    rows.sessionGoldPerHour:SetText(MoneyPerHourText(GetSessionGoldGained(), elapsed))
    rows.sessionVendorValue:SetText(MoneyText(s.vendorValueLooted or 0))
    rows.sessionItems:SetText(s.itemsLooted or 0)
    rows.sessionGreens:SetText(GREEN .. (s.greenItems or 0) .. RESET)
    rows.sessionBlues:SetText(BLUE .. (s.blueItems or 0) .. RESET)
    rows.sessionPurples:SetText(PURPLE .. (s.purpleItems or 0) .. RESET)
end

local function SendLifetimeMilestonePartyMessage(msg)
    if not SendChatMessage then return end

    local inGroup = false
    if IsInGroup then
        inGroup = IsInGroup()
    elseif GetNumGroupMembers then
        inGroup = (GetNumGroupMembers() or 0) > 0
    end

    if inGroup then
        SendChatMessage(msg, "PARTY")
    end
end

local function CheckMilestones(scope, key, value, thresholds, label, formatter, r, g, b)
    LlamaStatsDB.milestones = LlamaStatsDB.milestones or {}
    LlamaStatsDB.milestones[scope] = LlamaStatsDB.milestones[scope] or {}
    LlamaStatsDB.milestones[scope][key] = LlamaStatsDB.milestones[scope][key] or {}

    for _, threshold in ipairs(thresholds) do
        if value >= threshold and not LlamaStatsDB.milestones[scope][key][threshold] then
            LlamaStatsDB.milestones[scope][key][threshold] = true
            local milestoneValue = (formatter and formatter(threshold)) or threshold
            local msg = "LlamaStats: " .. scope .. " " .. label .. " reached " .. milestoneValue .. "!"
            Popup(msg, r, g, b)

            if scope == "lifetime" then
                SendLifetimeMilestonePartyMessage(msg)
            end
        end
    end
end

local function RunMilestoneChecks(key)
    if key == "moneyLooted" then
        CheckMilestones("lifetime", key, LlamaStatsDB.lifetime.moneyLooted or 0, goldMilestones, "looted coin", PlainMoneyText, 1, 0.82, 0)
        CheckMilestones("session", key, LlamaStatsDB.session.moneyLooted or 0, goldMilestones, "looted coin", PlainMoneyText, 1, 0.82, 0)

    elseif key == "itemsLooted" then
        CheckMilestones("lifetime", key, LlamaStatsDB.lifetime.itemsLooted or 0, itemMilestones, "items looted", nil, 1, 1, 1)
        CheckMilestones("session", key, LlamaStatsDB.session.itemsLooted or 0, itemMilestones, "items looted", nil, 1, 1, 1)

    elseif key == "greenItems" then
        CheckMilestones("lifetime", key, LlamaStatsDB.lifetime.greenItems or 0, qualityMilestones, "green items", nil, 0.1, 1, 0.1)
        CheckMilestones("session", key, LlamaStatsDB.session.greenItems or 0, qualityMilestones, "green items", nil, 0.1, 1, 0.1)

    elseif key == "blueItems" then
        CheckMilestones("lifetime", key, LlamaStatsDB.lifetime.blueItems or 0, qualityMilestones, "blue items", nil, 0.2, 0.6, 1)
        CheckMilestones("session", key, LlamaStatsDB.session.blueItems or 0, qualityMilestones, "blue items", nil, 0.2, 0.6, 1)

    elseif key == "purpleItems" then
        CheckMilestones("lifetime", key, LlamaStatsDB.lifetime.purpleItems or 0, qualityMilestones, "purple items", nil, 0.8, 0.3, 1)
        CheckMilestones("session", key, LlamaStatsDB.session.purpleItems or 0, qualityMilestones, "purple items", nil, 0.8, 0.3, 1)

    elseif key == "damageDealt" then
        CheckMilestones("lifetime", key, LlamaStatsDB.lifetime.damageDealt or 0, damageMilestones, "damage dealt", FormatNumber, 1, 0.25, 0.1)
        CheckMilestones("session", key, LlamaStatsDB.session.damageDealt or 0, damageMilestones, "damage dealt", FormatNumber, 1, 0.25, 0.1)
    end
end

local function CheckMobTypeMilestones(creatureType)
    creatureType = NormalizeMobType(creatureType)
    local milestoneKey = "mobType:" .. creatureType

    CheckMilestones("lifetime", milestoneKey, LlamaStatsDB.lifetime.mobTypes[creatureType] or 0, mobTypeMilestones, creatureType .. " kills", nil, 1, 0.45, 0.1)
    CheckMilestones("session", milestoneKey, LlamaStatsDB.session.mobTypes[creatureType] or 0, mobTypeMilestones, creatureType .. " kills", nil, 1, 0.45, 0.1)
end

local function AddStat(key, amount)
    amount = amount or 1
    LlamaStatsDB.lifetime[key] = (LlamaStatsDB.lifetime[key] or 0) + amount
    LlamaStatsDB.session[key] = (LlamaStatsDB.session[key] or 0) + amount
    UpdateUI()
    RunMilestoneChecks(key)
end

local function AddLifetimeOnly(key, amount)
    amount = amount or 1
    LlamaStatsDB.lifetime[key] = (LlamaStatsDB.lifetime[key] or 0) + amount
    UpdateUI()
    RunMilestoneChecks(key)
end

local function AddMobType(creatureType, amount)
    amount = amount or 1
    creatureType = NormalizeMobType(creatureType)
    LlamaStatsDB.lifetime.mobTypes = LlamaStatsDB.lifetime.mobTypes or {}
    LlamaStatsDB.session.mobTypes = LlamaStatsDB.session.mobTypes or {}
    LlamaStatsDB.lifetime.mobTypes[creatureType] = (LlamaStatsDB.lifetime.mobTypes[creatureType] or 0) + amount
    LlamaStatsDB.session.mobTypes[creatureType] = (LlamaStatsDB.session.mobTypes[creatureType] or 0) + amount
    UpdateUI()
    CheckMobTypeMilestones(creatureType)
end

local function AddExperience(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    LlamaStatsDB.lifetime.experienceGained = (LlamaStatsDB.lifetime.experienceGained or 0) + amount
    LlamaStatsDB.session.experienceGained = (LlamaStatsDB.session.experienceGained or 0) + amount
    UpdateUI()
end

local function ParseMoneyMessage(msg)
    msg = msg or ""

    local gold = tonumber(msg:match("(%d+) Gold")) or tonumber(msg:match("(%d+) gold")) or 0
    local silver = tonumber(msg:match("(%d+) Silver")) or tonumber(msg:match("(%d+) silver")) or 0
    local copper = tonumber(msg:match("(%d+) Copper")) or tonumber(msg:match("(%d+) copper")) or 0

    return gold * 10000 + silver * 100 + copper
end

local function ExtractItemLink(msg)
    msg = msg or ""

    local link = msg:match("(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
    if link then return link end

    link = msg:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
    if link then return link end

    return nil
end

local function ExtractQuantity(msg)
    msg = msg or ""
    local qty = tonumber(msg:match("x(%d+)"))
    if qty and qty > 0 then
        return qty
    end
    return 1
end

local function ShouldCountLootMessage(msg)
    msg = string.lower(msg or "")

    if string.find(msg, "you receive loot") then
        return true
    end

    if string.find(msg, "you receive item") then
        return false
    end

    return false
end

local function GetDamageAmountFromCombatLog(args, subEvent)
    if subEvent == "SWING_DAMAGE" then
        return tonumber(args[12]) or 0
    end

    if subEvent == "RANGE_DAMAGE"
        or subEvent == "SPELL_DAMAGE"
        or subEvent == "SPELL_PERIODIC_DAMAGE"
        or subEvent == "SPELL_BUILDING_DAMAGE"
        or subEvent == "DAMAGE_SHIELD" then
        return tonumber(args[15]) or 0
    end

    return 0
end

local function HandleExperienceUpdate()
    if not UnitXP or not UnitXPMax or not UnitLevel then return end

    local currentXP = UnitXP("player") or 0
    local currentMaxXP = UnitXPMax("player") or 0
    local currentLevel = UnitLevel("player") or 0
    local gained = 0

    if lastXP ~= nil and lastLevel ~= nil then
        if currentLevel > lastLevel then
            gained = math.max(0, (lastXPMax or 0) - (lastXP or 0)) + currentXP
        elseif currentLevel == lastLevel and currentXP > (lastXP or 0) then
            gained = currentXP - (lastXP or 0)
        end
    end

    lastXP = currentXP
    lastXPMax = currentMaxXP
    lastLevel = currentLevel
    AddExperience(gained)
end

local function ToggleWindow()
    if not frame then return end

    if frame:IsShown() then
        frame:Hide()
    else
        ApplyWindowOpacity()
        UpdateUI()
        frame:Show()
    end
end

local function OpenSettingsPanel()
    if Settings and Settings.OpenToCategory then
        local category = settingsCategory
        if category and category.GetID then
            category = category:GetID()
        end
        category = category or "LlamaStats"
        Settings.OpenToCategory(category)
        Settings.OpenToCategory(category)
    elseif InterfaceOptionsFrame_OpenToCategory and settingsPanel then
        InterfaceOptionsFrame_OpenToCategory(settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(settingsPanel)
    else
        Print("Open the WoW AddOns settings and select LlamaStats.")
    end
end

local function CreateDisplayCheckbox(parent, option, x, y)
    local check = CreateFrame("CheckButton", "LlamaStatsDisplay" .. option.key, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)

    local text = check.Text or _G[check:GetName() .. "Text"]
    if text then
        text:SetText(option.label)
    end

    check:SetScript("OnClick", function(self)
        LlamaStatsDB.window.display[option.key] = self:GetChecked() and true or false
        ApplyStatsDisplay()
    end)

    parent.checkboxes[option.key] = check
end

local function CreateSettingsPanel()
    if settingsPanel then return end

    settingsPanel = CreateFrame("Frame", "LlamaStatsSettingsPanel")
    settingsPanel.name = "LlamaStats"
    settingsPanel.checkboxes = {}

    local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("LlamaStats")

    local opacityLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    opacityLabel:SetPoint("TOPLEFT", 16, -52)
    opacityLabel:SetText("Tracker window opacity")

    local slider = CreateFrame("Slider", "LlamaStatsOpacitySlider", settingsPanel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 22, -80)
    slider:SetWidth(220)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(5)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    if _G[slider:GetName() .. "Low"] then
        _G[slider:GetName() .. "Low"]:SetText("0%")
    end

    if _G[slider:GetName() .. "High"] then
        _G[slider:GetName() .. "High"]:SetText("100%")
    end

    local sliderText = _G[slider:GetName() .. "Text"]
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value or 0) + 0.5)
        LlamaStatsDB.window.opacity = value / 100
        if sliderText then
            sliderText:SetText(value .. "%")
        end
        ApplyWindowOpacity()
    end)

    settingsPanel.opacitySlider = slider

    local lifetimeTitle = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lifetimeTitle:SetPoint("TOPLEFT", 16, -130)
    lifetimeTitle:SetText("Lifetime Display")

    local sessionTitle = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sessionTitle:SetPoint("TOPLEFT", 300, -130)
    sessionTitle:SetText("Session Display")

    local y = -154
    for _, option in ipairs(lifetimeDisplayOptions) do
        CreateDisplayCheckbox(settingsPanel, option, 16, y)
        y = y - 24
    end

    y = -154
    for _, option in ipairs(sessionDisplayOptions) do
        CreateDisplayCheckbox(settingsPanel, option, 300, y)
        y = y - 24
    end

    settingsPanel:SetScript("OnShow", function(self)
        CopyDefaults(defaults, LlamaStatsDB)

        self.opacitySlider:SetValue(math.floor((LlamaStatsDB.window.opacity or 0.85) * 100 + 0.5))

        for key, check in pairs(self.checkboxes) do
            check:SetChecked(IsDisplayEnabled(key))
        end
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsPanel, "LlamaStats")
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(settingsPanel)
    end
end

SLASH_LLAMASTATS1 = "/llamastats"
SLASH_LLAMASTATS2 = "/llama"

SlashCmdList["LLAMASTATS"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "reset session" then
        ResetSession()
        UpdateUI()
        Print("Session stats reset.")
        return
    end

    if msg == "reset all" then
        LlamaStatsDB = {}
        CopyDefaults(defaults, LlamaStatsDB)
        ResetSession()
        ApplyWindowOpacity()
        ApplyWindowScale()
        ApplyTextSize()
        ApplyStatsDisplay()
        UpdateUI()
        Print("All stats reset.")
        return
    end

    if msg == "options" or msg == "settings" then
        OpenSettingsPanel()
        return
    end

    if msg == "top mobs" then
        Print("Top mob kills:")

        local temp = {}

        for name, count in pairs(LlamaStatsDB.mobs or {}) do
            table.insert(temp, { name = name, count = count })
        end

        table.sort(temp, function(a, b)
            return a.count > b.count
        end)

        for i = 1, math.min(10, #temp) do
            Print(i .. ". " .. temp[i].name .. " - " .. temp[i].count)
        end

        return
    end

    if msg == "top types" or msg == "top mob types" then
        Print("Top lifetime mob types:")

        local temp = {}
        for creatureType, count in pairs(LlamaStatsDB.lifetime.mobTypes or {}) do
            table.insert(temp, { name = creatureType, count = count })
        end

        table.sort(temp, function(a, b)
            return a.count > b.count
        end)

        for i = 1, math.min(10, #temp) do
            Print(i .. ". " .. temp[i].name .. " - " .. temp[i].count)
        end

        if #temp == 0 then
            Print("No mob types tracked yet.")
        end

        return
    end

    if msg == "hide minimap" then
        LlamaStatsDB.minimap.hide = true
        if minimapButton then minimapButton:Hide() end
        Print("Minimap button hidden. Use /llamastats show minimap.")
        return
    end

    if msg == "show minimap" then
        LlamaStatsDB.minimap.hide = false
        if minimapButton then minimapButton:Show() end
        Print("Minimap button shown.")
        return
    end

    if string.find(msg, "^opacity ") then
        local value = tonumber(string.match(msg, "^opacity (%d+)"))

        if not value or value < 0 or value > 100 then
            Print("Use /llamastats opacity 0-100")
            return
        end

        LlamaStatsDB.window.opacity = value / 100
        ApplyWindowOpacity()
        Print("Window opacity set to " .. value .. "%.")
        return
    end

    if string.find(msg, "^scale ") then
        local value = tonumber(string.match(msg, "^scale (%d+)"))

        if not value or value < 50 or value > 200 then
            Print("Use /llamastats scale 50-200")
            return
        end

        LlamaStatsDB.window.scale = value / 100
        ApplyWindowScale()
        Print("Window scale set to " .. value .. "%.")
        return
    end

    if string.find(msg, "^text ") then
        local value = tonumber(string.match(msg, "^text (%d+)"))

        if not value or value < 8 or value > 24 then
            Print("Use /llamastats text 8-24")
            return
        end

        LlamaStatsDB.window.textSize = value
        ApplyTextSize()
        Print("Text size set to " .. value .. ".")
        return
    end

    ToggleWindow()
end

local function CreateRow(section, key, label, y, colour)
    local left = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    left:SetPoint("TOPLEFT", 14, y)
    left:SetText((colour or WHITE) .. label .. RESET)

    local right = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    right:SetPoint("TOPRIGHT", -14, y)
    right:SetText("0")

    table.insert(fontStrings, left)
    table.insert(fontStrings, right)
    table.insert(displayEntries, { type = "row", section = section, key = key, left = left, right = right })

    rows[key] = right
end

local function CreateSection(key, text, y)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 12, y)
    fs:SetText(YELLOW .. text .. RESET)

    table.insert(fontStrings, fs)
    table.insert(displayEntries, { type = "section", key = key, fs = fs })
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

local function CreateMainWindow()
    frame = CreateFrame("Frame", "LlamaStatsFrame", UIParent)
    frame:SetSize(280, 610)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetFrameStrata("DIALOG")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)

    CreateBorder(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(YELLOW .. "LlamaStats" .. RESET)
    table.insert(fontStrings, title)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnUpdate", function(_, elapsed)
        uiTick = uiTick + (elapsed or 0)
        if uiTick >= 1 then
            uiTick = 0
            UpdateUI()
        end
    end)

    CreateSection("lifetime", "Lifetime", -38)
    CreateRow("lifetime", "questsCompleted", "Quests:", -62)
    CreateRow("lifetime", "mobsKilled", "Kills:", -80)
    CreateRow("lifetime", "topMobType", "Top type:", -98)
    CreateRow("lifetime", "damageDealt", "Damage:", -116)
    CreateRow("lifetime", "moneyLooted", "Looted coin:", -134)
    CreateRow("lifetime", "moneyQuestRewards", "Quest gold:", -152)
    CreateRow("lifetime", "vendorValueLooted", "Vendor value:", -170)
    CreateRow("lifetime", "deaths", "Deaths:", -188)
    CreateRow("lifetime", "itemsLooted", "Items:", -206)
    CreateRow("lifetime", "greenItems", "Greens:", -224, GREEN)
    CreateRow("lifetime", "blueItems", "Blues:", -242, BLUE)
    CreateRow("lifetime", "purpleItems", "Purples:", -260, PURPLE)
    CreateRow("lifetime", "highestVendorItemName", "Best item:", -278)
    CreateRow("lifetime", "highestVendorItemValue", "Best value:", -296)

    CreateSection("session", "Session", -328)
    CreateRow("session", "sessionLength", "Length:", -352)
    CreateRow("session", "sessionQuests", "Quests:", -370)
    CreateRow("session", "sessionKills", "Kills:", -388)
    CreateRow("session", "sessionTopMobType", "Top type:", -406)
    CreateRow("session", "sessionDamage", "Damage:", -424)
    CreateRow("session", "sessionExperience", "XP:", -442)
    CreateRow("session", "sessionExpPerHour", "XP/hr:", -460)
    CreateRow("session", "sessionMoney", "Looted coin:", -478)
    CreateRow("session", "sessionQuestGold", "Quest gold:", -496)
    CreateRow("session", "sessionGoldPerHour", "Gold/hr:", -514)
    CreateRow("session", "sessionVendorValue", "Vendor value:", -532)
    CreateRow("session", "sessionItems", "Items:", -550)
    CreateRow("session", "sessionGreens", "Greens:", -568, GREEN)
    CreateRow("session", "sessionBlues", "Blues:", -586, BLUE)
    CreateRow("session", "sessionPurples", "Purples:", -604, PURPLE)

    ApplyTextSize()
    ApplyWindowOpacity()
    ApplyWindowScale()
    ApplyStatsDisplay()
    frame:Hide()
end

local function CreateMinimapButton()
    minimapButton = CreateFrame("Button", "LlamaStatsMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("HIGH")

    minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    minimapButton.icon:SetSize(20, 20)
    minimapButton.icon:SetPoint("CENTER")
    minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")

    minimapButton.border = minimapButton:CreateTexture(nil, "OVERLAY")
    minimapButton.border:SetSize(54, 54)
    minimapButton.border:SetPoint("CENTER")
    minimapButton.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local angle = math.rad(LlamaStatsDB.minimap.angle or 220)
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 78, math.sin(angle) * 78)

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            ToggleWindow()
        else
            Print("/llama, /llama settings, /llama top types, /llama opacity 0-100, /llama scale 50-200, /llama text 8-24")
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("LlamaStats")
        GameTooltip:AddLine("Left-click: toggle window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: commands", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    if LlamaStatsDB.minimap.hide then
        minimapButton:Hide()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("CHAT_MSG_MONEY")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "LlamaStats" then
            CopyDefaults(defaults, LlamaStatsDB)
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        CopyDefaults(defaults, LlamaStatsDB)
        ResetSession()
        CreateMainWindow()
        CreateMinimapButton()
        CreateSettingsPanel()
        RememberVisibleMobTypes()
        UpdateUI()
        Print("Ready. Use /llama")
        return
    end

    if event == "PLAYER_XP_UPDATE" then
        HandleExperienceUpdate()
        return
    end

    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
        RememberVisibleMobTypes()
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        RememberUnitMobType(unit)
        return
    end

    if event == "QUEST_TURNED_IN" then
        local questID, xpReward, moneyReward = ...

        AddStat("questsCompleted", 1)

        if moneyReward and moneyReward > 0 then
            AddStat("moneyQuestRewards", moneyReward)
        end

        return
    end

    if event == "PLAYER_DEAD" then
        AddLifetimeOnly("deaths", 1)
        return
    end

    if event == "CHAT_MSG_MONEY" then
        local msg = ...
        local copper = ParseMoneyMessage(msg)

        if copper > 0 then
            AddStat("moneyLooted", copper)
        end

        return
    end

    if event == "CHAT_MSG_LOOT" then
        local msg = ...

        if not ShouldCountLootMessage(msg) then
            return
        end

        local itemLink = ExtractItemLink(msg)

        if itemLink then
            local quantity = ExtractQuantity(msg)

            AddStat("itemsLooted", quantity)

            local itemName, _, itemQuality, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(itemLink)
            vendorPrice = vendorPrice or 0

            if vendorPrice > 0 then
                AddStat("vendorValueLooted", vendorPrice * quantity)
            end

            if itemQuality == 2 then
                AddStat("greenItems", quantity)
            elseif itemQuality == 3 then
                AddStat("blueItems", quantity)
            elseif itemQuality == 4 then
                AddStat("purpleItems", quantity)
            end

            if vendorPrice > (LlamaStatsDB.lifetime.highestVendorItemValue or 0) then
                LlamaStatsDB.lifetime.highestVendorItemValue = vendorPrice
                LlamaStatsDB.lifetime.highestVendorItemName = itemName or itemLink
                UpdateUI()
                Popup("LlamaStats: new record vendor item - " .. (itemName or itemLink) .. " (" .. PlainMoneyText(vendorPrice) .. ")")
            end
        end

        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local args = { CombatLogGetCurrentEventInfo() }
        local subEvent = args[2]
        local sourceGUID = args[4]
        local destGUID = args[8]

        local playerGUID = UnitGUID("player")
        local petGUID = UnitGUID("pet")

        if destGUID then
            RememberVisibleMobTypes()
        end

        if subEvent == "PARTY_KILL" then
            local destName = args[9]

            if sourceGUID == playerGUID or sourceGUID == petGUID then
                AddStat("mobsKilled", 1)
                AddMobType(GetMobTypeForGuid(destGUID), 1)

                if destName then
                    LlamaStatsDB.mobs[destName] = (LlamaStatsDB.mobs[destName] or 0) + 1
                end
            end

            return
        end

        if sourceGUID == playerGUID or sourceGUID == petGUID then
            local damage = GetDamageAmountFromCombatLog(args, subEvent)

            if damage and damage > 0 then
                AddStat("damageDealt", damage)
            end
        end

        return
    end
end)
