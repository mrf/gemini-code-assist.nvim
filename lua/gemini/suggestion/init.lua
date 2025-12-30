---@mod gemini.suggestion Suggestion module
---@brief [[
--- Handles inline code suggestions (ghost text).
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

---@type boolean
M._enabled = true

---@type table?
M._current_suggestion = nil

---@type number
M._suggestion_index = 1

---@type table[]
M._suggestions = {}

---@type boolean Flag to prevent re-triggering during accept
M._accepting = false

--- Setup suggestion module
---@param config GeminiConfig
function M.setup(config)
	M._config = config
	M._enabled = config.suggestion.enabled

	-- Setup autocommands for triggers
	if config.suggestion.auto_trigger then
		M._setup_auto_trigger()
	end

	-- Setup highlights
	require("gemini.ui.highlights").setup(config)
end

--- Setup auto-trigger
function M._setup_auto_trigger()
	local group = vim.api.nvim_create_augroup("GeminiSuggestion", { clear = true })
	local async = require("gemini.util.async")

	local trigger, cancel = async.debounce(function()
		if M._enabled and M._should_trigger() then
			M.trigger()
		end
	end, M._config.suggestion.debounce_ms)

	vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
		group = group,
		callback = function()
			cancel()
			M.dismiss()
			trigger()
		end,
	})

	vim.api.nvim_create_autocmd({ "InsertLeave" }, {
		group = group,
		callback = function()
			cancel()
			M.dismiss()
		end,
	})

	-- Clear ghost text when leaving window/buffer or losing focus
	vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "FocusLost" }, {
		group = group,
		callback = function()
			cancel()
			M.dismiss()
		end,
	})
end

--- Check if suggestion should trigger
---@return boolean
function M._should_trigger()
	-- Don't trigger during accept operation (prevents race condition)
	if M._accepting then
		return false
	end

	local bufnr = vim.api.nvim_get_current_buf()

	-- Check if buffer is modifiable
	if not vim.bo[bufnr].modifiable then
		return false
	end

	-- Check filetype
	local ft = vim.bo[bufnr].filetype
	local filetypes = M._config.suggestion.filetypes

	if filetypes[ft] == false then
		return false
	end

	if filetypes["*"] == false and filetypes[ft] ~= true then
		return false
	end

	-- Check if completion menu is visible
	if M._config.suggestion.hide_during_completion then
		if vim.fn.pumvisible() == 1 then
			return false
		end
	end

	return true
end

--- Trigger a suggestion request
function M.trigger()
	local context = require("gemini.context").build_buffer_context()
	local api = require("gemini.api")

	api.complete(context, function(err, response)
		if err then
			require("gemini.util").log.debug("Suggestion error: %s", err.message or "unknown")
			return
		end

		if response and response.text then
			M._suggestions = { response.text }
			M._suggestion_index = 1
			M._show_suggestion(response.text)
		end
	end)
end

--- Show a suggestion as ghost text
---@param text string
function M._show_suggestion(text)
	local ghost_text = require("gemini.suggestion.ghost_text")
	ghost_text.show(text)
	M._current_suggestion = text
end

--- Check if a suggestion is visible
---@return boolean
function M.is_visible()
	return M._current_suggestion ~= nil
end

--- Accept the current suggestion
function M.accept()
	if not M._current_suggestion then
		return
	end

	-- Prevent re-triggering during the accept operation
	M._accepting = true

	local ghost_text = require("gemini.suggestion.ghost_text")
	ghost_text.accept()
	M._current_suggestion = nil

	-- Clear the flag after debounce period to prevent race condition
	-- with TextChangedI that fires from the text insert
	local debounce_ms = M._config and M._config.suggestion.debounce_ms or 150
	vim.defer_fn(function()
		M._accepting = false
	end, debounce_ms + 50)
end

--- Accept just the next word
function M.accept_word()
	if not M._current_suggestion then
		return
	end

	-- Prevent re-triggering during the accept operation
	M._accepting = true

	local ghost_text = require("gemini.suggestion.ghost_text")
	ghost_text.accept_word()

	-- Clear the flag after debounce period to prevent race condition
	local debounce_ms = M._config and M._config.suggestion.debounce_ms or 150
	vim.defer_fn(function()
		M._accepting = false
	end, debounce_ms + 50)
end

--- Accept just the current line
function M.accept_line()
	if not M._current_suggestion then
		return
	end

	-- Prevent re-triggering during the accept operation
	M._accepting = true

	local ghost_text = require("gemini.suggestion.ghost_text")
	ghost_text.accept_line()

	-- Clear the flag after debounce period to prevent race condition
	local debounce_ms = M._config and M._config.suggestion.debounce_ms or 150
	vim.defer_fn(function()
		M._accepting = false
	end, debounce_ms + 50)
end

--- Dismiss the current suggestion
function M.dismiss()
	if not M._current_suggestion then
		return
	end

	local ghost_text = require("gemini.suggestion.ghost_text")
	ghost_text.clear()
	M._current_suggestion = nil
end

--- Show next suggestion
function M.next()
	if #M._suggestions == 0 then
		return
	end

	M._suggestion_index = M._suggestion_index % #M._suggestions + 1
	M._show_suggestion(M._suggestions[M._suggestion_index])
end

--- Show previous suggestion
function M.prev()
	if #M._suggestions == 0 then
		return
	end

	M._suggestion_index = (M._suggestion_index - 2) % #M._suggestions + 1
	M._show_suggestion(M._suggestions[M._suggestion_index])
end

--- Toggle suggestions
function M.toggle()
	M._enabled = not M._enabled
	if not M._enabled then
		M.dismiss()
	end
	vim.notify("Gemini suggestions: " .. (M._enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

--- Check if suggestions are enabled
---@return boolean
function M.is_enabled()
	return M._enabled
end

return M
