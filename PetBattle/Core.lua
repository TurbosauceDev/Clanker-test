-- PetBattle: Pokemon Showdown-style battles using WoW companion pets
PB = {}
PB.VERSION = "0.1.0"
PB.PREFIX = "PetBattle"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "PetBattle" then
            PetBattleDB = PetBattleDB or {}
            C_ChatInfo.RegisterAddonMessagePrefix(PB.PREFIX)
            print("|cff00ff00PetBattle|r v" .. PB.VERSION .. " loaded. Type /pb help")
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == PB.PREFIX then
            PB.Network.OnMessage(message, channel, sender)
        end
    end
end)

SLASH_PETBATTLE1 = "/pb"
SLASH_PETBATTLE2 = "/petbattle"
SlashCmdList["PETBATTLE"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or ""):lower()

    if cmd == "challenge" or cmd == "c" then
        if arg == "" then
            print("|cffff8800PetBattle:|r Usage: /pb challenge <PlayerName>")
        else
            PB.Network.SendChallenge(arg)
        end
    elseif cmd == "team" or cmd == "t" then
        PB.UI.ToggleTeamSelect()
    elseif cmd == "battle" or cmd == "b" then
        PB.UI.ToggleBattleFrame()
    elseif cmd == "random" or cmd == "r" then
        PB.AIBattle.Start()
    elseif cmd == "forfeit" then
        PB.Engine.Forfeit()
    elseif cmd == "help" or cmd == "" then
        print("|cff00ff00PetBattle Commands:|r")
        print("  /pb random            - Random battle vs AI (random team)")
        print("  /pb challenge <name>  - Challenge a player to a battle")
        print("  /pb team              - Open team builder")
        print("  /pb battle            - Toggle battle window")
        print("  /pb forfeit           - Forfeit current battle")
    else
        print("|cffff8800PetBattle:|r Unknown command. Type /pb help")
    end
end

-- Utility: print to battle log or chat
function PB.Print(msg)
    if PB.UI and PB.UI.LogLine then
        PB.UI.LogLine(msg)
    else
        print("|cff00ff00PetBattle:|r " .. msg)
    end
end

-- Utility: type ID to colored name
function PB.TypeLabel(typeID)
    local name = PB.TypeNames[typeID] or "???"
    local color = PB.TypeColors[typeID] or "ffffff"
    return "|cff" .. color .. name .. "|r"
end
