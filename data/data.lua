local commons = require("scripts.commons")

local prefix = commons.prefix
local debug_mode = commons.debug_mode

local function png(name) return ('__filter_assistant__/graphics/%s.png'):format(name) end

local declarations = {}

local function add(def)
    table.insert(declarations, def)
end

local function add_sprite(name)
    add({
        type = "sprite",
        name = prefix .. "-" .. name,
        filename = png(name),
        position = { 0, 0 },
        size = 32,
        flags = { "icon" }
    })
end

add_sprite("down")
add_sprite("up")
add_sprite("minus")
add_sprite("plus")

add_sprite("add")
add_sprite("apply")
add_sprite("import")
add_sprite("clear")
add_sprite("sort")
add_sprite("bp")

data:extend(declarations)

local styles = data.raw["gui-style"].default


styles[prefix .. "_slot_button_default"] = {
    type = "button_style",
    parent = "flib_slot_button_default",
    size = 32
}

styles[prefix .. "_flow"] = {
    type = "vertical_flow_style",
    padding = 0,
    vertical_spacing = 0,
    margin = 0
}

styles[prefix .. "_mini_button"] = {
    type = "button_style",
    parent = "flib_slot_button_default",
    padding = 0,
    margin = 0
}



-- log(serpent.block(data.raw["custom-input"][commons.shift_button1_event]))


-- log(serpent.block(data.raw["constant-combinator"]["constant-combinator"]))
