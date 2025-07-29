-- UI\MainFrame.lua
-- Main UI window and controls

local addonName, addonTable = ...

-- Initialize MainFrame module
addonTable.MainFrame = {}
local MainFrame = addonTable.MainFrame

MainFrame.frame = nil
MainFrame.listFrame = nil
MainFrame.listContent = nil

-- LibDBIcon support
local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
local RPCombatLDB = nil

function MainFrame:Initialize()
    self:CreateMainFrame()
    self:SetupMinimapIcon()
end

function MainFrame:CreateMainFrame()
    local Config = addonTable.Config
    
    local mainFrame = CreateFrame("Frame", "RPCombatFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(Config:Get("frameWidth"), Config:Get("frameHeight"))
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetMinResize(250, 300)
    mainFrame:SetMaxResize(500, 800)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()
    
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY")
    mainFrame.title:SetFontObject("GameFontHighlight")
    mainFrame.title:SetPoint("LEFT", mainFrame.TitleBg, "LEFT", 5, 0)
    mainFrame.title:SetText("RP Combat Tracker")
    
    self.frame = mainFrame
    
    self:CreateControls()
    self:CreateListFrame()
    self:CreateResizeHandle()
end

function MainFrame:CreateControls()
    local mainFrame = self.frame
    
    -- Combat mode selector
    local modeFrame = CreateFrame("Frame", nil, mainFrame)
    modeFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -30)
    modeFrame:SetSize(280, 30)
    
    local modeLabel = modeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("LEFT", modeFrame, "LEFT", 0, 0)
    modeLabel:SetText("Mode:")
    
    local modeButton = CreateFrame("Button", nil, modeFrame, "UIPanelButtonTemplate")
    modeButton:SetPoint("LEFT", modeLabel, "RIGHT", 10, 0)
    modeButton:SetSize(100, 22)
    modeButton:SetText("Initiative")
    
    -- Combat controls
    local controlsFrame = CreateFrame("Frame", nil, mainFrame)
    controlsFrame:SetPoint("TOPLEFT", modeFrame, "BOTTOMLEFT", 0, -10)
    controlsFrame:SetSize(280, 30)
    
    local startButton = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
    startButton:SetPoint("LEFT", controlsFrame, "LEFT", 0, 0)
    startButton:SetSize(80, 22)
    startButton:SetText("Start Combat")
    startButton:SetScript("OnClick", function() 
        if _G.RPCombat then _G.RPCombat:StartCombat() end 
    end)
    
    local endButton = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
    endButton:SetPoint("LEFT", startButton, "RIGHT", 5, 0)
    endButton:SetSize(80, 22)
    endButton:SetText("End Combat")
    endButton:SetScript("OnClick", function() 
        if _G.RPCombat then _G.RPCombat:EndCombat() end 
    end)
    
    local nextButton = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
    nextButton:SetPoint("LEFT", endButton, "RIGHT", 5, 0)
    nextButton:SetSize(80, 22)
    nextButton:SetText("Next Turn")
    nextButton:SetScript("OnClick", function() 
        if _G.RPCombat then _G.RPCombat:NextTurn() end 
    end)
    
    -- Second row
    local controlsFrame2 = CreateFrame("Frame", nil, mainFrame)
    controlsFrame2:SetPoint("TOPLEFT", controlsFrame, "BOTTOMLEFT", 0, -5)
    controlsFrame2:SetSize(280, 30)
    
    local rollButton = CreateFrame("Button", nil, controlsFrame2, "UIPanelButtonTemplate")
    rollButton:SetPoint("LEFT", controlsFrame2, "LEFT", 0, 0)
    rollButton:SetSize(100, 22)
    rollButton:SetText("Roll Initiative")
    rollButton:SetScript("OnClick", function() 
        if _G.RPCombat then _G.RPCombat:RollInitiative() end 
    end)
    
    -- Third row - Leader controls
    local controlsFrame3 = CreateFrame("Frame", nil, mainFrame)
    controlsFrame3:SetPoint("TOPLEFT", controlsFrame2, "BOTTOMLEFT", 0, -5)
    controlsFrame3:SetSize(280, 30)
    
    -- Add text input for player name
    local playerNameInput = CreateFrame("EditBox", nil, controlsFrame3, "InputBoxTemplate")
    playerNameInput:SetPoint("LEFT", controlsFrame3, "LEFT", 0, 0)
    playerNameInput:SetSize(100, 20)
    playerNameInput:SetAutoFocus(false)
    playerNameInput:SetText("Player Name")
    playerNameInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    playerNameInput:SetScript("OnEditFocusGained", function(self) 
        if self:GetText() == "Player Name" then
            self:SetText("")
        end
    end)
    playerNameInput:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText("Player Name")
        end
    end)
    
    local removeButton = CreateFrame("Button", nil, controlsFrame3, "UIPanelButtonTemplate")
    removeButton:SetPoint("LEFT", playerNameInput, "RIGHT", 5, 0)
    removeButton:SetSize(60, 22)
    removeButton:SetText("Remove")
    removeButton:SetScript("OnClick", function() 
        local playerName = playerNameInput:GetText()
        if playerName and playerName ~= "Player Name" and playerName ~= "" then
            if _G.RPCombat and _G.RPCombat.Modules.CombatManager then
                _G.RPCombat.Modules.CombatManager:RemovePlayer(playerName)
            end
        end
    end)
    
    local rerollButton = CreateFrame("Button", nil, controlsFrame3, "UIPanelButtonTemplate")
    rerollButton:SetPoint("LEFT", removeButton, "RIGHT", 5, 0)
    rerollButton:SetSize(80, 22)
    rerollButton:SetText("Allow Reroll")
    rerollButton:SetScript("OnClick", function() 
        local playerName = playerNameInput:GetText()
        if playerName and playerName ~= "Player Name" and playerName ~= "" then
            if _G.RPCombat and _G.RPCombat.Modules.CombatManager then
                _G.RPCombat.Modules.CombatManager:AllowReroll(playerName)
            end
        end
    end)
    
    -- Store reference for later use
    self.playerNameInput = playerNameInput
