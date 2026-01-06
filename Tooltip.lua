SageCraft = SageCraft or {}
local SC = SageCraft

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local _, link = self:GetItem()
    if not link then
        return
    end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then
        return
    end

    local itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID = GetItemInfo(link)
    if not itemName then
        itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID = GetItemInfo(itemID)
    end

    local spellName, spellID = GetItemSpell(link)
    if not spellID then
        spellName, spellID = GetItemSpell(itemID)
    end

    if not spellID and not itemName and not spellName then
        return
    end

    local recipeClassID = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or LE_ITEM_CLASS_RECIPE
    local isRecipeItem = false
    if recipeClassID and itemClassID == recipeClassID then
        isRecipeItem = true
    elseif itemType == "Recipe" or itemSubType == "Recipe" then
        isRecipeItem = true
    end

    local knownChars = SC:CharactersWhoKnowRecipe(spellID, spellName, itemName)

    if #knownChars > 0 then
        self:AddLine("|cff00ff00Known by:|r " .. table.concat(knownChars, ", "))
    elseif isRecipeItem then
        self:AddLine("|cffff0000Unknown to all characters|r")
    else
        return
    end

    self:Show()
end)
