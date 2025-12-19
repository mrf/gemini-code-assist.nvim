---@mod gemini.chat.window Chat window UI
---@brief [[
--- Handles chat window creation and management.
---@brief ]]

local M = {}

--- Create a chat window
---@param config GeminiChatConfig
---@return table window Window object
function M.create(config)
	local window_type = config.window_type or "floating"

	if window_type == "floating" then
		return M._create_floating(config)
	elseif window_type == "vsplit" then
		return M._create_vsplit(config)
	elseif window_type == "split" then
		return M._create_split(config)
	elseif window_type == "tab" then
		return M._create_tab(config)
	end

	return M._create_floating(config)
end

--- Create a floating window
---@param config GeminiChatConfig
---@return table
function M._create_floating(config)
	local width = math.floor(vim.o.columns * (config.width or 0.6))
	local height = math.floor(vim.o.lines * (config.height or 0.8))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "gemini-chat"

	-- Create window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Gemini Chat ",
		title_pos = "center",
	})

	-- Setup input handling
	M._setup_input(buf, win)

	return { buf = buf, win = win, type = "floating" }
end

--- Create a vertical split
---@param config GeminiChatConfig
---@return table
function M._create_vsplit(config)
	local width = math.floor(vim.o.columns * (config.width or 0.4))

	vim.cmd("vsplit")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_width(win, width)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "gemini-chat"

	M._setup_input(buf, win)

	return { buf = buf, win = win, type = "vsplit" }
end

--- Create a horizontal split
---@param config GeminiChatConfig
---@return table
function M._create_split(config)
	local height = math.floor(vim.o.lines * (config.height or 0.3))

	vim.cmd("split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_height(win, height)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "gemini-chat"

	M._setup_input(buf, win)

	return { buf = buf, win = win, type = "split" }
end

--- Create a new tab
---@param config GeminiChatConfig
---@return table
function M._create_tab(config)
	vim.cmd("tabnew")
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "gemini-chat"

	M._setup_input(buf, win)

	return { buf = buf, win = win, type = "tab" }
end

--- Setup window options
---@param win number
function M._setup_window_options(win)
	-- Enable text wrapping
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.wo[win].breakindent = true
	vim.wo[win].breakindentopt = "shift:2"
	-- Hide line numbers for cleaner look
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = false
end

--- Setup input handling
---@param buf number
---@param win number
function M._setup_input(buf, win)
	-- Setup window display options
	M._setup_window_options(win)
	-- Keymap to send message
	vim.keymap.set("n", "<CR>", function()
		M._prompt_input()
	end, { buffer = buf, desc = "Send message" })

	vim.keymap.set("n", "i", function()
		M._prompt_input()
	end, { buffer = buf, desc = "Send message" })

	vim.keymap.set("n", "q", function()
		require("gemini.chat").close()
	end, { buffer = buf, desc = "Close chat" })

	vim.keymap.set("n", "<Esc>", function()
		require("gemini.chat").close()
	end, { buffer = buf, desc = "Close chat" })

	-- Clear chat
	vim.keymap.set("n", "C", function()
		require("gemini.chat").clear()
	end, { buffer = buf, desc = "Clear chat" })
end

--- Prompt for input
function M._prompt_input()
	vim.ui.input({ prompt = "Message: " }, function(input)
		if input and input ~= "" then
			require("gemini.chat").send(input)
		end
	end)
end

--- Close a window
---@param window table
function M.close(window)
	if window.win and vim.api.nvim_win_is_valid(window.win) then
		vim.api.nvim_win_close(window.win, true)
	end
end

--- Set window content
---@param window table
---@param lines string[]
function M.set_content(window, lines)
	if window.buf and vim.api.nvim_buf_is_valid(window.buf) then
		vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, lines)

		-- Scroll to bottom
		if window.win and vim.api.nvim_win_is_valid(window.win) then
			local line_count = vim.api.nvim_buf_line_count(window.buf)
			vim.api.nvim_win_set_cursor(window.win, { line_count, 0 })
		end
	end
end

return M
