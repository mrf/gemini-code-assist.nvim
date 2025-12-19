-- Minimal init.lua for testing
-- Run with: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec"

-- Set up package path
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_dir)

-- Add plenary to runtime path (assumes it's in a sibling directory or installed)
local plenary_path = vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")
if vim.fn.isdirectory(plenary_path) == 1 then
	vim.opt.rtp:prepend(plenary_path)
else
	-- Try to find plenary in common locations
	local common_paths = {
		vim.fn.expand("~/.local/share/nvim/site/pack/*/start/plenary.nvim"),
		vim.fn.expand("~/.local/share/nvim/site/pack/*/opt/plenary.nvim"),
		vim.fn.expand("~/.config/nvim/plugged/plenary.nvim"),
	}
	for _, pattern in ipairs(common_paths) do
		local paths = vim.fn.glob(pattern, false, true)
		if #paths > 0 then
			vim.opt.rtp:prepend(paths[1])
			break
		end
	end
end

-- Basic settings for testing
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.undofile = false

-- Load plenary
local ok, plenary = pcall(require, "plenary")
if not ok then
	print("ERROR: plenary.nvim not found. Please install it first.")
	vim.cmd("quit!")
end

-- Initialize the plugin with test configuration
require("gemini").setup({
	auth = {
		method = "api_key",
		api_key = "test-api-key",
	},
	suggestion = {
		enabled = true,
		auto_trigger = false, -- Disable auto-trigger for tests
	},
	chat = {
		enabled = true,
	},
	actions = {
		enabled = true,
	},
	log = {
		level = "debug",
	},
})
