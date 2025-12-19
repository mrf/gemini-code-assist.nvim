---@mod gemini.ui.statusline Statusline component
---@brief [[
--- Provides a statusline component for Gemini status.
---@brief ]]

local M = {}

---@type string
M._status = "ok"

---@type string?
M._message = nil

--- Get the statusline text
---@return string
function M.get()
  local gemini = require("gemini")

  if not gemini.is_initialized() then
    return ""
  end

  local config = gemini.get_config()
  local icons = config.ui and config.ui.icons or {}

  local auth = require("gemini.auth")
  if not auth.is_authenticated() then
    return (icons.error or "") .. " Gemini: Not authenticated"
  end

  local suggestion = require("gemini.suggestion")
  if not suggestion.is_enabled() then
    return (icons.suggestion or "") .. " Gemini: Disabled"
  end

  if M._status == "loading" then
    return (icons.loading or "") .. " Gemini: Loading..."
  end

  if M._status == "error" then
    return (icons.error or "") .. " Gemini: " .. (M._message or "Error")
  end

  return (icons.suggestion or "") .. " Gemini"
end

--- Set status
---@param status string
---@param message? string
function M.set(status, message)
  M._status = status
  M._message = message
end

--- Get status for use in statusline
---@return string
function M.component()
  return M.get()
end

return M
