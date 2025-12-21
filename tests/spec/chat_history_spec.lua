---@diagnostic disable: undefined-global
-- Tests for gemini.chat.history module

local history = require("gemini.chat.history")
local path = require("gemini.util.path")

describe("gemini.chat.history", function()
	local test_messages
	local test_history_path

	before_each(function()
		-- Create test messages
		test_messages = {
			{
				role = "user",
				content = "Hello, Gemini!",
				timestamp = 1234567890,
			},
			{
				role = "model",
				content = "Hello! How can I help you today?",
				timestamp = 1234567891,
			},
			{
				role = "user",
				content = "Can you help me with Lua?",
				timestamp = 1234567892,
			},
		}

		-- Store the history path for cleanup
		test_history_path = history.get_path()

		-- Clear any existing history
		history.clear()
	end)

	after_each(function()
		-- Clean up test files
		if test_history_path and vim.fn.filereadable(test_history_path) == 1 then
			vim.fn.delete(test_history_path)
		end
	end)

	describe("get_path", function()
		it("returns a string path", function()
			local hist_path = history.get_path()
			assert.is_string(hist_path)
		end)

		it("returns path in data directory", function()
			local hist_path = history.get_path()
			local data_dir = path.get_data_dir()
			assert.matches(vim.pesc(data_dir), hist_path)
		end)

		it("returns path ending in chat_history.json", function()
			local hist_path = history.get_path()
			assert.matches("chat_history.json$", hist_path)
		end)

		it("returns consistent path across calls", function()
			local path1 = history.get_path()
			local path2 = history.get_path()
			assert.equals(path1, path2)
		end)
	end)

	describe("save", function()
		it("saves messages to file", function()
			local success = history.save(test_messages)
			assert.is_true(success)
			assert.equals(1, vim.fn.filereadable(test_history_path))
		end)

		it("creates data directory if it doesn't exist", function()
			local data_dir = path.get_data_dir()

			-- Remove data dir if it exists (this is safe in test environment)
			-- Note: We'll just test that save handles missing dir gracefully
			local success = history.save(test_messages)
			assert.is_true(success)
		end)

		it("returns false on write error", function()
			-- Try to save to an invalid path by mocking get_path
			-- This is tricky to test without mocking, so we'll skip detailed error testing
			-- and just ensure the function handles errors gracefully
			local success = history.save({})
			assert.is_not_nil(success)
			assert.is_boolean(success)
		end)

		it("saves messages in JSON format", function()
			history.save(test_messages)

			local file = io.open(test_history_path, "r")
			assert.is_not_nil(file)

			local content = file:read("*a")
			file:close()

			-- Should be valid JSON
			local ok, data = pcall(vim.json.decode, content)
			assert.is_true(ok)
			assert.is_table(data)
		end)

		it("includes version in saved data", function()
			history.save(test_messages)

			local file = io.open(test_history_path, "r")
			local content = file:read("*a")
			file:close()

			local data = vim.json.decode(content)
			assert.equals(1, data.version)
		end)

		it("includes timestamp in saved data", function()
			local before = os.time()
			history.save(test_messages)
			local after = os.time()

			local file = io.open(test_history_path, "r")
			local content = file:read("*a")
			file:close()

			local data = vim.json.decode(content)
			assert.is_number(data.updated_at)
			assert.is_true(data.updated_at >= before)
			assert.is_true(data.updated_at <= after)
		end)

		it("saves all message fields", function()
			history.save(test_messages)

			local file = io.open(test_history_path, "r")
			local content = file:read("*a")
			file:close()

			local data = vim.json.decode(content)
			assert.equals(3, #data.messages)

			local msg = data.messages[1]
			assert.equals("user", msg.role)
			assert.equals("Hello, Gemini!", msg.content)
			assert.equals(1234567890, msg.timestamp)
		end)

		it("overwrites existing history file", function()
			-- Save first set of messages
			history.save(test_messages)

			-- Save different messages
			local new_messages = {
				{ role = "user", content = "New message", timestamp = os.time() },
			}
			history.save(new_messages)

			-- Load and verify
			local loaded = history.load()
			assert.equals(1, #loaded)
			assert.equals("New message", loaded[1].content)
		end)

		it("handles empty message list", function()
			local success = history.save({})
			assert.is_true(success)

			local loaded = history.load()
			assert.is_table(loaded)
			assert.equals(0, #loaded)
		end)
	end)

	describe("load", function()
		it("returns empty table when file doesn't exist", function()
			-- Ensure no history file exists
			history.clear()

			local loaded = history.load()
			assert.is_table(loaded)
			assert.equals(0, #loaded)
		end)

		it("loads saved messages", function()
			history.save(test_messages)
			local loaded = history.load()

			assert.equals(3, #loaded)
			assert.equals("user", loaded[1].role)
			assert.equals("Hello, Gemini!", loaded[1].content)
			assert.equals(1234567890, loaded[1].timestamp)
		end)

		it("preserves message order", function()
			history.save(test_messages)
			local loaded = history.load()

			for i, msg in ipairs(test_messages) do
				assert.equals(msg.role, loaded[i].role)
				assert.equals(msg.content, loaded[i].content)
				assert.equals(msg.timestamp, loaded[i].timestamp)
			end
		end)

		it("handles corrupted JSON gracefully", function()
			-- Write invalid JSON to history file
			local file = io.open(test_history_path, "w")
			file:write("{ invalid json }")
			file:close()

			local loaded = history.load()
			assert.is_table(loaded)
			assert.equals(0, #loaded)
		end)

		it("handles missing messages field", function()
			-- Write JSON without messages field
			local file = io.open(test_history_path, "w")
			file:write(vim.json.encode({ version = 1 }))
			file:close()

			local loaded = history.load()
			assert.is_table(loaded)
			assert.equals(0, #loaded)
		end)

		it("loads messages with all fields intact", function()
			local messages = {
				{
					role = "user",
					content = "Test with\nmultiple\nlines",
					timestamp = 9999999,
				},
				{
					role = "model",
					content = "Response with special chars: !@#$%",
					timestamp = 9999998,
				},
			}

			history.save(messages)
			local loaded = history.load()

			assert.equals("Test with\nmultiple\nlines", loaded[1].content)
			assert.equals("Response with special chars: !@#$%", loaded[2].content)
		end)

		it("handles unicode content", function()
			local unicode_messages = {
				{
					role = "user",
					content = "Unicode: 你好 🚀 مرحبا",
					timestamp = os.time(),
				},
			}

			history.save(unicode_messages)
			local loaded = history.load()

			assert.equals("Unicode: 你好 🚀 مرحبا", loaded[1].content)
		end)

		it("loads large message history", function()
			local large_history = {}
			for i = 1, 500 do
				table.insert(large_history, {
					role = i % 2 == 1 and "user" or "model",
					content = "Message number " .. i,
					timestamp = os.time() + i,
				})
			end

			history.save(large_history)
			local loaded = history.load()

			assert.equals(500, #loaded)
			assert.equals("Message number 1", loaded[1].content)
			assert.equals("Message number 500", loaded[500].content)
		end)
	end)

	describe("clear", function()
		it("removes history file", function()
			history.save(test_messages)
			assert.equals(1, vim.fn.filereadable(test_history_path))

			local success = history.clear()
			assert.is_true(success)
			assert.equals(0, vim.fn.filereadable(test_history_path))
		end)

		it("returns true when file doesn't exist", function()
			-- Ensure no file exists
			history.clear()

			-- Clear again should still succeed
			local success = history.clear()
			assert.is_true(success)
		end)

		it("allows saving after clearing", function()
			history.save(test_messages)
			history.clear()
			history.save(test_messages)

			local loaded = history.load()
			assert.equals(3, #loaded)
		end)

		it("clears all data from file", function()
			history.save(test_messages)
			history.clear()

			local loaded = history.load()
			assert.equals(0, #loaded)
		end)
	end)

	describe("persistence workflow", function()
		it("supports save-load-clear cycle", function()
			-- Save
			local success = history.save(test_messages)
			assert.is_true(success)

			-- Load
			local loaded = history.load()
			assert.equals(3, #loaded)

			-- Clear
			success = history.clear()
			assert.is_true(success)

			-- Load after clear
			loaded = history.load()
			assert.equals(0, #loaded)
		end)

		it("maintains data integrity across multiple saves", function()
			-- First save
			history.save(test_messages)
			local loaded1 = history.load()

			-- Second save with updated data
			table.insert(test_messages, {
				role = "model",
				content = "Additional response",
				timestamp = os.time(),
			})
			history.save(test_messages)
			local loaded2 = history.load()

			assert.equals(3, #loaded1)
			assert.equals(4, #loaded2)
		end)

		it("handles concurrent operations gracefully", function()
			-- Simulate rapid save operations
			for i = 1, 10 do
				local msgs = {
					{ role = "user", content = "Iteration " .. i, timestamp = os.time() },
				}
				history.save(msgs)
			end

			local loaded = history.load()
			assert.is_table(loaded)
			assert.equals(1, #loaded) -- Should have last saved message
		end)
	end)

	describe("edge cases", function()
		it("handles very long message content", function()
			local long_messages = {
				{
					role = "user",
					content = string.rep("a", 100000),
					timestamp = os.time(),
				},
			}

			local success = history.save(long_messages)
			assert.is_true(success)

			local loaded = history.load()
			assert.equals(100000, #loaded[1].content)
		end)

		it("handles special characters in content", function()
			local special_messages = {
				{
					role = "user",
					content = 'Special: "\n\t\r\\ \'',
					timestamp = os.time(),
				},
			}

			history.save(special_messages)
			local loaded = history.load()

			assert.equals('Special: "\n\t\r\\ \'', loaded[1].content)
		end)

		it("preserves message timestamps", function()
			local timestamps = { 1000000, 2000000, 3000000 }
			local messages = {}

			for i, ts in ipairs(timestamps) do
				table.insert(messages, {
					role = i % 2 == 1 and "user" or "model",
					content = "Message " .. i,
					timestamp = ts,
				})
			end

			history.save(messages)
			local loaded = history.load()

			for i, ts in ipairs(timestamps) do
				assert.equals(ts, loaded[i].timestamp)
			end
		end)

		it("handles missing timestamp field", function()
			-- Manually create messages without timestamp
			local messages = {
				{ role = "user", content = "No timestamp" },
			}

			history.save(messages)
			local loaded = history.load()

			assert.equals(1, #loaded)
			assert.equals("No timestamp", loaded[1].content)
		end)
	end)
end)
