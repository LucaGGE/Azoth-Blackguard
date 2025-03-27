--[[
    Implemented components. NOTE: some will be checked for when a blueprint is created (i.e. npc, player),
    as they will be added to special groups, needed to avoid searching for specific components each time
    an event is fired (i.e. when Player gives input, or the Player position).
]]

-- this is needed during dynamic code generation, since loadstring() is limited to global variables
code_reference = nil

-- this stores all the legal movement-tile_type pairings
-- (see TILES_VALID_FEATURES in util.lua)
local pairings = {
    ["walk"] = "ground",
    ["swim"] = "liquid",
    ["climb"] = "climbable",
    ["phase"] = "solid",
    ["fly"] = "untraversable"
}

-- note this is NOT found in BLUEPRINTS_TABLE, as it is restricted to the game menu
Player = Object:extend()
function Player:new()
    -- players are automatically part of this group
    self.group = "players"
    self.action_state = nil
    self.valid_input = "qwertyuiopasdfghjklzxcvbnmspace"
    self.string = "" -- stores player input for all action_modes
    -- this variable contains all the movement inputs key-values for keypad and keyboard, with key = (row, column)
    self.movement_inputs = {
        ["kp7"] = {-1,-1}, ["q"] = {-1,-1},
        ["kp8"] = {-1,0}, ["w"] = {-1,0},
        ["kp9"] = {-1,1}, ["e"] = {-1,1},
        ["kp6"] = {0,1}, ["d"] = {0,1},
        ["kp3"] = {1,1}, ["c"] = {1,1},
        ["kp2"] = {1,0}, ["x"] = {1,0},
        ["kp1"] = {1,-1}, ["z"] = {1,-1},
        ["kp4"] = {0,-1}, ["a"] = {0,-1},
        ["kp5"] = {0, 0}, ["s"] = {0, 0}
    }
end

function Player:input_management(entity, key)
    if key == "escape" then 
        self.action_state = nil
        self.string = ""
        console_cmd(nil)

        return false
    end

    if not self.action_state then
        -- checking if player is trying to use a hotkey
        if not self.movement_inputs[key] and not self.action_state then
            -- note that hotkeys allow access only to a few states
            -- also note the difference between 'self' (this comp) and 'entity' (the player entity)
            return player_commands(self, key)
        end

        -- check if player has inventory open, to avoid undesired movement input
        if g.view_inventory then
            return false
        end
    
        -- check if player is skipping turn (always possible, even without a mov comp)
        if self.movement_inputs[key][1] == 0 and self.movement_inputs[key][2] == 0 then
            love.audio.stop(SOUNDS["wait"])
            love.audio.play(SOUNDS["wait"])
            return true
        end

        -- 'Movable' component can be modified/added/removed during gameplay, so always check
        if not entity.components["movable"] then
            print("INFO: The entity does not contain a movement component")
            return false
        end

        -- if no guard statements were activated, player is legally trying to move
        return entity.components["movable"]:move_entity(entity, self.movement_inputs[key])
    end

    -- managing self.action_state mode of input  
    if IO_DTABLE[self.action_state] then
        return IO_DTABLE[self.action_state](self, entity, key)
    end

    -- if no valid input was received for the mode, return false
    print("Called IO_DTABLE[self.action_state] where self.action_state is an invalid key!")
    return false
end

Movable = Object:extend()
function Movable:new(optional_args)
    self.movement_type = {}
    for i,v in ipairs(optional_args) do
        -- adding movement abilities
        table.insert(self.movement_type, v)
    end
end

