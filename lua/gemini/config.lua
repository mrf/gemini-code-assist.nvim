---@mod gemini.config Configuration management
---@brief [[
--- Handles plugin configuration with defaults and user overrides.
---@brief ]]

local M = {}

---@class GeminiAuthConfig
---@field api_key? string API key (or use GEMINI_API_KEY env var)

---@class GeminiModelConfig
---@field completion? string Model for completions
---@field chat? string Model for chat
---@field actions? string Model for smart actions

---@class GeminiSuggestionConfig
---@field enabled? boolean Enable suggestions
---@field auto_trigger? boolean Auto-trigger suggestions
---@field debounce_ms? number Debounce delay in milliseconds
---@field max_tokens? number Maximum tokens in response
---@field hide_during_completion? boolean Hide during completion menu
---@field filetypes? table<string, boolean> Filetype enable/disable map

---@class GeminiChatConfig
---@field enabled? boolean Enable chat
---@field window_type? "floating"|"vsplit"|"split"|"tab" Window type
---@field width? number Window width (0-1 for percentage)
---@field height? number Window height (0-1 for percentage)
---@field persist_history? boolean Persist chat history
---@field auto_context? boolean Include context automatically

---@class GeminiActionsConfig
---@field enabled? boolean Enable smart actions
---@field preview_diff? boolean Show diff before applying
---@field auto_apply? boolean Auto-apply without confirmation

---@class GeminiKeymapsConfig
---@field accept? string|false Accept suggestion keymap
---@field accept_word? string|false Accept word keymap
---@field accept_line? string|false Accept line keymap
---@field dismiss? string|false Dismiss suggestion keymap
---@field next? string|false Next suggestion keymap
---@field prev? string|false Previous suggestion keymap
---@field toggle_chat? string|false Toggle chat keymap
---@field generate? string|false Generate code keymap
---@field fix? string|false Fix code keymap
---@field test? string|false Generate test keymap

---@class GeminiUIConfig
---@field suggestion_hl? string Highlight group for suggestions
---@field icons? GeminiIconsConfig Icons configuration

---@class GeminiIconsConfig
---@field suggestion? string Suggestion icon
---@field loading? string Loading icon
---@field error? string Error icon

---@class GeminiLogConfig
---@field level? "debug"|"info"|"warn"|"error" Log level
---@field file? string Log file path

---@type GeminiConfig
local defaults = {
  auth = {
    api_key = nil, -- Uses GEMINI_API_KEY env var if not set
  },

  model = {
    completion = "gemini-2.0-flash",
    chat = "gemini-2.0-flash",
    actions = "gemini-2.0-flash",
  },

  suggestion = {
    enabled = true,
    auto_trigger = true,
    debounce_ms = 150,
    max_tokens = 256,
    hide_during_completion = true,
    filetypes = {
      ["*"] = true,
      gitcommit = false,
      gitrebase = false,
      ["."] = false,
    },
  },

  chat = {
    enabled = true,
    window_type = "floating",
    width = 0.6,
    height = 0.8,
    persist_history = true,
    auto_context = true,
  },

  actions = {
    enabled = true,
    preview_diff = true,
    auto_apply = false,
  },

  exclude = {
    "*.env",
    "*.key",
    "*.pem",
    "secrets/*",
    "node_modules/*",
  },

  keymaps = {
    accept = "<Tab>",
    accept_word = "<C-Right>",
    accept_line = "<C-Down>",
    dismiss = "<C-]>",
    next = "<M-]>",
    prev = "<M-[>",
    toggle_chat = "<leader>gc",
    generate = "<leader>gg",
    fix = "<leader>gf",
    test = "<leader>gt",
  },

  ui = {
    suggestion_hl = "Comment",
    icons = {
      suggestion = "",
      loading = "",
      error = "",
    },
  },

  log = {
    level = "warn",
    file = nil,
  },
}

--- Deep merge two tables
---@param t1 table Base table
---@param t2 table Override table
---@return table
local function deep_merge(t1, t2)
  local result = vim.deepcopy(t1)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

--- Setup configuration with user options
---@param opts? GeminiConfig User configuration
---@return GeminiConfig
function M.setup(opts)
  local config = deep_merge(defaults, opts or {})

  -- Check for API key in environment if not provided
  if not config.auth.api_key then
    config.auth.api_key = vim.env.GEMINI_API_KEY
  end

  return config
end

--- Get default configuration
---@return GeminiConfig
function M.get_defaults()
  return vim.deepcopy(defaults)
end

return M
