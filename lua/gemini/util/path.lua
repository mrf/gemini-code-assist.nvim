---@mod gemini.util.path Path utilities
---@brief [[
--- Provides path manipulation and workspace detection utilities.
---@brief ]]

local M = {}

--- Path separator for the current OS
M.sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"

--- Join path components
---@param ... string Path components
---@return string
function M.join(...)
  return table.concat({ ... }, M.sep)
end

--- Get the directory name of a path
---@param path string
---@return string
function M.dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

--- Get the base name of a path
---@param path string
---@return string
function M.basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

--- Get the file extension
---@param path string
---@return string
function M.extension(path)
  return vim.fn.fnamemodify(path, ":e")
end

--- Check if a path exists
---@param path string
---@return boolean
function M.exists(path)
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

--- Check if a path is a directory
---@param path string
---@return boolean
function M.is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

--- Check if a path is a file
---@param path string
---@return boolean
function M.is_file(path)
  return vim.fn.filereadable(path) == 1
end

--- Root markers for workspace detection
M.root_markers = {
  ".git",
  ".gitignore",
  "package.json",
  "Cargo.toml",
  "go.mod",
  "pyproject.toml",
  "setup.py",
  "Makefile",
  "CMakeLists.txt",
  ".project",
  "pom.xml",
  "build.gradle",
}

--- Find the workspace root starting from a path
---@param start_path? string Starting path (defaults to current buffer)
---@return string? root Workspace root or nil
function M.find_root(start_path)
  start_path = start_path or vim.api.nvim_buf_get_name(0)

  if start_path == "" then
    start_path = vim.fn.getcwd()
  end

  -- Try LSP root first
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end

  -- Fall back to marker detection
  local path = start_path
  while path and path ~= "" and path ~= M.sep do
    for _, marker in ipairs(M.root_markers) do
      local marker_path = M.join(path, marker)
      if M.exists(marker_path) then
        return path
      end
    end
    local parent = M.dirname(path)
    if parent == path then
      break
    end
    path = parent
  end

  -- Fall back to current working directory
  return vim.fn.getcwd()
end

--- Get the config directory for the plugin
---@return string
function M.get_config_dir()
  local config_home = vim.env.XDG_CONFIG_HOME or M.join(vim.env.HOME, ".config")
  return M.join(config_home, "gemini-code-assist")
end

--- Get the data directory for the plugin
---@return string
function M.get_data_dir()
  local data_home = vim.env.XDG_DATA_HOME or M.join(vim.env.HOME, ".local", "share")
  return M.join(data_home, "gemini-code-assist")
end

--- Ensure a directory exists
---@param path string
---@return boolean success
function M.ensure_dir(path)
  if not M.is_directory(path) then
    return vim.fn.mkdir(path, "p") == 1
  end
  return true
end

return M