end

function MainFrame:CreateListFrame()
    local mainFrame = self.frame
    
    local listFrame = CreateFrame("Frame", nil, mainFrame)
    listFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -170) -- Moved down to make room for third row
    listFrame:SetSize(260, 190) -- Slightly smaller to fit
    listFrame:SetClipsChildren(true)
    
    listFrame:EnableMouseWheel(true)
    listFrame.scrollOffset = 0
    listFrame:SetScript("OnMouseWheel", function(self, delta)
        local CombatManager = addonTable.CombatManager
        local PartyManager = addonTable.PartyManager
        local MarkerTracker = addonTable.MarkerTracker
        
        local scrollStep = 35
        local frameCount = CombatManager:IsInCombat() and #CombatManager:GetTurnOrder() or 
                          (#PartyManager:GetMembers() + #MarkerTracker:GetMarkedMobs())
        local maxOffset = math.max(0, (frameCount * 35) - self:GetHeight())
        
        if delta > 0 then
            self.scrollOffset = math.max(0, self.scrollOffset - scrollStep)
        else
            self.scrollOffset = math.min(maxOffset, self.scrollOffset + scrollStep)
        end
        
        if _G.RPCombat then _G.RPCombat:UpdateDisplayPositions() end
    end)
    
    local listContent = CreateFrame("Frame", nil, listFrame)
    listContent:SetSize(260, 220)
    listContent:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
    
    self.listFrame = listFrame
    self.listContent = listContent
end

function MainFrame:CreateResizeHandle()
    local mainFrame = self.frame
    local Config = addonTable.Config
    
    local resizeHandle = CreateFrame("Frame", nil, mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -5, 5)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnEnter", function(self) SetCursor("CAST_CURSOR") end)
    resizeHandle:SetScript("OnLeave", function(self) ResetCursor() end)
    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            mainFrame:StopMovingOrSizing()
            local width, height = mainFrame:GetSize()
            Config:Set("frameWidth", width)
            Config:Set("frameHeight", height)
            if _G.RPCombat then _G.RPCombat:UpdateListFrameSize() end
        end
    end)
    
    local handleTexture = resizeHandle:CreateTexture(nil, "BACKGROUND")
    handleTexture:SetAllPoints()
    handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
end

function MainFrame:SetupMinimapIcon()
    local Config = addonTable.Config
    local CombatManager = addonTable.CombatManager
    
    if LDB then
        RPCombatLDB = LDB:NewDataObject("RPCombat", {
            type = "data source",
            text = "RPCombat",
            label = "RP Combat Tracker",
            icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
            OnClick = function(self, button)
                if button == "LeftButton" then
                    MainFrame:Toggle()
                elseif button == "RightButton" then
                    if _G.RPCombat then _G.RPCombat:ShowHelp() end
                end
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                tooltip:AddLine("RP Combat Tracker")
                tooltip:AddLine("|cffeda55fLeft-click|r to open combat tracker", 0.2, 1, 0.2, 1)
                tooltip:AddLine("|cffeda55fRight-click|r for help", 0.2, 1, 0.2, 1)
                
                if CombatManager:IsInCombat() then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("|cff00ff00Combat Active|r", 0, 1, 0, 1)
                    local turnOrder = CombatManager:GetTurnOrder()
                    local currentTurn = CombatManager:GetCurrentTurn()
                    if #turnOrder > 0 and turnOrder[currentTurn] then
                        tooltip:AddLine("Current Turn: " .. turnOrder[currentTurn].name, 1, 1, 0, 1)
                    end
                else
                    tooltip:AddLine(" ")
                    tooltip:AddLine("|cff888888Combat Inactive|r", 0.5, 0.5, 0.5, 1)
                end
            end,
        })
    end
    
    if LDBIcon and RPCombatLDB then
        LDBIcon:Register("RPCombat", RPCombatLDB, Config:Get("minimap"))
    end
end

function MainFrame:Toggle()
    if self.frame:IsVisible() then
        self.frame:Hide()
    else
        if _G.RPCombat then _G.RPCombat:OnFrameShow() end
        self.frame:Show()
    end
end

function MainFrame:Show()
    self.frame:Show()
end

function MainFrame:Hide()
    self.frame:Hide()
end

function MainFrame:IsVisible()
    return self.frame:IsVisible()
end

function MainFrame:GetFrame()
    return self.frame
end

function MainFrame:GetListFrame()
    return self.listFrame
end

function MainFrame:GetListContent()
    return self.listContent
end

function MainFrame:UpdateListFrameSize()
    if not self.listFrame then return end
    
    local mainWidth, mainHeight = self.frame:GetSize()
    local listHeight = mainHeight - 180  -- Account for controls and margins
    local listWidth = mainWidth - 40
    
    listHeight = math.max(listHeight, 100)
    listWidth = math.max(listWidth, 200)
    
    self.listFrame:SetSize(listWidth, listHeight)
    self.listContent:SetSize(listWidth, listHeight)
    
    if _G.RPCombat then _G.RPCombat:UpdateDisplayPositions() end
end
