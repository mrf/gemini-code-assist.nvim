---@mod gemini.util.log Logging utilities
---@brief [[
--- Provides logging functionality with configurable levels.
---@brief ]]

---@class GeminiLog
local M = {}

---@type GeminiLogConfig
M._config = {
	level = "warn",
	file = nil,
}

local levels = {
	debug = 1,
	info = 2,
	warn = 3,
	error = 4,
}

---@type file*?
local log_file = nil

--- Setup logging with configuration
---@param config? GeminiLogConfig
function M.setup(config)
	M._config = vim.tbl_extend("force", M._config, config or {})

	-- Open log file if configured
	if M._config.file then
		log_file = io.open(M._config.file, "a")
	end
end

--- Check if a level should be logged
---@param level string
---@return boolean
local function should_log(level)
	return levels[level] >= levels[M._config.level]
end

--- Format a log message
---@param level string
---@param msg string
---@return string
local function format_message(level, msg)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	return string.format("[%s] [Gemini] [%s] %s", timestamp, level:upper(), msg)
end

--- Write to log file
---@param formatted string
local function write_to_file(formatted)
	if log_file then
		log_file:write(formatted .. "\n")
		log_file:flush()
	end
end

--- Log a debug message
---@param msg string
---@param ... any Format arguments
function M.debug(msg, ...)
	if should_log("debug") then
		local formatted = format_message("debug", string.format(msg, ...))
		write_to_file(formatted)
	end
end

--- Log an info message
---@param msg string
---@param ... any Format arguments
function M.info(msg, ...)
	if should_log("info") then
		local formatted = format_message("info", string.format(msg, ...))
		write_to_file(formatted)
		vim.notify(string.format(msg, ...), vim.log.levels.INFO)
	end
end

--- Log a warning message
---@param msg string
---@param ... any Format arguments
function M.warn(msg, ...)
	if should_log("warn") then
		local formatted = format_message("warn", string.format(msg, ...))
		write_to_file(formatted)
		vim.notify("Gemini: " .. string.format(msg, ...), vim.log.levels.WARN)
	end
end

--- Log an error message
---@param msg string
---@param ... any Format arguments
function M.error(msg, ...)
	if should_log("error") then
		local formatted = format_message("error", string.format(msg, ...))
		write_to_file(formatted)
		vim.notify("Gemini: " .. string.format(msg, ...), vim.log.levels.ERROR)
	end
end

--- Close the log file
function M.close()
	if log_file then
		log_file:close()
		log_file = nil
	end
end

return M
