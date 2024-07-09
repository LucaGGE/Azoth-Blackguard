--[[
    Implemented features. NOTE: some will be checked for when a blueprint is created (i.e. drawable, input...),
    as they will be added to special groups, needed to avoid searching for specific components each time
    an event is fired (i.e. when Player gives input, or the Player position).
    This is no different than looking for them each update, but much less computationally expensive.
--]]

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

-- note how this is not found in FEATURES_TABLE, as this is reserved for the game menu
Player = Object:extend()
function Player:new(optional_args)
    -- players are automatically part of this group
    self.group = "players"
    -- checking that numbers were input for Player variables, and converting them from strings
    self.hp = 1
    self.gold = 0
    self.inventory_size = 1

    -- checking if optional args are there, and in case convert them to numbers
    if optional_args[1] and optional_args[1]:match("%d") then self.hp = tonumber(optional_args[1]) end
    if optional_args[2] and optional_args[2]:match("%d") then self.gold = tonumber(optional_args[2]) end
    if optional_args[3] and optional_args[3]:match("%d") then self.inventory_size = tonumber(optional_args[3]) end
    self.inventory = {}
    if optional_args[4] then
        error_handler("Feeding to 'Player' component more than three args, additional args ignored")
    end
end

function Player:input_management(entity, key)
    -- input is handled this way: input received -> check and store component -> activate component
    -- this variable contains all the movement inputs key-values for keypad and keyboard, with key = (row, column)
    local movement_inputs = {
    ["kp7"] = {-1,-1}, ["t"] = {-1,-1},
    ["kp8"] = {-1,0}, ["y"] = {-1,0},
    ["kp9"] = {-1,1}, ["u"] = {-1,1},
    ["kp6"] = {0,1}, ["j"] = {0,1},
    ["kp3"] = {1,1}, ["m"] = {1,1},
    ["kp2"] = {1,0}, ["n"] = {1,0},
    ["kp1"] = {1,-1}, ["b"] = {1,-1},
    ["kp4"] = {0,-1}, ["g"] = {0,-1},
    ["kp5"] = "stay", ["h"] = "stay"
    }
    if movement_inputs[key] ~= nil then
        -- check if player is skipping turn
        if movement_inputs[key] ~= "stay" then
            -- Movable features can be modified/added/removed during gameplay, so always check
            if entity.features["movable"] then
                -- remember that Object:function() automatically feeds 'self' to func
                return entity.features["movable"]:move_entity(entity, movement_inputs[key])
            else
                print("INFO: The entity does not contain a movement component")
                return false
            end
        else
            -- player skipped turn, playing sound
            love.audio.stop(SOUNDS["wait"])
            love.audio.play(SOUNDS["wait"])
            return true
        end
    end
end

Movable = Object:extend()
function Movable:new(optional_args)
    self.movement_type = {}
    for i,v in ipairs(optional_args) do
        print(v)
        -- adding movement abilities
        table.insert(self.movement_type, v)
    end
end

