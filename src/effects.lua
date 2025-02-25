-- This file contains all of the game's Effects, the modules that build powers scroll to
-- bottom to find the EFFECT_TABLE that links to all the valid effects because of how Power
-- is structured, all these funcs need (target, input) even when (target) is useless

function poison(target, input)
    print(target)
end

function slash(target, input)
    print(target)
end

function str_effect(target, input)
    print(input)
end

-- valid effects for the that can be applied to entities with consequence
EFFECTS_TABLE = {
    ["poison"] = poison,
    ["slash"] = slash,
    ["str"] = str_effect
}
