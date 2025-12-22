---@diagnostic disable: undefined-global
-- Tests for gemini.auth module

local auth = require("gemini.auth")
local credentials = require("gemini.auth.credentials")

describe("gemini.auth", function()
	-- Save original state before each test
	local original_env_key
	local original_authenticated
	local original_api_key
	local original_oauth_creds
	local original_config

	before_each(function()
		-- Save environment variable
		original_env_key = vim.env.GEMINI_API_KEY
		vim.env.GEMINI_API_KEY = nil

		-- Save auth module state
		original_authenticated = auth._authenticated
		original_api_key = auth._api_key
		original_oauth_creds = auth._oauth_creds
		original_config = auth._config

		-- Reset auth state
		auth._authenticated = false
		auth._api_key = nil
		auth._oauth_creds = nil
		auth._config = nil

		-- Clear credentials file
		credentials.clear()
	end)

	after_each(function()
		-- Restore environment variable
		vim.env.GEMINI_API_KEY = original_env_key

		-- Restore auth state
		auth._authenticated = original_authenticated
		auth._api_key = original_api_key
		auth._oauth_creds = original_oauth_creds
		auth._config = original_config

		-- Clean up credentials file
		credentials.clear()
	end)

	describe("API Key Loading", function()
		describe("from config", function()
			it("loads API key from config when provided", function()
				local config = {
					auth = {
						api_key = "config-test-key",
					},
				}

				auth.setup(config)

				assert.is_true(auth.is_authenticated())
				assert.equals("config-test-key", auth.get_api_key())
				assert.equals("api_key", auth.get_auth_type())
			end)

			it("sets authenticated flag when config has API key", function()
				local config = {
					auth = {
						api_key = "test-key",
					},
				}

				auth.setup(config)

				assert.is_true(auth._authenticated)
			end)

			it("handles config with no auth section", function()
				local config = {}

				auth.setup(config)

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_api_key())
			end)

			it("handles nil config gracefully", function()
				auth.setup(nil)

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_api_key())
			end)
		end)

		describe("from environment variable", function()
			it("loads API key from GEMINI_API_KEY env var", function()
				vim.env.GEMINI_API_KEY = "env-test-key"

				auth.setup({})

				assert.is_true(auth.is_authenticated())
				assert.equals("env-test-key", auth.get_api_key())
				assert.equals("api_key", auth.get_auth_type())
			end)

			it("prefers config API key over environment variable", function()
				vim.env.GEMINI_API_KEY = "env-key"
				local config = {
					auth = {
						api_key = "config-key",
					},
				}

				auth.setup(config)

				assert.equals("config-key", auth.get_api_key())
			end)

			it("handles empty environment variable", function()
				vim.env.GEMINI_API_KEY = ""

				auth.setup({})

				-- Empty string should be falsy in Lua
				assert.is_false(auth.is_authenticated())
			end)
		end)

		describe("from credentials file", function()
			it("loads API key from saved credentials", function()
				-- Save credentials first
				credentials.save({ api_key = "saved-test-key" })

				auth.setup({})

				assert.is_true(auth.is_authenticated())
				assert.equals("saved-test-key", auth.get_api_key())
				assert.equals("api_key", auth.get_auth_type())
			end)

			it("prefers config over saved credentials", function()
				credentials.save({ api_key = "saved-key" })
				local config = {
					auth = {
						api_key = "config-key",
					},
				}

				auth.setup(config)

				assert.equals("config-key", auth.get_api_key())
			end)

			it("prefers environment variable over saved credentials", function()
				credentials.save({ api_key = "saved-key" })
				vim.env.GEMINI_API_KEY = "env-key"

				auth.setup({})

				assert.equals("env-key", auth.get_api_key())
			end)

			it("handles missing credentials file", function()
				-- Ensure no credentials file exists
				credentials.clear()

				auth.setup({})

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_api_key())
			end)

			it("handles corrupted credentials file", function()
				-- Write invalid JSON to credentials file
				local creds_path = credentials.get_path()
				local path = require("gemini.util.path")
				path.ensure_dir(path.get_config_dir())
				local file = io.open(creds_path, "w")
				if file then
					file:write("{ invalid json }")
					file:close()
				end

				auth.setup({})

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_api_key())
			end)
		end)

		describe("credential loading priority", function()
			it("follows priority: config > env > saved > oauth", function()
				-- Set up all sources
				credentials.save({ api_key = "saved-key" })
				vim.env.GEMINI_API_KEY = "env-key"
				local config = {
					auth = {
						api_key = "config-key",
					},
				}

				auth.setup(config)

				-- Should use config (highest priority)
				assert.equals("config-key", auth.get_api_key())
			end)

			it("falls back to env when config has no API key", function()
				credentials.save({ api_key = "saved-key" })
				vim.env.GEMINI_API_KEY = "env-key"

				auth.setup({})

				-- Should use env (second priority)
				assert.equals("env-key", auth.get_api_key())
			end)

			it("falls back to saved credentials when config and env empty", function()
				credentials.save({ api_key = "saved-key" })

				auth.setup({})

				-- Should use saved (third priority)
				assert.equals("saved-key", auth.get_api_key())
			end)
		end)
	end)

	describe("OAuth Flow", function()
		-- Mock file system for OAuth credentials
		local function create_mock_oauth_file(oauth_data)
			local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
			local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")

			-- Create directory
			vim.fn.mkdir(oauth_dir, "p")

			-- Write OAuth credentials
			local file = io.open(oauth_path, "w")
			if file then
				file:write(vim.json.encode(oauth_data))
				file:close()
			end

			return oauth_path
		end

		local function cleanup_mock_oauth_file()
			local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
			vim.fn.delete(oauth_path)
		end

		after_each(function()
			cleanup_mock_oauth_file()
		end)

		describe("loading OAuth credentials", function()
			it("loads valid OAuth credentials from Gemini CLI", function()
				local oauth_data = {
					access_token = "test-access-token",
					refresh_token = "test-refresh-token",
					token_type = "Bearer",
					expiry_date = (os.time() + 3600) * 1000, -- 1 hour from now
				}

				create_mock_oauth_file(oauth_data)
				auth.setup({})

				assert.is_true(auth.is_authenticated())
				assert.equals("test-access-token", auth.get_access_token())
				assert.equals("oauth", auth.get_auth_type())
			end)

			it("returns nil when OAuth file doesn't exist", function()
				cleanup_mock_oauth_file()

				local result = auth._load_gemini_cli_oauth()

				assert.is_nil(result)
			end)

			it("returns nil when OAuth file has invalid JSON", function()
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local file = io.open(oauth_path, "w")
				if file then
					file:write("{ invalid json content }")
					file:close()
				end

				local result = auth._load_gemini_cli_oauth()

				assert.is_nil(result)
			end)

			it("returns nil when access_token is missing", function()
				local oauth_data = {
					refresh_token = "test-refresh-token",
					token_type = "Bearer",
				}

				create_mock_oauth_file(oauth_data)

				local result = auth._load_gemini_cli_oauth()

				assert.is_nil(result)
			end)
		end)

		describe("token expiration handling", function()
			it("accepts valid non-expired token", function()
				local future_time = (os.time() + 3600) * 1000 -- 1 hour in future (milliseconds)
				local oauth_data = {
					access_token = "valid-token",
					expiry_date = future_time,
				}

				create_mock_oauth_file(oauth_data)

				local result = auth._load_gemini_cli_oauth()

				assert.is_table(result)
				assert.equals("valid-token", result.access_token)
			end)

			it("rejects expired token", function()
				local past_time = (os.time() - 3600) * 1000 -- 1 hour ago (milliseconds)
				local oauth_data = {
					access_token = "expired-token",
					expiry_date = past_time,
				}

				create_mock_oauth_file(oauth_data)

				local result = auth._load_gemini_cli_oauth()

				assert.is_nil(result)
			end)

			it("rejects expired token even with refresh_token present", function()
				local past_time = (os.time() - 3600) * 1000
				local oauth_data = {
					access_token = "expired-token",
					refresh_token = "refresh-token",
					expiry_date = past_time,
				}

				create_mock_oauth_file(oauth_data)

				local result = auth._load_gemini_cli_oauth()

				-- Should return nil (doesn't auto-refresh)
				assert.is_nil(result)
			end)

			it("handles missing expiry_date field", function()
				local oauth_data = {
					access_token = "token-without-expiry",
				}

				create_mock_oauth_file(oauth_data)

				local result = auth._load_gemini_cli_oauth()

				-- Should accept token without expiry check
				assert.is_table(result)
				assert.equals("token-without-expiry", result.access_token)
			end)

			it("handles non-numeric expiry_date", function()
				local oauth_data = {
					access_token = "test-token",
					expiry_date = "invalid-date",
				}

				create_mock_oauth_file(oauth_data)

				local result = auth._load_gemini_cli_oauth()

				-- Should handle gracefully (accepts if conversion fails)
				assert.is_table(result)
			end)
		end)

		describe("OAuth vs API key priority", function()
			it("prefers API key from config over OAuth", function()
				local oauth_data = {
					access_token = "oauth-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				create_mock_oauth_file(oauth_data)
				local config = {
					auth = {
						api_key = "config-api-key",
					},
				}

				auth.setup(config)

				assert.equals("api_key", auth.get_auth_type())
				assert.equals("config-api-key", auth.get_api_key())
				assert.is_nil(auth.get_access_token())
			end)

			it("prefers API key from env over OAuth", function()
				local oauth_data = {
					access_token = "oauth-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				create_mock_oauth_file(oauth_data)
				vim.env.GEMINI_API_KEY = "env-api-key"

				auth.setup({})

				assert.equals("api_key", auth.get_auth_type())
				assert.equals("env-api-key", auth.get_api_key())
			end)

			it("prefers saved API key over OAuth", function()
				local oauth_data = {
					access_token = "oauth-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				create_mock_oauth_file(oauth_data)
				credentials.save({ api_key = "saved-api-key" })

				auth.setup({})

				assert.equals("api_key", auth.get_auth_type())
				assert.equals("saved-api-key", auth.get_api_key())
			end)

			it("falls back to OAuth when no API key available", function()
				local oauth_data = {
					access_token = "oauth-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				create_mock_oauth_file(oauth_data)

				auth.setup({})

				assert.equals("oauth", auth.get_auth_type())
				assert.equals("oauth-token", auth.get_access_token())
			end)
		end)
	end)

	describe("Credential Storage and Retrieval", function()
		describe("credentials.save", function()
			it("saves credentials to file", function()
				local test_creds = { api_key = "test-save-key" }

				local success = credentials.save(test_creds)

				assert.is_true(success)

				-- Verify file exists
				local creds_path = credentials.get_path()
				assert.equals(1, vim.fn.filereadable(creds_path))
			end)

			it("creates config directory if it doesn't exist", function()
				local path = require("gemini.util.path")
				local config_dir = path.get_config_dir()

				-- Remove directory if exists
				vim.fn.delete(config_dir, "rf")

				local test_creds = { api_key = "test-key" }
				local success = credentials.save(test_creds)

				assert.is_true(success)
				assert.equals(1, vim.fn.isdirectory(config_dir))
			end)

			it("saves valid JSON format", function()
				local test_creds = {
					api_key = "test-json-key",
					extra_field = "extra-value",
				}

				credentials.save(test_creds)

				-- Read file and verify JSON
				local creds_path = credentials.get_path()
				local file = io.open(creds_path, "r")
				assert.is_not_nil(file)

				local content = file:read("*a")
				file:close()

				local ok, decoded = pcall(vim.json.decode, content)
				assert.is_true(ok)
				assert.equals("test-json-key", decoded.api_key)
				assert.equals("extra-value", decoded.extra_field)
			end)

			it("overwrites existing credentials", function()
				credentials.save({ api_key = "old-key" })
				credentials.save({ api_key = "new-key" })

				local loaded = credentials.load()

				assert.equals("new-key", loaded.api_key)
			end)

			it("sets restrictive file permissions on Unix", function()
				if vim.fn.has("unix") == 0 then
					-- Skip on non-Unix systems
					return
				end

				local test_creds = { api_key = "permission-test-key" }
				credentials.save(test_creds)

				local creds_path = credentials.get_path()
				local perms = vim.fn.getfperm(creds_path)

				-- Should be rw------- (600)
				assert.is_true(string.match(perms, "^rw%-") ~= nil)
			end)
		end)

		describe("credentials.load", function()
			it("loads credentials from file", function()
				local test_creds = { api_key = "test-load-key" }
				credentials.save(test_creds)

				local loaded = credentials.load()

				assert.is_table(loaded)
				assert.equals("test-load-key", loaded.api_key)
			end)

			it("returns nil when file doesn't exist", function()
				credentials.clear()

				local loaded = credentials.load()

				assert.is_nil(loaded)
			end)

			it("returns nil for corrupted JSON", function()
				local creds_path = credentials.get_path()
				local path = require("gemini.util.path")
				path.ensure_dir(path.get_config_dir())

				local file = io.open(creds_path, "w")
				if file then
					file:write("not valid json at all")
					file:close()
				end

				local loaded = credentials.load()

				assert.is_nil(loaded)
			end)

			it("preserves all fields from saved credentials", function()
				local test_creds = {
					api_key = "complex-key",
					custom_field = "custom-value",
					nested = {
						field = "nested-value",
					},
				}

				credentials.save(test_creds)
				local loaded = credentials.load()

				assert.same(test_creds, loaded)
			end)
		end)

		describe("credentials.clear", function()
			it("deletes credentials file", function()
				credentials.save({ api_key = "to-be-deleted" })

				local success = credentials.clear()

				assert.is_true(success)

				local creds_path = credentials.get_path()
				assert.equals(0, vim.fn.filereadable(creds_path))
			end)

			it("returns true when file doesn't exist", function()
				credentials.clear()

				local success = credentials.clear()

				assert.is_true(success)
			end)

			it("clears credentials from auth module", function()
				credentials.save({ api_key = "to-clear" })
				auth.setup({})

				auth.sign_out()

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_api_key())
				assert.is_nil(credentials.load())
			end)
		end)

		describe("credentials.get_path", function()
			it("returns a string path", function()
				local path = credentials.get_path()

				assert.is_string(path)
			end)

			it("path includes credentials.json filename", function()
				local path = credentials.get_path()

				assert.is_true(string.match(path, "credentials%.json$") ~= nil)
			end)

			it("path is in config directory", function()
				local path_util = require("gemini.util.path")
				local config_dir = path_util.get_config_dir()
				local creds_path = credentials.get_path()

				assert.is_true(string.match(creds_path, "^" .. vim.pesc(config_dir)) ~= nil)
			end)
		end)
	end)

	describe("Auth Method Selection", function()
		describe("get_auth_type", function()
			it("returns 'api_key' when using API key", function()
				local config = {
					auth = {
						api_key = "test-key",
					},
				}

				auth.setup(config)

				assert.equals("api_key", auth.get_auth_type())
			end)

			it("returns 'oauth' when using OAuth", function()
				-- Mock OAuth file
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local oauth_data = {
					access_token = "test-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				local file = io.open(oauth_path, "w")
				if file then
					file:write(vim.json.encode(oauth_data))
					file:close()
				end

				auth.setup({})

				assert.equals("oauth", auth.get_auth_type())

				-- Cleanup
				vim.fn.delete(oauth_path)
			end)

			it("returns nil when not authenticated", function()
				auth.setup({})

				assert.is_nil(auth.get_auth_type())
			end)

			it("prefers api_key over oauth in auth type", function()
				-- Setup both
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local oauth_data = {
					access_token = "oauth-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				local file = io.open(oauth_path, "w")
				if file then
					file:write(vim.json.encode(oauth_data))
					file:close()
				end

				local config = {
					auth = {
						api_key = "api-key",
					},
				}

				auth.setup(config)

				assert.equals("api_key", auth.get_auth_type())

				-- Cleanup
				vim.fn.delete(oauth_path)
			end)
		end)

		describe("is_authenticated", function()
			it("returns true when API key is set", function()
				local config = {
					auth = {
						api_key = "test-key",
					},
				}

				auth.setup(config)

				assert.is_true(auth.is_authenticated())
			end)

			it("returns true when OAuth credentials are set", function()
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local oauth_data = {
					access_token = "test-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				local file = io.open(oauth_path, "w")
				if file then
					file:write(vim.json.encode(oauth_data))
					file:close()
				end

				auth.setup({})

				assert.is_true(auth.is_authenticated())

				-- Cleanup
				vim.fn.delete(oauth_path)
			end)

			it("returns false when no credentials are available", function()
				auth.setup({})

				assert.is_false(auth.is_authenticated())
			end)

			it("requires both _authenticated flag and credentials", function()
				auth._authenticated = true
				auth._api_key = nil
				auth._oauth_creds = nil

				assert.is_false(auth.is_authenticated())
			end)
		end)

		describe("get_api_key", function()
			it("returns API key when set", function()
				local config = {
					auth = {
						api_key = "return-test-key",
					},
				}

				auth.setup(config)

				assert.equals("return-test-key", auth.get_api_key())
			end)

			it("returns nil when using OAuth", function()
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local oauth_data = {
					access_token = "oauth-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				local file = io.open(oauth_path, "w")
				if file then
					file:write(vim.json.encode(oauth_data))
					file:close()
				end

				auth.setup({})

				assert.is_nil(auth.get_api_key())

				-- Cleanup
				vim.fn.delete(oauth_path)
			end)

			it("returns nil when not authenticated", function()
				auth.setup({})

				assert.is_nil(auth.get_api_key())
			end)
		end)

		describe("get_access_token", function()
			it("returns access token when using OAuth", function()
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local oauth_data = {
					access_token = "test-access-token",
					expiry_date = (os.time() + 3600) * 1000,
				}

				local file = io.open(oauth_path, "w")
				if file then
					file:write(vim.json.encode(oauth_data))
					file:close()
				end

				auth.setup({})

				assert.equals("test-access-token", auth.get_access_token())

				-- Cleanup
				vim.fn.delete(oauth_path)
			end)

			it("returns nil when using API key", function()
				local config = {
					auth = {
						api_key = "test-key",
					},
				}

				auth.setup(config)

				assert.is_nil(auth.get_access_token())
			end)

			it("returns nil when not authenticated", function()
				auth.setup({})

				assert.is_nil(auth.get_access_token())
			end)
		end)

		describe("sign_out", function()
			it("clears API key authentication", function()
				local config = {
					auth = {
						api_key = "to-sign-out",
					},
				}

				auth.setup(config)
				auth.sign_out()

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_api_key())
			end)

			it("clears OAuth authentication", function()
				local oauth_path = vim.fn.expand("~/.gemini/oauth_creds.json")
				local oauth_dir = vim.fn.fnamemodify(oauth_path, ":h")
				vim.fn.mkdir(oauth_dir, "p")

				local oauth_data = {
					access_token = "to-sign-out",
					expiry_date = (os.time() + 3600) * 1000,
				}

				local file = io.open(oauth_path, "w")
				if file then
					file:write(vim.json.encode(oauth_data))
					file:close()
				end

				auth.setup({})
				auth.sign_out()

				assert.is_false(auth.is_authenticated())
				assert.is_nil(auth.get_access_token())

				-- Cleanup
				vim.fn.delete(oauth_path)
			end)

			it("removes saved credentials file", function()
				credentials.save({ api_key = "saved-key" })

				auth.setup({})
				auth.sign_out()

				local loaded = credentials.load()
				assert.is_nil(loaded)
			end)

			it("resets authenticated flag", function()
				local config = {
					auth = {
						api_key = "test-key",
					},
				}

				auth.setup(config)
				assert.is_true(auth._authenticated)

				auth.sign_out()
				assert.is_false(auth._authenticated)
			end)
		end)
	end)
end)
