---@mod gemini.util.async Async utilities
---@brief [[
--- Provides async/await patterns for non-blocking operations.
---@brief ]]

local M = {}

--- Create a debounced function
---@param fn function Function to debounce
---@param ms number Delay in milliseconds
---@return function debounced Debounced function
---@return function cancel Cancel function
function M.debounce(fn, ms)
	local timer = vim.uv.new_timer()
	local cancelled = false

	local function debounced(...)
		local args = { ... }
		cancelled = false
		timer:stop()
		timer:start(ms, 0, function()
			if not cancelled then
				vim.schedule(function()
					fn(unpack(args))
				end)
			end
		end)
	end

	local function cancel()
		cancelled = true
		timer:stop()
	end

	return debounced, cancel
end

--- Create a throttled function
---@param fn function Function to throttle
---@param ms number Minimum interval in milliseconds
---@return function throttled Throttled function
function M.throttle(fn, ms)
	local last_call = 0

	return function(...)
		local now = vim.uv.now()
		if now - last_call >= ms then
			last_call = now
			fn(...)
		end
	end
end

--- Run a function asynchronously using vim.schedule
---@param fn function Function to run
function M.schedule(fn)
	vim.schedule(fn)
end

--- Run a function after a delay
---@param ms number Delay in milliseconds
---@param fn function Function to run
---@return uv_timer_t timer Timer handle
function M.defer(ms, fn)
	local timer = vim.uv.new_timer()
	timer:start(ms, 0, function()
		timer:stop()
		timer:close()
		vim.schedule(fn)
	end)
	return timer
end

--- Create an async queue for sequential processing
---@return table queue Queue object
function M.queue()
	local queue = {
		items = {},
		processing = false,
	}

	function queue:push(fn)
		table.insert(self.items, fn)
		self:process()
	end

	function queue:process()
		if self.processing or #self.items == 0 then
			return
		end

		self.processing = true
		local fn = table.remove(self.items, 1)

		fn(function()
			self.processing = false
			self:process()
		end)
	end

	return queue
end

return M
