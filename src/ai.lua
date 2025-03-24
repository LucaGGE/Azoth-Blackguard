local AI_DTABLE = {
    ["aggressive"] = function(owner, npc_comp)
        local other_pawn
        local other_controller

        other_pawn = search_entity(owner, npc_comp)

        if not other_pawn then
            return false
        end

        other_controller = other_pawn.components["npc"] or other_pawn.components["player"]

        print("...")
        print(other_controller.group)
        if other_controller.group ~= npc_comp.group then
            -- reset other_pawn to its initial value
            local target_row = other_pawn.cell["grid_row"]
            local target_column = other_pawn.cell["grid_column"]
            local out_row
            local out_col
            local direction

            if owner.cell["grid_row"] < target_row then
                out_row = 1
            elseif owner.cell["grid_row"] == target_row then
                out_row = 0
            else 
                out_row = -1 
            end
            if owner.cell["grid_column"] < target_column then
                out_col = 1
            elseif owner.cell["grid_column"] == target_column then
                out_col = 0
            else 
                out_col = -1 
            end

            direction = {out_row, out_col}

            owner.components["movable"]:move_entity(owner, direction)

            return true
        end

    end
}

-- this simple function feeds necessary input in AI_DTABLE,
-- which in turns manages NPC behavior
function ai_behavior(owner, npc_comp)
    -- check nature validity
    if not AI_DTABLE[npc_comp.nature] then
        --print("ERROR: invalid NPC nature: " .. npc_comp.nature)
        return false
    end

    return AI_DTABLE[npc_comp.nature](owner, npc_comp)    
end

function search_entity(owner, npc_comp)
    print(owner.name)
    local search_row = owner.cell["grid_row"] - npc_comp.sight
    local search_col
    local column_condition
    local row_condition

    -- searching for enemy entities in a square. This algorithm is temporary and badly designed.
    -- TO DO TO DO TO DOTO DO TO DO TO DOTO DO TO DO TO DOTO DO TO DO TO DO: need to choose target & ignore ones hidden behind obstacles
    for i = 0, npc_comp.sight * 2 do
        search_col = owner.cell["grid_column"] - npc_comp.sight
        for j = 0, npc_comp.sight * 2 do
            local other_entity

            -- check if search is happening beyond grid boundaries
            column_condition = search_col > g.grid_x or search_col <= 0
            row_condition = search_row > g.grid_y or search_row <= 0

            -- if search conditions are invalid, skip loop
            if column_condition or row_condition then
                goto continue
            end

            other_entity = g.grid[search_row][search_col].occupant

            -- skip code if found no Entity or self
            if not other_entity or other_entity == owner then
                goto continue
            end

            -- return other_entity only if it is not an obstacle
            if other_entity.components["npc"] or other_entity.components["player"] then
                print("Found other entity: " .. other_entity.name)
                return other_entity
            end

            ::continue::
            
            search_col = search_col + 1
        end
        search_row = search_row + 1
    end

    -- if no Entity was found, return false
    return false
end