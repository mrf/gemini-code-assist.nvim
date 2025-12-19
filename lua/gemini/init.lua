---@mod gemini Gemini Code Assist for Neovim
---@brief [[
--- A Neovim plugin for Google's Gemini Code Assist.
--- Provides inline code completions, chat interface, and smart actions.
---@brief ]]

local M = {}

---@class GeminiConfig
---@field auth? GeminiAuthConfig Authentication configuration
---@field model? GeminiModelConfig Model configuration
---@field suggestion? GeminiSuggestionConfig Suggestion settings
---@field chat? GeminiChatConfig Chat settings
---@field actions? GeminiActionsConfig Smart actions settings
---@field exclude? string[] File patterns to exclude
---@field keymaps? GeminiKeymapsConfig Keymap configuration
---@field ui? GeminiUIConfig UI settings
---@field log? GeminiLogConfig Logging settings

---@type GeminiConfig
M.config = {}

---@type boolean
M._initialized = false

--- Setup the plugin with user configuration
---@param opts? GeminiConfig User configuration
function M.setup(opts)
  if M._initialized then
    vim.notify("Gemini: Already initialized", vim.log.levels.WARN)
    return
  end

  local config = require("gemini.config")
  M.config = config.setup(opts or {})

  -- Initialize core modules
  local util = require("gemini.util")
  util.setup(M.config)

  -- Initialize authentication
  require("gemini.auth").setup(M.config)

  -- Register commands
  require("gemini.commands").setup(M.config)

  -- Setup keymaps if enabled
  if M.config.keymaps then
    require("gemini.keymaps").setup(M.config)
  end

  -- Initialize suggestion module if enabled
  if M.config.suggestion and M.config.suggestion.enabled then
    require("gemini.suggestion").setup(M.config)
  end

  -- Initialize chat module if enabled
  if M.config.chat and M.config.chat.enabled then
    require("gemini.chat").setup(M.config)
  end

  -- Initialize actions module if enabled
  if M.config.actions and M.config.actions.enabled then
    require("gemini.actions").setup(M.config)
  end

  M._initialized = true

  util.log.info("Gemini Code Assist initialized")
end

--- Check if the plugin is initialized
---@return boolean
function M.is_initialized()
  return M._initialized
end

--- Get the current configuration
---@return GeminiConfig
function M.get_config()
  return M.config
end

return M