--[[
    NOTE: if something can move, it can attack. Moving against an Entity = attacking it.
    This also means that something can have no mov features but if it is movable, it can
    still attack - think of a living tree that can bash players with its branches but
    cannot move around!
]]--
function Movable:move_entity(entity, direction)
    local target_cell
    local relevant_tiles = {}
    local can_traverse = false
    local row_movement = entity.cell["grid_row"] + direction[1]
    local column_movement = entity.cell["grid_column"] + direction[2]
    -- making sure that the Player isn't trying to move out of g.grid
    if column_movement > g.grid_x or column_movement <= 0 or row_movement > g.grid_y or row_movement <= 0 then
        target_cell = nil
        print("Trying to move out of g.grid boundaries")
        return false
    else
        -- once we are sure the cell exists and is part of the g.grid, store it as target_cell
        target_cell = g.grid[entity.cell["grid_row"] + direction[1]][entity.cell["grid_column"] + direction[2]]
    end

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
        can_traverse = false
        for i2, mov_type in ipairs(self.movement_type) do
            if pairings[mov_type] == tile_type then
                can_traverse = true
                break
            elseif pairings[mov_type] == "wiggle" then
                -- NOTE: wiggle is a special mov type that allows unmoving entities to interact with other
                -- entities, I.E. think of a living tree, stuck to the grund but able to hit with its branches
                can_traverse = true
            end
        end
        -- if even one cell isn't compatible with entity mov, entity cannot interact with it
        if not can_traverse then
            print("Incompatible tile terrain in path for entity")
            return false
        end 
    end    
    -- checking if there are entities on the target_cell. These always have precedence of interaction
    if target_cell.occupant ~= nil and can_traverse then
        -- a lack of controller means the player is dealing with an object entity, not a creature entity
        if target_cell.occupant.controller then
            -- moving against another entity = attack, if they are part of different groups or the special "self" group
            if entity.controller.group ~= target_cell.occupant.controller.group or entity.controller.group == "self" then
                -- checking if entity has stats and can take damage
                if target_cell.occupant.features["stats"] then
                    local target_stats = target_cell.occupant.features["stats"].stats
                    if target_stats["hp"] then
                        -- dices get rolled to identify successful hit and eventual damage
                        local successful_attack = dice_roll({1, 12, 1}, 7)
                        
                        -- entities without dice sets roll 1d1
                        local damage = dice_roll(entity.features["dies"].dies["atk"] or {1, 1})
                        target_stats["hp"] = target_stats["hp"] - (successful_attack and damage or 0)
                        if successful_attack then 
                            love.audio.stop(SOUNDS["hit_blow"])
                            love.audio.play(SOUNDS["hit_blow"])
                        else
                            love.audio.play(SOUNDS["hit_miss"])
                        end
                        if target_stats["hp"] <= 0 then
                            target_stats["hp"] = 0
                            -- entity will be removed from render_group automatically in StatePlay:Draw()
                            target_cell.occupant.alive = false
                            if target_cell.occupant.features["player"] then
                                local deceased = {["player"] = target_cell.occupant.name,
                                ["killer"] = entity.name,
                                ["loot"] = target_cell.occupant.features["stats"].stats["gold"],
                                ["place"] = "Black Swamps"
                                }
                                table.insert(g.cemetery, deceased)
                            end
                            target_cell.occupant = nil
                        end
                    else
                        print("This NPC has no HP and cannot die")
                    end
                else
                    print("NPC has no Stats component")
                end
                -- HERE CHECK IF ATTACKED ENTITY IS NPC, AND IN CASE REACT CONSEQUENTIALLY ---------------------------------------------------------------------
            else
                print("You order you teammate to do something")
            end
            return true
        elseif target_cell.occupant.features["block"] then
            print("Cell is already occupied by: "..target_cell.occupant.id)
            return false
        end
    end  
    -- self is a reference to the Entity's Movable() component
    if can_traverse then
        entity.cell["cell"].occupant = nil -- freeing old cell
        entity.cell["grid_row"] = entity.cell["grid_row"] + direction[1]
        entity.cell["grid_column"] = entity.cell["grid_column"] + direction[2]
        entity.cell["cell"] = target_cell
        target_cell.occupant = entity -- occupying new cell
        
        -- playing sound based on tile type
        love.audio.stop(SOUNDS[TILES_FEATURES_PAIRS[target_cell.index]])
        love.audio.play(SOUNDS[TILES_FEATURES_PAIRS[target_cell.index]])

        -- if there's an entity in the cell, compute it
        if target_cell.entity ~= nil then
            -- immediately check if that's a trigger and which effects it may have
            if target_cell.entity.features["trigger"] then
                if target_cell.entity.features["statchange"] then
                    target_cell.entity.features["statchange"]:activate(entity)
                elseif target_cell.entity.features["exit"] then
                    -- stepping into an exit means turn isn't valid and stuff has to be reset!
                    target_cell.entity.features["exit"]:activate(target_cell.entity)
                    return false
                end

                -- if entity is to destroyontrigger, destroy it
                if target_cell.entity.features["trigger"].destroyontrigger then
                    -- will be removed from render_group automatically in StatePlay:Draw()
                    target_cell.entity.alive = false
                    target_cell.entity = nil
                end
            end
        end

        return true
    else
        return false
    end
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
        -- if it is a valid variable, assign values to it
        if variables_group[new_var[1]] then
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
                    error_handler("Trying to assign multiple values to a NPC variable. 'enemies' is the only variable that can take multiple args.")
                end
            end
        end
    end

    self.group = variables_group["group"]
    self.enemies = variables_group["enemies"]
    self.nature = variables_group["nature"]
    self.sight = variables_group["sight"]
    self.hearing = variables_group["hearing"]
end

