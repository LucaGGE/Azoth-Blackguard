-- useful variables that get used often in the scope of util.lua
local TILESET_WIDTH = TILESET:getWidth()
local TILESET_HEIGHT = TILESET:getHeight()
local sprites_groups = {} -- for blueprints with random/semi-random sprites

-- simple, user-friendly error message handler
function error_handler(error_input_1, error_input_2)
    table.insert(g.error_messages, error_input_1 or "Triggered error handler without any message")
    if error_input_2 then
        table.insert(g.error_messages, error_input_2)
    end
end

-- this simple function returns all the optional arguments of components
function component_tags(tags)
    if not tags then return nil end
    local component_tags = {}

    for i,v in ipairs(tags) do
        -- avoiding first tag, as it is the id of the component!
        if i ~= 1 then
            table.insert(component_tags, v)
        end
    end

    return component_tags
end

--[[
    components_interface() links input comps and their args to actual components.
    Input components are found inside 'blueprints.csv'.
    Components are make Entities functional and active/reactive.
]]--
function components_interface(tags)
    -- tags[1] = component id, others (if present) are their arguments
    if not COMPONENTS_TABLE[tags[1]] then return nil end
    -- adding () to COMPONENTS_TABLE value, to turn it into class
    return COMPONENTS_TABLE[tags[1]](component_tags(tags))
end

function str_slicer(line, separator, pos)
    local line = line
    local separator = separator
    local pos = pos
    local results = {}

    -- parsing results for each line, until end of line
    while true do
        if not line then
            error_handler("ERROR READING CSV: Blank file/line")
            break
        end
        -- storing starting and end points between commas, updating pos value
        local start_point, end_point = string.find(line, separator, pos)
        if (start_point) then
            -- start_point - 1 is used since we do not want to store the sep. value,
            -- so we store from start/after a sep. to before the next sep.
            table.insert(results, string.sub(line, pos, start_point - 1))
            -- and then we update pos, so we can skip already stored values
            pos = end_point + 1
        else
            -- no separator found, end of file/line, use rest of value
            table.insert(results, string.sub(line, pos))
            -- then break, and loop to next line
            break  
        end                      
    end
    return results
end

--[[
    csv_reader() returns a 3D table in this fashion:
    'table[line number] = {line value 1, line value 2, ...}'
    Note that the error_handler is never called in csv_reader since if we call it in
    main.lua we can output some more info about the error.
]]
function csv_reader(input_csv, separator)
    -- this final table will contain all lines from the CSV
    local new_table = {}

    if not input_csv then
        new_table = "ERROR READING CSV: Missing input"
        return new_table
    end

    local file = io.open(input_csv, "r")

    if not file then
        new_table = "ERROR READING CSV: Invalid file/path"
        return new_table
    end

    local input_line = "nil"
    local separator = separator or "|"
    local count = 1

    io.input(file)
    -- reading line by line from CSV, starting from first char
    local pos = 1 -- start position in file
    for line in file:lines() do
        local results = str_slicer(line, separator, pos)
        -- reset all values for next line, and append result to return table
        pos = 1
        new_table[count] = results
        results = {}
        count = count + 1
    end
    io.close(file)

    -- returning results only if the whole operation went right
    return new_table
end

-- stores borders as unchanging images. Only stores for these UIs:
-- main menu, gameover and inventory.
function borders_manager()
    local new_border

    for i = 1, 3 do
        -- for each line in the csv, insert data in BORDERS = {} as images
        for j = 1, 2 do
            new_border = love.graphics.newQuad(
                TILE_SIZE * 2 * (j - 1) + (TILE_SIZE * 4 * (i - 1)), 0, TILE_SIZE * 2, TILE_SIZE * 2, 240, 80
            )
            table.insert(BORDERS[i], new_border)
        end

        for k = 1, 2 do
            new_border = love.graphics.newQuad(
                TILE_SIZE * 2 * (k - 1) + (TILE_SIZE * 4 * (i - 1)), TILE_SIZE * 2, TILE_SIZE * 2, TILE_SIZE * 2, 240, 80
            )
            table.insert(BORDERS[i], new_border)
        end
    end
    
    return true
end

function sprites_groups_manager()
    -- all sprites groups are managed by a single CSV file
    local sprites_groups_csv = csv_reader(FILES_PATH .. "sprites_groups.csv")

    -- check if operation went right; if not, activate error_handler
    if type(sprites_groups_csv) == "string" then
        error_handler(
            "The above error was triggered while trying to read sprites_groups.csv"
        )
        g.game_state:exit()
        g.game_state = StateFatalError()
        g.game_state:init()

        return false
    end

    for i, line in ipairs(sprites_groups_csv) do
        local current_group = {}
        local name = "" -- group name
        -- for each line in the csv, store its data in util.lua local sprites_groups
        current_group = str_slicer(line[1], ",", 1)
        for i2, value in ipairs(current_group) do
            -- first value is the group's name
            if i2 == 1 then
                name = value
                sprites_groups[name] = {}
                sprites_groups[name .. "_size"] = 0
            else
                table.insert(sprites_groups[name], tonumber(value))
                sprites_groups[name.."_size"] = sprites_groups[name.."_size"] + 1
            end
        end
    end
    
    return true
end

