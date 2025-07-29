-- Party member management
local addonName, addonTable = ...

-- Initialize module
addonTable.PartyManager = {}
local PartyManager = addonTable.PartyManager

PartyManager.members = {}
PartyManager.isLeader = false

function PartyManager:Initialize()
    local Events = addonTable.Events
    
    Events:RegisterCallback("GROUP_ROSTER_UPDATE", function()
        self:UpdateMembers()
        self:UpdateLeaderStatus()
        self:NotifyUpdate()
    end)
    
    self:UpdateMembers()
    self:UpdateLeaderStatus()
end

function PartyManager:UpdateMembers()
    self.members = {}
    
    -- Always include the player
    table.insert(self.members, {
        name = UnitName("player"),
        unitId = "player",
        isPlayer = true
    })
    
    -- Add party/raid members
    if IsInGroup() then
        local numMembers = GetNumGroupMembers()
        local isRaid = IsInRaid()
        
        for i = 1, numMembers do
            local unitId = isRaid and ("raid" .. i) or ("party" .. (i - 1))
            if i > 1 or isRaid then
                local name = UnitName(unitId)
                if name and name ~= UnitName("player") then
                    table.insert(self.members, {
                        name = name,
                        unitId = unitId,
                        isPlayer = false
                    })
                end
            end
        end
    end
end

function PartyManager:UpdateLeaderStatus()
    if IsInGroup() then
        self.isLeader = UnitIsGroupLeader("player")
    else
        self.isLeader = true -- Solo player is always leader
    end
end

function PartyManager:GetMembers()
    return self.members
end

function PartyManager:IsLeader()
    return self.isLeader
end

function PartyManager:NotifyUpdate()
    if _G.RPCombat and _G.RPCombat.OnPartyUpdate then
        _G.RPCombat:OnPartyUpdate()
    end
end
