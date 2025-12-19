---@mod gemini.integrations.blink blink.cmp integration
---@brief [[
--- Provides a completion source for blink.cmp.
---@brief ]]

local M = {}

--- Create a blink.cmp source
---@return table
function M.new()
	return setmetatable({}, { __index = M })
end

--- Check if source is available
---@return boolean
function M:enabled()
	local gemini = require("gemini")
	return gemini.is_initialized()
end

--- Get completions
---@param context table
---@param callback function
function M:get_completions(context, callback)
	local api = require("gemini.api")
	local ctx = require("gemini.context").build_buffer_context()

	api.complete(ctx, function(err, response)
		if err then
			callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
			return
		end

		if response and response.text then
			local items = {
				{
					label = response.text:match("^[^\n]+") or response.text,
					insertText = response.text,
					kind = vim.lsp.protocol.CompletionItemKind.Snippet,
					source_name = "gemini",
				},
			}
			callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
		else
			callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
		end
	end)
end

return M
