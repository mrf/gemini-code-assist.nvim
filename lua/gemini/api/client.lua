---@mod gemini.api.client HTTP client wrapper
---@brief [[
--- Provides HTTP request functionality using curl or plenary.
---@brief ]]

local M = {}

--- Make an HTTP request
---@param url string Request URL
---@param opts table Request options
---@param callback function Callback with response
function M.request(url, opts, callback)
	opts = opts or {}
	local method = opts.method or "GET"
	local headers = opts.headers or {}
	local body = opts.body

	-- Build curl command
	local cmd = { "curl", "-s", "-X", method }

	-- Add headers
	for key, value in pairs(headers) do
		table.insert(cmd, "-H")
		table.insert(cmd, key .. ": " .. value)
	end

	-- Add body
	if body then
		table.insert(cmd, "-d")
		if type(body) == "table" then
			table.insert(cmd, vim.json.encode(body))
		else
			table.insert(cmd, body)
		end
	end

	-- Add URL
	table.insert(cmd, url)

	-- Execute request
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				local response = table.concat(data, "\n")
				vim.schedule(function()
					local ok, parsed = pcall(vim.json.decode, response)
					if ok then
						callback(nil, parsed)
					else
						callback(nil, { raw = response })
					end
				end)
			end
		end,
		on_stderr = function(_, data)
			if data and data[1] and data[1] ~= "" then
				vim.schedule(function()
					callback({ message = table.concat(data, "\n") }, nil)
				end)
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.schedule(function()
					callback({ message = "Request failed with code " .. code }, nil)
				end)
			end
		end,
	})
end

--- Make a streaming HTTP request
---@param url string Request URL
---@param opts table Request options
---@param on_chunk function Callback for each chunk
---@param on_done function Callback when complete
function M.stream(url, opts, on_chunk, on_done)
	opts = opts or {}
	local method = opts.method or "POST"
	local headers = opts.headers or {}
	local body = opts.body

	-- Build curl command
	local cmd = { "curl", "-s", "-N", "-X", method }

	-- Add headers
	for key, value in pairs(headers) do
		table.insert(cmd, "-H")
		table.insert(cmd, key .. ": " .. value)
	end

	-- Add body
	if body then
		table.insert(cmd, "-d")
		if type(body) == "table" then
			table.insert(cmd, vim.json.encode(body))
		else
			table.insert(cmd, body)
		end
	end

	-- Add URL
	table.insert(cmd, url)

	-- Execute streaming request
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						vim.schedule(function()
							on_chunk(line)
						end)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data and data[1] and data[1] ~= "" then
				vim.schedule(function()
					on_chunk(nil, table.concat(data, "\n"))
				end)
			end
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				on_done(code == 0)
			end)
		end,
	})
end

return M
