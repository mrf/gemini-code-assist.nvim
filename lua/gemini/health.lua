---@mod gemini.health Health check module
---@brief [[
--- Provides :checkhealth support for the plugin.
---@brief ]]

local M = {}

--- Run health check
function M.check()
	vim.health.start("Gemini Code Assist")

	-- Check Neovim version
	if vim.fn.has("nvim-0.10") == 1 then
		vim.health.ok("Neovim version >= 0.10.0")
	else
		vim.health.error("Neovim version >= 0.10.0 required")
	end

	-- Check for curl
	if vim.fn.executable("curl") == 1 then
		vim.health.ok("curl is available")
	else
		vim.health.error("curl is required for API requests")
	end

	-- Check for plenary
	local has_plenary, _ = pcall(require, "plenary")
	if has_plenary then
		vim.health.ok("plenary.nvim is installed")
	else
		vim.health.error("plenary.nvim is required", {
			"Install with your package manager",
			"e.g., { 'nvim-lua/plenary.nvim' }",
		})
	end

	-- Check plugin initialization
	local gemini = require("gemini")
	if gemini.is_initialized() then
		vim.health.ok("Plugin is initialized")
	else
		vim.health.warn("Plugin is not initialized", {
			"Call require('gemini').setup() in your config",
		})
	end

	-- Check authentication
	local auth = require("gemini.auth")
	local config = gemini.get_config()

	-- Check for Gemini CLI
	if vim.fn.executable("gemini") == 1 then
		vim.health.ok("Gemini CLI is installed (can use 'gemini login' for OAuth)")
	else
		vim.health.info("Gemini CLI not found (optional - enables OAuth login)")
	end

	-- Check credentials
	local auth_type = auth.get_auth_type()

	if auth_type == "api_key" then
		vim.health.ok("Authenticated with API key")
	elseif auth_type == "oauth" then
		vim.health.ok("Authenticated with Gemini CLI OAuth (~/.gemini/oauth_creds.json)")
	elseif config.auth and config.auth.api_key then
		vim.health.ok("API key configured in setup()")
	elseif vim.env.GEMINI_API_KEY then
		vim.health.ok("API key found in GEMINI_API_KEY environment variable")
	elseif vim.fn.filereadable(vim.fn.expand("~/.gemini/oauth_creds.json")) == 1 then
		vim.health.warn("Gemini CLI OAuth file found but may be expired", {
			"Run 'gemini login' to refresh credentials",
		})
	else
		vim.health.warn("No authentication configured", {
			"Option 1: Set GEMINI_API_KEY environment variable",
			"Option 2: Run 'gemini login' (if Gemini CLI installed)",
			"Option 3: Provide api_key in setup({ auth = { api_key = '...' } })",
			"Get a free API key at https://aistudio.google.com/apikey",
		})
	end

	if auth.is_authenticated() then
		vim.health.ok("Authentication is valid")
	end

	-- Check optional dependencies
	local has_cmp, _ = pcall(require, "cmp")
	if has_cmp then
		vim.health.ok("nvim-cmp is available (optional)")
	else
		vim.health.info("nvim-cmp not found (optional for completion menu integration)")
	end

	local has_treesitter, _ = pcall(require, "nvim-treesitter")
	if has_treesitter then
		vim.health.ok("nvim-treesitter is available (optional)")
	else
		vim.health.info("nvim-treesitter not found (optional for enhanced context)")
	end
end

return M
