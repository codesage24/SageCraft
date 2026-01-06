SageCraft = SageCraft or {}
local SC = SageCraft

-- Initialize DB if not present
SageCraftDB = SageCraftDB or { characters = {} }

-- Initialize character data - FIXED VERSION
function SC:InitializeCharacter()
    local charKey = self:GetCharKey()
    
    -- Ensure character entry exists
    if not SageCraftDB.characters[charKey] then
        local _, class = UnitClass("player")
        SageCraftDB.characters[charKey] = {
            class = class,
            professions = {}
        }
    else
        -- IMPORTANT: Ensure professions table exists even for existing characters
        local charData = SageCraftDB.characters[charKey]
        if not charData.professions then
            charData.professions = {}
        end
        -- Ensure class is set for existing characters
        if not charData.class then
            local _, class = UnitClass("player")
            charData.class = class
        end
    end
    
    return SageCraftDB.characters[charKey]
end

-- Enhanced profession scan with multiple fallback methods
function SC:ScanCurrentTradeSkill()
    local profName = GetTradeSkillLine()
    SC:Debug(string.format("Profession name: %s", profName or "nil"))
    
    if not profName then 
        SC:Debug("No profession window open or profession name not found")
        return 
    end

    local charData = self:InitializeCharacter()
    
    -- Double-check that professions table exists (safety check)
    if not charData.professions then
        charData.professions = {}
        SC:Debug("Had to create missing professions table")
    end
    
    local profData = charData.professions[profName]
    if not profData then
        local profID = select(3, GetTradeSkillLine())
        profData = { id = profID, recipes = {} }
        charData.professions[profName] = profData
        SC:Debug(string.format("Created new profession data for %s (ID: %s)", profName, profID or "nil"))
    end

    local added = 0
    local total = 0
    local numRecipes = GetNumTradeSkills()
    SC:Debug(string.format("Found %d trade skill entries", numRecipes))
    
    for i = 1, numRecipes do
        -- Try different return value patterns for different WoW versions
        local recipeName, skillType, numAvailable, isExpanded, serviceType, numSkillUps, spellID = GetTradeSkillInfo(i)
        
        -- Debug: Show all return values
        SC:Debug(string.format("[%d] Raw values: name=%s, type=%s, avail=%s, exp=%s, service=%s, skillups=%s, spellID=%s", 
            i, tostring(recipeName), tostring(skillType), tostring(numAvailable), tostring(isExpanded), tostring(serviceType), tostring(numSkillUps), tostring(spellID)))
        
        -- Skip headers
        if skillType ~= "header" and recipeName then
            total = total + 1
            
            -- Try multiple methods to get a unique identifier
            local recipeID = nil
            
            -- Method 1: Use spellID if available
            if spellID and type(spellID) == "number" and spellID > 0 then
                recipeID = spellID
                SC:Debug(string.format("Method 1 - Using spellID: %d for %s", spellID, recipeName))
            
            -- Method 2: Try to get spell ID by name
            elseif recipeName then
                -- Search for spell by name
                local nameBasedSpellID = nil
                for spellId = 1, 100000 do -- reasonable range
                    local spellName = GetSpellInfo(spellId)
                    if spellName and spellName == recipeName then
                        nameBasedSpellID = spellId
                        break
                    end
                end
                
                if nameBasedSpellID then
                    recipeID = nameBasedSpellID
                    SC:Debug(string.format("Method 2 - Found spellID by name: %d for %s", nameBasedSpellID, recipeName))
                
                -- Method 3: Use recipe name + profession as hash
                else
                    -- Create a pseudo-unique ID from recipe name + profession
                    local hashString = profName .. ":" .. recipeName
                    local hash = 0
                    for j = 1, #hashString do
                        hash = hash + string.byte(hashString, j)
                    end
                    recipeID = hash + 1000000 -- offset to avoid conflicts with real spell IDs
                    SC:Debug(string.format("Method 3 - Using name hash: %d for %s", recipeID, recipeName))
                end
            end
            
            -- Store the recipe with whatever ID we found
            if recipeID and not profData.recipes[recipeID] then
                profData.recipes[recipeID] = {
                    name = recipeName,
                    recipeID = recipeID,
                    spellID = spellID
                }
                added = added + 1
                SC:Debug(string.format("Added new recipe: %s (ID: %d)", recipeName, recipeID))
            elseif recipeID then
                SC:Debug(string.format("Recipe already known: %s (ID: %d)", recipeName, recipeID))
            end
        end
    end

    SC:Debug(string.format("%s: %d new recipes (Total: %d)", profName, added, total))
    
    -- Debug: Show current profession data
    local recipeCount = 0
    for _ in pairs(profData.recipes) do recipeCount = recipeCount + 1 end
    SC:Info(string.format("Total recipes stored for %s: %d", profName, recipeCount))
end

-- Find the correct trade skill frame
function SC:FindTradeSkillFrame()
    -- Try multiple possible frame names
    local possibleFrames = {
        "TradeSkillFrame",
        "CraftFrame", 
        "TradeSkillWindow",
        "ProfessionFrame"
    }
    
    for _, frameName in ipairs(possibleFrames) do
        local frame = _G[frameName]
        if frame then
            SC:Debug(string.format("Found frame: %s", frameName))
            return frame
        end
    end
    
    SC:Debug("No trade skill frame found")
    return nil
end

