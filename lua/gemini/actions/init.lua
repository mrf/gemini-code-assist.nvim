---@mod gemini.actions Smart actions module
---@brief [[
--- Provides smart code actions like fix, simplify, document, test.
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

--- Setup actions module
---@param config GeminiConfig
function M.setup(config)
	M._config = config
end

--- Get selected text from visual selection marks
---@return string?, number?, number?
local function get_selection()
	-- Get visual selection marks (set when command is run from visual mode)
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	-- Check if marks are valid (line numbers > 0)
	if start_pos[2] == 0 or end_pos[2] == 0 then
		return nil
	end

	-- Check if marks are in current buffer and recent (not stale)
	local start_line = start_pos[2]
	local end_line = end_pos[2]
	local buf_lines = vim.api.nvim_buf_line_count(0)

	if start_line > buf_lines or end_line > buf_lines then
		return nil
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

	if #lines == 0 then
		return nil
	end

	-- Adjust first and last line for character positions
	local start_col = start_pos[3]
	local end_col = end_pos[3]

	if #lines == 1 then
		lines[1] = lines[1]:sub(start_col, end_col)
	else
		lines[1] = lines[1]:sub(start_col)
		lines[#lines] = lines[#lines]:sub(1, end_col)
	end

	local text = table.concat(lines, "\n")

	-- Don't return empty or whitespace-only selections
	if text:match("^%s*$") then
		return nil
	end

	return text, start_line, end_line
end

--- Execute an action
---@param action_type string
---@param prompt_template string
---@param selection string?
local function execute_action(action_type, prompt_template, selection)
	local api = require("gemini.api")
	local context = require("gemini.context").build_buffer_context()

	local code = selection or context.current_line or ""
	local prompt = prompt_template
		:gsub("{{CODE}}", code)
		:gsub("{{LANGUAGE}}", context.filetype or "text")
		:gsub("{{FILENAME}}", context.filename or "unknown")

	vim.notify("Gemini: Processing " .. action_type .. "...", vim.log.levels.INFO)

	api.generate(prompt, {
		model = M._config.model.actions,
		temperature = 0.3,
		max_tokens = 2048,
	}, function(err, response)
		if err then
			vim.notify("Gemini " .. action_type .. " error: " .. (err.message or "unknown"), vim.log.levels.ERROR)
			return
		end

		if response and response.text then
			M._show_result(action_type, response.text, selection ~= nil)
		end
	end)
end

--- Show action result
---@param action_type string
---@param result string
---@param has_selection boolean
function M._show_result(action_type, result, has_selection)
	-- Clean up code blocks from response
	local code = result:match("```%w*\n?(.-)\n?```") or result

	if M._config.actions.preview_diff and has_selection then
		-- Show in floating window for review
		M._show_preview(action_type, code)
	else
		-- Insert/replace directly
		if M._config.actions.auto_apply then
			M._apply_result(code)
		else
			M._show_preview(action_type, code)
		end
	end
end

--- Show preview in floating window
---@param action_type string
---@param code string
function M._show_preview(action_type, code)
	local lines = vim.split(code, "\n")

	local width = math.min(80, vim.o.columns - 4)
	local height = math.min(#lines + 2, vim.o.lines - 4)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Gemini: " .. action_type .. " (y to apply, q to cancel) ",
		title_pos = "center",
	})

	-- Keymaps for the preview
	vim.keymap.set("n", "y", function()
		vim.api.nvim_win_close(win, true)
		M._apply_result(code)
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

--- Apply result to buffer
---@param code string
function M._apply_result(code)
	local lines = vim.split(code, "\n")
	vim.api.nvim_put(lines, "l", true, true)
	vim.notify("Gemini: Applied changes", vim.log.levels.INFO)
end

--- Generate code from description
---@param description string?
function M.generate(description)
	if not description or description == "" then
		vim.ui.input({ prompt = "Describe code to generate: " }, function(input)
			if input and input ~= "" then
				M.generate(input)
			end
		end)
		return
	end

	local prompt = [[
Generate code based on this description:

Description: ]] .. description .. [[

Language: {{LANGUAGE}}
File: {{FILENAME}}

Provide only the code, no explanations.
]]

	execute_action("generate", prompt, nil)
end

--- Fix issues in code
function M.fix()
	local selection = get_selection()
	if not selection then
		vim.notify("Gemini: Please select code to fix", vim.log.levels.WARN)
		return
	end

	local prompt = [[
Fix any issues in this code. Correct bugs, errors, and potential problems.

Language: {{LANGUAGE}}

```
{{CODE}}
```

Provide the fixed code only, no explanations.
]]

	execute_action("fix", prompt, selection)
end

--- Simplify/refactor code
function M.simplify()
	local selection = get_selection()
	if not selection then
		vim.notify("Gemini: Please select code to simplify", vim.log.levels.WARN)
		return
	end

	local prompt = [[
Simplify and refactor this code. Make it more readable, efficient, and maintainable.

Language: {{LANGUAGE}}

```
{{CODE}}
```

Provide the simplified code only, no explanations.
]]

	execute_action("simplify", prompt, selection)
end

--- Add documentation to code
function M.document()
	local selection = get_selection()
	if not selection then
		vim.notify("Gemini: Please select code to document", vim.log.levels.WARN)
		return
	end

	local prompt = [[
Add comprehensive documentation to this code. Include docstrings, comments for complex logic, and type annotations where appropriate.

Language: {{LANGUAGE}}

```
{{CODE}}
```

Provide the documented code only.
]]

	execute_action("document", prompt, selection)
end

--- Generate unit tests
function M.test()
	local selection = get_selection()
	if not selection then
		vim.notify("Gemini: Please select code to test", vim.log.levels.WARN)
		return
	end

	local prompt = [[
Generate comprehensive unit tests for this code. Cover edge cases, error conditions, and typical usage.

Language: {{LANGUAGE}}

```
{{CODE}}
```

Provide only the test code.
]]

	execute_action("test", prompt, selection)
end

--- Explain code
function M.explain()
	local selection = get_selection()
	if not selection then
		vim.notify("Gemini: Please select code to explain", vim.log.levels.WARN)
		return
	end

	local prompt = [[
Explain this code in detail. Describe what it does, how it works, and any important considerations.

Language: {{LANGUAGE}}

```
{{CODE}}
```
]]

	local api = require("gemini.api")

	api.generate(prompt, {
		model = M._config.model.actions,
		temperature = 0.5,
		max_tokens = 2048,
	}, function(err, response)
		if err then
			vim.notify("Gemini explain error: " .. (err.message or "unknown"), vim.log.levels.ERROR)
			return
		end

		if response and response.text then
			-- Show explanation in floating window
			M._show_explanation(response.text)
		end
	end)
end

--- Show explanation in floating window
---@param text string
function M._show_explanation(text)
	local lines = vim.split(text, "\n")

	local width = math.min(100, vim.o.columns - 4)
	local height = math.min(#lines + 2, vim.o.lines - 4)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Gemini: Explanation ",
		title_pos = "center",
	})

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

return M
