---@mod gemini.ui.virtual_text Virtual text utilities
---@brief [[
--- Provides utilities for working with extmarks and virtual text.
---@brief ]]

local M = {}

--- Create a namespace
---@param name string
---@return number
function M.create_namespace(name)
	return vim.api.nvim_create_namespace("gemini_" .. name)
end

--- Set virtual text at position
---@param bufnr number
---@param ns_id number
---@param line number 0-indexed line number
---@param col number 0-indexed column
---@param text string|table Virtual text
---@param hl_group string Highlight group
---@param opts? table Additional options
---@return number extmark_id
function M.set(bufnr, ns_id, line, col, text, hl_group, opts)
	opts = opts or {}

	local virt_text
	if type(text) == "string" then
		virt_text = { { text, hl_group } }
	else
		virt_text = text
	end

	local extmark_opts = vim.tbl_extend("force", {
		virt_text = virt_text,
		virt_text_pos = opts.pos or "overlay",
		hl_mode = opts.hl_mode or "combine",
	}, opts)

	return vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, extmark_opts)
end

--- Clear virtual text
---@param bufnr number
---@param ns_id number
---@param start_line? number
---@param end_line? number
function M.clear(bufnr, ns_id, start_line, end_line)
	start_line = start_line or 0
	end_line = end_line or -1
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, start_line, end_line)
end

--- Get extmarks in range
---@param bufnr number
---@param ns_id number
---@param start_line? number
---@param end_line? number
---@return table[]
function M.get(bufnr, ns_id, start_line, end_line)
	start_line = start_line or 0
	end_line = end_line or -1
	return vim.api.nvim_buf_get_extmarks(bufnr, ns_id, { start_line, 0 }, { end_line, -1 }, {})
end

return M
