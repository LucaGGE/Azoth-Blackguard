-- useful variables that get used often in the scope of util.lua
local TILESET_WIDTH = TILESET:getWidth()
local TILESET_HEIGHT = TILESET:getHeight()
local sprites_groups = {} -- for blueprints with random/semi-random sprites
local SIZE = {
    ["MAX"] = (mod.SIZE_MAX or 30) * SIZE_MULT,
    ["SUB"] = (mod.SIZE_SUB or 17.5) * SIZE_MULT,
    ["TAG"] = (mod.SIZE_TAG or 22.5) * SIZE_MULT,
    ["DEF"] = (mod.SIZE_DEF or 15) * SIZE_MULT,
    ["ERR"] = (mod.SIZE_DEF or 12) * SIZE_MULT,
    ["PAD"] = (mod.padding or 16) * SIZE_MULT
}
local FONTS = {
    ["tag"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE["TAG"]),
    ["logo"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE["SUB"]),
    ["title"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE["MAX"]),
    ["subtitle"] = love.graphics.newFont("fonts/alagard.ttf", SIZE["SUB"]),
    ["ui"] = love.graphics.newFont("fonts/alagard.ttf", SIZE["DEF"]),
    ["error"] = love.graphics.newFont("fonts/BitPotion.ttf", SIZE["ERR"]),
    ["console"] = love.graphics.newFont("fonts/VeniceClassic.ttf", SIZE["DEF"]),
}

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
    local new_player

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

        -- check if player has Stats() comp with hp, maxhp and hunger
        if not instanced_entity.comp["stats"] then
            local stat_component = components_interface(
                {"stats", "hp=1", "maxhp=1", "hunger=0", "appetite=1", "stamina=20"}
            )
            instanced_entity.comp["stats"] = stat_component
        end

        -- all players have access to at least a basic inventory view with no spaces
        if not instanced_entity.comp["inventory"] then
            local inv_component = components_interface(
                {"inventory", "0"}
            )
            instanced_entity.comp["inventory"] = inv_component
        end

        new_player = instanced_entity
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

    return instanced_entity
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
        local new_index = tile_index

        if tonumber(tile_index) == 0 then
            new_index = "empty"
        end
        
        -- if no tile, index == 0 or index == < 0, mark cell index as 'empty'
        if tonumber(tile_index) < 0 then
            error_handle("Cell invalid by index < 0 value at "..i..", "..j)
            new_index = "empty"
            tile_index = 0
        end

        if not TILES_PHYSICS[new_index] then
            error_handler("Cell invalid by index value absent in TILES_PHYSICS at "..i..", "..j)
            new_index = "empty"
            tile_index = 0
        end

        -- extracting the quad for graphics
        g.grid[i][j].tile = tile_to_quad(tile_index)
                
        -- 'g.grid' reads STRINGS and NOT numbers! 
        g.grid[i][j].index = new_index

        -- spawning the entity from a blueprint
        if blueprint then
            entities_spawner(blueprint, i, j, entity_name)
        end
    end
    -- decision table for entity/no entity cells chain of action
    local CELL_DTABLE = {
        [true] = function(tile_value_1, tile_value_2, tile_value_3, i, j)
            local tile_index = tile_value_1
            local type
            local blueprint

            -- if tile_index = x, it's a player spawn point!
            if tile_index == "x" and tile_value_2:match("%d") then
                -- if a spawn point, save locations for players to be spawned later
                player_spawn[tonumber(tile_value_2)] = {["row"] = i, ["col"] = j, ["cell"] = g.grid[i][j]}
                -- avoid finalize_cell() func, instead set cell to 'empty'
                g.grid[i][j].index = "empty"

                return true
            end

            -- if tile_index isn't x and neither a number, it's an illegal value!
            if not tile_index:match("%d") then
                error_handler("Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell.")
                g.grid[i][j].index = "empty"

                return false
            end

            -- check if tile_value_2 is a valid BP
            type = str_slicer(tile_value_2, "@", 1)

            if type[2] then
                local bp_index = type[2]
                
                if not BP_LIST[bp_index] then
                    error_handler(
                        "Map: illegal entity at row "..i.." column "..j..". Ignored."
                    )

                    finalize_cell(tile_index, false, i, j)

                    return false
                end
                
                -- save entity in the blueprint variable
                blueprint = BP_LIST[bp_index]
                -- checking if a special name for the entity was fed in the map
                entity_name = tile_value_3

                goto continue
            end

            -- if tile_value_2 is not a BP, check if it's a Selector
            type = str_slicer(tile_value_2, "#", 1)

            if type[2] then
                local selector_index = tile_value_2
                local selector_ref
                local bp_index

                if not SE_LIST[selector_index] then
                    error_handler(
                        "Map: illegal selector at row "..i.." column "..j..". Ignored."
                    )
                    print(selector_index)

                    return false
                end

                selector_ref = SE_LIST[selector_index]

                bp_index = dice_roll(selector_ref.die_set)

                blueprint = BP_LIST[selector_ref.elements[bp_index]]

                goto continue
            end

            -- if tile_value_2 is not a Selector, check if it's a Matrix
            type = str_slicer(tile_value_2, "&", 1)

            if type[2] then
                local matrix_index = tile_value_2
                local matrix_ref
                local selector_index
                local selector_ref
                local bp_index

                if not MA_LIST[matrix_index] then
                    error_handler(
                        "Map: illegal matrix at row "..i.." column "..j..". Ignored."
                    )
                    print(matrix_index)

                    return false
                end

                matrix_ref = MA_LIST[matrix_index]

                -- first set selector_index as a random element
                selector_index = tonumber(dice_roll(matrix_ref.die_set))
                -- then set selector_index as actual Selector id string reference
                selector_index = matrix_ref.elements[selector_index]

                selector_ref = SE_LIST[selector_index]

                bp_index = dice_roll(selector_ref.die_set)

                blueprint = BP_LIST[selector_ref.elements[bp_index]]

                goto continue
            end

            if not blueprint then
                error_handler("Cell contains invalid arg without @, # or & identifiers at "..i.." column "..j..". Ignored.")
                blueprint = false
            end

            ::continue::
            finalize_cell(tile_index, blueprint, i, j)

            return true
        end,
        [false] = function(tile_value_1, i, j)
            -- reset entity_name value
            entity_name = nil
            local tile_index = tile_value_1

            -- if tile_index == nil there must be a blank line/unreadable value.
            -- If tile index is not a number then there is an illegal value!
            if not tile_index or not tile_index:match("%d") then
                error_handler("Map: illegal cell value at row "..i.." column "..j..". Replaced with empty cell.")
                g.grid[i][j].index = "empty"

                return false
            end

            -- if spawn location but lacking an order number, then...
            if tile_index == "x" then
                error_handler("Map: spawn point at row "..i.." column "..j.." lacking second arg. Replaced with empty cell.")
                g.grid[i][j].index = "empty"

                return false
            end

            -- cell simply has no entities inside!
            finalize_cell(tile_index, false, i, j)
            return true
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
            player.cell["cell"] = player_spawn[i]["cell"]
            player.cell["cell"].pawn = player["entity"]
            player.cell["grid_row"] = player_spawn[i]["row"]
            player.cell["grid_col"] = player_spawn[i]["col"]
            table.insert(g.render_group, player)
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

-- when screen changes to larger or smaller sizes, fonts and sizes need adjustment
function size_adjust()
    SIZE = {
        ["MAX"] = (mod.SIZE_MAX or 30) * SIZE_MULT,
        ["SUB"] = (mod.SIZE_SUB or 17.5) * SIZE_MULT,
        ["TAG"] = (mod.SIZE_TAG or 22.5) * SIZE_MULT,
        ["DEF"] = (mod.SIZE_DEF or 15) * SIZE_MULT,
        ["ERR"] = (mod.SIZE_DEF or 12) * SIZE_MULT,
        ["PAD"] = (mod.padding or 16) * SIZE_MULT
    }
    FONTS = {
        ["tag"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE["TAG"]),
        ["logo"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE["SUB"]),
        ["title"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE["MAX"]),
        ["subtitle"] = love.graphics.newFont("fonts/alagard.ttf", SIZE["SUB"]),
        ["ui"] = love.graphics.newFont("fonts/alagard.ttf", SIZE["DEF"]),
        ["error"] = love.graphics.newFont("fonts/BitPotion.ttf", SIZE["ERR"]),
        ["console"] = love.graphics.newFont("fonts/VeniceClassic.ttf", SIZE["DEF"]),
    }
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

    -- change dinamically SIZE_MULT
    if w < 640 then
        local mod_mult = mod.IMAGE_SIZE_MULTIPLIER

        SIZE_MULT = mod_mult and mod_mult / 2 or 1
        size_adjust()
    end

    if w >= 640 then
        local mod_mult = mod.IMAGE_SIZE_MULTIPLIER

        SIZE_MULT = mod_mult or 2
        size_adjust()
    end

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
    BP_LIST[id] = Entity(id, tile, blueprint_components, blueprint_powers)
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
        local j = 1

        -- counting number of components contained in each line
        for _, component in ipairs(line) do
            n_of_elements = n_of_elements + 1
        end
        -- using j to index elements assigned to entity_components, starting from 1
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

-- NOTE: at the time of coding, this is used only for selectors and matrices
function simple_csv_generator(line_data, label, element_class)
    local list_content = {
        ["selector"] = BP_LIST,
        ["matrix"] = SE_LIST
    }
    local list_container = {
        ["selector"] = SE_LIST,
        ["matrix"] = MA_LIST
    }
    local class = {
        ["selector"] = Selector,
        ["matrix"] = Matrix
    }
    local element_id
    -- element_die_set will change from (num) to 1d(num) based on num of elements
    local element_die_set = 0
    -- blueprints for selectors, selectors for matrices
    local element_parts = {}
    local element_input

    for _, part in pairs(line_data) do
        local data

        data = str_slicer(part, label, 1)

        -- if label appears, then it's the element's name
        if data[2] then
            print(part .. " is id")
            element_id = part

            goto continue
        end

        -- if not, it's a csv line containing all its parts
        element_input = part
        print(element_input)
        print("^^^^^")

        ::continue::
    end

    -- slice element_input and make it a collection of its own parts
    element_input = str_slicer(element_input, ",", 1)

    -- save all element parts in element_parts table for element creation
    for i, part in pairs(element_input) do
        -- check part validity
        if not list_content[element_class][part] then
            error_handler('Trying to add invalid bp/selector to ' .. element_class)
            goto continue
        end

        element_parts[i] = part

        element_die_set = element_die_set + 1

        ::continue::
    end

    -- create die set based on number of parts contained in element
    element_die_set = "1d" .. tostring(element_die_set)

    list_container[element_class][element_id] = class[element_class](element_id, element_die_set, element_parts)
    print(element_class)
    print(MA_LIST[element_id] and MA_LIST[element_id].id or "ciiofecaz")
end

function simple_csv_manager(file_path, error_msg, label, element_class)
    local csv = csv_reader(FILES_PATH .. file_path)

    -- check if operation went right; if not, activate error_handler
    if type(csv) == "string" then
        error_handler(error_msg)
        return false
    end

    for _, line_data_table in ipairs(csv) do
        simple_csv_generator(line_data_table, label, element_class)
    end

    return true
end

function selectors_matrices_manager()
    local error_msg
    local selectors
    local matrices

    error_msg = "The above error was triggered while trying to read selectors.csv"
    selectors = simple_csv_manager("selectors.csv", error_msg, "#", "selector")

    error_msg = "The above error was triggered while trying to read matrices.csv"
    matrices = simple_csv_manager("matrices.csv", error_msg, "&", "matrix")

    return selectors and matrices
end

function camera_setting()
    -- setting g.camera to the first spawned player
    local camera_entity = g.party_group[1]
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
function turns_manager(current_player)
    -- setting current_player coords for camera tweening
    local x_for_tweening = current_player.cell["cell"].x
    local y_for_tweening = current_player.cell["cell"].y

    -- set this next (or first) player as the g.camera entity
    g.camera["entity"] = current_player

    -- immediately nil console string, or it will linger for a moment after an
    -- action like 'equip' that closes inventory has been executed
    console_cmd(nil)

    -- tween camera between previous and current active player
    Timer.tween(TWEENING_TIME, {
        [g.camera] =  {x = x_for_tweening, y = y_for_tweening}        
    }):finish(function ()
        local player_comp = current_player.comp["player"]

        -- if it's not the NPCs turn, apply player pawn effects and enable them 
        if current_player.alive then
            print("Player turn...")
            for i, effect_tag in ipairs(current_player.effects) do
                print("Player effect tag detected")
                -- activate lasting effects for current_player
                effect_tag:activate()
                -- remove concluded effects from current_player["entity"].effects
                if effect_tag.duration <= 0 then
                    table.remove(current_player.effects, i)
                end
            end
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

        -- add to played turns
        player_comp.turns = player_comp.turns + 1

        -- check 'game cycle' completion for player's hp regeneration/hunger increase
        if player_comp.turns > 20 then
            local stat = current_player.comp["stats"].stat

            player_comp.turns = 0
            stat["hunger"] = stat["hunger"] + stat["appetite"]

            -- if player is well fed (first 400 turns), regain 1 hp
            if stat["hunger"] <= stat["stamina"] and stat["hp"] < stat["maxhp"] then
                local base_color = {0.28, 0.46, 0.73}
                local flash_color = {1, 1, 1, 1}

                stat["hp"] = stat["hp"] + 1

                -- flashing gold color. Activating a tween state isn't necessary, since it's
                -- always the same target that flashes, unlike the console messages
                g.hp_rgb = flash_color
                g.cnv_ui = ui_manager_play()

                -- flash white hp value on player's UI
                Timer.tween(TWEENING_TIME, {}):finish(function ()
                    g.hp_rgb = base_color
                    g.cnv_ui = ui_manager_play()
                end)
            end

            if stat["hunger"] >= 20 then
                if g.hunger_msg then
                    local name = current_player.name
                    local color = {1, 0.5, 0.4, 1}

                    console_event(name .. " belly is most empty!", color)
                    -- set this to false so it won't print again
                    g.hunger_msg = false
                end
            end

            -- after 750 turns withous eating, player starts to starve
            if stat["hunger"] > 50 then
                local name = current_player.name
                local color = {1, 0.5, 0.4, 1}

                -- this is the max value for hunger
                stat["hunger"] = 51

                console_event(name .. " is in dire want of sustenance!", color)

                death_check(current_player, "1d1", "starvation", "perished from starvation!")

                -- check if starvation killed player
                if not current_player.alive then
                    register_death(current_player, "starvation", "Black Swamps")
                end
            end
        end

        g.tweening["turn"] = nil
        g.game_state:refresh()        
    end)
end

function ui_manager_play()
    local color_1, color_2, color_3, color_4, color_5, color_0
    local event_1, event_2, event_3, event_4, event_5
    local cmd_x, cmd_y, cmd_alignment
    -- generating and setting a canvas of the proper size
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    love.graphics.setCanvas(new_canvas)

    -- clear to transparent black
    love.graphics.clear(0, 0, 0, 0)

    -- setting UI position based on inventory open/closed
    if not g.panel_on then
        cmd_x = HALF_TILE
        cmd_y = (g.w_height / 2) - SIZE["DEF"] - (TILE_SIZE * 1.5)
        cmd_alignment = "center"
    else
        cmd_x = SIZE["PAD"]
        cmd_y = g.w_height - (SIZE["PAD"] * 1.5)
        cmd_alignment = "left"
    end

    -- drawing UI on top of everything for the current player
    love.graphics.setFont(FONTS["console"])
    -- setting font color for name/console
    love.graphics.setColor(0.78, 0.97, 0.95, 1)
    
    -- if present, print console["string"]
    if g.console["string"] then
        love.graphics.printf(g.console["string"], cmd_x, cmd_y,
        g.w_width, cmd_alignment
    )
    end

    -- storing colors for better legibility
    color_5 = {g.console["rgb5"][1], g.console["rgb5"][2], g.console["rgb5"][3], 1}
    color_4 = {g.console["rgb4"][1], g.console["rgb4"][2], g.console["rgb4"][3], 1}
    color_3 = {g.console["rgb3"][1], g.console["rgb3"][2], g.console["rgb3"][3], 1}
    color_2 = {g.console["rgb2"][1], g.console["rgb2"][2], g.console["rgb2"][3], 1}
    color_1 = {g.console["rgb1"][1], g.console["rgb1"][2], g.console["rgb1"][3], 1}

    -- storing event strings for better legibility
    event_5 = g.console["event5"] or "Error: fed nothing to console_event() or forgot to reset its value in main.lua"
    event_4 = g.console["event4"] or "Error: fed nothing to console_event() or forgot to reset its value in main.lua"
    event_3 = g.console["event3"] or "Error: fed nothing to console_event() or forgot to reset its value in main.lua"
    event_2 = g.console["event2"] or "Error: fed nothing to console_event() or forgot to reset its value in main.lua"
    event_1 = g.console["event1"] or "Error: fed nothing to console_event() or forgot to reset its value in main.lua"

    -- print newest console event with inv open and no console cmd or inv closed
    if g.panel_on and not g.console["string"] or not g.panel_on then
        love.graphics.setColor(color_1)
        love.graphics.print(event_1, SIZE["PAD"], g.w_height - (SIZE["PAD"] * 1.5))
    end

    -- if inventory is closed, show all the other events that would otherwise bloat screen
    if not g.panel_on then
        local pc_stats = g.camera["entity"].comp["stats"].stat
        local pc_gold = g.camera["entity"].comp["inventory"]

        -- manage situations where the pc has no inventory object equipped
        pc_gold = pc_gold and pc_gold.capacity > 0 and pc_gold.gold
        pc_gold = pc_gold and "Gold " .. pc_gold or false

        -- print console events
        love.graphics.setColor(color_5)
        love.graphics.print(event_5, SIZE["PAD"], g.w_height - (SIZE["PAD"] * 5.5))

        love.graphics.setColor(color_4)
        love.graphics.print(event_4, SIZE["PAD"], g.w_height - (SIZE["PAD"] * 4.5))

        love.graphics.setColor(color_3)
        love.graphics.print(event_3, SIZE["PAD"], g.w_height - (SIZE["PAD"] * 3.5))

        love.graphics.setColor(color_2)
        love.graphics.print(event_2, SIZE["PAD"], g.w_height - (SIZE["PAD"] * 2.5))

        -- set proper font
        love.graphics.setFont(FONTS["tag"])

        -- set proper color
        love.graphics.setColor(0.49, 0.82, 0.90, 1)
        
        -- print player stats
        love.graphics.print(g.camera["entity"].name, SIZE["PAD"], SIZE["PAD"])

        love.graphics.setFont(FONTS["ui"])

        -- setting font color for player data
        love.graphics.setColor(g.hp_rgb)
        love.graphics.print("Life "..pc_stats["hp"], SIZE["PAD"], SIZE["PAD"] * 2.5)

        -- if pc has no inventory, skip printing gold amount
        if not pc_gold then
            goto continue
        end

        love.graphics.setColor(g.gold_rgb)
        love.graphics.print(pc_gold, SIZE["PAD"], SIZE["PAD"] * 3.5)

        ::continue::
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
    logo_y = (g.w_height / 5) - SIZE["MAX"]

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
    text_y = g.w_height / 5 + (SIZE["PAD"] * 4)
    input_x = 0
    input_y = g.w_height / 5 + (SIZE["PAD"] * 4)

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
    title_y = g.w_height / 4 - SIZE["PAD"]

    text_x = 0
    text_y = g.w_height / 4 + SIZE["PAD"]

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
        list_y = g.w_height / 3.5 + (SIZE["PAD"] * (i * 3))
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
    play_sound(SOUNDS["type_backspace"])

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
        play_sound(SOUNDS["type_input"])
    elseif #input_string >= max_length then
        play_sound(SOUNDS["type_nil"])
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

    -- pause for few seconds & play sting to emphasize player's death
    if entity.comp["player"] then
        g.tweening["cutscene"] = true

        play_sound(SOUNDS["sfx_death"])

        Timer.tween(2.5, {}):finish(function ()
            -- empty any input given while tweening for character death
            g.keys_pressed = {}

            g.tweening["cutscene"] = nil
        end)
    end
end

-- this func registers game events and chronologially displays them
function console_event(event, font_color)
    g.tweening["event"] = true
    g.new_event = false
    local base_color = {[1] = 0.28, [2] = 0.46, [3] = 0.73}
    local events_table = {}

    -- extracting values from g.console
    -- PLEASE NOTE: in Lua, tables are passed as *ref*, *not* as value!
    for i, msg in pairs(g.console) do
        events_table[i] = msg
    end

    -- assigning new values to global colors
    g.console["rgb5"] = events_table["rgb4"]
    g.console["rgb4"] = events_table["rgb3"]
    g.console["rgb3"] = events_table["rgb2"]
    g.console["rgb2"] = events_table["rgb1"]
    g.console["rgb1"] = font_color or base_color

    -- assigning new values to global strings
    g.console["event5"] = events_table["event4"]
    g.console["event4"] = events_table["event3"]
    g.console["event3"] = events_table["event2"]
    g.console["event2"] = events_table["event1"]
    g.console["event1"] = event:gsub("^%l", string.upper)
    g.cnv_ui = ui_manager_play()
    g.new_event = true
end

function console_cmd(cmd)
    g.console["string"] = cmd
    g.cnv_ui = ui_manager_play()
end

-- this function applies damage, gives consonle feedback and sets Entities as dead
function death_check(target, damage_dice, type, message, sound)
    -- this is needed to output messages on screen in yellow or red
    local event_rgb = {
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
        return true
    end

    stats["hp"] = stats["hp"] - damage_score
    print(target.name .. " receives damage: " .. damage_score)

    -- target is dead
    if stats["hp"] <= 0 then
        -- Entity will be removed from render_group and cell during refresh()
        target.alive = false

        -- canont go below 0
        stats["hp"] = 0

        -- play dedicated death message and sound depending on damage
        if sound then
            play_sound(SOUNDS[sound])
        end

        if message then
            console_event(target.name .. " " .. message, event_rgb[target_family])
        end
    end

    -- returning success and damage inflicted, useful to influence EffectTags:
    -- i.e. the harder you slash someone, the longer he will bleed
    return true, damage_score
end

-- simple function to register decess details for game over screen
function register_death(victim_entity, killer_name, place)
    local victim_inv = victim_entity.comp["inventory"]
    local deceased = {
        ["player"] = victim_entity.name,
        ["killer"] = killer_name,
        ["loot"] = victim_inv and victim_inv.gold or "0",
        ["place"] = place
    }
    table.insert(g.cemetery, deceased)
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

function panel_update(player)
    local new_canvas  = love.graphics.newCanvas(g.w_width, g.w_height)
    local size = SIZE_MULT * 2
    local t_size = TILE_SIZE * 2
    local inv_str = "abcdefghijklmnopqrstuvwxyz"
    local slots_str = "01234567890"
    -- referencing eventual player's 'inventory' component
    local inventory = player.comp["inventory"]
    local slots = player.comp["slots"]
    local available_items = {}
    local equipped = false
    local title_color = {0.49, 0.82, 0.90, 1}
    local text_color = {
        [true] = {0.93, 0.18, 0.27, 1},
        [false] = {0.28, 0.46, 0.73, 1}    
    }

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
    love.graphics.printf(player.name .. "'s bag", 0, SIZE["DEF"], g.w_width, "center")

    -- warn developer when player is missing inventory component
    if not inventory then
        print("INFO: In 'panel_update()', found player with missing inventory")
    end

    -- setting font for inventory's items
    love.graphics.setFont(FONTS["ui"])

    if inventory then
        -- at this point, reference 'inventory' comp table of items
        inventory = inventory.items

        -- print all item in player inventory and couple them with a letter
        for i = 1, string.len(inv_str) do
            -- reference item's 'equipable' comp for each item in inventory
            local equipable_ref
            local stack_str = ""
            local slot_str = ""
            local item_str
            local tag_str
            local text_y

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
            text_y = (SIZE["DEF"] + SIZE["DEF"] / 8) * (i + 2)

            -- print string canvas
            love.graphics.printf(tag_str .. item_str .. stack_str .. slot_str,
            0, text_y, g.w_width, "center"
            )
            available_items[string.sub(inv_str, i, i)] = inventory[i]
        end
    end

    if slots then
        -- at this point, reference 'slots' comp table of items
        slots = slots.slots
        local slot_key = {}
        
        -- store non-empty slot_comp.slots string keys in order
        for key, value in pairs(slots) do
            if value ~= "empty" then
                table.insert(slot_key, key)
            end
        end

        for i = 1, string.len(slots_str) do
            print("Slotted items:")
            local slot_ref
            local stack_ref
            local item_str
            local stack_str = ""
            local slot_ref_str = ""
            local tag_str
            local text_y

            -- if no more items are available, break loop
            if not slots[slot_key[i]] then
                break
            end

            slot_ref = slots[slot_key[i]]
            -- saving item's numerical tag
            slot_ref["tag"] = string.sub(slots_str, i, i)

            stack_ref = slot_ref["item"].comp["stack"]

            if stack_ref then
                local stack_qty = slot_ref["item"].comp["stats"].stat["hp"]
                stack_str = " [" .. stack_qty .. "]"
            end

            -- chosen text_color setting
            love.graphics.setColor(text_color[true])

            -- print all items on canvas
            item_str = string_selector(slot_ref["item"])

            slot_ref_str = slot_ref["item"].comp["equipable"].slot_reference .. ": "

            -- establish and set tag_str and text_y
            tag_str = string.sub(slots_str, i, i) .. "."

            text_y = (SIZE["DEF"] + SIZE["DEF"] / 8) * (i + 2)

            -- print string canvas
            love.graphics.printf(tag_str .. slot_ref_str .. item_str .. stack_str,
            SIZE["PAD"], text_y, g.w_width, "left"
            )

            available_items[string.sub(inv_str, i, i)] = slot_ref["item"]

            print(slot_ref["tag"])
            print(slot_ref["item"])
        end
    end

    -- storing available_items to be used with action_modes
    g.active_panel = available_items
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
    
    
    if not g.panel_on then
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

        -- RETURNING: valid input, target pawn, target Entity, target cell
        return true, pawn_ref, entity_ref, target_cell
    end

    -- RETURNING: valid input, target pawn, target Entity from inventory
    return true, false, g.active_panel[key]
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

-- simple sound player function
function play_sound(sfx_input)
    love.audio.stop(sfx_input)
    love.audio.play(sfx_input)
end

function print_errors()
    love.graphics.setFont(FONTS["error"])
    love.graphics.setColor(1, 0.56, 0.68, 1)

    for i, error_msg in ipairs(g.error_messages) do
        love.graphics.printf(error_msg, 0, (i - 1) * SIZE["ERR"], g.w_width, "left")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Action modes from action_modes.lua related and exclusive functions
]]--

