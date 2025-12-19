# Gemini Code Assist for Neovim - Architecture

## Overview

This plugin brings Google's [Gemini Code Assist](https://developers.google.com/gemini-code-assist/docs/overview) capabilities to Neovim, providing AI-powered code completions, chat assistance, code generation, and smart actions. The architecture is inspired by existing Neovim AI plugins like [copilot.lua](https://github.com/zbirenbaum/copilot.lua) and [windsurf.nvim](https://github.com/Exafunction/windsurf.nvim), adapted for Google's Gemini ecosystem.

## Feature Parity Goals

Based on the [VS Code](https://marketplace.visualstudio.com/items?itemName=Google.geminicodeassist) and [IntelliJ](https://plugins.jetbrains.com/plugin/24198-gemini-code-assist) plugins:

| Feature | VS Code/IntelliJ | This Plugin | Priority |
|---------|------------------|-------------|----------|
| Inline code completions (ghost text) | Yes | Yes | P0 |
| Code generation from comments | Yes | Yes | P0 |
| Chat interface | Yes | Yes | P0 |
| Unit test generation | Yes | Yes | P1 |
| Smart actions (fix/simplify/doc) | Yes | Yes | P1 |
| Next edit predictions | Yes (Preview) | Future | P2 |
| Repository context (@mentions) | Yes | Future | P2 |
| Agent mode | Yes | Future | P3 |
| MCP server integration | Yes | Future | P3 |

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Neovim                                       │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    User Interface Layer                          ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ ││
│  │  │  Ghost Text  │  │ Completion   │  │    Chat Window         │ ││
│  │  │  (extmarks)  │  │ Menu (cmp)   │  │    (floating/split)    │ ││
│  │  └──────────────┘  └──────────────┘  └────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    Core Plugin Layer                             ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ ││
│  │  │  Suggestion  │  │    Chat      │  │    Smart Actions       │ ││
│  │  │   Module     │  │   Module     │  │       Module           │ ││
│  │  └──────────────┘  └──────────────┘  └────────────────────────┘ ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ ││
│  │  │   Context    │  │  Workspace   │  │     Commands           │ ││
│  │  │   Builder    │  │    Root      │  │     & Keymaps          │ ││
│  │  └──────────────┘  └──────────────┘  └────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    API Client Layer                              ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ ││
│  │  │    Auth      │  │   Request    │  │     Response           │ ││
│  │  │   Manager    │  │   Handler    │  │     Parser             │ ││
│  │  └──────────────┘  └──────────────┘  └────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ HTTPS
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Google Cloud APIs                                 │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Vertex AI Gemini API                                         │   │
│  │  (generativelanguage.googleapis.com)                          │   │
│  │  - generateContent (chat, code generation)                    │   │
│  │  - streamGenerateContent (streaming responses)                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Google AI Studio API (ai.google.dev)                         │   │
│  │  - API key authentication                                     │   │
│  │  - Free tier: 15 RPM, 1M tokens/min, 1500 req/day            │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
gemini-code-assist.nvim/
├── lua/
│   └── gemini/
│       ├── init.lua              # Plugin entry point, setup()
│       ├── config.lua            # Configuration management
│       ├── auth/
│       │   ├── init.lua          # Auth module entry
│       │   ├── oauth.lua         # OAuth flow (browser-based)
│       │   ├── apikey.lua        # API key management
│       │   └── credentials.lua   # Credential storage/retrieval
│       ├── api/
│       │   ├── init.lua          # API client entry
│       │   ├── client.lua        # HTTP client wrapper (curl/plenary)
│       │   ├── gemini.lua        # Gemini API implementation
│       │   ├── vertex.lua        # Vertex AI API (enterprise)
│       │   └── streaming.lua     # Server-sent events handler
│       ├── suggestion/
│       │   ├── init.lua          # Suggestion module entry
│       │   ├── trigger.lua       # Completion trigger logic
│       │   ├── ghost_text.lua    # Virtual text rendering
│       │   ├── debounce.lua      # Request debouncing
│       │   └── cache.lua         # Response caching
│       ├── chat/
│       │   ├── init.lua          # Chat module entry
│       │   ├── window.lua        # Chat window UI
│       │   ├── history.lua       # Conversation persistence
│       │   ├── markdown.lua      # Markdown rendering
│       │   └── context.lua       # Context injection
│       ├── actions/
│       │   ├── init.lua          # Smart actions entry
│       │   ├── generate.lua      # Code generation
│       │   ├── fix.lua           # Fix code issues
│       │   ├── simplify.lua      # Simplify code
│       │   ├── document.lua      # Add documentation
│       │   └── test.lua          # Generate unit tests
│       ├── context/
│       │   ├── init.lua          # Context builder entry
│       │   ├── buffer.lua        # Buffer context extraction
│       │   ├── workspace.lua     # Workspace/project context
│       │   ├── lsp.lua           # LSP-based context
│       │   └── treesitter.lua    # Treesitter-based context
│       ├── ui/
│       │   ├── init.lua          # UI utilities entry
│       │   ├── highlights.lua    # Highlight groups
│       │   ├── virtual_text.lua  # Extmark management
│       │   ├── floating.lua      # Floating windows
│       │   └── statusline.lua    # Statusline integration
│       ├── integrations/
│       │   ├── cmp.lua           # nvim-cmp source
│       │   ├── blink.lua         # blink.cmp source
│       │   └── lualine.lua       # Lualine component
│       ├── commands.lua          # User commands
│       ├── keymaps.lua           # Default keymaps
│       ├── health.lua            # :checkhealth support
│       └── util/
│           ├── init.lua          # Utilities entry
│           ├── log.lua           # Logging
│           ├── async.lua         # Async utilities
│           └── path.lua          # Path utilities
├── plugin/
│   └── gemini.lua                # Vim plugin loader
├── doc/
│   └── gemini-codeassist.txt     # Vimdoc help file
├── tests/
│   ├── minimal_init.lua          # Minimal test config
│   └── spec/                     # Test specifications
│       ├── auth_spec.lua
│       ├── api_spec.lua
│       ├── suggestion_spec.lua
│       └── chat_spec.lua
├── ARCHITECTURE.md               # This file
├── README.md                     # User documentation
├── CHANGELOG.md                  # Version history
└── LICENSE                       # MIT
```

## Module Details

### 1. Authentication Module (`lua/gemini/auth/`)

Supports three authentication methods matching [Gemini CLI](https://github.com/google-gemini/gemini-cli):

#### API Key Authentication (Recommended for individuals)
```lua
-- Environment variable: GEMINI_API_KEY
-- Or stored in: ~/.config/gemini-code-assist/credentials.json
{
  type = "api_key",
  key = "AIza..."
}
```

#### OAuth Authentication (Login with Google)
```lua
-- Browser-based OAuth 2.0 flow
-- Tokens stored in: ~/.config/gemini-code-assist/oauth_tokens.json
{
  type = "oauth",
  access_token = "ya29...",
  refresh_token = "1//...",
  expiry = 1234567890
}
```

#### Vertex AI / Enterprise
```lua
-- Uses Google Cloud Application Default Credentials
-- Requires: GOOGLE_CLOUD_PROJECT environment variable
-- Supports: gcloud auth application-default login
{
  type = "vertex_ai",
  project_id = "my-project",
  location = "us-central1"
}
```

### 2. API Client Module (`lua/gemini/api/`)

#### Primary Endpoints

**Gemini API (Google AI Studio)**
```
Base URL: https://generativelanguage.googleapis.com/v1beta
Endpoints:
  - POST /models/{model}:generateContent
  - POST /models/{model}:streamGenerateContent
Models:
  - gemini-2.0-flash (fast, cost-effective)
  - gemini-2.5-pro (advanced reasoning)
  - gemini-2.5-flash (balanced)
```

**Vertex AI (Enterprise)**
```
Base URL: https://{location}-aiplatform.googleapis.com/v1
Endpoints:
  - POST /projects/{project}/locations/{location}/publishers/google/models/{model}:generateContent
  - POST /projects/{project}/locations/{location}/publishers/google/models/{model}:streamGenerateContent
```

#### Request Format (Code Completion)

```lua
{
  contents = {
    {
      role = "user",
      parts = {
        {
          text = [[
You are an expert code completion assistant. Complete the code at the cursor position.

File: main.py
Language: python

```python
def calculate_fibonacci(n):
    """Calculate the nth Fibonacci number."""
    if n <= 1:
        return n
    # CURSOR_POSITION
```

Provide only the code completion, no explanations.
]]
        }
      }
    }
  },
  generationConfig = {
    temperature = 0.2,
    topP = 0.95,
    maxOutputTokens = 256,
    stopSequences = { "\n\n", "```" }
  }
}
```

#### Response Handling

```lua
-- Standard response
{
  candidates = {
    {
      content = {
        parts = {
          { text = "    return calculate_fibonacci(n-1) + calculate_fibonacci(n-2)" }
        }
      },
      finishReason = "STOP"
    }
  }
}

-- Streaming response (Server-Sent Events)
data: {"candidates":[{"content":{"parts":[{"text":"return"}]}}]}
data: {"candidates":[{"content":{"parts":[{"text":" calculate"}]}}]}
...
```

### 3. Suggestion Module (`lua/gemini/suggestion/`)

Handles inline code completions displayed as ghost text.

#### Trigger Logic

```lua
-- Triggers:
-- 1. Auto-trigger after typing pause (configurable debounce: 150ms default)
-- 2. Manual trigger via keymap (e.g., <C-]>)
-- 3. After specific characters: '.', ':', '(', '{', '[', ' '

