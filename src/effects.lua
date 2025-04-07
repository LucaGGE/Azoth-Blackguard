--[[
    This file contains all of the game's Effects, the modules that build powers.
    EFFECT_TABLES links to all the valid effects.
    Because of how Power is structured, all these funcs need (target, input) even
    when (target) is useless.
    NOTE WELL: *effects* are just functions that can apply EffectTags.
    EffectTags are classes that apply *effects* for x turns.
    NOTE: effects rely on death_check() func to avoid code repetition!
]]--

-- effects influence entities in a variety of ways and are assigned by 'Power' comp.
-- Effects are validated by EFFECTS_TABLE and executed by apply_effect() func.
Effect = Object:extend()
function Effect:new(input_effects)
    self.active_effects = {}

    -- immediately add optional effects and effect immunities on comp creation
    self:add(input_effects)
end

function Effect:add(input_effects)
    -- improve code ligibility with this variable
    local active_fxs = self.active_effects

    for i, effect in ipairs(input_effects) do
        local new_fx = str_slicer(effect, "=", 1)
        -- checking that first arg is a valid effect
        if not EFFECTS_TABLE[new_fx[1]] then
            error_handler(
                'In component "Effect" tried to input invalid effect, ignored'
            )
            goto continue
        end
        -- checking if entity is assigned as immune to an effect
        if new_fx[2] == "immune" then
            active_fxs[new_fx[1]] = new_fx[2]
        end
        -- checking if entity is immune to effect and in case skip rest of code
        if active_fxs[new_fx[1]] == "immune" then
            print("Entity is immune to "..new_fx[1])
            goto continue
        end
        -- checking if an effect is assigned permanent
        if new_fx[2] == "permanent" then
            -- some effects can be given as permanent effects
            active_fxs[new_fx[1]] = new_fx[2]
        end
        -- check if permanent and therefore cannot be modified, in case skip to end
        if new_fx[1] == "permanent" then
            print("Effect is permanent and therefore its duration cannot be modified normally")
            goto continue
        end
        -- checking if second arg is a valid number and assigning it
        if new_fx[2]:match("%d") then
            new_fx[2] = tonumber(new_fx[2])
            -- transforming possibly nil values to arithmetic values
            if active_fxs[new_fx[1]] == nil then
                active_fxs[new_fx[1]] = 0
            end
            --[[
                Code below translates to:
                'active_fxs[effect_name] duration = duration + modifier'
                NOTE: this can receive a negative value, reducing effect duration!
            ]]--
            active_fxs[new_fx[1]] = active_fxs[new_fx[1]] + new_fx[2]
        else
            error_handler('In component "Effect" tried to assign invalid value to effect, ignored')
        end

        ::continue::
    end
end

-- this is called each turn while the effect persists
-- also kills the effect class if nothing is active anymore
function Effect:activate(owner)
    for i,effect in ipairs(self.active_effects) do
        if effect == "immune" then
            goto continue
        end

        -- apply effect, since validity is already checked on Effect:add()
        apply_effect(owner, i)

        -- reduce effect duration by 1 and eventually kill it (if not permanent)
        if effect ~= "permanent" then
            self.active_effects[i] = self.active_effects[i] - 1
            if self.active_effects[i] <= 0 then self.active_effects[i] = nil end
        end

        ::continue::
    end
end

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

    success, damage = death_check(target, input, "slash", "was slaughtered")

    if success then
        -- the higher the slash damage, the longer the target will bleed
        table.insert(target.effects, EffectTag(target, input, dice_roll("3d3+"..damage), bleed))
    end
end

function bludgeon(target, input)
    local success, damage

    success, damage = death_check(target, input, "bludgeon", "was pulverized")
end

function pierce(target, input)
    local success, damage

    success, damage = death_check(target, input, "pierce", "was massacred")
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
    if target.comp["description"] then
        target_str = target.comp["description"].string
    end

    if target.comp["secret"] then
        target_str = target.comp["secret"].string
    end

    console_event(
        input .. " " .. target_str .. "!", {[1] = 1, [2] = 0.97, [3] = 0.44}
    )
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
    local target_stats = target.comp["stats"].stat

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
    if target.tile == new_tile then target.tile = target.og_tile return true end
    if target.tile == target.og_tile then target.tile = new_tile return true end

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
    print("Tile restored to: " .. target.og_tile)
    target.tile = target.og_tile
end

--[[
    This powerful effect changes physical properties of Entities.
    Currently only used to add/remove 'Obstacle' component, more complexity will
    require a decision table and not simple if statements.
]]--
function phys_change(target, property)
    if property == "obstacle" then
        if target.comp["obstacle"] then
            target.comp["obstacle"] = nil
        else
            target.comp["obstacle"] = Obstacle()
        end
    end
end