--[[
    This simple func links pickup, unlock & unseal to optional same-named powers.
    Relative to action modes, but only called from util.lua.
    NOTE: trigger power would instead target the activator, not its owner, so it
    is better reserved for adverse effects on activator.
]]--
function action_to_power(owner, target, key)
    if not owner.powers[key] then
        print("No power associated with action performed on entity")

        return false
    end

    -- activate target power
    owner.powers[key]:activate(owner, target, nil)
end

function observe_func(player_comp, player_entity, key)
    local valid_key
    local pawn, entity
    local pawn_str, entity_str

    valid_key, pawn, entity = target_selector(player_comp, player_entity, key)

    if not valid_key then return false end

    if pawn then
        -- defaut action is to set name for string
        pawn_str = string_selector(pawn)
    end

    if entity then
        -- defaut action is to set name for string
        entity_str = string_selector(entity)
    end


    if not pawn_str and not entity_str then
        console_event("Thou dost observe nothing")
    end

    if not pawn_str and entity_str then
        console_event("Thou dost observe ain " .. entity_str)
    end

    if pawn_str and not entity_str then
        console_event("Thou dost observe " .. pawn_str)
    end

    if pawn_str and entity_str then
        console_event(
            "Thou dost observe " .. pawn_str .. ", standing on somethende"
        )
    end

    -- observing is a 'free' action, so it resets action_state to 'nil'
    player_comp.action_state = nil
    console_cmd(nil)

    return false
