SageCraft = SageCraft or {}
local SC = SageCraft

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...)
    if SC.OnLogin then
        SC:OnLogin()
    else
        SC:Error("|cff88ccffSageCraft:|r OnLogin not defined yet!")
    end
end)
