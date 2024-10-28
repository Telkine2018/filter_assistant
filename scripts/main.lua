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

---@param item ItemFilter?
---@return string?
local function item_to_string(item)
    if not item then return nil end
    return item.name .. "/" .. (item.comparator or "=") .. "/" .. (item.quality or "normal")
end

local gmatch = string.gmatch

---@param qname string?
---@return ItemFilter?
local function string_to_item(qname)
    if not qname then return nil end
    if type(qname) ~= "string" then return qname end
    local split = gmatch(qname, "([^/]+)")
    local name = split()
    local comparator = split() or "="
    local quality = split() or "normal"
    return { name = name, comparator = comparator, quality = quality }
end

---Close current ui
---@param player LuaPlayer
local function close_ui(player)
    ---@type LuaGuiElement
    local frame = player.gui.relative[frame_name]
    if frame and frame.valid then
        local vars = tools.get_vars(player)
        vars.current = nil
        frame.destroy()

        local scanned_list = storage.scanned_list
        if scanned_list then
            scanned_list[player.index] = nil
        end
    end
end

local bsize = 30
local mini_style = prefix .. "_mini_button"
local mini_size = 16

---@param filter_flow LuaGuiElement
---@param qname string?
---@param count ItemCount
local function create_cell(filter_flow, qname, count)
    local filter_cell = filter_flow.add { type = "flow", direction = "horizontal" }

    local item = string_to_item(qname)
    local b = filter_cell.add { type = "choose-elem-button", elem_type = "item-with-quality", name = "item" }
    b.elem_value = item
    b.style.size = bsize

    local f = filter_cell.add { type = "textfield", name = "count", numeric = true, text = tostring(count),
        tooltip = { "tooltip.count" } }
    f.style.width = 40

    local count_flow = filter_cell.add { type = "flow", direction = "vertical" }
    count_flow.style = prefix .. "_flow"
    b = count_flow.add { type = "sprite-button", sprite = prefix .. "-plus", name = prefix .. "-plus",
        style = mini_style }
    b.style.size = mini_size
    b = count_flow.add { type = "sprite-button", sprite = prefix .. "-minus", name = prefix .. "-minus",
        style = mini_style }
    b.style.size = mini_size

    local position_flow = filter_cell.add { type = "flow", direction = "vertical" }
    position_flow.style = prefix .. "_flow"
    b = position_flow.add { type = "sprite-button", sprite = prefix .. "-up", name = prefix .. "-up",
        style = mini_style, tooltip = { "tooltip.up" } }
    b.style.size = mini_size
    b = position_flow.add { type = "sprite-button", sprite = prefix .. "-down", name = prefix .. "-down",
        style = mini_style, tooltip = { "tooltip.down" } }
    b.style.size = mini_size
end

