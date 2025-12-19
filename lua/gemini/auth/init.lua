---@mod gemini.auth Authentication module
---@brief [[
--- Handles authentication with Google Gemini API.
--- Supports:
---   1. GEMINI_API_KEY environment variable
---   2. API key in config
---   3. Gemini CLI OAuth credentials (~/.gemini/oauth_creds.json)
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

---@type boolean
M._authenticated = false

---@type string?
M._api_key = nil

---@type table?
M._oauth_creds = nil

--- Setup authentication module
---@param config GeminiConfig
function M.setup(config)
	M._config = config
	M._load_credentials()
end

--- Load credentials from various sources
--- Priority: config api_key > env var > saved credentials > Gemini CLI OAuth
function M._load_credentials()
	-- 1. Check config
	if M._config and M._config.auth and M._config.auth.api_key then
		M._api_key = M._config.auth.api_key
		M._authenticated = true
		return
	end

	-- 2. Check environment variable
	if vim.env.GEMINI_API_KEY then
		M._api_key = vim.env.GEMINI_API_KEY
		M._authenticated = true
		return
	end

	-- 3. Check saved credentials file
	local credentials = require("gemini.auth.credentials")
	local saved = credentials.load()
	if saved and saved.api_key then
		M._api_key = saved.api_key
		M._authenticated = true
		return
	end

	-- 4. Check for Gemini CLI OAuth credentials
	local oauth_creds = M._load_gemini_cli_oauth()
	if oauth_creds then
		M._oauth_creds = oauth_creds
		M._authenticated = true
		return
	end
end

--- Load OAuth credentials from Gemini CLI
---@return table?
function M._load_gemini_cli_oauth()
	local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")

	if vim.fn.filereadable(oauth_path) ~= 1 then
		return nil
	end

	local file = io.open(oauth_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok or not data then
		return nil
	end

	-- Check if we have a valid access token
	if not data.access_token then
		return nil
	end

	-- Check if token is expired
	if data.expiry_date then
		local expiry = tonumber(data.expiry_date)
		if expiry and expiry < os.time() * 1000 then
			-- Token expired, but we might have refresh token
			-- For now, just warn - full refresh would require OAuth flow
			if data.refresh_token then
				-- TODO: Implement token refresh
				vim.notify("Gemini: OAuth token expired. Run 'gemini login' to refresh.", vim.log.levels.WARN)
			end
			return nil
		end
	end

	return data
end

--- Check if authenticated
---@return boolean
function M.is_authenticated()
	return M._authenticated and (M._api_key ~= nil or M._oauth_creds ~= nil)
end

--- Get the API key (if using API key auth)
---@return string?
function M.get_api_key()
	return M._api_key
end

--- Get OAuth access token (if using Gemini CLI OAuth)
---@return string?
function M.get_access_token()
	if M._oauth_creds then
		return M._oauth_creds.access_token
	end
	return nil
end

--- Get auth type
---@return "api_key"|"oauth"|nil
function M.get_auth_type()
	if M._api_key then
		return "api_key"
	elseif M._oauth_creds then
		return "oauth"
	end
	return nil
end

--- Authenticate (prompt for API key if not set)
function M.authenticate()
	if M.is_authenticated() then
		local auth_type = M.get_auth_type()
		if auth_type == "oauth" then
			vim.notify("Gemini: Using Gemini CLI OAuth credentials", vim.log.levels.INFO)
		else
			vim.notify("Gemini: Already authenticated with API key", vim.log.levels.INFO)
		end
		return
	end

	-- Check if gemini CLI is installed
	if vim.fn.executable("gemini") == 1 then
		vim.ui.select(
			{ "Enter API key manually", "Login with Gemini CLI (gemini login)" },
			{ prompt = "Choose authentication method:" },
			function(choice)
				if choice == "Login with Gemini CLI (gemini login)" then
					vim.notify("Run 'gemini login' in your terminal, then restart Neovim", vim.log.levels.INFO)
				elseif choice == "Enter API key manually" then
					M._prompt_api_key()
				end
			end
		)
	else
		M._prompt_api_key()
	end
end

--- Prompt for API key
function M._prompt_api_key()
	vim.ui.input({
		prompt = "Enter Gemini API key (from aistudio.google.com/apikey): ",
		default = "",
	}, function(input)
		if input and input ~= "" then
			M._api_key = input
			M._authenticated = true

			-- Save to credentials file
			local credentials = require("gemini.auth.credentials")
			credentials.save({ api_key = input })

			vim.notify("Gemini: API key saved", vim.log.levels.INFO)
		else
			vim.notify("Gemini: Authentication cancelled", vim.log.levels.WARN)
		end
	end)
end

--- Sign out and clear credentials
function M.sign_out()
	local credentials = require("gemini.auth.credentials")
	credentials.clear()
	M._api_key = nil
	M._oauth_creds = nil
	M._authenticated = false
	vim.notify("Gemini: Signed out (note: Gemini CLI credentials not affected)", vim.log.levels.INFO)
end

return M
