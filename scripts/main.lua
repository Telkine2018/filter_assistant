local commons = require("scripts.commons")

local prefix = commons.prefix
local tools = require("scripts.tools")

local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local frame_name = prefix .. "_frame"

local container_filter = {
    ["container"] = true,
    ["logistic-container"] = true,
    ["linked-container"] = true
}

---Close current ui
---@param player LuaPlayer
local function close_ui(player)
    ---@type LuaGuiElement
    local frame = player.gui.relative[frame_name]
    if frame and frame.valid then
        local vars = tools.get_vars(player)
        vars.current = nil
        frame.destroy()

        local scanned_list = global.scanned_list
        if scanned_list then
            scanned_list[player.index] = nil
        end
    end
end

---@param filter_flow LuaGuiElement
---@param item Item?
---@param count ItemCount
local function create_cell(filter_flow, item, count)
    local filter_cell = filter_flow.add { type = "flow", direction = "horizontal" }
    filter_cell.add { type = "choose-elem-button", elem_type = "item", item = item, name = "item" }
    local f = filter_cell.add { type = "textfield", name = "count", numeric = true, text = tostring(count),
        tooltip = { "tooltip.count" } }
    f.style.width = 50
    f.style.top_margin = 7

    local b = filter_cell.add { type = "sprite-button", sprite = prefix .. "-plus", name = prefix .. "-plus",
        style = prefix .. "_slot_button_default" }
    b.style.top_margin = 7
    b = filter_cell.add { type = "sprite-button", sprite = prefix .. "-minus", name = prefix .. "-minus",
        style = prefix .. "_slot_button_default" }
    b.style.top_margin = 7
    b = filter_cell.add { type = "sprite-button", sprite = prefix .. "-up", name = prefix .. "-up",
        style = prefix .. "_slot_button_default", tooltip = { "tooltip.up" } }
    b.style.top_margin = 7
    b = filter_cell.add { type = "sprite-button", sprite = prefix .. "-down", name = prefix .. "-down",
        style = prefix .. "_slot_button_default", tooltip = { "tooltip.down" } }
    b.style.top_margin = 7
end

---@param filter_flow LuaGuiElement
---@param filter_order Item[]
---@param filters table<Item, ItemCount>
local function create_cells(filter_flow, filter_order, filters)
    for _, item in ipairs(filter_order) do
        create_cell(filter_flow, item, filters[item])
    end
end

---Get inventory from entity
---@param entity LuaEntity
---@return LuaInventory?
---@return defines.relative_gui_type?
local function get_inventory(entity)
    ---@type LuaInventory?
    local inv
    ---@type defines.relative_gui_type
    local gui_type
    if container_filter[entity.type] then
        if (entity.type == "linked-container") then
            inv, gui_type = entity.get_inventory(defines.inventory.chest), defines.relative_gui_type
                .linked_container_gui
        else
            inv, gui_type = entity.get_inventory(defines.inventory.chest), defines.relative_gui_type.container_gui
        end
    elseif entity.type == "car" then
        inv, gui_type = entity.get_inventory(defines.inventory.car_trunk), defines.relative_gui_type.car_gui
    elseif entity.type == "cargo-wagon" then
        inv, gui_type = entity.get_inventory(defines.inventory.cargo_wagon), defines.relative_gui_type.container_gui
    elseif entity.type == "spider-vehicle" then
        inv, gui_type = entity.get_inventory(defines.inventory.spider_trunk),
            defines.relative_gui_type.spider_vehicle_gui
    elseif entity.type == "character" then
        inv, gui_type = entity.get_inventory(defines.inventory.character_main), defines.relative_gui_type.controller_gui
    else
        return nil, nil
    end
    ---@cast inv -nil
    return inv, gui_type
end

