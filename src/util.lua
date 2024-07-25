-- useful variables that get used often
local TILESET_WIDTH = g.TILESET:getWidth()
local TILESET_HEIGHT = g.TILESET:getHeight()
local TILE_SIZE = mod.TILE_SIZE or 20 -- used for cell size/tileset slicing.

-- simple, user-friendly error message handler
function error_handler(error_input_1, error_input_2)
    table.insert(g.error_messages, error_input_1 or "Triggered error handler without any message")
    if error_input_2 then
        table.insert(g.error_messages, error_input_2)
    end
end

-- this simple function returns all the optional arguments of features
function feature_tags(tags)
    if tags then
        local feature_tags = {}
        for i,v in ipairs(tags) do
            -- avoiding first tag, as it is the id of the feature!
            if i ~= 1 then
                table.insert(feature_tags, v)
            end
        end
        return feature_tags
    else
        return nil
    end
end

--[[
    Features interface. Used to link features and their optional args to the actual components.
    These are the the strings you feed inside the 'entities.csv' to explain to the engine what an
    entity is composed of. The function below needs to be updated with each added feature!
]]--
function features_interface(tags)
    -- tags[1] = feature id, others (if present) are their arguments
    if FEATURES_TABLE[tags[1]] ~= nil then
        -- adding () to FEATURES_TABLE values, to turn them into functions
        return FEATURES_TABLE[tags[1]](feature_tags(tags))
    else
        return nil
    end
end

function strings_separator(line, separator, pos)
    local line = line
    local separator = separator
    local pos = pos
    local results = {} 
    -- parsing results for each line, until end of line
    while true do
        if line == nil then
            error_handler("ERROR READING CSV: Blank file/line")
            break
        end
        -- storing starting and end points between commas, updating pos value
        local start_point, end_point = string.find(line, separator, pos)
        if (start_point) then
            --[[ 
            start_point - 1 is used since we do not want to store the sep. value,
            so we store from start/after a sep. to before the next sep.
            --]]
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
    note that the error_handler is never called in csv_reader, since it is called various times
    and if we call it in main.lua we can output some more info about the error
]]--
function csv_reader(input_csv, separator)
    local input_line = "nil"
    local new_table = {} -- final table
    local separator = separator or "|"
    local count = 1
    if input_csv ~= nil then
        local file = io.open(input_csv, "r")
        if file ~= nil then
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
        else
            new_table = "ERROR READING CSV: Invalid file/path"
            return new_table
        end
    else
        new_table = "ERROR READING CSV: Missing input"
        return new_table
    end
    -- returning results only if the whole operation went right
    return new_table
end

function entities_spawner(blueprint, loc_row, loc_column)
    local player_num = 1
    local is_occupant = false
    local is_npc = false
    local new_player = {
        ["entity"] = nil,
        ["player_component"] = nil
    }

    -- now create Component instances to feed to new Entity
    local instanced_features = {}
    local instanced_entity = nil

    for i, comp_tags in ipairs(blueprint["bp"].features) do
        -- translating features tags into actual components thanks to features_interface
        local new_feature = features_interface(comp_tags)
        instanced_features[comp_tags[1]] = new_feature

        -- checking for components that need to be stored
        if comp_tags[1] == "npc" then
            -- NPCs need to be stored for easier, faster calling
            is_npc = true
            is_occupant = true
        elseif comp_tags[1] == "player" then
            new_player["player_component"] = new_feature
            is_occupant = true
        elseif comp_tags[1] == "block" then
            is_occupant = true
        end
    end

    instanced_entity = Entity(blueprint["bp"].id, blueprint["bp"].tile, instanced_features, blueprint["name"])

    -- once special components are stored, finish Entityt identity 
    if is_npc then
        -- save NPC controller in entity.controller
        instanced_entity.controller = instanced_entity.features["npc"]
        table.insert(g.npcs_group, instanced_entity)
    -- if one uses a 'Npc' comp with a player, it just becomes a Npc!
    elseif instanced_entity.id == "player" and not is_npc then
        if loc_row and loc_column then
            -- save Player controller in entity.controller
            instanced_entity.controller = instanced_entity.features["player"]
            -- immediately check if player has Stats() component with "hp". If not, add it/them
            if instanced_entity.features["stats"] then
                if not instanced_entity.features["stats"].stats["hp"] then
                    instanced_entity.features["stats"].stats["hp"] = 1
                end
            else
                local stat_feature = features_interface({"stats", "hp:1"})
                instanced_entity.features["stats"] = stat_feature
            end

            new_player["entity"] = instanced_entity
            table.insert(g.players_party, new_player)
        else
            -- as soon as missing player spawn locations are called, call FatalError State
            error_handler("Insufficient player spawning locations in current map. Each player needs one.")
            g.game_state:exit()
            g.game_state = StateFatalError()
            g.game_state:init()
        end
    end

    -- positioning Entities
    instanced_entity.cell["cell"] = g.grid[loc_row][loc_column]
    instanced_entity.cell["grid_row"] = loc_row
    instanced_entity.cell["grid_column"] = loc_column

    -- occupying the cell appropriately depending on Entity type
    if is_occupant then
        instanced_entity.cell["cell"].occupant = instanced_entity
    else
        instanced_entity.cell["cell"].entity = instanced_entity
    end
    -- adding the entity to the g.render_group IF it is not invisible by default
    if not instanced_entity.features["invisible"] then
        table.insert(g.render_group, instanced_entity)
    end