---@param filter_flow LuaGuiElement
---@param filter_order string[]
---@param filters {[string]:integer}
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
---@return {[string]:integer}
---@return string[]
local function get_inventory_filters(inv)
    ---@type {[string]:integer}
    local filter_counts = {}

    ---@type string[]
    local filter_order = {}

    for index = 1, #inv do
        local item = inv.get_filter(index)
        if item then
            local qname = item_to_string(item)
            if qname then
                if not filter_counts[qname] then
                    filter_counts[qname] = 1
                    table.insert(filter_order, qname)
                else
                    filter_counts[qname] = filter_counts[qname] + 1
                end
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
    ---@return table string[]
    local filter_order = {}

    local content = inv.get_contents()
    for _, itemc in pairs(content) do
        local qname = itemc.name .. "/=/" .. itemc.quality
        if not filter_counts[qname] then
            filter_counts[qname] = itemc.count
            table.insert(filter_order, qname)
        else
            filter_counts[qname] = filter_counts[qname] + itemc.count
        end
    end
    for qname, count in pairs(filter_counts) do
        local item = string_to_item(qname)
        ---@cast item -nil
        filter_counts[qname] = math.ceil(count / prototypes.item[item.name].stack_size)
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

        local filter_counts, filter_order = get_inventory_filters(inv)
        local filter_scroll = frame.add { type = "scroll-pane", direction = "vertical", name = "filter_scroll", }
        filter_scroll.style.maximal_height = 800
        filter_scroll.style.minimal_width = 190

        local col_count = player.mod_settings[prefix .. "-col_count"].value
        local filter_flow = filter_scroll.add { type = "table", column_count = col_count, name = "filter_flow", }

        create_cells(filter_flow, filter_order, filter_counts)


        local param_flow = frame.add { type = "table", column_count = 2 }
        param_flow.add { type = "label", caption = { "label.free_slots" } }
        param_flow.style.top_margin = 5
        param_flow.style.bottom_margin = 5
        local free_slot = param_flow.add { type = "textfield", name = "free_slot", numeric = true, text = "0" }
        free_slot.style.width = 50
        free_slot.style.left_margin = 10

        local b_flow1 = frame.add { type = "flow", direction = "horizontal" }
        local b = b_flow1.add { type = "sprite-button", sprite = prefix .. "-add", name = prefix .. "_add", tooltip = { "tooltip.add" } }
        b.style.size = 24
        b = b_flow1.add { type = "sprite-button", sprite = prefix .. "-apply", name = prefix .. "_apply",
            tooltip = { "tooltip.apply" } }
        b.style.size = 24
        b = b_flow1.add { type = "sprite-button", sprite = prefix .. "-import", name = prefix .. "_import",
            tooltip = { "tooltip.import" } }
        b.style.size = 24
        b = b_flow1.add { type = "sprite-button", sprite = prefix .. "-clear", name = prefix .. "_clear",
            tooltip = { "tooltip.clear" } }
        b.style.size = 24

        b = b_flow1.add { type = "sprite-button", sprite = prefix .. "-sort", name = prefix .. "_sort",
            tooltip = { "tooltip.sort" } }
        b.style.size = 24

        b = b_flow1.add { type = "sprite-button", sprite = prefix .. "-bp", name = prefix .. "_bp",
            tooltip = { "tooltip.bp" } }
        b.style.size = 24

        local vars = tools.get_vars(player)

        ---@type  ScanProcess
        vars.current = {
            entity = entity,
            filter_flow = filter_flow,
            filter_order = filter_order,
            filter_counts = filter_counts,
            free_slot = free_slot
        }

        if not storage.scanned_list then
            storage.scanned_list = {}
        end
        storage.scanned_list[player.index] = vars.current
    end
end

tools.on_gui_click(prefix .. "_add", function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    local filter_flow = frame.filter_scroll.filter_flow
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
    local filter_flow = frame.filter_scroll.filter_flow
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

    local filter_flow = frame.filter_scroll.filter_flow
    filter_flow.clear()

    local vars = tools.get_vars(player)
    local current = vars.current
    if not current then return end

    if not current.entity.valid then return end

    local inv = get_inventory(current.entity)
    local last = #inv
    current.free_slot.text = tostring(last)
end)

tools.on_gui_click(prefix .. "-up", function(e)
    local element = e.element
    if not element or not element.valid then return end
    local cell = element.parent.parent
    ---@cast cell -nil
    local filter_flow = cell.parent
    ---@cast filter_flow -nil
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
    local cell = element.parent.parent
    ---@cast cell -nil
    local filter_flow = cell.parent
    ---@cast filter_flow -nil
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
    local cell = element.parent.parent
    ---@cast cell  ElementWithFields
    local fcount = cell.count
    if fcount.text then
        fcount.text = tostring(tonumber(fcount.text) + 1)
    end
end)

