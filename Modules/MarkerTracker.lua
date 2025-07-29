-- Modules\MarkerTracker.lua
-- Raid marker tracking for mobs

local addonName, addonTable = ...

-- Initialize MarkerTracker module
addonTable.MarkerTracker = {}
local MarkerTracker = addonTable.MarkerTracker

MarkerTracker.markedMobs = {}

local markerNames = {
    [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle",
    [5] = "Moon", [6] = "Square", [7] = "Cross", [8] = "Skull"
}

function MarkerTracker:Initialize()
    local Events = addonTable.Events
    
    Events:RegisterCallback("RAID_TARGET_UPDATE", function()
        self:UpdateMarkedMobs()
        self:NotifyUpdate()
    end)
    
    self:UpdateMarkedMobs()
end

function MarkerTracker:UpdateMarkedMobs()
    self.markedMobs = {}
    
    -- Only group leaders can see marked targets reliably
    local PartyManager = addonTable.PartyManager
    if not PartyManager:IsLeader() then 
        return
    end
    
    for i = 1, 8 do
        local targetName = self:FindMarkedTarget(i)
        if targetName then
            table.insert(self.markedMobs, {
                name = targetName,
                marker = i,
                markerName = markerNames[i]
            })
        end
    end
end

function MarkerTracker:FindMarkedTarget(markerId)
    -- Check player's target
    if UnitExists("target") and GetRaidTargetIndex("target") == markerId then
        return UnitName("target")
    end
    
    -- Check player's focus
    if UnitExists("focus") and GetRaidTargetIndex("focus") == markerId then
        return UnitName("focus")
    end
    
    -- Check party/raid member targets
    if IsInGroup() then
        local numMembers = GetNumGroupMembers()
        local isRaid = IsInRaid()
        
        for i = 1, numMembers do
            local unitId = isRaid and ("raid" .. i .. "target") or ((i == 1) and "target" or ("party" .. (i - 1) .. "target"))
            if UnitExists(unitId) and GetRaidTargetIndex(unitId) == markerId then
                return UnitName(unitId)
            end
        end
    end
    
    return nil
end

function MarkerTracker:GetMarkedMobs()
    return self.markedMobs
end

function MarkerTracker:NotifyUpdate()
    -- Notify main addon of marker changes
    if _G.RPCombat and _G.RPCombat.OnMarkersUpdate then
        _G.RPCombat:OnMarkersUpdate()
    end
end
