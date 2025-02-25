-- useful variables that get used often
local TILESET_WIDTH = g.TILESET:getWidth()
local TILESET_HEIGHT = g.TILESET:getHeight()
local TILE_SIZE = mod.TILE_SIZE or 20 -- used for cell size/tileset slicing.
local sprites_groups = {}

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
    Components interface. Used to link components and their optional args to the actual components.
    These are the the strings you feed inside the 'blueprints.csv' to explain to the engine what an
    entity is composed of. The function below needs to be updated with each added component!
]]
function components_interface(tags)
    -- tags[1] = component id, others (if present) are their arguments
    if not COMPONENTS_TABLE[tags[1]] then return nil end
    -- adding () to COMPONENTS_TABLE value, to turn it into class
    return COMPONENTS_TABLE[tags[1]](component_tags(tags))
end

function strings_separator(line, separator, pos)
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
    csv_reader() returns a 3D table like 'table[line number] = {line value 1, line value 2, ...}'
    Note that the error_handler is never called in csv_reader, since it is called various times
    and if we call it in main.lua we can output some more info about the error.
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
        local results = strings_separator(line, separator, pos)
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

function sprites_groups_manager()
    -- all sprites groups are managed by a single CSV file
    local sprites_groups_csv = csv_reader(PATH_TO_CSV .. "sprites_groups.csv")

    -- check if operation went right; if not, activate error_handler
    if type(sprites_groups_csv) == "string" then
        error_handler("The above error was triggered while trying to read sprites_groups.csv")
        return false
    end

    for i, line in ipairs(sprites_groups_csv) do
        local current_group = {}
        local group_name = ""
        -- for each line in the csv, store its data in util.lua local sprites_groups
        current_group = strings_separator(line[1], ",", 1)
        for i2, value in ipairs(current_group) do
            -- first value is the group's name
            if i2 == 1 then
                group_name = value
                sprites_groups[group_name] = {}
                sprites_groups[group_name .. "_length"] = 0
            else
                table.insert(sprites_groups[group_name], tonumber(value))
                sprites_groups[group_name .. "_length"] = sprites_groups[group_name .. "_length"] + 1
            end
        end
    end
    
    return true
end

function entities_spawner(blueprint, loc_row, loc_column, name)
    local player_num = 1
    local is_occupant = false
    local is_npc = false
    local new_player = {
        ["entity"] = nil,
        ["player_component"] = nil
    }

    -- now create component instances to feed to new entity
    local instanced_components = {}
    local instanced_entity = nil

    for i, comp_tags in ipairs(blueprint["bp"].components) do
        -- translating components tags into actual components thanks to components_interface
        local new_component = components_interface(comp_tags)
        instanced_components[comp_tags[1]] = new_component

        -- checking for components that need to be stored in special groups for easier, faster calling
        if comp_tags[1] == "npc" then
            is_npc = true
            is_occupant = true
        elseif comp_tags[1] == "player" then
            new_player["player_component"] = new_component
            is_occupant = true
        elseif comp_tags[1] == "obstacle" then
            is_occupant = true
        end
    end

    instanced_entity = Entity(blueprint["bp"].id, blueprint["bp"].tile, instanced_components, blueprint["bp"].powers, name)

    -- once special components are stored, finish entityt identity 
    if is_npc then
        -- save NPC controller in entity.controller
        instanced_entity.controller = instanced_entity.components["npc"]
        table.insert(g.npcs_group, instanced_entity)
    -- if one uses a 'Npc' comp with a player, it just becomes a Npc!
    elseif instanced_entity.id == "player" and not is_npc then
        if not loc_row and not loc_column then
            -- as soon as missing player spawn locations are called, call FatalError State
            error_handler("Insufficient player spawning locations in current map. Each player needs one.")
            g.game_state:exit()
            g.game_state = StateFatalError()
            g.game_state:init()

            return nil
        end

        -- save Player controller in entity.controller
        instanced_entity.controller = instanced_entity.components["player"]
        -- immediately check if player has Stats() component with "hp". If not, add it/them
        if not instanced_entity.components["stats"] then
            local stat_component = components_interface({"stats", "hp:1"})
            instanced_entity.components["stats"] = stat_component
        end

        if not instanced_entity.components["stats"].stats["hp"] then
            instanced_entity.components["stats"].stats["hp"] = 1
        end

        new_player["entity"] = instanced_entity
        table.insert(g.players_party, new_player)
    end

    -- positioning entities
    instanced_entity.cell["cell"] = g.grid[loc_row][loc_column]
    instanced_entity.cell["grid_row"] = loc_row
    instanced_entity.cell["grid_column"] = loc_column

    -- occupying the cell appropriately depending on entity type
    if is_occupant then
        g.grid[loc_row][loc_column].occupant = instanced_entity
    else
        g.grid[loc_row][loc_column].entity = instanced_entity
    end
    -- adding the entity to the g.render_group IF it is not invisible by default
    if not instanced_entity.components["invisible"] then
        -- adding entity in front or back depending if it is an occupant or a simple entity
        if is_occupant then
            -- insert to front in drawing order (last in group)
            table.insert(g.render_group, instanced_entity)
        else
            -- insert to back in drawing order (first in group)
            table.insert(g.render_group, 1, instanced_entity)
        end
    else
        table.insert(g.invisible_group, instanced_entity)
    end
