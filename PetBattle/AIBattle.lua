-- AIBattle: random battle vs local AI opponent
-- Player gets 3 random pets from their journal; AI gets 3 random pets from the pool.

PB.AIBattle = {}

-- ─── AI Pet Pool ─────────────────────────────────────────────────────────────
-- 30 WoW-themed pets spread across all 10 families.
-- Stats approximate level-25 rare quality (hp 1200-1800, power/speed 240-325).
PB.AIBattle.PetPool = {
    -- Humanoid (1) → Fighting
    { name="Hogger",               wowFamily=1, hp=1481, power=305, speed=260 },
    { name="Murloc Tidehunter",    wowFamily=1, hp=1319, power=260, speed=325 },
    { name="Troll Dice",           wowFamily=1, hp=1546, power=289, speed=244 },
    -- Dragonkin (2) → Dragon
    { name="Lil' Deathwing",       wowFamily=2, hp=1400, power=325, speed=260 },
    { name="Onyxian Whelpling",    wowFamily=2, hp=1465, power=289, speed=289 },
    { name="Bronze Whelpling",     wowFamily=2, hp=1319, power=276, speed=325 },
    -- Flying (3) → Flying
    { name="Gilnean Raven",        wowFamily=3, hp=1237, power=289, speed=341 },
    { name="Brilliant Kaliri",     wowFamily=3, hp=1400, power=273, speed=309 },
    { name="Stormwing",            wowFamily=3, hp=1465, power=305, speed=257 },
    -- Undead (4) → Ghost
    { name="Ghostly Skull",        wowFamily=4, hp=1627, power=289, speed=244 },
    { name="Restless Shadeling",   wowFamily=4, hp=1546, power=276, speed=257 },
    { name="Mr. Bigglesworth",     wowFamily=4, hp=1400, power=257, speed=309 },
    -- Critter (5) → Normal
    { name="Squirrel",             wowFamily=5, hp=1400, power=244, speed=341 },
    { name="Prairie Dog",          wowFamily=5, hp=1465, power=257, speed=305 },
    { name="Rat",                  wowFamily=5, hp=1319, power=244, speed=341 },
    -- Magic (6) → Psychic
    { name="Enchanted Broom",      wowFamily=6, hp=1400, power=305, speed=289 },
    { name="Arcane Eye",           wowFamily=6, hp=1481, power=289, speed=273 },
    { name="Lunar Lantern",        wowFamily=6, hp=1237, power=325, speed=305 },
    -- Elemental (7) → Fire
    { name="Lil' Ragnaros",        wowFamily=7, hp=1400, power=325, speed=257 },
    { name="Pandaren Fire Spirit", wowFamily=7, hp=1627, power=260, speed=244 },
    { name="Burning Gemstone",     wowFamily=7, hp=1319, power=305, speed=305 },
    -- Beast (8) → Dark
    { name="Core Hound Pup",       wowFamily=8, hp=1546, power=289, speed=260 },
    { name="Perky Pug",            wowFamily=8, hp=1400, power=257, speed=325 },
    { name="Nightsaber Cub",       wowFamily=8, hp=1465, power=305, speed=273 },
    -- Aquatic (9) → Water
    { name="Chuck",                wowFamily=9, hp=1546, power=276, speed=273 },
    { name="Magical Crawdad",      wowFamily=9, hp=1725, power=244, speed=244 },
    { name="Strand Crab",          wowFamily=9, hp=1627, power=244, speed=260 },
    -- Mechanical (10) → Steel
    { name="Mechanical Yeti",      wowFamily=10, hp=1400, power=305, speed=289 },
    { name="Landro's Lil' XT",     wowFamily=10, hp=1546, power=289, speed=257 },
    { name="De-Weaponized Mechsuit",wowFamily=10, hp=1319, power=260, speed=341 },
}

-- ─── Build AI Battle Pet ──────────────────────────────────────────────────────
local function BuildAIPet(entry)
    local wowFamily = entry.wowFamily
    local pokeType  = PB.FamilyType[wowFamily] or PB.Types.NORMAL
    local moves     = PB.FamilyMoves[wowFamily] or PB.FamilyMoves[5]
    local defense   = math.floor(entry.hp / 8)

    local pet = {
        petID    = "AI_" .. entry.name:gsub("%W", "_"),
        name     = entry.name,
        level    = 25,
        wowFamily = wowFamily,
        pokeType = pokeType,
        icon     = nil,
        isAI     = true,

        baseStats = {
            hp      = entry.hp,
            attack  = entry.power,
            spatk   = entry.power,
            defense = defense,
            spdef   = defense,
            speed   = entry.speed,
        },

        currentHP    = entry.hp,
        stages       = { atk=0, def=0, spatk=0, spdef=0, spd=0, acc=0, eva=0 },
        status       = nil,
        statusTurns  = 0,
        toxicCounter = 0,
        pp           = {},
        moves        = moves,

        isFainted       = false,
        mustRecharge    = false,
        isCharging      = false,
        usedDestinyBond = false,
    }

    for _, moveName in ipairs(moves) do
        local md = PB.Moves[moveName]
        pet.pp[moveName] = md and md.pp or 10
    end

    return pet
