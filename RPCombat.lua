-- RPCombat: Turn-based RP Combat Tracker
local addonName, addonTable = ...

-- Addon namespace
RPCombat = {}
local RC = RPCombat

-- Default settings
local defaults = {
    combatMode = "roll", -- "roll", "split", "free"
    showCountdown = true,
    countdownTime = 60,
    framePosition = { x = 100, y = -100 },
    frameWidth = 300,
    frameHeight = 400,
    soundEnabled = true,
    minimap = {
        hide = false,
    },
}

-- Variables
RC.isInCombat = false
RC.turnOrder = {}
RC.currentTurn = 1
RC.combatants = {}
RC.isLeader = false

-- LibDBIcon support
local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

-- Data Broker object
local RPCombatLDB = nil
if LDB then
    RPCombatLDB = LDB:NewDataObject("RPCombat", {
        type = "data source",
        text = "RPCombat",
        label = "RP Combat Tracker",
        icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
        OnClick = function(self, button)
            if button == "LeftButton" then
                RC:ToggleMainFrame()
            elseif button == "RightButton" then
                RC:ShowHelp()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("RP Combat Tracker")
            tooltip:AddLine("|cffeda55fLeft-click|r to open combat tracker", 0.2, 1, 0.2, 1)
            tooltip:AddLine("|cffeda55fRight-click|r for help", 0.2, 1, 0.2, 1)
            if RC.isInCombat then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ff00Combat Active|r", 0, 1, 0, 1)
                if #RC.turnOrder > 0 then
                    local current = RC.turnOrder[RC.currentTurn]
                    if current then
                        tooltip:AddLine("Current Turn: " .. current.name, 1, 1, 0, 1)
                    end
                end
            else
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff888888Combat Inactive|r", 0.5, 0.5, 0.5, 1)
            end
        end,
    })
end

