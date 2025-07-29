-- Core\Events.lua
-- Event management system for RPCombat

local addonName, addonTable = ...

-- Initialize Events module
addonTable.Events = {}
local Events = addonTable.Events

local eventFrame = CreateFrame("Frame")
local eventCallbacks = {}

function Events:RegisterCallback(event, callback)
    if not eventCallbacks[event] then
        eventCallbacks[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventCallbacks[event], callback)
end

function Events:Initialize()
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if eventCallbacks[event] then
            for _, callback in ipairs(eventCallbacks[event]) do
                callback(event, ...)
            end
        end
    end)
end