--[[
    NOTE: if something can move, it can attack. Moving against an entity = attacking it.
    This also means that something can have a movable component but no movement_type,
    and it can still attack - think of a living tree that can bash players with its branches
    but cannot move around!
]]
function Movable:move_entity(entity, direction)
    local target_cell
    local relevant_tiles = {} -- if moving diagonally, check if adjacent cells are transversable
    local row_movement = entity.cell["grid_row"] + direction[1]
    local column_movement = entity.cell["grid_column"] + direction[2]
    local score_to_succeed = 7
    local successful_attack

    -- making sure that the Player isn't trying to move out of g.grid
    if column_movement > g.grid_x or column_movement <= 0 or row_movement > g.grid_y or row_movement <= 0 then
        target_cell = nil
        print("Trying to move out of g.grid boundaries")
        return false
    end

    -- once we are sure the cell exists and is part of the g.grid, store it as target_cell
    target_cell = g.grid[entity.cell["grid_row"] + direction[1]][entity.cell["grid_column"] + direction[2]]

    -- checking for additional tiles to check, since diagonal mov requires entity to be able to traverse all of them
    if direction[1] ~= 0 and direction[2] ~= 0 then
        -- since movement is diagonal, add to relevant_tiles the adjacent tiles
        local new_target_cell
        new_target_cell = g.grid[entity.cell["grid_row"]][entity.cell["grid_column"] + direction[2]]
        table.insert(relevant_tiles, TILES_FEATURES_PAIRS[new_target_cell.index])
        new_target_cell = g.grid[entity.cell["grid_row"] + direction[1]][entity.cell["grid_column"]]
        table.insert(relevant_tiles, TILES_FEATURES_PAIRS[new_target_cell.index])
    end

    -- now checking if tile feature is compatible with movement abilities
    table.insert(relevant_tiles, TILES_FEATURES_PAIRS[target_cell.index])
    for i, tile_type in ipairs(relevant_tiles) do
        local can_traverse = false
        for i2, mov_type in ipairs(self.movement_type) do
            if pairings[mov_type] == tile_type or pairings[mov_type] == "wiggle" then
                can_traverse = true
                break
            end
        end
        -- if even one cell isn't compatible with entity mov, entity cannot interact with it
        if not can_traverse then
            print("Incompatible tile terrain in path for entity")
            return false
        end 
    end

    -- check if player is dealing with an obstacle Entity, not an occupant
    if target_cell.entity and target_cell.entity.components["obstacle"] then
        print("Cell is already occupied by: " .. target_cell.entity.id)
        return false
    end

    -- checking if there are entities on the target_cell. These always have precedence of interaction
    if target_cell.occupant then
        -- a lack of controller means the player is dealing with an object entity, not a creature entity
        if not target_cell.occupant.controller then
            print("Cell is already occupied by: " .. target_cell.occupant.id)
            return false
        end

        -- moving against another entity = attack, if they are part of different groups or the special "self" group
        if entity.controller.group ~= "self" and entity.controller.group == target_cell.occupant.controller.group then
            print("Entity interacts with teammate")
            return true
        end

        if entity.controller.group == "players" and target_cell.occupant.controller.nature == "civilized" then
            print("Player dialogues with civilized creature")
            return true -- this will actually lead to a dialogue func() that will return true/false
        end

        -- checking if entity has stats and can take damage
        if not target_cell.occupant.components["stats"] then
            print("NPC has no Stats component")
            return false
        end

        local target_stats = target_cell.occupant.components["stats"].stats
        if not target_stats["hp"] then
            print("This NPC has no HP and cannot die")
            return false
        end

        -- if target is invisible, you need to roll a lower number
        if target_cell.occupant.components["invisible"] then
            print("Trying to hit invisible entity, success when: roll < 4")
            score_to_succeed = 4
        end

        -- dices get rolled to identify successful hit and eventual damage
        successful_attack = dice_roll("1d12+1", score_to_succeed)
        
        if successful_attack then 
            love.audio.stop(SOUNDS["hit_blow"])
            love.audio.play(SOUNDS["hit_blow"])
            for power_tag, power_class in pairs(entity.powers) do
                power_class:activate(target_cell.occupant)
            end
        else
            love.audio.play(SOUNDS["hit_miss"])
        end

        if target_stats["hp"] <= 0 then
            target_stats["hp"] = 0
            -- entity will be removed from render_group and cell automatically in StatePlay:refresh()
            target_cell.occupant.alive = false
            -- if a player just died, save all deceased's relevant info in cemetery for Game Over screen
            if target_cell.occupant.components["player"] then
                local deceased = {["player"] = target_cell.occupant.name,
                ["killer"] = entity.name,
                ["loot"] = target_cell.occupant.components["stats"].stats["gold"],
                ["place"] = "Black Swamps"
                }
                table.insert(g.cemetery, deceased)
                -- send a 'game over' string to console in red color
                console_event(deceased["player"] .. " got slain by " .. deceased["killer"], {[1] = 0.93, [2] = 0.18, [3] = 0.27})
            end
        end

        return true
    end

    -- if no occupants are found in target cell, you're good to go
    entity.cell["cell"].occupant = nil -- freeing old cell
    entity.cell["grid_row"] = entity.cell["grid_row"] + direction[1]
    entity.cell["grid_column"] = entity.cell["grid_column"] + direction[2]
    entity.cell["cell"] = target_cell -- storing new cell
    entity.cell["cell"].occupant = entity -- occupying new cell
    
    -- playing sound based on tile type
    love.audio.stop(SOUNDS[TILES_FEATURES_PAIRS[target_cell.index]])
    love.audio.play(SOUNDS[TILES_FEATURES_PAIRS[target_cell.index]])

    -- lastly, check if there's an entity in the new cell
    if not target_cell.entity then
        return true
    end

    -- see if the entity is an exit
    if target_cell.entity.components["exit"] then
        target_cell.entity.components["exit"]:activate(target_cell.entity, entity)
        return true
    end

    -- see if entity is has trigger component
    if target_cell.entity.components["trigger"] and target_cell.entity.components["trigger"].triggeroncollision then
        -- trigger may work or not, but entity still moved, so return true
        target_cell.entity.components["trigger"]:activate(target_cell.entity, entity)
        return true
    end

    -- if a non-reactive, non-NPC, non-Player, non-Obstacle Entity is in target cell, simply ignore 
    return true
