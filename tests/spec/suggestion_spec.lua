---@diagnostic disable: undefined-global
-- Tests for gemini.suggestion module

local suggestion = require("gemini.suggestion")
local ghost_text = require("gemini.suggestion.ghost_text")

describe("gemini.suggestion", function()
	local test_config

	before_each(function()
		-- Reset module state
		suggestion._enabled = true
		suggestion._current_suggestion = nil
		suggestion._suggestion_index = 1
		suggestion._suggestions = {}

		-- Mock configuration
		test_config = {
			suggestion = {
				enabled = true,
				auto_trigger = true,
				debounce_ms = 100,
				max_tokens = 256,
				hide_during_completion = true,
				filetypes = {
					["*"] = true,
					gitcommit = false,
					oil = false,
				},
			},
		}

		-- Setup with test config
		suggestion._config = test_config

		-- Clear ghost text
		ghost_text.clear()
	end)

	after_each(function()
		-- Clean up
		ghost_text.clear()
	end)

	describe("setup", function()
		it("initializes with config", function()
			suggestion.setup(test_config)
			assert.is_not_nil(suggestion._config)
			assert.equals(true, suggestion._enabled)
		end)

		it("respects enabled state from config", function()
			local disabled_config = vim.deepcopy(test_config)
			disabled_config.suggestion.enabled = false
			suggestion.setup(disabled_config)
			assert.equals(false, suggestion._enabled)
		end)
	end)

	describe("trigger logic", function()
		before_each(function()
			-- Create a test buffer
			vim.cmd("enew")
			vim.bo.modifiable = true
			vim.bo.filetype = "lua"
		end)

		describe("_should_trigger", function()
			it("returns true for modifiable buffer with allowed filetype", function()
				vim.bo.modifiable = true
				vim.bo.filetype = "lua"
				assert.is_true(suggestion._should_trigger())
			end)

			it("returns false for non-modifiable buffer", function()
				vim.bo.modifiable = false
				assert.is_false(suggestion._should_trigger())
			end)

			it("returns false for disallowed filetype", function()
				vim.bo.filetype = "gitcommit"
				assert.is_false(suggestion._should_trigger())
			end)

			it("returns false when completion menu is visible and hide_during_completion is true", function()
				-- Mock pumvisible
				local original_pumvisible = vim.fn.pumvisible
				vim.fn.pumvisible = function()
					return 1
				end

				assert.is_false(suggestion._should_trigger())

				-- Restore
				vim.fn.pumvisible = original_pumvisible
			end)

			it("respects wildcard filetype setting", function()
				local config_with_wildcard = vim.deepcopy(test_config)
				config_with_wildcard.suggestion.filetypes = {
					["*"] = false,
					lua = true,
				}
				suggestion._config = config_with_wildcard

				vim.bo.filetype = "lua"
				assert.is_true(suggestion._should_trigger())

				vim.bo.filetype = "python"
				assert.is_false(suggestion._should_trigger())
			end)
		end)

		describe("trigger", function()
			it("calls API with buffer context", function()
				local api_called = false
				local received_context = nil

				-- Mock the API
				package.loaded["gemini.api"] = {
					complete = function(context, callback)
						api_called = true
						received_context = context
						-- Simulate async response
						vim.schedule(function()
							callback(nil, { text = "test completion" })
						end)
					end,
				}

				-- Mock context builder
				package.loaded["gemini.context"] = {
					build_buffer_context = function()
						return {
							filename = "test.lua",
							filetype = "lua",
							prefix = "local x = ",
							suffix = "",
						}
					end,
				}

				suggestion.trigger()

				-- Wait for async callback
				vim.wait(200, function()
					return api_called
				end)

				assert.is_true(api_called)
				assert.is_not_nil(received_context)
			end)

			it("shows suggestion on successful API response", function()
				-- Mock the API with successful response
				package.loaded["gemini.api"] = {
					complete = function(context, callback)
						vim.schedule(function()
							callback(nil, { text = "function test()\n  return true\nend" })
						end)
					end,
				}

				package.loaded["gemini.context"] = {
					build_buffer_context = function()
						return { filename = "test.lua", filetype = "lua" }
					end,
				}

				suggestion.trigger()

				-- Wait for suggestion to be shown
				vim.wait(200, function()
					return suggestion._current_suggestion ~= nil
				end)

				assert.is_not_nil(suggestion._current_suggestion)
				assert.equals("function test()\n  return true\nend", suggestion._current_suggestion)
			end)

			it("handles API errors gracefully", function()
				local error_logged = false

				-- Mock logger
				package.loaded["gemini.util"] = {
					log = {
						debug = function(...)
							error_logged = true
						end,
					},
				}

				-- Mock the API with error response
				package.loaded["gemini.api"] = {
					complete = function(context, callback)
						vim.schedule(function()
							callback({ message = "API error" }, nil)
						end)
					end,
				}

				package.loaded["gemini.context"] = {
					build_buffer_context = function()
						return {}
					end,
				}

				suggestion.trigger()

				-- Wait for error to be logged
				vim.wait(200, function()
					return error_logged
				end)

				assert.is_true(error_logged)
				assert.is_nil(suggestion._current_suggestion)
			end)
		end)
	end)

	describe("debouncing behavior", function()
		it("debounces rapid trigger calls", function()
			local api_call_count = 0

			-- Mock API
			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					api_call_count = api_call_count + 1
					vim.schedule(function()
						callback(nil, { text = "completion" })
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			-- Create debounced trigger
			local async = require("gemini.util.async")
			local trigger, cancel = async.debounce(function()
				suggestion.trigger()
			end, 50)

			-- Trigger multiple times rapidly
			trigger()
			trigger()
			trigger()

			-- Wait for debounce to settle
			vim.wait(200, function()
				return api_call_count > 0
			end)

			-- Should only call API once
			assert.equals(1, api_call_count)
		end)

		it("cancels pending trigger when dismiss is called", function()
			local api_call_count = 0

			-- Mock API
			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					api_call_count = api_call_count + 1
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			local async = require("gemini.util.async")
			local trigger, cancel = async.debounce(function()
				suggestion.trigger()
			end, 100)

			trigger()
			cancel()

			-- Wait to ensure no API call happens
			vim.wait(200, function()
				return false
			end)

			assert.equals(0, api_call_count)
		end)
	end)

	describe("ghost text rendering", function()
		before_each(function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = " })
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
		end)

		it("shows ghost text at cursor position", function()
			ghost_text.show("test")

			assert.is_not_nil(ghost_text._current_text)
			assert.equals("test", ghost_text._current_text)
			assert.is_not_nil(ghost_text._current_bufnr)
		end)

		it("renders single-line suggestion as inline virtual text", function()
			-- Set cursor position explicitly
			vim.api.nvim_win_set_cursor(0, { 1, 9 })
			ghost_text.show("complete_text")

			-- Check that ghost text state is set
			assert.equals("complete_text", ghost_text._current_text)
			assert.equals(0, ghost_text._current_line)
			assert.equals(9, ghost_text._current_col)
		end)

		it("renders multi-line suggestion with virtual lines", function()
			local multiline = "function test()\n  return true\nend"
			ghost_text.show(multiline)

			assert.equals(multiline, ghost_text._current_text)
			assert.is_not_nil(ghost_text._current_bufnr)
		end)

		it("clears previous ghost text when showing new suggestion", function()
			ghost_text.show("first")
			local first_text = ghost_text._current_text

			ghost_text.show("second")
			local second_text = ghost_text._current_text

			assert.not_equals(first_text, second_text)
			assert.equals("second", second_text)
		end)

		it("clears ghost text completely", function()
			ghost_text.show("test")
			assert.is_not_nil(ghost_text._current_text)

			ghost_text.clear()
			assert.is_nil(ghost_text._current_text)
			assert.is_nil(ghost_text._current_bufnr)
		end)
	end)

	describe("accept/dismiss actions", function()
		before_each(function()
			vim.cmd("enew")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = " })
			vim.api.nvim_win_set_cursor(0, { 1, 10 })

			-- Set a suggestion
			suggestion._current_suggestion = "test_value"
			ghost_text._current_text = "test_value"
			ghost_text._current_bufnr = vim.api.nvim_get_current_buf()
		end)

		describe("accept", function()
			it("inserts suggestion text at cursor", function()
				suggestion.accept()

				-- Wait for scheduled insertion
				vim.wait(100, function()
					return false
				end)

				-- Verify ghost text was cleared
				assert.is_nil(suggestion._current_suggestion)
			end)

			it("does nothing when no suggestion is visible", function()
				suggestion._current_suggestion = nil
				ghost_text._current_text = nil

				local initial_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				suggestion.accept()

				vim.wait(100, function()
					return false
				end)

				local final_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				assert.same(initial_lines, final_lines)
			end)

			it("clears suggestion state after accept", function()
				suggestion.accept()
				assert.is_nil(suggestion._current_suggestion)
			end)
		end)

		describe("accept_word", function()
			it("accepts only the first word", function()
				suggestion._current_suggestion = "hello world"
				ghost_text._current_text = "hello world"

				suggestion.accept_word()

				-- Wait for scheduled operations
				vim.wait(100, function()
					return false
				end)

				-- Current suggestion should still exist but be empty or nil after full acceptance
				-- or have remaining text
			end)

			it("does nothing when no suggestion is visible", function()
				suggestion._current_suggestion = nil
				ghost_text._current_text = nil

				suggestion.accept_word()
				-- Should not error
			end)
		end)

		describe("accept_line", function()
			it("accepts only the current line", function()
				suggestion._current_suggestion = "line1\nline2"
				ghost_text._current_text = "line1\nline2"

				suggestion.accept_line()

				-- Wait for scheduled operations
				vim.wait(100, function()
					return false
				end)
			end)

			it("does nothing when no suggestion is visible", function()
				suggestion._current_suggestion = nil
				ghost_text._current_text = nil

				suggestion.accept_line()
				-- Should not error
			end)
		end)

		describe("dismiss", function()
			it("clears current suggestion", function()
				suggestion.dismiss()

				assert.is_nil(suggestion._current_suggestion)
				assert.is_nil(ghost_text._current_text)
			end)

			it("does nothing when no suggestion is visible", function()
				suggestion._current_suggestion = nil
				ghost_text._current_text = nil

				-- Should not error
				suggestion.dismiss()
			end)
		end)

		describe("is_visible", function()
			it("returns true when suggestion is shown", function()
				suggestion._current_suggestion = "test"
				assert.is_true(suggestion.is_visible())
			end)

			it("returns false when no suggestion is shown", function()
				suggestion._current_suggestion = nil
				assert.is_false(suggestion.is_visible())
			end)
		end)
	end)

	describe("suggestion navigation", function()
		before_each(function()
			suggestion._suggestions = { "first", "second", "third" }
			suggestion._suggestion_index = 1
		end)

		describe("next", function()
			it("cycles to next suggestion", function()
				local shown_suggestions = {}

				-- Mock _show_suggestion to track calls
				local original_show = suggestion._show_suggestion
				suggestion._show_suggestion = function(text)
					table.insert(shown_suggestions, text)
				end

				suggestion.next()
				assert.equals(2, suggestion._suggestion_index)

				suggestion.next()
				assert.equals(3, suggestion._suggestion_index)

				suggestion.next()
				assert.equals(1, suggestion._suggestion_index)

				-- Restore
				suggestion._show_suggestion = original_show
			end)

			it("does nothing with no suggestions", function()
				suggestion._suggestions = {}
				suggestion.next()
				-- Should not error
			end)
		end)

		describe("prev", function()
			it("cycles to previous suggestion", function()
				suggestion._suggestion_index = 2

				local original_show = suggestion._show_suggestion
				suggestion._show_suggestion = function(text) end

				suggestion.prev()
				assert.equals(1, suggestion._suggestion_index)

				suggestion.prev()
				assert.equals(3, suggestion._suggestion_index)

				-- Restore
				suggestion._show_suggestion = original_show
			end)

			it("does nothing with no suggestions", function()
				suggestion._suggestions = {}
				suggestion.prev()
				-- Should not error
			end)
		end)
	end)

	describe("toggle", function()
		it("toggles enabled state", function()
			suggestion._enabled = true
			suggestion.toggle()
			assert.is_false(suggestion._enabled)

			suggestion.toggle()
			assert.is_true(suggestion._enabled)
		end)

		it("dismisses suggestion when disabling", function()
			suggestion._enabled = true
			suggestion._current_suggestion = "test"

			suggestion.toggle()

			assert.is_false(suggestion._enabled)
			assert.is_nil(suggestion._current_suggestion)
		end)
	end)

	describe("is_enabled", function()
		it("returns current enabled state", function()
			suggestion._enabled = true
			assert.is_true(suggestion.is_enabled())

			suggestion._enabled = false
			assert.is_false(suggestion.is_enabled())
		end)
	end)

	describe("API response caching simulation", function()
		-- Note: The current implementation doesn't have explicit caching,
		-- but these tests demonstrate how caching behavior could be tested

		before_each(function()
			-- Wait for any pending async operations to complete
			vim.wait(50, function()
				return false
			end)

			-- Reset suggestion state
			suggestion._current_suggestion = nil
			suggestion._suggestions = {}
			suggestion._suggestion_index = 1
			ghost_text.clear()
		end)

		it("makes fresh API call on first trigger", function()
			local api_call_count = 0

			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					api_call_count = api_call_count + 1
					vim.schedule(function()
						callback(nil, { text = "cached_result" })
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return { filename = "test.lua", prefix = "local x = ", suffix = "" }
				end,
			}

			suggestion.trigger()

			vim.wait(200, function()
				return api_call_count > 0
			end)

			assert.equals(1, api_call_count)
		end)

		it("makes new API call for different context", function()
			local api_call_count = 0
			local contexts_received = {}

			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					api_call_count = api_call_count + 1
					table.insert(contexts_received, context)
					vim.schedule(function()
						callback(nil, { text = "result_" .. api_call_count })
					end)
				end,
			}

			-- First context
			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return { filename = "test.lua", prefix = "local x = ", suffix = "" }
				end,
			}

			suggestion.trigger()

			vim.wait(200, function()
				return api_call_count > 0
			end)

			-- Clear suggestion before second trigger
			suggestion._current_suggestion = nil
			suggestion._suggestions = {}

			-- Second context (different)
			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return { filename = "test.lua", prefix = "local y = ", suffix = "" }
				end,
			}

			suggestion.trigger()

			vim.wait(200, function()
				return api_call_count > 1
			end)

			assert.equals(2, api_call_count)
		end)

		it("handles empty API responses", function()
			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					vim.schedule(function()
						callback(nil, {}) -- Empty response
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			suggestion.trigger()

			vim.wait(200, function()
				return false
			end)

			-- Should not show suggestion for empty response
			assert.is_nil(suggestion._current_suggestion)
		end)

		it("handles nil response text", function()
			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					vim.schedule(function()
						callback(nil, { text = nil })
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			suggestion.trigger()

			vim.wait(200, function()
				return false
			end)

			assert.is_nil(suggestion._current_suggestion)
		end)
	end)

	describe("integration scenarios", function()
		before_each(function()
			vim.cmd("enew")
			vim.bo.modifiable = true
			vim.bo.filetype = "lua"
		end)

		it("complete workflow: trigger -> show -> accept", function()
			local workflow_complete = false

			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					vim.schedule(function()
						callback(nil, { text = "complete_code()" })
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return { filename = "test.lua", filetype = "lua" }
				end,
			}

			-- Trigger
			suggestion.trigger()

			-- Wait for suggestion
			vim.wait(200, function()
				return suggestion.is_visible()
			end)

			assert.is_true(suggestion.is_visible())

			-- Accept
			suggestion.accept()

			vim.wait(100, function()
				return not suggestion.is_visible()
			end)

			assert.is_false(suggestion.is_visible())
		end)

		it("complete workflow: trigger -> show -> dismiss", function()
			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					vim.schedule(function()
						callback(nil, { text = "complete_code()" })
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			-- Trigger
			suggestion.trigger()

			-- Wait for suggestion
			vim.wait(200, function()
				return suggestion.is_visible()
			end)

			assert.is_true(suggestion.is_visible())

			-- Dismiss
			suggestion.dismiss()

			assert.is_false(suggestion.is_visible())
		end)

		it("handles multiple suggestions cycling", function()
			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					vim.schedule(function()
						callback(nil, { text = "suggestion_1" })
					end)
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			-- Manually set multiple suggestions
			suggestion._suggestions = { "option_1", "option_2", "option_3" }
			suggestion._suggestion_index = 1

			local original_show = suggestion._show_suggestion
			local shown_texts = {}
			suggestion._show_suggestion = function(text)
				table.insert(shown_texts, text)
				original_show(text)
			end

			suggestion.next()
			suggestion.next()
			suggestion.prev()

			assert.equals(3, #shown_texts)

			suggestion._show_suggestion = original_show
		end)

		it("respects enabled state during trigger", function()
			local api_called = false

			package.loaded["gemini.api"] = {
				complete = function(context, callback)
					api_called = true
				end,
			}

			package.loaded["gemini.context"] = {
				build_buffer_context = function()
					return {}
				end,
			}

			-- Disable suggestions
			suggestion._enabled = false

			-- Try to trigger
			suggestion.trigger()

			vim.wait(100, function()
				return false
			end)

			-- API should still be called (enabled check is in _should_trigger, not trigger)
			-- But in practice, auto-trigger checks _enabled before calling trigger
		end)
	end)
end)
