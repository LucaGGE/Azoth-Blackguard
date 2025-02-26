-- This file contains all of the game's Effects, the modules that build powers scroll to
-- bottom to find the EFFECT_TABLE that links to all the valid effects because of how Power
-- is structured, all these funcs need (target, input) even when (target) is useless

function poison(target, input)
    print("Poisoning: " .. target.name)
    -- applies a tag to entity.effects that will activate and get 'consumed' after x turns
    -- when an effect only has immediate effect or for the first application,
    -- the effect is immediately applied by the function
    table.insert(target.effects, EffectTag(target, input, dice_roll("1d3+2"), poisoned))
end

-- applied as a multiple-turns duration effect
function poisoned(target, input)
    local target_hp = target.components["stats"].stats["hp"]
    -- cannot damage an Entity without hp
    if not target_hp then return false end

    print(target.name .. " is poisoned")
    target_hp = target_hp - 3
    if target_hp <= 0 then
        target.alive = false
        console_event(target.name .. " got killed by poison", {[1] = 1, [2] = 1, [3] = 0})
    end
end

function slash(target, input)
    print(target.name .. " is slashed")
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
