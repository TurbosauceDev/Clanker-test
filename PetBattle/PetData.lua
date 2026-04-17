-- PetData: builds a battle-ready pet from a WoW pet journal entry
-- Uses C_PetJournal API to read live pet stats then maps them to our system

PB.PetData = {}

-- Build a battle pet table from a petID (journal GUID)
-- Returns nil if pet is invalid or not owned
function PB.PetData.BuildBattlePet(petID)
    if not petID then return nil end

    -- GetPetInfoByPetID returns: speciesID, customName, level, xp, maxXp,
    --   displayID, isFavorite, name, icon, petType, creatureID, sourceText,
    --   description, isWild, canBattle, isTradeable, isUnique, isObtainable, creatureName
    local speciesID, customName, level, _, _, displayID, _, name, icon,
          petType = C_PetJournal.GetPetInfoByPetID(petID)

    if not speciesID then return nil end

    -- GetPetStats returns: maxHealth, power, speed, rarity, isCapped
    local maxHealth, power, speed = C_PetJournal.GetPetStats(petID)

    if not maxHealth then
        -- Fallback stats for a level 25 pet if API fails
        maxHealth, power, speed = 1400, 273, 273
    end

    local wowFamily  = petType or 5
    local pokeType   = PB.FamilyType[wowFamily] or PB.Types.NORMAL
    local moves      = PB.FamilyMoves[wowFamily] or PB.FamilyMoves[5]
    local displayName = (customName and customName ~= "") and customName or name or "Unknown Pet"

    -- Defense derived from health (bulkier pets tank more)
    local defense = math.floor(maxHealth / 8)

    local battlePet = {
        petID       = petID,
        speciesID   = speciesID,
        name        = displayName,
        creatureName = name,
        icon        = icon,
        displayID   = displayID,
        level       = level or 25,
        wowFamily   = wowFamily,
        pokeType    = pokeType,

        -- Base stats (don't change during battle)
        baseStats = {
            hp      = maxHealth,
            attack  = power,
            spatk   = power,
            defense = defense,
            spdef   = defense,
            speed   = speed,
        },

        -- Current battle stats (modified by stages, status etc.)
        currentHP = maxHealth,

        -- Stat boost stages (-6 to +6)
        stages = { atk=0, def=0, spatk=0, spdef=0, spd=0, acc=0, eva=0 },

        -- Active status condition
        status = nil,       -- "burn"|"poison"|"toxic"|"paralysis"|"sleep"|"freeze"|"confusion"
        statusTurns = 0,    -- turns remaining for sleep/freeze
        toxicCounter = 0,   -- toxic stacks (1/16, 2/16, 3/16 ...)

        -- Move PP tracking: moveName -> remaining PP
        pp = {},

        -- Moves assigned to this pet
        moves = moves,

        -- Misc flags
        isFainted    = false,
        usedDestinyBond = false,
        mustRecharge    = false,
        isCharging      = false,  -- Solar Beam charge turn
    }

    -- Initialize PP from move data
    for _, moveName in ipairs(moves) do
        local moveData = PB.Moves[moveName]
        battlePet.pp[moveName] = moveData and moveData.pp or 10
    end

    return battlePet
end

-- Serialize a battle pet to a compact string for network transmission
-- Format: "petID:speciesID:name:level:wowFamily:hp:power:speed"
function PB.PetData.Serialize(battlePet)
    return table.concat({
        battlePet.petID,
        battlePet.speciesID,
        battlePet.name:gsub(":", "_"),  -- sanitize delimiter
        battlePet.level,
        battlePet.wowFamily,
        battlePet.baseStats.hp,
        battlePet.baseStats.attack,
        battlePet.baseStats.speed,
    }, ":")
end

-- Deserialize a pet sent over the network (opponent's pet we don't own)
function PB.PetData.Deserialize(str)
    local parts = {}
    for p in str:gmatch("[^:]+") do parts[#parts+1] = p end
    if #parts < 8 then return nil end

    local petID      = parts[1]
    local speciesID  = tonumber(parts[2])
    local name       = parts[3]:gsub("_", ":")
    local level      = tonumber(parts[4]) or 25
    local wowFamily  = tonumber(parts[5]) or 5
    local maxHealth  = tonumber(parts[6]) or 1400
    local power      = tonumber(parts[7]) or 273
    local speed      = tonumber(parts[8]) or 273

    local pokeType  = PB.FamilyType[wowFamily] or PB.Types.NORMAL
    local moves     = PB.FamilyMoves[wowFamily] or PB.FamilyMoves[5]
    local defense   = math.floor(maxHealth / 8)

    local battlePet = {
        petID       = petID,
        speciesID   = speciesID,
        name        = name,
        level       = level,
        wowFamily   = wowFamily,
        pokeType    = pokeType,
        icon        = nil,  -- opponent icon loaded separately if needed

        baseStats = {
            hp      = maxHealth,
            attack  = power,
            spatk   = power,
            defense = defense,
            spdef   = defense,
            speed   = speed,
        },

        currentHP       = maxHealth,
        stages          = { atk=0, def=0, spatk=0, spdef=0, spd=0, acc=0, eva=0 },
        status          = nil,
        statusTurns     = 0,
        toxicCounter    = 0,
        pp              = {},
        moves           = moves,
        isFainted       = false,
        usedDestinyBond = false,
        mustRecharge    = false,
        isCharging      = false,
    }

    for _, moveName in ipairs(moves) do
        local moveData = PB.Moves[moveName]
        battlePet.pp[moveName] = moveData and moveData.pp or 10
    end

    return battlePet
end

-- Apply a stat stage change to a pet and return a description string
function PB.PetData.ApplyStatStage(pet, stat, stages)
    if stat == "all" then
        for _, s in ipairs({"atk","def","spatk","spdef","spd"}) do
            PB.PetData.ApplyStatStage(pet, s, stages)
        end
        return pet.name .. "'s all stats rose!"
    end
    if stat == "atk_spd" then
        PB.PetData.ApplyStatStage(pet, "atk", stages)
        PB.PetData.ApplyStatStage(pet, "spd", stages)
        return pet.name .. "'s Attack and Speed rose!"
    end

    local prev = pet.stages[stat] or 0
    local new  = math.max(-6, math.min(6, prev + stages))
    pet.stages[stat] = new

    local statNames = { atk="Attack", def="Defense", spatk="Sp. Atk", spdef="Sp. Def", spd="Speed", acc="Accuracy", eva="Evasion" }
    local label = statNames[stat] or stat

    if new == prev then
        return pet.name .. "'s " .. label .. " won't go " .. (stages > 0 and "higher" or "lower") .. "!"
    elseif stages >= 2 then
        return pet.name .. "'s " .. label .. " sharply rose!"
    elseif stages == 1 then
        return pet.name .. "'s " .. label .. " rose!"
    elseif stages <= -2 then
        return pet.name .. "'s " .. label .. " sharply fell!"
    else
        return pet.name .. "'s " .. label .. " fell!"
    end
end

-- Get the effective stat value after stage modifiers
function PB.PetData.GetEffectiveStat(pet, stat)
    local base
    if     stat == "atk"   then base = pet.baseStats.attack
    elseif stat == "spatk" then base = pet.baseStats.spatk
    elseif stat == "def"   then base = pet.baseStats.defense
    elseif stat == "spdef" then base = pet.baseStats.spdef
    elseif stat == "spd"   then base = pet.baseStats.speed
    else return 1 end

    -- Burn halves physical attack
    if stat == "atk" and pet.status == "burn" then
        base = math.floor(base * 0.5)
    end
    -- Paralysis halves speed
    if stat == "spd" and pet.status == "paralysis" then
        base = math.floor(base * 0.5)
    end

    local stage = pet.stages[stat] or 0
    if stage > 0 then
        return math.floor(base * (2 + stage) / 2)
    elseif stage < 0 then
        return math.floor(base * 2 / (2 - stage))
    end
    return base
end
