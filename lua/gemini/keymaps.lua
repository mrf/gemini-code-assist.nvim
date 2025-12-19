---@mod gemini.keymaps Default keymaps
---@brief [[
--- Sets up default keymaps for the plugin.
---@brief ]]

local M = {}

---@type GeminiConfig
M._config = nil

--- Setup keymaps
---@param config GeminiConfig
function M.setup(config)
  M._config = config
  local keymaps = config.keymaps

  if not keymaps then
    return
  end

  -- Suggestion keymaps (insert mode)
  if keymaps.accept then
    vim.keymap.set("i", keymaps.accept, function()
      local suggestion = require("gemini.suggestion")
      if suggestion.is_visible() then
        suggestion.accept()
        return ""
      end
      return keymaps.accept
    end, { expr = true, silent = true, desc = "Accept Gemini suggestion" })
  end

  if keymaps.accept_word then
    vim.keymap.set("i", keymaps.accept_word, function()
      require("gemini.suggestion").accept_word()
    end, { silent = true, desc = "Accept Gemini suggestion word" })
  end

  if keymaps.accept_line then
    vim.keymap.set("i", keymaps.accept_line, function()
      require("gemini.suggestion").accept_line()
    end, { silent = true, desc = "Accept Gemini suggestion line" })
  end

  if keymaps.dismiss then
    vim.keymap.set("i", keymaps.dismiss, function()
      require("gemini.suggestion").dismiss()
    end, { silent = true, desc = "Dismiss Gemini suggestion" })
  end

  if keymaps.next then
    vim.keymap.set("i", keymaps.next, function()
      require("gemini.suggestion").next()
    end, { silent = true, desc = "Next Gemini suggestion" })
  end

  if keymaps.prev then
    vim.keymap.set("i", keymaps.prev, function()
      require("gemini.suggestion").prev()
    end, { silent = true, desc = "Previous Gemini suggestion" })
  end

  -- Chat keymap (normal mode)
  if keymaps.toggle_chat then
    vim.keymap.set("n", keymaps.toggle_chat, function()
      require("gemini.chat").toggle()
    end, { silent = true, desc = "Toggle Gemini chat" })
  end

  -- Action keymaps (visual mode)
  if keymaps.generate then
    vim.keymap.set({ "n", "v" }, keymaps.generate, function()
      require("gemini.actions").generate()
    end, { silent = true, desc = "Generate code with Gemini" })
  end

  if keymaps.fix then
    vim.keymap.set("v", keymaps.fix, function()
      require("gemini.actions").fix()
    end, { silent = true, desc = "Fix code with Gemini" })
  end

  if keymaps.test then
    vim.keymap.set("v", keymaps.test, function()
      require("gemini.actions").test()
    end, { silent = true, desc = "Generate tests with Gemini" })
  end
end

return M
