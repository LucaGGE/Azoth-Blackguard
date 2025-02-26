-- This file contains all of the game's Effects, the modules that build powers scroll to
-- bottom to find the EFFECT_TABLE that links to all the valid effects because of how Power
-- is structured, all these funcs need (target, input) even when (target) is useless

function poison(target, input)
    print(target.name .. " gets poisoned for the first time")
    -- applies a tag to entity.effects that will activate and get 'consumed' after x turns
    -- when an effect only has immediate effect or for the first application,
    -- the effect is immediately applied by the function
    table.insert(target.effects, EffectTag(target, input, 3, poisoned))
end

function poisoned(target, input)
    print(target.name .. " is poisoned")
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
