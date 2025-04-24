--[[
    This file contains all of the game's Effects, the modules that build powers.
    EFFECT_TABLES links to all the valid effects.
    Because of how Power is structured, all these funcs need (owner, target,
    activator, input) even when one or more of these are useless.
    Activator is often = nil as it generally corresponds to target.
    NOTE WELL: *effects* are just functions that can apply EffectTags.
    EffectTags are classes that apply *effects* for x turns.
    NOTE: effects rely on death_check() func to avoid code repetition!
]]--

--[[
    List of all the Effects functions
]]

function poison(target, input)
    print("Poisoning: " .. target.name)
    -- poison doens't apply damage per se, but it applies a damaging EffectTag
    table.insert(target.effects, EffectTag(target, input, dice_roll("1d3+2"), poisoned))
end

-- applied as a multiple-turns duration effect by poison()
function poisoned(target, input)
    print(target.name .. " is poisoned")
    death_check(target, "1", "poison", "got killed by poison")
end

function slash(target, input)
    local success, damage

    success, damage = death_check(target, input, "slash", "hath been slaughtered","sfx_death_sla")

    if success then
        -- the higher the slash damage, the longer the target will bleed
        table.insert(target.effects, EffectTag(target, input, dice_roll("3d3+"..damage), bleed))
    end
end

function bludgeon(target, input)
    local success, damage

    success, damage = death_check(target, input, "bludgeon", "hath been crushed","sfx_death_blu")
end

function pierce(target, input)
    local success, damage

    success, damage = death_check(target, input, "pierce", "hath been massacred", "sfx_death_pie")
end

function hemorrage(target, input)
    print(target.name)
    -- bleed duration is established by input
    table.insert(target.effects, EffectTag(target, input, dice_roll(input), bleed))
end

-- this is only called by EffetTag class
function bleed(target, input)
    local success

    -- if player is suffering effect, warn him
    effect_player_check(target, "is bleeding")

    success, _ = death_check(target, "1", "bleeding", "hath bled to death", "sfx_death_ble")

    return success
end

-- this effect is used to describe on console the action performed by a power
function action_str(target, input)
    local target_str = target.name
    local color = {[1] = 1, [2] = 0.97, [3] = 0.44}

    -- check if target alive, to avoid printing an action after its death
    if target.alive == false then
        return false
    end
            
    -- as usual, favor Entity description (or secret) to Entity name
    if target.comp["description"] then
        target_str = target.comp["description"].string
    end

    if target.comp["secret"] then
        target_str = target.comp["secret"].string
    end

    console_event(target_str .. " " .. input .. "!", color)
end

function event_effect(target, input)
    local color = {[1] = 0.5, [2] = 0.83, [3] = 0.9}

    console_event(input, color)
end

function sfx_play(target, input)
    print("Playing sound: " .. input)

    -- if valid, play eventual sound
    if SOUNDS[input] then
        play_sound(SOUNDS[input])
    else
        error_handler("Trying to play invalid sound effect: " .. input)
    end
end

function stat_gold(target, input)
    local target_stats = target.comp["stats"].stat
    local base_color = {0.28, 0.46, 0.73}
    local flash_color = {1, 1, 1, 1}

    -- give feedback to eventual trigger that Entity has no stats or 'gold' stat
    if not target_stats or not target_stats["gold"] then
        return false
    end
    
    target_stats["gold"] = target_stats["gold"] + dice_roll(input)

    print(target.name .. " gold has been changed: " .. input)

    -- flashing gold color. Activating a tween state isn't necessary, since it's
    -- always the same target that flashes, unlike the console messages
    g.gold_rgb = flash_color
    g.cnv_ui = ui_manager_play()

    -- flash white gold value on player's UI
    Timer.tween(TWEENING_TIME, {}):finish(function ()
        g.gold_rgb = base_color
        g.cnv_ui = ui_manager_play()
    end)

    return true
end

-- simple function swapping between two tiles, depending on the current one.
function tile_switch(target, input)
    -- swap current target tile with other tile
    if target.tile == input then target.tile = target.og_tile return true end
    if target.tile == target.og_tile then target.tile = input return true end

    -- if neither is true, then target.tile has been changed in unexpected way
    print("Warning: the Entity has been morphed and is now unable to tile_switch until de-morphed")
    return false
end

-- changing Entity's tile to a new one
function tile_change(target, input)
    target.tile = input
end

-- restoring Entity's tile to original one
function tile_restore(target, input)
    print("Tile restored to: " .. target.og_tile)
    target.tile = target.og_tile
end

--[[
    This powerful effect changes physical properties of Entities.
    Currently only used to add/remove 'Obstacle' component, more complexity will
    require a decision table and not simple if statements.
]]--
function phys_change(target, input)
    if input == "obstacle" then
        if target.comp["obstacle"] then
            target.comp["obstacle"] = nil
        else
            target.comp["obstacle"] = Obstacle()
        end
    end
end

function cmd_func(target, input)
    local target_use = target.comp["usable"] and target.comp["usable"].uses[input]

    -- check if input given to usable comp is linked to a power or not
    if not target_use then
        print("No power associated with action performed to linked entity")

        return false
    end

    -- activate target power, feeding only owner arg (the target)
    target.powers[target_use]:activate(target, nil, nil)
end

-- note that call_power can only input its target arg to another power, in case
-- owner/activator are needed, it won't be useful 
function call_power(target, input)
    if not target.powers[input] then
        print("Trying to call power with call_power effect, but no input-named power found")
    end

    target.powers[input]:activate(target, nil, nil)
end

function mutagen_apply(target, input, owner)
    if not owner.comp["mutagen"] then
        error_handler('Trying to mutagen_apply, but effect owner has no "mutagen" component')
        return false
    end

    -- feed target, owner.id to store unique set of modifiers, and modifiers table
    stat_update(target, owner.id, owner.comp["mutagen"].modificators)

    return true
end

function mutagen_remove(target, input, owner)
    print("mutagen_remove() inputs:")
    print(target.name)
    print(owner.name)
    print("------------------------")

    -- feed target, owner.id to identify unique set of modifiers, and nil
    stat_update(target, owner.id, nil)

    return true
end