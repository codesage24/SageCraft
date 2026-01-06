local SC = SageCraft

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    if not parent or not parent.rollID then return end

    local link = GetLootRollItemLink(parent.rollID)
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local spellID = GetItemSpell(itemID)
    if not spellID then return end

    for char, charData in pairs(SageCraftDB.characters) do
        for _, prof in pairs(charData.professions or {}) do
            if prof.recipes and prof.recipes[spellID] then
                tooltip:AddLine("|cff00ff00Known by:|r " .. char)
                tooltip:Show()
                return
            end
        end
    end

    tooltip:AddLine("|cffff0000Unknown to all characters|r")
    tooltip:Show()
end)