end

Npc = Object:extend()
function Npc:new(args)
    -- assigning important NPC variables thanks to an initial table
    local variables_group = {
        ["group"] = true,
        ["enemies"] = {},
        ["nature"] = true,
        ["sight"] = true,
        ["hearing"] = true
    }
    for i, var in ipairs(args) do
        local new_var = strings_separator(var, "=", 1)
        -- if it is a valid table variable, assign values to it
        if not variables_group[new_var[1]] then
            goto continue
        end
        -- "enemies" is the only 'array' variable 
        if new_var[1] == "enemies" then
            for k, values in ipairs(new_var) do
                -- first new_var value is always index name
                if k ~= 1 then
                    table.insert(variables_group[new_var[1]], values)
                end
            end
        else
            variables_group[new_var[1]] = new_var[2]
            if new_var[3] then
                error_handler('Trying to assign multiple values to a NPC variable. Only "enemies" can take multiple args.')
            end
        end
        ::continue::
    end

    self.group = variables_group["group"]
    self.enemies = variables_group["enemies"]
    self.nature = variables_group["nature"]
    self.sight = tonumber(variables_group["sight"])
    self.hearing = tonumber(variables_group["hearing"])
    self.target = false -- stores current locked target
end

function Npc:activate(owner)
    -- if NPC cannot move, skip turn
    if not owner.components["movable"] then
        return false
    end

    -- choose path of action depending on nature
    return ai_behavior(owner, self)
end

Trap = Object:extend()
function Trap:new()
end

-- for all the entities that are not Players but occupy it entirely (trees, boulders...)
Obstacle = Object:extend()
function Obstacle:new()

end

-- this comp warns the game when an entity behaves in a trigger volume fashion
Trigger = Object:extend()
function Trigger:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    self.destroyontrigger = string_to_bool[args[1]]
    self.triggeroncollision = string_to_bool[args[2]]
    self.event_string = args[3]
end

function Trigger:activate(owner, entity)  
    -- check if owner Entity has a dedicated power flagged as 'trigger'
    if owner.powers["trigger"] then
        owner.powers["trigger"]:activate(entity)
    else
        print("Blank trigger: a destroyontrigger Entity has no 'trigger' power to activate")
    end

    -- print trigger event string (i.e. 'A trap activates!')
    if self.event_string then
        console_event(entity.name .. " " .. self.event_string)
    end
    
    -- if owner is to 'destroyontrigger', destroy it
    if self.destroyontrigger then
        -- will be removed from render_group and cell automatically in StatePlay:refresh()
        owner.alive = false
    end
end

-- Pickup is a 'flag' class, where its only utility is to let the game know an entity can be picked up
Pickup = Object:extend()
function Pickup:new()
end

-- Usable is a for all objects that can be used in some way and then trigger an event
Usable = Object:extend()
function Usable:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    local key_power
    self.uses = {}
    self.destroyonuse = string_to_bool[args[1]]
    for i, arg in ipairs(args) do
        if i == 1 then
            self.destroyonuse = string_to_bool[arg]
            goto continue
        end

        key_power = strings_separator(arg, "=", 1)
        if not key_power then
            print("Warning: blank Usable component has no key-action couple")
            return false
        end
        self.uses[key_power[1]] = key_power[2]

        ::continue::
    end