---@param inv LuaInventory
---@return table ItemTable
---@return table Item[]
local function get_filters(inv)
    ---@type ItemTable
    local filter_counts = {}

    ---@type Item[]
    local filter_order = {}

    for index = 1, #inv do
        local item = inv.get_filter(index)
        if item then
            if not filter_counts[item] then
                filter_counts[item] = 1
                table.insert(filter_order, item)
            else
                filter_counts[item] = filter_counts[item] + 1
            end
        end
    end

    return filter_counts, filter_order
end

---@param inv LuaInventory
---@return table table<Item, integer>
---@return table Item[]
local function import_filters(inv)
    ---@type table<Item, integer>
    local filter_counts = {}
    ---@return table table<Item, integer>
    local filter_order = {}

    for index = 1, #inv do
        if inv[index].valid and inv[index].valid_for_read then
            local item = inv[index].name
            if item then
                if not filter_counts[item] then
                    filter_counts[item] = 1
                    table.insert(filter_order, item)
                else
                    filter_counts[item] = filter_counts[item] + 1
                end
            end
        end
    end

    return filter_counts, filter_order
end

---@param e EventData.on_gui_opened
local function on_gui_opened(e)
    local player = game.players[e.player_index]
    local entity = e.entity

    if not entity then
        if e.gui_type ~= defines.gui_type.controller then
            return
        end
        if not player.mod_settings[prefix .. "-use_on_player"].value then
            return
        end
        entity = player.character
        if not entity then return end
    elseif not entity.valid then
        return
    end

    close_ui(player)
    if container_filter[entity.type]
        or entity.type == "car"
        or entity.type == "cargo-wagon"
        or entity.type == "spider-vehicle"
        or entity.type == "character"
    then
        local inv, anchor = get_inventory(entity)

        ---@cast anchor -nil
        ---@cast inv -nil
        if not inv.supports_filters() then
            return
        end

        local frame = player.gui.relative.add { type = "frame", caption = { "frame.title" }, name = frame_name,

            anchor = {
                gui = anchor,
                position = defines.relative_gui_position.right
            },
            direction = "vertical"
        }

        frame.style.minimal_width = 200

        local filter_counts, filter_order = get_filters(inv)
        local filter_flow = frame.add { type = "scroll-pane", name = "filter_flow", direction = "vertical" }
        filter_flow.style.maximal_height = 800
        filter_flow.style.minimal_width = 190

        create_cells(filter_flow, filter_order, filter_counts)


        local param_flow = frame.add { type = "table", column_count = 2 }
        param_flow.add { type = "label", caption = { "label.free_slots" } }
        param_flow.style.top_margin = 5
        param_flow.style.bottom_margin = 5
        local free_slot = param_flow.add { type = "textfield", name = "free_slot", numeric = true, text = "0" }
        free_slot.style.width = 50
        free_slot.style.left_margin = 10

        local b_flow1 = frame.add { type = "flow", direction = "horizontal" }
        b_flow1.add { type = "button", caption = { "button.add" }, name = prefix .. "_add", tooltip = { "tooltip.add" } }
        b_flow1.add { type = "button", caption = { "button.apply" }, name = prefix .. "_apply",
            tooltip = { "tooltip.apply" } }

        local b_flow2 = frame.add { type = "flow", direction = "horizontal" }
        b_flow2.add { type = "button", caption = { "button.import" }, name = prefix .. "_import",
            tooltip = { "tooltip.import" } }
        b_flow2.add { type = "button", caption = { "button.clear" }, name = prefix .. "_clear",
            tooltip = { "tooltip.clear" } }

        local vars = tools.get_vars(player)
        ---@type  ScanProcess
        vars.current = {
            entity = entity,
            filter_flow = filter_flow,
            filter_order = filter_order,
            filter_counts = filter_counts,
            free_slot = free_slot
        }

        if not global.scanned_list then
            global.scanned_list = {}
        end
        global.scanned_list[player.index] = vars.current
    end
end

tools.on_gui_click(prefix .. "_add", function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    local filter_flow = frame.filter_flow
    create_cell(filter_flow, nil, 1)
end)

