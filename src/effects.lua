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
    local target_str = target.name
            
    -- as usual, favor Entity description (or secret) to Entity name
    if target.components["description"] then
        target_str = target.components["description"].string
    end

    if target.components["secret"] then
        target_str = target.components["secret"].string
    end

    console_event(input .. " " .. target_str .. "!", {[1] = 1, [2] = 0.97, [3] = 0.44})
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

-- simple function swapping between two tiles, depending on the current one.
function tile_switch(target, new_tile)
    -- swap current target tile with other tile
    if target.tile == new_tile then target.tile = target.base_tile return true end
    if target.tile == target.base_tile then target.tile = new_tile return true end

    -- if neither is true, then target.tile has been changed in unexpected way
    print("Warning: the Entity has been morphed and is now unable to tile_switch until de-morphed")
    return false
end

-- changing Entity's tile to a new one
function tile_change(target, new_tile)
    target.tile = new_tile
end

-- restoring Entity's tile to original one
function tile_restore(target)
    print("Tile restored to: " .. target.base_tile)
    target.tile = target.base_tile
end

-- this effect changes physical properties of Entities. Currently only used to add/remove
-- 'Obstacle' component, more complexity will require a decision table and not if statements.
function phys_change(target, property)
    if property == "obstacle" then
        if target.components["obstacle"] then
            target.components["obstacle"] = nil
        else
            target.components["obstacle"] = Obstacle()
        end
    end
end

-- TO MOVE IN CONSTANTS ---------- TODO ---------- TODO ---------- TODO ---------- TODO ---------- TODO ---------- TODO ---------- TODO
-- valid effects for the that can be applied to entities with consequence
EFFECTS_TABLE = {
    ["poison"] = poison,
    ["slash"] = slash,
    ["str"] = str_effect,
    ["statgold"] = stat_gold,
    ["sfx"] = sfx_play,
    ["tileswitch"] = tile_switch,
    ["tilechange"] = tile_change,
    ["tilerestore"] = tile_restore,
    ["physchange"] = phys_change
}