end

-- to have simple 'use' working, have a power named 'use'
function Usable:activate(target, input_entity, input_key)
    local key = input_key or "use"
    local entity = input_entity

    -- trigger always hits activating Entity, even if linked comp is present
    if target.components["trigger"] then
        target.components["trigger"]:activate(target, entity)
    end

    -- if Entity is destroyontrigger, don't bother with rest of code
    if not target.alive then
        return false
    end

    if not self.uses[key] then
        console_event("Nothing doth happen")
    end

    if not target.powers[self.uses[key]] then
        error_handler("Usable comp has valid key-power couple called, but no corresponding power")

        return false
    end

    -- activate target power
    target.powers[self.uses[key]]:activate(target, entity)
    -- if destroyonuse, destroy used object (useful for consumables)
    if self.destroyonuse then
        target.alive = false
    end

    -- if self.uses[key] ~= 'linked', no need to proceed
    if self.uses[key] ~= "linked" then
        print("Power does not call for linked activation")
        return true
    end
    
    -- search for linked comp and store eventual linked Entity
    if target.components["linked"] then
        print("Linked component was found")
        local row, column = target.components["linked"]:activate(target)
        row = tonumber(row)
        column = tonumber(column)
        -- check immediately for NPC/Player
        entity = g.grid[row][column] and g.grid[row][column].occupant or false
        -- if absent, check for Entity
        if not entity then entity = g.grid[row][column].entity or false end
    else
        -- no linked component, return true
        return true
    end

    -- if linked but Entity is missing in cell, nothing happened and return true
    if not entity then
        console_event("The target is absent")

        return true
    end

    if not entity.powers["linked"] then
        print("WARNING: linked Entity has no dedicated 'linked' power")

        return true
    end

    -- at this point we know everything is in check, proceed
    entity.powers["linked"]:activate(entity)

    return true
end

-- StatChange class is useful for things like gold or traps, since they change player's stats
StatChange = Object:extend()
function StatChange:new(args)
    self.stat = args[1]
    self.change = args[2]
    self.sound = args[3]
end

function StatChange:activate(entity)
    -- entities without the stat of interest won't be affected
    if entity.components["stats"].stats[self.stat] then
        code_reference = entity.components["stats"].stats

        -- creating final string for code conversion
        local codeblock = 'code_reference["' .. self.stat .. '"]'
        local code_script = codeblock .. "=" .. codeblock .. "+" .. self.change

        print("Script executed: "..code_script)

        -- creating function from string and executing it
        local f = loadstring(code_script); f()
        -- resetting global code_reference to nil
        code_reference = nil
        -- play eventual sound
        if self.sound and SOUNDS[self.sound] then
            love.audio.stop(SOUNDS[self.sound])
            love.audio.play(SOUNDS[self.sound])
        end

        -- return successful statchange
        return true
    else
        return false
    end
end

Exit = Object:extend()
function Exit:new(args)
    -- string to print on level change
    self.event_string = args[1]
end

-- Simple class to jump between levels or from game to menu (game end)
function Exit:activate(owner, entity)
    console_event(self.event_string)
    if entity.components["player"] then
        -- the entity's name indicates the level to load
        if owner.name ~= "menu" then
            g.game_state:exit()
            print("Exit id: "..owner.id)
            print("Level name: "..owner.name)
            g.game_state:init(owner.name, false)
        else
            g.game_state = StateMenu()
            g.game_state:init()
        end
    end
end

-- this contains all the entity's stats
-- NPCs need this comp or they won't have hp = they will be immortal
-- if a Player doesn't have it, the system automatically adds it with hp = 1, gold = 0
Stats = Object:extend()
function Stats:new(stats_table)
    self.stats = {}
    for i, stat in ipairs(stats_table) do
        local new_stat = strings_separator(stat, "=", 1)
        -- automatically convert numerical stats to numbers
        if new_stat[2]:match("%d") then
            new_stat[2] = tonumber(new_stat[2])
        end
        -- code below translates as "self.stats[stat_name] = stat_value"
        self.stats[new_stat[1]] = new_stat[2]
    end
end

