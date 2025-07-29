-- Addon communication system for syncing combat state

local addonName, addonTable = ...

-- Initialize Communication module with safety limits
addonTable.Communication = {}
local Communication = addonTable.Communication

-- Safety configuration
local ADDON_PREFIX = "RPCombat"
local MAX_MESSAGE_LENGTH = 200  -- WoW limit is 255, leave buffer
local MESSAGE_THROTTLE_TIME = 0.1  -- Minimum time between messages
local MAX_CLIENTS = 40  -- Reasonable party/raid limit
local CLIENT_TIMEOUT = 300  -- 5 minutes timeout

-- Simple messages
local MESSAGE_TYPES = {
    VERSION = "VERSION",
    COMBAT_START = "START", 
    COMBAT_END = "END",
    INITIATIVE_ROLL = "ROLL",
    TURN_ADVANCE = "TURN",
    PLAYER_REMOVE = "REMOVE",
    ALLOW_REROLL = "REROLL"
}

-- State tracking with safety limits
Communication.connectedClients = {}
Communication.lastMessageTime = 0
Communication.messageQueue = {}
Communication.isInitialized = false

function Communication:Initialize()
    -- Prevent double initialization
    if self.isInitialized then
        return
    end
    
    -- Validate addon prefix
    if not ADDON_PREFIX or ADDON_PREFIX == "" then
        print("|cffff0000RPCombat:|r Communication initialization failed - invalid prefix")
        return
    end
    
    -- Register addon communication with error handling
    local success = pcall(function()
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    end)
    
    if not success then
        print("|cffff0000RPCombat:|r Failed to register communication")
        return
    end
    
    local Events = addonTable.Events
    if not Events then
        print("|cffff0000RPCombat:|r Events module not available")
        return
    end
    
    -- Register for addon messages with error wrapper
    Events:RegisterCallback("CHAT_MSG_ADDON", function(event, prefix, message, channel, sender)
        self:SafeHandleMessage(prefix, message, channel, sender)
    end)
    
    -- Register for group changes to clean up client list
    Events:RegisterCallback("GROUP_ROSTER_UPDATE", function()
        self:CleanupClients()
    end)
    
    -- Start periodic cleanup timer (every 60 seconds)
    C_Timer.NewTicker(60, function()
        self:PeriodicCleanup()
    end)
    
    -- Send initial presence with delay to avoid startup spam
    C_Timer.After(3, function()
        self:SendVersionCheck()
    end)
    
    self.isInitialized = true
    print("|cff00ff00RPCombat:|r Communication system initialized safely")
end

-- Safe message handling
function Communication:SafeHandleMessage(prefix, message, channel, sender)
    -- Validate prefix
    if prefix ~= ADDON_PREFIX then return end
    
    -- Ignore our own messages
    if sender == UnitName("player") then return end
    
    -- Validate sender is in our group
    if not self:IsValidGroupMember(sender) then 
        return 
    end
    
    -- Validate message length and content
    if not message or type(message) ~= "string" or #message == 0 or #message > MAX_MESSAGE_LENGTH then
        return
    end
    
    -- Rate limiting check
    local currentTime = GetServerTime()
    if self.lastMessageTime and (currentTime - self.lastMessageTime) < MESSAGE_THROTTLE_TIME then
        return -- Too frequent, ignore
    end
    
    -- Parse message with error protection
    local success, messageType, data = pcall(function()
        local colonPos = message:find(":")
        if colonPos then
            return message:sub(1, colonPos - 1), message:sub(colonPos + 1)
        else
            return message, ""
        end
    end)
    
    if not success or not messageType then
        return
    end
    
    -- Debug: Show received messages (except version checks)
    if messageType ~= MESSAGE_TYPES.VERSION then
        print("|cff888888RPCombat:|r Received " .. messageType .. " from " .. sender)
    end
    
    -- Handle message type with error protection
    pcall(function()
        if messageType == MESSAGE_TYPES.VERSION then
            self:HandleVersionCheck(sender, data)
        elseif messageType == MESSAGE_TYPES.COMBAT_START then
            self:HandleCombatStart(sender, data)
        elseif messageType == MESSAGE_TYPES.COMBAT_END then
            self:HandleCombatEnd(sender, data)
        elseif messageType == MESSAGE_TYPES.INITIATIVE_ROLL then
            self:HandleInitiativeRoll(sender, data)
        elseif messageType == MESSAGE_TYPES.TURN_ADVANCE then
            self:HandleTurnAdvance(sender, data)
        elseif messageType == MESSAGE_TYPES.PLAYER_REMOVE then
            self:HandlePlayerRemove(sender, data)
        elseif messageType == MESSAGE_TYPES.ALLOW_REROLL then
            self:HandleAllowReroll(sender, data)
        end
    end)
    
    self.lastMessageTime = currentTime
end

