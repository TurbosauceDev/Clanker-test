-- BattleEngine: turn resolution, damage calculation, state machine

PB.Engine = {}

-- Battle states
PB.State = {
    IDLE            = "IDLE",
    CHALLENGE_OUT   = "CHALLENGE_OUT",   -- we sent a challenge, waiting
    CHALLENGE_IN    = "CHALLENGE_IN",    -- we received a challenge
    TEAM_SELECT     = "TEAM_SELECT",     -- accepted, picking team
    WAITING_TEAM    = "WAITING_TEAM",    -- team sent, waiting for opponent's team
    CHOOSING        = "CHOOSING",        -- our turn: pick a move or switch
    WAITING_MOVE    = "WAITING_MOVE",    -- move sent, waiting for opponent's move
    RESOLVING       = "RESOLVING",       -- host is resolving this turn
    SWITCH_PROMPT   = "SWITCH_PROMPT",   -- fainted, must switch
    GAME_OVER       = "GAME_OVER",
}

-- Active battle data
PB.Battle = {
    state           = PB.State.IDLE,
    isHost          = false,    -- challenger is host and resolves turns
    opponentName    = nil,
    randomSeed      = 0,

    myTeam          = {},       -- array of 3 battlePets
    oppTeam         = {},
    myActiveIndex   = 1,
    oppActiveIndex  = 1,

    myMove          = nil,      -- chosen this turn: { type="move", name=... } or { type="switch", index=N }
    oppMove         = nil,

    turn            = 0,
}

-- ─── Stat stage accuracy/evasion multipliers ────────────────────────────────
local ACC_TABLE = { [6]=3.0, [5]=8/3, [4]=7/3, [3]=2.0, [2]=5/3, [1]=4/3,
                    [0]=1.0,
                    [-1]=3/4, [-2]=3/5, [-3]=3/6, [-4]=3/7, [-5]=3/8, [-6]=1/3 }

-- ─── Core Damage Calculation ─────────────────────────────────────────────────
function PB.Engine.CalcDamage(attacker, defender, moveName, roll)
    local move = PB.Moves[moveName]
    if not move or move.category == "Status" then return 0 end

    local atkStat, defStat
    if move.category == "Physical" then
        atkStat = PB.PetData.GetEffectiveStat(attacker, "atk")
        defStat = PB.PetData.GetEffectiveStat(defender, "def")
    else
        atkStat = PB.PetData.GetEffectiveStat(attacker, "spatk")
        defStat = PB.PetData.GetEffectiveStat(defender, "spdef")
    end

    local power = move.power

    -- Hex doubles power if target has a status
    if move.effect and move.effect.double_if_status and defender.status then
        power = power * 2
    end

    local damage = math.floor(power * atkStat / defStat)

    -- STAB: 1.5x if move type matches attacker's Pokemon type
    if move.type == attacker.pokeType then
        damage = math.floor(damage * 1.5)
    end

    -- Type effectiveness
    local effectiveness = PB.GetEffectiveness(move.type, defender.pokeType)
    damage = math.floor(damage * effectiveness)

    -- Random factor 85-100%
    local r = roll or math.random(85, 100)
    damage = math.floor(damage * r / 100)

    return math.max(1, damage), effectiveness
end

-- ─── Accuracy Check ──────────────────────────────────────────────────────────
function PB.Engine.AccuracyCheck(attacker, defender, move)
    if move.accuracy == true then return true end  -- never misses
    local acc = move.accuracy or 100
    local accStage = attacker.stages.acc or 0
    local evaStage = defender.stages.eva or 0
    local netStage = math.max(-6, math.min(6, accStage - evaStage))
    local mult = ACC_TABLE[netStage] or 1
    local finalAcc = math.floor(acc * mult)
    return math.random(100) <= finalAcc
end

