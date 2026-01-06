local SC = SageCraft
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
-- frame:RegisterEvent("TRADE_SKILL_SHOW")
-- frame:RegisterEvent("LEARNED_SPELL_IN_TAB")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SC:OnLogin()
    --elseif event == "TRADE_SKILL_SHOW" then
        --SC:ScanCurrentTradeSkill()
    --elseif event == "LEARNED_SPELL_IN_TAB" then
        --SC:ScanCurrentTradeSkill()
    end
end)
