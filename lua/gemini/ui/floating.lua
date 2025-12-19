---@mod gemini.ui.floating Floating window utilities
---@brief [[
--- Provides utilities for creating floating windows.
---@brief ]]

local M = {}

---@class FloatingWindowOpts
---@field width? number|string Width (number or percentage like "80%")
---@field height? number|string Height (number or percentage like "80%")
---@field title? string Window title
---@field border? string Border style
---@field relative? string Relative positioning
---@field focusable? boolean Whether window is focusable
---@field style? string Window style

--- Create a floating window
---@param content string|string[] Content to display
---@param opts? FloatingWindowOpts Options
---@return table window { buf: number, win: number }
function M.create(content, opts)
  opts = opts or {}

  -- Parse dimensions
  local width = M._parse_dimension(opts.width or "60%", vim.o.columns)
  local height = M._parse_dimension(opts.height or "60%", vim.o.lines)

  -- Calculate position
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set content
  if type(content) == "string" then
    content = vim.split(content, "\n")
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  -- Create window
  local win_opts = {
    relative = opts.relative or "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = opts.style or "minimal",
    border = opts.border or "rounded",
    focusable = opts.focusable ~= false,
  }

  if opts.title then
    win_opts.title = " " .. opts.title .. " "
    win_opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Default keymaps
  vim.keymap.set("n", "q", function()
    M.close({ buf = buf, win = win })
  end, { buffer = buf })

  vim.keymap.set("n", "<Esc>", function()
    M.close({ buf = buf, win = win })
  end, { buffer = buf })

  return { buf = buf, win = win }
end

--- Parse dimension (number or percentage)
---@param dim number|string
---@param max number
---@return number
function M._parse_dimension(dim, max)
  if type(dim) == "number" then
    if dim <= 1 then
      return math.floor(max * dim)
    end
    return math.floor(dim)
  end

  if type(dim) == "string" and dim:match("%%$") then
    local pct = tonumber(dim:sub(1, -2)) or 60
    return math.floor(max * pct / 100)
  end

  return math.floor(max * 0.6)
end

--- Close a floating window
---@param window table { buf?: number, win: number }
function M.close(window)
  if window.win and vim.api.nvim_win_is_valid(window.win) then
    vim.api.nvim_win_close(window.win, true)
  end
end

--- Update floating window content
---@param window table { buf: number, win: number }
---@param content string|string[]
function M.update(window, content)
  if not window.buf or not vim.api.nvim_buf_is_valid(window.buf) then
    return
  end

  if type(content) == "string" then
    content = vim.split(content, "\n")
  end

  vim.bo[window.buf].modifiable = true
  vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, content)
  vim.bo[window.buf].modifiable = false
end

return M
