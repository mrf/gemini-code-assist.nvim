---@mod gemini.context Context building module
---@brief [[
--- Builds context for AI requests from various sources.
---@brief ]]

local M = {}

--- Build buffer context for code completion
---@return table
function M.build_buffer_context()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local col = cursor[2]

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local total_lines = #lines

	-- Get prefix (code before cursor)
	local prefix_lines = {}
	for i = 1, line - 1 do
		table.insert(prefix_lines, lines[i])
	end
	-- Add current line up to cursor
	if lines[line] then
		table.insert(prefix_lines, lines[line]:sub(1, col))
	end

	-- Get suffix (code after cursor)
	local suffix_lines = {}
	if lines[line] then
		table.insert(suffix_lines, lines[line]:sub(col + 1))
	end
	for i = line + 1, total_lines do
		table.insert(suffix_lines, lines[i])
	end

	return {
		bufnr = bufnr,
		filename = vim.api.nvim_buf_get_name(bufnr),
		filetype = vim.bo[bufnr].filetype,
		line = line,
		col = col,
		prefix = table.concat(prefix_lines, "\n"),
		suffix = table.concat(suffix_lines, "\n"),
		current_line = lines[line] or "",
		total_lines = total_lines,
	}
end

--- Build context for chat
---@return table
function M.build_chat_context()
	local buffer_ctx = M.build_buffer_context()
	local workspace_ctx = M.build_workspace_context()

	local parts = {}

	table.insert(parts, "Current file: " .. (buffer_ctx.filename or "untitled"))
	table.insert(parts, "Language: " .. (buffer_ctx.filetype or "text"))

	if workspace_ctx.root then
		table.insert(parts, "Workspace: " .. workspace_ctx.root)
	end

	-- Add current buffer content (truncated if too long)
	local content = buffer_ctx.prefix .. buffer_ctx.suffix
	local max_chars = 4000
	if #content > max_chars then
		content = content:sub(1, max_chars) .. "\n... (truncated)"
	end

	table.insert(parts, "")
	table.insert(parts, "Current file content:")
	table.insert(parts, "```" .. (buffer_ctx.filetype or ""))
	table.insert(parts, content)
	table.insert(parts, "```")

	-- Add selection if any
	local selection = M.get_visual_selection()
	if selection then
		table.insert(parts, "")
		table.insert(parts, "Selected code:")
		table.insert(parts, "```" .. (buffer_ctx.filetype or ""))
		table.insert(parts, selection)
		table.insert(parts, "```")
	end

	return {
		text = table.concat(parts, "\n"),
		filename = buffer_ctx.filename,
		filetype = buffer_ctx.filetype,
		workspace = workspace_ctx.root,
	}
end

--- Build workspace context
---@return table
function M.build_workspace_context()
	local path = require("gemini.util.path")
	local root = path.find_root()

	return {
		root = root,
		-- TODO: Add more workspace info (package.json, git info, etc.)
	}
end

--- Get visual selection
---@return string?
function M.get_visual_selection()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		return nil
	end

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	if start_pos[2] == 0 and end_pos[2] == 0 then
		return nil
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		return nil
	end

	return table.concat(lines, "\n")
end

--- Build LSP context (diagnostics, symbols)
---@return table
function M.build_lsp_context()
	local bufnr = vim.api.nvim_get_current_buf()

	-- Get diagnostics
	local diagnostics = vim.diagnostic.get(bufnr)
	local diag_text = {}

	for _, diag in ipairs(diagnostics) do
		local severity = vim.diagnostic.severity[diag.severity] or "UNKNOWN"
		table.insert(diag_text, string.format("Line %d: [%s] %s", diag.lnum + 1, severity, diag.message))
	end

	return {
		diagnostics = diagnostics,
		diagnostics_text = table.concat(diag_text, "\n"),
	}
end

return M
