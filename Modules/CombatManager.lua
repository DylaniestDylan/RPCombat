-- Combat logic and turn management
local addonName, addonTable = ...

addonTable.CombatManager = {}
local CombatManager = addonTable.CombatManager

CombatManager.isInCombat = false
CombatManager.turnOrder = {}
CombatManager.currentTurn = 1
CombatManager.initiativeRolled = {}

function CombatManager:Initialize()
    local Events = addonTable.Events
    
    Events:RegisterCallback("CHAT_MSG_SYSTEM", function(event, message)
        self:HandleRollMessage(message)
    end)
end

function CombatManager:StartCombat()
    local PartyManager = addonTable.PartyManager
    
    if not PartyManager:IsLeader() then
        print("|cffff0000RPCombat:|r Only the group leader can start combat.")
        return false
    end
    
    self.isInCombat = true
    print("|cff00ff00RPCombat:|r Combat started! Roll for initiative with /roll 20")
    
    self.turnOrder = {}
    self.currentTurn = 1
    self.initiativeRolled = {}
    
    -- Broadcast combat start to party members
    local Communication = addonTable.Communication
    if Communication then
        print("|cff888888RPCombat:|r Broadcasting combat start to party...")
        Communication:BroadcastCombatStart()
    else
        print("|cffff0000RPCombat:|r Communication module not available!")
    end
    
    return true
end

function CombatManager:EndCombat()
    local PartyManager = addonTable.PartyManager
    
    if not PartyManager:IsLeader() then
        print("|cffff0000RPCombat:|r Only the group leader can end combat.")
        return false
    end
    
    self.isInCombat = false
    print("|cff00ff00RPCombat:|r Combat ended.")
    
    -- Broadcast combat end to party members
    local Communication = addonTable.Communication
    if Communication then
        Communication:BroadcastCombatEnd()
    end
    
    return true
end

function CombatManager:RollInitiative()
    if not self.isInCombat then
        print("|cffff0000RPCombat:|r Combat must be started first!")
        return false
    end
    
    local playerName = UnitName("player")
    if self.initiativeRolled[playerName] then
        print("|cffff0000RPCombat:|r You have already rolled initiative! Ask the party leader to allow a reroll if needed.")
        return false
    end
    
    RandomRoll(1, 20)
    return true
end

function CombatManager:NextTurn()
    if not self.isInCombat then return false end
    
    self.currentTurn = self.currentTurn + 1
    if self.currentTurn > #self.turnOrder then
        self.currentTurn = 1
    end
    
    local currentPlayer = self.turnOrder[self.currentTurn]
    if currentPlayer then
        if currentPlayer.name == UnitName("player") then
            print("|cffff9900RPCombat:|r It's your turn!")
            PlaySound(8959)
        else
            print("|cffff9900RPCombat:|r It's " .. currentPlayer.name .. "'s turn.")
        end
    end
    
    -- Broadcast turn advance to party members (only if party lead)
    local PartyManager = addonTable.PartyManager
    if PartyManager:IsLeader() then
        local Communication = addonTable.Communication
        if Communication then
            Communication:BroadcastTurnAdvance(self.currentTurn)
        end
    end
    
    return true
end

function CombatManager:HandleRollMessage(message)
    if not self.isInCombat then return end
    
    local playerName, roll, maxRoll = message:match("(%S+) rolls (%d+) %(1%-(%d+)%)")
    if playerName and roll and maxRoll == "20" then
        self:AddToTurnOrder(playerName, tonumber(roll))
        self.initiativeRolled[playerName] = true
        
        -- Broadcast roll to party members
        if playerName == UnitName("player") then
            local Communication = addonTable.Communication
            if Communication then
                print("|cff888888RPCombat:|r Broadcasting your roll (" .. roll .. ") to party...")
                Communication:BroadcastInitiativeRoll(playerName, tonumber(roll))
            else
                print("|cffff0000RPCombat:|r Communication module not available!")
            end
        end
    end
end

function CombatManager:AddToTurnOrder(playerName, roll)
    for i, combatant in ipairs(self.turnOrder) do
        if combatant.name == playerName then
            table.remove(self.turnOrder, i)
            break
        end
    end
    
    -- Add new entry and sort by roll (highest first)
    table.insert(self.turnOrder, {name = playerName, roll = roll})
    table.sort(self.turnOrder, function(a, b) return a.roll > b.roll end)
    
    print("|cff00ff00RPCombat:|r " .. playerName .. " rolled " .. roll .. " for initiative.")
    
    if _G.RPCombat and _G.RPCombat.OnTurnOrderUpdate then
        _G.RPCombat:OnTurnOrderUpdate()
    end
end

function CombatManager:IsInCombat()
    return self.isInCombat
end

function CombatManager:GetTurnOrder()
    return self.turnOrder
end

function CombatManager:GetCurrentTurn()
    return self.currentTurn
end

function CombatManager:RemovePlayer(playerName)
    -- Only party leader can remove players
    local PartyManager = addonTable.PartyManager
    if not PartyManager:IsLeader() then
        print("|cffff0000RPCombat:|r Only the party leader can remove players.")
        return false
    end
    
    -- Remove from turn order
    for i, combatant in ipairs(self.turnOrder) do
        if combatant.name == playerName then
            table.remove(self.turnOrder, i)
            print("|cffff9900RPCombat:|r " .. playerName .. " has been removed from combat.")
            
            if i <= self.currentTurn then
                self.currentTurn = self.currentTurn - 1
                if self.currentTurn < 1 and #self.turnOrder > 0 then
                    self.currentTurn = #self.turnOrder
                end
            end
            
            -- Broadcast removal to party members
            local Communication = addonTable.Communication
            if Communication then
                Communication:BroadcastPlayerRemove(playerName)
            end
            
            if _G.RPCombat and _G.RPCombat.OnTurnOrderUpdate then
                _G.RPCombat:OnTurnOrderUpdate()
            end
            
            return true
        end
    end
    
    print("|cffff0000RPCombat:|r " .. playerName .. " not found in combat.")
    return false
end

function CombatManager:AllowReroll(playerName)
    -- Only party leader can allow rerolls
    local PartyManager = addonTable.PartyManager
    if not PartyManager:IsLeader() then
        print("|cffff0000RPCombat:|r Only the party leader can allow rerolls.")
        return false
    end
    
    if self.initiativeRolled[playerName] then
        self.initiativeRolled[playerName] = nil
        print("|cffff9900RPCombat:|r " .. playerName .. " can now reroll their initiative.")
        
        -- Broadcast reroll allowance to party members
        local Communication = addonTable.Communication
        if Communication then
            Communication:BroadcastAllowReroll(playerName)
        end
        
        return true
    else
        print("|cffff9900RPCombat:|r " .. playerName .. " hasn't rolled initiative yet.")
        return false
    end
end