-- Find the profession title text element
function SC:FindProfessionTitle(parentFrame)
    -- Common title element names in profession frames
    local possibleTitles = {
        "TradeSkillFrameTitleText",
        "CraftFrameTitleText",
        "TradeSkillWindowTitleText", 
        "ProfessionFrameTitleText"
    }
    
    for _, titleName in ipairs(possibleTitles) do
        local titleFrame = _G[titleName]
        if titleFrame and titleFrame:GetParent() == parentFrame then
            SC:Debug(string.format("Found title: %s", titleName))
            return titleFrame
        end
    end
    
    -- Try to find title by searching child frames
    local function findTitleRecursive(frame, depth)
        if depth > 3 then return nil end -- Limit recursion depth
        
        if frame.GetText and frame:GetText() then
            local text = frame:GetText()
            local profName = GetTradeSkillLine()
            if profName and text:find(profName) then
                SC:Debug(string.format("Found title by text search: %s", text))
                return frame
            end
        end
        
        -- Search children
        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do
            local result = findTitleRecursive(child, depth + 1)
            if result then return result end
        end
        
        return nil
    end
    
    local titleFrame = findTitleRecursive(parentFrame, 0)
    if not titleFrame then
        SC:Debug("Could not find profession title, using fallback position")
    end
    
    return titleFrame
end

-- Create scan button as smaller icon next to profession title
function SC:CreateScanButton()
    if SC.scanButton then
        return -- Button already exists
    end

    local parentFrame = self:FindTradeSkillFrame()
    if not parentFrame then
        SC:Debug("Could not find profession window to attach button")
        return
    end

    -- Create the scan button as a smaller icon button to fit title bar
    local button = CreateFrame("Button", "SageCraftScanButton", parentFrame)
    button:SetSize(16, 16) -- Reduced from 20x20 to 16x16 for better title bar fit
    
    -- Create icon texture
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    -- Use a magnifying glass or search icon - this is a common WoW interface icon
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
    
    -- Create a more subtle border for the smaller size
    button.border = button:CreateTexture(nil, "BORDER")
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.border:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    button.border:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    button.border:SetVertexColor(0.6, 0.6, 0.6, 0.6) -- More subtle border
    
    -- Find title and position button to its left
    local titleFrame = self:FindProfessionTitle(parentFrame)
    if titleFrame then
        -- Position closer to title with less spacing for smaller icon
        button:SetPoint("RIGHT", titleFrame, "LEFT", -3, 0)
        SC:Debug("Positioned button relative to title")
    else
        -- Fallback positioning if we can't find the title - adjust for smaller size
        button:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 8, -8)
        SC:Debug("Using fallback button position")
    end
    
    -- Button interactions
    button:SetScript("OnClick", function()
        SC:Debug("Scan button clicked!")
        SC:ScanCurrentTradeSkill()
    end)
    
    -- Hover effects - adjusted for smaller icon
    button:SetScript("OnEnter", function(self)
        -- Slightly less dramatic hover effect for smaller icon
        self.icon:SetVertexColor(1.1, 1.1, 1.1)
        self.border:SetVertexColor(0.9, 0.9, 0.7, 0.8) -- Subtle yellow tint
        
        -- Show tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("SageCraft: Scan Recipes", 1, 1, 1)
        GameTooltip:AddLine("Click to scan all recipes in this profession", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        -- Reset icon colors
        self.icon:SetVertexColor(1, 1, 1)
        self.border:SetVertexColor(0.6, 0.6, 0.6, 0.6)
        
        GameTooltip:Hide()
    end)

    -- Make button clickable
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    SC.scanButton = button
    SC:Debug("Scan icon created successfully!")
end

-- Update scan button visibility and position
function SC:UpdateScanButton()
    if SC.scanButton then
        local parentFrame = self:FindTradeSkillFrame()
        if parentFrame and parentFrame:IsVisible() and GetTradeSkillLine() then
            SC.scanButton:Show()
            
            -- Reposition button relative to title if possible
            local titleFrame = self:FindProfessionTitle(parentFrame)
            if titleFrame then
                SC.scanButton:ClearAllPoints()
                SC.scanButton:SetPoint("RIGHT", titleFrame, "LEFT", -3, 0) -- Adjusted spacing for smaller icon
            end
        else
            SC.scanButton:Hide()
        end
    end
end

-- Event handler for profession window management
local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("TRADE_SKILL_SHOW")
scanFrame:RegisterEvent("TRADE_SKILL_UPDATE") 
scanFrame:RegisterEvent("TRADE_SKILL_CLOSE")
scanFrame:RegisterEvent("CRAFT_SHOW")
scanFrame:RegisterEvent("CRAFT_CLOSE")
scanFrame:RegisterEvent("ADDON_LOADED")
scanFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "SageCraft" or addonName == GetAddOnMetadata("SageCraft", "Title") then
            SC:Info("Loaded AddOn!")
        end
    elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
        SC:Debug(string.format("Event triggered: %s", event))
        
        -- Small delay to ensure window is fully loaded
        C_Timer.After(0.2, function()
            -- Create button if it doesn't exist
            if not SC.scanButton then
                SC:CreateScanButton()
            end
            
            -- Update button visibility and position
            SC:UpdateScanButton()
        end)
        
    elseif event == "TRADE_SKILL_UPDATE" then
        SC:UpdateScanButton()
    elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        SC:UpdateScanButton()
    end
end)
