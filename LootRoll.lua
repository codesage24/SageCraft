SageCraft = SageCraft or {}
local SC = SageCraft

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    if not parent or not parent.rollID then return end

    local link = GetLootRollItemLink(parent.rollID)
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID = GetItemInfo(link)
    if not itemName then
        itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID = GetItemInfo(itemID)
    end

    local spellName, spellID = GetItemSpell(link)
    if not spellID then
        spellName, spellID = GetItemSpell(itemID)
    end

    local knownChars = SC:CharactersWhoKnowRecipe(spellID, spellName, itemName)

    if #knownChars > 0 then
        tooltip:AddLine("|cff00ff00Known by:|r " .. table.concat(knownChars, ", "))
    elseif isRecipeItem then
        tooltip:AddLine("|cffff0000Unknown to all characters|r")
    else
        return
    end


    tooltip:Show()
end)
