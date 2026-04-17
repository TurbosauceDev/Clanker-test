-- Move database: ~4 moves per Pokemon type
-- category: "Physical" | "Special" | "Status"
-- effect: optional table describing secondary effects
--   status: "burn"|"poison"|"paralysis"|"sleep"|"freeze"|"flinch"
--   chance: 0-100 (percent chance of effect triggering)
--   self_stat / foe_stat: { stat="atk"|"def"|"spatk"|"spdef"|"spd", stages=N }
--   drain: fraction of damage healed back to attacker
--   recharge: must skip next turn after use
--   heal: fraction of max HP restored (status move)
--   multi: {min=N, max=N} hits 2-5 times

local T = PB.Types

PB.Moves = {
    -- =========== NORMAL ===========
    ["Tackle"] = {
        type=T.NORMAL, category="Physical", power=40, accuracy=100, pp=35,
    },
    ["Body Slam"] = {
        type=T.NORMAL, category="Physical", power=85, accuracy=100, pp=15,
        effect={ status="paralysis", chance=30 },
    },
    ["Hyper Beam"] = {
        type=T.NORMAL, category="Special", power=150, accuracy=90, pp=5,
        effect={ recharge=true },
    },
    ["Quick Attack"] = {
        type=T.NORMAL, category="Physical", power=40, accuracy=100, pp=30,
        priority=1,
    },
    ["Recover"] = {
        type=T.NORMAL, category="Status", power=0, accuracy=100, pp=10,
        effect={ heal=0.5 },
    },

    -- =========== FIRE ===========
    ["Ember"] = {
        type=T.FIRE, category="Special", power=40, accuracy=100, pp=25,
        effect={ status="burn", chance=10 },
    },
    ["Flamethrower"] = {
        type=T.FIRE, category="Special", power=90, accuracy=100, pp=15,
        effect={ status="burn", chance=10 },
    },
    ["Fire Blast"] = {
        type=T.FIRE, category="Special", power=110, accuracy=85, pp=5,
        effect={ status="burn", chance=10 },
    },
    ["Will-O-Wisp"] = {
        type=T.FIRE, category="Status", power=0, accuracy=85, pp=15,
        effect={ status="burn", chance=100 },
    },

    -- =========== WATER ===========
    ["Water Gun"] = {
        type=T.WATER, category="Special", power=40, accuracy=100, pp=25,
    },
    ["Surf"] = {
        type=T.WATER, category="Special", power=90, accuracy=100, pp=15,
    },
    ["Hydro Pump"] = {
        type=T.WATER, category="Special", power=110, accuracy=80, pp=5,
    },
    ["Aqua Jet"] = {
        type=T.WATER, category="Physical", power=40, accuracy=100, pp=20,
        priority=1,
    },

    -- =========== ELECTRIC ===========
    ["Thunder Shock"] = {
        type=T.ELECTRIC, category="Special", power=40, accuracy=100, pp=30,
        effect={ status="paralysis", chance=10 },
    },
    ["Thunderbolt"] = {
        type=T.ELECTRIC, category="Special", power=90, accuracy=100, pp=15,
        effect={ status="paralysis", chance=10 },
    },
    ["Thunder"] = {
        type=T.ELECTRIC, category="Special", power=110, accuracy=70, pp=10,
        effect={ status="paralysis", chance=30 },
    },
    ["Thunder Wave"] = {
        type=T.ELECTRIC, category="Status", power=0, accuracy=90, pp=20,
        effect={ status="paralysis", chance=100 },
    },

    -- =========== GRASS ===========
    ["Vine Whip"] = {
        type=T.GRASS, category="Physical", power=45, accuracy=100, pp=25,
    },
    ["Razor Leaf"] = {
        type=T.GRASS, category="Physical", power=55, accuracy=95, pp=25,
        effect={ crit_boost=true },
    },
    ["Solar Beam"] = {
        type=T.GRASS, category="Special", power=120, accuracy=100, pp=10,
        effect={ charge=true },
    },
    ["Leech Seed"] = {
        type=T.GRASS, category="Status", power=0, accuracy=90, pp=10,
        effect={ status="leech_seed", chance=100 },
    },

    -- =========== ICE ===========
    ["Ice Shard"] = {
        type=T.ICE, category="Physical", power=40, accuracy=100, pp=30,
        priority=1,
    },
    ["Ice Beam"] = {
        type=T.ICE, category="Special", power=90, accuracy=100, pp=10,
        effect={ status="freeze", chance=10 },
    },
    ["Blizzard"] = {
        type=T.ICE, category="Special", power=110, accuracy=70, pp=5,
        effect={ status="freeze", chance=10 },
    },
    ["Icy Wind"] = {
        type=T.ICE, category="Special", power=55, accuracy=95, pp=15,
        effect={ foe_stat={ stat="spd", stages=-1 }, chance=100 },
    },

    -- =========== FIGHTING ===========
    ["Karate Chop"] = {
        type=T.FIGHTING, category="Physical", power=50, accuracy=100, pp=25,
        effect={ crit_boost=true },
    },
    ["Low Kick"] = {
        type=T.FIGHTING, category="Physical", power=65, accuracy=100, pp=20,
    },
    ["Close Combat"] = {
        type=T.FIGHTING, category="Physical", power=120, accuracy=100, pp=5,
        effect={ self_stat={ stat="def", stages=-1 }, chance=100 },
    },
    ["Bulk Up"] = {
        type=T.FIGHTING, category="Status", power=0, accuracy=100, pp=20,
        effect={ self_stat={ stat="atk", stages=1 }, chance=100 },
    },

    -- =========== POISON ===========
    ["Poison Sting"] = {
        type=T.POISON, category="Physical", power=15, accuracy=100, pp=35,
        effect={ status="poison", chance=30 },
    },
    ["Sludge Bomb"] = {
        type=T.POISON, category="Special", power=90, accuracy=100, pp=10,
        effect={ status="poison", chance=30 },
    },
    ["Toxic"] = {
        type=T.POISON, category="Status", power=0, accuracy=90, pp=10,
        effect={ status="toxic", chance=100 },
    },
    ["Acid"] = {
        type=T.POISON, category="Special", power=40, accuracy=100, pp=30,
        effect={ foe_stat={ stat="spdef", stages=-1 }, chance=10 },
    },

    -- =========== GROUND ===========
    ["Mud Shot"] = {
        type=T.GROUND, category="Special", power=55, accuracy=95, pp=15,
        effect={ foe_stat={ stat="spd", stages=-1 }, chance=100 },
    },
    ["Earthquake"] = {
        type=T.GROUND, category="Physical", power=100, accuracy=100, pp=10,
    },
    ["Earth Power"] = {
        type=T.GROUND, category="Special", power=90, accuracy=100, pp=10,
        effect={ foe_stat={ stat="spdef", stages=-1 }, chance=10 },
    },
    ["Sand Attack"] = {
        type=T.GROUND, category="Status", power=0, accuracy=100, pp=15,
        effect={ foe_stat={ stat="acc", stages=-1 }, chance=100 },
    },

    -- =========== FLYING ===========
    ["Gust"] = {
        type=T.FLYING, category="Special", power=40, accuracy=100, pp=35,
    },
    ["Air Slash"] = {
        type=T.FLYING, category="Special", power=75, accuracy=95, pp=15,
        effect={ status="flinch", chance=30 },
    },
    ["Hurricane"] = {
        type=T.FLYING, category="Special", power=110, accuracy=70, pp=10,
        effect={ status="paralysis", chance=30 },
    },
    ["Tailwind"] = {
        type=T.FLYING, category="Status", power=0, accuracy=100, pp=15,
        effect={ self_stat={ stat="spd", stages=2 }, chance=100 },
    },

    -- =========== PSYCHIC ===========
    ["Confusion"] = {
        type=T.PSYCHIC, category="Special", power=50, accuracy=100, pp=25,
        effect={ status="confusion", chance=10 },
    },
    ["Psybeam"] = {
        type=T.PSYCHIC, category="Special", power=65, accuracy=100, pp=20,
        effect={ status="confusion", chance=10 },
    },
    ["Psychic"] = {
        type=T.PSYCHIC, category="Special", power=90, accuracy=100, pp=10,
        effect={ foe_stat={ stat="spdef", stages=-1 }, chance=10 },
    },
    ["Calm Mind"] = {
        type=T.PSYCHIC, category="Status", power=0, accuracy=100, pp=20,
        effect={ self_stat={ stat="spatk", stages=1 }, chance=100 },
    },

    -- =========== BUG ===========
    ["Bug Bite"] = {
        type=T.BUG, category="Physical", power=60, accuracy=100, pp=20,
    },
    ["X-Scissor"] = {
        type=T.BUG, category="Physical", power=80, accuracy=100, pp=15,
    },
    ["Bug Buzz"] = {
        type=T.BUG, category="Special", power=90, accuracy=100, pp=10,
        effect={ foe_stat={ stat="spdef", stages=-1 }, chance=10 },
    },
    ["String Shot"] = {
        type=T.BUG, category="Status", power=0, accuracy=95, pp=40,
        effect={ foe_stat={ stat="spd", stages=-2 }, chance=100 },
    },

    -- =========== ROCK ===========
    ["Rock Throw"] = {
        type=T.ROCK, category="Physical", power=50, accuracy=90, pp=15,
    },
    ["Rock Slide"] = {
        type=T.ROCK, category="Physical", power=75, accuracy=90, pp=10,
        effect={ status="flinch", chance=30 },
    },
    ["Stone Edge"] = {
        type=T.ROCK, category="Physical", power=100, accuracy=80, pp=5,
        effect={ crit_boost=true },
    },
    ["Ancient Power"] = {
        type=T.ROCK, category="Special", power=60, accuracy=100, pp=5,
        effect={ self_stat={ stat="all", stages=1 }, chance=10 },
    },

    -- =========== GHOST ===========
    ["Lick"] = {
        type=T.GHOST, category="Physical", power=30, accuracy=100, pp=30,
        effect={ status="paralysis", chance=30 },
    },
    ["Shadow Ball"] = {
        type=T.GHOST, category="Special", power=80, accuracy=100, pp=15,
        effect={ foe_stat={ stat="spdef", stages=-1 }, chance=20 },
    },
    ["Hex"] = {
        type=T.GHOST, category="Special", power=65, accuracy=100, pp=10,
        -- doubles power if target has a status condition (handled in engine)
        effect={ double_if_status=true },
    },
    ["Destiny Bond"] = {
        type=T.GHOST, category="Status", power=0, accuracy=100, pp=5,
        effect={ status="destiny_bond", chance=100 },
    },

    -- =========== DRAGON ===========
    ["Dragon Breath"] = {
        type=T.DRAGON, category="Special", power=60, accuracy=100, pp=20,
        effect={ status="paralysis", chance=30 },
    },
    ["Dragon Pulse"] = {
        type=T.DRAGON, category="Special", power=85, accuracy=100, pp=10,
    },
    ["Outrage"] = {
        type=T.DRAGON, category="Physical", power=120, accuracy=100, pp=10,
        effect={ self_stat={ stat="confusion_lock", stages=1 }, chance=100 },
    },
    ["Dragon Dance"] = {
        type=T.DRAGON, category="Status", power=0, accuracy=100, pp=20,
        effect={ self_stat={ stat="atk_spd", stages=1 }, chance=100 },
    },

    -- =========== DARK ===========
    ["Bite"] = {
        type=T.DARK, category="Physical", power=60, accuracy=100, pp=25,
        effect={ status="flinch", chance=30 },
    },
    ["Crunch"] = {
        type=T.DARK, category="Physical", power=80, accuracy=100, pp=15,
        effect={ foe_stat={ stat="def", stages=-1 }, chance=20 },
    },
    ["Night Slash"] = {
        type=T.DARK, category="Physical", power=70, accuracy=100, pp=15,
        effect={ crit_boost=true },
    },
    ["Nasty Plot"] = {
        type=T.DARK, category="Status", power=0, accuracy=100, pp=20,
        effect={ self_stat={ stat="spatk", stages=2 }, chance=100 },
    },

    -- =========== STEEL ===========
    ["Metal Claw"] = {
        type=T.STEEL, category="Physical", power=50, accuracy=95, pp=35,
        effect={ self_stat={ stat="atk", stages=1 }, chance=10 },
    },
    ["Iron Head"] = {
        type=T.STEEL, category="Physical", power=80, accuracy=100, pp=15,
        effect={ status="flinch", chance=30 },
    },
    ["Flash Cannon"] = {
        type=T.STEEL, category="Special", power=80, accuracy=100, pp=10,
        effect={ foe_stat={ stat="spdef", stages=-1 }, chance=10 },
    },
    ["Iron Defense"] = {
        type=T.STEEL, category="Status", power=0, accuracy=100, pp=15,
        effect={ self_stat={ stat="def", stages=2 }, chance=100 },
    },

    -- =========== FAIRY ===========
    ["Fairy Wind"] = {
        type=T.FAIRY, category="Special", power=40, accuracy=100, pp=30,
    },
    ["Moonblast"] = {
        type=T.FAIRY, category="Special", power=95, accuracy=100, pp=15,
        effect={ foe_stat={ stat="spatk", stages=-1 }, chance=30 },
    },
    ["Dazzling Gleam"] = {
        type=T.FAIRY, category="Special", power=80, accuracy=100, pp=10,
    },
    ["Sweet Kiss"] = {
        type=T.FAIRY, category="Status", power=0, accuracy=75, pp=10,
        effect={ status="confusion", chance=100 },
    },
}

