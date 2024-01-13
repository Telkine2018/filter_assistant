local commons = require("scripts.commons")

local prefix = commons.prefix
local debug_mode = commons.debug_mode

local function png(name) return ('__filter_assistant__/graphics/%s.png'):format(name) end

data:extend({
    { type = "sprite", name = prefix .. "-up", filename = png("up"), position = { 0, 0 }, size = 32, flags = { "icon" } },
    { type = "sprite", name = prefix .. "-down", filename = png("down"), position = { 0, 0 }, size = 32,
        flags = { "icon" } },
    { type = "sprite", name = prefix .. "-minus", filename = png("minus"), position = { 0, 0 }, size = 32,
        flags = { "icon" } },
    { type = "sprite", name = prefix .. "-plus", filename = png("plus"), position = { 0, 0 }, size = 32,
        flags = { "icon" } }
})


local styles = data.raw["gui-style"].default


styles[prefix .. "_slot_button_default"] = {
    type = "button_style",
    parent = "flib_slot_button_default",
    size = 32
}


-- log(serpent.block(data.raw["custom-input"][commons.shift_button1_event]))


-- log(serpent.block(data.raw["constant-combinator"]["constant-combinator"]))
