---@diagnostic disable: undefined-global
-- Tests for API client modules

local client = require("gemini.api.client")
local streaming = require("gemini.api.streaming")
local gemini = require("gemini.api.gemini")

describe("gemini.api.client", function()
	describe("request formatting", function()
		it("builds GET request command correctly", function()
			local captured_cmd = nil

			-- Mock jobstart to capture command
			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(cmd, _)
				captured_cmd = cmd
				return 0
			end

			client.request("https://example.com/api", {
				method = "GET",
			}, function() end)

			vim.fn.jobstart = original_jobstart

			assert.is_not_nil(captured_cmd)
			assert.equals("curl", captured_cmd[1])
			assert.equals("-s", captured_cmd[2])
			assert.equals("-X", captured_cmd[3])
			assert.equals("GET", captured_cmd[4])
			assert.equals("https://example.com/api", captured_cmd[#captured_cmd])
		end)

		it("builds POST request with JSON body", function()
			local captured_cmd = nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(cmd, _)
				captured_cmd = cmd
				return 0
			end

			local body = { key = "value", nested = { data = 123 } }
			client.request("https://example.com/api", {
				method = "POST",
				body = body,
			}, function() end)

			vim.fn.jobstart = original_jobstart

			-- Find -d flag and check body is JSON encoded
			local body_idx = nil
			for i, arg in ipairs(captured_cmd) do
				if arg == "-d" then
					body_idx = i + 1
					break
				end
			end

			assert.is_not_nil(body_idx)
			local encoded_body = captured_cmd[body_idx]
			local decoded = vim.json.decode(encoded_body)
			assert.equals("value", decoded.key)
			assert.equals(123, decoded.nested.data)
		end)

		it("builds request with string body", function()
			local captured_cmd = nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(cmd, _)
				captured_cmd = cmd
				return 0
			end

			client.request("https://example.com/api", {
				method = "POST",
				body = "raw string data",
			}, function() end)

			vim.fn.jobstart = original_jobstart

			-- Find -d flag and check body
			local body_idx = nil
			for i, arg in ipairs(captured_cmd) do
				if arg == "-d" then
					body_idx = i + 1
					break
				end
			end

			assert.is_not_nil(body_idx)
			assert.equals("raw string data", captured_cmd[body_idx])
		end)

		it("includes custom headers in request", function()
			local captured_cmd = nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(cmd, _)
				captured_cmd = cmd
				return 0
			end

			client.request("https://example.com/api", {
				method = "GET",
				headers = {
					["Content-Type"] = "application/json",
					["Authorization"] = "Bearer token123",
				},
			}, function() end)

			vim.fn.jobstart = original_jobstart

			-- Check for -H flags with headers
			local has_content_type = false
			local has_authorization = false

			for i, arg in ipairs(captured_cmd) do
				if arg == "-H" then
					local header = captured_cmd[i + 1]
					if header:match("Content%-Type: application/json") then
						has_content_type = true
					end
					if header:match("Authorization: Bearer token123") then
						has_authorization = true
					end
				end
			end

			assert.is_true(has_content_type)
			assert.is_true(has_authorization)
		end)

		it("builds streaming request with -N flag", function()
			local captured_cmd = nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(cmd, _)
				captured_cmd = cmd
				return 0
			end

			client.stream("https://example.com/stream", {
				method = "POST",
			}, function() end, function() end)

			vim.fn.jobstart = original_jobstart

			assert.is_not_nil(captured_cmd)
			-- Check for -N flag (no buffering)
			local has_no_buffer = false
			for _, arg in ipairs(captured_cmd) do
				if arg == "-N" then
					has_no_buffer = true
					break
				end
			end

			assert.is_true(has_no_buffer)
		end)
	end)

	describe("response parsing", function()
		it("parses valid JSON response", function()
			local callback_err, callback_response = nil, nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				-- Simulate successful response
				vim.schedule(function()
					callbacks.on_stdout(nil, { '{"status":"success","data":123}' })
				end)
				return 0
			end

			client.request("https://example.com/api", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			-- Wait for async callback
			vim.wait(100, function()
				return callback_response ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.is_nil(callback_err)
			assert.is_not_nil(callback_response)
			assert.equals("success", callback_response.status)
			assert.equals(123, callback_response.data)
		end)

		it("handles non-JSON response as raw data", function()
			local callback_err, callback_response = nil, nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_stdout(nil, { "This is plain text" })
				end)
				return 0
			end

			client.request("https://example.com/api", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			vim.wait(100, function()
				return callback_response ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.is_nil(callback_err)
			assert.is_not_nil(callback_response)
			assert.equals("This is plain text", callback_response.raw)
		end)

		it("handles multi-line JSON response", function()
			local callback_err, callback_response = nil, nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_stdout(nil, {
						"{",
						'  "key": "value",',
						'  "number": 42',
						"}",
					})
				end)
				return 0
			end

			client.request("https://example.com/api", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			vim.wait(100, function()
				return callback_response ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.is_nil(callback_err)
			assert.is_not_nil(callback_response)
			assert.equals("value", callback_response.key)
			assert.equals(42, callback_response.number)
		end)
	end)

	describe("error scenarios", function()
		it("handles stderr output as error", function()
			local callback_err, callback_response = nil, nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_stderr(nil, { "curl: (6) Could not resolve host" })
				end)
				return 0
			end

			client.request("https://invalid.example.com/api", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			vim.wait(100, function()
				return callback_err ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.is_not_nil(callback_err)
			assert.is_nil(callback_response)
			assert.equals("curl: (6) Could not resolve host", callback_err.message)
		end)

		it("handles non-zero exit code", function()
			local callback_err, callback_response = nil, nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_exit(nil, 7)
				end)
				return 0
			end

			client.request("https://example.com/api", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			vim.wait(100, function()
				return callback_err ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.is_not_nil(callback_err)
			assert.is_nil(callback_response)
			assert.equals("Request failed with code 7", callback_err.message)
		end)

		it("ignores empty stderr data", function()
			local callback_err, callback_response = nil, nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					-- Simulate empty stderr (common with successful requests)
					callbacks.on_stderr(nil, { "" })
					callbacks.on_stdout(nil, { '{"status":"ok"}' })
				end)
				return 0
			end

			client.request("https://example.com/api", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			vim.wait(100, function()
				return callback_response ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.is_nil(callback_err)
			assert.is_not_nil(callback_response)
		end)

		it("handles streaming errors via stderr", function()
			local chunk_err = nil
			local done_success = nil

			local original_jobstart = vim.fn.jobstart
			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_stderr(nil, { "Connection timeout" })
					callbacks.on_exit(nil, 1)
				end)
				return 0
			end

			client.stream(
				"https://example.com/stream",
				{},
				function(chunk, err)
					chunk_err = err
				end,
				function(success)
					done_success = success
				end
			)

			vim.wait(100, function()
				return chunk_err ~= nil and done_success ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.equals("Connection timeout", chunk_err)
			assert.is_false(done_success)
		end)
	end)
end)

describe("gemini.api.streaming", function()
	describe("SSE line parsing", function()
		it("parses valid SSE data line", function()
			local line =
				'data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]},"finishReason":"STOP"}]}'
			local result = streaming.parse_sse_line(line)

			assert.is_not_nil(result)
			assert.equals("Hello", result.text)
			assert.equals("STOP", result.finish_reason)
		end)

		it("handles SSE line with extra whitespace", function()
			local line =
				'data:    {"candidates":[{"content":{"parts":[{"text":"Test"}]},"finishReason":"MAX_TOKENS"}]}'
			local result = streaming.parse_sse_line(line)

			assert.is_not_nil(result)
			assert.equals("Test", result.text)
			assert.equals("MAX_TOKENS", result.finish_reason)
		end)

		it("concatenates multiple text parts", function()
			local line =
				'data: {"candidates":[{"content":{"parts":[{"text":"Hello "},{"text":"world"}]},"finishReason":"STOP"}]}'
			local result = streaming.parse_sse_line(line)

			assert.is_not_nil(result)
			assert.equals("Hello world", result.text)
		end)

		it("returns nil for empty line", function()
			local result = streaming.parse_sse_line("")
			assert.is_nil(result)
		end)

		it("returns nil for non-SSE line", function()
			local result = streaming.parse_sse_line("Just a regular line")
			assert.is_nil(result)
		end)

		it("returns nil for invalid JSON", function()
			local line = "data: {invalid json"
			local result = streaming.parse_sse_line(line)
			assert.is_nil(result)
		end)

		it("returns nil for missing candidates", function()
			local line = 'data: {"error":"No candidates"}'
			local result = streaming.parse_sse_line(line)
			assert.is_nil(result)
		end)

		it("returns nil for missing content.parts", function()
			local line = 'data: {"candidates":[{"content":{}}]}'
			local result = streaming.parse_sse_line(line)
			assert.is_nil(result)
		end)

		it("handles finish reason without text", function()
			local line = 'data: {"candidates":[{"content":{"parts":[]},"finishReason":"STOP"}]}'
			local result = streaming.parse_sse_line(line)

			-- Should still return result with empty text
			assert.is_not_nil(result)
			assert.equals("", result.text)
			assert.equals("STOP", result.finish_reason)
		end)
	end)

	describe("streaming accumulator", function()
		it("creates accumulator with initial state", function()
			local acc = streaming.create_accumulator()

			assert.is_not_nil(acc)
			assert.equals("", acc:get_text())
			assert.equals(0, #acc.chunks)
		end)

		it("accumulates text from chunks", function()
			local acc = streaming.create_accumulator()

			acc:add({ text = "Hello" })
			acc:add({ text = " " })
			acc:add({ text = "world" })

			assert.equals("Hello world", acc:get_text())
		end)

		it("stores individual chunks", function()
			local acc = streaming.create_accumulator()

			acc:add({ text = "First", finish_reason = nil })
			acc:add({ text = "Second", finish_reason = "STOP" })

			assert.equals(2, #acc.chunks)
			assert.equals("First", acc.chunks[1].text)
			assert.equals("Second", acc.chunks[2].text)
			assert.equals("STOP", acc.chunks[2].finish_reason)
		end)

		it("clears accumulator state", function()
			local acc = streaming.create_accumulator()

			acc:add({ text = "Some text" })
			assert.equals("Some text", acc:get_text())

			acc:clear()
			assert.equals("", acc:get_text())
			assert.equals(0, #acc.chunks)
		end)

		it("ignores nil chunks", function()
			local acc = streaming.create_accumulator()

			acc:add(nil)
			acc:add({ text = "Valid" })
			acc:add(nil)

			assert.equals("Valid", acc:get_text())
			assert.equals(1, #acc.chunks)
		end)

		it("ignores chunks without text", function()
			local acc = streaming.create_accumulator()

			acc:add({ finish_reason = "STOP" })
			acc:add({ text = "Has text" })

			assert.equals("Has text", acc:get_text())
			assert.equals(1, #acc.chunks)
		end)
	end)

	describe("streaming chunk handling", function()
		it("processes complete streaming session", function()
			local original_jobstart = vim.fn.jobstart
			local chunks_received = {}
			local final_done = nil

			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					-- Simulate streaming chunks
					callbacks.on_stdout(nil, {
						'data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}',
						'data: {"candidates":[{"content":{"parts":[{"text":" world"}]}}]}',
						'data: {"candidates":[{"content":{"parts":[{"text":"!"}]},"finishReason":"STOP"}]}',
					})
					callbacks.on_exit(nil, 0)
				end)
				return 0
			end

			client.stream(
				"https://example.com/stream",
				{},
				function(line)
					local chunk = streaming.parse_sse_line(line)
					if chunk then
						table.insert(chunks_received, chunk)
					end
				end,
				function(success)
					final_done = success
				end
			)

			vim.wait(100, function()
				return final_done ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.equals(3, #chunks_received)
			assert.equals("Hello", chunks_received[1].text)
			assert.equals(" world", chunks_received[2].text)
			assert.equals("!", chunks_received[3].text)
			assert.equals("STOP", chunks_received[3].finish_reason)
			assert.is_true(final_done)
		end)

		it("accumulates streaming text correctly", function()
			local original_jobstart = vim.fn.jobstart
			local acc = streaming.create_accumulator()
			local final_done = nil

			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_stdout(nil, {
						'data: {"candidates":[{"content":{"parts":[{"text":"The"}]}}]}',
						'data: {"candidates":[{"content":{"parts":[{"text":" quick"}]}}]}',
						'data: {"candidates":[{"content":{"parts":[{"text":" brown"}]}}]}',
						'data: {"candidates":[{"content":{"parts":[{"text":" fox"}]},"finishReason":"STOP"}]}',
					})
					callbacks.on_exit(nil, 0)
				end)
				return 0
			end

			client.stream(
				"https://example.com/stream",
				{},
				function(line)
					local chunk = streaming.parse_sse_line(line)
					acc:add(chunk)
				end,
				function(success)
					final_done = success
				end
			)

			vim.wait(100, function()
				return final_done ~= nil
			end)

			vim.fn.jobstart = original_jobstart

			assert.equals("The quick brown fox", acc:get_text())
			assert.equals(4, #acc.chunks)
		end)

		it("filters out non-SSE lines in stream", function()
			local original_jobstart = vim.fn.jobstart
			local chunks_received = {}

			vim.fn.jobstart = function(_, callbacks)
				vim.schedule(function()
					callbacks.on_stdout(nil, {
						"", -- empty line
						'data: {"candidates":[{"content":{"parts":[{"text":"Valid"}]}}]}',
						"Not an SSE line",
						'data: {"candidates":[{"content":{"parts":[{"text":" chunk"}]}}]}',
						"event: message", -- SSE event line (not data)
					})
					callbacks.on_exit(nil, 0)
				end)
				return 0
			end

			client.stream(
				"https://example.com/stream",
				{},
				function(line)
					local chunk = streaming.parse_sse_line(line)
					if chunk then
						table.insert(chunks_received, chunk)
					end
				end,
				function() end
			)

			vim.wait(100)

			vim.fn.jobstart = original_jobstart

			-- Only valid SSE data lines should be parsed
			assert.equals(2, #chunks_received)
			assert.equals("Valid", chunks_received[1].text)
			assert.equals(" chunk", chunks_received[2].text)
		end)
	end)
end)

describe("gemini.api.gemini", function()
	-- Note: These tests will fail without proper auth setup, but test the request structure
	describe("request body building", function()
		it("builds request with string prompt", function()
			-- We'll test this indirectly by mocking the client
			local captured_body = nil
			local original_request = require("gemini.api.client").request

			require("gemini.api.client").request = function(url, opts, callback)
				captured_body = opts.body
				callback(nil, {
					candidates = {
						{
							content = { parts = { { text = "Response" } } },
							finishReason = "STOP",
						},
					},
				})
			end

			-- Mock auth to return test credentials
			local auth = require("gemini.auth")
			local original_get_type = auth.get_auth_type
			local original_get_key = auth.get_api_key

			auth.get_auth_type = function()
				return "api_key"
			end
			auth.get_api_key = function()
				return "test-key"
			end

			gemini.generate_content("Test prompt", "gemini-2.0-flash", {}, function() end)

			-- Restore original functions
			require("gemini.api.client").request = original_request
			auth.get_auth_type = original_get_type
			auth.get_api_key = original_get_key

			assert.is_not_nil(captured_body)
			assert.is_table(captured_body.contents)
			assert.equals(1, #captured_body.contents)
			assert.equals("user", captured_body.contents[1].role)
			assert.equals("Test prompt", captured_body.contents[1].parts[1].text)
		end)

		it("builds request with generation config", function()
			local captured_body = nil
			local original_request = require("gemini.api.client").request

			require("gemini.api.client").request = function(url, opts, callback)
				captured_body = opts.body
				callback(nil, {
					candidates = {
						{
							content = { parts = { { text = "Response" } } },
							finishReason = "STOP",
						},
					},
				})
			end

			local auth = require("gemini.auth")
			local original_get_type = auth.get_auth_type
			local original_get_key = auth.get_api_key

			auth.get_auth_type = function()
				return "api_key"
			end
			auth.get_api_key = function()
				return "test-key"
			end

			gemini.generate_content("Test", "gemini-2.0-flash", {
				temperature = 0.9,
				top_p = 0.8,
				max_tokens = 2048,
			}, function() end)

			require("gemini.api.client").request = original_request
			auth.get_auth_type = original_get_type
			auth.get_api_key = original_get_key

			assert.is_not_nil(captured_body)
			assert.is_not_nil(captured_body.generationConfig)
			assert.equals(0.9, captured_body.generationConfig.temperature)
			assert.equals(0.8, captured_body.generationConfig.topP)
			assert.equals(2048, captured_body.generationConfig.maxOutputTokens)
		end)
	end)

	describe("authentication handling", function()
		it("returns error when not authenticated", function()
			local callback_err = nil
			local auth = require("gemini.auth")
			local original_get_type = auth.get_auth_type

			auth.get_auth_type = function()
				return nil
			end

			gemini.generate_content("Test", "gemini-2.0-flash", {}, function(err, _)
				callback_err = err
			end)

			auth.get_auth_type = original_get_type

			assert.is_not_nil(callback_err)
			assert.is_true(callback_err.message:match("Not authenticated") ~= nil)
		end)
	end)

	describe("response parsing", function()
		it("extracts text from valid response", function()
			local callback_err, callback_response = nil, nil
			local original_request = require("gemini.api.client").request

			require("gemini.api.client").request = function(url, opts, callback)
				callback(nil, {
					candidates = {
						{
							content = {
								parts = {
									{ text = "First part " },
									{ text = "Second part" },
								},
							},
							finishReason = "STOP",
						},
					},
				})
			end

			local auth = require("gemini.auth")
			local original_get_type = auth.get_auth_type
			local original_get_key = auth.get_api_key

			auth.get_auth_type = function()
				return "api_key"
			end
			auth.get_api_key = function()
				return "test-key"
			end

			gemini.generate_content("Test", "gemini-2.0-flash", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			require("gemini.api.client").request = original_request
			auth.get_auth_type = original_get_type
			auth.get_api_key = original_get_key

			assert.is_nil(callback_err)
			assert.is_not_nil(callback_response)
			assert.equals("First part Second part", callback_response.text)
			assert.equals("STOP", callback_response.finish_reason)
		end)

		it("handles error response from API", function()
			local callback_err, callback_response = nil, nil
			local original_request = require("gemini.api.client").request

			require("gemini.api.client").request = function(url, opts, callback)
				callback(nil, {
					error = {
						message = "API quota exceeded",
					},
				})
			end

			local auth = require("gemini.auth")
			local original_get_type = auth.get_auth_type
			local original_get_key = auth.get_api_key

			auth.get_auth_type = function()
				return "api_key"
			end
			auth.get_api_key = function()
				return "test-key"
			end

			gemini.generate_content("Test", "gemini-2.0-flash", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			require("gemini.api.client").request = original_request
			auth.get_auth_type = original_get_type
			auth.get_api_key = original_get_key

			assert.is_not_nil(callback_err)
			assert.is_nil(callback_response)
			assert.equals("API quota exceeded", callback_err.message)
		end)

		it("handles invalid response format", function()
			local callback_err, callback_response = nil, nil
			local original_request = require("gemini.api.client").request

			require("gemini.api.client").request = function(url, opts, callback)
				callback(nil, { unexpected = "format" })
			end

			local auth = require("gemini.auth")
			local original_get_type = auth.get_auth_type
			local original_get_key = auth.get_api_key

			auth.get_auth_type = function()
				return "api_key"
			end
			auth.get_api_key = function()
				return "test-key"
			end

			gemini.generate_content("Test", "gemini-2.0-flash", {}, function(err, response)
				callback_err = err
				callback_response = response
			end)

			require("gemini.api.client").request = original_request
			auth.get_auth_type = original_get_type
			auth.get_api_key = original_get_key

			assert.is_not_nil(callback_err)
			assert.is_nil(callback_response)
			assert.equals("Invalid response format", callback_err.message)
		end)
	end)
end)
