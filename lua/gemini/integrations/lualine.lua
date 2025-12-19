---@mod gemini.integrations.lualine Lualine integration
---@brief [[
--- Provides a lualine component for Gemini status.
---@brief ]]

local M = {}

---@class LualineGeminiComponent
---@field status string Current status ("ok", "loading", "error", "disabled")
---@field message string? Status message
local component = {
  status = "ok",
  message = nil,
}

--- Get the status text
---@return string
function component:get_status_text()
  local gemini = require("gemini")
  local suggestion = require("gemini.suggestion")
  local auth = require("gemini.auth")

  if not gemini.is_initialized() then
    return ""
  end

  local config = gemini.get_config()
  local icons = config.ui and config.ui.icons or {}

  if not auth.is_authenticated() then
    return (icons.error or "") .. " Not authenticated"
  end

  if not suggestion.is_enabled() then
    return (icons.suggestion or "") .. " Disabled"
  end

  if self.status == "loading" then
    return (icons.loading or "") .. " Loading..."
  end

  if self.status == "error" then
    return (icons.error or "") .. " " .. (self.message or "Error")
  end

  return (icons.suggestion or "") .. " Gemini"
end

--- Get the status color
---@return table
function component:get_color()
  if self.status == "loading" then
    return { fg = "#61afef" }
  elseif self.status == "error" then
    return { fg = "#e06c75" }
  end
  return { fg = "#98c379" }
end

--- Create lualine component
---@return function
function M.create()
  return function()
    return component:get_status_text()
  end
end

--- Create lualine component with color
---@return table
function M.create_with_color()
  return {
    M.create(),
    color = function()
      return component:get_color()
    end,
  }
end

--- Set status
---@param status string
---@param message? string
function M.set_status(status, message)
  component.status = status
  component.message = message
end

return M
