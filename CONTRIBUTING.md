# Contributing to gemini-code-assist.nvim

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/mrf/gemini-code-assist.nvim.git
   cd gemini-code-assist.nvim
   ```

2. Ensure you have:
   - Neovim >= 0.10.0
   - [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) installed

3. Add the plugin to your runtime path for development:
   ```lua
   vim.opt.rtp:prepend("/path/to/gemini-code-assist.nvim")
   ```

## Running Tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s test harness:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec"
```

Or run a specific test file:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/spec/config_spec.lua"
```

## Code Style

- Follow existing code patterns in the codebase
- Use [stylua](https://github.com/JohnnyMorganz/StyLua) for formatting (if available)
- Keep functions small and focused
- Add type annotations using LuaLS/EmmyLua style comments

## Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes
4. Run tests to ensure nothing is broken
5. Submit a pull request

Keep PRs focused on a single change. If you're fixing a bug and adding a feature, submit them as separate PRs.

## Reporting Issues

When reporting bugs, please include:
- Neovim version (`:version`)
- Output of `:checkhealth gemini`
- Steps to reproduce
- Expected vs actual behavior