-- Blockers (don't trigger):
-- 1. Completion menu visible
-- 2. In prompt buffer
-- 3. Buffer not modifiable
-- 4. Filetype disabled
-- 5. File matches .aiexclude patterns
```

#### Ghost Text Rendering

Uses Neovim's extmarks with `virt_text` and `virt_lines`:

```lua
-- Single-line completion
vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, {
  virt_text = {{ suggestion_text, "GeminiSuggestion" }},
  virt_text_pos = "overlay",
  hl_mode = "combine",
})

-- Multi-line completion
vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, {
  virt_text = {{ first_line, "GeminiSuggestion" }},
  virt_text_pos = "overlay",
  virt_lines = {
    {{ second_line, "GeminiSuggestion" }},
    {{ third_line, "GeminiSuggestion" }},
  },
})
```

#### Suggestion Lifecycle

```
User Types → Debounce Timer → Build Context → API Request → Parse Response
                                                                   │
                                                                   ▼
User Accepts ← Show Ghost Text ← Cache Result ← Validate Response
     │
     ▼
Insert Text → Clear Extmark → Next Suggestion Cycle
```

### 4. Chat Module (`lua/gemini/chat/`)

Provides interactive chat within Neovim.

#### Window Modes

1. **Floating Window** - Modal overlay (default)
2. **Vertical Split** - Side panel
3. **Horizontal Split** - Bottom panel
4. **Tab** - Dedicated tab

#### Conversation Structure

```lua
{
  id = "uuid-v4",
  title = "Auto-generated or user-defined",
  created_at = 1234567890,
  messages = {
    { role = "user", content = "Explain this code", timestamp = 1234567890 },
    { role = "model", content = "This code...", timestamp = 1234567891 },
  },
  context = {
    files = { "main.py" },
    selection = { start_line = 10, end_line = 20 },
  }
}
```

#### Context Injection

```lua
-- Automatic context includes:
-- 1. Current file path and language
-- 2. Selected code (if any)
-- 3. LSP diagnostics for current file
-- 4. Recent edits
-- 5. Workspace information (if indexed)

