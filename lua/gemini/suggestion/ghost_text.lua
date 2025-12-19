---@mod gemini.suggestion.ghost_text Ghost text rendering
---@brief [[
--- Handles rendering suggestions as virtual text.
---@brief ]]

local M = {}

local ns_id = vim.api.nvim_create_namespace("gemini_suggestion")

---@type string?
M._current_text = nil

---@type number?
M._current_bufnr = nil

---@type number?
M._current_line = nil

---@type number?
M._current_col = nil

--- Show ghost text at current cursor position
---@param text string Suggestion text
function M.show(text)
  M.clear()

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local col = cursor[2]

  M._current_text = text
  M._current_bufnr = bufnr
  M._current_line = line
  M._current_col = col

  -- Split text into lines
  local lines = vim.split(text, "\n", { plain = true })

  if #lines == 0 then
    return
  end

  -- First line as inline virtual text
  local first_line = lines[1]
  local virt_text = { { first_line, "GeminiSuggestion" } }

  -- Remaining lines as virtual lines
  local virt_lines = {}
  for i = 2, #lines do
    table.insert(virt_lines, { { lines[i], "GeminiSuggestion" } })
  end

  -- Create extmark
  local opts = {
    virt_text = virt_text,
    virt_text_pos = "overlay",
    hl_mode = "combine",
  }

  if #virt_lines > 0 then
    opts.virt_lines = virt_lines
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, opts)
end

--- Clear ghost text
function M.clear()
  if M._current_bufnr then
    vim.api.nvim_buf_clear_namespace(M._current_bufnr, ns_id, 0, -1)
  end
  M._current_text = nil
  M._current_bufnr = nil
  M._current_line = nil
  M._current_col = nil
end

--- Accept the full suggestion
function M.accept()
  if not M._current_text then
    return
  end

  local text = M._current_text
  M.clear()

  -- Insert the text at cursor (scheduled to avoid E565 errors during callbacks)
  vim.schedule(function()
    local lines = vim.split(text, "\n", { plain = true })
    if #lines == 1 then
      -- Single line: insert at cursor
      vim.api.nvim_put({ lines[1] }, "c", false, true)
    else
      -- Multi-line: insert as block
      vim.api.nvim_put(lines, "c", false, true)
    end
  end)
end

--- Accept just the next word
function M.accept_word()
  if not M._current_text then
    return
  end

  -- Extract first word
  local word = M._current_text:match("^(%S+)")
  if not word then
    word = M._current_text:match("^(%s+)")
  end

  if word then
    -- Update remaining text
    local remaining = M._current_text:sub(#word + 1)
    M.clear()

    -- Insert the word (scheduled to avoid E565 errors during callbacks)
    vim.schedule(function()
      vim.api.nvim_put({ word }, "c", false, true)

      -- Show remaining suggestion
      if remaining ~= "" then
        M.show(remaining)
      end
    end)
  end
end

--- Accept just the current line
function M.accept_line()
  if not M._current_text then
    return
  end

  -- Extract first line
  local first_line, rest = M._current_text:match("^([^\n]*)\n?(.*)")

  if first_line then
    M.clear()

    -- Insert the line (scheduled to avoid E565 errors during callbacks)
    vim.schedule(function()
      vim.api.nvim_put({ first_line }, "c", false, true)

      -- Update remaining text
      if rest and rest ~= "" then
        M.show(rest)
      end
    end)
  end
end

return M