tools.on_gui_click(prefix .. "_import", function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    local vars = tools.get_vars(player)
    local current = vars.current
    if not current then return end

    local entity = current.entity
    local filter_flow = frame.filter_flow
    local inv = get_inventory(entity)
    ---@cast inv -nil
    local filter_counts, filter_order = import_filters(inv)
    filter_flow.clear()
    create_cells(filter_flow, filter_order, filter_counts)
end)


tools.on_gui_click(prefix .. "_clear", function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    local filter_flow = frame.filter_flow
    filter_flow.clear()
end)

tools.on_gui_click(prefix .. "-up", function(e)
    local element = e.element
    if not element or not element.valid then return end
    local cell = element.parent
    local filter_flow = cell.parent
    local index = cell.get_index_in_parent()
    local count = 1
    if e.shift then count = 5 end
    while (count > 0) do
        if index > 1 then
            filter_flow.swap_children(index - 1, index)
        else
            break
        end
        count = count - 1
        index = index - 1
    end
end)

tools.on_gui_click(prefix .. "-down", function(e)
    local element = e.element
    if not element or not element.valid then return end
    local cell = element.parent
    local filter_flow = cell.parent
    local index = cell.get_index_in_parent()
    local count = 1
    if e.shift then count = 5 end
    while count > 0 do
        if index < #filter_flow.children then
            filter_flow.swap_children(index + 1, index)
        end
        count = count - 1
        index = index + 1
    end
end)

---@alias ElementWithFields LuaGuiElement|{["count"]:LuaGuiElement}

tools.on_gui_click(prefix .. "-plus", function(e)
    local element = e.element
    if not element or not element.valid then return end
    local cell = element.parent
    ---@cast cell  ElementWithFields
    local fcount = cell.count
    if fcount.text then
        fcount.text = tostring(tonumber(fcount.text) + 1)
    end
end)

tools.on_gui_click(prefix .. "-minus", function(e)
    local element = e.element
    if not element or not element.valid then return end
    local cell = element.parent
    ---@cast cell ElementWithFields
    local fcount = cell.count
    if fcount.text then
        local count = tonumber(fcount.text)
        if count == 1 then
            cell.destroy()
        else
            fcount.text = tostring(count - 1)
        end
    end
end)