--[[
    Spawns all the Entities in a map.
    NOTE: players get spawned on spawn points and get *generated* only once, at game
    start, to avoid erasing their data. Both cases are found in map_generator() func
]]--
function entities_spawner(bp, loc_row, loc_col, name)
    local player_num = 1
    local is_pawn = false
    local is_npc = false
    local new_player = {
        ["entity"] = nil,
        ["player_comp"] = nil
    }

    -- now create component instances to feed to new entity
    local instanced_comps = {}
    local instanced_entity = nil

    for i, comp_tags in ipairs(bp.comp) do
        -- translating components tags into actual components
        local new_component = components_interface(comp_tags)
        instanced_comps[comp_tags[1]] = new_component

        -- checking/storing special components
        if comp_tags[1] == "npc" then
            is_npc = true
            is_pawn = true
        elseif comp_tags[1] == "player" then
            new_player["player_comp"] = new_component
            is_pawn = true
        end
    end

    instanced_entity = Entity(bp.id, bp.tile, instanced_comps, bp.powers, name)

    -- once special components are stored, finish entityt identity 
    if is_npc then
        -- save NPC pilot in entity.pilot
        instanced_entity.pilot = instanced_entity.comp["npc"]
        table.insert(g.npcs_group, instanced_entity)
    -- if one uses a 'Npc' comp with a player, it just becomes a Npc!
    elseif instanced_entity.id == "player" and not is_npc then
        if not loc_row and not loc_col then
            -- if player spawn locations are missing, call FatalError State
            error_handler(
                "Insufficient player spawning locations in current map. Each player needs one."
            )
            g.game_state:exit()
            g.game_state = StateFatalError()
            g.game_state:init()

            return nil
        end

        -- save Player pilot in entity.pilot
        instanced_entity.pilot = instanced_entity.comp["player"]
        -- check if player has Stats() component with "hp". If not, add stat/comp
        if not instanced_entity.comp["stats"] then
            local stat_component = components_interface({"stats", "hp:1"})
            instanced_entity.comp["stats"] = stat_component
        end

        if not instanced_entity.comp["stats"].stat["hp"] then
            instanced_entity.comp["stats"].stat["hp"] = 1
        end

        new_player["entity"] = instanced_entity
        table.insert(g.party_group, new_player)
    end

    -- positioning entities
    instanced_entity.cell["cell"] = g.grid[loc_row][loc_col]
    instanced_entity.cell["grid_row"] = loc_row
    instanced_entity.cell["grid_col"] = loc_col

    -- occupying the cell appropriately depending on entity type
    if is_pawn then
        g.grid[loc_row][loc_col].pawn = instanced_entity
    else
        g.grid[loc_row][loc_col].entity = instanced_entity
    end
    -- adding the entity to the g.render_group IF it is not invisible by default
    if not instanced_entity.comp["invisible"] then
        -- insert entity to be drawn front/back depending if is pawn or not
        if is_pawn then
            -- insert to front in drawing order (last in group)
            table.insert(g.render_group, instanced_entity)
        else
            -- insert to back in drawing order (first in group)
            table.insert(g.render_group, 1, instanced_entity)
        end
    else
        table.insert(g.hidden_group, instanced_entity)
    end
end

