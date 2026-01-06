local SC = SageCraft

-- WoW class color codes
local CLASS_COLORS = {
    ["DRUID"] = "FF7D0A",
    ["HUNTER"] = "ABD473",
    ["MAGE"] = "69CCF0",
    ["PALADIN"] = "F58CBA",
    ["PRIEST"] = "FFFFFF",
    ["ROGUE"] = "FFF569",
    ["SHAMAN"] = "0070DE",
    ["WARLOCK"] = "9482C9",
    ["WARRIOR"] = "C79C6E",
}

-- Return class-colored character name
local function GetColoredCharName(char)
    local data = SageCraftDB.characters[char]
    if not data then return char end
    local color = CLASS_COLORS[data.class] or "FFFFFF"
    return string.format("|cff%s%s|r", color, char)
end

-- Return table of all characters who know this recipe
local function CharactersWhoKnowRecipe(spellID)
    local known = {}
    for char, charData in pairs(SageCraftDB.characters) do
        for _, prof in pairs(charData.professions or {}) do
            if prof.recipes and prof.recipes[spellID] then
                table.insert(known, GetColoredCharName(char))
                break
            end
        end
    end
    return known
end

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local _, link = self:GetItem()
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local spellID = GetItemSpell(itemID)
    if not spellID then return end

    local knownChars = CharactersWhoKnowRecipe(spellID)

    if #knownChars > 0 then
        self:AddLine("|cff00ff00Known by:|r " .. table.concat(knownChars, ", "))
    else
        self:AddLine("|cffff0000Unknown to all characters|r")
    end

    self:Show()
end)
