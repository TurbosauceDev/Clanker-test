-- Full Gen 6+ 18-type Pokemon effectiveness chart
-- Values: 2 = super effective, 0.5 = not very effective, 0 = immune, 1 = normal (default)

PB.Types = {
    NORMAL   = 1,  FIRE     = 2,  WATER    = 3,  ELECTRIC = 4,
    GRASS    = 5,  ICE      = 6,  FIGHTING = 7,  POISON   = 8,
    GROUND   = 9,  FLYING   = 10, PSYCHIC  = 11, BUG      = 12,
    ROCK     = 13, GHOST    = 14, DRAGON   = 15, DARK     = 16,
    STEEL    = 17, FAIRY    = 18,
}

PB.TypeNames = {
    "Normal","Fire","Water","Electric","Grass","Ice",
    "Fighting","Poison","Ground","Flying","Psychic","Bug",
    "Rock","Ghost","Dragon","Dark","Steel","Fairy",
}

-- Hex colors per type for UI
PB.TypeColors = {
    "a8a878", -- Normal
    "f08030", -- Fire
    "6890f0", -- Water
    "f8d030", -- Electric
    "78c850", -- Grass
    "98d8d8", -- Ice
    "c03028", -- Fighting
    "a040a0", -- Poison
    "e0c068", -- Ground
    "a890f0", -- Flying
    "f85888", -- Psychic
    "a8b820", -- Bug
    "b8a038", -- Rock
    "705898", -- Ghost
    "7038f8", -- Dragon
    "705848", -- Dark
    "b8b8d0", -- Steel
    "ee99ac", -- Fairy
}

-- chart[attackType][defenseType] = multiplier
-- Only non-1 values are stored; missing = 1
local T = PB.Types
local chart = {}
for i = 1, 18 do chart[i] = {} end

local function se(atk, def) chart[atk][def] = 2   end  -- super effective
local function nv(atk, def) chart[atk][def] = 0.5 end  -- not very effective
local function im(atk, def) chart[atk][def] = 0   end  -- immune

