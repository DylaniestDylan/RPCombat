-- UI\InitiativeList.lua
-- Pre-combat initiative list display

local addonName, addonTable = ...

-- Initialize InitiativeList module
addonTable.InitiativeList = {}
local InitiativeList = addonTable.InitiativeList

InitiativeList.frames = {}

function InitiativeList:Initialize()
    -- Nothing specific needed
end

function InitiativeList:Update()
    local CombatManager = addonTable.CombatManager
    
    if CombatManager:IsInCombat() then
        return
    end
    
    self:ClearFrames()
    
    local PartyManager = addonTable.PartyManager
    local MarkerTracker = addonTable.MarkerTracker
    local MainFrame = addonTable.MainFrame
    
    local allCombatants = {}
    
    -- Add party members
    for _, member in ipairs(PartyManager:GetMembers()) do
        table.insert(allCombatants, {
            name = member.name,
            type = "player",
            isPlayer = member.isPlayer,
            unitId = member.unitId
        })
    end
    
    -- Add marked mobs
    for _, mob in ipairs(MarkerTracker:GetMarkedMobs()) do
        table.insert(allCombatants, {
            name = mob.name .. " (" .. mob.markerName .. ")",
            type = "mob",
            marker = mob.marker,
            markerName = mob.markerName
        })
    end
    
    local listContent = MainFrame:GetListContent()
    
    for i, combatant in ipairs(allCombatants) do
        local frame = CreateFrame("Frame", nil, listContent)
        frame:SetSize(240, 30)
        frame:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i-1) * 35)
        
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if combatant.type == "player" then
            bg:SetColorTexture(0.1, 0.3, 0.1, 0.3)
        else
            bg:SetColorTexture(0.3, 0.1, 0.1, 0.3)
        end
        
        local border = frame:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetColorTexture(0.5, 0.5, 0.5, 0.8)
        border:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
        border:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)
        
        local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", frame, "LEFT", 5, 0)
        nameText:SetText(combatant.name)
        
        if combatant.type == "player" then
            if combatant.isPlayer then
                nameText:SetTextColor(0.3, 1, 0.3)
                
                local rollButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
                rollButton:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
                rollButton:SetSize(80, 20)
                rollButton:SetText("Roll Init")
                rollButton:SetScript("OnClick", function() 
                    if _G.RPCombat then _G.RPCombat:RollInitiative() end 
                end)
                
                nameText:SetPoint("LEFT", frame, "LEFT", 5, 0)
                nameText:SetPoint("RIGHT", rollButton, "LEFT", -5, 0)
                nameText:SetJustifyH("LEFT")
            else
                nameText:SetTextColor(0.7, 0.7, 1)
            end
        else
            nameText:SetTextColor(1, 0.7, 0.7)
        end
        
        table.insert(self.frames, frame)
    end
    
    self:UpdatePositions()
end

function InitiativeList:UpdatePositions()
    local MainFrame = addonTable.MainFrame
    local listFrame = MainFrame:GetListFrame()
    local listContent = MainFrame:GetListContent()
    
    if not listFrame or not self.frames then return end
    
    for i, frame in ipairs(self.frames) do
        local yPosition = -(i-1) * 35 + listFrame.scrollOffset
        frame:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, yPosition)
    end
end

function InitiativeList:ClearFrames()
    if self.frames then
        for _, frame in ipairs(self.frames) do
            frame:Hide()
            frame:SetParent(nil)
        end
        self.frames = {}
    end
end
