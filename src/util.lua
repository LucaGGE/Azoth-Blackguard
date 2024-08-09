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
    These are the the strings you feed inside the 'entities.csv' to explain to the engine what an
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
    note that the error_handler is never called in csv_reader, since it is called various times
    and if we call it in main.lua we can output some more info about the error
]]
function csv_reader(input_csv, separator)
    local new_table = {} -- final table

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

function entities_spawner(blueprint, loc_row, loc_column)
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
        elseif comp_tags[1] == "bulky" then
            is_occupant = true
        end
    end

    instanced_entity = Entity(blueprint["bp"].id, blueprint["bp"].tile, instanced_components, blueprint["name"])

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
            entities_spawner(blueprint, i, j)
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
                    blueprint["name"] = tile_value_3
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
            entities_spawner(player_blueprint, player_spawn_loc[i]["row"], player_spawn_loc[i]["column"])
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
    if not type(map_values) == "string" then
        error_handler(map_values, "The above error was triggered while trying to read map.csv")
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
        error_handler(tiles_features_csv, "The above error was triggered while trying to read tiles_features.csv")
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

function blueprints_generator(id, tile, components_list_input)
    if BLUEPRINTS_LIST[id] then
        error_handler('Blueprint "'..id..'" is not unique, duplicates ignored.')
        return false
    end
    -- components not implemented in components_interface will be ignored and flagged with a warning
    local all_components = {}
    -- this table stores which components have been saved to avoid duplicates
    local stored_components = {}
    -- this will be the list of actual components to input as argument to new entity
    local blueprint_components = {}
    for i, comp in ipairs(components_list_input) do
        -- pos is set to 1 by default and keeps track of the separator position inside the string
        local pos = 1
        -- note that components names and their arguments are separated with commas
        -- this variable contains every input of the component
        local component_tags = strings_separator(comp, ",", pos)
        -- all_components contains tables with a comp tag and its optional arguments tags
        table.insert(all_components, component_tags)
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
    local new_blueprint = Entity(id, tile, blueprint_components)
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
        -- keeping track of all the entity components and counting
        local n_of_elements = 0
        local entity_components = {}
        -- counting number of components contained in each line
        for i2, component in ipairs(line) do
            n_of_elements = n_of_elements + 1
        end
        -- using j to index elements assigned to entity_components, starting from 1
        local j = 1
        -- storing components starting from the third, since the first two elements are id and tile
        for k = 3, n_of_elements do
            entity_components[j] = entities_csv[i][k]
            j = j + 1
        end
        -- passing the new entity with the data extracted from the CSV file (id, tile, components)
        blueprints_generator(entities_csv[i][1], entities_csv[i][2], entity_components)
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
        if not npc_turn and not g.npcs_group then goto continue end

        for i, npc in ipairs(g.npcs_group) do
            -- check if the NPC is alive or needs to be removed from game
            if npc.alive then
                g.npcs_group[i].components["npc"]:activate(g.npcs_group[i])
            end
        end

        ::continue::
        g.is_tweening = false
        -- canceling previous player values in global strings
        g.local_string = nil
        g.console_string = nil
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
    
    love.graphics.print(
        g.camera["entity"].name,
        FONT_SIZE_SUBTITLE, g.window_height - (FONT_SIZE_SUBTITLE * 3.5)
    )
    love.graphics.print(
        "Life "..g.camera["entity"].components["stats"].stats["hp"],
        FONT_SIZE_SUBTITLE, g.window_height - (FONT_SIZE_SUBTITLE * 2.5)
    )
    love.graphics.print(
        "Gold "..g.camera["entity"].components["stats"].stats["gold"], -- WARNING: stats component is not forced and therefore 'gold' will crash game. UI system should be modular and adapt to dynamic stats!  
        FONT_SIZE_SUBTITLE, g.window_height - (FONT_SIZE_SUBTITLE * 1.5)
    )

    if g.console_string then
        love.graphics.printf(g.console_string, 0,
        g.window_height - (FONT_SIZE_SUBTITLE * 1.5), g.window_width, "center")
    end
    
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
        love.graphics.printf(text[input_phase] .. n_of_players, 0, g.window_height / 5 + (FONT_SIZE_TITLE * 2), g.window_width, "center")
    else
        love.graphics.printf(text[input_phase] .. text[current_player + 2] .. "rogue:\n" .. input_name,
        0, g.window_height / 5 + (FONT_SIZE_TITLE * 2), g.window_width, "center")
    end

    return new_canvas
end

function ui_manager_gameover()
    -- generating a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.window_width, g.window_height)
    love.graphics.setCanvas(new_canvas)

    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.setFont(FONTS["title"])
    love.graphics.printf("Game Over", 0, g.window_height / 4 - FONT_SIZE_TITLE, g.window_width, "center")

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(FONTS["subtitle"])
    love.graphics.printf("These souls have left us forever:", 0, g.window_height / 4 + (FONT_SIZE_SUBTITLE), g.window_width, "center")

    -- printing all deceased players and info about their death
    for i, death in ipairs(g.cemetery) do 
        love.graphics.printf(death["player"]..", killed by "..death["killer"].." for "..death["loot"].." gold,\n"..
        "has found a final resting place in "..death["place"]..".",
        0, g.window_height / 3.5 + (FONT_SIZE_SUBTITLE * (i * 3)), g.window_width, "center")
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
    if entity.components["bulky"] or entity.components["player"] or entity.components["npc"] then
        print("Bulky entity destroyed")
        entity.cell["cell"].occupant = nil
    else
        entity.cell["cell"].entity = nil
    end
end