---@param player LuaPlayer
local function do_apply(player)
    local vars = tools.get_vars(player)
    local current = vars.current
    if not current then return end

    local filter_flow = current.filter_flow
    local entity = current.entity
    local free_slot_count = tonumber(current.free_slot.text)

    if not entity.valid then
        return
    end

    local inv = get_inventory(entity)
    local temp = game.create_inventory(#inv)

    ---@cast inv -nil

    for i = 1, #inv do
        local stack = inv[i]
        temp[i].swap_stack(stack)
    end

    inv.clear()

    if inv.supports_bar() then
        inv.set_bar()
    end

    local item_set = {}

    local records = {}
    for _, child in pairs(filter_flow.children) do
        local item = child.item.elem_value
        if item then
            local count = tonumber(child.count.text)
            if count and count > 0 then
                table.insert(records, { item = item, count = count })
                item_set[item] = true
            end
        end
    end

    local index = 1
    for _, record in pairs(records) do
        for i = 1, record.count do
            if index > #inv then
                break
            end
            inv.set_filter(index, record.item)
            index = index + 1
        end
        if index > #inv then
            break
        end
    end

    local last = index
    while (index <= #inv) do
        inv.set_filter(index, nil)
        index = index + 1
    end

    local remaining = {}
    for i = 1, #inv do
        local stack = temp[i]
        local count = stack.count
        local count1 = inv.insert(stack)
        if count1 ~= count then
            stack.count = count - count1
            table.insert(remaining, i)
        end
    end

    if #remaining > 0 then
        local private_inv = player.get_main_inventory()
        ---@cast private_inv -nil
        for _, index in ipairs(remaining) do
            local stack = temp[index]
            local count = stack.count
            local count1 = private_inv.insert(stack)
            if count1 ~= count then
                stack.count = count - count1
                entity.surface.spill_item_stack(entity.position, stack, true, entity.force)
            end
        end
    end

    if free_slot_count > 0 then
        item_set = nil
    end

    if remote.interfaces["logistic_belt2_filtering"] and remote.interfaces["logistic_belt2_filtering"].set_restrictions then
        remote.call("logistic_belt2_filtering", "set_restrictions", entity.unit_number, item_set, player.index)
    end

    if free_slot_count then
        last = last + free_slot_count
    end
    if last <= #inv and inv.supports_bar() then
        inv.set_bar(last)
    end

    if free_slot_count == 0 then

    end

    temp.destroy()
end

local function on_apply(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    do_apply(player)
end

local function on_gui_elem_changed(e)
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)
    if not vars.current then return end

    if not e.element or e.element.name ~= "item" then return end

    if e.element.elem_value == nil then
        e.element.parent.destroy()
    end
end

---@param e EventData.on_gui_confirmed
local function on_gui_confirmed(e)
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)
    if not vars.current then return end

    if not tools.is_child_of(e.element, frame_name) then return end

    do_apply(player)
end

local function on_gui_closed(e)
    local player = game.players[e.player_index]

    close_ui(player)
end

local function on_nth_tick(e)
    local scanned_list = global.scanned_list
    if not scanned_list then return end

    local list = {}
    for player_index, value in pairs(scanned_list) do
        list[player_index] = value
    end

    for player_index, container in pairs(list) do
        if not container.entity.valid then
            scanned_list[player_index] = nil
        else
            local inv = get_inventory(container.entity)
            if inv then
                local filter_counts, filter_order = get_filters(inv)

                local change = false
                if #filter_order ~= #container.filter_order then
                    change = true
                else
                    for index, item in ipairs(filter_order) do
                        if item ~= container.filter_order[index] then
                            change = true
                            break
                        elseif filter_counts[item] ~= container.filter_counts[item] then
                            change = true
                            break
                        end
                    end
                end
                if change then
                    container.filter_flow.clear()
                    create_cells(container.filter_flow, filter_order, filter_counts)
                    container.filter_order = filter_order
                    container.filter_counts = filter_counts
                end
            end
        end
    end
end

local function add_filter(inv, item)
    for i = 1, #inv do
        local filter = inv.get_filter(i)
        if filter == item then return end

        if filter == nil then
            local stack = inv[i]
            if stack.valid_for_read then
                if stack.name == item then
                    inv.set_filter(i, item)
                    return
                end
            else
                inv.set_filter(i, item)
                return
            end
        end
    end
end

local function on_shift_button1(e)
    local player = game.players[e.player_index]

    debug("click")
    local machine = player.entity_copy_source
    if machine and machine.type == "assembling-machine" then
        if not player.mod_settings[prefix .. "-copy_paste_container"].value then
            return
        end
        local selected = player.selected
        if not selected or not selected.valid then return end

        if selected.type == "logistic-container" and (selected.prototype.logistic_mode == "requester" or selected.prototype.logistic_mode == "buffer") then
            return
        end

        local inv = get_inventory(selected)
        if not inv then return end

        local recipe = machine.get_recipe()
        if not recipe then return end

        for _, ingredient in pairs(recipe.ingredients) do
            if ingredient.type == "item" then
                add_filter(inv, ingredient.name)
            end
        end
        for _, product in pairs(recipe.products) do
            if product.type == "item" then
                add_filter(inv, product.name)
            end
        end
    end
end

tools.on_gui_click(prefix .. "_apply", on_apply)
tools.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
tools.on_event(defines.events.on_gui_opened, on_gui_opened)
tools.on_event(defines.events.on_gui_closed, on_gui_closed)
tools.on_event(defines.events.on_gui_confirmed, on_gui_confirmed)

script.on_event(commons.shift_button1_event, on_shift_button1)

script.on_nth_tick(30, on_nth_tick)