-- ─── Apply Secondary Effect ──────────────────────────────────────────────────
local function tryApplyStatus(target, statusName, chance)
    if math.random(100) > chance then return nil end
    if target.status then return nil end  -- already has a condition
    if statusName == "toxic" then
        target.status = "toxic"
        target.toxicCounter = 0
        return target.name .. " was badly poisoned!"
    elseif statusName == "leech_seed" then
        if target.pokeType == PB.Types.GRASS then return nil end
        target.status = "leech_seed"
        return target.name .. " was seeded!"
    elseif statusName == "destiny_bond" then
        target.status = "destiny_bond"
        return target.name .. " destined bond!"
    else
        target.status = statusName
        if statusName == "sleep" then
            target.statusTurns = math.random(1, 3)
            return target.name .. " fell asleep!"
        elseif statusName == "freeze" then
            return target.name .. " was frozen solid!"
        elseif statusName == "burn" then
            return target.name .. " was burned!"
        elseif statusName == "poison" then
            return target.name .. " was poisoned!"
        elseif statusName == "paralysis" then
            return target.name .. " was paralyzed!"
        elseif statusName == "confusion" then
            target.statusTurns = math.random(2, 5)
            return target.name .. " became confused!"
        elseif statusName == "flinch" then
            return nil  -- flinch is handled in turn order
        end
    end
    return nil
end