-- Moveset pool per WoW pet family (petTypeID 1-10 -> list of 4 move names)
-- WoW: 1=Humanoid 2=Dragonkin 3=Flying 4=Undead 5=Critter
--      6=Magic 7=Elemental 8=Beast 9=Aquatic 10=Mechanical
PB.FamilyMoves = {
    [1]  = { "Karate Chop", "Close Combat", "Bulk Up",       "Recover"       }, -- Humanoid -> Fighting
    [2]  = { "Dragon Breath","Dragon Pulse","Dragon Dance",  "Fire Blast"    }, -- Dragonkin -> Dragon
    [3]  = { "Gust",         "Air Slash",   "Hurricane",     "Tailwind"      }, -- Flying -> Flying
    [4]  = { "Lick",         "Shadow Ball", "Hex",           "Destiny Bond"  }, -- Undead -> Ghost
    [5]  = { "Tackle",       "Body Slam",   "Quick Attack",  "Recover"       }, -- Critter -> Normal
    [6]  = { "Confusion",    "Psychic",     "Calm Mind",     "Moonblast"     }, -- Magic -> Psychic/Fairy
    [7]  = { "Ember",        "Flamethrower","Fire Blast",    "Will-O-Wisp"   }, -- Elemental -> Fire
    [8]  = { "Bite",         "Crunch",      "Night Slash",   "Nasty Plot"    }, -- Beast -> Dark
    [9]  = { "Water Gun",    "Surf",        "Hydro Pump",    "Aqua Jet"      }, -- Aquatic -> Water
    [10] = { "Metal Claw",   "Iron Head",   "Flash Cannon",  "Iron Defense"  }, -- Mechanical -> Steel
}

-- Pokemon type assigned to each WoW pet family
PB.FamilyType = {
    [1]  = PB.Types.FIGHTING,
    [2]  = PB.Types.DRAGON,
    [3]  = PB.Types.FLYING,
    [4]  = PB.Types.GHOST,
    [5]  = PB.Types.NORMAL,
    [6]  = PB.Types.PSYCHIC,
    [7]  = PB.Types.FIRE,
    [8]  = PB.Types.DARK,
    [9]  = PB.Types.WATER,
    [10] = PB.Types.STEEL,
}
