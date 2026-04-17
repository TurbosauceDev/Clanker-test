-- Network: addon message protocol for multiplayer battles
-- All messages sent as WHISPER via C_ChatInfo.SendAddonMessage
-- Format: "CMD|data"

PB.Network = {}

local PENDING_CHALLENGE_FROM = nil  -- player who challenged us

-- ─── Send ────────────────────────────────────────────────────────────────────
function PB.Network.Send(target, cmd, data)
    local msg = data and (cmd .. "|" .. data) or cmd
    C_ChatInfo.SendAddonMessage(PB.PREFIX, msg, "WHISPER", target)
end

-- ─── Receive ─────────────────────────────────────────────────────────────────
function PB.Network.OnMessage(message, channel, sender)
    -- Strip realm from sender name
    local senderName = sender:match("^([^%-]+)") or sender
    local selfName   = UnitName("player")

    -- Ignore our own reflected messages
    if senderName == selfName then return end

    local cmd, data = message:match("^([^|]+)|?(.*)")
    cmd = cmd or message

    -- ── Challenge flow ──────────────────────────────────────────────────────
    if cmd == "CHALLENGE" then
        if PB.Battle.state ~= PB.State.IDLE then
            PB.Network.Send(senderName, "BUSY")
            return
        end
        PENDING_CHALLENGE_FROM = senderName
        PB.Battle.state = PB.State.CHALLENGE_IN
        PB.Print("|cffffcc00" .. senderName .. " challenges you to a pet battle!|r")
        PB.Print("Type |cff00ffff/pb challenge accept|r or |cffff4444/pb challenge decline|r")
        if PB.UI.ShowChallengePrompt then PB.UI.ShowChallengePrompt(senderName) end

    elseif cmd == "BUSY" then
        PB.Print(senderName .. " is already in a battle.")
        PB.Battle.state = PB.State.IDLE

    elseif cmd == "DECLINE" then
        PB.Print(senderName .. " declined your challenge.")
        PB.Battle.state = PB.State.IDLE

    elseif cmd == "ACCEPT" then
        -- They accepted our challenge; we are the host
        PB.Battle.isHost = true
        PB.Battle.opponentName = senderName
        local seed = math.random(1, 999999)
        PB.Battle.randomSeed = seed
        math.randomseed(seed)
        PB.Network.Send(senderName, "SEED", tostring(seed))
        PB.Battle.state = PB.State.TEAM_SELECT
        PB.Print(senderName .. " accepted! Select your team: /pb team")
        if PB.UI.OpenTeamSelect then PB.UI.OpenTeamSelect() end

    elseif cmd == "SEED" then
        -- We accepted their challenge; they sent the seed
        PB.Battle.randomSeed = tonumber(data) or 12345
        math.randomseed(PB.Battle.randomSeed)
        PB.Battle.isHost = false
        PB.Battle.state = PB.State.TEAM_SELECT
        PB.Print("Battle starting! Select your team: /pb team")
        if PB.UI.OpenTeamSelect then PB.UI.OpenTeamSelect() end

    -- ── Team exchange ───────────────────────────────────────────────────────
    elseif cmd == "TEAM" then
        -- data = "serialPet1;serialPet2;serialPet3"
        local pets = {}
        for chunk in data:gmatch("[^;]+") do
            local bp = PB.PetData.Deserialize(chunk)
            if bp then pets[#pets+1] = bp end
        end
        if #pets < 3 then
            PB.Print("Received invalid team from " .. senderName)
            return
        end
        PB.Battle.oppTeam = pets
        PB.Battle.oppActiveIndex = 1
        PB.Print("Received " .. senderName .. "'s team!")

        -- If we already sent our team, battle can start
        if PB.Battle.state == PB.State.WAITING_TEAM then
            PB.Engine.StartBattle()
        end

    -- ── Move exchange ───────────────────────────────────────────────────────
    elseif cmd == "MOVE" then
        -- data = "moveName"
        if PB.Battle.state ~= PB.State.WAITING_MOVE and PB.Battle.state ~= PB.State.RESOLVING then return end
        PB.Battle.oppMove = { type="move", name=data }
        PB.Network.TryResolve()

    elseif cmd == "SWITCH" then
        -- data = "teamIndex"
        if PB.Battle.state ~= PB.State.WAITING_MOVE and PB.Battle.state ~= PB.State.RESOLVING then return end
        PB.Battle.oppMove = { type="switch", index=tonumber(data) }
        PB.Network.TryResolve()

    elseif cmd == "SWITCH_IN" then
        -- Forced switch after faint; data = "teamIndex"
        local idx = tonumber(data)
        if idx then
            local oppPet = PB.Battle.oppTeam[idx]
            if oppPet and not oppPet.isFainted then
                PB.Battle.oppActiveIndex = idx
                PB.Print("Opponent sent out " .. oppPet.name .. "!")
                if PB.UI.Refresh then PB.UI.Refresh() end
            end
        end

    -- ── Turn result (host -> client) ────────────────────────────────────────
    elseif cmd == "RESULT" then
        if PB.Battle.isHost then return end  -- host doesn't receive its own results
        local result = PB.Engine.ApplyResult(data)
        PB.Network.HandleResult(result)

    -- ── Battle end ──────────────────────────────────────────────────────────
    elseif cmd == "FORFEIT" then
        PB.Print(senderName .. " forfeited!")
        PB.Engine.EndBattle("me", false)

    elseif cmd == "BATTLEEND" then
        PB.Engine.EndBattle(data == "you" and "opponent" or "me", false)
    end
end

-- ─── Send Challenge ──────────────────────────────────────────────────────────
function PB.Network.SendChallenge(targetName)
    if PB.Battle.state ~= PB.State.IDLE then
        PB.Print("You are already in a battle or challenge.")
        return
    end
    PB.Battle.opponentName = targetName
    PB.Battle.state = PB.State.CHALLENGE_OUT
    PB.Network.Send(targetName, "CHALLENGE")
    PB.Print("Challenge sent to " .. targetName .. "!")
end

function PB.Network.AcceptChallenge()
    if PB.Battle.state ~= PB.State.CHALLENGE_IN or not PENDING_CHALLENGE_FROM then
        PB.Print("No pending challenge to accept.")
        return
    end
    PB.Battle.opponentName = PENDING_CHALLENGE_FROM
    PENDING_CHALLENGE_FROM = nil
    PB.Network.Send(PB.Battle.opponentName, "ACCEPT")
    -- Wait for SEED from host before opening team select
end

function PB.Network.DeclineChallenge()
    if PENDING_CHALLENGE_FROM then
        PB.Network.Send(PENDING_CHALLENGE_FROM, "DECLINE")
        PENDING_CHALLENGE_FROM = nil
    end
    PB.Battle.state = PB.State.IDLE
    PB.Print("Challenge declined.")
end

-- ─── Send Team ───────────────────────────────────────────────────────────────
function PB.Network.SendTeam(petIDList)
    local parts = {}
    for _, petID in ipairs(petIDList) do
        local bp = PB.PetData.BuildBattlePet(petID)
        if bp then
            parts[#parts+1] = PB.PetData.Serialize(bp)
        end
    end
    if #parts < 3 then
        PB.Print("Could not build team. Make sure you selected 3 valid pets.")
        return false
    end

    -- Store our own team
    PB.Battle.myTeam = {}
    for _, petID in ipairs(petIDList) do
        local bp = PB.PetData.BuildBattlePet(petID)
        if bp then PB.Battle.myTeam[#PB.Battle.myTeam+1] = bp end
    end
    PB.Battle.myActiveIndex = 1

    local teamStr = table.concat(parts, ";")
    PB.Network.Send(PB.Battle.opponentName, "TEAM", teamStr)

    if #PB.Battle.oppTeam >= 3 then
        PB.Engine.StartBattle()
    else
        PB.Battle.state = PB.State.WAITING_TEAM
        PB.Print("Team sent! Waiting for opponent...")
    end
    return true
end

-- ─── Send Move ───────────────────────────────────────────────────────────────
function PB.Network.SendMove(moveName)
    if PB.Battle.state ~= PB.State.CHOOSING then
        PB.Print("It's not time to choose a move.")
        return
    end
    PB.Battle.myMove = { type="move", name=moveName }
    PB.Battle.state = PB.State.WAITING_MOVE
    PB.Network.Send(PB.Battle.opponentName, "MOVE", moveName)
    PB.Print("Move sent. Waiting for opponent...")
    PB.Network.TryResolve()
end

function PB.Network.SendSwitch(teamIndex)
    if PB.Battle.state ~= PB.State.CHOOSING and PB.Battle.state ~= PB.State.SWITCH_PROMPT then
        PB.Print("Can't switch right now.")
        return
    end
    local pet = PB.Battle.myTeam[teamIndex]
    if not pet or pet.isFainted then
        PB.Print("That pet has fainted!")
        return
    end
    if teamIndex == PB.Battle.myActiveIndex then
        PB.Print("That pet is already active!")
        return
    end

    if PB.Battle.state == PB.State.SWITCH_PROMPT then
        -- Forced switch after faint
        PB.Battle.myActiveIndex = teamIndex
        PB.Network.Send(PB.Battle.opponentName, "SWITCH_IN", tostring(teamIndex))
        PB.Print("Sent out " .. pet.name .. "!")
        PB.Battle.state = PB.State.CHOOSING
        if PB.UI.Refresh then PB.UI.Refresh() end
        return
    end

    PB.Battle.myMove = { type="switch", index=teamIndex }
    PB.Battle.state = PB.State.WAITING_MOVE
    PB.Network.Send(PB.Battle.opponentName, "SWITCH", tostring(teamIndex))
    PB.Network.TryResolve()
end

-- ─── Try Resolve (host only) ─────────────────────────────────────────────────
function PB.Network.TryResolve()
    if not PB.Battle.isHost then return end
    if not PB.Battle.myMove or not PB.Battle.oppMove then return end

    PB.Battle.state = PB.State.RESOLVING
    local result = PB.Engine.ResolveTurn(PB.Battle.myMove, PB.Battle.oppMove)
    PB.Battle.myMove  = nil
    PB.Battle.oppMove = nil

    -- Send result to opponent
    local myPet  = PB.Battle.myTeam[PB.Battle.myActiveIndex]
    local oppPet = PB.Battle.oppTeam[PB.Battle.oppActiveIndex]
    local resultStr = PB.Engine.SerializeResult(result, myPet, oppPet)
    PB.Network.Send(PB.Battle.opponentName, "RESULT", resultStr)

    PB.Network.HandleResult(result)
end

-- ─── Handle Resolved Turn ────────────────────────────────────────────────────
function PB.Network.HandleResult(result)
    -- Print log lines
    for _, line in ipairs(result.log or {}) do
        PB.Print(line)
    end

    if result.winner then
        PB.Engine.EndBattle(result.winner, false)
        return
    end

    -- Prompt for switch if active pet fainted
    if result.faintedMy then
        if PB.Engine.TeamAlive(PB.Battle.myTeam) then
            PB.Battle.state = PB.State.SWITCH_PROMPT
            PB.Print("|cffffcc00Your pet fainted! Choose a replacement.|r")
            if PB.UI.ShowSwitchPrompt then PB.UI.ShowSwitchPrompt() end
        end
    elseif result.faintedOpp then
        PB.Battle.state = PB.State.CHOOSING
        PB.Print("Opponent's pet fainted!")
        if PB.UI.Refresh then PB.UI.Refresh() end
    else
        PB.Battle.state = PB.State.CHOOSING
        if PB.UI.Refresh then PB.UI.Refresh() end
    end
end

-- ─── Start Battle (after both teams received) ────────────────────────────────
function PB.Engine.StartBattle()
    PB.Battle.turn = 1
    PB.Battle.myActiveIndex  = 1
    PB.Battle.oppActiveIndex = 1
    PB.Battle.state = PB.State.CHOOSING

    local myPet  = PB.Battle.myTeam[1]
    local oppPet = PB.Battle.oppTeam[1]

    PB.Print("|cff00ff00--- Battle Start! ---")
    PB.Print("You sent out " .. myPet.name .. "!")
    PB.Print("Opponent sent out " .. oppPet.name .. "!")

    if PB.UI.OpenBattleFrame then PB.UI.OpenBattleFrame() end
    if PB.UI.Refresh then PB.UI.Refresh() end
end