-- Validate that sender is actually in group
function Communication:IsValidGroupMember(senderName)
    if not IsInGroup() then
        return senderName == UnitName("player")
    end
    
    local numMembers = GetNumGroupMembers()
    local isRaid = IsInRaid()
    
    for i = 1, numMembers do
        local unitId
        if isRaid then
            unitId = "raid" .. i
        else
            unitId = (i == 1) and "player" or ("party" .. (i - 1))
        end
        
        local memberName = UnitName(unitId)
        if memberName == senderName then
            return true
        end
    end
    
    return false
end

-- Message sending with throttling and validation
function Communication:SendMessage(messageType, data)
    -- Validate inputs
    if not messageType or type(messageType) ~= "string" or messageType == "" then
        print("|cffff0000RPCombat:|r Invalid message type")
        return false
    end
    
    -- Validate we're in a group
    if not IsInGroup() then
        print("|cffff9900RPCombat:|r Not in a group, cannot send message")
        return false
    end
    
    -- Construct message safely
    local message = messageType
    if data and data ~= "" then
        message = messageType .. ":" .. tostring(data)
    end
    
    -- Validate message length
    if #message > MAX_MESSAGE_LENGTH then
        print("|cffff0000RPCombat:|r Message too long (" .. #message .. " chars)")
        return false
    end
    
    -- Throttle check
    local currentTime = GetServerTime()
    if self.lastMessageTime and (currentTime - self.lastMessageTime) < MESSAGE_THROTTLE_TIME then
        -- Queue message for later
        table.insert(self.messageQueue, {messageType, data, currentTime + MESSAGE_THROTTLE_TIME})
        return true
    end
    
    -- Send message with error protection
    local success = pcall(function()
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)
    end)
    
    if success then
        self.lastMessageTime = currentTime
        -- Debug: Show sent messages (except version checks)
        if messageType ~= MESSAGE_TYPES.VERSION then
            print("|cff888888RPCombat:|r Sent " .. messageType .. " to group")
        end
        return true
    else
        print("|cffff0000RPCombat:|r Failed to send message")
        return false
    end
end

-- Process queued messages safely
function Communication:ProcessMessageQueue()
    if #self.messageQueue == 0 then return end
    
    local currentTime = GetServerTime()
    local i = 1
    
    while i <= #self.messageQueue do
        local queuedMessage = self.messageQueue[i]
        if not queuedMessage or #queuedMessage < 3 then
            table.remove(self.messageQueue, i)
            return
        end
        
        local messageType, data, sendTime = queuedMessage[1], queuedMessage[2], queuedMessage[3]
        
        if currentTime >= sendTime then
            if self:SendMessage(messageType, data) then
                table.remove(self.messageQueue, i)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

-- Cleanup disconnected clients and limit memory usage
function Communication:CleanupClients()
    if not IsInGroup() then
        -- Not in group, clear all clients
        self.connectedClients = {}
        return
    end
    
    local currentMembers = {}
    local numMembers = GetNumGroupMembers()
    local isRaid = IsInRaid()
    
    -- Build current member list
    for i = 1, numMembers do
        local unitId
        if isRaid then
            unitId = "raid" .. i
        else
            unitId = (i == 1) and "player" or ("party" .. (i - 1))
        end
        
        local memberName = UnitName(unitId)
        if memberName and memberName ~= UnitName("player") then
            currentMembers[memberName] = true
        end
    end
    
    -- Remove clients not in current group
    for clientName, _ in pairs(self.connectedClients) do
        if not currentMembers[clientName] then
            self.connectedClients[clientName] = nil
        end
    end
    
    -- Enforce client limit
    local clientCount = 0
    for _ in pairs(self.connectedClients) do
        clientCount = clientCount + 1
    end
    
    if clientCount > MAX_CLIENTS then
        self.connectedClients = {}
    end
end

-- Periodic cleanup to prevent memory leaks
function Communication:PeriodicCleanup()
    -- Process any queued messages
    self:ProcessMessageQueue()
    
    -- Clean up old client data
    local currentTime = GetServerTime()
    for clientName, clientData in pairs(self.connectedClients) do
        if clientData.lastSeen and (currentTime - clientData.lastSeen) > CLIENT_TIMEOUT then
            self.connectedClients[clientName] = nil
        end
    end
    
    -- Clear oversized queue
    if #self.messageQueue > 10 then
        self.messageQueue = {}
    end
end

-- Safe version tracking (no auto-response to prevent loops)
function Communication:HandleVersionCheck(sender, data)
    if not sender or sender == "" then return end
    
    local version = data or "unknown"
    if #version > 20 then version = "unknown" end -- Validate version string
    
    self.connectedClients[sender] = {
        version = version,
        lastSeen = GetServerTime()
    }
    
    print("|cff00ff00RPCombat:|r " .. sender .. " has RPCombat v" .. version)
end