--[[
    During g.grid generation, tiles (if present) are assigned to cells.
    Tiles are then drawn once, being static, and then stored as a base canvas for
    dynamic Entities that need to be drawn each loop.
]]
function map_generator(map_values, generate_players)
    local cell_x = 0
    local cell_y = 0
    local entity_name -- optional entity name, tanken from third cell arg
    local player_spawn = {}
    -- function dedicated to finalize cell generation with tile/entity
    local finalize_cell = function(tile_index, blueprint, i, j)
        -- extracting the quad for graphics
        g.grid[i][j].tile = tile_to_quad(tile_index)
        -- if no tile, index == 0 or index == < 0, mark cell index as 'empty'
        if tonumber(tile_index) > 0 then
            -- 'g.grid' reads STRINGS and NOT numbers! 
            g.grid[i][j].index = tile_index
        else
            g.grid[i][j].index = "empty"
        end

        -- spawning the entity from a blueprint
        if blueprint then
            entities_spawner(blueprint, i, j, entity_name)
        end
    end
    -- decision table for entity/no entity cells chain of action
    local CELL_DTABLE = {
        [true] = function(tile_value_1, tile_value_2, tile_value_3, i, j)
            local blueprint
            local tile_index = tile_value_1
            -- if tile_value_1 is a tile, then tile_value_2 is a blueprint,
            -- else, if it is = x, it's a player spawn point!
            if tile_index:match("%d") then
                -- save entity in the blueprint variable
                if BP_LIST[tile_value_2] then
                    blueprint = BP_LIST[tile_value_2]
                    -- checking if a special name for the entity was fed in the map
                    entity_name = tile_value_3
                else
                    error_handler(
                        "Map: illegal entity at row "..i.." column "..j..". Ignored."
                    )
                end

                finalize_cell(tile_index, blueprint, i, j)
            elseif tile_index == "x" and tile_value_2:match("%d") then
                -- if a spawn point, save locations for players to be spawned later
                player_spawn[tonumber(tile_value_2)] = {["row"] = i, ["col"] = j, ["cell"] = g.grid[i][j]}
                -- avoid finalize_cell() func, instead set cell to 'empty'
                g.grid[i][j].index = "empty"
            else
                error_handler(
                    "Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell."
                )
                g.grid[i][j].index = "empty"
            end
        end,
        [false] = function(tile_value_1, i, j)
            -- reset entity_name value
            entity_name = nil
            local tile_index = tile_value_1
            --[[
                If tile_index == nil there must be a blank line/unreadable value.
                If tile index is not a number then there is an illegal value!
            ]]--
            if not tile_index or not tile_index:match("%d") then
                -- not-numeric value for a tile
                error_handler(
                    "Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell."
                )
                g.grid[i][j].index = "empty"
            elseif tile_index == "x" then
                -- spawn location lacking an order number
                error_handler(
                    "Map: spawn point at row "..i.." column "..j.." lacking second arg. Replaced with empty cell."
                )
                g.grid[i][j].index = "empty"
            else
                -- cell simply has no entities inside!
                finalize_cell(tile_index, false, i, j)
            end
            return tile_index
        end
    }

    -- for every g.grid row, assign number of columns cells with x and y values
    for i = 1, g.grid_y do
        g.grid[i] = {}
        for j = 1, g.grid_x do
            -- filling g.grid position with a cell 'struct'
            g.grid[i][j] = {cell}
            g.grid[i][j].x = cell_x
            g.grid[i][j].y = cell_y

            -- checking if a cell contains entities...
            local tile_values = str_slicer(map_values[i][j], ",", 1)
            -- ...if it does, the table will have at least a second element:
            if tile_values[2] then
                CELL_DTABLE[true](tile_values[1], tile_values[2], tile_values[3], i, j)
            else
                -- funcs do not accept entire tables as arguments! Feeding values
                CELL_DTABLE[false](tile_values[1], i, j)
            end
            -- increase column value and break, since we found a spawn loc in cell
            cell_x = cell_x + TILE_SIZE
        end
        -- reset columns value, increase row value
        cell_x = 0
        cell_y = cell_y + TILE_SIZE
    end

    -- not spawning the players again if we just changed level
    if generate_players then
        -- finalizing player spawn: in the menu we have inserted players entities,
        -- but not their input components!
        local party_group_copy = g.party_group
        g.party_group = {}

        for i, bpandname in ipairs(party_group_copy) do
            local bp = bpandname["bp"]
            local name = bpandname["name"]
            -- check that all 4 spawn locations for players were set
            if not player_spawn[i] then
                error_handler(
                    "Map has insufficient Player Spawn Points. All maps should have four."
                )
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()
                break
            end
            entities_spawner(bp, player_spawn[i]["row"], player_spawn[i]["col"], name)
        end
    else
        -- players get generated at game start, and map generation happens each map.
        -- If players already exist, position them on their ordered spawn points
        for i, player in ipairs(g.party_group)  do
            player["entity"].cell["cell"] = player_spawn[i]["cell"]
            player["entity"].cell["cell"].pawn = player["entity"]
            player["entity"].cell["grid_row"] = player_spawn[i]["row"]
            player["entity"].cell["grid_col"] = player_spawn[i]["col"]
            table.insert(g.render_group, player["entity"])
        end
    end
end

function map_reader(map, generate_players)
    -- reading map values (static, one-draw pass tiles only)
    local map_values = csv_reader(FILES_PATH .. "map_"..map..".csv")

    -- check if operation went right; if not, activate error_handler and return
    if type(map_values) == "string" then
        error_handler("The above error was triggered while trying to read map.csv")
        return false
    end

    -- setting g.grid size depending on map's CSV input
    for row, column in ipairs(map_values) do
        g.grid_y = row
        for column_number, columns_value in ipairs(column) do
            g.grid_x = column_number
        end
    end

    -- initializing game canvases
    -- g.cnv_static for static tiles, g.cnv_dynamic for dynamic Entities
    g.cnv_static  = love.graphics.newCanvas(g.grid_x * TILE_SIZE, g.grid_y * TILE_SIZE)
    g.cnv_dynamic = love.graphics.newCanvas(g.grid_x * TILE_SIZE, g.grid_y * TILE_SIZE)

    -- getting tiles features groups from the specific CSV file
    local tiles_features_csv = csv_reader(FILES_PATH .. "tiles_features.csv")

    -- check if operation went right; if not, activate error_handler and return
    if type(tiles_features_csv) == "string" then
        error_handler(
            "The above error was triggered while trying to read tiles_features.csv"
        )
        return false
    end

    for i, tile_type in ipairs(tiles_features_csv) do
        -- check if the type is valid and has tile indexes assigned to it
        if tile_type[2] and VALID_PHYSICS[tile_type[1]] then
            -- separating tile indexes inside tile_type[2]
            tile_type[2] = str_slicer(tile_type[2], ",", 1)
            -- tile_type[1] == tile_type name, tile_type[2] == tiles
            for i2, tile in ipairs(tile_type[2]) do
                -- each tile == its type
                TILES_PHYSICS[tile] = tile_type[1]
            end
        end
    end
    -- now generating the map with the extracted data
    map_generator(map_values, generate_players)
    -- if everything went fine, return true. Else, false.
    return true
end