end

--[[
    During g.grid generation, tiles (if present) are assigned to cells. After this process,
    tiles are drawn once and stored for next drawing passes, so they get drawn only once and 
    function as a base canvas where dynamic entities will be drawn each loop.
]]
function map_generator(map_values, generate_players)
    local cell_x = 0
    local cell_y = 0
    local entity_name -- optional entity name, tanken from third cell arg
    local player_spawn_loc = {}
    -- function dedicated to finalize cell generation with tile/entity
    local finalize_cell = function(tile_index, blueprint, i, j)
        -- extracting the quad for graphics
        g.grid[i][j].tile = tile_to_quad(tile_index)
        -- check if the map is 'empty' there (no tile, index == 0 or < 0), and mark it as 'empty'
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
                if BLUEPRINTS_LIST[tile_value_2] then
                    blueprint = {["bp"] = BLUEPRINTS_LIST[tile_value_2]}
                    -- checking if a special name for the entity was fed in the map
                    entity_name = tile_value_3
                else
                    error_handler("Map: illegal entity at row "..i.." column "..j..". Ignored.")
                end

                finalize_cell(tile_index, blueprint, i, j)
            elseif tile_index == "x" and tile_value_2:match("%d") then
                -- if that's a spawn point, save locations for players to be spawned later
                player_spawn_loc[tonumber(tile_value_2)] = {["row"] = i, ["column"] = j, ["cell"] = g.grid[i][j]}
                -- no need for the finalize_cell() function, just set cell to 'empty'
                g.grid[i][j].index = "empty"
            else
                error_handler("Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell.")
                g.grid[i][j].index = "empty"
            end
        end,
        [false] = function(tile_value_1, i, j)
            -- reset entity_name value
            entity_name = nil
            local tile_index = tile_value_1
            -- if tile_index == nil then there must be a blank line or the value is unreadable
            -- if tile index doesn't match a number ("%d") then there is an illegal value
            if not tile_index or not tile_index:match("%d") then
                -- not-numeric value for a tile
                error_handler("Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell.")
                g.grid[i][j].index = "empty"
            elseif tile_index == "x" then
                -- spawn location lacking an order number
                error_handler("Map: spawn point at row "..i.." column "..j.." lacking second arg. Replaced with empty cell.")
                g.grid[i][j].index = "empty"
            else
                -- cell simply has no entities inside!
                finalize_cell(tile_index, nil, i, j)
            end
            return tile_index
        end
    }

    -- for every g.grid row, assign number of columns cells; each one with x and y values
    for i = 1, g.grid_y do
        g.grid[i] = {}
        for j = 1, g.grid_x do
            -- filling g.grid position with a cell 'struct'
            g.grid[i][j] = {cell}
            g.grid[i][j].x = cell_x
            g.grid[i][j].y = cell_y

            -- checking if a cell contains entities...
            local tile_values = strings_separator(map_values[i][j], ",", 1)
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
        -- spawning players: in the menu we have inserted players entities but not their input_comp!
        local players_party_copy = g.players_party
        g.players_party = {}
        for i, player_blueprint in ipairs(players_party_copy) do
            -- check that all 4 spawn locations for players were set
            if not player_spawn_loc[i] then
                error_handler("Map has insufficient Player Spawn Points. All maps should have four.")
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()
                break
            end
            entities_spawner(player_blueprint, player_spawn_loc[i]["row"], player_spawn_loc[i]["column"], entity_name)
        end
    else
        for i, player in ipairs(g.players_party)  do
            player["entity"].cell["cell"] = player_spawn_loc[i]["cell"]
            player["entity"].cell["cell"].occupant = player["entity"]
            player["entity"].cell["grid_row"] = player_spawn_loc[i]["row"]
            player["entity"].cell["grid_column"] = player_spawn_loc[i]["column"]
            table.insert(g.render_group, player["entity"])
        end
    end
