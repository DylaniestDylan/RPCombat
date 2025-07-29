-- UI\TurnOrder.lua
-- Combat turn order display

local addonName, addonTable = ...

-- Initialize TurnOrder module
addonTable.TurnOrder = {}
local TurnOrder = addonTable.TurnOrder

TurnOrder.frames = {}

function TurnOrder:Initialize()
end

function TurnOrder:Update()
    local CombatManager = addonTable.CombatManager
    
    if not CombatManager:IsInCombat() then
        return
    end
    
    self:ClearFrames()
    
    local MainFrame = addonTable.MainFrame
    local turnOrder = CombatManager:GetTurnOrder()
    local currentTurn = CombatManager:GetCurrentTurn()
    local listContent = MainFrame:GetListContent()
    
    for i, combatant in ipairs(turnOrder) do
        local frame = CreateFrame("Frame", nil, listContent)
        frame:SetSize(240, 30)
        frame:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i-1) * 35)
        
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i == currentTurn then
            bg:SetColorTexture(0.2, 0.7, 0.2, 0.3)
        else
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
        end
        
        local border = frame:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetColorTexture(0.5, 0.5, 0.5, 0.8)
        border:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
        border:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)
        
        local turnNum = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        turnNum:SetPoint("LEFT", frame, "LEFT", 5, 0)
        turnNum:SetText(i .. ".")
        turnNum:SetTextColor(1, 1, 1)
        
        local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", turnNum, "RIGHT", 5, 0)
        nameText:SetText(combatant.name)
        
        -- Check if player is online
        local isOnline = UnitIsConnected(combatant.name) ~= false
        
        if not isOnline then
            -- Gray out offline players
            nameText:SetTextColor(0.5, 0.5, 0.5)
            turnNum:SetTextColor(0.5, 0.5, 0.5)
        elseif combatant.name == UnitName("player") then
            nameText:SetTextColor(0.3, 1, 0.3)
        else
            nameText:SetTextColor(1, 1, 1)
        end
        
        local rollText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rollText:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        rollText:SetText("(" .. combatant.roll .. ")")
        
        if not isOnline then
            rollText:SetTextColor(0.5, 0.5, 0.5) -- Gray for offline
        else
            rollText:SetTextColor(0.8, 0.8, 0.8)
        end
        
        if i == currentTurn then
            local indicator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            indicator:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
            indicator:SetText("← CURRENT")
            indicator:SetTextColor(1, 1, 0)
        end
        
        -- Add right-click context menu for party leaders
        frame:EnableMouse(true)
        frame:RegisterForClicks("RightButtonUp")
        frame:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local PartyManager = addonTable.PartyManager
                if PartyManager:IsPartyLeader() then
                    TurnOrder:ShowContextMenu(combatant.name, self)
                end
            end
        end)
        
        table.insert(self.frames, frame)
    end
    
    self:UpdatePositions()
    
    -- Print turn order to chat
    print("|cff888888Turn Order:|r")
    for i, combatant in ipairs(turnOrder) do
        local marker = (i == currentTurn) and " <-- CURRENT" or ""
        print(i .. ". " .. combatant.name .. " (" .. combatant.roll .. ")" .. marker)
    end
end

function TurnOrder:UpdatePositions()
    local MainFrame = addonTable.MainFrame
    local listFrame = MainFrame:GetListFrame()
    local listContent = MainFrame:GetListContent()
    
    if not listFrame or not self.frames then return end
    
    for i, frame in ipairs(self.frames) do
        local yPosition = -(i-1) * 35 + listFrame.scrollOffset
        frame:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, yPosition)
    end
end

function TurnOrder:ClearFrames()
    if self.frames then
        for _, frame in ipairs(self.frames) do
            frame:Hide()
            frame:SetParent(nil)
        end
        self.frames = {}
    end
end

function TurnOrder:ShowContextMenu(playerName, anchorFrame)
    -- Create a simple dropdown-style menu
    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetSize(120, 60)
    menu:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 5, 0)
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    menu:SetBackdropColor(0, 0, 0, 0.8)
    menu:SetFrameStrata("TOOLTIP")
    
    -- Remove button
    local removeBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    removeBtn:SetPoint("TOP", menu, "TOP", 0, -10)
    removeBtn:SetSize(100, 20)
    removeBtn:SetText("Remove")
    removeBtn:SetScript("OnClick", function()
        local CombatManager = addonTable.CombatManager
        CombatManager:RemovePlayer(playerName)
        menu:Hide()
    end)
    
    -- Allow reroll button
    local rerollBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    rerollBtn:SetPoint("TOP", removeBtn, "BOTTOM", 0, -5)
    rerollBtn:SetSize(100, 20)
    rerollBtn:SetText("Allow Reroll")
    rerollBtn:SetScript("OnClick", function()
        local CombatManager = addonTable.CombatManager
        CombatManager:AllowReroll(playerName)
        menu:Hide()
    end)
    
    -- Auto-hide when clicking elsewhere
    menu:SetScript("OnShow", function()
        C_Timer.After(0.1, function()
            menu:SetScript("OnUpdate", function(self)
                if not self:IsMouseOver() then
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end)
    end)
    
    menu:Show()
end