-- this component stores resistances and immunity to effects
Profile = Object:extend()
function Profile:new(input_table)
    self.profile = {}
    for i, stat in ipairs(input_table) do
        local new_stat = strings_separator(stat, "=", 1)
        -- automatically convert numerical stats to numbers
        if new_stat[2]:match("%d") then
            new_stat[2] = tonumber(new_stat[2])
        end
        -- code below translates as "self.profile[stat_name] = stat_value"
        self.profile[new_stat[1]] = new_stat[2]
    end
end

-- for all entities that are invisible by default (i.e. traps, invisible creatures)
-- simple 'tag' component telling system 'do not draw me by default'
Invisible = Object:extend()
function Invisible:new()
end

--[[
    Simple component that stores a key and removes 'locked' component from an Entity
    with corresponding name, i.e. if name = door_a45, remove 'locked' from Entity with
    name = door_a45. Can also used to activate golems, unlock quests, etc.
]]--
Key = Object:extend()
function Key:new()
end

-- for all Entities that can store items (i.e. Players, NPCs, chests, libraries...)
Inventory = Object:extend()
function Inventory:new(arg)
    self.items = {}
    self.spaces = 0 -- available spaces
    self.capacity = 0 -- max number of spaces

    -- setting Inventory's capacity as n of Entities
    if not arg[1] or tonumber(arg[1]) > 26 then
        error_handler("Inventory comp has number of spaces > 26 or none, set to 26")
        self.spaces = tonumber(arg[1])
        self.capacity = tonumber(arg[1])
    else
        self.spaces = tonumber(arg[1])
        self.capacity = tonumber(arg[1])
    end
end

function Inventory:add(item)
    if self.spaces > 0 then
        local item_ref = item.name

        if item.components["description"] then
            item_ref = item.components["description"].string
        end

        if item.components["secret"] then
            item_ref = item.components["secret"].string
        end

        self.spaces = self.spaces - 1
        table.insert(self.items, item)
        console_event("Thee pick up " .. item_ref)
        item.alive = false

        return true
    else
        console_event("Thy inventory is full")

        return false
    end
end

function Inventory:remove(item)
    for i, stored_item in ipairs(self.items) do
        if stored_item:is(item) then
            table.remove(self.items, i)
            print("Removing object from inventory...")
        end
    end
    print("Releasing object on ground...")
end

-- for all Entities that can equip Equipable Entities, matches Equipable comp tags
-- with own tags (i.e. Equipable on: horns works with Slots : horns)
Slots = Object:extend()
function Slots:new(args)
    -- slot is available if == true and ~= Entity
    self.slots = {}
    for _,slot in ipairs(args) do
        print("->->-> "..slot)
        -- adding all input slots from args (true = available)
        self.slots[slot] = "empty"
    end
end

--[[
    For all Entities that can be equipped (i.e. rings, amulets, crowns...),
    need to know in which slot they're supposed to fit (i.e. head, hand, tentacle...)
    and multiple suitable slots are accepted (i.e. right hand, left hand...).
    Also note that once equipped, objects will trigger/apply effects.
    The last simply artificially changes Player's characteristics.
]]
Equipable = Object:extend()
function Equipable:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    -- cursed objects cannot be normally unequipped
    self.cursed = string_to_bool[args[1]]
    self.suitable_slots = {}
    self.slot_reference = false
    -- now remove first arg, as it becomes useless
    table.remove(args, 1)

    for i, slot in ipairs(args) do
        -- adding all compatible slots for an Equipable
        table.insert(self.suitable_slots, slot)
    end
end

function Equipable:equip(owner, target)
    target.tile = self.appearance

    if not owner.powers["equip"] then
        print("Warning: trying to activate equip power, but none is found")
        return false
    end

    owner.powers["equip"]:activate(target)
    return true
end

function Equipable:unequip(owner, target)
    if owner.components["equipable"].cursed then
        console_event("Thy item is cursed and may not be removed!", {0.6, 0.2, 1})
        return false
    end

    if not owner.powers["unequip"] then
        print("Warning: trying to activate unequip power, but none is found")
        return false
    end

    owner.powers["unequip"]:activate(target)
    return true
end

-- this component allows entities to be subjected through a variety of effects give by the Power comp
-- these effects are validated by EFFECTS_TABLE and executed by apply_effect() function
Effect = Object:extend()
function Effect:new(input_effects)
    self.active_effects = {}

    -- immediately add optional effects and effect immunities on comp creation
    self:add(input_effects)
end