end

function map_reader(map, generate_players)
    -- all the valid tiles features for TILES_VALID_FEATURES table (see pairings in components.lua)
    local TILES_VALID_FEATURES = {
    ["liquid"] = true,
    ["tricky"] = true,
    ["untraversable"] = true,
    ["solid"] = true,
    ["ground"] = true
    }
    -- reading map values (static, one-draw pass tiles only)
    local map_values = csv_reader(PATH_TO_CSV .. "map_"..map..".csv")

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

    -- initializing game canvases (g.canvas_static  with tiles, g.canvas_dynamic adds entities)
    g.canvas_static  = love.graphics.newCanvas(g.grid_x * TILE_SIZE, g.grid_y * TILE_SIZE)
    g.canvas_dynamic = love.graphics.newCanvas(g.grid_x * TILE_SIZE, g.grid_y * TILE_SIZE)

    -- getting tiles features groups from the specific CSV file
    local tiles_features_csv = csv_reader(PATH_TO_CSV .. "tiles_features.csv")

    -- check if operation went right; if not, activate error_handler and return
    if type(tiles_features_csv) == "string" then
        error_handler("The above error was triggered while trying to read tiles_features.csv")
        return false
    end

    for i, tile_type in ipairs(tiles_features_csv) do
        -- check if the type is valid and has tile indexes assigned to it
        if tile_type[2] and TILES_VALID_FEATURES[tile_type[1]] then
            -- separating tile indexes inside tile_type[2]
            tile_type[2] = strings_separator(tile_type[2], ",", 1)
            -- tile_type[1] == tile_type name, tile_type[2] == tiles
            for i2, tile in ipairs(tile_type[2]) do
                -- each tile == its type
                TILES_FEATURES_PAIRS[tile] = tile_type[1]
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

    -- checking if index is in g.TILESET's range (NOTE: indexes start from 1)
    if tile_index <= 0 or tile_index > max_index then
        return nil
    end
    
    -- search for correct row with a simple subtraction
    while tile_index > tileset_width_in_cells do
        row = row + 1
        tile_index = tile_index - (tileset_width_in_cells)
    end

    local column = tile_index -- since what is left is the column position
    
    -- note how the 0 based coords for drawing are kept with -1 subtractions
    return love.graphics.newQuad((column - 1) * TILE_SIZE, (row - 1) * TILE_SIZE,
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
    g.window_width, g.window_height = pixel_adjust(w, h)
    g.game_state:refresh()
end

function blueprints_generator(input_table)
    local id -- blueprint's id
    local tile -- blueprint's tile
    -- components not implemented in components_interface will be ignored and flagged with a warning
    local all_components = {}
    -- this table stores which powers have been saved to avoid duplicates
    local blueprint_powers = {}
    -- this table stores which components have been saved to avoid duplicates
    local stored_components = {}
    -- this will be the list of actual components to input as argument to new entity
    local blueprint_components = {}
    -- this variable will store eventual multi-value input for tile index or a pool name
    local index_value = {}

    for i, element in ipairs(input_table) do
        -- useful copy of element, used for element type check
        local element_output
        -- only used for components, not for id, tile or power values
        -- pos is set to 1 by default and keeps track of the separator position inside the string
        local pos = 1
        -- only used for components. Note that components ids and their arguments are separated
        -- with commas. This variable stores every input of the component
        local component_tags = {}

        -- checking if the element is the Blueprint's id
        element_output = strings_separator(element, "@", 1)
        
        if element_output[2] then
            print("id: " .. element_output[2])
            id = element_output[2]

            -- checking to ensure Blueprint id uniqueness
            if BLUEPRINTS_LIST[id] then
                error_handler('Blueprint "'..id..'" is not unique, duplicates ignored.')
                return false
            end

            goto continue
        end

        -- checking if the element is the Blueprint's tile/tile_group
        element_output = strings_separator(element, ":", 1)
        -- an entity can have a fixed tile, or a random tile from a group in sprites_groups.
        -- In the latter case, the selected tile will be removed from the pool once used.
        -- Now it is being checked if the Entity has a fixed tile or a random one from a group.
        if element_output[2] then
            print("tile: " .. element_output[2])
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

            -- check if group is valid or not (char ':' may have been manually misused)
            if not sprites_groups[element_output[2]] then
                error_handler("Trying to assign sprite to an Entity from a non-existing sprites_group")
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()

                return false
            end

            -- checking the group length, stored beforehand in sprites_groups_manager()
            group_length = sprites_groups[element_output[2] .. "_length"]

            -- check if there are still sprites available in selected group
            if group_length <= 0 then
                error_handler("Trying to assign sprite to an Entity from a depleted sprites_group (more entities than available sprites)")
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()

                return false
            end

            -- saving the random index, otherwise different results will be output when setting/removing
            for j = 1, math.random(group_length) do
                selected_index = selected_index + 1
            end            

            -- setting randomly chosen sprite
            tile = sprites_groups[element_output[2]][selected_index]
            -- removing randomly chosen sprite from its group
            table.remove(sprites_groups[element_output[2]], selected_index)
            -- length of the group was reduced by one
            sprites_groups[element_output[2] .. "_length"] = group_length - 1

            goto continue
        end

        -- checking if the element is a power
        element_output = strings_separator(element, "*", 1)

        if element_output[2] then
            -- only used for powers. Structure is like components, but effects are functions
            local power_effects = strings_separator(element_output[2], ",", pos)
            
            -- check power name uniqueness
            if blueprint_powers[power_effects[1]] then
                error_handler('Power"'..power_effects[1]..'" for blueprint "'..id..'" is not unique, duplicates ignored.')
                goto continue
            end
            
            print("Power: " .. power_effects[1])

            -- store newly added power in blueprint_powers, to add to final Entity
            blueprint_powers[power_effects[1]] = Power(power_effects)

            goto continue
        end    

        -- if nothing of the above is true, then element must be a component

        component_tags = strings_separator(element, ",", pos)
        -- all_components contains tables with a element tag and its optional arguments tags
        table.insert(all_components, component_tags)

        ::continue::
    end 

    for i, comp_tags in ipairs(all_components) do
        -- translating components tags into actual components thanks to components_interface
        local new_component = components_interface(comp_tags)
        -- check for duplicate components (comp_tags[1] = component's name)
        if stored_components[comp_tags[1]] then
            error_handler('Component "'..comp_tags[1]..'" for blueprint "'..id..'" is not unique, duplicates ignored.')
            goto continue
        end

        -- check for component validity and in case insert it
        if new_component then
            -- at this stage, we don't store any component, only its data for later use
            table.insert(blueprint_components, comp_tags)
            stored_components[comp_tags[1]] = true
        else
            -- warning with console if an invalid component was found inside CSV
            error_handler('Invalid component: "'..comp_tags[1]..'" was ignored.')
        end

        ::continue::
    end

    -- create final blueprint from entity and its components and save it in BLUEPRINTS_LIST
    local new_blueprint = Entity(id, tile, blueprint_components, blueprint_powers)
    BLUEPRINTS_LIST[id] = new_blueprint
end

function blueprints_manager()
    -- all game entities are managed by a single CSV file.
    local entities_csv = csv_reader(PATH_TO_CSV .. "blueprints.csv")

    -- check if operation went right; if not, activate error_handler
    if type(entities_csv) == "string" then
        error_handler("The above error was triggered while trying to read blueprints.csv")
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
        blueprints_generator(entity_components)
    end

    return true
end

function camera_setting()
    -- setting g.camera to the first spawned player
    local camera_entity = g.players_party[1]["entity"]
    if g.camera["entity"] == nil then
        g.camera["entity"] = camera_entity
        g.camera["x"] = camera_entity.cell["cell"].x
        g.camera["y"] = camera_entity.cell["cell"].y
    end
end

-- a simple dice throwing function accepting any number of any type of dice
function dice_roll(die_set, success)
    local throws = die_set[1]
    local dies_value = die_set[2]
    local modifier = die_set[3] or 0
    local result = 0

    for i = 1, throws do
        result = result + math.random(1, dies_value)
    end
    -- apply modifier
    result = result + modifier
    -- if success is request, it must be >= 0 or return false
    if success and success - result < 0 then result = false end
    -- numerical results can't be < 0
    if result and result < 0 then result = 0 end 
    return result
end

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
        -- if it's not the NPCs turn, skip single NPC activation
        if not npc_turn then goto continue end

        for i, npc in ipairs(g.npcs_group) do
            -- check if the NPC is alive or is waiting to be removed from game
            if npc.alive then
                g.npcs_group[i].components["npc"]:activate(g.npcs_group[i])
            end
        end

        ::continue::
        g.is_tweening = false
        console_cmd(nil)
        g.game_state:refresh()        
    end)
end

function ui_manager_play()
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.window_width, g.window_height)
    love.graphics.setCanvas(new_canvas)

    -- clear to transparent black
    love.graphics.clear(0, 0, 0, 0)
    -- drawing UI on top of everything for the current player    
    love.graphics.setFont(FONTS["subtitle"])
    -- making the UI semi-transparent
    love.graphics.setColor(0.78, 0.96, 0.94, 1)
    
    -- print player stats
    love.graphics.print(
        g.camera["entity"].name,
        PADDING, g.window_height - (PADDING * 3.5)
    )
    love.graphics.print(
        "Life "..g.camera["entity"].components["stats"].stats["hp"],
        PADDING, g.window_height - (PADDING * 2.5)
    )
    love.graphics.print(
        "Gold "..g.camera["entity"].components["stats"].stats["gold"], -- WARNING: stats component is not forced and therefore 'gold' will crash game. UI system should be modular and adapt to dynamic stats!  
        PADDING, g.window_height - (PADDING * 1.5)
    )

    -- if present, print console["string"]
    if g.console["string"] then
        love.graphics.printf(g.console["string"], 0,
        g.window_height - (PADDING * 1.5), g.window_width, "center")
    end

    -- print console events
    love.graphics.setColor(g.console["color3"][1], g.console["color3"][2], g.console["color3"][3], 1)
    love.graphics.print(
        g.console["event3"], PADDING, (PADDING)
    )
    love.graphics.setColor(g.console["color2"][1], g.console["color2"][2], g.console["color2"][3], 1)
    love.graphics.print(
        g.console["event2"], PADDING, (PADDING * 2)
    )
    love.graphics.setColor(g.console["color1"][1], g.console["color1"][2], g.console["color1"][3], 1)
    love.graphics.print(
        g.console["event1"], PADDING, (PADDING * 3)
    )
    
    -- restoring default RGBA, since this function influences ALL graphics
    love.graphics.setColor(1, 1, 1, 1)

    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()

    return new_canvas
