SageCraft = SageCraft or {}
local SC = SageCraft

-- WoW class color codes
SC.CLASS_COLORS = {
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

function SC:OnLogin()
    -- Initialize DB for this character if needed
    local charKey = self:GetCharKey()
    SageCraftDB.characters[charKey] = SageCraftDB.characters[charKey] or {}
    local charData = SageCraftDB.characters[charKey]

    -- Save class info for coloring
    charData.class = charData.class or select(2, UnitClass("player"))

    SC:Debug("Loaded for " .. UnitName("player"))
end

-- Return character key for DB
function SC:GetCharKey()
    return UnitName("player") .. "-Ascension"
end

-- Debug Logger
function SC:Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft (Debug):|r " .. msg)
end

-- Information Logger
function SC:Info(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SageCraft:|r " .. msg)
end

-- Error Logger
function SC:Error(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000SageCraft (ERROR):|r " .. msg)
end

-- Return class-colored character name (trimmed of -Ascension suffix)
function SC:GetColoredCharName(char)
    local data = SageCraftDB.characters[char]
    if not data then return char end

    -- Trim "-Ascension" suffix from character name for display
    local displayName = char
    if char:sub(-10) == "-Ascension" then
        displayName = char:sub(1, -11)  -- Remove "-Ascension" (10 chars + 1 for the dash)
    end

    local color = SC.CLASS_COLORS[data.class] or "FFFFFF"
    return string.format("|cff%s%s|r", color, displayName)
end

function SC:NormalizeName(name)
    if not name then
        return nil
    end
    name = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("^recipe:%s*", "")
    name = name:gsub("^plans:%s*", "")
    name = name:gsub("^pattern:%s*", "")
    name = name:gsub("^design:%s*", "")
    name = name:gsub("^formula:%s*", "")
    name = name:gsub("^schematic:%s*", "")
    name = name:gsub("^manual:%s*", "")
    return name
end

function SC:CharactersWhoKnowRecipe(spellID, spellName, itemName)
    local known = {}

    local searchSpell = SC:NormalizeName(spellName)
    local searchItem = SC:NormalizeName(itemName)

    for char, charData in pairs(SageCraftDB.characters) do
        for _, prof in pairs(charData.professions or {}) do
            if prof.recipes then
                if spellID and prof.recipes[spellID] then
                    table.insert(known, SC:GetColoredCharName(char))
                    break
                end

                if searchSpell or searchItem then
                    for _, recipeData in pairs(prof.recipes) do
                        if recipeData.name then
                            local recipeNorm = SC:NormalizeName(recipeData.name)
                            if recipeNorm then
                                if (searchSpell and (recipeNorm:find(searchSpell, 1, true) or searchSpell:find(recipeNorm, 1, true)))
                                    or (searchItem and (recipeNorm:find(searchItem, 1, true) or searchItem:find(recipeNorm, 1, true))) then
                                    table.insert(known, SC:GetColoredCharName(char))
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return known
end

function SC:ClearCurrentCharRecipes()
    local charKey = self:GetCharKey()
    local charData = SageCraftDB.characters[charKey]
    if not charData or not charData.professions then
        SC:Info("No stored recipes for this character.")
        return
    end

    local clearedRecipes = 0
    local clearedProfs = 0

    for _, prof in pairs(charData.professions) do
        clearedProfs = clearedProfs + 1
        if prof.recipes then
            for _ in pairs(prof.recipes) do
                clearedRecipes = clearedRecipes + 1
            end
        end
    end

    if clearedProfs == 0 then
        SC:Info("No stored recipes for this character.")
        return
    end

    charData.professions = {}
    SC:Info(string.format("Cleared %d recipe%s across %d profession%s for %s.", clearedRecipes, clearedRecipes == 1 and "" or "s", clearedProfs, clearedProfs == 1 and "" or "s", SC:GetColoredCharName(charKey)))

    if self.RecipesFrame then
        self.RecipesFrame:UpdateRecipeList(self.RecipesFrame.searchBox:GetText())
    end
end

-- Helper: Find spellID by recipe name (current character)
local function FindRecipeSpellIDByName(recipeName)
    for i = 1, GetNumTradeSkills() do
        local name, skillType, _, _, _, _, spellID = GetTradeSkillInfo(i)
        if skillType ~= "header" and name:lower() == recipeName:lower() then
            return spellID
        end
    end
    return nil
end

-- /sc who <recipe>
function SC:WhoRecipe(recipeName)
    local spellID = FindRecipeSpellIDByName(recipeName)
    if not spellID then
        SC:Debug("Recipe not found.")
        return
    end

    local knownChars = {}
    for char, charData in pairs(SageCraftDB.characters or {}) do
        for profName, prof in pairs(charData.professions or {}) do
            if prof.recipes and prof.recipes[spellID] then
                table.insert(knownChars, string.format("%s (%s)", SC:GetColoredCharName(char), profName))
            end
        end
    end

    if #knownChars > 0 then
        SC:Debug("Recipe '"..recipeName.."' known by: " .. table.concat(knownChars, ", "))
    else
        SC:Debug("Recipe '"..recipeName.."' unknown to all characters.")
    end
end

-- /sc recipes
function SC:ShowRecipesWindow()
    if self.RecipesFrame then
        self.RecipesFrame:UpdateRecipeList(self.RecipesFrame.searchBox:GetText())
        self.RecipesFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "SageCraftRecipesFrame", UIParent)
    frame:SetSize(450, 530)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.selectedChar = "ALL"
    frame.selectedProf = "ALL"

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
    frame.title:SetText("SageCraft: All Recipes")

    -- Close button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- Character filter dropdown
    local charDrop = CreateFrame("Frame", "SageCraftRecipesCharDrop", frame, "UIDropDownMenuTemplate")
    charDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -42)

    local function BuildCharList()
        local chars = { { text = "All Characters", value = "ALL" } }
        for char in pairs(SageCraftDB.characters or {}) do
            table.insert(chars, { text = SC:GetColoredCharName(char), value = char }) -- value is the key
        end
        table.sort(chars, function(a, b) return a.text < b.text end)
        return chars
    end

    local function BuildProfList()
        local profs = { { text = "All Professions", value = "ALL" } }
        local seen = {}
        if frame.selectedChar == "ALL" then
            for _, charData in pairs(SageCraftDB.characters or {}) do
                for profName in pairs(charData.professions or {}) do
                    if not seen[profName] then
                        seen[profName] = true
                        table.insert(profs, { text = profName, value = profName })
                    end
                end
            end
        else
            local charData = SageCraftDB.characters and SageCraftDB.characters[frame.selectedChar]
            for profName in pairs(charData and charData.professions or {}) do
                if not seen[profName] then
                    seen[profName] = true
                    table.insert(profs, { text = profName, value = profName })
                end
            end
        end

        table.sort(profs, function(a, b)
            if a.value == "ALL" then return true end
            if b.value == "ALL" then return false end
            return a.text < b.text
        end)

        return profs
    end

    local profDrop = CreateFrame("Frame", "SageCraftRecipesProfDrop", frame, "UIDropDownMenuTemplate")
    profDrop:SetPoint("LEFT", charDrop, "RIGHT", 14, 0)
    profDrop:SetPoint("TOP", charDrop, "TOP", 0, 0)

    local function OnProfSelected(_, value)
        frame.selectedProf = value
        UIDropDownMenu_SetSelectedValue(profDrop, value)
        UIDropDownMenu_SetText(profDrop, value == "ALL" and "All Professions" or value)
        frame:UpdateRecipeList(frame.searchBox:GetText())
    end

    local function OnCharSelected(_, value)
        frame.selectedChar = value
        UIDropDownMenu_SetSelectedValue(charDrop, value)
        UIDropDownMenu_SetText(charDrop, value == "ALL" and "All Characters" or SC:GetColoredCharName(value))
        frame.selectedProf = "ALL"
        UIDropDownMenu_SetSelectedValue(profDrop, "ALL")
        UIDropDownMenu_SetText(profDrop, "All Professions")
        frame:UpdateRecipeList(frame.searchBox:GetText())
    end

    UIDropDownMenu_Initialize(charDrop, function(self, level)
        for _, entry in ipairs(BuildCharList()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.value = entry.value
            info.arg1 = entry.value      -- pass key to callback
            info.func = OnCharSelected
            info.checked = (entry.value == frame.selectedChar)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(charDrop, 150)
    UIDropDownMenu_SetSelectedValue(charDrop, "ALL")
    UIDropDownMenu_SetText(charDrop, "All Characters")

    -- Profession filter dropdown
    UIDropDownMenu_Initialize(profDrop, function(self, level)
        for _, entry in ipairs(BuildProfList()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.value = entry.value
            info.arg1 = entry.value
            info.func = OnProfSelected
            info.checked = (entry.value == frame.selectedProf)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(profDrop, 150)
    UIDropDownMenu_SetSelectedValue(profDrop, "ALL")
    UIDropDownMenu_SetText(profDrop, "All Professions")

    -- Search box (now below the dropdowns)
    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(380, 20)
    searchBox:SetPoint("TOPLEFT", charDrop, "BOTTOMLEFT", 20, -14)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        frame:UpdateRecipeList(self:GetText())
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        frame:UpdateRecipeList(self:GetText())
    end)

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -2, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    frame.content = content
    frame.scrollFrame = scrollFrame
    frame.searchBox = searchBox

    -- Update recipe list
    function frame:UpdateRecipeList(filter)
        filter = filter and filter:lower() or ""
        local yOffset = -5

        for _, child in ipairs({ self.content:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        for char, charData in pairs(SageCraftDB.characters or {}) do
            if self.selectedChar == "ALL" or self.selectedChar == char then
                for profName, prof in pairs(charData.professions or {}) do
                    if self.selectedProf == "ALL" or self.selectedProf == profName then
                        for spellID, _ in pairs(prof.recipes or {}) do
                            local spellName = GetSpellInfo(spellID) or ("SpellID " .. spellID)
                            if spellName:lower():find(filter, 1, true) then
                                local line = CreateFrame("Button", nil, self.content)
                                line:SetSize(400, 15)
                                line:SetPoint("TOPLEFT", 5, yOffset)
                                line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                line.text:SetAllPoints()
                                line.text:SetJustifyH("LEFT")
                                line.text:SetJustifyV("MIDDLE")
                                line.text:SetWordWrap(false)
                                line.text:SetText(string.format("%s (%s) - %s", SC:GetColoredCharName(char), profName, spellName))

                                line:SetScript("OnEnter", function(selfBtn)
                                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                                    GameTooltip:SetSpellByID(spellID)
                                    GameTooltip:Show()
                                end)
                                line:SetScript("OnLeave", function()
                                    GameTooltip:Hide()
                                end)
                                line:SetScript("OnClick", function(_, button)
                                    if button == "LeftButton" and IsShiftKeyDown() then
                                        ChatEdit_InsertLink(GetSpellLink(spellID))
                                    end
                                end)

                                yOffset = yOffset - 15
                            end
                        end
                    end
                end
            end
        end

        self.content:SetHeight(-yOffset + 5)
    end

    frame:UpdateRecipeList()
    self.RecipesFrame = frame
end

-- Slash command
SLASH_SAGECRAFT1 = "/sc"
SlashCmdList["SAGECRAFT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    local command = args[1] and args[1]:lower()

    -- /sc who <recipe>
    if command == "who" and args[2] then
        table.remove(args, 1)
        SC:WhoRecipe(table.concat(args, " "))

    -- /sc recipes
    elseif command == "recipes" then
        SC:ShowRecipesWindow()

    -- /sc clear
    elseif command == "clear" then
        SC:ClearCurrentCharRecipes()

    -- Help text
    else
        SC:Info("|cff88ccffSageCraft commands:|r")
        SC:Info("  /sc who <name>    - Who knows a recipe")
        SC:Info("  /sc recipes       - Show all known recipes window")
        SC:Info("  /sc clear         - Clear all stored recipes for this character")
    end
end
