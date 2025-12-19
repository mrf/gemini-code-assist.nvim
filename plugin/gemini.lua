-- Gemini Code Assist for Neovim
-- Plugin loader

if vim.g.loaded_gemini then
  return
end

-- Require Neovim 0.10.0+
if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("Gemini Code Assist requires Neovim 0.10.0 or later", vim.log.levels.ERROR)
  return
end

vim.g.loaded_gemini = true

-- Lazy load the plugin on first command or explicit setup
vim.api.nvim_create_user_command("GeminiSetup", function()
  require("gemini").setup()
end, { desc = "Initialize Gemini Code Assist" })