tools.on_gui_click(prefix .. "-minus", function(e)
    local element = e.element
    if not element or not element.valid then return end
    local cell = element.parent.parent
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

---@param filter_flow  LuaGuiElement
---@return {item:{name:string,quality:string}, count:integer}[]
---@return {[string]:boolean}?
local function get_edited_filters(filter_flow)
    local records = {}
    local item_set = {}
    for _, child in pairs(filter_flow.children) do
        local item = child["item"].elem_value
        if item then
            local count = tonumber(child["count"].text)
            if count and count > 0 then
                table.insert(records, { item = item, count = count })
                local qname = item_to_string(item)
                ---@cast qname -nil
                item_set[qname] = true
            end
        end
    end
    return records, item_set
end

---@param player LuaPlayer
---@param connect_to_lb2 boolean?
local function do_apply(player, connect_to_lb2)
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

    local records, item_set = get_edited_filters(filter_flow)

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

    if not free_slot_count or free_slot_count > 0 then
        item_set = nil
    end

    if connect_to_lb2 then
        if remote.interfaces["logistic_belt2_filtering"] and remote.interfaces["logistic_belt2_filtering"].set_restrictions then
            remote.call("logistic_belt2_filtering", "set_restrictions", entity, item_set, player.index)
        end
    end

    if free_slot_count then
        last = last + free_slot_count
    end
    if last <= #inv and inv.supports_bar() then
        inv.set_bar(last)
    end

    temp.destroy()
end

tools.on_gui_click(prefix .. "_sort", function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    local vars = tools.get_vars(player)
    local current = vars.current
    if not current then return end

    local filter_flow = frame.filter_scroll.filter_flow

    local records     = get_edited_filters(filter_flow)

    table.sort(records,
        function(i1, i2)
            local p1 = prototypes.item[i1.item.name]
            local p2 = prototypes.item[i2.item.name]
            if p1.group ~= p2.group then
                return p1.group.order < p2.group.order
            elseif p1.subgroup ~= p2.subgroup then
                return p1.subgroup.order < p2.subgroup.order
            else
                return p1.order < p2.order
            end
        end)

    filter_flow.clear()
    for _, r in ipairs(records) do
        create_cell(filter_flow, r.item, r.count)
    end
end)

tools.on_gui_click(prefix .. "_bp", function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    local vars = tools.get_vars(player)
    local current = vars.current
    if not current then return end

    local filter_flow = frame.filter_scroll.filter_flow
    local stack = player.cursor_stack
    if not stack then return end
    if stack.is_blueprint then
        local entities = stack.get_blueprint_entities()
        local records = {}
        for _, entity in pairs(entities) do
            if entity.name == "constant-combinator" then
                local sections = (entity.control_behavior --[[@as any]]).sections.sections
                for _, section in pairs(sections) do
                    local filters = section.filters
                    for _, filter in pairs(filters) do
                        if not filter.type or filter.type == "item" then
                            table.insert(records, {
                                item = { name = filter.name, quality = filter.quality },
                                count = filter.count
                            })
                        end
                    end
                end
            end
        end
        filter_flow.clear()
        for _, r in ipairs(records) do
            create_cell(filter_flow, r.item, r.count)
        end
    else
        stack.clear()
        stack.set_stack({ name = "blueprint", count = 1 })

        local records = get_edited_filters(filter_flow)
        local x = 0.5
        local y = 0.5
        local bpentities = {}
        local current = nil
        local filters
        local index
        local entity_number = 1
        for _, r in pairs(records) do
            if current == nil then
                filters = {}
                local bpentity = {

                    name = "constant-combinator",
                    position = { x = x, y = y },
                    control_behavior = {
                        sections = {
                            sections = {
                                { index = 1, filters = filters }
                            }
                        }
                    },
                    entity_number = entity_number
                }
                x = x + 1
                current = bpentity
                table.insert(bpentities, bpentity)
                index = 1
                entity_number = entity_number + 1
            end
            table.insert(filters, {
                name = r.item.name,
                quality = r.item.quality,
                count = r.count,
                comparator = "=",
                index = index
            })
            index = index + 1
            if index > 20 then
                current = nil
            end
        end
        stack.set_blueprint_entities(bpentities)
    end
end)

---@param e EventData.on_gui_click
local function on_apply(e)
    local player = game.players[e.player_index]
    local frame = player.gui.relative[frame_name]
    if not frame then return end

    do_apply(player, e.control)
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
    local scanned_list = storage.scanned_list
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
                local filter_counts, filter_order = get_inventory_filters(inv)

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

---@param inv LuaInventory
---@param item string
---@param count integer?
local function add_filter(inv, item, count)
    if not count then count = 1 end
    for i = 1, #inv do
        local filter = inv.get_filter(i)
        local found
        if filter == item then
            found = true
        elseif filter == nil then
            local stack = inv[i]
            if stack.valid_for_read then
                if stack.name == item then
                    inv.set_filter(i, item)
                    found = true
                end
            else
                inv.set_filter(i, item)
                found = true
            end
        end
        if found then
            count = count - 1
            if count <= 0 then
                return
            end
        end
    end
end

local function on_shift_button1(e)
    local player = game.players[e.player_index]

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
                add_filter(inv, ingredient.name, 2)
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
