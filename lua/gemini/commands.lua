---@mod gemini.commands User commands
---@brief [[
--- Registers all user commands for the plugin.
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

--- Setup user commands
---@param config GeminiConfig
function M.setup(config)
	M._config = config

	-- Authentication command
	vim.api.nvim_create_user_command("GeminiAuth", function()
		require("gemini.auth").authenticate()
	end, { desc = "Authenticate with Google" })

	-- Toggle suggestions
	vim.api.nvim_create_user_command("GeminiToggle", function()
		require("gemini.suggestion").toggle()
	end, { desc = "Toggle Gemini suggestions" })

	-- Chat commands
	vim.api.nvim_create_user_command("GeminiChat", function()
		require("gemini.chat").toggle()
	end, { desc = "Open Gemini chat" })

	-- Smart action commands
	vim.api.nvim_create_user_command("GeminiGenerate", function(opts)
		require("gemini.actions").generate(opts.args)
	end, { desc = "Generate code from description", nargs = "?" })

	vim.api.nvim_create_user_command("GeminiFix", function()
		require("gemini.actions").fix()
	end, { desc = "Fix selected code", range = true })

	vim.api.nvim_create_user_command("GeminiSimplify", function()
		require("gemini.actions").simplify()
	end, { desc = "Simplify selected code", range = true })

	vim.api.nvim_create_user_command("GeminiDocument", function()
		require("gemini.actions").document()
	end, { desc = "Add documentation to selected code", range = true })

	vim.api.nvim_create_user_command("GeminiTest", function()
		require("gemini.actions").test()
	end, { desc = "Generate unit tests for selected code", range = true })

	vim.api.nvim_create_user_command("GeminiExplain", function()
		require("gemini.actions").explain()
	end, { desc = "Explain selected code", range = true })

	-- Status and logging
	vim.api.nvim_create_user_command("GeminiStatus", function()
		M.show_status()
	end, { desc = "Show Gemini status" })

	vim.api.nvim_create_user_command("GeminiLog", function()
		M.open_log()
	end, { desc = "Open Gemini log file" })
end

--- Show plugin status
function M.show_status()
	local gemini = require("gemini")
	local auth = require("gemini.auth")

	local lines = {
		"Gemini Code Assist Status",
		string.rep("-", 40),
		"",
		"Initialized: " .. tostring(gemini.is_initialized()),
		"Authenticated: " .. tostring(auth.is_authenticated()),
		"",
		"Configuration:",
		"  Auth method: " .. (auth.get_auth_type() or "not set"),
		"  Completion model: " .. (M._config.model.completion or "not set"),
		"  Suggestions enabled: " .. tostring(M._config.suggestion.enabled),
		"  Chat enabled: " .. tostring(M._config.chat.enabled),
		"  Actions enabled: " .. tostring(M._config.actions.enabled),
	}

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- Open log file
function M.open_log()
	if M._config.log.file then
		vim.cmd.edit(M._config.log.file)
	else
		vim.notify("No log file configured", vim.log.levels.WARN)
	end
end

return M
