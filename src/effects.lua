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
    death_check(target, "1", "poison", "got killed by poison")
end

function slash(target, input)
    local success, damage

    success, damage = death_check(target, input, "slash", "was slaughtered")

    if success then
        -- the higher the slash damage, the longer the target will bleed
        table.insert(target.effects, EffectTag(target, input, dice_roll("3d3+"..damage), bleed))
    end
end

function bleed(effect_tag, target, input)
    local success

    success, _ = death_check(target, "1", "bleeding", "bled to death")

    -- if target is immune to EffectTag, then set its duration to 0
    if not success then effect_tag.duration = 0 end
end

function str_effect(target, input)
    console_event(input .. " " .. target.name .. "!")
end

function sfx_play(target, input)
    print("Playing sound: " .. input)

    -- if valid, play eventual sound
    if SOUNDS[input] then
        love.audio.stop(SOUNDS[input])
        love.audio.play(SOUNDS[input])
    else
        error_handler("Trying to play invalid sound effect: " .. input)
    end
end

function stat_gold(target, input)
    local target_stats = target.components["stats"].stats

    -- give feedback to eventual trigger that Entity has no stats or 'gold' stat
    if not target_stats or not target_stats["gold"] then
        return false
    end
    
    target_stats["gold"] = target_stats["gold"] + dice_roll(input)

    print(target.name .. " gold has been changed: " .. input)
    return true
end

-- valid effects for the that can be applied to entities with consequence
EFFECTS_TABLE = {
    ["poison"] = poison,
    ["slash"] = slash,
    ["str"] = str_effect,
    ["statgold"] = stat_gold,
    ["sfx"] = sfx_play
}