end

-- ─── Random Player Team ───────────────────────────────────────────────────────
function PB.AIBattle.RandomPlayerTeam()
    local eligible = {}
    local total = C_PetJournal.GetNumPets()
    for i = 1, total do
        local petID, _, _, _, _, _, _, _, _, _, _, _, _, _, canBattle =
            C_PetJournal.GetPetInfoByIndex(i)
        if petID and canBattle then
            eligible[#eligible + 1] = petID
        end
    end

    if #eligible < 3 then
        return nil, "You need at least 3 battle-eligible pets in your journal!"
    end

    -- Fisher-Yates shuffle
    for i = #eligible, 2, -1 do
        local j = math.random(i)
        eligible[i], eligible[j] = eligible[j], eligible[i]
    end

    local team = {}
    for i = 1, 3 do
        local bp = PB.PetData.BuildBattlePet(eligible[i])
        if bp then team[#team + 1] = bp end
    end

    if #team < 3 then
        return nil, "Could not build a full team from your pets."
    end
    return team
end

-- ─── Random AI Team ───────────────────────────────────────────────────────────
-- Picks 3 pets with no two from the same family for variety.
function PB.AIBattle.RandomAITeam()
    local pool = {}
    for _, e in ipairs(PB.AIBattle.PetPool) do pool[#pool + 1] = e end

    -- shuffle
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local team, used = {}, {}
    for _, entry in ipairs(pool) do
        if not used[entry.wowFamily] then
            team[#team + 1] = BuildAIPet(entry)
            used[entry.wowFamily] = true
        end
        if #team >= 3 then break end
    end

    -- Fallback: allow repeats if pool diversity is exhausted
    for _, entry in ipairs(pool) do
        if #team >= 3 then break end
        team[#team + 1] = BuildAIPet(entry)
    end

    return team
end

-- ─── AI Action Selection ─────────────────────────────────────────────────────
-- Returns { type="move", name=str } or { type="switch", index=N }
function PB.AIBattle.ChooseAction(aiPet, playerPet)
    local battle = PB.Battle

    -- Score every available move
    local bestMove, bestScore = nil, -math.huge
    for _, moveName in ipairs(aiPet.moves) do
        local move = PB.Moves[moveName]
        if not move or (aiPet.pp[moveName] or 0) <= 0 then goto continue end

        local score = 0
        if move.category == "Status" then
            -- Status moves: worth casting once; prefer if opponent has no status
            if move.effect and move.effect.status and not playerPet.status then
                score = 45
            elseif move.effect and move.effect.self_stat then
                score = 35  -- setup moves
            elseif move.effect and move.effect.heal then
                -- Recover: useful when below 50% HP
                local pct = aiPet.currentHP / aiPet.baseStats.hp
                score = pct < 0.5 and 80 or 5
            else
                score = 10
            end
        else
            score = move.power or 0
            -- Type effectiveness
            local eff = PB.GetEffectiveness(move.type, playerPet.pokeType)
            score = score * eff
            -- STAB
            if move.type == aiPet.pokeType then score = score * 1.5 end
            -- Bonus for confirmed KO (use 92% roll estimate)
            local estDmg = PB.Engine.CalcDamage(aiPet, playerPet, moveName, 92)
            if estDmg >= playerPet.currentHP then score = score + 10000 end
        end

        if score > bestScore then
            bestScore = score
            bestMove  = moveName
        end
        ::continue::
    end

    -- Fallback: first move with PP
    if not bestMove then
        for _, moveName in ipairs(aiPet.moves) do
            if (aiPet.pp[moveName] or 0) > 0 then bestMove = moveName; break end
        end
    end
    if not bestMove then bestMove = aiPet.moves[1] end -- Struggle territory

    -- Consider a voluntary switch if at a significant type disadvantage and healthy
    local incomingEff = PB.GetEffectiveness(playerPet.pokeType, aiPet.pokeType)
    if incomingEff >= 2 and aiPet.currentHP > aiPet.baseStats.hp * 0.45 then
        for i, candidate in ipairs(battle.oppTeam) do
            if not candidate.isFainted and i ~= battle.oppActiveIndex then
                local candEff = PB.GetEffectiveness(playerPet.pokeType, candidate.pokeType)
                if candEff < incomingEff then
                    return { type="switch", index=i }
                end
            end
        end
    end

    return { type="move", name=bestMove }
end

-- ─── AI Forced Switch (after faint) ──────────────────────────────────────────
function PB.AIBattle.ChooseForcedSwitch()
    local battle    = PB.Battle
    local playerPet = battle.myTeam[battle.myActiveIndex]
    local bestIdx, bestScore = nil, -math.huge

    for i, pet in ipairs(battle.oppTeam) do
        if not pet.isFainted and i ~= battle.oppActiveIndex then
            -- Prefer type advantage over player's active type
            local outgoingEff = PB.GetEffectiveness(pet.pokeType, playerPet.pokeType)
            local incomingEff = PB.GetEffectiveness(playerPet.pokeType, pet.pokeType)
            local score = outgoingEff * 50 - incomingEff * 30
                        + (pet.currentHP / pet.baseStats.hp) * 20
                        + PB.PetData.GetEffectiveStat(pet, "spd") / 20
            if score > bestScore then
                bestScore = score
                bestIdx   = i
            end
        end
    end

    return bestIdx
end

-- ─── Start Random AI Battle ───────────────────────────────────────────────────
function PB.AIBattle.Start()
    local s = PB.Battle.state
    if s ~= PB.State.IDLE and s ~= PB.State.GAME_OVER then
        PB.Print("Finish your current battle first!")
        return
    end

    -- Seed RNG from time for variety
    math.randomseed(time())

    -- Reset
    PB.Battle.isAIBattle   = true
    PB.Battle.isHost       = true
    PB.Battle.opponentName = "AI Trainer"
    PB.Battle.myMove       = nil
    PB.Battle.oppMove      = nil
    PB.Battle.turn         = 0

    local playerTeam, err = PB.AIBattle.RandomPlayerTeam()
    if not playerTeam then
        PB.Print("|cffff4444" .. (err or "Failed to build player team.") .. "|r")
        return
    end

    local aiTeam = PB.AIBattle.RandomAITeam()

    PB.Battle.myTeam         = playerTeam
    PB.Battle.oppTeam        = aiTeam
    PB.Battle.myActiveIndex  = 1
    PB.Battle.oppActiveIndex = 1

    PB.Print("|cff00ff00=== Random Battle vs AI ===|r")
    PB.Print("Your team : " .. playerTeam[1].name .. ", " .. playerTeam[2].name .. ", " .. playerTeam[3].name)
    PB.Print("AI team   : " .. aiTeam[1].name    .. ", " .. aiTeam[2].name    .. ", " .. aiTeam[3].name)

    PB.Engine.StartBattle()
end

-- ─── Submit Player Action (AI battle turn loop) ───────────────────────────────
function PB.AIBattle.SubmitAction(playerAction)
    if PB.Battle.state ~= PB.State.CHOOSING then return end
    PB.Battle.state = PB.State.RESOLVING

    local aiPet     = PB.Battle.oppTeam[PB.Battle.oppActiveIndex]
    local playerPet = PB.Battle.myTeam[PB.Battle.myActiveIndex]
    local aiAction  = PB.AIBattle.ChooseAction(aiPet, playerPet)

    local result = PB.Engine.ResolveTurn(playerAction, aiAction)

    for _, line in ipairs(result.log or {}) do PB.Print(line) end

    if result.winner then
        PB.Engine.EndBattle(result.winner, false)
        if PB.UI.Refresh then PB.UI.Refresh() end
        return
    end

    -- AI auto-switches if its active pet fainted
    if result.faintedOpp and PB.Engine.TeamAlive(PB.Battle.oppTeam) then
        local nextIdx = PB.AIBattle.ChooseForcedSwitch()
        if nextIdx then
            PB.Battle.oppActiveIndex = nextIdx
            PB.Print("AI sent out " .. PB.Battle.oppTeam[nextIdx].name .. "!")
        end
    end

    -- Prompt player to switch if their pet fainted
    if result.faintedMy and PB.Engine.TeamAlive(PB.Battle.myTeam) then
        PB.Battle.state = PB.State.SWITCH_PROMPT
        PB.Print("|cffffcc00Your pet fainted! Choose a replacement.|r")
        if PB.UI.Refresh then PB.UI.Refresh() end
        if PB.UI.ShowSwitchPrompt then PB.UI.ShowSwitchPrompt() end
        return
    end

    PB.Battle.state = PB.State.CHOOSING
    if PB.UI.Refresh then PB.UI.Refresh() end
end

-- ─── Player Forced Switch (after faint, no turn resolution) ──────────────────
function PB.AIBattle.DoForcedSwitch(teamIndex)
    local pet = PB.Battle.myTeam[teamIndex]
    if not pet or pet.isFainted then
        PB.Print("That pet has fainted!")
        return
    end
    PB.Battle.myActiveIndex = teamIndex
    PB.Print("You sent out " .. pet.name .. "!")
    PB.Battle.state = PB.State.CHOOSING
    if PB.UI.Refresh then PB.UI.Refresh() end
end