-- Normal
im(T.NORMAL, T.GHOST)
-- Fire
se(T.FIRE, T.GRASS) se(T.FIRE, T.ICE)   se(T.FIRE, T.BUG)   se(T.FIRE, T.STEEL)
nv(T.FIRE, T.FIRE)  nv(T.FIRE, T.WATER) nv(T.FIRE, T.ROCK)  nv(T.FIRE, T.DRAGON)
-- Water
se(T.WATER, T.FIRE)   se(T.WATER, T.GROUND) se(T.WATER, T.ROCK)
nv(T.WATER, T.WATER)  nv(T.WATER, T.GRASS)  nv(T.WATER, T.DRAGON)
-- Electric
se(T.ELECTRIC, T.WATER)    se(T.ELECTRIC, T.FLYING)
nv(T.ELECTRIC, T.ELECTRIC) nv(T.ELECTRIC, T.GRASS)  nv(T.ELECTRIC, T.DRAGON)
im(T.ELECTRIC, T.GROUND)
-- Grass
se(T.GRASS, T.WATER)  se(T.GRASS, T.GROUND) se(T.GRASS, T.ROCK)
nv(T.GRASS, T.FIRE)   nv(T.GRASS, T.GRASS)  nv(T.GRASS, T.POISON)
nv(T.GRASS, T.FLYING) nv(T.GRASS, T.BUG)    nv(T.GRASS, T.DRAGON)  nv(T.GRASS, T.STEEL)
-- Ice
se(T.ICE, T.GRASS)  se(T.ICE, T.GROUND) se(T.ICE, T.FLYING) se(T.ICE, T.DRAGON)
nv(T.ICE, T.FIRE)   nv(T.ICE, T.WATER)  nv(T.ICE, T.ICE)    nv(T.ICE, T.STEEL)
-- Fighting
se(T.FIGHTING, T.NORMAL) se(T.FIGHTING, T.ICE)  se(T.FIGHTING, T.ROCK)
se(T.FIGHTING, T.DARK)   se(T.FIGHTING, T.STEEL)
nv(T.FIGHTING, T.POISON) nv(T.FIGHTING, T.FLYING) nv(T.FIGHTING, T.PSYCHIC)
nv(T.FIGHTING, T.BUG)    nv(T.FIGHTING, T.FAIRY)
im(T.FIGHTING, T.GHOST)
-- Poison
se(T.POISON, T.GRASS) se(T.POISON, T.FAIRY)
nv(T.POISON, T.POISON) nv(T.POISON, T.GROUND) nv(T.POISON, T.ROCK) nv(T.POISON, T.GHOST)
im(T.POISON, T.STEEL)
-- Ground
se(T.GROUND, T.FIRE)  se(T.GROUND, T.ELECTRIC) se(T.GROUND, T.POISON)
se(T.GROUND, T.ROCK)  se(T.GROUND, T.STEEL)
nv(T.GROUND, T.GRASS) nv(T.GROUND, T.BUG)
im(T.GROUND, T.FLYING)
-- Flying
se(T.FLYING, T.GRASS)    se(T.FLYING, T.FIGHTING) se(T.FLYING, T.BUG)
nv(T.FLYING, T.ELECTRIC) nv(T.FLYING, T.ROCK)     nv(T.FLYING, T.STEEL)
-- Psychic
se(T.PSYCHIC, T.FIGHTING) se(T.PSYCHIC, T.POISON)
nv(T.PSYCHIC, T.PSYCHIC)  nv(T.PSYCHIC, T.STEEL)
im(T.PSYCHIC, T.DARK)
-- Bug
se(T.BUG, T.GRASS)    se(T.BUG, T.PSYCHIC) se(T.BUG, T.DARK)
nv(T.BUG, T.FIRE)     nv(T.BUG, T.FIGHTING) nv(T.BUG, T.FLYING)
nv(T.BUG, T.GHOST)    nv(T.BUG, T.STEEL)    nv(T.BUG, T.FAIRY)
-- Rock
se(T.ROCK, T.FIRE)    se(T.ROCK, T.ICE)  se(T.ROCK, T.FLYING) se(T.ROCK, T.BUG)
nv(T.ROCK, T.FIGHTING) nv(T.ROCK, T.GROUND) nv(T.ROCK, T.STEEL)
-- Ghost
se(T.GHOST, T.GHOST)   se(T.GHOST, T.PSYCHIC)
im(T.GHOST, T.NORMAL)
nv(T.GHOST, T.DARK)
-- Dragon
se(T.DRAGON, T.DRAGON)
nv(T.DRAGON, T.STEEL)
im(T.DRAGON, T.FAIRY)
-- Dark
se(T.DARK, T.GHOST)   se(T.DARK, T.PSYCHIC)
nv(T.DARK, T.FIGHTING) nv(T.DARK, T.DARK) nv(T.DARK, T.FAIRY)
-- Steel
se(T.STEEL, T.ICE)   se(T.STEEL, T.ROCK)    se(T.STEEL, T.FAIRY)
nv(T.STEEL, T.FIRE)  nv(T.STEEL, T.WATER)   nv(T.STEEL, T.ELECTRIC) nv(T.STEEL, T.STEEL)
-- Fairy
se(T.FAIRY, T.FIGHTING) se(T.FAIRY, T.DRAGON)  se(T.FAIRY, T.DARK)
nv(T.FAIRY, T.FIRE)     nv(T.FAIRY, T.POISON)  nv(T.FAIRY, T.STEEL)

PB.TypeChart = chart

function PB.GetEffectiveness(attackType, defenseType)
    local row = PB.TypeChart[attackType]
    if not row then return 1 end
    return row[defenseType] or 1
end

function PB.EffectivenessText(mult)
    if mult == 0   then return "|cff888888It doesn't affect...|r"
    elseif mult >= 4 then return "|cffff4444It's extremely effective!|r"
    elseif mult >= 2 then return "|cffffaa00It's super effective!|r"
    elseif mult <= 0.25 then return "|cff6688ffIt's not very effective...|r"
    elseif mult < 1  then return "|cff6688ffIt's not very effective...|r"
    end
    return nil
end
