---@mod gemini.integrations.cmp nvim-cmp integration
---@brief [[
--- Provides a completion source for nvim-cmp.
---@brief ]]

local M = {}

local source = {}

source.new = function()
	return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
	return [[\k\+]]
end

source.get_trigger_characters = function()
	return { ".", ":", "(", "[", "{", " ", "\t" }
end

source.is_available = function()
	local gemini = require("gemini")
	return gemini.is_initialized()
end

source.complete = function(self, params, callback)
	local api = require("gemini.api")
	local context = require("gemini.context").build_buffer_context()

	api.complete(context, function(err, response)
		if err then
			callback({ items = {} })
			return
		end

		if response and response.text then
			local items = {
				{
					label = response.text:match("^[^\n]+") or response.text,
					insertText = response.text,
					kind = 15, -- Snippet
					documentation = {
						kind = "markdown",
						value = "```" .. (context.filetype or "") .. "\n" .. response.text .. "\n```",
					},
				},
			}
			callback({ items = items })
		else
			callback({ items = {} })
		end
	end)
end

--- Register the source with nvim-cmp
function M.setup()
	local ok, cmp = pcall(require, "cmp")
	if not ok then
		return
	end

	cmp.register_source("gemini", source.new())
end

return M
