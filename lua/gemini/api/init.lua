---@mod gemini.api API client module
---@brief [[
--- Handles communication with Google's Gemini APIs.
---@brief ]]

local M = {}

--- Get the plugin config
---@return GeminiConfig
local function get_config()
  return require("gemini").get_config()
end

--- Generate content (non-streaming)
---@param prompt string|table Prompt or messages
---@param opts? table Options (model, temperature, etc.)
---@param callback function Callback with response
function M.generate(prompt, opts, callback)
  local gemini = require("gemini.api.gemini")
  local config = get_config()

  opts = opts or {}
  local model = opts.model or (config.model and config.model.completion) or "gemini-2.0-flash"

  gemini.generate_content(prompt, model, opts, callback)
end

--- Generate content with streaming
---@param prompt string|table Prompt or messages
---@param opts? table Options
---@param on_chunk function Callback for each chunk
---@param on_done function Callback when complete
function M.stream(prompt, opts, on_chunk, on_done)
  local gemini = require("gemini.api.gemini")
  local config = get_config()

  opts = opts or {}
  local model = opts.model or (config.model and config.model.completion) or "gemini-2.0-flash"

  gemini.stream_content(prompt, model, opts, on_chunk, on_done)
end

--- Get code completion
---@param context table Buffer context
---@param callback function Callback with completions
function M.complete(context, callback)
  local config = get_config()
  local prompt = M._build_completion_prompt(context)

  M.generate(prompt, {
    model = config.model and config.model.completion or "gemini-2.0-flash",
    temperature = 0.2,
    max_tokens = config.suggestion and config.suggestion.max_tokens or 256,
  }, callback)
end

--- Build completion prompt from context
---@param context table
---@return string
function M._build_completion_prompt(context)
  local parts = {
    "You are an expert code completion assistant.",
    "Complete the code at the cursor position.",
    "Provide only the code completion, no explanations or markdown.",
    "",
    "File: " .. (context.filename or "unknown"),
    "Language: " .. (context.filetype or "text"),
    "",
    "```" .. (context.filetype or ""),
    context.prefix or "",
    "-- CURSOR --",
    context.suffix or "",
    "```",
    "",
    "Complete the code at CURSOR:",
  }
  return table.concat(parts, "\n")
end

return M
