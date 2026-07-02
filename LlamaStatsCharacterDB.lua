local resetAllWrapped = false

local function GetCharacterKey()
    local name, realm

    if UnitFullName then
        name, realm = UnitFullName("player")
    end

    if (not name or name == "") and UnitName then
        name = UnitName("player")
    end

    if (not realm or realm == "") and GetRealmName then
        realm = GetRealmName()
    end

    if not name or name == "" or not realm or realm == "" then
        return nil
    end

    return realm .. " - " .. name
end

local function LooksLikeCharacterStats(db)
    return type(db) == "table"
        and (db.lifetime ~= nil
        or db.session ~= nil
        or db.milestones ~= nil
        or db.achievements ~= nil
        or db.window ~= nil
        or db.minimap ~= nil)
        and db.characters == nil
end

local function EnsureAccountDB()
    LlamaStatsAccountDB = LlamaStatsAccountDB or {}
    LlamaStatsAccountDB.characters = LlamaStatsAccountDB.characters or {}
    return LlamaStatsAccountDB
end

function LlamaStats_UseCharacterDB()
    local key = GetCharacterKey()
    if not key then
        return false
    end

    local accountDB = EnsureAccountDB()

    if not accountDB.characters[key] then
        if LooksLikeCharacterStats(LlamaStatsDB) then
            accountDB.characters[key] = LlamaStatsDB
        else
            accountDB.characters[key] = {}
        end
    end

    LlamaStatsDB = accountDB.characters[key]
    accountDB.currentCharacter = key
    return true
end

local function InstallResetAllWrapper()
    if resetAllWrapped or not SlashCmdList or not SlashCmdList.LLAMASTATS then
        return false
    end

    resetAllWrapped = true
    local original = SlashCmdList.LLAMASTATS
    SlashCmdList.LLAMASTATS = function(msg)
        original(msg)

        if string.lower(msg or "") == "reset all" then
            local key = GetCharacterKey()
            if key then
                local accountDB = EnsureAccountDB()
                accountDB.characters[key] = LlamaStatsDB or {}
                accountDB.currentCharacter = key
            end
        end
    end

    return true
end

local function TryInstallResetAllWrapper()
    if InstallResetAllWrapper() then
        return
    end

    local waiter = CreateFrame("Frame")
    local elapsed = 0
    waiter:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed < 0.1 then return end
        elapsed = 0

        if InstallResetAllWrapper() then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "LlamaStats" then
        return
    end

    LlamaStats_UseCharacterDB()

    if event == "PLAYER_LOGIN" then
        TryInstallResetAllWrapper()
    end
end)