end

function ui_manager_menu(text, input_phase, n_of_players, current_player, input_name)
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.window_width, g.window_height)
    love.graphics.setCanvas(new_canvas)

    love.graphics.setFont(FONTS["title"])
    love.graphics.printf(GAME_TITLE, 0, g.window_height / 5, g.window_width, "center")

    love.graphics.setFont(FONTS["subtitle"])
    if input_phase == 1 then
        love.graphics.printf(text[input_phase] .. n_of_players, 0, g.window_height / 5 + (PADDING * 4), g.window_width, "center")
    else
        love.graphics.printf(text[input_phase] .. text[current_player + 2] .. "rogue:\n" .. input_name,
        0, g.window_height / 5 + (PADDING * 4), g.window_width, "center")
    end

    return new_canvas
end

function ui_manager_gameover()
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.window_width, g.window_height)
    love.graphics.setCanvas(new_canvas)

    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.setFont(FONTS["title"])
    love.graphics.printf("Game Over", 0, g.window_height / 4 - PADDING, g.window_width, "center")

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(FONTS["subtitle"])
    love.graphics.printf("These souls have left us forever:", 0, g.window_height / 4 + (PADDING), g.window_width, "center")

    -- printing all deceased players and info about their death
    for i, death in ipairs(g.cemetery) do 
        love.graphics.printf(death["player"]..", killed by "..death["killer"].." for "..death["loot"].." gold,\n"..
        "has found a final resting place in "..death["place"]..".",
        0, g.window_height / 3.5 + (PADDING * (i * 3)), g.window_width, "center")
    end

    return new_canvas