end

function bestow_select_func(player_comp, player_entity, key)
    local player_slots = player_entity.comp["slots"]
    local item

    if not player_slots then
        print("Entity without slots comp trying to bestow")
        return false
    end

    item = g.active_panel[key]

    -- check if there's an item coupled with this letter
    if not item then
        return false
    end

    -- if this variable == false, then the item is currently equipped
    if item.comp["equipable"] and item.comp["equipable"].slot_reference then
        console_event("Thee need to unequip this first")
        return false
    end


    -- at this point, a valid item was selected
    g.panel_on = false
    player_comp.action_state = "/bestow"
    -- store selected item in player_comp.string
    player_comp.string = key
    console_cmd("Where do you bestow it?")

    return false
end

function quit_func(player_comp, player_entity, key)
    if key == "n" then
        player_comp.string = false
        console_cmd(nil)
        player_comp.action_state = nil

        return false
    end

    if key == "y" then
        love.event.quit()

        return false
    end

    player_comp.string = false
    console_event("Inscribe Y(ea) or N(ay)")

    return false
end

-- bestow can be applied to any Entity in inventory, if not equipped
function bestow_place_func(player_comp, player_entity, key)
    local valid_key
    local pawn, entity
    local target_cell
    local item
    local item_key = player_comp.string
    local item_str
    local inventory = player_entity.comp["inventory"]

    valid_key, pawn, entity, target_cell = target_selector(player_comp, player_entity, key)

    if not valid_key then
        print("Invalid key")
        return false
    end

    if not target_cell or TILES_PHYSICS[target_cell.index] == "solid" then
        console_event("You cannot bestow anything here")
        return false
    end

    if pawn then
        local pawn_str = string_selector(pawn)

        console_event(pawn_str .. " is hindering your action")
        return false
    end

    if entity then
        local entity_str = string_selector(entity)

        console_event(entity_str .. " is already occupying this space")
        return false
    end

    -- at this point, everything is in check. Store item
    item = g.active_panel[item_key]

    -- set proper item string
    item_str = string_selector(item)

    -- then remove item from inventory using item_key position in alphabet
    inventory:remove(item_key)
    panel_update(player_entity)
    player_comp.string = false

    -- then position item in target_cell and add to entities_group
    item.cell["cell"] = target_cell
    item.cell["grid_row"] = target_cell.y
    item.cell["grid_col"] = target_cell.x
    target_cell.entity = item
    table.insert(g.entities_group, item)

    -- insert item in visible or invisible group
    if not item.comp["invisible"] then
        -- adding entity in proper drawing order (back/front) based on their
        -- belonging to Players/NPCs or simple Entities
        table.insert(g.render_group, 1, item)
    else
        table.insert(g.hidden_group, item)
    end

    -- free an inventory space
    inventory.spaces = inventory.spaces + 1

    -- play a 'touching the ground' sound (same as stepping)
    play_sound(SOUNDS[TILES_PHYSICS[target_cell.index]])

    console_event("Thee bestow " .. item_str)

    return true
