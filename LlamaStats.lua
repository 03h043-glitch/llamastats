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
local rows = {}
local fontStrings = {}

local goldMilestones = { 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000 }
local itemMilestones = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
local qualityMilestones = { 1, 5, 10, 25, 50, 100, 250 }
local damageMilestones = { 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000 }

local defaults = {
    lifetime = {
        questsCompleted = 0,
        mobsKilled = 0,
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
    },
    session = {
        questsCompleted = 0,
        mobsKilled = 0,
        moneyLooted = 0,
        vendorValueLooted = 0,
        itemsLooted = 0,
        greenItems = 0,
        blueItems = 0,
        purpleItems = 0,
        damageDealt = 0,
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
    },
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
    copper = copper or 0

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
    copper = copper or 0
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    if g > 0 then return g .. "g " .. s .. "s " .. c .. "c" end
    if s > 0 then return s .. "s " .. c .. "c" end
    return c .. "c"
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
        questsCompleted = 0,
        mobsKilled = 0,
        moneyLooted = 0,
        vendorValueLooted = 0,
        itemsLooted = 0,
        greenItems = 0,
        blueItems = 0,
        purpleItems = 0,
        damageDealt = 0,
    }

    LlamaStatsDB.milestones = LlamaStatsDB.milestones or {}
    LlamaStatsDB.milestones.session = {}
end

local function ApplyWindowOpacity()
    if not frame or not frame.bg then return end
    local opacity = LlamaStatsDB.window.opacity or 0.85
    frame.bg:SetColorTexture(0, 0, 0, opacity)
end

local function UpdateUI()
    if not rows.questsCompleted then return end

    local l = LlamaStatsDB.lifetime
    local s = LlamaStatsDB.session

    rows.questsCompleted:SetText(l.questsCompleted or 0)
    rows.mobsKilled:SetText(l.mobsKilled or 0)
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

    rows.sessionQuests:SetText(s.questsCompleted or 0)
    rows.sessionKills:SetText(s.mobsKilled or 0)
    rows.sessionDamage:SetText(FormatNumber(s.damageDealt or 0))
    rows.sessionMoney:SetText(MoneyText(s.moneyLooted or 0))
    rows.sessionVendorValue:SetText(MoneyText(s.vendorValueLooted or 0))
    rows.sessionItems:SetText(s.itemsLooted or 0)
    rows.sessionGreens:SetText(GREEN .. (s.greenItems or 0) .. RESET)
    rows.sessionBlues:SetText(BLUE .. (s.blueItems or 0) .. RESET)
    rows.sessionPurples:SetText(PURPLE .. (s.purpleItems or 0) .. RESET)
end

local function CheckMilestones(scope, key, value, thresholds, label, formatter, r, g, b)
    LlamaStatsDB.milestones = LlamaStatsDB.milestones or {}
    LlamaStatsDB.milestones[scope] = LlamaStatsDB.milestones[scope] or {}
    LlamaStatsDB.milestones[scope][key] = LlamaStatsDB.milestones[scope][key] or {}

    for _, threshold in ipairs(thresholds) do
        if value >= threshold and not LlamaStatsDB.milestones[scope][key][threshold] then
            LlamaStatsDB.milestones[scope][key][threshold] = true
            Popup("LlamaStats: " .. scope .. " " .. label .. " reached " .. ((formatter and formatter(threshold)) or threshold) .. "!", r, g, b)
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
        UpdateUI()
        Print("All stats reset.")
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

local function CreateRow(key, label, y, colour)
    local left = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    left:SetPoint("TOPLEFT", 14, y)
    left:SetText((colour or WHITE) .. label .. RESET)

    local right = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    right:SetPoint("TOPRIGHT", -14, y)
    right:SetText("0")

    table.insert(fontStrings, left)
    table.insert(fontStrings, right)

    rows[key] = right
end

local function CreateSection(text, y)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 12, y)
    fs:SetText(YELLOW .. text .. RESET)

    table.insert(fontStrings, fs)
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
    frame:SetSize(270, 500)
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

    CreateSection("Lifetime", -38)
    CreateRow("questsCompleted", "Quests:", -62)
    CreateRow("mobsKilled", "Kills:", -80)
    CreateRow("damageDealt", "Damage:", -98)
    CreateRow("moneyLooted", "Looted coin:", -116)
    CreateRow("moneyQuestRewards", "Quest gold:", -134)
    CreateRow("vendorValueLooted", "Vendor value:", -152)
    CreateRow("deaths", "Deaths:", -170)
    CreateRow("itemsLooted", "Items:", -188)
    CreateRow("greenItems", "Greens:", -206, GREEN)
    CreateRow("blueItems", "Blues:", -224, BLUE)
    CreateRow("purpleItems", "Purples:", -242, PURPLE)
    CreateRow("highestVendorItemName", "Best item:", -260)
    CreateRow("highestVendorItemValue", "Best value:", -278)

    CreateSection("Session", -310)
    CreateRow("sessionQuests", "Quests:", -334)
    CreateRow("sessionKills", "Kills:", -352)
    CreateRow("sessionDamage", "Damage:", -370)
    CreateRow("sessionMoney", "Looted coin:", -388)
    CreateRow("sessionVendorValue", "Vendor value:", -406)
    CreateRow("sessionItems", "Items:", -424)
    CreateRow("sessionGreens", "Greens:", -442, GREEN)
    CreateRow("sessionBlues", "Blues:", -460, BLUE)
    CreateRow("sessionPurples", "Purples:", -478, PURPLE)

    ApplyTextSize()
    ApplyWindowOpacity()
    ApplyWindowScale()
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
            Print("/llama, /llama opacity 0-100, /llama scale 50-200, /llama text 8-24")
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
            ResetSession()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        CopyDefaults(defaults, LlamaStatsDB)
        CreateMainWindow()
        CreateMinimapButton()
        UpdateUI()
        Print("Ready. Use /llama")
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

        local playerGUID = UnitGUID("player")
        local petGUID = UnitGUID("pet")

        if subEvent == "PARTY_KILL" then
            local destName = args[9]

            if sourceGUID == playerGUID or sourceGUID == petGUID then
                AddStat("mobsKilled", 1)

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