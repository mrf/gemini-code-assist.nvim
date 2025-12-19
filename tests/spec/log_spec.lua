---@diagnostic disable: undefined-global
-- Tests for gemini.util.log module

-- Fresh require each test to reset state
local function fresh_log()
	package.loaded["gemini.util.log"] = nil
	return require("gemini.util.log")
end

describe("gemini.util.log", function()
	local log
	local test_log_file
	local notifications = {}
	local original_notify

	before_each(function()
		log = fresh_log()
		test_log_file = "/tmp/gemini-test-log-" .. os.time() .. ".log"
		notifications = {}

		-- Mock vim.notify to capture notifications
		original_notify = vim.notify
		vim.notify = function(msg, level)
			table.insert(notifications, { msg = msg, level = level })
		end
	end)

	after_each(function()
		log.close()
		vim.notify = original_notify

		-- Clean up test log file
		if vim.fn.filereadable(test_log_file) == 1 then
			vim.fn.delete(test_log_file)
		end
	end)

	describe("setup", function()
		it("accepts nil config", function()
			assert.has_no.errors(function()
				log.setup(nil)
			end)
		end)

		it("accepts empty config", function()
			assert.has_no.errors(function()
				log.setup({})
			end)
		end)

		it("sets log level", function()
			log.setup({ level = "debug" })
			assert.equals("debug", log._config.level)
		end)

		it("creates log file when configured", function()
			log.setup({ level = "debug", file = test_log_file })
			log.debug("test message")

			assert.equals(1, vim.fn.filereadable(test_log_file))
		end)
	end)

	describe("log levels", function()
		describe("with debug level", function()
			before_each(function()
				log.setup({ level = "debug", file = test_log_file })
			end)

			it("logs debug messages", function()
				log.debug("debug message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
				assert.is_true(content[1]:match("DEBUG") ~= nil)
			end)

			it("logs info messages", function()
				log.info("info message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
				assert.is_true(content[1]:match("INFO") ~= nil)
			end)

			it("logs warn messages", function()
				log.warn("warn message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
				assert.is_true(content[1]:match("WARN") ~= nil)
			end)

			it("logs error messages", function()
				log.error("error message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
				assert.is_true(content[1]:match("ERROR") ~= nil)
			end)
		end)

		describe("with info level", function()
			before_each(function()
				log.setup({ level = "info", file = test_log_file })
			end)

			it("does not log debug messages", function()
				log.debug("debug message")
				local content = vim.fn.readfile(test_log_file)
				assert.equals(0, #content)
			end)

			it("logs info messages", function()
				log.info("info message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
			end)
		end)

		describe("with warn level", function()
			before_each(function()
				log.setup({ level = "warn", file = test_log_file })
			end)

			it("does not log debug messages", function()
				log.debug("debug message")
				local content = vim.fn.readfile(test_log_file)
				assert.equals(0, #content)
			end)

			it("does not log info messages", function()
				log.info("info message")
				local content = vim.fn.readfile(test_log_file)
				assert.equals(0, #content)
			end)

			it("logs warn messages", function()
				log.warn("warn message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
			end)

			it("logs error messages", function()
				log.error("error message")
				local content = vim.fn.readfile(test_log_file)
				assert.is_true(#content > 0)
			end)
		end)

		describe("with error level", function()
			before_each(function()
				log.setup({ level = "error", file = test_log_file })
			end)

			it("only logs error messages", function()
				log.debug("debug")
				log.info("info")
				log.warn("warn")
				local content = vim.fn.readfile(test_log_file)
				assert.equals(0, #content)

				log.error("error")
				content = vim.fn.readfile(test_log_file)
				assert.equals(1, #content)
			end)
		end)
	end)

	describe("message formatting", function()
		before_each(function()
			log.setup({ level = "debug", file = test_log_file })
		end)

		it("includes timestamp", function()
			log.debug("test")
			local content = vim.fn.readfile(test_log_file)
			-- Match timestamp pattern: [YYYY-MM-DD HH:MM:SS]
			assert.is_true(content[1]:match("%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%]") ~= nil)
		end)

		it("includes Gemini prefix", function()
			log.debug("test")
			local content = vim.fn.readfile(test_log_file)
			assert.is_true(content[1]:match("%[Gemini%]") ~= nil)
		end)

		it("supports format arguments", function()
			log.debug("value: %d, string: %s", 42, "hello")
			local content = vim.fn.readfile(test_log_file)
			assert.is_true(content[1]:match("value: 42") ~= nil)
			assert.is_true(content[1]:match("string: hello") ~= nil)
		end)
	end)

	describe("vim.notify integration", function()
		before_each(function()
			log.setup({ level = "debug" })
		end)

		it("info sends vim.notify with INFO level", function()
			log.info("info test")
			assert.equals(1, #notifications)
			assert.equals(vim.log.levels.INFO, notifications[1].level)
		end)

		it("warn sends vim.notify with WARN level", function()
			log.warn("warn test")
			assert.equals(1, #notifications)
			assert.equals(vim.log.levels.WARN, notifications[1].level)
		end)

		it("error sends vim.notify with ERROR level", function()
			log.error("error test")
			assert.equals(1, #notifications)
			assert.equals(vim.log.levels.ERROR, notifications[1].level)
		end)

		it("debug does not send vim.notify", function()
			log.debug("debug test")
			assert.equals(0, #notifications)
		end)

		it("warn and error include Gemini prefix in notification", function()
			log.warn("test warn")
			assert.is_true(notifications[1].msg:match("^Gemini:") ~= nil)

			log.error("test error")
			assert.is_true(notifications[2].msg:match("^Gemini:") ~= nil)
		end)
	end)

	describe("close", function()
		it("can be called without file open", function()
			log.setup({ level = "debug" })
			assert.has_no.errors(function()
				log.close()
			end)
		end)

		it("closes log file when open", function()
			log.setup({ level = "debug", file = test_log_file })
			log.debug("before close")
			log.close()

			-- File should exist and have content
			assert.equals(1, vim.fn.filereadable(test_log_file))
		end)

		it("can be called multiple times", function()
			log.setup({ level = "debug", file = test_log_file })
			assert.has_no.errors(function()
				log.close()
				log.close()
				log.close()
			end)
		end)
	end)
end)
