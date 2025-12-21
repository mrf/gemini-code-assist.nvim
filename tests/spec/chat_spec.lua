---@diagnostic disable: undefined-global
-- Tests for gemini.chat module

local chat = require("gemini.chat")
local history = require("gemini.chat.history")

describe("gemini.chat", function()
	local test_config

	before_each(function()
		-- Create test configuration
		test_config = {
			chat = {
				enabled = true,
				window_type = "floating",
				width = 0.6,
				height = 0.8,
				persist_history = false,
				auto_context = false,
			},
			model = {
				chat = "gemini-2.0-flash",
			},
		}

		-- Setup chat with test config
		chat.setup(test_config)

		-- Clear messages before each test
		chat._messages = {}

		-- Close any open windows
		if chat._window then
			pcall(function()
				require("gemini.chat.window").close(chat._window)
			end)
			chat._window = nil
		end
	end)

	after_each(function()
		-- Cleanup
		chat._messages = {}
		if chat._window then
			pcall(function()
				require("gemini.chat.window").close(chat._window)
			end)
			chat._window = nil
		end
	end)

	describe("setup", function()
		it("stores configuration", function()
			assert.is_not_nil(chat._config)
			assert.is_table(chat._config.chat)
			assert.equals("gemini-2.0-flash", chat._config.model.chat)
		end)

		it("initializes empty message list", function()
			assert.is_table(chat._messages)
			assert.equals(0, #chat._messages)
		end)
	end)

	describe("message handling", function()
		it("adds user message to message list", function()
			chat.send("Hello, Gemini!")

			assert.equals(1, #chat._messages)
			assert.equals("user", chat._messages[1].role)
			assert.equals("Hello, Gemini!", chat._messages[1].content)
		end)

		it("adds timestamp to messages", function()
			local before = os.time()
			chat.send("Test message")
			local after = os.time()

			assert.is_number(chat._messages[1].timestamp)
			assert.is_true(chat._messages[1].timestamp >= before)
			assert.is_true(chat._messages[1].timestamp <= after)
		end)

		it("ignores empty messages", function()
			chat.send("")
			assert.equals(0, #chat._messages)

			chat.send(nil)
			assert.equals(0, #chat._messages)
		end)

		it("handles multiline messages", function()
			local multiline = "Line 1\nLine 2\nLine 3"
			chat.send(multiline)

			assert.equals(1, #chat._messages)
			assert.equals(multiline, chat._messages[1].content)
		end)

		it("stores multiple messages in sequence", function()
			chat.send("First message")
			chat.send("Second message")
			chat.send("Third message")

			assert.equals(3, #chat._messages)
			assert.equals("First message", chat._messages[1].content)
			assert.equals("Second message", chat._messages[2].content)
			assert.equals("Third message", chat._messages[3].content)
		end)

		it("preserves message order", function()
			for i = 1, 10 do
				chat.send("Message " .. i)
			end

			for i = 1, 10 do
				assert.equals("Message " .. i, chat._messages[i].content)
			end
		end)
	end)

	describe("conversation structure", function()
		it("creates proper conversation format", function()
			chat._messages = {
				{ role = "user", content = "Hello", timestamp = os.time() },
				{ role = "model", content = "Hi there!", timestamp = os.time() },
			}

			local prompt = chat._build_prompt("How are you?", nil)

			-- Should have previous messages + new message
			assert.is_table(prompt)
			assert.equals(2, #prompt) -- Previous 2 messages (new one added separately)

			-- Check structure
			assert.equals("user", prompt[1].role)
			assert.equals("model", prompt[2].role)
			assert.is_table(prompt[1].parts)
			assert.equals("Hello", prompt[1].parts[1].text)
		end)

		it("builds empty prompt for first message", function()
			chat._messages = {}
			local prompt = chat._build_prompt("First message", nil)

			-- Should be empty since we haven't added the user message yet
			assert.is_table(prompt)
			assert.equals(0, #prompt)
		end)

		it("preserves conversation history in prompt", function()
			-- Simulate a conversation
			chat._messages = {
				{ role = "user", content = "What is Lua?", timestamp = os.time() },
				{ role = "model", content = "Lua is a programming language", timestamp = os.time() },
				{ role = "user", content = "What's it used for?", timestamp = os.time() },
				{ role = "model", content = "It's used for scripting", timestamp = os.time() },
			}

			local prompt = chat._build_prompt("Tell me more", nil)

			assert.equals(4, #prompt)
			assert.equals("What is Lua?", prompt[1].parts[1].text)
			assert.equals("Lua is a programming language", prompt[2].parts[1].text)
			assert.equals("What's it used for?", prompt[3].parts[1].text)
			assert.equals("It's used for scripting", prompt[4].parts[1].text)
		end)

		it("maintains role alternation in conversation", function()
			chat._messages = {
				{ role = "user", content = "Message 1", timestamp = os.time() },
				{ role = "model", content = "Message 2", timestamp = os.time() },
				{ role = "user", content = "Message 3", timestamp = os.time() },
			}

			local prompt = chat._build_prompt("Message 4", nil)

			assert.equals("user", prompt[1].role)
			assert.equals("model", prompt[2].role)
			assert.equals("user", prompt[3].role)
		end)
	end)

	describe("context injection", function()
		it("injects context at the beginning of prompt", function()
			local context = {
				text = "File: test.lua\nContent: print('hello')",
			}

			local prompt = chat._build_prompt("Explain this code", context)

			-- Should have context user message + model acknowledgment
			assert.is_table(prompt)
			assert.equals(2, #prompt)
			assert.equals("user", prompt[1].role)
			assert.equals("model", prompt[2].role)
			assert.matches("Context:", prompt[1].parts[1].text)
			assert.matches("I understand the context", prompt[2].parts[1].text)
		end)

		it("includes context text in user message", function()
			local context = {
				text = "Current file: main.lua\nLanguage: lua",
			}

			local prompt = chat._build_prompt("Help me", context)

			assert.matches("Current file: main.lua", prompt[1].parts[1].text)
			assert.matches("Language: lua", prompt[1].parts[1].text)
		end)

		it("builds prompt without context when nil", function()
			chat._messages = {
				{ role = "user", content = "Previous message", timestamp = os.time() },
			}

			local prompt = chat._build_prompt("New message", nil)

			-- Should only have previous messages, no context injection
			assert.equals(1, #prompt)
			assert.equals("user", prompt[1].role)
			assert.equals("Previous message", prompt[1].parts[1].text)
		end)

		it("places context before conversation history", function()
			chat._messages = {
				{ role = "user", content = "Existing message", timestamp = os.time() },
			}

			local context = { text = "Context info" }
			local prompt = chat._build_prompt("New message", context)

			-- Context should be first (2 messages), then history (1 message)
			assert.equals(3, #prompt)
			assert.matches("Context:", prompt[1].parts[1].text)
			assert.equals("model", prompt[2].role)
			assert.equals("Existing message", prompt[3].parts[1].text)
		end)

		it("handles empty context gracefully", function()
			local context = { text = "" }
			local prompt = chat._build_prompt("Message", context)

			-- Empty context should still create context messages
			assert.equals(2, #prompt)
			assert.matches("Context:", prompt[1].parts[1].text)
		end)

		it("preserves context structure with multiple messages", function()
			chat._messages = {
				{ role = "user", content = "Q1", timestamp = os.time() },
				{ role = "model", content = "A1", timestamp = os.time() },
				{ role = "user", content = "Q2", timestamp = os.time() },
			}

			local context = { text = "Important context" }
			local prompt = chat._build_prompt("Q3", context)

			-- Context (2) + history (3) = 5 messages
			assert.equals(5, #prompt)
			assert.matches("Context:", prompt[1].parts[1].text)
			assert.equals("model", prompt[2].role)
			assert.equals("Q1", prompt[3].parts[1].text)
			assert.equals("A1", prompt[4].parts[1].text)
			assert.equals("Q2", prompt[5].parts[1].text)
		end)
	end)

	describe("clear", function()
		it("clears all messages", function()
			chat._messages = {
				{ role = "user", content = "Message 1", timestamp = os.time() },
				{ role = "model", content = "Message 2", timestamp = os.time() },
				{ role = "user", content = "Message 3", timestamp = os.time() },
			}

			chat.clear()

			assert.equals(0, #chat._messages)
		end)

		it("can send new messages after clearing", function()
			chat.send("First")
			chat.clear()
			chat.send("Second")

			assert.equals(1, #chat._messages)
			assert.equals("Second", chat._messages[1].content)
		end)

		it("handles clearing empty message list", function()
			chat._messages = {}
			chat.clear()
			assert.equals(0, #chat._messages)
		end)
	end)

	describe("window management", function()
		it("tracks window state", function()
			assert.is_nil(chat._window)
		end)

		it("closes window when window exists", function()
			-- Create a mock window
			chat._window = {
				win = -1, -- Invalid window
				buf = -1,
			}

			-- Should not error even with invalid window
			assert.has_no_errors(function()
				chat.close()
			end)

			assert.is_nil(chat._window)
		end)

		it("handles close when no window exists", function()
			chat._window = nil
			assert.has_no_errors(function()
				chat.close()
			end)
		end)
	end)

	describe("edge cases", function()
		it("handles very long messages", function()
			local long_message = string.rep("a", 10000)
			chat.send(long_message)

			assert.equals(1, #chat._messages)
			assert.equals(10000, #chat._messages[1].content)
		end)

		it("handles special characters in messages", function()
			local special = "Special chars: \n\t\r\0 !@#$%^&*()"
			chat.send(special)

			assert.equals(1, #chat._messages)
			assert.equals(special, chat._messages[1].content)
		end)

		it("handles unicode in messages", function()
			local unicode = "Unicode: 你好 🚀 مرحبا"
			chat.send(unicode)

			assert.equals(1, #chat._messages)
			assert.equals(unicode, chat._messages[1].content)
		end)

		it("builds prompt with many messages", function()
			for i = 1, 100 do
				table.insert(chat._messages, {
					role = i % 2 == 1 and "user" or "model",
					content = "Message " .. i,
					timestamp = os.time(),
				})
			end

			local prompt = chat._build_prompt("New message", nil)
			assert.equals(100, #prompt)
		end)
	end)
end)
