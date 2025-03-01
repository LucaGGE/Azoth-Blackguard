-- This file contains all of the game's Effects, the modules that build powers scroll to
-- bottom to find the EFFECT_TABLE that links to all the valid effects because of how Power
-- is structured, all these funcs need (target, input) even when (target) is useless
-- NOTE: effects rely on death_check() function found in util.lua, to avoid code repetition

function poison(target, input)
    print("Poisoning: " .. target.name)
    -- applies a tag to entity.effects that will activate and get 'consumed' after x turns
    -- when an effect only has immediate effect or for the first application,
    -- the effect is immediately applied by the function
    table.insert(target.effects, EffectTag(target, input, dice_roll("1d3+2"), poisoned))
end

-- applied as a multiple-turns duration effect by poison()
function poisoned(target, input)
    print(target.name .. " is poisoned")
    death_check(target, "1", "got killed by poison")
end

function slash(target, input)
    -- NOTE: to reference, you need a table. With ... .stats["hp"] you'll get a copy!
    local target_stats = target.components["stats"].stats
    
    print(target.name .. " is slashed")

    death_check(target, input, "was slaughtered")  
    table.insert(target.effects, EffectTag(target, input, dice_roll("3d3"), bleed))
end

function bleed(target, input)
    local target_hp = target.components["stats"].stats["hp"]

    death_check(target, "1d2", "bled to death")
end

function str_effect(target, input)
    console_event(input .. " " .. target.name .. "!")
end

-- valid effects for the that can be applied to entities with consequence
EFFECTS_TABLE = {
    ["poison"] = poison,
    ["slash"] = slash,
    ["str"] = str_effect
}
