---@mod gemini.chat.history Chat history persistence
---@brief [[
--- Handles saving and loading chat history.
---@brief ]]

local M = {}

local path = require("gemini.util.path")

--- Get the history file path
---@return string
function M.get_path()
  local data_dir = path.get_data_dir()
  return path.join(data_dir, "chat_history.json")
end

--- Save chat history
---@param messages table[]
---@return boolean success
function M.save(messages)
  local data_dir = path.get_data_dir()
  if not path.ensure_dir(data_dir) then
    return false
  end

  local history_path = M.get_path()
  local file = io.open(history_path, "w")
  if not file then
    return false
  end

  local data = {
    version = 1,
    updated_at = os.time(),
    messages = messages,
  }

  file:write(vim.json.encode(data))
  file:close()
  return true
end

--- Load chat history
---@return table[]
function M.load()
  local history_path = M.get_path()

  if not path.is_file(history_path) then
    return {}
  end

  local file = io.open(history_path, "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data.messages then
    return {}
  end

  return data.messages
end

--- Clear chat history
---@return boolean success
function M.clear()
  local history_path = M.get_path()
  if path.is_file(history_path) then
    return vim.fn.delete(history_path) == 0
  end
  return true
end

return M