end

--[[
    During g.grid generation, tiles (if present) are assigned to cells. After this process,
    tiles are drawn once and stored for next drawing passes, so they get drawn only once and 
    function as a base canvas where dynamic entities will be drawn each loop.
]]--
function map_generator(map_values, regen_players)
    local cell_x = 0
    local cell_y = 0
    local player_spawn_loc = {}
    -- for every g.grid row, assign number of columns cells; each one with x and y values
    for i = 1, g.grid_y do
        g.grid[i] = {}
        for j = 1, g.grid_x do
            local tile_index
            local blueprint = false

            -- filling g.grid position with a cell 'struct'
            g.grid[i][j] = {cell}
            g.grid[i][j].x = cell_x
            g.grid[i][j].y = cell_y

            -- checking if a tile contains Entities...
            local tile_values = strings_separator(map_values[i][j], ",", 1)
            -- ...if it does, the table will have at least a second element:
            if tile_values[2] then
                tile_index = tile_values[1]
                -- if tile_values[1] is a legal tile, then it's a blueprint.
                -- else, if it is = x, it's a player spawn point!
                if tile_index:match("%d") then
                    -- save Entity in the blueprint variable
                    if BLUEPRINTS_LIST[tile_values[2]] then
                        blueprint = {["bp"] = BLUEPRINTS_LIST[tile_values[2]],
                        ["name"] = nil
                        }

                        -- checking if a special name for the entity was fed in the map
                        if tile_values[3] then 
                            blueprint["name"] = tile_values[3]
                        end
                    else
                        error_handler("Map: illegal entity at row "..i.." column "..j..". Ignored.")
                    end
                elseif tile_index == "x" and tile_values[2]:match("%d") then
                    -- REMEMBER: values extracted from CSV (such as tile_values[2]) are STRINGS!
                    player_spawn_loc[tonumber(tile_values[2])] = {["row"] = i, ["column"] = j, ["cell"] = g.grid[i][j]}
                    -- if that's a spawn point, no need for more calculations, just go to next loop
                    g.grid[i][j].index = "empty"
                    goto continue
                else
                    error_handler("Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell.")
                    g.grid[i][j].index = "empty"
                    goto continue
                end                    
            else
                tile_index = map_values[i][j]
                -- if tile_index == nil then there must be a blank line or the value is unreadable
                -- if tile index doesn't match a number ("%d") then there is an illegal value
                if tile_index == nil or not tile_index:match("%d") then
                    -- not-numeric value for a tile
                    error_handler("Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell.")
                    g.grid[i][j].index = "empty"
                    goto continue
                elseif tile_index == "x" then
                    -- spawn location lacking an order number
                    error_handler("Map: spawn point at row "..i.." column "..j.." lacking second arg. Replaced with empty cell.")
                    g.grid[i][j].index = "empty"
                    goto continue
                end
            end

            -- extracting the quad for graphics
            g.grid[i][j].tile = tile_to_quad(tile_index)

            -- checking if the map has an empty tile there (0 or < 0), and marking it as 'empty'
            if tonumber(tile_index) > 0 then
                -- 'g.grid' reads STRINGS and NOT numbers! 
                g.grid[i][j].index = tile_index
            else
                g.grid[i][j].index = "empty"
            end

            -- spawn here
            if blueprint then
                entities_spawner(blueprint, i, j)
            end
            -- if we found a spawn location in the cell, we skipped to here
            ::continue::

            -- increase column value
            cell_x = cell_x + TILE_SIZE
        end
        -- reset columns value, increase row value
        cell_x = 0
        cell_y = cell_y + TILE_SIZE
    end

    -- not spawning the players again if we just changed level
    if regen_players then
        -- spawning players: in the menu we have inserted players Entities but not their input_comp!
        local players_party_copy = g.players_party
        g.players_party = {}
        for i,blueprint in ipairs(players_party_copy) do
            -- check that all 4 spawn locations for players were set
            if not player_spawn_loc[i] then
                error_handler("Map has insufficient Player Spawn Points. All maps should have four.")
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()
                break
            end
            entities_spawner(blueprint, player_spawn_loc[i]["row"], player_spawn_loc[i]["column"])
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