-- Create main frame
local mainFrame = CreateFrame("Frame", "RPCombatFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(300, 400)
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

-- Frame title
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY")
mainFrame.title:SetFontObject("GameFontHighlight")
mainFrame.title:SetPoint("LEFT", mainFrame.TitleBg, "LEFT", 5, 0)
mainFrame.title:SetText("RP Combat Tracker")

-- Event frame
local eventFrame = CreateFrame("Frame")

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            RC:Initialize()
            print("|cff00ff00RPCombat|r successfully loaded! Type |cffffffff/rpc|r for commands.")
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        RC:HandleRollMessage(message)
    elseif event == "GROUP_ROSTER_UPDATE" then
        RC:UpdateLeaderStatus()
    end
end

-- Initialize addon
function RC:Initialize()
    -- Load saved variables
    if not RPCombatDB then
        RPCombatDB = CopyTable(defaults)
    end
    
    -- Apply saved frame size
    if RPCombatDB.frameWidth and RPCombatDB.frameHeight then
        mainFrame:SetSize(RPCombatDB.frameWidth, RPCombatDB.frameHeight)
    end
    
    -- Set up minimap icon
    self:SetupMinimapIcon()
    
    -- Set up UI
    self:CreateUI()
    
    -- Update list frame size after UI creation
    self:UpdateListFrameSize()
    
    -- Register events
    eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    -- Update leader status
    self:UpdateLeaderStatus()
end

-- Create the main UI
function RC:CreateUI()
    -- Combat mode selector
    local modeFrame = CreateFrame("Frame", nil, mainFrame)
    modeFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -30)
    modeFrame:SetSize(280, 30)
    
    local modeLabel = modeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("LEFT", modeFrame, "LEFT", 0, 0)
    modeLabel:SetText("Mode:")
    
    -- Mode dropdown (simplified for now)
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
    startButton:SetScript("OnClick", function() RC:StartCombat() end)
    
    local endButton = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
    endButton:SetPoint("LEFT", startButton, "RIGHT", 5, 0)
    endButton:SetSize(80, 22)
    endButton:SetText("End Combat")
    endButton:SetScript("OnClick", function() RC:EndCombat() end)
    
    local nextButton = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
    nextButton:SetPoint("LEFT", endButton, "RIGHT", 5, 0)
    nextButton:SetSize(80, 22)
    nextButton:SetText("Next Turn")
    nextButton:SetScript("OnClick", function() RC:NextTurn() end)
    
    -- Second row of controls
    local controlsFrame2 = CreateFrame("Frame", nil, mainFrame)
    controlsFrame2:SetPoint("TOPLEFT", controlsFrame, "BOTTOMLEFT", 0, -5)
    controlsFrame2:SetSize(280, 30)
    
    local rollButton = CreateFrame("Button", nil, controlsFrame2, "UIPanelButtonTemplate")
    rollButton:SetPoint("LEFT", controlsFrame2, "LEFT", 0, 0)
    rollButton:SetSize(100, 22)
    rollButton:SetText("Roll Initiative")
    rollButton:SetScript("OnClick", function() RC:RollInitiative() end)
    
    -- Turn order list (custom scrolling without ScrollFrame)
    local listFrame = CreateFrame("Frame", nil, mainFrame)
    listFrame:SetPoint("TOPLEFT", controlsFrame2, "BOTTOMLEFT", 0, -10)
    listFrame:SetSize(260, 250)
    listFrame:SetClipsChildren(true) -- This clips content that extends beyond the frame
    
    -- Enable mouse wheel scrolling
    listFrame:EnableMouseWheel(true)
    listFrame.scrollOffset = 0 -- Track scroll position
    listFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollStep = 35 -- Height of one turn frame
        local maxOffset = math.max(0, (#RC.turnOrder * 35) - self:GetHeight())
        
        if delta > 0 then
            -- Scroll up
            self.scrollOffset = math.max(0, self.scrollOffset - scrollStep)
        else
            -- Scroll down
            self.scrollOffset = math.min(maxOffset, self.scrollOffset + scrollStep)
        end
        
        -- Update position of all turn frames
        RC:UpdateTurnFramePositions()
    end)
    
    local listContent = CreateFrame("Frame", nil, listFrame)
    listContent:SetSize(260, 250)
    listContent:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
    
    RC.listContent = listContent
    RC.listFrame = listFrame
    RC.turnFrames = {} -- Store individual turn frames
    
    -- Resize handle
    local resizeHandle = CreateFrame("Frame", nil, mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -5, 5)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnEnter", function(self)
        SetCursor("CAST_CURSOR")
    end)
    resizeHandle:SetScript("OnLeave", function(self)
        ResetCursor()
    end)
    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            mainFrame:StopMovingOrSizing()
            -- Save the new size
            local width, height = mainFrame:GetSize()
            RPCombatDB.frameWidth = width
            RPCombatDB.frameHeight = height
            
            -- Update list frame size to match
            RC:UpdateListFrameSize()
        end
    end)
    
    -- Resize handle texture
    local handleTexture = resizeHandle:CreateTexture(nil, "BACKGROUND")
    handleTexture:SetAllPoints()
    handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    
    RC.resizeHandle = resizeHandle
end

-- Start combat
function RC:StartCombat()
    if not self.isLeader then
        print("|cffff0000RPCombat:|r Only the group leader can start combat.")
        return
    end
    
    self.isInCombat = true
    print("|cff00ff00RPCombat:|r Combat started! Roll for initiative with /roll 20")
    
    -- Clear previous combat data
    self.turnOrder = {}
    self.currentTurn = 1
    
    -- Clear previous UI frames
    self:ClearTurnFrames()
    
    -- Show the frame
    mainFrame:Show()
end

-- Roll initiative function
function RC:RollInitiative()
    if not self.isInCombat then
        print("|cffff0000RPCombat:|r Combat must be started first!")
        return
    end
    
    -- Send /roll 20 command
    RandomRoll(1, 20)
end

-- End combat
function RC:EndCombat()
    if not self.isLeader then
        print("|cffff0000RPCombat:|r Only the group leader can end combat.")
        return
    end
    
    self.isInCombat = false
    print("|cff00ff00RPCombat:|r Combat ended.")
    
    -- Hide the frame
    mainFrame:Hide()
end