function Effect:add(input_effects)
    for i, effect in ipairs(input_effects) do
        local assigned_effect = strings_separator(effect, "=", 1)
        -- checking that first arg is a valid effect
        if not EFFECTS_TABLE[assigned_effect[1]] then
            error_handler('In component "Effect" tried to input invalid effect, ignored')
            goto continue
        end
        -- checking if entity is assigned as immune to an effect
        if assigned_effect[2] == "immune" then
            self.active_effects[assigned_effect[1]] = assigned_effect[2]
        end
        -- checking if entity is immune to effect (will skip rest of loop after new immune assignment)
        if self.active_effects[assigned_effect[1]] == "immune" then
            print("Entity is immune to "..assigned_effect[1])
            goto continue
        end
        -- checking if an effect is assigned permanent
        if assigned_effect[2] == "permanent" then
            -- some effects can be given as permanent effects
            self.active_effects[assigned_effect[1]] = assigned_effect[2]
        end
        -- check if permanent and therefore cannot be modified (will skip rest of loop after new permanent assignment)
        if assigned_effect[1] == "permanent" then
            print("Effect is permanent and therefore its duration cannot be modified normally")
            goto continue
        end
        -- checking if second arg is a valid number and assigning it
        if assigned_effect[2]:match("%d") then
            assigned_effect[2] = tonumber(assigned_effect[2])
            -- transforming possibly nil values to arithmetic values
            if self.active_effects[assigned_effect[1]] == nil then self.active_effects[assigned_effect[1]] = 0 end
            -- code below translates as "self.active_effects[effect_name] = existing_value + new_value"
            -- please note that this can be given a negative value, reducing effect duration
            self.active_effects[assigned_effect[1]] = self.active_effects[assigned_effect[1]] + assigned_effect[2]
        else
            error_handler('In component "Effect" tried to assign invalid value to effect, ignored')
        end

        ::continue::
    end
end

-- this is called each turn when the effect component is present, and kills the comp if nothing is active anymore
function Effect:activate(owner)
    for i,effect in ipairs(self.active_effects) do
        if effect == "immune" then
            goto continue
        end

        -- apply effect, since validity is already checked on Effect:add()
        apply_effect(owner, i)

        -- if the effect is not permanent, reduce duration by 1 and eventually cancel effect
        if effect ~= "permanent" then
            self.active_effects[i] = self.active_effects[i] - 1
            if self.active_effects[i] <= 0 then self.active_effects[i] = nil end
        end

        ::continue::
    end
end

-- same as 'locked', but requires 'say' interaction to unlock
Sealed = Object:extend()
function Sealed:new(input)

end

function Sealed:activate(target, entity, player_comp)
    if target.name == player_comp.string then
        console_event("Thou dost unseal it!")
        if target.components["trigger"] then
            target.components["trigger"]:activate(target, entity)
        end

        -- if Entity gets successfully unsealed, remove 'seled' comp
        target.components["sealed"] = nil
        player_comp.string = ""
        return true
    end

    console_event("There is no response")

    return false
end

-- when is requested to unlock from console, searches in requester inventory for an
-- Entity with a 'key' comp with corresponding name.
-- As the 'key' component, name = Entity.name
Locked = Object:extend()
function Locked:new(input)

end

function Locked:activate(target, entity)
    if entity.components["inventory"] then
        for _, item in ipairs(entity.components["inventory"].items) do
            if item.components["key"] and item.name == target.name then
                console_event("Thou dost unlock it!")
                if target.components["trigger"] then
                    target.components["trigger"]:activate(target, entity)
                end

                -- if Entity was successfully unlocked, remove 'Locked' comp
                target.components["locked"] = nil
                return true
            end
        end
        console_event("Thou dost miss the key")
        
        return true
    end
    error_handler("Entity without invetory is trying to use key to unlock")
    return false
end

-- simple comp that prevents acces to Entity name, id or description
-- can only removed by effect 
Secret = Object:extend()
function Secret:new(input)
    self.string = input[1]
end

Description = Object:extend()
function Description:new(input)
    self.string = input[1]
end

-- linked Entities will activate other Entities in specific row, column
-- position of other Entities is defined by linked Entity name that
-- indicates the cell to search for
Linked = Object:extend()
function Linked:new(input)

end

-- note how changing the Entity's name will change its cell of interest
function Linked:activate(owner)
    local row_column = strings_separator(owner.name, "-", 1)
    local row = row_column[1]
    local column = row_column[2]

    return row, column
end