# Gemini Code Assist for Neovim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Neovim plugin for Google's [Gemini Code Assist](https://developers.google.com/gemini-code-assist/docs/overview), bringing AI-powered code completions, chat, and smart actions to your editor.

## Features

- **Inline Code Completions** - Ghost text suggestions as you type
- **Interactive Chat** - AI assistant in a floating/split window
- **Smart Actions** - Fix, simplify, document, explain, and generate tests
- **Code Generation** - Generate code from natural language descriptions

## Requirements

- Neovim >= 0.10.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- `curl` (for API requests)
- Authentication (one of the following):
  - Gemini API key (free tier available)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli) OAuth login

## Quick Start (Manual Testing)

### Authentication Options

#### Option A: Gemini CLI OAuth (Recommended if you have Gemini CLI)

If you have [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed:

```bash
gemini login
```

That's it! The plugin automatically uses credentials from `~/.gemini/oauth_creds.json`.

#### Option B: API Key

1. Go to [Google AI Studio](https://aistudio.google.com/apikey)
2. Click "Create API Key"
3. Set the environment variable:

```bash
export GEMINI_API_KEY="your-api-key-here"
```

Add to your shell profile (`~/.zshrc` or `~/.bashrc`) to persist.

## Installation

### lazy.nvim

```lua
{
  "mrf/gemini-code-assist.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("gemini").setup()
  end,
}
```

### Manual Installation

Clone the repository and add to your runtimepath:

```bash
git clone https://github.com/mrf/gemini-code-assist.nvim.git
```

Then in your `init.lua`:

```lua
vim.opt.rtp:prepend("/path/to/gemini-code-assist.nvim")
require("gemini").setup()
```

### Verify Installation

```vim
:checkhealth gemini
```

You should see:
- Neovim version >= 0.10.0
- curl is available
- plenary.nvim is installed
- API key is configured

### Test the Plugin

#### Check Status
```vim
:GeminiStatus
```

#### Test Chat
```vim
:GeminiChat
```
Press `i` or `Enter` to type a message, `q` to close.

#### Test Code Generation
```vim
:GeminiGenerate write a function to calculate fibonacci
```

#### Test Smart Actions
1. Select some code in visual mode (`v` or `V`)
2. Run one of:
   - `:GeminiExplain` - Explain the code
   - `:GeminiFix` - Fix issues
   - `:GeminiDocument` - Add documentation
   - `:GeminiTest` - Generate tests
   - `:GeminiSimplify` - Refactor/simplify

#### Test Inline Suggestions
With `auto_trigger = true`:
1. Open a code file
2. Start typing
3. Wait 150ms for ghost text to appear
4. Press `<Tab>` to accept or `<C-]>` to dismiss

## Commands

| Command | Description |
|---------|-------------|
| `:GeminiAuth` | Authenticate (prompts for API key if not set) |
| `:GeminiStatus` | Show plugin status and config |
| `:GeminiToggle` | Enable/disable suggestions |
| `:GeminiChat` | Open chat window |
| `:GeminiGenerate [description]` | Generate code from description |
| `:GeminiFix` | Fix selected code (visual mode) |
| `:GeminiSimplify` | Simplify selected code (visual mode) |
| `:GeminiDocument` | Add documentation (visual mode) |
| `:GeminiTest` | Generate unit tests (visual mode) |
| `:GeminiExplain` | Explain selected code (visual mode) |

## Default Keymaps

### Insert Mode (Suggestions)

| Key | Action |
|-----|--------|
| `<Tab>` | Accept suggestion |
| `<C-Right>` | Accept word |
| `<C-Down>` | Accept line |
| `<C-]>` | Dismiss suggestion |
| `<M-]>` | Next suggestion |
| `<M-[>` | Previous suggestion |

### Normal Mode

| Key | Action |
|-----|--------|
| `<leader>gc` | Toggle chat |
| `<leader>gg` | Generate code |

### Visual Mode

| Key | Action |
|-----|--------|
| `<leader>gf` | Fix selected code |
| `<leader>gt` | Generate tests |

## Configuration

```lua
require("gemini").setup({
  auth = {
    api_key = nil,  -- Uses GEMINI_API_KEY env var if not set
  },

  model = {
    completion = "gemini-2.0-flash",
    chat = "gemini-2.0-flash",
    actions = "gemini-2.0-flash",
  },

  suggestion = {
    enabled = true,
    auto_trigger = true,
    debounce_ms = 150,
    max_tokens = 256,
    hide_during_completion = true,
    filetypes = {
      ["*"] = true,
      gitcommit = false,
      gitrebase = false,
    },
  },

  chat = {
    enabled = true,
    window_type = "floating",  -- "floating" | "vsplit" | "split" | "tab"
    width = 0.6,
    height = 0.8,
    persist_history = true,
    auto_context = true,
  },

  actions = {
    enabled = true,
    preview_diff = true,
    auto_apply = false,
  },

  keymaps = {
    accept = "<Tab>",
    accept_word = "<C-Right>",
    accept_line = "<C-Down>",
    dismiss = "<C-]>",
    next = "<M-]>",
    prev = "<M-[>",
    toggle_chat = "<leader>gc",
    generate = "<leader>gg",
    fix = "<leader>gf",
    test = "<leader>gt",
  },

  ui = {
    suggestion_hl = "Comment",
    icons = {
      suggestion = "",
      loading = "",
      error = "",
    },
  },

  log = {
    level = "warn",  -- "debug" | "info" | "warn" | "error"
    file = nil,
  },
})
```

## Troubleshooting

### "API key not found"

```bash
# Check if env var is set
echo $GEMINI_API_KEY

# Set it
export GEMINI_API_KEY="your-key"
```

### "plenary.nvim not found"

Install plenary first:
```lua
-- lazy.nvim
{ "nvim-lua/plenary.nvim" }
```

### No suggestions appearing

1. Check `:GeminiStatus` - is it authenticated?
2. Check `:checkhealth gemini`
3. Try `:GeminiToggle` to enable
4. Check if filetype is enabled in config

### Debug mode

Enable debug logging:
```lua
require("gemini").setup({
  log = {
    level = "debug",
    file = "/tmp/gemini.log",
  },
})
```

Then tail the log:
```bash
tail -f /tmp/gemini.log
```

## License

[MIT](LICENSE)
