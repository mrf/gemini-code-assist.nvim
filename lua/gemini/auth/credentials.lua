---@mod gemini.auth.credentials Credential storage
---@brief [[
--- Handles storage and retrieval of API key credentials.
---@brief ]]

local M = {}

local path = require("gemini.util.path")

--- Get the credentials file path
---@return string
function M.get_path()
	local config_dir = path.get_config_dir()
	return path.join(config_dir, "credentials.json")
end

--- Load credentials from file
---@return table?
function M.load()
	local creds_path = M.get_path()

	if not path.is_file(creds_path) then
		return nil
	end

	local file = io.open(creds_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		return nil
	end

	return data
end

--- Save credentials to file
---@param credentials table
---@return boolean success
function M.save(credentials)
	local config_dir = path.get_config_dir()
	if not path.ensure_dir(config_dir) then
		return false
	end

	local creds_path = M.get_path()
	local file = io.open(creds_path, "w")
	if not file then
		return false
	end

	local content = vim.json.encode(credentials)
	file:write(content)
	file:close()

	-- Set restrictive permissions (Unix only)
	if vim.fn.has("unix") == 1 then
		vim.fn.system({ "chmod", "600", creds_path })
	end

	return true
end

--- Clear stored credentials
---@return boolean success
function M.clear()
	local creds_path = M.get_path()
	if path.is_file(creds_path) then
		return vim.fn.delete(creds_path) == 0
	end
	return true
end

return M