end

function equip_func(player_comp, player_entity, key)
    local player_slots = player_entity.comp["slots"]
    local target_item
    local equipable_comp

    if not player_slots then
        error_handler("Trying to equip without slots component")
        return false
    end

    -- player slots
    player_slots = player_slots.slots

    _, _, target_item = target_selector(player_comp, player_entity, key)

    -- check if there's a target item
    if not target_item then
        return false
    end

    equipable_comp = target_item.comp["equipable"]

    -- check if the selected item is equipable
    if not equipable_comp then
        console_event("Thee can't equip this")
        return false
    end

    if equipable_comp.slot_reference then
        console_event("This is already beset upon thee")

        return false
    end

    -- check if proper slot for the item is available in 'slots' component
    for _, slot in ipairs(equipable_comp.suitable_slots) do
        if player_slots[slot] == "empty" then
            local item_str = string_selector(target_item)

            -- save occupied slot in equipped object for easier referencing
            equipable_comp.slot_reference = slot
            -- store item inside slots component
            player_slots[slot] = {
                ["tag"] = key,
                ["item"] = target_item
            }

            play_sound(SOUNDS["sfx_equip"])
            -- activate equip() func in 'equipable' component
            -- this can trigger dedicated effects thanks to 'equip' tagged power
            equipable_comp:equip(target_item, player_entity)

            console_event("Thou dost equip thyself with " .. item_str)

            -- if target_item is on map, pickup
            if not g.panel_on then
                return pickup_func(target_item, player_entity)
            end

            return true
        end
    end

    -- if no compatible/free slot is found on Entity, return false
    console_event("Thou hast no vacant slot to don this")
    return false
