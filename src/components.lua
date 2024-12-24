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
    self.valid_input = "qwertyuiopasdfghjklzxcvbnm"
    self.local_string = ""
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
        print("Action mode quit...")
        self.action_state = nil
        self.local_string = ""
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
    and it can still attack - think of a living tree that can bash players with its branches but
    cannot move around!
]]
function Movable:move_entity(entity, direction)
    local target_cell
    local relevant_tiles = {} -- if moving diagonally, check if adjacent cells are transversable
    local row_movement = entity.cell["grid_row"] + direction[1]
    local column_movement = entity.cell["grid_column"] + direction[2]

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
    -- checking if there are entities on the target_cell. These always have precedence of interaction
    if target_cell.occupant then
        -- a lack of controller means the player is dealing with an object entity, not a creature entity
        if not target_cell.occupant.controller then
            print("Cell is already occupied by: "..target_cell.occupant.id)
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

        -- dices get rolled to identify successful hit and eventual damage
        local score_to_succeed = 7
        local successful_attack = dice_roll({1, 12, 1}, score_to_succeed)
        
        -- entities without dice sets roll 1d1
        local damage = dice_roll(entity.components["dies"].dies["atk"] or {1, 1})
        target_stats["hp"] = target_stats["hp"] - (successful_attack and damage or 0)

        if successful_attack then 
            love.audio.stop(SOUNDS["hit_blow"])
            love.audio.play(SOUNDS["hit_blow"])
        else
            love.audio.play(SOUNDS["hit_miss"])
        end

        if target_stats["hp"] <= 0 then
            target_stats["hp"] = 0
            -- entity will be removed from render_group and cell automatically in StatePlay:refresh()
            target_cell.occupant.alive = false
            print("Player set as dead")
            -- if a player just died, save all deceased's relevant info in cemetery for Game Over screen
            if target_cell.occupant.components["player"] then
                local deceased = {["player"] = target_cell.occupant.name,
                ["killer"] = entity.name,
                ["loot"] = target_cell.occupant.components["stats"].stats["gold"],
                ["place"] = "Black Swamps"
                }
                table.insert(g.cemetery, deceased)
                -- send a 'game over' string to console in red color
                console_event(deceased["player"] .. " got slain by " .. deceased["killer"], {[1] = 1, [2] = 0, [3] = 0})
            else
                -- send a 'creature killed' string to console in visible color
                console_event(target_cell.occupant.name .. " got slain by " .. entity.name, {[1] = 1, [2] = 1, [3] = 0})
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
    if not target_cell.entity or not target_cell.entity.components["trigger"]
    or not target_cell.entity.components["trigger"].triggeroncollision then
        return true
    end

    -- check if that's a trigger. It may work or not, but entity still moved, so return true
    target_cell.entity.components["trigger"]:activate(target_cell.entity, entity)
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
        local new_var = strings_separator(var, ":", 1)
        -- if it is a valid table variable, assign values to it
        if not variables_group[new_var[1]] then
            goto continue
        end
        -- "enemies" is the only 'array' variable 
        if new_var[1] == "enemies" then
            for i2, values in ipairs(new_var) do
                -- first new_var value is always index name
                if i2 ~= 1 then
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
    self.sight = variables_group["sight"]
    self.hearing = variables_group["hearing"]
end

function Npc:activate(entity)
    -- this code is in draft state... I beg thee pardon
    if entity.components["movable"] then
        if self.nature == "aggressive" then
            local search_row = entity.cell["grid_row"] - 2
            local search_col

            -- searching for enemy entities in a square. This algorithm is temporary and badly designed.
            for i = 1, 5, 1 do
                search_col = entity.cell["grid_column"] - 2
                for j = 1, 5, 1 do
                    if search_col > g.grid_x or search_col <= 0 or search_row > g.grid_y or search_row <= 0 then
                        
                    else
                        local other_entity = g.grid[search_row][search_col].occupant
                        if other_entity then
                            other_entity = other_entity.components["npc"] or other_entity.components["player"]
                        end
                        if other_entity then
                            if other_entity.group ~= self.group then
                                -- reset other_entity to its initial value
                                other_entity = g.grid[search_row][search_col].occupant
                                local target_row = other_entity.cell["grid_row"]
                                local target_column = other_entity.cell["grid_column"]
                                local out_row
                                local out_col

                                if entity.cell["grid_row"] < target_row then
                                    out_row = 1
                                elseif entity.cell["grid_row"] == target_row then
                                    out_row = 0
                                else 
                                    out_row = -1 
                                end
                                if entity.cell["grid_column"] < target_column then
                                    out_col = 1
                                elseif entity.cell["grid_column"] == target_column then
                                    out_col = 0
                                else 
                                    out_col = -1 
                                end

                                local direction = {out_row, out_col}

                                entity.components["movable"]:move_entity(entity, direction)
                                return true
                            end
                        end
                    end
                    search_col = search_col + 1
                end
                search_row = search_row + 1
            end
        else
            --print("The NPC mids it own business")
        end
    end
end

Trap = Object:extend()
function Trap:new()
end

Inventory = Object:extend()
function Inventory:new()
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
    console_event(self.event_string)
    -- stepping into an exit means turn isn't valid and stuff has to be reset!
    if owner.components["exit"] then
        owner.components["exit"]:activate(owner, entity)
        return false
    end

    if owner.components["statchange"] then
        local trigger_fired = owner.components["statchange"]:activate(entity)
        -- if owner is to 'destroyontrigger', destroy it
        if owner.components["trigger"].destroyontrigger and trigger_fired then
            -- will be removed from render_group and cell automatically in StatePlay:refresh()
            owner.alive = false
        end

        -- if trigger was fired or not (ie critters cannot pick up gold), turn still counts
        return true
    end
