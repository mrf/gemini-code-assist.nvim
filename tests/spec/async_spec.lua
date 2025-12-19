---@diagnostic disable: undefined-global
-- Tests for gemini.util.async module

local async = require("gemini.util.async")

describe("gemini.util.async", function()
	describe("debounce", function()
		it("returns a function and cancel function", function()
			local fn = function() end
			local debounced, cancel = async.debounce(fn, 100)
			assert.is_function(debounced)
			assert.is_function(cancel)
		end)

		it("does not call function immediately", function()
			local call_count = 0
			local fn = function()
				call_count = call_count + 1
			end

			local debounced, _ = async.debounce(fn, 50)
			debounced()

			-- Should not be called immediately
			assert.equals(0, call_count)
		end)

		it("cancel prevents function from being called", function()
			local call_count = 0
			local fn = function()
				call_count = call_count + 1
			end

			local debounced, cancel = async.debounce(fn, 50)
			debounced()
			cancel()

			-- Wait for timer to potentially fire
			vim.wait(100, function()
				return false
			end)

			assert.equals(0, call_count)
		end)

		it("calling multiple times only fires once after delay", function()
			local call_count = 0
			local fn = function()
				call_count = call_count + 1
			end

			local debounced, _ = async.debounce(fn, 50)
			debounced()
			debounced()
			debounced()

			-- Wait for the debounced function to fire
			vim.wait(200, function()
				return call_count > 0
			end)

			assert.equals(1, call_count)
		end)

		it("passes arguments to debounced function", function()
			local received_args = nil
			local fn = function(a, b)
				received_args = { a, b }
			end

			local debounced, _ = async.debounce(fn, 50)
			debounced("hello", "world")

			vim.wait(200, function()
				return received_args ~= nil
			end)

			assert.same({ "hello", "world" }, received_args)
		end)
	end)

	describe("throttle", function()
		it("returns a function", function()
			local fn = function() end
			local throttled = async.throttle(fn, 100)
			assert.is_function(throttled)
		end)

		it("calls function immediately on first call", function()
			local call_count = 0
			local fn = function()
				call_count = call_count + 1
			end

			local throttled = async.throttle(fn, 100)
			throttled()

			assert.equals(1, call_count)
		end)

		it("throttles subsequent calls within interval", function()
			local call_count = 0
			local fn = function()
				call_count = call_count + 1
			end

			local throttled = async.throttle(fn, 100)
			throttled()
			throttled()
			throttled()

			-- Only first call should have gone through
			assert.equals(1, call_count)
		end)

		it("allows call after interval has passed", function()
			local call_count = 0
			local fn = function()
				call_count = call_count + 1
			end

			local throttled = async.throttle(fn, 50)
			throttled()

			-- Wait for interval to pass
			vim.wait(100, function()
				return false
			end)

			throttled()
			assert.equals(2, call_count)
		end)

		it("passes arguments to throttled function", function()
			local received_args = nil
			local fn = function(a, b)
				received_args = { a, b }
			end

			local throttled = async.throttle(fn, 50)
			throttled("foo", "bar")

			assert.same({ "foo", "bar" }, received_args)
		end)
	end)

	describe("schedule", function()
		it("schedules function for later execution", function()
			local executed = false
			async.schedule(function()
				executed = true
			end)

			-- Should not execute synchronously
			assert.is_false(executed)

			-- Wait for scheduled function
			vim.wait(100, function()
				return executed
			end)

			assert.is_true(executed)
		end)
	end)

	describe("defer", function()
		it("returns a timer handle", function()
			local timer = async.defer(100, function() end)
			assert.is_userdata(timer)
			timer:stop()
			timer:close()
		end)

		it("executes function after delay", function()
			local executed = false
			local timer = async.defer(50, function()
				executed = true
			end)

			-- Should not execute immediately
			assert.is_false(executed)

			-- Wait for deferred function
			vim.wait(200, function()
				return executed
			end)

			assert.is_true(executed)
		end)

		it("does not execute before delay", function()
			local executed = false
			local timer = async.defer(200, function()
				executed = true
			end)

			-- Check after short wait
			vim.wait(50, function()
				return false
			end)

			assert.is_false(executed)

			-- Clean up
			timer:stop()
			timer:close()
		end)
	end)

	describe("queue", function()
		it("returns a queue object", function()
			local q = async.queue()
			assert.is_table(q)
			assert.is_function(q.push)
			assert.is_function(q.process)
		end)

		it("processes items in order", function()
			local results = {}
			local q = async.queue()

			q:push(function(done)
				table.insert(results, 1)
				done()
			end)

			q:push(function(done)
				table.insert(results, 2)
				done()
			end)

			q:push(function(done)
				table.insert(results, 3)
				done()
			end)

			-- Wait for queue to process
			vim.wait(200, function()
				return #results == 3
			end)

			assert.same({ 1, 2, 3 }, results)
		end)

		it("waits for done callback before processing next", function()
			local results = {}
			local q = async.queue()

			q:push(function(done)
				table.insert(results, "first_start")
				vim.defer_fn(function()
					table.insert(results, "first_end")
					done()
				end, 50)
			end)

			q:push(function(done)
				table.insert(results, "second_start")
				done()
			end)

			-- Wait for queue to process
			vim.wait(300, function()
				return #results >= 3
			end)

			-- First should complete before second starts
			local first_end_idx = nil
			local second_start_idx = nil
			for i, v in ipairs(results) do
				if v == "first_end" then
					first_end_idx = i
				end
				if v == "second_start" then
					second_start_idx = i
				end
			end

			if first_end_idx and second_start_idx then
				assert.is_true(first_end_idx < second_start_idx)
			end
		end)

		it("can push items while processing", function()
			local results = {}
			local q = async.queue()

			q:push(function(done)
				table.insert(results, 1)
				-- Push another item while processing
				q:push(function(done2)
					table.insert(results, 3)
					done2()
				end)
				done()
			end)

			q:push(function(done)
				table.insert(results, 2)
				done()
			end)

			-- Wait for queue to process
			vim.wait(300, function()
				return #results == 3
			end)

			assert.equals(3, #results)
		end)
	end)
end)
