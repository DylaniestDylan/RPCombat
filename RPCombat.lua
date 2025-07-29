-- RPCombat.lua
-- Main initialization file for RP Combat Tracker

local addonName, addonTable = ...

-- Main addon object
RPCombat = {}
local RC = RPCombat

-- Initialize when addon loads
local function OnAddonLoaded(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        RC:Initialize()
        print("|cff00ff00RPCombat|r successfully loaded! Type |cffffffff/rpc|r for commands.")
        
        -- Unregister this event since we only need it once
        self:UnregisterEvent("ADDON_LOADED")
    end
end

-- Register for addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnAddonLoaded)

function RC:Initialize()
    -- Initialize modules in proper order
    addonTable.Config:Initialize()
    addonTable.Events:Initialize()
    addonTable.PartyManager:Initialize()
    addonTable.MarkerTracker:Initialize()
    addonTable.CombatManager:Initialize()
    addonTable.MainFrame:Initialize()
    addonTable.InitiativeList:Initialize()
    addonTable.TurnOrder:Initialize()
    
    self:UpdateDisplay()
end

function RC:StartCombat()
    if addonTable.CombatManager:StartCombat() then
        addonTable.TurnOrder:ClearFrames()
        addonTable.InitiativeList:ClearFrames()
        addonTable.MainFrame:Show()
    end
end

function RC:EndCombat()
    if addonTable.CombatManager:EndCombat() then
        addonTable.TurnOrder:ClearFrames()
        self:UpdateDisplay()
        addonTable.MainFrame:Hide()
    end
end

function RC:RollInitiative()
    addonTable.CombatManager:RollInitiative()
end

function RC:NextTurn()
    if addonTable.CombatManager:NextTurn() then
        addonTable.TurnOrder:Update()
    end
end

function RC:ShowHelp()
    print("|cff00ff00RPCombat Commands:|r")
    print("|cffffffff/rpc start|r - Start combat (leader only)")
    print("|cffffffff/rpc end|r - End combat (leader only)")
    print("|cffffffff/rpc next|r - Next turn")
    print("|cffffffff/rpc roll|r - Roll initiative")
    print("|cffffffff/rpc show|r - Show/hide tracker")
    print("|cffffffff/rpc minimap|r - Toggle minimap icon")
    print("|cff888888Drag the bottom-right corner to resize the window|r")
end

function RC:UpdateDisplay()
    if addonTable.CombatManager:IsInCombat() then
        addonTable.TurnOrder:Update()
    else
        addonTable.InitiativeList:Update()
    end
end

function RC:UpdateDisplayPositions()
    if addonTable.CombatManager:IsInCombat() then
        addonTable.TurnOrder:UpdatePositions()
    else
        addonTable.InitiativeList:UpdatePositions()
    end
end

function RC:UpdateListFrameSize()
    addonTable.MainFrame:UpdateListFrameSize()
end

function RC:OnPartyUpdate()
    if not addonTable.CombatManager:IsInCombat() then
        addonTable.InitiativeList:Update()
    end
end

function RC:OnMarkersUpdate()
    if not addonTable.CombatManager:IsInCombat() then
        addonTable.InitiativeList:Update()
    end
end

function RC:OnTurnOrderUpdate()
    if addonTable.CombatManager:IsInCombat() then
        addonTable.TurnOrder:Update()
    end
end

function RC:OnFrameShow()
    addonTable.PartyManager:UpdateMembers()
    addonTable.MarkerTracker:UpdateMarkedMobs()
    self:UpdateDisplay()
end

-- Slash commands
local function HandleSlashCommand(msg)
    local command, arg = msg:match("^(%S*)%s*(.*)")
    command = command:lower()
    
    if command == "" or command == "help" then
        RC:ShowHelp()
    elseif command == "start" then
        RC:StartCombat()
    elseif command == "end" then
        RC:EndCombat()
    elseif command == "next" then
        RC:NextTurn()
    elseif command == "roll" then
        RC:RollInitiative()
    elseif command == "show" then
        addonTable.MainFrame:Toggle()
    elseif command == "minimap" then
        local minimapConfig = addonTable.Config:Get("minimap")
        minimapConfig.hide = not minimapConfig.hide
        addonTable.Config:Set("minimap", minimapConfig)
        
        local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
        if LDBIcon then
            if minimapConfig.hide then
                LDBIcon:Hide("RPCombat")
                print("|cff00ff00RPCombat:|r Minimap icon hidden.")
            else
                LDBIcon:Show("RPCombat")
                print("|cff00ff00RPCombat:|r Minimap icon shown.")
            end
        end
    else
        print("|cffff0000RPCombat:|r Unknown command. Type /rpc help for commands.")
    end
end

SLASH_RPCOMBAT1 = "/rpcombat"
SLASH_RPCOMBAT2 = "/rpc"
SlashCmdList["RPCOMBAT"] = HandleSlashCommand