function Npc:activate(entity)
    if entity.features["movable"] then
        if self.nature == "aggressive" then
            local search_row = entity.cell["grid_row"] - 2
            local search_col

            -- searching for enemy entities in a square. This algorithm is temporary and badly designed.
            for i = 1, 5, 1 do
                search_col = entity.cell["grid_column"] - 2
                for j = 1, 5, 1 do
                    if search_col > g.grid_x or search_col <= 0 or search_row > g.grid_y or search_row <= 0 then
                        -- this code is in draft state... I beg thee pardon
                    else
                        local other_entity = g.grid[search_row][search_col].occupant
                        if other_entity then
                            other_entity = other_entity.features["npc"] or other_entity.features["player"]
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

                                entity.features["movable"]:move_entity(entity, direction)
                                return true
                            end
                        end
                    end
                    search_col = search_col + 1
                end
                search_row = search_row + 1
            end
        else
            --print("The NPC minds its business")
        end
    end
end

Trap = Object:extend()
function Trap:new()
end

Inventory = Object:extend()
function Inventory:new()
end

-- for all the Entities that are not Players but occupy it entirely (trees, boulders...)
Block = Object:extend()
function Block:new()
end

-- This comp warns the game when an entity behaves in a trigger volume fashion
Trigger = Object:extend()
function Trigger:new(args)
    self.destroyontrigger = args[1] -- THIS IS TEMPORARY. RIGHT NOW, IT TRANSLATES ANY FIRST ARG AS A "DESTROYONTRIGGER" VALIDATION <-----------------
end

StatChange = Object:extend()
function StatChange:new(args)
    self.stat = args[1]
    self.change = args[2]
    self.sound = args[3]
end

function StatChange:activate(entity, sound)
    if entity.features["player"] then
        code_reference = entity.features["stats"].stats
    end

    -- creating final string for code conversion
    local codeblock = 'code_reference["' .. self.stat .. '"]'
    local code_test = codeblock .. "=" .. codeblock .. "+" .. self.change

    print("Script executed: "..code_test)
    
    -- creating function from string and executing it
    local f = loadstring(code_test); f()
    code_reference = nil
    -- play eventual sound
    if self.sound and SOUNDS[self.sound] then
        love.audio.stop(SOUNDS[self.sound])
        love.audio.play(SOUNDS[self.sound])
    end
end

Exit = Object:extend()
function Exit:new()
end

function Exit:activate(owner)
    if owner.name ~= "menu" then
        g.game_state:exit()
        print("id "..owner.id)
        print("name "..owner.name)
        g.game_state:init(owner.name, false)
    else
        g.game_state = StateMenu()
        g.game_state:init()
    end
end

-- this contains all the Entity's stats
-- NPCs need this comp or they won't have hp = they will be immortal
-- if a Player doesn't hav it, the system automatically adds it with hp = 1, gold = 0
Stats = Object:extend()
function Stats:new(stats_table)
    self.stats = {}
    for i, stat in ipairs(stats_table) do
        local new_stat = strings_separator(stat, ":", 1)
        -- automatically convert numerical stats to numbers
        if new_stat[2]:match("%d") then
            new_stat[2] = tonumber(new_stat[2])
        end
        -- assign. below translates as "self.stats[stat_name] = stat_value"
        self.stats[new_stat[1]] = new_stat[2]
    end
end

Dies = Object:extend()
function Dies:new(dies_table)
    -- NOTE: TO DATE, die sets can contain only dies of the same type (d4, d6...)
    -- self.dies is a table of all of the entity's die sets
    self.dies = {}
    for i, stat in ipairs(dies_table) do
        -- new_set[1] == set name; new_set[2] == set
        local new_set = strings_separator(stat, ":", 1)
        -- set_values == all of the set's values but name
        local set_values = {}
        -- set_data == n of dies, type of die + (optional) modifier
        local set_data = strings_separator(new_set[2], "d", 1)

        set_values[1] = set_data[1]
        set_values[2] = set_data[2]

        --check for the presence of positive/negative modifiers
        local is_plus = string.find(set_values[2], "+")
        local is_minus = string.find(set_values[2], "-")

        -- (optional) modifier[1] == dice type, modifier[2] == modifier 
        if is_plus then
            local modifier = strings_separator(set_values[2], "+", 1)
            set_values[2] = modifier[1]
            set_values[3] = modifier[2]
        elseif is_minus then
            local modifier = strings_separator(set_values[2], "-", 1)
            set_values[2] = modifier[1]
            set_values[3] = modifier[2]
        end

        -- at last, assign new set to self.dies at name (new_set[1])
        self.dies[new_set[1]] = set_values
    end
end