end

function ui_manager_credits(credits_image)
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.window_width, g.window_height)
    love.graphics.setCanvas(new_canvas)

    -- this is simply an optimal proportion between the image size and the screen size
    local scale = g.window_height / 1300
    local credits_width = credits_image:getWidth()
    local credits_height = credits_image:getHeight()

    -- always keeping the image with its original proportions and in the screen center
    love.graphics.draw(
        credits_image,
        g.window_width / 2 - (credits_width / 2 * scale), g.window_height / 2 - (credits_height / 2 * scale),
        0, scale, scale
    )
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
    if entity.components["obstacle"] or entity.components["player"] or entity.components["npc"] then
        print("Obstacle entity destroyed")

        entity.cell["cell"].occupant = nil
    else
        entity.cell["cell"].entity = nil
    end
end

-- this func registers game events and chronologially displays them
function console_event(event, font_color)
    local events_table = {}
    -- extracting values from g.console. In Lua, tables are passed as ref, not as value!
    for i, v in pairs(g.console) do
        events_table[i] = v
    end

    -- assigning new values to global colors
    g.console["color3"] = events_table["color2"]
    g.console["color2"] = events_table["color1"]
    g.console["color1"] = font_color or {[1] = 0.78, [2] = 0.96, [3] = 0.94,}
    
    -- assigning new values to global strings
    g.console["event3"] = events_table["event2"]
    g.console["event2"] = events_table["event1"]
    g.console["event1"] = event
    g.canvas_ui = ui_manager_play()
end

function console_cmd(cmd)
    g.console["string"] = cmd
    g.canvas_ui = ui_manager_play()
end