function tile_to_quad(index)
    -- converting index to actual number (all CSV data is extracted as string)
    local tile_index = tonumber(index)
    -- calculating max indexes
    local tileset_width_in_cells = TILESET_WIDTH / TILE_SIZE
    local tileset_height_in_cells = TILESET_HEIGHT / TILE_SIZE
    local max_index = tileset_width_in_cells * tileset_height_in_cells
    local row = 1

    -- checking if index is in TILESET's range (NOTE: indexes start from 1)
    if tile_index <= 0 or tile_index > max_index then
        return nil
    end
    
    -- search for correct row with a simple subtraction
    while tile_index > tileset_width_in_cells do
        row = row + 1
        tile_index = tile_index - (tileset_width_in_cells)
    end

    local col = tile_index -- since what is left is the column position
    
    -- note how the 0 based coords for drawing are kept with -1 subtractions
    return love.graphics.newQuad((col - 1) * TILE_SIZE, (row - 1) * TILE_SIZE,
    TILE_SIZE, TILE_SIZE, TILESET_WIDTH, TILESET_HEIGHT)
end

-- screen pixel-perfect adjustment (screen size must always be even)
function pixel_adjust(w, h)
    if w % 2 ~= 0 then
        w = w + 1
    end
    if h % 2 ~= 0 then
        h = h + 1
    end
    print(("Window resized to width: %d and height: %d."):format(w, h))
    return w, h
end

-- screen resizing handling
function love.resize(w, h)
    g.w_width, g.w_height = pixel_adjust(w, h)
    g.game_state:refresh()
end