end

function unequip_func(player_comp, player_entity, key)
    local player_slots

    if not player_entity.comp["slots"] then
        print("WARNING: Entity without slots is trying to unequip")
        return false
    end
    -- if an item player_entity was equipped and still is,
    -- we can assume its data is predictable
    player_slots = player_entity.comp["slots"].slots

    if g.active_panel[key] then
        local item
        local success

        item = g.active_panel[key]

        if not item.comp["equipable"] then
            print("Trying to unequip an unequippable object!")
            return false
        end

        -- if this variable == false, then the item wasn't equipped
        if not item.comp["equipable"].slot_reference then
            print("Trying to unequip a non-equipped, equippable object")
            return false
        end

        success = item.comp["equipable"]:unequip(item, player_entity)

        -- if item isn't cursed, empty player_slots component reference
        -- and also equipable component slot_reference
        if success then
            local item_str = string_selector(g.active_panel[key])

            play_sound(SOUNDS["sfx_unequip"])
            player_slots[item.comp["equipable"].slot_reference] = "empty"

            item.comp["equipable"].slot_reference = false

            console_event("Thou dost relinquish thy " .. item_str)
        else
            play_sound(SOUNDS["sfx_cursed"])
        end
    else
        print("No item at this key address")
        return false
    end

    return true
end

function unlock_func(player_comp, player_entity, key)
    local valid_key
    local pawn, entity

    valid_key, pawn, entity = target_selector(player_comp, player_entity, key)
    
    if not valid_key then return false end

    -- if no target is found, return a 'nothing found' message
    if not entity then
        console_event("There be naught that can be unlocked h're")
        return true
    end

    -- if no unlockable target is found then warn player
    if entity.comp["locked"] then
        entity.comp["locked"]:activate(entity, player_entity)
    else
        console_event("Thee can't unlock this")
    end

    return true
end

function use_func(player_comp, player_entity, key)
    local valid_key
    local pawn, entity
    
    valid_key, pawn, entity = target_selector(player_comp, player_entity, key)

    if not valid_key then return false end

    if not g.panel_on then
        local input = player_comp.movement_inputs[key]
        -- player shouldn't be able to activate entities he's standing on,
        -- since they could change physics and block him improperly
        
        if input[1] == 0 and input[2] == 0 then
            console_event("Thou need to step back to accomplish this!")
            return false
        end
    end

    if pawn then
        local pawn_str = string_selector(pawn)

        console_event(pawn_str .. " is hindering your action")
        return false
    end

    -- if no target is found, return a 'nothing found' message
    if not entity then
        console_event("There is naught usaeble h're")
        return true
    end

    -- block any interaction with 'locked' or 'sealed' Entities
    if not entity_available(entity) then return true end

    -- if the target has a trigger 'trig_on_coll' comp, trigger immediately
    if entity.comp["trigger"] and entity.comp["trigger"].trig_on_coll then
        entity.comp["trigger"]:activate(entity, player_entity, nil)
    end

    -- if usable target is found activate, else warn player
    if entity.comp["usable"] then
        local console_string
        local entity_str = string_selector(entity)

        -- if player_comp.string is empty, the command is a simple 'use'.
        -- Set it to false to let Usable comp & console_event() know this.
        if player_comp.string == "" then player_comp.string = false end
        console_string = player_comp.string or "usae "

        console_event("Thee " .. console_string .. " " .. entity_str)
        entity.comp["usable"]:activate(entity, player_entity, player_comp.string)
    else
        console_event("Nothing doth happen")
    end

    return true
end

function pickup_check_func(player_comp, player_entity, key)
    local valid_key
    local pawn, entity
    local pc_inventory = player_entity.comp["inventory"]

    -- if capacity <= 0, it is read as false
    pc_inventory = pc_inventory and pc_inventory.capacity > 0

    if not pc_inventory then
        print("WARNING: Entity without inventory/inventory capacity is trying to pickup")
        console_event("Thou hast no bag to stow this item")
        return false
    end            

    valid_key, pawn, entity = target_selector(player_comp, player_entity, key)
    
    if not valid_key then return false end

    -- if no target is found, return a 'nothing found' message
    if not entity then
        console_event("There's naught to pick up h're")
        return true
    end

    -- block any interaction with 'locked' or 'sealed' Entities
    if not entity_available(entity) then return true end

    return pickup_func(entity, player_entity) 
end

function pickup_func(target_entity, player_entity)
    -- if the target has a trigger comp, trigger immediately
    if target_entity.comp["trigger"] then
        target_entity.comp["trigger"]:activate(target_entity, player_entity)

        -- activating optional pickup-related power
        action_to_power(target_entity, player_entity, "on_pickup")
    end

    -- if target is has destroyontrigger, don't bother picking up
    if not target_entity.alive then
        return true
    end

    -- if target has no pickup comp then warn player
    if target_entity.comp["pickup"] then
        return player_entity.comp["inventory"]:add(target_entity)
    else
        console_event("Thee art unable to pick hider up")
        return false
    end
end

function talk_func(player_comp, player_entity, key)
    local valid_key
    local entity

    valid_key, _, entity = target_selector(player_comp, player_entity, key)
    
    if not valid_key then return false end

    -- if no target is found, return a 'nothing happens' message
    if not entity then
        console_event("There is naught within")
        return false
    end

    -- if the target has a trigger comp, trigger immediately
    if entity.comp["sealed"] then
        entity.comp["sealed"]:activate(entity, player_entity, player_comp)

        -- activating optional unseal-related power
        action_to_power(entity, player_entity, "on_unseal")

        return true
    end

    console_event("Nothing doth seem to happen")

    return true
end

