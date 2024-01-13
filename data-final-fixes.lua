
local commons = require("scripts.commons")


if settings.startup[commons.prefix .. "-add_filter"].value then
	for _, type in pairs({"container","logistic-container","infinity-container"}) do
		for name, chest in pairs(data.raw[type]) do
			chest.inventory_type = "with_filters_and_bar"
			data:extend { chest }
		end
	end
end

data:extend
{
    {
        type = "custom-input",
        name = commons.shift_button1_event,
        key_sequence = "SHIFT + mouse-button-1",
        consuming = "none"
    }
}