function PB.Engine.ApplyEffect(attacker, defender, move, damage)
    local log = {}
    local eff = move.effect
    if not eff then return log end

    -- Status on target
    if eff.status and eff.status ~= "flinch" then
        local msg = tryApplyStatus(defender, eff.status, eff.chance or 100)
        if msg then log[#log+1] = msg end
    end

    -- Flinch stored as flag (only matters if attacker moved first)
    if eff.status == "flinch" and math.random(100) <= (eff.chance or 30) then
        defender._flinched = true
    end

    -- Stat changes on target
    if eff.foe_stat and math.random(100) <= (eff.chance or 100) then
        local s = eff.foe_stat
        local msg = PB.PetData.ApplyStatStage(defender, s.stat, s.stages)
        log[#log+1] = msg
    end

    -- Stat changes on self
    if eff.self_stat and math.random(100) <= (eff.chance or 100) then
        local s = eff.self_stat
        if s.stat == "confusion_lock" then
            attacker.confusion_lock = (attacker.confusion_lock or 0) + 1
            if attacker.confusion_lock >= 2 then
                attacker.confusion_lock = nil
                attacker.status = "confusion"
                attacker.statusTurns = math.random(2, 5)
                log[#log+1] = attacker.name .. " became confused from Outrage!"
            end
        else
            local msg = PB.PetData.ApplyStatStage(attacker, s.stat, s.stages)
            log[#log+1] = msg
        end
    end

    -- Drain
    if eff.drain and damage > 0 then
        local healed = math.max(1, math.floor(damage * eff.drain))
        attacker.currentHP = math.min(attacker.baseStats.hp, attacker.currentHP + healed)
        log[#log+1] = attacker.name .. " drained " .. healed .. " HP!"
    end

    -- Heal (status move)
    if eff.heal then
        local healed = math.floor(attacker.baseStats.hp * eff.heal)
        attacker.currentHP = math.min(attacker.baseStats.hp, attacker.currentHP + healed)
        log[#log+1] = attacker.name .. " restored " .. healed .. " HP!"
    end

    -- Recharge flag
    if eff.recharge then
        attacker.mustRecharge = true
    end

    return log
end

-- ─── Execute a Single Move ───────────────────────────────────────────────────
-- Returns a log table of strings describing what happened
function PB.Engine.ExecuteMove(attacker, defender, moveName)
    local log = {}
    local move = PB.Moves[moveName]

    if not move then
        log[#log+1] = attacker.name .. " tried to use an unknown move!"
        return log
    end

    -- Recharge turn
    if attacker.mustRecharge then
        attacker.mustRecharge = false
        log[#log+1] = attacker.name .. " must recharge!"
        return log
    end

    -- Sleep check
    if attacker.status == "sleep" then
        attacker.statusTurns = attacker.statusTurns - 1
        if attacker.statusTurns <= 0 then
            attacker.status = nil
            log[#log+1] = attacker.name .. " woke up!"
        else
            log[#log+1] = attacker.name .. " is fast asleep!"
            return log
        end
    end

    -- Freeze check
    if attacker.status == "freeze" then
        if math.random(100) <= 20 then
            attacker.status = nil
            log[#log+1] = attacker.name .. " thawed out!"
        else
            log[#log+1] = attacker.name .. " is frozen solid!"
            return log
        end
    end

    -- Paralysis skip check
    if attacker.status == "paralysis" then
        if math.random(100) <= 25 then
            log[#log+1] = attacker.name .. " is fully paralyzed!"
            return log
        end
    end

    -- Flinch check (set by previous move this turn)
    if attacker._flinched then
        attacker._flinched = nil
        log[#log+1] = attacker.name .. " flinched!"
        return log
    end

    -- Confusion self-hit
    if attacker.status == "confusion" then
        attacker.statusTurns = attacker.statusTurns - 1
        if attacker.statusTurns <= 0 then
            attacker.status = nil
            log[#log+1] = attacker.name .. " snapped out of confusion!"
        elseif math.random(3) == 1 then
            local selfDmg = math.max(1, math.floor(attacker.baseStats.attack * 40 / attacker.baseStats.defense))
            attacker.currentHP = attacker.currentHP - selfDmg
            log[#log+1] = attacker.name .. " hurt itself in confusion! (-" .. selfDmg .. " HP)"
            return log
        end
    end

    -- PP check
    local pp = attacker.pp[moveName] or 0
    if pp <= 0 then
        log[#log+1] = attacker.name .. " used Struggle! (No PP left)"
        moveName = "_Struggle"
        move = { type=PB.Types.NORMAL, category="Physical", power=50, accuracy=100, pp=1 }
    else
        attacker.pp[moveName] = pp - 1
    end

    log[#log+1] = attacker.name .. " used " .. moveName .. "!"

    -- Accuracy check
    if not PB.Engine.AccuracyCheck(attacker, defender, move) then
        log[#log+1] = attacker.name .. "'s attack missed!"
        return log
    end

    if move.category == "Status" then
        local effLog = PB.Engine.ApplyEffect(attacker, defender, move, 0)
        for _, m in ipairs(effLog) do log[#log+1] = m end
    else
        local damage, effectiveness = PB.Engine.CalcDamage(attacker, defender, moveName)
        local effText = PB.EffectivenessText(effectiveness)
        if effText then log[#log+1] = effText end

        -- Destiny Bond: if attacker would faint, take defender down too
        if defender.status == "destiny_bond" then
            -- handled in faint check below
        end

        defender.currentHP = math.max(0, defender.currentHP - damage)
        log[#log+1] = "Dealt " .. damage .. " damage. (" .. defender.name .. " has " .. math.max(0, defender.currentHP) .. " HP)"

        local effLog = PB.Engine.ApplyEffect(attacker, defender, move, damage)
        for _, m in ipairs(effLog) do log[#log+1] = m end

        -- Struggle recoil
        if moveName == "_Struggle" then
            local recoil = math.max(1, math.floor(attacker.baseStats.hp / 4))
            attacker.currentHP = math.max(0, attacker.currentHP - recoil)
            log[#log+1] = attacker.name .. " was hurt by recoil! (-" .. recoil .. " HP)"
        end
    end

    return log
end

-- ─── End-of-Turn Effects ─────────────────────────────────────────────────────
function PB.Engine.EndOfTurnEffects(pet)
    local log = {}
    if pet.isFainted then return log end

    if pet.status == "burn" then
        local dmg = math.max(1, math.floor(pet.baseStats.hp / 16))
        pet.currentHP = math.max(0, pet.currentHP - dmg)
        log[#log+1] = pet.name .. " was hurt by its burn! (-" .. dmg .. " HP)"

    elseif pet.status == "poison" then
        local dmg = math.max(1, math.floor(pet.baseStats.hp / 8))
        pet.currentHP = math.max(0, pet.currentHP - dmg)
        log[#log+1] = pet.name .. " was hurt by poison! (-" .. dmg .. " HP)"

    elseif pet.status == "toxic" then
        pet.toxicCounter = pet.toxicCounter + 1
        local dmg = math.max(1, math.floor(pet.baseStats.hp * pet.toxicCounter / 16))
        pet.currentHP = math.max(0, pet.currentHP - dmg)
        log[#log+1] = pet.name .. " was hurt by toxic! (-" .. dmg .. " HP)"
    end

    return log
end

-- ─── Check Fainted ───────────────────────────────────────────────────────────
function PB.Engine.CheckFainted(pet)
    if pet.currentHP <= 0 and not pet.isFainted then
        pet.currentHP = 0
        pet.isFainted = true
        return true
    end
    return false
end

function PB.Engine.TeamAlive(team)
    for _, pet in ipairs(team) do
        if not pet.isFainted then return true end
    end
    return false
end

-- ─── Determine Turn Order ────────────────────────────────────────────────────
-- Returns true if myPet moves first this turn
function PB.Engine.MyGoesFirst(myPet, oppPet, myAction, oppAction)
    -- Switches always go before moves
    local myIsSwitch  = myAction.type == "switch"
    local oppIsSwitch = oppAction.type == "switch"
    if myIsSwitch and not oppIsSwitch then return true  end
    if oppIsSwitch and not myIsSwitch then return false end
    if myIsSwitch and oppIsSwitch     then return true  end  -- both switch: doesn't matter

    local myMove  = PB.Moves[myAction.name]
    local oppMove = PB.Moves[oppAction.name]
    local myPrio  = (myMove and myMove.priority) or 0
    local oppPrio = (oppMove and oppMove.priority) or 0

    if myPrio ~= oppPrio then return myPrio > oppPrio end

    -- Same priority: compare speed
    local mySpd  = PB.PetData.GetEffectiveStat(myPet, "spd")
    local oppSpd = PB.PetData.GetEffectiveStat(oppPet, "spd")
    if mySpd ~= oppSpd then return mySpd > oppSpd end

    return math.random(2) == 1  -- speed tie
end

-- ─── Resolve a Full Turn ─────────────────────────────────────────────────────
-- Called by the host after both moves are known.
-- Returns a results table: { log={}, myHPFinal, oppHPFinal, faintedMy, faintedOpp, winner }
function PB.Engine.ResolveTurn(myAction, oppAction)
    local log = {}
    local battle = PB.Battle

    local myPet  = battle.myTeam[battle.myActiveIndex]
    local oppPet = battle.oppTeam[battle.oppActiveIndex]

    local function addLog(lines)
        for _, l in ipairs(lines) do log[#log+1] = l end
    end

    local myFirst = PB.Engine.MyGoesFirst(myPet, oppPet, myAction, oppAction)

    local function handleAction(action, actor, target, isMyAction)
        if action.type == "switch" then
            local team = isMyAction and battle.myTeam or battle.oppTeam
            local newPet = team[action.index]
            if newPet and not newPet.isFainted then
                if isMyAction then
                    battle.myActiveIndex = action.index
                    myPet = newPet
                else
                    battle.oppActiveIndex = action.index
                    oppPet = newPet
                end
                log[#log+1] = (isMyAction and "You" or "Opponent") .. " sent out " .. newPet.name .. "!"
            end
        elseif action.type == "move" then
            if actor.isFainted then return end
            addLog(PB.Engine.ExecuteMove(actor, target, action.name))

            -- Destiny Bond: if target fainted from this move and had dest bond
            if PB.Engine.CheckFainted(target) then
                if target.status == "destiny_bond" and not actor.isFainted then
                    actor.currentHP = 0
                    PB.Engine.CheckFainted(actor)
                    log[#log+1] = actor.name .. " was taken down by Destiny Bond!"
                end
                log[#log+1] = target.name .. " fainted!"
            end
            if PB.Engine.CheckFainted(actor) then
                log[#log+1] = actor.name .. " fainted!"
            end
        end
    end

    if myFirst then
        handleAction(myAction,  myPet,  oppPet, true)
        if not oppPet.isFainted then
            handleAction(oppAction, oppPet, myPet,  false)
        end
    else
        handleAction(oppAction, oppPet, myPet,  false)
        if not myPet.isFainted then
            handleAction(myAction,  myPet,  oppPet, true)
        end
    end

    -- End-of-turn effects for both active pets
    addLog(PB.Engine.EndOfTurnEffects(myPet))
    if PB.Engine.CheckFainted(myPet) then log[#log+1] = myPet.name .. " fainted!" end

    addLog(PB.Engine.EndOfTurnEffects(oppPet))
    if PB.Engine.CheckFainted(oppPet) then log[#log+1] = oppPet.name .. " fainted!" end

    battle.turn = battle.turn + 1

    -- Build result summary
    local myFainted  = myPet.isFainted
    local oppFainted = oppPet.isFainted
    local winner = nil

    if not PB.Engine.TeamAlive(battle.myTeam) then
        winner = "opponent"
    elseif not PB.Engine.TeamAlive(battle.oppTeam) then
        winner = "me"
    end

    return {
        log          = log,
        myHP         = myPet.currentHP,
        oppHP        = oppPet.currentHP,
        myHPPercent  = myPet.currentHP / myPet.baseStats.hp,
        oppHPPercent = oppPet.currentHP / oppPet.baseStats.hp,
        faintedMy    = myFainted,
        faintedOpp   = oppFainted,
        winner       = winner,
    }
end

-- ─── Apply Network Result (non-host side) ────────────────────────────────────
-- The host sends us a serialized result; we apply it directly
function PB.Engine.ApplyResult(resultStr)
    -- Format: "myHP:oppHP:myStatus:oppStatus:winner:faintedMy:faintedOpp|logline|logline..."
    local header, rest = resultStr:match("^([^|]+)|?(.*)")
    local parts = {}
    for p in header:gmatch("[^:]+") do parts[#parts+1] = p end

    local myHP     = tonumber(parts[1]) or 0
    local oppHP    = tonumber(parts[2]) or 0
    local myStatus = parts[3] == "nil" and nil or parts[3]
    local oppStatus= parts[4] == "nil" and nil or parts[4]
    local winner   = parts[5] == "nil" and nil or parts[5]
    local faintedMy  = parts[6] == "true"
    local faintedOpp = parts[7] == "true"

    local battle = PB.Battle
    local myPet  = battle.myTeam[battle.myActiveIndex]
    local oppPet = battle.oppTeam[battle.oppActiveIndex]

    if myPet  then myPet.currentHP  = myHP;  myPet.status  = myStatus;  myPet.isFainted  = faintedMy  end
    if oppPet then oppPet.currentHP = oppHP; oppPet.status = oppStatus; oppPet.isFainted = faintedOpp end

    local log = {}
    for line in rest:gmatch("[^|]+") do log[#log+1] = line end

    return { log=log, winner=winner, faintedMy=faintedMy, faintedOpp=faintedOpp }
end

-- ─── Serialize Result for Network ────────────────────────────────────────────
function PB.Engine.SerializeResult(result, myPet, oppPet)
    local header = table.concat({
        myPet.currentHP,
        oppPet.currentHP,
        myPet.status or "nil",
        oppPet.status or "nil",
        result.winner or "nil",
        tostring(result.faintedMy),
        tostring(result.faintedOpp),
    }, ":")
    local logStr = table.concat(result.log, "|")
    return header .. "|" .. logStr
end

-- ─── Forfeit ─────────────────────────────────────────────────────────────────
function PB.Engine.Forfeit()
    if PB.Battle.state == PB.State.IDLE or PB.Battle.state == PB.State.GAME_OVER then
        PB.Print("You are not in a battle.")
        return
    end
    PB.Network.Send(PB.Battle.opponentName, "FORFEIT")
    PB.Engine.EndBattle("opponent", true)
end

-- ─── End Battle ──────────────────────────────────────────────────────────────
function PB.Engine.EndBattle(winner, forfeit)
    PB.Battle.state = PB.State.GAME_OVER
    if winner == "me" then
        PB.Print("|cff00ff00You won the battle!|r")
    elseif winner == "opponent" then
        local msg = forfeit and "You forfeited." or "You lost the battle."
        PB.Print("|cffff4444" .. msg .. "|r")
    else
        PB.Print("The battle ended in a draw.")
    end
    if PB.UI.OnBattleEnd then PB.UI.OnBattleEnd(winner) end
end
