---@mod gemini.util Utility modules
---@brief [[
--- Common utilities used across the plugin.
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

--- Setup utilities with configuration
---@param config GeminiConfig
function M.setup(config)
  M._config = config
  M.log = require("gemini.util.log")
  M.log.setup(config.log)
  M.async = require("gemini.util.async")
  M.path = require("gemini.util.path")
end

--- Get the log module
---@return GeminiLog
function M.get_log()
  return M.log
end

return M