function map_reader(map, regen_players)
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

    -- check if operation went right; if not, activate error_handler
    if type(map_values) == "string" then
        error_handler(map_values, "The above error was triggered while trying to read map.csv")
        return false
    else
        -- setting g.grid size depending on map's CSV input
        for row, column in ipairs(map_values) do
            g.grid_y = row
            for column_number, columns_value in ipairs(column) do
                g.grid_x = column_number
            end
        end

        -- initializing game canvases (g.canvas_base  with tiles, g.canvas_final adds Entities)
        g.canvas_final = love.graphics.newCanvas(g.grid_x * TILE_SIZE, g.grid_y * TILE_SIZE)
        g.canvas_base  = love.graphics.newCanvas(g.grid_x * TILE_SIZE, g.grid_y * TILE_SIZE)

        -- getting tiles features groups from the specific CSV file
        local tiles_features_csv = csv_reader(PATH_TO_CSV .. "tiles_features.csv")

        -- check if operation went right; if not, activate error_handler
        if type(tiles_features_csv) == "string" then
            error_handler(tiles_features_csv, "The above error was triggered while trying to read tiles_features.csv")
            return false
        else
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
            map_generator(map_values, regen_players)
        end
    end
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
    -- checking if index is in g.TILESET's range (NOTE: indexes start from 1)
    -- or if index is a string, the 'x' value used to mark player spawn positions
    if tile_index <= 0 or tile_index > max_index then
        return nil
    end
    local row = 1
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
end

function blueprints_generator(id, tile, features_list_input)
    -- features not implemented in features_interface will be ignored and flagged with a warning
    local interface_tags = {}
    -- this will be the list of actual features to input as argument to new entity
    local features_list = {}
    for i, comp in ipairs(features_list_input) do
        -- pos is set to 1 by default and keeps track of the separator position inside the string
        local pos = 1
        -- note that features and their arguments are separated with commas
        -- this variable contains every input of the component
        local feature_with_optional_inputs = strings_separator(comp, ",", pos)
        -- interface_tags contains tables with a comp tag and its optional arguments tags
        table.insert(interface_tags, feature_with_optional_inputs)
    end             
    for i, comp_tags in ipairs(interface_tags) do
        -- translating features tags into actual components thanks to features_interface
        local new_feature = features_interface(comp_tags)
        if new_feature ~= nil then
            -- at this stage, we don't store any Component, only its data for later use
            table.insert(features_list, comp_tags)
        else
            -- warning with console if an invalid feature was found inside CSV
            print('Invalid feature: "'..comp_tags[1]..'" was ignored.')
            error_handler('Invalid feature: "'..comp_tags[1]..'" was ignored.')
        end
    end
    local new_blueprint = Entity(id, tile, features_list)
    BLUEPRINTS_LIST[id] = new_blueprint
end

function blueprints_manager()
    -- all game entities are managed by a single CSV file.
    local entities_csv = csv_reader(PATH_TO_CSV .. "entities.csv")

    -- check if operation went right; if not, activate error_handler
    if type(entities_csv) == "string" then
        error_handler(entities_csv, "The above error was triggered while trying to read entities.csv")
        return false
    end

    for i, line in ipairs(entities_csv) do
        -- keeping track of all the entity features and counting
        local n_of_elements = 0
        local entity_features = {}
        -- counting number of components contained in each line
        for i2, component in ipairs(line) do
            n_of_elements = n_of_elements + 1
        end
        -- using j to index elements assigned to entity_features, starting from 1
        local j = 1
        -- storing features starting from the third, since the first two elements are id and tile
        for k = 3, n_of_elements do
            entity_features[j] = entities_csv[i][k]
            j = j + 1
        end
        -- passing the new entity with the data extracted from the CSV file (id, tile, features)
        blueprints_generator(entities_csv[i][1], entities_csv[i][2], entity_features)
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
    -- updating current_player to next entity for tweening purposes
    local x_for_tweening = current_player["entity"].cell["cell"].x
    local y_for_tweening = current_player["entity"].cell["cell"].y
    -- set next (or first) player as the g.camera entity
    g.camera["entity"] = current_player["entity"]
    -- tween between previous and current active player
    Timer.tween(TWEENING_TIME, {
        [g.camera] =  {x = x_for_tweening, y = y_for_tweening}
    }):finish(function ()
        if npc_turn and g.npcs_group then
            for i, npc in ipairs(g.npcs_group) do
                -- check if the NPC is alive or needs to be removed from game
                if npc.alive == false then
                    table.remove(g.npcs_group, i)
                else
                    g.npcs_group[i].features["npc"]:activate(g.npcs_group[i])
                end
            end
        end
        g.is_tweening = false
    end)
end