-- Next turn
function RC:NextTurn()
    if not self.isInCombat then return end
    
    self.currentTurn = self.currentTurn + 1
    if self.currentTurn > #self.turnOrder then
        self.currentTurn = 1
    end
    
    local currentPlayer = self.turnOrder[self.currentTurn]
    if currentPlayer then
        if currentPlayer.name == UnitName("player") then
            print("|cffff9900RPCombat:|r It's your turn!")
            PlaySound(8959) -- Achievement sound
        else
            print("|cffff9900RPCombat:|r It's " .. currentPlayer.name .. "'s turn.")
        end
    end
    
    -- Update the visual display
    self:UpdateTurnOrderDisplay()
end

-- Handle roll messages
function RC:HandleRollMessage(message)
    if not self.isInCombat then return end
    
    -- Parse roll results (simplified)
    local playerName, roll, maxRoll = message:match("(%S+) rolls (%d+) %(1%-(%d+)%)")
    if playerName and roll and maxRoll == "20" then
        self:AddToTurnOrder(playerName, tonumber(roll))
    end
end

-- Add player to turn order
function RC:AddToTurnOrder(playerName, roll)
    -- Remove if already exists
    for i, combatant in ipairs(self.turnOrder) do
        if combatant.name == playerName then
            table.remove(self.turnOrder, i)
            break
        end
    end
    
    -- Add new entry
    table.insert(self.turnOrder, {name = playerName, roll = roll})
    
    -- Sort by roll (highest first)
    table.sort(self.turnOrder, function(a, b) return a.roll > b.roll end)
    
    print("|cff00ff00RPCombat:|r " .. playerName .. " rolled " .. roll .. " for initiative.")
    
    -- Update UI (placeholder)
    self:UpdateTurnOrderDisplay()
end

-- Update turn order display
function RC:UpdateTurnOrderDisplay()
    -- Clear existing frames
    self:ClearTurnFrames()
    
    -- Create new frames for each combatant
    for i, combatant in ipairs(self.turnOrder) do
        local frame = CreateFrame("Frame", nil, self.listContent)
        frame:SetSize(240, 30)
        frame:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, -(i-1) * 35)
        
        -- Background
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i == self.currentTurn then
            bg:SetColorTexture(0.2, 0.7, 0.2, 0.3) -- Green for current turn
        else
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.3) -- Dark grey
        end
        
        -- Border
        local border = frame:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetColorTexture(0.5, 0.5, 0.5, 0.8)
        border:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
        border:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -1, 1)
        
        -- Turn number
        local turnNum = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        turnNum:SetPoint("LEFT", frame, "LEFT", 5, 0)
        turnNum:SetText(i .. ".")
        turnNum:SetTextColor(1, 1, 1)
        
        -- Player name
        local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", turnNum, "RIGHT", 5, 0)
        nameText:SetText(combatant.name)
        if combatant.name == UnitName("player") then
            nameText:SetTextColor(0.3, 1, 0.3) -- Green for player
        else
            nameText:SetTextColor(1, 1, 1) -- White for others
        end
        
        -- Initiative roll
        local rollText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rollText:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        rollText:SetText("(" .. combatant.roll .. ")")
        rollText:SetTextColor(0.8, 0.8, 0.8)
        
        -- Current turn indicator
        if i == self.currentTurn then
            local indicator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            indicator:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
            indicator:SetText("← CURRENT")
            indicator:SetTextColor(1, 1, 0) -- Yellow
        end
        
        -- Store the frame
        table.insert(self.turnFrames, frame)
    end
    
    -- Update scroll positions
    self:UpdateTurnFramePositions()
    
    -- Also print to chat for backup
    print("|cff888888Turn Order:|r")
    for i, combatant in ipairs(self.turnOrder) do
        local marker = (i == self.currentTurn) and " <-- CURRENT" or ""
        print(i .. ". " .. combatant.name .. " (" .. combatant.roll .. ")" .. marker)
    end
end