function loose_func(player_comp, player_entity, key)
    -- select behavior between launching item or shooting ranged weapon,
    -- depending on inventory open/close
    if not g.panel_on then
        local weapon_ref = player_entity.comp["slots"]
        local quiver_ref = player_entity.comp["slots"]

        -- trying to store player's 'weapon' slot
        weapon_ref = weapon_ref and weapon_ref.slots["weapon"] or false
        -- trying to store player's 'quiver' slot
        quiver_ref = quiver_ref and quiver_ref.slots["quiver"] or false
        
        -- checking if player is missing 'weapon' slot or 'slots' component
        if not weapon_ref or not quiver_ref then
            error_handler("Player has no slots component or weapon/quiver slot")
            
            return false
        end

        -- checking if player has an equipped weapon, and it is a ranged one            
        if weapon_ref == "empty" or not weapon_ref["item"].comp["shooter"] then
            console_event("Thou hast no missile armament at thy side")
            
            return false
        end

        if quiver_ref == "empty" then
            console_event("Thine quiver is void of projectiles")

            return false
        end

        -- search expected 'quiver' slot for proper ammunition
        for _, ammo_type in ipairs(weapon_ref["item"].comp["shooter"].munitions) do
            if not BP_LIST[ammo_type] then
                error_handler(
                    "Assigned to shooter entity ammo_type with invalid id " .. ammo_type
                )
    
                return false
            end

            if quiver_ref["item"].id == ammo_type then
                -- check if ammo are stackable or not...
                local stack_ammo = quiver_ref["item"].comp["stack"] or false
                -- ...if it is stackable, reference its stats comp...
                stack_ammo = stack_ammo and quiver_ref["item"].comp["stats"]
                -- ...and then its stat table, or leave it false
                stack_ammo = stack_ammo and stack_ammo.stat

                -- kill non-stack ammo, remove from slots and inventory
                if not stack_ammo then
                    local slots_ref = player_entity.comp["slots"].slots
                    local tag = slots_ref["quiver"]["tag"]

                    --quiver_ref["item"].alive = false
                    player_entity.comp["inventory"]:remove(tag)
                    slots_ref["quiver"] = "empty"
                    
                    console_event(
                        "Thou hast emptied thy quiver",
                        {[1] = 1, [2] = 0.97, [3] = 0.44}
                    )
                end

                -- reduce hp by number of ammo used by shooter Entity
                if stack_ammo and stack_ammo["hp"] then
                    local hp = stack_ammo["hp"]

                    hp = hp - weapon_ref["item"].comp["shooter"].shots

                    stack_ammo["hp"] = hp
                end

                -- kill consumed stack ammo, remove from inventory and slots
                if stack_ammo and stack_ammo["hp"] <= 0 then
                    local slots_ref = player_entity.comp["slots"].slots
                    local tag = slots_ref["quiver"]["tag"]

                    --quiver_ref["item"].alive = false
                    player_entity.comp["inventory"]:remove(tag)
                    slots_ref["quiver"] = "empty"
                    
                    console_event(
                        "Thou hast emptied thy quiver",
                        {[1] = 1, [2] = 0.97, [3] = 0.44}
                    )
                end

                print("Succefully shot your weapon. Implement aiming code")

                return true                    
            end
        end

        -- ammunitions in quiver are not compatible with equipped ranged weapon
        console_event("Thy weapon is ill-suited for these projectiles")

        return false
    end

    console_event("Select equipped/unequipped object from inventory. Implement aiming code")

    return false
end

--[[
    Components from components.lua related functions.
    It is imperative to separate components code into common functions as much as
    possible, since components are store and iterated many times for each Entity.
]]--

function player_manage_input(entity, key, comp)
    if key == "escape" then 
        comp.action_state = nil
        comp.string = ""
        console_cmd(nil)

        return false
    end

    if not comp.action_state then
        local mov_input = comp.movement_inputs[key]

        -- checking if player is trying to use a hotkey
        if not mov_input and not comp.action_state then
            -- hotkeys allow access only to a few selected states/interactions.
            -- NOTE: 'comp' = this comp, and 'entity' = player entity
            return player_cmd(comp, key)
        end

        -- check if player has inventory open, to avoid undesired movement input
        if g.panel_on then
            return false
        end

        -- check if player is skipping turn (possible even without a mov comp)
        if mov_input[1] == 0 and mov_input[2] == 0 then
            play_sound(SOUNDS["wait"])
            return true
        end

        -- 'Movable' component can be modified/added/removed during gameplay,
        -- so it is imperative to check for it each time
        if not entity.comp["movable"] then
            print("INFO: The entity does not contain a movement component")
            return false
        end

        -- if no guard statements were activated, player is legally trying to move
        return entity.comp["movable"]:move_entity(entity, mov_input)
    end

    -- managing comp.action_state mode of input  
    if IO_DTABLE[comp.action_state] then
        return IO_DTABLE[comp.action_state](comp, entity, key)
    end

    -- if no valid input was received for the mode, return false
    print("Called IO_DTABLE[comp.action_state] where comp.action_state is an invalid key!")
    return false
end

