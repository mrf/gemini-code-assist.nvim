---@diagnostic disable: undefined-global
-- Tests for gemini.context module
-- Tests cover: buffer extraction, workspace detection, LSP integration, treesitter parsing

local context = require("gemini.context")
local path = require("gemini.util.path")

describe("gemini.context", function()
	-- Helper function to create a test buffer with content
	local function create_test_buffer(lines, filetype)
		filetype = filetype or "lua"
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(bufnr, "filetype", filetype)
		return bufnr
	end

	-- Helper to set buffer as current and position cursor
	local function set_current_buffer_and_cursor(bufnr, line, col)
		-- Create a window for the buffer
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, bufnr)
		vim.api.nvim_win_set_cursor(win, { line, col })
	end

	describe("build_buffer_context", function()
		local test_bufnr

		after_each(function()
			-- Clean up test buffer
			if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
				vim.api.nvim_buf_delete(test_bufnr, { force = true })
			end
		end)

		it("extracts basic buffer information", function()
			local lines = {
				"local function test()",
				"  return 42",
				"end",
			}
			test_bufnr = create_test_buffer(lines, "lua")
			set_current_buffer_and_cursor(test_bufnr, 2, 10)

			local ctx = context.build_buffer_context()

			assert.is_table(ctx)
			assert.equals(test_bufnr, ctx.bufnr)
			assert.equals("lua", ctx.filetype)
			assert.equals(2, ctx.line)
			assert.equals(10, ctx.col)
			assert.equals(3, ctx.total_lines)
		end)

		it("extracts filename", function()
			local lines = { "test content" }
			test_bufnr = create_test_buffer(lines)
			vim.api.nvim_buf_set_name(test_bufnr, "/tmp/test.lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_buffer_context()

			assert.equals("/tmp/test.lua", ctx.filename)
		end)

		it("splits buffer into prefix and suffix at cursor", function()
			local lines = {
				"line 1",
				"line 2 middle",
				"line 3",
			}
			test_bufnr = create_test_buffer(lines)
			-- Position cursor at line 2, column 7 (after "line 2 ")
			set_current_buffer_and_cursor(test_bufnr, 2, 7)

			local ctx = context.build_buffer_context()

			-- Prefix should include line 1 and up to cursor on line 2
			local expected_prefix = "line 1\nline 2 "
			assert.equals(expected_prefix, ctx.prefix)

			-- Suffix should include rest of line 2 and line 3
			local expected_suffix = "middle\nline 3"
			assert.equals(expected_suffix, ctx.suffix)
		end)

		it("handles cursor at start of buffer", function()
			local lines = { "first line", "second line" }
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_buffer_context()

			assert.equals("", ctx.prefix)
			assert.equals("first line\nsecond line", ctx.suffix)
		end)

		it("handles cursor at end of buffer", function()
			local lines = { "first line", "second line" }
			test_bufnr = create_test_buffer(lines)
			-- "second line" has 11 characters, so column 10 is at the last 'e'
			-- Column is 0-indexed, so column 10 means we're after the 11th character
			set_current_buffer_and_cursor(test_bufnr, 2, 10)

			local ctx = context.build_buffer_context()

			-- Column 10 on "second line" (0-indexed) means after char index 10
			-- which is at the 'e' in "line"
			assert.is_true(ctx.prefix:find("second lin") ~= nil)
		end)

		it("handles empty buffer", function()
			test_bufnr = create_test_buffer({})
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_buffer_context()

			assert.equals("", ctx.prefix)
			assert.equals("", ctx.suffix)
			assert.equals("", ctx.current_line)
			-- Empty buffer still has 1 empty line in nvim
			assert.is_true(ctx.total_lines >= 0)
		end)

		it("extracts current line correctly", function()
			local lines = {
				"first",
				"current line content",
				"third",
			}
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 2, 5)

			local ctx = context.build_buffer_context()

			assert.equals("current line content", ctx.current_line)
		end)

		it("handles different filetypes", function()
			local test_cases = {
				{ filetype = "python", expected = "python" },
				{ filetype = "javascript", expected = "javascript" },
				{ filetype = "rust", expected = "rust" },
				{ filetype = "", expected = "" },
			}

			for _, tc in ipairs(test_cases) do
				test_bufnr = create_test_buffer({ "test" }, tc.filetype)
				set_current_buffer_and_cursor(test_bufnr, 1, 0)

				local ctx = context.build_buffer_context()

				assert.equals(tc.expected, ctx.filetype)

				-- Clean up for next iteration
				vim.api.nvim_buf_delete(test_bufnr, { force = true })
			end
		end)

		it("handles multi-line prefix correctly", function()
			local lines = {
				"function test()",
				"  local x = 1",
				"  local y = 2",
				"  return x + y",
				"end",
			}
			test_bufnr = create_test_buffer(lines)
			-- Position at line 3, after "  local y = " (column 12, 0-indexed)
			set_current_buffer_and_cursor(test_bufnr, 3, 12)

			local ctx = context.build_buffer_context()

			local expected_prefix = "function test()\n  local x = 1\n  local y = "
			assert.equals(expected_prefix, ctx.prefix)
		end)

		it("handles multi-line suffix correctly", function()
			local lines = {
				"function test()",
				"  local x = 1",
				"  local y = 2",
				"  return x + y",
				"end",
			}
			test_bufnr = create_test_buffer(lines)
			-- Position after "  loca" on line 2 (column 6, 0-indexed)
			-- "  local x = 1" -> column 6 is after "  loca"
			set_current_buffer_and_cursor(test_bufnr, 2, 6)

			local ctx = context.build_buffer_context()

			local expected_suffix = "l x = 1\n  local y = 2\n  return x + y\nend"
			assert.equals(expected_suffix, ctx.suffix)
		end)
	end)

	describe("build_workspace_context", function()
		-- Mock vim.lsp.get_clients to avoid API compatibility issues
		local original_get_clients
		before_each(function()
			if vim.lsp and vim.lsp.get_clients then
				original_get_clients = vim.lsp.get_clients
			end
			-- Mock it to return empty array (fallback to marker detection)
			vim.lsp.get_clients = function()
				return {}
			end
		end)

		after_each(function()
			if original_get_clients then
				vim.lsp.get_clients = original_get_clients
			end
		end)

		it("returns a table with root field", function()
			local ctx = context.build_workspace_context()

			assert.is_table(ctx)
			assert.is_not_nil(ctx.root)
			assert.is_string(ctx.root)
		end)

		it("uses path.find_root for workspace detection", function()
			-- This test verifies integration with path module
			local ctx = context.build_workspace_context()
			local expected_root = path.find_root()

			assert.equals(expected_root, ctx.root)
		end)

		it("detects workspace root with .git marker", function()
			-- Since we're in a git repository, this should work
			local ctx = context.build_workspace_context()

			-- The root should be a valid directory
			assert.is_true(path.is_directory(ctx.root))

			-- Should contain .git directory or be under git control
			-- (Note: in worktree, .git might be a file pointing to main .git)
			local git_path = path.join(ctx.root, ".git")
			local has_git = path.exists(git_path)
			assert.is_true(has_git)
		end)
	end)

	describe("build_chat_context", function()
		local test_bufnr
		local original_get_clients

		before_each(function()
			if vim.lsp and vim.lsp.get_clients then
				original_get_clients = vim.lsp.get_clients
			end
			-- Mock to avoid API compatibility issues
			vim.lsp.get_clients = function()
				return {}
			end
		end)

		after_each(function()
			if original_get_clients then
				vim.lsp.get_clients = original_get_clients
			end
			if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
				vim.api.nvim_buf_delete(test_bufnr, { force = true })
			end
		end)

		it("returns table with text and metadata", function()
			local lines = { "test code" }
			test_bufnr = create_test_buffer(lines, "lua")
			vim.api.nvim_buf_set_name(test_bufnr, "/tmp/test.lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			assert.is_table(ctx)
			assert.is_string(ctx.text)
			assert.is_string(ctx.filename)
			assert.is_string(ctx.filetype)
			assert.is_string(ctx.workspace)
		end)

		it("includes filename in context text", function()
			local lines = { "test" }
			test_bufnr = create_test_buffer(lines)
			vim.api.nvim_buf_set_name(test_bufnr, "/tmp/myfile.lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			assert.is_true(ctx.text:find("/tmp/myfile.lua") ~= nil)
		end)

		it("includes filetype in context text", function()
			local lines = { "test" }
			test_bufnr = create_test_buffer(lines, "python")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			assert.is_true(ctx.text:find("python") ~= nil)
		end)

		it("includes workspace root in context text", function()
			local lines = { "test" }
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			-- Should mention workspace
			assert.is_true(ctx.text:find("Workspace:") ~= nil)
		end)

		it("includes file content in code block", function()
			local lines = { "local x = 1", "local y = 2" }
			test_bufnr = create_test_buffer(lines, "lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			-- Should have markdown code fence
			assert.is_true(ctx.text:find("```lua") ~= nil)
			assert.is_true(ctx.text:find("local x = 1") ~= nil)
		end)

		it("truncates long content with ellipsis", function()
			-- Create content longer than 4000 chars
			local long_line = string.rep("x", 4100)
			local lines = { long_line }
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			assert.is_true(ctx.text:find("%(truncated%)") ~= nil)
		end)

		it("does not truncate short content", function()
			local lines = { "short content" }
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_chat_context()

			assert.is_false(ctx.text:find("%(truncated%)") ~= nil)
		end)
	end)

	describe("get_visual_selection", function()
		local test_bufnr

		after_each(function()
			if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
				vim.api.nvim_buf_delete(test_bufnr, { force = true })
			end
		end)

		it("returns nil when not in visual mode", function()
			local lines = { "test" }
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			-- In normal mode
			local selection = context.get_visual_selection()

			assert.is_nil(selection)
		end)

		it("returns nil when selection markers are invalid", function()
			-- When no visual selection has been made, marks are at position 0
			local selection = context.get_visual_selection()

			assert.is_nil(selection)
		end)

		-- Note: Testing actual visual mode selection is complex in headless tests
		-- because it requires entering visual mode and setting marks.
		-- The following tests document expected behavior:

		it("should extract single line visual selection", function()
			-- This is a documentation test - actual visual mode testing
			-- requires user interaction or more complex setup
			-- Expected behavior: selecting "world" from "hello world" should return "world"
			assert.is_true(true) -- Placeholder
		end)

		it("should extract multi-line visual selection", function()
			-- This is a documentation test
			-- Expected behavior: V mode selection should return all selected lines
			assert.is_true(true) -- Placeholder
		end)

		it("should handle block visual mode", function()
			-- This is a documentation test
			-- Expected behavior: Ctrl-V selection should return selected block
			assert.is_true(true) -- Placeholder
		end)
	end)

	describe("build_lsp_context", function()
		local test_bufnr

		before_each(function()
			local lines = { "local x = 1", "local y = 2" }
			test_bufnr = create_test_buffer(lines, "lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)
		end)

		after_each(function()
			-- Clear diagnostics
			vim.diagnostic.reset()

			if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
				vim.api.nvim_buf_delete(test_bufnr, { force = true })
			end
		end)

		it("returns table with diagnostics fields", function()
			local ctx = context.build_lsp_context()

			assert.is_table(ctx)
			assert.is_table(ctx.diagnostics)
			assert.is_string(ctx.diagnostics_text)
		end)

		it("returns empty diagnostics when none present", function()
			local ctx = context.build_lsp_context()

			assert.equals(0, #ctx.diagnostics)
			assert.equals("", ctx.diagnostics_text)
		end)

		it("extracts LSP diagnostics from buffer", function()
			-- Add a diagnostic to the buffer
			local diagnostics = {
				{
					lnum = 0,
					col = 0,
					message = "Test error message",
					severity = vim.diagnostic.severity.ERROR,
				},
			}
			vim.diagnostic.set(vim.api.nvim_create_namespace("test"), test_bufnr, diagnostics, {})

			local ctx = context.build_lsp_context()

			assert.equals(1, #ctx.diagnostics)
			assert.is_true(ctx.diagnostics_text:find("Test error message") ~= nil)
		end)

		it("formats diagnostics with line numbers", function()
			local diagnostics = {
				{
					lnum = 2,
					col = 5,
					message = "Syntax error",
					severity = vim.diagnostic.severity.ERROR,
				},
			}
			vim.diagnostic.set(vim.api.nvim_create_namespace("test"), test_bufnr, diagnostics, {})

			local ctx = context.build_lsp_context()

			-- Line should be 1-indexed in output (lnum is 0-indexed)
			assert.is_true(ctx.diagnostics_text:find("Line 3") ~= nil)
		end)

		it("includes severity level in diagnostic text", function()
			local diagnostics = {
				{
					lnum = 0,
					col = 0,
					message = "Error message",
					severity = vim.diagnostic.severity.ERROR,
				},
			}
			vim.diagnostic.set(vim.api.nvim_create_namespace("test"), test_bufnr, diagnostics, {})

			local ctx = context.build_lsp_context()

			assert.is_true(ctx.diagnostics_text:find("ERROR") ~= nil)
		end)

		it("handles multiple diagnostics", function()
			local diagnostics = {
				{
					lnum = 0,
					col = 0,
					message = "First error",
					severity = vim.diagnostic.severity.ERROR,
				},
				{
					lnum = 1,
					col = 0,
					message = "Second warning",
					severity = vim.diagnostic.severity.WARN,
				},
			}
			vim.diagnostic.set(vim.api.nvim_create_namespace("test"), test_bufnr, diagnostics, {})

			local ctx = context.build_lsp_context()

			assert.equals(2, #ctx.diagnostics)
			assert.is_true(ctx.diagnostics_text:find("First error") ~= nil)
			assert.is_true(ctx.diagnostics_text:find("Second warning") ~= nil)
		end)

		it("handles different severity levels", function()
			local test_cases = {
				{ severity = vim.diagnostic.severity.ERROR, expected = "ERROR" },
				{ severity = vim.diagnostic.severity.WARN, expected = "WARN" },
				{ severity = vim.diagnostic.severity.INFO, expected = "INFO" },
				{ severity = vim.diagnostic.severity.HINT, expected = "HINT" },
			}

			for _, tc in ipairs(test_cases) do
				-- Clear previous diagnostics
				vim.diagnostic.reset()

				local diagnostics = {
					{
						lnum = 0,
						col = 0,
						message = "Test message",
						severity = tc.severity,
					},
				}
				vim.diagnostic.set(vim.api.nvim_create_namespace("test"), test_bufnr, diagnostics, {})

				local ctx = context.build_lsp_context()

				assert.is_true(ctx.diagnostics_text:find(tc.expected) ~= nil)
			end
		end)
	end)

	describe("treesitter integration", function()
		-- Note: Treesitter is currently marked as optional and not actively used
		-- in context gathering. These tests document expected behavior if/when
		-- treesitter integration is implemented.

		it("should detect treesitter availability", function()
			local has_treesitter = pcall(require, "nvim-treesitter")
			-- Test passes whether or not treesitter is installed
			assert.is_boolean(has_treesitter)
		end)

		it("should parse buffer with treesitter when available", function()
			local has_treesitter = pcall(require, "nvim-treesitter")
			if not has_treesitter then
				-- Skip if treesitter not available
				assert.is_true(true)
				return
			end

			-- Future implementation would:
			-- 1. Parse current buffer with treesitter
			-- 2. Extract syntax nodes
			-- 3. Identify function/class boundaries
			-- 4. Return structured context

			assert.is_true(true) -- Placeholder for future implementation
		end)

		it("should extract function definitions with treesitter", function()
			-- Future: Extract function signatures and bodies
			assert.is_true(true) -- Placeholder
		end)

		it("should extract class definitions with treesitter", function()
			-- Future: Extract class/module structure
			assert.is_true(true) -- Placeholder
		end)

		it("should identify symbol at cursor with treesitter", function()
			-- Future: Use treesitter to identify exact symbol under cursor
			assert.is_true(true) -- Placeholder
		end)

		it("should gracefully fallback when treesitter unavailable", function()
			-- The current implementation already works without treesitter
			-- This test verifies that behavior continues
			local ctx = context.build_buffer_context()
			assert.is_table(ctx)
			assert.is_not_nil(ctx.prefix)
			assert.is_not_nil(ctx.suffix)
		end)
	end)

	describe("integration tests", function()
		local test_bufnr
		local original_get_clients

		before_each(function()
			if vim.lsp and vim.lsp.get_clients then
				original_get_clients = vim.lsp.get_clients
			end
			-- Mock to avoid API compatibility issues
			vim.lsp.get_clients = function()
				return {}
			end
		end)

		after_each(function()
			if original_get_clients then
				vim.lsp.get_clients = original_get_clients
			end
			vim.diagnostic.reset()
			if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
				vim.api.nvim_buf_delete(test_bufnr, { force = true })
			end
		end)

		it("combines buffer and workspace context correctly", function()
			local lines = { "local test = true" }
			test_bufnr = create_test_buffer(lines, "lua")
			vim.api.nvim_buf_set_name(test_bufnr, "/tmp/integration_test.lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 6)

			local buffer_ctx = context.build_buffer_context()
			local workspace_ctx = context.build_workspace_context()

			-- Verify they work together
			assert.is_not_nil(buffer_ctx.filename)
			assert.is_not_nil(workspace_ctx.root)
			assert.is_string(buffer_ctx.filetype)
		end)

		it("chat context includes LSP diagnostics when present", function()
			local lines = { "local x = 1", "print(x)" }
			test_bufnr = create_test_buffer(lines, "lua")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			-- Add diagnostic
			local diagnostics = {
				{
					lnum = 1,
					col = 0,
					message = "Undefined variable",
					severity = vim.diagnostic.severity.WARN,
				},
			}
			vim.diagnostic.set(vim.api.nvim_create_namespace("test"), test_bufnr, diagnostics, {})

			local lsp_ctx = context.build_lsp_context()
			local chat_ctx = context.build_chat_context()

			-- Both should work independently
			assert.equals(1, #lsp_ctx.diagnostics)
			assert.is_string(chat_ctx.text)
		end)

		it("handles unnamed buffers gracefully", function()
			local lines = { "unnamed buffer content" }
			test_bufnr = create_test_buffer(lines)
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_buffer_context()

			assert.is_string(ctx.filename)
			-- Unnamed buffers have empty string as name
			assert.is_not_nil(ctx.filetype)
		end)

		it("handles buffers without filetype", function()
			local lines = { "plain text" }
			test_bufnr = create_test_buffer(lines, "")
			set_current_buffer_and_cursor(test_bufnr, 1, 0)

			local ctx = context.build_buffer_context()

			assert.equals("", ctx.filetype)
			-- Should still work with empty filetype
			assert.is_not_nil(ctx.prefix)
			assert.is_not_nil(ctx.suffix)
		end)
	end)
end)
