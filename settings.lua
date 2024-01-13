

local commons = require("scripts.commons")

local prefix = commons.prefix

data:extend(
    {
		{
			type = "bool-setting",
			name = prefix .. "-add_filter",
			setting_type = "startup",
			default_value = true
		},
		{
			type = "bool-setting",
			name = prefix .. "-copy_paste_container",
			setting_type = "runtime-per-user",
			default_value = true
		},
		{
			type = "bool-setting",
			name = prefix .. "-use_on_player",
			setting_type = "runtime-per-user",
			default_value = true
		}

})