function movable_move_entity(owner, dir, comp)
    -- destination, the target cell
    local destination
    local current_cell = g.grid[owner.cell["grid_row"]][owner.cell["grid_col"]]
    -- target entity, the target cell eventual entity
    local entity
    -- necessary to check if adjacent cells are transversable when moving diagonally
    local adj_tiles = {}
    local row_mov = owner.cell["grid_row"] + dir[1]
    local col_mov = owner.cell["grid_col"] + dir[2]
    -- score to succeed, throw needs to be less or equal
    local succ_score = owner.comp["stats"].stat["dexterity"] or 7 -- 7 by default
    local succ_atk = false -- by default, not needed and set to false
    local can_ruck = false
    -- this stores all the legal movement-phys MOV_TO_PHYS (see VALID_PHYSICS)
    local PHYS_TO_MOV = {
        ["difficult"] = "ruck",
        ["liquid"] = "swim",
        ["climbable"] = "climb",
        ["void"] = "fly",
        ["solid"] = "phase",
        ["ground"] ="walk"
    }

    -- store ability to ruck for later check
    if comp.mov_type["ruck"] then can_ruck = true end

    -- making sure that the comp owner isn't trying to move out of g.grid
    if col_mov > g.grid_x or col_mov <= 0 or row_mov > g.grid_y or row_mov <= 0 then
        destination = nil
        print("Trying to move out of g.grid boundaries")
        return false
    end

    -- special 'wiggle' movement can reach any adjacent tiles, skip all code
    if comp.mov_type["wiggle"] then
        can_traverse = true

        goto continue
    end

    -- if cell exists and is part of the g.grid, store it as destination
    destination = g.grid[row_mov][col_mov]
    -- store its eventual Entity for later reference
    entity = destination.entity

    -- checking for additional tiles to check, since diagonal mov requires entity
    -- to be able to traverse all of them!
    if dir[1] ~= 0 and dir[2] ~= 0 then
        -- since movement is diagonal, add to adj_tiles the adjacent tiles
        local adj_tile
        adj_tile = g.grid[owner.cell["grid_row"]][owner.cell["grid_col"] + dir[2]]
        table.insert(adj_tiles, TILES_PHYSICS[adj_tile.index])
        adj_tile = g.grid[owner.cell["grid_row"] + dir[1]][owner.cell["grid_col"]]
        table.insert(adj_tiles, TILES_PHYSICS[adj_tile.index])
    end

    -- now checking if tile feature is compatible with movement abilities
    table.insert(adj_tiles, TILES_PHYSICS[destination.index])

    -- if even one cell isn't compatible with Entity mov, Entity cannot proceed
    for _, phys in ipairs(adj_tiles) do
        local can_traverse = false
        local required_mov = PHYS_TO_MOV[phys]

        if comp.mov_type[required_mov] then
            can_traverse = true
        end

        -- Entities that can walk, can also enter 'difficult' terrain
        if comp.mov_type["walk"] and required_mov == "ruck" then
            can_traverse = true
        end
         
        if not can_traverse then
            print("Incompatible tile terrain in path for entity")
            return false
        end 
    end

    ::continue::

    -- if Entity is in 'difficult' terrain, throw dice to confirm movement
    -- if and only if they do not have 'ruck' movement ability
    if TILES_PHYSICS[current_cell.index] == "difficult" and not can_ruck then
        local succesfully_moves = dice_roll("1d3", 2)

        -- if still cannot traverse, Entity got stuck in difficult terrain
        if not succesfully_moves then
            play_sound(SOUNDS[TILES_PHYSICS[current_cell.index]])

            return true
        end
    end

    -- check if owner movement is impeded by an obstacle Entity
    if entity and entity.comp["obstacle"] then
        print("Cell is blocked by obstacle: " .. entity.id)
        return false
    end

    -- checking for NPC/Player Entities. These always have precedence of interaction
    if destination.pawn then
        local pilot = owner.pilot
        local pawn = destination.pawn
        local pawn_slots = owner.comp["slots"] and owner.comp["slots"].slots or false

        -- trying to establish attack mode: armed or unarmed. Checking weapon slot
        local attack_mode = pawn_slots and pawn_slots["weapon"] or false

        -- checking if slot is available but empty
        if attack_mode and attack_mode == "empty" then
            attack_mode = false
        end

        -- if weapon is available, select its 'hit' power (always expected)
        attack_mode =  attack_mode and attack_mode["item"].powers["on_hit"] or false

        -- moving against an Entity = interaction. If part of different groups
        -- or of special 'self' group, the interaction results in an attack
        if pilot.group ~= "self" and pilot.group == pawn.pilot.group then
            print("Entity interacts with another Entity of the same group")
            return true
        end

        -- Player/Civilised interaction is always peaceful
        if pilot.group == "players" and pawn.pilot.nature == "civilized" then
            print("Player dialogues with civilized creature")
            -- this will actually lead to a dialogue func() that will return true/false
            return true
        end
        if pilot.group == "civilised" and pawn.pilot.nature == "player" then
            print("Player dialogues with civilized creature")
            -- this will actually lead to a dialogue func() that will return true/false
            return true
        end

        -- selecting between weapon, if available, or unarmed attack
        attack_mode = attack_mode or owner.powers["on_unarmed"]

        -- an enemy was found, but owner has no weapon equipped or 'unarmed' power
        if not attack_mode then
            print('Trying to attack other entity without weapon, but no "on_unarmed" power was assigned')
            print('If weapon is equipped, it lacks essential "on_hit" power')

            return false
        end

        -- an enemy was found. Check if it has stats and can take damage
        if not pawn.comp["stats"] then
            print("Target entity has no Stats component")
            return false
        end

        local target_stats = pawn.comp["stats"].stat
        if not target_stats["hp"] then
            print("Target entity has no HP and cannot die")
            return false
        end

        -- if target is invisible, you need to roll a lower number
        if pawn.comp["invisible"] then
            print("Trying to hit invisible entity, success when: roll <= 4")
            succ_score = 4
        end

        -- dices get rolled to identify successful hit and eventual damage
        succ_atk = dice_roll("1d12", succ_score)
        
        if succ_atk then
            -- NOTE: both "unarmed" and "hit" are expected powers previously checked
            attack_mode:activate(owner, pawn, nil)

            -- if target has reactive 'on_hurt' power, activate immediately
            if pawn.powers["on_hurt"] then
                pawn.powers["on_hurt"]:activate(pawn, owner, nil)
            end
        else
            love.audio.play(SOUNDS["sfx_miss"])
        end

        -- if a player just died, save all deceased's relevant info in cemetery
        -- variable for recap in Game Over screen
        if pawn.alive == false and pawn.comp["player"] then
            register_death(pawn, owner.name, "Black Swamps")
        end

        return true
    end

    -- if no pawns are found in target cell, you're good to go
    owner.cell["cell"].pawn = nil -- freeing old cell
    owner.cell["grid_row"] = owner.cell["grid_row"] + dir[1]
    owner.cell["grid_col"] = owner.cell["grid_col"] + dir[2]
    owner.cell["cell"] = destination -- storing new cell
    owner.cell["cell"].pawn = owner -- occupying new cell
    
    -- playing sound based on tile type, check if valid to avoid crashes
    if SOUNDS[TILES_PHYSICS[destination.index]] then
        play_sound(SOUNDS[TILES_PHYSICS[destination.index]])
    else
        print("WARNING: destination has no related sound")
    end

    -- lastly, check if there's an item Entity in the new cell
    if not entity then
        return true
    end
    -- see if the Entity is an exit
    if entity.comp["exit"] then
        entity.comp["exit"]:activate(entity, owner)
        return true
    end

    -- see if Entity is has trigger component
    if entity.comp["trigger"] and entity.comp["trigger"].trig_on_coll then
        -- trigger may work or not, but Entity still moved, so return true
        entity.comp["trigger"]:activate(entity, owner)
        return true
    end

    -- if a non-reactive, non-NPC, non-Player, non-Obstacle Entity is in target cell
    -- simply ignore it anad return true for successful movement 
    return true
end

function npc_activate(owner, comp)
    -- if NPC cannot move, skip turn
    if not owner.comp["movable"] then
        return false
    end

    -- choose path of action depending on nature
    return ai_behavior(owner, comp)
end

function trigger_activate(owner, target, activator, comp)  
    -- check if owner Entity has a dedicated power flagged as 'trigger'
    if owner.powers["on_trigger"] then
        owner.powers["on_trigger"]:activate(owner, target, nil)
    else
        print("Blank trigger: a trigger Entity has no 'on_trigger' power to activate")
    end

    -- check if trigger is set to print event
    if comp.event then
        local color = {[1] = 1, [2] = 0.97, [3] = 0.44}
        local owner_str = string_selector(owner)

        console_event(owner_str .. " " .. comp.event, color)
    end
    
    -- if owner is to 'destroyontrigger', destroy it
    if comp.destroyontrigger then
        local owner_stat

        if not owner.comp["stack"] then
            owner.alive = false

            return true
        end

        owner_stat = owner.comp["stats"].stat
        owner_stat["hp"] = owner_stat["hp"] - 1
        
        if owner_stat["hp"] <= 0 then
            owner.alive = false
        end

        return true
    end

    -- if component is set to fire_once, destroy component
    if comp.fire_once then
        owner.comp["trigger"] = nil
    end
end

function usable_activate(owner, activator, input_key, comp)
    local key = input_key or "use"
    local target

    -- search for linked comp and store eventual linked Entity coords
    if owner.comp["linked"] and comp.uses[key] == "to_linked" then
        print("Linked component + dedicated function found")
        -- 'linked' comp activation returns name-store coordinates
        local row, col = owner.comp["linked"]:activate(owner)
        row = tonumber(row)
        col = tonumber(col)

        -- check immediately for NPC/Player
        target = g.grid[row][col] and g.grid[row][col].pawn or false
        -- if absent, check for Entity
        if not target then target = g.grid[row][col].entity or false end

        -- if linked but Entity is missing in cell, nothing happened and return true
        if not target then
            console_event("The target is absent")

            return true
        end

        if not owner.powers["to_linked"] then
            print('WARNING: Entity with "linked" component has no dedicated "to_linked" power')

            return true
        end

        -- on_linked power needs to discriminate between target (linked Entity) and
        -- activator (Entity interacting with self)
        owner.powers["to_linked"]:activate(owner, target, activator)

        return true
    end

    -- trigger always hits activating Entity, even if linked comp is present
    if owner.comp["trigger"] then
        owner.comp["trigger"]:activate(owner, activator, nil)
    end

    -- if Entity is destroyontrigger, don't bother with rest of code
    if not owner.alive then
        return false
    end

    if not comp.uses[key] then
        console_event("Nothing doth happen")
    end

    if not owner.powers[comp.uses[key]] then
        print("NOTE: usable comp called, but no corresponding power")

        return false
    end

    -- activate owner power, passing activator as target and nil as activator
    owner.powers[comp.uses[key]]:activate(owner, activator, nil)
    
    -- if destroyonuse, destroy used object (useful for consumables)
    if comp.destroyonuse then
        local owner_stat

        if not owner.comp["stack"] then
            owner.alive = false

            return true
        end

        owner_stat = owner.comp["stats"].stat
        owner_stat["hp"] = owner_stat["hp"] - 1

        if owner_stat["hp"] <= 0 then
            owner.alive = false
        end
    end

    return true
end

