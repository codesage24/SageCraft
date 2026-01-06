SageCraft = SageCraft or {}
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

-- Return character key for DB
function SC:GetCharKey()
    return UnitName("player") .. "-Ascension"
end

-- Debug helper
function SC:Debug(msg)
    -- Uncomment to see debug messages
    -- DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft:|r " .. msg)
end

-- Return class-colored character name
function SC:GetColoredCharName(char)
    local data = SageCraftDB.characters[char]
    if not data then return char end
    local color = CLASS_COLORS[data.class] or "FFFFFF"
    return string.format("|cff%s%s|r", color, char)
end

-- Helper: get spellID from recipe name (in current character's scanned professions)
local function FindRecipeSpellIDByName(recipeName)
    for i = 1, GetNumTradeSkills() do
        local name, skillType, _, _, _, _, spellID = GetTradeSkillInfo(i)
        if skillType ~= "header" and name:lower() == recipeName:lower() then
            return spellID
        end
    end
    return nil
end

function SageCraft:ShowRecipesWindow()
    if self.RecipesFrame then
        self.RecipesFrame:Show()
        return
    end

    -- Basic frame
    local frame = CreateFrame("Frame", "SageCraftRecipesFrame", UIParent)
    frame:SetSize(450, 500)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
        edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight", 
        edgeSize = 16, 
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
    frame.title:SetText("SageCraft: All Recipes")

    -- Close button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(400, 20)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        frame:UpdateRecipeList(self:GetText())
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        frame:UpdateRecipeList(self:GetText())
    end)

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    frame.content = content
    frame.scrollFrame = scrollFrame
    frame.searchBox = searchBox

    -- Update function
    function frame:UpdateRecipeList(filter)
        filter = filter and filter:lower() or ""
        local yOffset = -5

        -- Clear previous lines
        for _, child in ipairs(self.content:GetChildren()) do
            child:Hide()
            child:SetParent(nil)
        end

        for char, charData in pairs(SageCraftDB.characters or {}) do
            for profName, prof in pairs(charData.professions or {}) do
                for spellID, _ in pairs(prof.recipes or {}) do
                    local spellName = GetSpellInfo(spellID) or ("SpellID " .. spellID)
                    if spellName:lower():find(filter, 1, true) then
                        local line = CreateFrame("Button", nil, self.content)
                        line:SetSize(400, 15)
                        line:SetPoint("TOPLEFT", 5, yOffset)

                        line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        line.text:SetAllPoints()
                        line.text:SetText(string.format("%s (%s) - %s", SageCraft:GetColoredCharName(char), profName, spellName))

                        line:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetSpellByID(spellID)
                            GameTooltip:Show()
                        end)
                        line:SetScript("OnLeave", function(self)
                            GameTooltip:Hide()
                        end)
                        line:SetScript("OnClick", function(self, button)
                            if button == "LeftButton" and IsShiftKeyDown() then
                                ChatEdit_InsertLink(GetSpellLink(spellID))
                            end
                        end)

                        yOffset = yOffset - 15
                    end
                end
            end
        end

        self.content:SetHeight(-yOffset + 5)
    end

    -- Initial population
    frame:UpdateRecipeList()

    self.RecipesFrame = frame
end

-- Slash command
SLASH_SAGECRAFT1 = "/sc"
SlashCmdList["SAGECRAFT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    local command = args[1] and args[1]:lower()

    -- /sc scan
    if command == "scan" then
        SC:ScanAllProfessions()

    -- /sc who <recipe>
    elseif command == "who" and args[2] then
        table.remove(args, 1)
        local recipeName = table.concat(args, " ")
        local spellID = FindRecipeSpellIDByName(recipeName)

        if not spellID then
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft:|r Recipe not found in your scanned professions. Run /sage scan first.")
            return
        end

        local knownChars = {}
        for char, charData in pairs(SageCraftDB.characters) do
            for profName, prof in pairs(charData.professions or {}) do
                if prof.recipes and prof.recipes[spellID] then
                    table.insert(knownChars, string.format("%s (%s)", SC:GetColoredCharName(char), profName))
                end
            end
        end

        if #knownChars > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft:|r Recipe '"..recipeName.."' known by: " .. table.concat(knownChars, ", "))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft:|r Recipe '"..recipeName.."' is unknown to all characters.")
        end

    -- /sc recipes
    elseif command == "recipes" then
        SC:ShowRecipesWindow()

    -- Help text
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffSageCraft commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  /sage scan        - Scan all professions on this character")
        DEFAULT_CHAT_FRAME:AddMessage("  /sage who <name>  - Show which characters know a recipe")
    end
end