-- Update turn frame positions based on scroll offset
function RC:UpdateTurnFramePositions()
    if not self.listFrame or not self.turnFrames then return end
    
    for i, frame in ipairs(self.turnFrames) do
        local yPosition = -(i-1) * 35 + self.listFrame.scrollOffset
        frame:SetPoint("TOPLEFT", self.listContent, "TOPLEFT", 0, yPosition)
    end
end

-- Clear turn frames
function RC:ClearTurnFrames()
    if self.turnFrames then
        for _, frame in ipairs(self.turnFrames) do
            frame:Hide()
            frame:SetParent(nil)
        end
        self.turnFrames = {}
    end
end

-- Update list frame size to match main frame
function RC:UpdateListFrameSize()
    if not self.listFrame then return end
    
    local mainWidth, mainHeight = mainFrame:GetSize()
    
    -- Calculate available space for the list
    -- Account for: top margin (70), controls (65), bottom margin (15)
    local listHeight = mainHeight - 150
    local listWidth = mainWidth - 40
    
    -- Ensure minimum sizes
    listHeight = math.max(listHeight, 100)
    listWidth = math.max(listWidth, 200)
    
    self.listFrame:SetSize(listWidth, listHeight)
    self.listContent:SetSize(listWidth, listHeight)
    
    -- Reset scroll position if content no longer needs scrolling
    if #self.turnOrder * 35 <= listHeight then
        self.listFrame.scrollOffset = 0
    else
        -- Ensure scroll offset doesn't exceed new limits
        local maxOffset = math.max(0, (#self.turnOrder * 35) - listHeight)
        self.listFrame.scrollOffset = math.min(self.listFrame.scrollOffset, maxOffset)
    end
    
    -- Update frame positions
    self:UpdateTurnFramePositions()
end

-- Setup minimap icon
function RC:SetupMinimapIcon()
    if LDBIcon and RPCombatLDB then
        LDBIcon:Register("RPCombat", RPCombatLDB, RPCombatDB.minimap)
    end
end

-- Toggle main frame
function RC:ToggleMainFrame()
    if mainFrame:IsVisible() then
        mainFrame:Hide()
    else
        mainFrame:Show()
    end
end

-- Show help
function RC:ShowHelp()
    print("|cff00ff00RPCombat Commands:|r")
    print("|cffffffff/rpc start|r - Start combat (leader only)")
    print("|cffffffff/rpc end|r - End combat (leader only)")
    print("|cffffffff/rpc next|r - Next turn")
    print("|cffffffff/rpc roll|r - Roll initiative")
    print("|cffffffff/rpc show|r - Show/hide tracker")
end

-- Update leader status
function RC:UpdateLeaderStatus()
    if IsInGroup() then
        self.isLeader = UnitIsGroupLeader("player")
    else
        self.isLeader = true -- Solo player is always leader
    end
end

-- Register events
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")

-- Slash commands
SLASH_RPCOMBAT1 = "/rpcombat"
SLASH_RPCOMBAT2 = "/rpc"
SlashCmdList["RPCOMBAT"] = function(msg)
    local command, arg = msg:match("^(%S*)%s*(.*)")
    command = command:lower()
    
    if command == "" or command == "help" then
        print("|cff00ff00RPCombat Commands:|r")
        print("|cffffffff/rpc start|r - Start combat (leader only)")
        print("|cffffffff/rpc end|r - End combat (leader only)")
        print("|cffffffff/rpc next|r - Next turn")
        print("|cffffffff/rpc roll|r - Roll initiative")
        print("|cffffffff/rpc show|r - Show/hide tracker")
        print("|cffffffff/rpc minimap|r - Toggle minimap icon")
        print("|cff888888Drag the bottom-right corner to resize the window|r")
    elseif command == "start" then
        RC:StartCombat()
    elseif command == "end" then
        RC:EndCombat()
    elseif command == "next" then
        RC:NextTurn()
    elseif command == "roll" then
        RC:RollInitiative()
    elseif command == "show" then
        if mainFrame:IsVisible() then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    elseif command == "minimap" then
        RPCombatDB.minimap.hide = not RPCombatDB.minimap.hide
        if LDBIcon then
            if RPCombatDB.minimap.hide then
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