function exit_activate(owner, entity, comp)
    console_event(comp.event_string)
    if entity.comp["player"] then
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

function inventory_add(item, comp)
    local item_ref
    local stack
    local success = false
    local print_event

    item_ref = string_selector(item)

    -- if not stackable, simply add to inventory
    if not item.comp["stack"] then
        goto addtoinv
    end

    -- return error if stackable Entity is missins essential 'hp' stat
    if not item.comp["stats"] and not item.comp["stats"].stat["hp"] then
        error_handler(
            "Trying to stack Stackable Entity without HP stat, which defines stack amount.",
            "Pickup action canceled!"
        )
        return false
    end

    -- at this point, pickup is valid and ready to be added to inventory
    -- if everything is in check, stack Entity in inventory, even if equipped
    for _, obj in ipairs(comp.items) do
        if obj.id == item.id then
            local supplement =  item.comp["stats"].stat["hp"]
            local stack_stat

            stack = obj
            stack_stat = stack.comp["stats"]

            -- search for a stack not yet full
            if stack_stat.stat["hp"] == stack.comp["stack"].max then
                stack = false
            end

            -- if target non-full stack is found, skip rest of code
            if stack then
                stack_stat.stat["hp"] = stack_stat.stat["hp"] + supplement
                play_sound(SOUNDS["sfx_pickup"])
                -- a partial pickup happened, return true
                success = true
                break
            end
        end
    end

    -- pickup is non-stackable, not yet collected or a new stack, add
    ::addtoinv::

    -- now check if stack is exceeding its max size
    if stack and stack.comp["stats"].stat["hp"] > stack.comp["stack"].max then
        print("stack exceeding its max size")
        local max_stack = stack.comp["stack"].max
        local difference = stack.comp["stats"].stat["hp"] - max_stack

        -- set picked stackable Entity HP as its max stack capacity
        stack.comp["stats"].stat["hp"] = max_stack
        item.comp["stats"].stat["hp"] = difference
    end

    -- check if space is available (stackable entities do not require more spaces)
    -- return is true or false based on partial (from stackables)/no pickup
    if comp.capacity > 0 and comp.spaces <= 0 then
        if not success then
            console_event("Thy inventory is full")
            play_sound(SOUNDS["puzzle_fail"])

            return false
        end

        print_event = comp.capacity > 0 and console_event("Thee pick up some " .. item_ref)
        play_sound(SOUNDS["sfx_pickup"])

        return true
    end

    comp.spaces = comp.spaces - 1
    table.insert(comp.items, item)
    print_event = comp.capacity > 0 and console_event("Thee pick up " .. item_ref)
    item.alive = "inventory"
    play_sound(SOUNDS["sfx_pickup"])

    return true
end

function inventory_remove(item_key, comp)
    local inv_str = "abcdefghijklmnopqrstuvwxyz"

    for i = 1, string.len(inv_str) do
        if string.sub(inv_str, i, i) == item_key then
            table.remove(comp.items, i)

            return true
        end
    end
end

function equipable_equip(owner, target)
    -- try to activate 'on_equip' related powers, if any
    if not owner.powers["on_equip"] then
        print('Warning: trying to activate "on_equip" power, but none is found')
        return false
    end

    owner.powers["on_equip"]:activate(owner, target, nil)
    return true
end

function equipable_unequip(owner, target)
    -- check if owner is cursed and cannot be removed. If so, reveal item
    if owner.comp["equipable"].cursed then
        console_event("Thy item is cursed and may not be removed!", {0.6, 0.2, 1})

        -- reveal Entity real description
        if owner.comp["secret"] then
            owner.comp["secret"] = nil
        end

        return false
    end

    if not owner.powers["on_unequip"] then
        print('Warning: trying to activate "on_unequip" power, but none is found. Object unequipped anyway.')
        return true
    end

    owner.powers["on_unequip"]:activate(owner, target, nil)
    return true
end

function sealed_activate(target, entity, player_comp)
    if target.name == player_comp.string then
        console_event("Thou dost unseal it!")
        if target.comp["trigger"] then
            target.comp["trigger"]:activate(owner, target, nil)
        end

        -- if Entity gets successfully unsealed, remove 'seled' comp
        target.comp["sealed"] = nil
        player_comp.string = ""
        return true
    end

    console_event("There is no response")

    return false
end

function locked_activate(owner, entity)
    if entity.comp["inventory"] then
        for _, item in ipairs(entity.comp["inventory"].items) do
            if item.comp["key"] and item.name == owner.name then
                console_event("Thou dost unlock it!")
                if owner.comp["trigger"] then
                    owner.comp["trigger"]:activate(owner, entity, nil)
                end

                -- if Entity was successfully unlocked, remove 'Locked' comp
                owner.comp["locked"] = nil

                -- activating optional unlock-related power
                action_to_power(owner, entity, "on_unlock")

                return true
            end
        end
        console_event("Thou dost miss the key")
        
        return true
    end
    error_handler("Entity without invetory is trying to use key to unlock")
    return false
end

function linked_activate(owner)
    local row_column = str_slicer(owner.name, "-", 1)
    local row = row_column[1]
    local column = row_column[2]

    return row, column
end

-- this func updates all the stats values based on base value + modifiers
-- all modifiers are contatined in table 'mods' (needs to be a table)
function  stat_update(target, id, mods)
    local stats = target.comp["stats"]
    -- immediately check target entity to update is in order
    if not stats then
        error_handler("Trying to stat_update() an entity without stats component")
        return false
    end

    -- if mods ~= nil and id is present, system is trying to create a duplicate
    if mods and stats.modifiers[id] then
        error_handler("Trying to add modifier in stat_update() but id is already occupied")
        return false
    end

    -- if mods == nil and id is present, then mutagen modificator is being removed
    if mods == nil and stats.modifiers[id] then
        stats.modifiers[id] = nil
    end

    -- if mods ~= nil id is not present, system is adding a new mutagen modificator
    if mods and not stats.modifiers[id] then
        -- this code translates to something like stats.modifiers["id"] = {
        -- ["maxhp"] = +3, ["sight"] = -1, ...}
        stats.modifiers[id] = mods
    end

    -- update all statistics with its base_stat + corresponding modifier
    -- NOTE: if modifier but no stat = ignored. If stat but no modifier = 0.
    for statistic, _ in pairs(stats.stat) do

        -- current hp and hunger can never be modified by mutagens
        if statistic == "hp" or statistic == "hunger" then
            goto continue
        end

        -- if no mods input and no mods stored, reset to base values and skip
        if not mods and not stats.modifier then
            print(":::::STATS RESET:::::")
            print("Stat selected: " .. statistic)
            print("Stat base: " .. stats.base_stat[statistic])
            print("Stat current: " .. stats.stat[statistic])
            stats.stat[statistic] = stats.base_stat[statistic]
            print("Result: " .. stats.stat[statistic])

            goto continue
        end

        -- each mutagen modificator in stats.modifier needs to be checked. This will
        -- be done for both add/removal, except when stats.modifiers is empty,
        -- since the loop wouldn't run
        for mod_id, modificator in pairs(stats.modifiers) do
            local mod_value = modificator[statistic] or 0

            print(":::::STATS MODIFICATION:::::")
            print("Modifier id: " .. mod_id)
            print("Stat selected: " .. statistic)
            print("Stat base: " .. stats.base_stat[statistic])
            print("Stat current: " .. stats.stat[statistic])
            print("Stat modifier value: " .. mod_value)
            stats.stat[statistic] = stats.base_stat[statistic] + (mod_value)
            print("Result: " .. stats.stat[statistic])
        end

        ::continue::
    end

    return true
end

-- this warns the player when an EffectTag influences him
function effect_player_check(target, string)
    -- if player is suffering effect, warn him
    if target.comp["player"] then
        local color = {[1] = 1, [2] = 0.97, [3] = 0.44}

        console_event(target.name .. " " .. string .. "!", color)

        return true
    end

    -- if not a player, ignore
    return false
end