local SC = SageCraft

function SC:OnLogin()
    local charKey = self:GetCharKey()

    SageCraftDB.characters[charKey] =
        SageCraftDB.characters[charKey] or {
            class = select(2, UnitClass("player")),
            professions = {}
        }
end

function SC:ScanAllProfessions()
    local numSkills = GetNumSkillLines()
    local foundAny = false

    -- List of primary professions in WoW 3.3.5a
    local PROFESSION_NAMES = {
        "Alchemy", "Blacksmithing", "Enchanting", "Engineering",
        "Leatherworking", "Tailoring", "Jewelcrafting",
        "Cooking", "First Aid", "Inscription"
    }

    for i = 1, numSkills do
        local name, _, _, _, _, _, skillID = GetSkillLineInfo(i)
        if name then
            for _, prof in ipairs(PROFESSION_NAMES) do
                if name == prof then
                    CastSpellByName(name)
                    self:ScanCurrentTradeSkill()
                    foundAny = true
                    break
                end
            end
        end
    end

    if not foundAny then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft:|r No professions found.")
    end
end

function SC:ScanCurrentTradeSkill()
    local profName = GetTradeSkillLine()
    if not profName then return end

    local charKey = self:GetCharKey()
    local charData = SageCraftDB.characters[charKey]
    charData.professions = charData.professions or {}

    -- Initialize profession if missing
    local profData = charData.professions[profName]
    if not profData then
        profData = {
            id = select(3, GetTradeSkillLine()),
            recipes = {}
        }
        charData.professions[profName] = profData
    end

    local added = 0
    local numRecipes = GetNumTradeSkills()

    for i = 1, numRecipes do
        local _, skillType = GetTradeSkillInfo(i)
        if skillType ~= "header" then
            local spellID = select(7, GetTradeSkillInfo(i))
            if spellID and not profData.recipes[spellID] then
                profData.recipes[spellID] = true
                added = added + 1
            end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        string.format(
            "|cff88ccffSageCraft:|r %s — %d new recipe%s",
            profName,
            added,
            added == 1 and "" or "s"
        )
    )
end