end

-- Pickup is a 'flag' class, where its only utility is to let the game know an entity can be picked up
Pickup = Object:extend()
function Pickup:new()
end

function Pickup:activate(owner, entity)
    print("Adding item to entity's inventory/hands")
end

-- Usable is a for all objects that can be used in some way and then trigger an event
Usable = Object:extend()
function Usable:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    self.destroyonuse = string_to_bool[args[1]]
end

function Usable:activate(owner, entity)
    print("Object has been used")

    -- A DECISION TABLE IS NEEDED HERE, WHERE DEPENDING ON ARGS[] INPUT AN OBJECT, WHEN USED, WILL TRIGGER OR DO SOMETHING ELSE (REMEMBER TRIGGER/SCRIPT SEPARATION) -------
    if target.components["trigger"] then
        print("The object triggers!")
        target.components["trigger"]:activate(target, player)
        return true
    end

    -- if destroyonuse, destroy used object (useful for consumables)
    if self.destroyonuse then
        owner.alive = false
    end

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
function Exit:new()
end

-- Simple class to jump between levels or from game to menu (game end)
function Exit:activate(owner, entity)
    if entity.components["player"] then
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
        local new_stat = strings_separator(stat, ":", 1)
        -- automatically convert numerical stats to numbers
        if new_stat[2]:match("%d") then
            new_stat[2] = tonumber(new_stat[2])
        end
        -- code below translates as "self.stats[stat_name] = stat_value"
        self.stats[new_stat[1]] = new_stat[2]
    end
end

Dies = Object:extend()
function Dies:new(dies_table)
    -- NOTE: TO DATE, die sets can contain only dies of the same type (2d4, 3d6...)
    -- self.dies is a table of all of the entity's die sets
    self.dies = {}
    for i, stat in ipairs(dies_table) do
        -- new_set[1] == set name; new_set[2] == set
        local new_set = strings_separator(stat, ":", 1)
        -- set_values == all of the set's values but name
        local set_values = {}
        -- set_data == n of dies, type of die + (optional) modifier
        local set_data = strings_separator(new_set[2], "d", 1)

        -- check for the presence of positive/negative modifiers. This would mean
        -- that set_data[2] corresponds to a dice value like 4+1, or 6-2
        local is_plus = string.find(set_data[2], "+")
        local is_minus = string.find(set_data[2], "-")

        -- number of dies in set
        set_values[1] = set_data[1]

        -- (optional) modifier[1] == dice type, modifier[2] == modifier
        if is_plus then
            local modifier = strings_separator(set_data[2], "+", 1)
            set_values[2] = tonumber(modifier[1])
            set_values[3] = tonumber(modifier[2])
        elseif is_minus then
            local modifier = strings_separator(set_data[2], "-", 1)
            set_values[2] = tonumber(modifier[1])
            set_values[3] = tonumber(modifier[2]) * -1
        else
            set_values[2] = tonumber(set_data[2])
        end

        -- at last, assign new set to self.dies at name (new_set[1])
        self.dies[new_set[1]] = set_values
    end
end

-- for all entities that are invisible by default (i.e. traps, invisible creatures)
Invisible = Object:extend()
function Invisible:new()
end

-- simple component that stores a key and triggers an entity with corresponding name,
-- i.e. self.key_value = door_a45 triggers door entity with name = door_a45
-- can also used to activate golems, unlock quests, etc
Key = Object:extend()
function Key:new(arg)
    self.key_value = arg[1]
end

-- for all entities that can store items (i.e. Players, NPCs, chests, libraries...)
Inventory = Object:extend()
function Inventory:new(arg)
    -- setting Inventory's capacity as n of entities
    self.space = arg[1]
end

-- for all entities that can equip Equipable entities, matches Equipable comp tags
-- with own tags (i.e. Equipable on: horns works with Slots : horns)
Slots = Object:extend()
function Slots:new(args)
    self.slots = {}
    for i,v in ipairs(args) do
        -- adding all input slots from args
        table.insert(self.slots, v)
    end
end

--[[
    For all entities that can be equipped (i.e. rings, amulets, crowns...),
    need to know in which slot they're supposed to fit (i.e. head, hand, tentacle...)
    and multiple compatible slots are accepted (i.e. right hand, left hand...).
    Also note that once equipped, objects will trigger/statchange/apply effects.
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
    -- now remove the frist arg, as it becomes useless
    table.remove(args, 1)

    self.compatible_slots = {}

    for i,v in ipairs(args) do
        -- adding all compatible slots for an Equipable
        table.insert(self.compatible_slots, v)
    end
end

-- this component allows entities to be subjected through a variety of effects give by the Power comp
-- these effects are validated by EFFECTS_TABLE and executed by apply_effect() function
Effect = Object:extend()
function Effect:new(input_effects)
    print(input_effects)
    self.active_effects = {}

    -- immediately add optional effects and effect immunities on comp creation
    self:add(input_effects)
end

function Effect:add(input_effects)
    for i, effect in ipairs(input_effects) do
        local assigned_effect = strings_separator(effect, ":", 1)
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

-- this component is the one which will allow entities to apply effects to each other. The effects
-- available are dictated by EFFECTS_TABLE and are applied to individual entities after each turn 
Power = Object:extend()
function Power:new(input_effects)

end