local context = [[
Current file: src/main.py
Language: python
Selection (lines 10-20):
```python
def process_data(items):
    results = []
    for item in items:
        results.append(transform(item))
    return results
```
]]
```

### 5. Smart Actions Module (`lua/gemini/actions/`)

Pre-defined prompts for common coding tasks.

#### Available Actions

| Action | Command | Description |
|--------|---------|-------------|
| Generate | `:GeminiGenerate` | Generate code from comment/description |
| Fix | `:GeminiFix` | Fix issues in selected code |
| Simplify | `:GeminiSimplify` | Simplify/refactor code |
| Document | `:GeminiDocument` | Add documentation/comments |
| Test | `:GeminiTest` | Generate unit tests |
| Explain | `:GeminiExplain` | Explain selected code |

#### Action Flow

```
User Selection → Action Command → Build Prompt → API Request → Show Diff/Preview
                                                                      │
                                                                      ▼
                                                        User Accept/Reject
                                                              │
                                                              ▼
                                                        Apply Changes
```

### 6. Context Module (`lua/gemini/context/`)

Builds rich context for better suggestions.

#### Context Sources

1. **Buffer Context**
   - Current file content (with token limits)
   - Cursor position
   - Surrounding code (before/after cursor)
   - Selected text

2. **Workspace Context**
   - Project root detection (git, package.json, etc.)
   - Related files (imports, includes)
   - Project structure hints

3. **LSP Context**
   - Diagnostics
   - Symbol information
   - Type information

4. **Treesitter Context**
   - Current function/class scope
   - Syntax tree navigation
   - Semantic tokens

### 7. Integrations (`lua/gemini/integrations/`)

#### nvim-cmp Source

```lua
-- In user's nvim-cmp config:
sources = {
  { name = "gemini", priority = 100 },
  { name = "nvim_lsp" },
  { name = "buffer" },
}
```

#### blink.cmp Source

```lua
-- In user's blink.cmp config:
providers = {
  gemini = { module = "gemini.integrations.blink" },
}
```

#### Lualine Component

```lua
-- Shows: suggestion count, loading state, errors
sections = {
  lualine_x = { "gemini" },
}
```

## Configuration

```lua
require("gemini").setup({
  -- Authentication
  auth = {
    -- "api_key" | "oauth" | "vertex_ai"
    method = "api_key",
    -- For API key: can also use GEMINI_API_KEY env var
    api_key = nil,
    -- For Vertex AI
    vertex_ai = {
      project_id = nil,  -- or GOOGLE_CLOUD_PROJECT env var
      location = "us-central1",
    },
  },

  -- Model configuration
  model = {
    -- Model for completions (fast, low-latency)
    completion = "gemini-2.0-flash",
    -- Model for chat (more capable)
    chat = "gemini-2.5-flash",
    -- Model for complex actions (most capable)
    actions = "gemini-2.5-pro",
  },

  -- Suggestion settings
  suggestion = {
    enabled = true,
    auto_trigger = true,
    debounce_ms = 150,
    max_tokens = 256,
    -- Hide suggestions when completion menu is visible
    hide_during_completion = true,
    -- Filetypes to enable (true = enabled, false = disabled)
    filetypes = {
      ["*"] = true,
      gitcommit = false,
      gitrebase = false,
      ["."] = false,  -- dotfiles
    },
  },

  -- Chat settings
  chat = {
    enabled = true,
    -- "floating" | "vsplit" | "split" | "tab"
    window_type = "floating",
    -- Window dimensions (for floating/split)
    width = 0.6,
    height = 0.8,
    -- Persist conversations across sessions
    persist_history = true,
    -- Include context automatically
    auto_context = true,
  },

  -- Smart actions settings
  actions = {
    enabled = true,
    -- Show diff before applying
    preview_diff = true,
    -- Auto-apply without confirmation
    auto_apply = false,
  },

  -- File exclusions (like .gitignore syntax)
  -- Can also use .aiexclude file in project root
  exclude = {
    "*.env",
    "*.key",
    "*.pem",
    "secrets/*",
    "node_modules/*",
  },

  -- Keymaps (set to false to disable defaults)
  keymaps = {
    -- Suggestion keymaps
    accept = "<Tab>",
    accept_word = "<C-Right>",
    accept_line = "<C-Down>",
    dismiss = "<C-]>",
    next = "<M-]>",
    prev = "<M-[>",
    -- Chat keymaps
    toggle_chat = "<leader>gc",
    -- Action keymaps (visual mode)
    generate = "<leader>gg",
    fix = "<leader>gf",
    test = "<leader>gt",
  },

  -- UI settings
  ui = {
    -- Highlight group for ghost text
    suggestion_hl = "Comment",
    -- Icons
    icons = {
      suggestion = "",
      loading = "",
      error = "",
    },
  },

  -- Logging
  log = {
    level = "warn",  -- "debug" | "info" | "warn" | "error"
    file = nil,  -- Log file path (nil = no file logging)
  },
})
```

## User Commands

| Command | Description |
|---------|-------------|
| `:GeminiAuth` | Authenticate with Google |
| `:GeminiToggle` | Enable/disable suggestions |
| `:GeminiChat` | Open chat window |
| `:GeminiGenerate` | Generate code from description |
| `:GeminiFix` | Fix selected code |
| `:GeminiSimplify` | Simplify selected code |
| `:GeminiDocument` | Add documentation |
| `:GeminiTest` | Generate unit tests |
| `:GeminiExplain` | Explain selected code |
| `:GeminiStatus` | Show plugin status |
| `:GeminiLog` | Open log file |

## Dependencies

### Required
- Neovim >= 0.10.0 (for extmarks, floating windows)
- `nvim-lua/plenary.nvim` (async utilities, HTTP client)
- `curl` (system command for HTTP requests)

### Optional
- `hrsh7th/nvim-cmp` (completion menu integration)
- `saghen/blink.cmp` (alternative completion menu)
- `nvim-lua/lualine.nvim` (statusline integration)
- `nvim-treesitter/nvim-treesitter` (enhanced context)

## Error Handling

### API Errors
```lua
-- Rate limiting (429)
-- Retry with exponential backoff, show user notification