function blueprint_generator(bp_data)
    local id -- blueprint's id
    local tile -- blueprint's tile
    -- comps not implemented in components_interface will be ignored
    local all_components = {}
    -- this table stores which powers have been saved to avoid duplicates
    local blueprint_powers = {}
    -- this table stores which components have been saved to avoid duplicates
    local stored_components = {}
    -- this will be the list of actual components to input as argument to new entity
    local blueprint_components = {}

    -- for each element in bp_data, identify type (id, tile, component or power)
    for _, element in ipairs(bp_data) do
        -- useful copy of element, used for element type check
        local element_output
        -- only used for components, not for id, tile or power values
        -- pos is 1 by default and tracks the separator position inside the string
        local pos = 1
        -- only used for components. Components id and their arguments are separated
        -- with commas. This variable stores every input for the component
        local comp_args = {}

        -- checking if the element is the Blueprint's id
        element_output = str_slicer(element, "@", 1)
        
        if element_output[2] then
            id = element_output[2]

            -- checking to ensure Blueprint id uniqueness
            if BP_LIST[id] then
                error_handler(
                    'Blueprint "'..id..'" is not unique, duplicates ignored.'
                )
                return false
            end

            goto continue
        end

        -- checking if the element is the Blueprint's tile/tile_group
        element_output = str_slicer(element, ":", 1)
        --[[
            Entities can have a fixed tile or a random one from their group, stored
            in sprites_groups. In the latter case, the selected tile will be removed
            from the group.
        ]]--
        -- check if the Entity has a fixed tile or a random one from a group
        if element_output[2] then
            -- number of values in the group, counted later
            local num_of_values = 0
            -- selected random index
            local selected_index = 0
            -- selected group length
            local group_length = 0

            -- checking if it's a single index or a group
            if tonumber(element_output[2]) then
                tile = element_output[2]
                goto continue
            end

            -- check if group is valid or not (char ':' can be manually misused)
            if not sprites_groups[element_output[2]] then
                error_handler(
                    "Trying to assign sprite to an Entity from a non-existing sprites_group"
                )
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()

                return false
            end

            -- check group length (previously stored in sprites_groups_manager())
            group_length = sprites_groups[element_output[2] .. "_size"]

            -- check if there are still sprites available in selected group
            if group_length <= 0 then
                error_handler(
                    "Trying to assign sprite to an Entity from a depleted sprites_group (more entities than available sprites)"
                )
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()

                return false
            end

            -- store the random index to constant number with loop
            for j = 1, math.random(group_length) do
                selected_index = selected_index + 1
            end            

            -- setting randomly chosen sprite
            tile = sprites_groups[element_output[2]][selected_index]
            -- removing randomly chosen sprite from its group
            table.remove(sprites_groups[element_output[2]], selected_index)
            -- length of the group was reduced by one
            sprites_groups[element_output[2] .. "_size"] = group_length - 1

            goto continue
        end

        -- checking if the element is a power
        element_output = str_slicer(element, "*", 1)

        if element_output[2] then
            -- only used for powers.
            -- Structure for components is the same, but effects are functions!
            local power_effects = str_slicer(element_output[2], ",", pos)
            
            -- check power name uniqueness
            if blueprint_powers[power_effects[1]] then
                error_handler(
                    'Power"'..power_effects[1]..'" for blueprint "'..id..'" is not unique, duplicates ignored.'
                )
                goto continue
            end

            -- store newly added power in blueprint_powers, to add to final Entity
            blueprint_powers[power_effects[1]] = Power(power_effects)

            goto continue
        end    

        -- if nothing of the above is true, then element must be a component
        comp_args = str_slicer(element, ",", pos)
        -- all_components contains tables of all data for all components
        table.insert(all_components, comp_args)

        ::continue::
    end 

    for _, comp_tags in ipairs(all_components) do
        -- translating comps data into actual comps with components_interface
        local new_component = components_interface(comp_tags)
        -- check for duplicate components (comp_tags[1] = component's name)
        if stored_components[comp_tags[1]] then
            error_handler(
                'Component "'..comp_tags[1]..'" for blueprint "'..id..'" is not unique, duplicates ignored.'
            )

            goto continue
        end

        -- check for component validity and in case insert it
        if new_component then
            -- here we don't store any component, only its data for later use
            table.insert(blueprint_components, comp_tags)
            stored_components[comp_tags[1]] = true
        else
            -- warning with console if an invalid component was found inside CSV
            error_handler('Invalid component: "'..comp_tags[1]..'" was ignored.')
        end

        ::continue::
    end

    -- create final blueprint from entity and its components and save it in BP_LIST
    local new_blueprint = Entity(id, tile, blueprint_components, blueprint_powers)
    BP_LIST[id] = new_blueprint
end

function blueprints_manager()
    -- all game entities are managed by a single CSV file.
    local entities_csv = csv_reader(FILES_PATH .. "blueprints.csv")

    -- check if operation went right; if not, activate error_handler
    if type(entities_csv) == "string" then
        error_handler(
            "The above error was triggered while trying to read blueprints.csv"
        )
        return false
    end

    for i, line in ipairs(entities_csv) do
        -- keeping track of all the entity components and counting
        local n_of_elements = 0
        local entity_components = {}
        -- counting number of components contained in each line
        for _, component in ipairs(line) do
            n_of_elements = n_of_elements + 1
        end
        -- using j to index elements assigned to entity_components, starting from 1
        local j = 1
        -- storing components
        for k = 1, n_of_elements do
            entity_components[j] = entities_csv[i][k]
            j = j + 1
        end
        -- passing the new entity with the data extracted from the CSV file
        blueprint_generator(entity_components)
    end

    return true
end

function camera_setting()
    -- setting g.camera to the first spawned player
    local camera_entity = g.party_group[1]["entity"]
    if g.camera["entity"] == nil then
        g.camera["entity"] = camera_entity
        g.camera["x"] = camera_entity.cell["cell"].x
        g.camera["y"] = camera_entity.cell["cell"].y
    end
end

-- a simple dice throwing function accepting any number of any type of dice
-- WARNING: this function ONLY ACCEPTS STRINGS
function dice_roll(die_set_input, success_input)
    local die_set -- contains: n of throws, value of dice, optional modifier
    local throws
    local die_value
    local modifier = false
    local value_modifier_couple
    local result = 0
    local success = success_input

    -- immediately check if it's a dice set or a constant
    die_set = str_slicer(die_set_input, "d", 1)

    -- die_set_input is constant, immediately return it as result
    if not die_set[2] then
        result = tonumber(die_set_input)

        return result
    end

    -- die_set_input is an actual die set, store all data
    throws = tonumber(die_set[1])
    die_value = tonumber(die_set[2])

    -- check if actual die set has positive modifier
    value_modifier_couple = str_slicer(die_set[2], "+", 1)
    if value_modifier_couple[2] then
        die_value = tonumber(value_modifier_couple[1])
        modifier = tonumber(value_modifier_couple[2])
        
        goto continue
    end

    -- check if actual die set has negative modifier
    value_modifier_couple = str_slicer(die_set[2], "-", 1)
    if value_modifier_couple[2] then
        die_value = tonumber(value_modifier_couple[1])
        modifier = tonumber(value_modifier_couple[2]) * -1
    end

    :: continue ::

    -- sum of all throws from the die set
    for i = 1, throws do
        result = result + math.random(1, die_value)
    end
    -- apply modifier, if any
    result = result + (modifier or 0)
    -- if success is requested, throw needs to be <= success
    if success and success - result < 0 then result = false end
    -- numerical results can't be < 0
    if result and result < 0 then result = 0 end

    return result
end

-- manages turns and applies effects before Entity activation
-- NOTE: current player is always fed to coordinate camera position!
function turns_manager(current_player, npc_turn)
    -- setting current_player coords for camera tweening
    local x_for_tweening = current_player["entity"].cell["cell"].x
    local y_for_tweening = current_player["entity"].cell["cell"].y
    -- set this next (or first) player as the g.camera entity
    g.camera["entity"] = current_player["entity"]
    -- tween camera between previous and current active player
    Timer.tween(TWEENING_TIME, {
        [g.camera] =  {x = x_for_tweening, y = y_for_tweening}
    }):finish(function ()
        -- if it's not the NPCs turn, apply player pawn effects and enable them 
        if not npc_turn then
            for i, effect_tag in ipairs(current_player["entity"].effects) do
                -- activate lasting effects for current_player
                effect_tag:activate()
                -- remove concluded effects from current_player["entity"].effects
                if effect_tag.duration <= 0 then
                    table.remove(current_player["entity"].effects, i)
                end
            end

            -- ignore NPCs activation and skip to end of code
            goto continue
        end

        -- activate NPCs and apply their effects
        for i, npc in ipairs(g.npcs_group) do
            -- check if the NPC is alive or is waiting to be removed from game
            if npc.alive then
                for j, effect_tag in ipairs(npc.effects) do
                    -- activate lasting effects for each npc
                    effect_tag:activate()
                    -- remove concluded effects from each npc.effects
                    if effect_tag.duration <= 0 then
                        table.remove(npc.effects, j)
                    end
                end
            end

            -- check again if NPC is still alive after the receiving lasting effects
            if npc.alive then
                g.npcs_group[i].comp["npc"]:activate(g.npcs_group[i])
            end
        end

        ::continue::
        g.tweening = false
        console_cmd(nil)
        g.game_state:refresh()        
    end)
end

function ui_manager_play()
    local color_1, color_2, color_3
    local event_1, event_2, event_3
    -- generating and setting a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    love.graphics.setCanvas(new_canvas)

    -- clear to transparent black
    love.graphics.clear(0, 0, 0, 0)
    -- drawing UI on top of everything for the current player    
    love.graphics.setFont(FONTS["console"])
    -- setting font color for name/console
    love.graphics.setColor(0.49, 0.82, 0.90, 1)
    
    -- if present, print console["string"]
    if g.console["string"] then
        love.graphics.printf(g.console["string"], 0,
        g.w_height - (PADDING * 1.5), g.w_width, "center")
    end

    -- storing colors for better legibility
    color_3 = {g.console["rgb3"][1], g.console["rgb3"][2], g.console["rgb3"][3], 1}
    color_2 = {g.console["rgb2"][1], g.console["rgb2"][2], g.console["rgb2"][3], 1}
    color_1 = {g.console["rgb1"][1], g.console["rgb1"][2], g.console["rgb1"][3], 1}

    -- storing event strings for better legibility
    event_3 = g.console["event3"] or "Error: fed nothing to console_event() func"
    event_2 = g.console["event2"] or "Error: fed nothing to console_event() func"
    event_1 = g.console["event1"] or "Error: fed nothing to console_event() func"

    -- print console events
    love.graphics.setColor(color_3)
    love.graphics.print(event_3, PADDING, g.w_height - (PADDING * 3.5))

    love.graphics.setColor(color_2)
    love.graphics.print(event_2, PADDING, g.w_height - (PADDING * 2.5))

    love.graphics.setColor(color_1)
    love.graphics.print(event_1, PADDING, g.w_height - (PADDING * 1.5))

    if not g.view_inv then
        local player_stats = g.camera["entity"].comp["stats"].stat
        -- set proper font
        love.graphics.setFont(FONTS["tag"])

        -- set proper color
        love.graphics.setColor(0.49, 0.82, 0.90, 1)
        
        -- print player stats
        love.graphics.print(g.camera["entity"].name, PADDING, PADDING)

        
        love.graphics.setFont(FONTS["ui"])

        -- setting font color for player data
        love.graphics.setColor(0.28, 0.46, 0.73, 1)

        love.graphics.print("Life "..player_stats["hp"], PADDING, PADDING * 2.5)
        love.graphics.print("Gold "..player_stats["gold"], PADDING, PADDING * 3.5)
    end
    
    -- restoring default RGBA, since this function influences ALL graphics
    love.graphics.setColor(1, 1, 1, 1)

    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()

    return new_canvas
end

function draw_borders(group)
    local size = SIZE_MULT * 2
    local t_size = TILE_SIZE * 2
    -- frame borders coordinates, for better legibility and management
    local x1, x2, x3, x4
    local y1, y2, y3, y4

    -- PLEASE NOTE: frames positioning follow standard quadrant anti-clockwise order
    x1 = 0
    x2 = 0
    x3 = g.w_width - (t_size) * size, g.w_height - (t_size) * size
    x4 = g.w_width - (t_size) * size

    y1 = 0
    y2 = g.w_height - (t_size) * size
    y3 = g.w_height - (t_size) * size
    y4 = 0

    -- draw borders
    love.graphics.draw(FRAMESET, BORDERS[group][1], x1, y1, 0, size, size)
    love.graphics.draw(FRAMESET, BORDERS[group][3], x2, y2, 0, size, size)
    love.graphics.draw(FRAMESET, BORDERS[group][4], x3, y3, 0, size, size)
    love.graphics.draw(FRAMESET, BORDERS[group][2], x4, y4, 0, size, size)
end

-- main menu UI manager
function ui_manager_menu(text_in, input_phase, n_of_players, current_player, name)
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    local size = SIZE_MULT * 2
    local t_size = TILE_SIZE * 2
    -- text coordinates for better readibility
    local logo_x, logo_y
    local title_x, title_y
    local text_x, text_y
    local input_x, input_y
    -- text and text_in str, stored for better legibility
    local text, str
    
    love.graphics.setCanvas(new_canvas)

    -- draw borders from group 1
    draw_borders(1)

    -- logo coordinates setting
    logo_x = 0
    logo_y = (g.w_height / 5) - SIZE_MAX

    love.graphics.setColor(0.78, 0.96, 0.94, 1) 
    love.graphics.setFont(FONTS["logo"])
    love.graphics.printf(GAME_LOGO, logo_x, logo_y, g.w_width, "center")

    -- title coordinates setting
    title_x = 0
    title_y = g.w_height / 5

    love.graphics.setFont(FONTS["title"])
    love.graphics.printf(GAME_TITLE, title_x, title_y, g.w_width, "center")

    -- setting proper text for input_phase
    text = text_in[input_phase]
    str = text_in[current_player + 2]

    -- text and text input coordinates setting
    text_x = 0
    text_y = g.w_height / 5 + (PADDING * 4)
    input_x = 0
    input_y = g.w_height / 5 + (PADDING * 4)

    love.graphics.setFont(FONTS["subtitle"])
    if input_phase == 1 then
        love.graphics.printf(text .. n_of_players, text_x, text_y, g.w_width, "center")
    else
        love.graphics.printf(text .. str .. "rogue:\n" .. name, input_x, input_y, g.w_width, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)

    return new_canvas
end

function ui_manager_gameover()
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    local size = SIZE_MULT * 2
    local t_size = TILE_SIZE * 2
    -- text coords for better readibility
    local title_x, title_y
    local text_x, text_y
    local list_x, list_y
    -- text content, for better readibility
    local cemetery_text
    

    love.graphics.setCanvas(new_canvas)

    -- draw borders from group 3
    draw_borders(3)

    -- set text coordinates
    title_x = 0
    title_y = g.w_height / 4 - PADDING

    text_x = 0
    text_y = g.w_height / 4 + PADDING

    list_x = 0

    love.graphics.setColor(0.93, 0.18, 0.27, 1)
    love.graphics.setFont(FONTS["title"])
    love.graphics.printf("Game Over", title_x, title_y, g.w_width, "center")

    -- setting text
    cemetery_text = "These souls have left us forever:"

    love.graphics.setColor(0.78, 0.96, 0.94, 1)
    love.graphics.setFont(FONTS["subtitle"])
    love.graphics.printf(cemetery_text, text_x, text_y, g.w_width, "center")

    -- printing all deceased players and info about their death
    for i, death in ipairs(g.cemetery) do
        list_y = g.w_height / 3.5 + (PADDING * (i * 3))
        love.graphics.printf(death["player"]..", killed by "..death["killer"].." for "..death["loot"].." gold,\n"..
        "has found a final resting place in "..death["place"]..".",
        list_x, list_y, g.w_width, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)

    return new_canvas
end

function ui_manager_credits(credits_image)
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    love.graphics.setCanvas(new_canvas)
    -- this is the optimal proportion between the image size and the screen size
    local scale = g.w_height / 1300
    local credits_width = credits_image:getWidth()
    local credits_height = credits_image:getHeight()
    -- coordinates for better legibility
    local image_x, image_y

    image_x = g.w_width / 2 - (credits_width / 2 * scale)
    image_y = g.w_height / 2 - (credits_height / 2 * scale)

    -- always keep the image with its original proportions and in the screen center
    love.graphics.draw(credits_image, image_x, image_y, 0, scale, scale)
    return new_canvas
end

function text_backspace(input_string)
    input_string = string.sub(input_string, 1, -2)
    love.audio.stop(SOUNDS["type_backspace"])
    love.audio.play(SOUNDS["type_backspace"])

    return input_string
end

function text_input(valid_input, key, input_string, max_length)
    -- if the character is legal (see valid_input variable) then append it
    if string.find(valid_input, key) and #input_string < max_length then
        if key == "space" then
            input_string = input_string .. " "
        elseif love.keyboard.isDown("rshift") or love.keyboard.isDown("lshift") then
            input_string = input_string .. string.upper(key)
        else
            input_string = input_string .. key
        end
        love.audio.stop(SOUNDS["type_input"])
        love.audio.play(SOUNDS["type_input"])
    elseif #input_string >= max_length then
        love.audio.stop(SOUNDS["type_nil"])
        love.audio.play(SOUNDS["type_nil"])
    end

    return input_string
end

function entity_kill(entity, index, group)
    table.remove(group, index)
    if entity.comp["obstacle"] or entity.comp["player"] or entity.comp["npc"] then
        print("Pawn entity or obstacle entity destroyed")

        entity.cell["cell"].pawn = nil
    else
        entity.cell["cell"].entity = nil
    end
end

-- this func registers game events and chronologially displays them
function console_event(event, font_color)
    local base_color = {[1] = 0.28, [2] = 0.46, [3] = 0.73}
    local events_table = {}
    -- extracting values from g.console
    -- PLEASE NOTE: in Lua, tables are passed as *ref*, *not* as value!
    for i, v in pairs(g.console) do
        events_table[i] = v
    end

    -- assigning new values to global colors
    g.console["rgb3"] = events_table["rgb2"]
    g.console["rgb2"] = events_table["rgb1"]
    g.console["rgb1"] = font_color or base_color
    -- assigning new values to global strings
    g.console["event3"] = events_table["event2"]
    g.console["event2"] = events_table["event1"]
    g.console["event1"] = event:gsub("^%l", string.upper)
    g.cnv_ui = ui_manager_play()
end

function console_cmd(cmd)
    g.console["string"] = cmd
    g.cnv_ui = ui_manager_play()
end

function death_check(target, damage_dice, type, message)
    -- this is needed to output messages on screen in yellow or red
    local event_color = {
        [false] = {[1] = 0.87, [2] = 0.26, [3] = 0.43},
        [true] = {[1] = 0.93, [2] = 0.18, [3] = 0.27}
    }
    -- store target.comp for better readibility
    local comps = target.comp
    -- reference eventual 'stats' component or set variable to false
    local stats = comps["stats"] and comps["stats"].stat or false
    -- reference eventual 'profile' component or set variable to false
    local modifier = comps["profile"] and comps["profile"].profile[type] or false
    -- choose color depending on player (red) or npc (yellow)
    local target_family = comps["player"] and true or false
    -- stores final damage score to subtract from target's HP
    local damage_score = 0

    -- cannot damage an Entity without hp
    if not stats and not stats["hp"] then
        print("Target has no HP stat")
        return false
    end

    -- cannot damage an Entity immune to that effect
    if modifier and modifier == "immune" then
        console_event(target.name .. " doth seem immune to " .. type)
        return false
    end
    
    damage_score = dice_roll(damage_dice) + tonumber(modifier or 0)

    -- this is done to avoid adding HP when modifier is so impactful to output <= 0
    if damage_score <= 0 then
        console_event(target.name .. " doth not appear troubled by " .. type)
        return false
    end

    stats["hp"] = stats["hp"] - damage_score
    print(target.name .. " receives damage: " .. damage_score)

    if stats["hp"] <= 0 then
        target.alive = false
        console_event(target.name .. " " .. message, event_color[target_family])
    end

    -- returning success and damage inflicted, useful to influence EffectTags:
    -- i.e. the harder you slash someone, the longer he will bleed
    return true, damage_score
end

-- check if Entity can be interacted with actions such as pickup, use, etc
function entity_available(target)
    if target.comp["locked"] or target.comp["sealed"] then
        console_event(
            target.comp["locked"] and "You require a key"
            or target.comp["sealed"] and "It is sealed by magic"
        )
        
        return false
    else
        return true
    end
end

function inventory_update(player)
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    local size = SIZE_MULT * 2
    local t_size = TILE_SIZE * 2
    local inv_str = "abcdefghijklmnopqrstuvwxyz"
    local tag_str
    -- referencing eventual player's 'inventory' component
    local inventory = player.comp["inventory"]
    local available_items = {}
    local equipped = false
    local title_color = {0.49, 0.82, 0.90, 1}
    local text_y
    local text_color = {
        [true] = {0.93, 0.18, 0.27, 1},
        [false] = {0.28, 0.46, 0.73, 1}    
    }

    -- immediately check if player is missing inventory component
    if not inventory then
        error_handler(
            "In 'inventory_update()', found player with missing inventory"
        )
        return false
    end

    -- setting a canvas of the proper size
    love.graphics.setCanvas(new_canvas)
    -- clear to transparent black, set proper font and text_color
    love.graphics.clear(0, 0, 0, 0)

    -- draw borders
    draw_borders(2)

    -- setting font for inventory's title
    love.graphics.setFont(FONTS["tag"])
    -- setting font text_color for inventory's title
    love.graphics.setColor(title_color)

    -- printing owner's name
    love.graphics.printf(player.name .. "'s bag", 0, SIZE_DEF, g.w_width, "center")

    -- at this point, reference 'inventory' comp table of items
    inventory = inventory.items

    -- setting font for inventory's items
    love.graphics.setFont(FONTS["ui"])

    -- print all item in player inventory and couple them with a letter
    for i = 1, string.len(inv_str) do
        -- reference item's 'equipable' comp for each item in inventory
        local equipable_ref
        local stack_str = ""
        local slot_str = ""
        local item_str
        -- if no more items are available, break loop
        if not inventory[i] then
            break
        end

        -- item exists, proceed referencing it
        equipable_ref = inventory[i].comp["equipable"]

        -- choosing printf text_color to discriminate equipped/unequipped items
        if equipable_ref and equipable_ref.slot_reference then
            equipped = true
            slot_str = " (" .. equipable_ref.slot_reference .. ")"
        else
            equipped = false
        end

        equipable_ref = inventory[i].comp["stack"]

        if equipable_ref then
            local stack_qty = inventory[i].comp["stats"].stat["hp"]
            stack_str = " [" .. stack_qty .. "]"
        end

        -- chosen text_color setting
        love.graphics.setColor(text_color[equipped])

        -- print all items on canvas
        item_str = string_selector(inventory[i])

        -- establish and set tag_str and text_y
        tag_str = string.sub(inv_str, i, i) .. ": "
        text_y = (SIZE_DEF + SIZE_DEF / 3) * (i + 2)

        -- print string canvas
        love.graphics.printf(tag_str .. item_str .. stack_str .. slot_str,
        0, text_y, g.w_width, "center"
        )
        available_items[string.sub(inv_str, i, i)] = inventory[i]
    end

    -- storing available_items to be used with action_modes
    g.current_inv = available_items
    -- copying updated inventory canvas to g.cnv_inv (global inventory canvas)
    g.cnv_inv = new_canvas

    -- restoring default RGBA, since this function influences ALL graphics
    love.graphics.setColor(1, 1, 1, 1)
    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()

    return true
end

-- related to action_modes, selects a tile OR an inventory item to perform action on
-- which one is selcted depends on inventory being opened or closed
function target_selector(player_comp, performer, key)
    local target_cell
    local pawn_ref, entity_ref -- Entities references
    
    
    if not g.view_inv then
        if player_comp.movement_inputs[key] then
            local target_x, target_y

            target_y = performer.cell["grid_col"] + player_comp.movement_inputs[key][2]
            target_x = performer.cell["grid_row"] + player_comp.movement_inputs[key][1]

            target_cell = g.grid[target_x][target_y]
        else
            -- if input is not a valid direction, turn is not valid
            return false
        end

        -- store eventual pawn Entity or Entity
        pawn_ref = target_cell and target_cell.pawn
        entity_ref = target_cell and target_cell.entity

        -- avoiding performer from acting on itself
        if target_cell and target_cell.pawn == performer then
            pawn_ref = nil
        end

        return true, pawn_ref, entity_ref, target_cell
    end

    return true, false, g.current_inv[key]
end

-- based on Entity current components, select best proper string
function string_selector(entity)
    local proper_string

    proper_string = entity.name

    if entity.comp["description"] then
        proper_string = entity.comp["description"].string
    end

    if entity.comp["secret"] then
        proper_string = entity.comp["secret"].string
    end

    return proper_string
end