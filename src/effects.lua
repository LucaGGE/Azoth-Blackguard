-- This file contains all of the game's Effects, the modules that build powers
-- scroll to bottom to find the EFFECT_TABLE that links to all the valid effects

function poison(target, input)
    print(target)
end

-- valid effects for the that can be applied to entities with consequence
EFFECTS_TABLE = {
    ["poison"] = poison
}