-- Safe combat start handler
function Communication:HandleCombatStart(sender, data)
    -- Only accept from valid group leaders
    if not UnitIsGroupLeader(sender) then
        return
    end
    
    local CombatManager = addonTable.CombatManager
    if CombatManager and not CombatManager:IsInCombat() then
        -- Actually start combat locally
        CombatManager.isInCombat = true
        CombatManager.turnOrder = {}
        CombatManager.currentTurn = 1
        CombatManager.initiativeRolled = {}
        
        print("|cff00ff00RPCombat:|r " .. sender .. " started combat! Roll for initiative with /roll 20")
        
        -- Show UI and update display
        local MainFrame = addonTable.MainFrame
        if MainFrame then
            MainFrame:Show()
        end
        
        if _G.RPCombat then
            _G.RPCombat:UpdateDisplay()
        end
    end
end

-- Safe combat end handler
function Communication:HandleCombatEnd(sender, data)
    -- Only accept from valid group leaders
    if not UnitIsGroupLeader(sender) then
        return
    end
    
    local CombatManager = addonTable.CombatManager
    if CombatManager and CombatManager:IsInCombat() then
        -- Actually end combat locally
        CombatManager.isInCombat = false
        
        print("|cff00ff00RPCombat:|r " .. sender .. " ended combat.")
        
        if _G.RPCombat then
            _G.RPCombat:UpdateDisplay()
        end
    end
end

-- Safe initiative roll handler
function Communication:HandleInitiativeRoll(sender, data)
    if not data or data == "" then return end
    
    local roll = tonumber(data)
    if not roll or roll < 1 or roll > 20 then return end
    
    local CombatManager = addonTable.CombatManager
    if CombatManager and CombatManager:IsInCombat() then
        -- Add the roll to our local turn order
        CombatManager:AddToTurnOrder(sender, roll)
        CombatManager.initiativeRolled[sender] = true
        
        -- Update display
        if _G.RPCombat and _G.RPCombat.OnTurnOrderUpdate then
            _G.RPCombat:OnTurnOrderUpdate()
        end
    end
end

-- Safe turn advance handler
function Communication:HandleTurnAdvance(sender, data)
    -- Only accept from valid group leaders
    if not UnitIsGroupLeader(sender) then
        return
    end
    
    local CombatManager = addonTable.CombatManager
    if CombatManager and CombatManager:IsInCombat() then
        local turn = tonumber(data)
        if turn and turn > 0 then
            CombatManager.currentTurn = turn
            if _G.RPCombat and _G.RPCombat.OnTurnOrderUpdate then
                _G.RPCombat:OnTurnOrderUpdate()
            end
        end
    end
end

-- Safe player remove handler
function Communication:HandlePlayerRemove(sender, data)
    -- Only accept from valid group leaders
    if not UnitIsGroupLeader(sender) then
        return
    end
    
    if not data or data == "" or #data > 50 then return end
    
    local CombatManager = addonTable.CombatManager
    if CombatManager and CombatManager:IsInCombat() then
        print("|cffff9900RPCombat:|r " .. sender .. " removed " .. data .. " from combat.")
    end
end

-- Safe allow reroll handler
function Communication:HandleAllowReroll(sender, data)
    -- Only accept from valid group leaders
    if not UnitIsGroupLeader(sender) then
        return
    end
    
    if not data or data == "" or #data > 50 then return end
    
    local playerName = UnitName("player")
    if data == playerName then
        print("|cff00ff00RPCombat:|r " .. sender .. " allowed you to reroll initiative!")
        -- Clear local reroll lock
        local CombatManager = addonTable.CombatManager
        if CombatManager then
            CombatManager.initiativeRolled[playerName] = nil
        end
    end
end

-- Safe version announcement
function Communication:SendVersionCheck()
    local version = GetAddOnMetadata(addonName, "Version") or "0.1.0"
    self:SendMessage(MESSAGE_TYPES.VERSION, version)
end

-- Safe broadcast functions with simple data
function Communication:BroadcastCombatStart()
    self:SendMessage(MESSAGE_TYPES.COMBAT_START, "")
end

function Communication:BroadcastCombatEnd()
    self:SendMessage(MESSAGE_TYPES.COMBAT_END, "")
end

function Communication:BroadcastInitiativeRoll(playerName, roll)
    self:SendMessage(MESSAGE_TYPES.INITIATIVE_ROLL, tostring(roll))
end

function Communication:BroadcastTurnAdvance(currentTurn)
    self:SendMessage(MESSAGE_TYPES.TURN_ADVANCE, tostring(currentTurn))
end

function Communication:BroadcastPlayerRemove(playerName)
    self:SendMessage(MESSAGE_TYPES.PLAYER_REMOVE, playerName)
end

function Communication:BroadcastAllowReroll(playerName)
    self:SendMessage(MESSAGE_TYPES.ALLOW_REROLL, playerName)
end

-- Safe getter functions
function Communication:GetConnectedClients()
    if not self.connectedClients then
        self.connectedClients = {}
    end
    return self.connectedClients
end

function Communication:IsClientConnected(playerName)
    return self.connectedClients[playerName] ~= nil
end
