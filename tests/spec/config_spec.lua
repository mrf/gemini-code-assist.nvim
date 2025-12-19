---@diagnostic disable: undefined-global
-- Tests for gemini.config module

local config = require("gemini.config")

describe("gemini.config", function()
	describe("get_defaults", function()
		it("returns a table", function()
			local defaults = config.get_defaults()
			assert.is_table(defaults)
		end)

		it("returns a copy of defaults, not the original", function()
			local defaults1 = config.get_defaults()
			local defaults2 = config.get_defaults()
			defaults1.auth.api_key = "modified"
			assert.is_nil(defaults2.auth.api_key)
		end)

		it("has expected top-level keys", function()
			local defaults = config.get_defaults()
			assert.is_table(defaults.auth)
			assert.is_table(defaults.model)
			assert.is_table(defaults.suggestion)
			assert.is_table(defaults.chat)
			assert.is_table(defaults.actions)
			assert.is_table(defaults.keymaps)
			assert.is_table(defaults.ui)
			assert.is_table(defaults.log)
		end)

		it("has correct default model values", function()
			local defaults = config.get_defaults()
			assert.equals("gemini-2.0-flash", defaults.model.completion)
			assert.equals("gemini-2.0-flash", defaults.model.chat)
			assert.equals("gemini-2.0-flash", defaults.model.actions)
		end)

		it("has correct default suggestion values", function()
			local defaults = config.get_defaults()
			assert.is_true(defaults.suggestion.enabled)
			assert.is_true(defaults.suggestion.auto_trigger)
			assert.equals(150, defaults.suggestion.debounce_ms)
			assert.equals(256, defaults.suggestion.max_tokens)
		end)

		it("has correct default chat values", function()
			local defaults = config.get_defaults()
			assert.is_true(defaults.chat.enabled)
			assert.equals("floating", defaults.chat.window_type)
			assert.equals(0.6, defaults.chat.width)
			assert.equals(0.8, defaults.chat.height)
		end)

		it("has correct default keymap values", function()
			local defaults = config.get_defaults()
			assert.equals("<Tab>", defaults.keymaps.accept)
			assert.equals("<C-Right>", defaults.keymaps.accept_word)
			assert.equals("<C-]>", defaults.keymaps.dismiss)
		end)
	end)

	describe("setup", function()
		-- Save original env var
		local original_api_key

		before_each(function()
			original_api_key = vim.env.GEMINI_API_KEY
			vim.env.GEMINI_API_KEY = nil
		end)

		after_each(function()
			vim.env.GEMINI_API_KEY = original_api_key
		end)

		it("returns defaults when called with nil", function()
			local result = config.setup(nil)
			assert.is_table(result)
			assert.equals("gemini-2.0-flash", result.model.completion)
		end)

		it("returns defaults when called with empty table", function()
			local result = config.setup({})
			assert.is_table(result)
			assert.is_true(result.suggestion.enabled)
		end)

		it("merges user config with defaults", function()
			local result = config.setup({
				suggestion = {
					debounce_ms = 300,
				},
			})
			-- User override should be applied
			assert.equals(300, result.suggestion.debounce_ms)
			-- Other defaults should remain
			assert.is_true(result.suggestion.enabled)
			assert.equals(256, result.suggestion.max_tokens)
		end)

		it("deep merges nested tables", function()
			local result = config.setup({
				model = {
					completion = "gemini-pro",
				},
				chat = {
					width = 0.8,
				},
			})
			-- User overrides
			assert.equals("gemini-pro", result.model.completion)
			assert.equals(0.8, result.chat.width)
			-- Defaults preserved
			assert.equals("gemini-2.0-flash", result.model.chat)
			assert.equals(0.8, result.chat.height)
		end)

		it("uses api_key from config when provided", function()
			local result = config.setup({
				auth = {
					api_key = "test-key-from-config",
				},
			})
			assert.equals("test-key-from-config", result.auth.api_key)
		end)

		it("falls back to GEMINI_API_KEY env var when not in config", function()
			vim.env.GEMINI_API_KEY = "test-key-from-env"
			local result = config.setup({})
			assert.equals("test-key-from-env", result.auth.api_key)
		end)

		it("prefers config api_key over env var", function()
			vim.env.GEMINI_API_KEY = "env-key"
			local result = config.setup({
				auth = {
					api_key = "config-key",
				},
			})
			assert.equals("config-key", result.auth.api_key)
		end)

		it("can disable features", function()
			local result = config.setup({
				suggestion = { enabled = false },
				chat = { enabled = false },
				actions = { enabled = false },
			})
			assert.is_false(result.suggestion.enabled)
			assert.is_false(result.chat.enabled)
			assert.is_false(result.actions.enabled)
		end)

		it("can disable keymaps", function()
			local result = config.setup({
				keymaps = {
					accept = false,
					dismiss = false,
				},
			})
			assert.is_false(result.keymaps.accept)
			assert.is_false(result.keymaps.dismiss)
			-- Others remain
			assert.equals("<C-Right>", result.keymaps.accept_word)
		end)

		it("preserves exclude patterns when not overridden", function()
			local result = config.setup({})
			assert.is_table(result.exclude)
			assert.equals("*.env", result.exclude[1])
		end)

		it("can override exclude patterns", function()
			local result = config.setup({
				exclude = { "*.custom" },
			})
			-- Note: deep_merge merges arrays by index, so first element is overwritten
			-- but remaining default elements persist
			assert.equals("*.custom", result.exclude[1])
		end)

		it("preserves filetype settings", function()
			local result = config.setup({})
			assert.is_true(result.suggestion.filetypes["*"])
			assert.is_false(result.suggestion.filetypes["gitcommit"])
		end)

		it("can override filetype settings", function()
			local result = config.setup({
				suggestion = {
					filetypes = {
						python = true,
						javascript = false,
					},
				},
			})
			assert.is_true(result.suggestion.filetypes.python)
			assert.is_false(result.suggestion.filetypes.javascript)
		end)
	end)
end)
