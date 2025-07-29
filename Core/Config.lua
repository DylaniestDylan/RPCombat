-- Management for RPCombat
local addonName, addonTable = ...

addonTable.Config = {}
local Config = addonTable.Config

Config.defaults = {
    combatMode = "roll",
    showCountdown = true,
    countdownTime = 60,
    framePosition = { x = 100, y = -100 },
    frameWidth = 300,
    frameHeight = 400,
    soundEnabled = true,
    minimap = { hide = false },
}

function Config:Initialize()
    if not RPCombatDB then
        RPCombatDB = CopyTable(self.defaults)
    end
    
    -- Merge defaults with saved data
    for key, value in pairs(self.defaults) do
        if RPCombatDB[key] == nil then
            if type(value) == "table" then
                RPCombatDB[key] = CopyTable(value)
            else
                RPCombatDB[key] = value
            end
        end
    end
end

function Config:Get(key)
    return RPCombatDB[key]
end

function Config:Set(key, value)
    RPCombatDB[key] = value
end
