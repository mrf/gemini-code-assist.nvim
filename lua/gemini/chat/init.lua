---@mod gemini.chat Chat module
---@brief [[
--- Provides interactive chat interface.
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

---@type table?
M._window = nil

---@type table[]
M._messages = {}

--- Setup chat module
---@param config GeminiConfig
function M.setup(config)
	M._config = config
end

--- Toggle chat window
function M.toggle()
	if M._window and vim.api.nvim_win_is_valid(M._window.win) then
		M.close()
	else
		M.open()
	end
end

--- Open chat window
function M.open()
	local window = require("gemini.chat.window")
	M._window = window.create(M._config.chat)
	M._render_messages()
end

--- Close chat window
function M.close()
	if M._window then
		local window = require("gemini.chat.window")
		window.close(M._window)
		M._window = nil
	end
end

--- Send a message
---@param message string
function M.send(message)
	if not message or message == "" then
		return
	end

	-- Add user message
	table.insert(M._messages, {
		role = "user",
		content = message,
		timestamp = os.time(),
	})

	M._render_messages()

	-- Build context if enabled
	local context_module = require("gemini.context")
	local context = nil
	if M._config.chat.auto_context then
		context = context_module.build_chat_context()
	end

	-- Build prompt with context
	local prompt = M._build_prompt(message, context)

	-- Send to API
	local api = require("gemini.api")
	local accumulator = require("gemini.api.streaming").create_accumulator()

	api.stream(prompt, {
		model = M._config.model.chat,
	}, function(chunk, err)
		if err then
			vim.notify("Gemini chat error: " .. err, vim.log.levels.ERROR)
			return
		end

		if chunk then
			accumulator:add(chunk)
			M._update_streaming_response(accumulator:get_text())
		end
	end, function(success)
		if success then
			-- Finalize message
			table.insert(M._messages, {
				role = "model",
				content = accumulator:get_text(),
				timestamp = os.time(),
			})
			M._render_messages()

			-- Save history if enabled
			if M._config.chat.persist_history then
				require("gemini.chat.history").save(M._messages)
			end
		end
	end)
end

--- Build prompt with optional context
---@param message string
---@param context table?
---@return table
function M._build_prompt(message, context)
	local contents = {}

	-- Add system context if available
	if context then
		table.insert(contents, {
			role = "user",
			parts = { { text = "Context:\n" .. context.text } },
		})
		table.insert(contents, {
			role = "model",
			parts = { { text = "I understand the context. How can I help?" } },
		})
	end

	-- Add conversation history
	for _, msg in ipairs(M._messages) do
		table.insert(contents, {
			role = msg.role,
			parts = { { text = msg.content } },
		})
	end

	return contents
end

--- Render messages in chat window
function M._render_messages()
	if not M._window then
		return
	end

	local window = require("gemini.chat.window")
	local lines = {}

	for _, msg in ipairs(M._messages) do
		local prefix = msg.role == "user" and "You: " or "Gemini: "
		local content_lines = vim.split(msg.content, "\n")
		for i, line in ipairs(content_lines) do
			if i == 1 then
				table.insert(lines, prefix .. line)
			else
				table.insert(lines, "  " .. line)
			end
		end
		table.insert(lines, "")
	end

	window.set_content(M._window, lines)
end

--- Update streaming response display
---@param text string
function M._update_streaming_response(text)
	if not M._window then
		return
	end

	-- Re-render with streaming response
	local window = require("gemini.chat.window")
	local lines = {}

	for _, msg in ipairs(M._messages) do
		local prefix = msg.role == "user" and "You: " or "Gemini: "
		local content_lines = vim.split(msg.content, "\n")
		for i, line in ipairs(content_lines) do
			if i == 1 then
				table.insert(lines, prefix .. line)
			else
				table.insert(lines, "  " .. line)
			end
		end
		table.insert(lines, "")
	end

	-- Add streaming response (split by newlines to avoid nvim_buf_set_lines error)
	local streaming_lines = vim.split(text, "\n")
	for i, line in ipairs(streaming_lines) do
		if i == 1 then
			table.insert(lines, "Gemini: " .. line .. (i == #streaming_lines and "▌" or ""))
		else
			table.insert(lines, "  " .. line .. (i == #streaming_lines and "▌" or ""))
		end
	end

	window.set_content(M._window, lines)
end

--- Clear chat history
function M.clear()
	M._messages = {}
	M._render_messages()
end

return M