-- Authentication errors (401, 403)
-- Prompt re-authentication, clear cached credentials

-- Network errors
-- Show offline indicator, cache last suggestions

-- Invalid responses
-- Log error, fallback gracefully
```

### User Feedback
```lua
-- Notifications via vim.notify()
vim.notify("Gemini: Rate limit exceeded, retrying...", vim.log.levels.WARN)

-- Statusline updates
-- Loading: ""
-- Error: ""
-- Ready: " 3" (3 suggestions available)
```

## Security Considerations

1. **Credential Storage**: Encrypted at rest using OS keychain when available
2. **Code Exclusion**: Respect `.aiexclude` and `.gitignore` patterns
3. **No Telemetry**: Plugin does not send analytics beyond API calls
4. **Token Limits**: Truncate context to prevent sensitive data leakage
5. **HTTPS Only**: All API communication over TLS

## Testing Strategy

### Unit Tests
- Configuration parsing
- Context building
- Response parsing
- Authentication flow (mocked)

### Integration Tests
- Full suggestion cycle (with mock API)
- Chat conversation flow
- Smart action application

### Manual Testing Checklist
- [ ] Authentication with all three methods
- [ ] Suggestions in multiple languages
- [ ] Multi-line completions
- [ ] Chat with context
- [ ] All smart actions
- [ ] nvim-cmp integration
- [ ] Error handling scenarios

## Future Enhancements

### P2: Next Release
- **Next Edit Predictions**: Suggest edits elsewhere in file based on current changes
- **Repository Context**: Index and reference project files with @mentions
- **Multi-file Awareness**: Consider related files for better suggestions

### P3: Future
- **Agent Mode**: Autonomous multi-step task execution
- **MCP Integration**: Connect to external tools via Model Context Protocol
- **Code Review**: Review diffs and suggest improvements
- **Custom Models**: Support for self-hosted or fine-tuned models

## References

- [Gemini Code Assist Overview](https://developers.google.com/gemini-code-assist/docs/overview)
- [Gemini API Documentation](https://ai.google.dev/api)
- [Vertex AI Gemini](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/gemini)
- [copilot.lua](https://github.com/zbirenbaum/copilot.lua) - Architecture reference
- [windsurf.nvim](https://github.com/Exafunction/windsurf.nvim) - Architecture reference
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) - Auth flow reference
