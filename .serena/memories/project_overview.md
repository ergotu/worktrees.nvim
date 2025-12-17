# Project Overview: worktrees.nvim

## Purpose
worktrees.nvim is a Neovim plugin for managing Git worktrees. It provides commands to add, switch, and remove Git worktrees directly from within Neovim.

## Key Features
- **WorktreeAdd**: Add a new Git worktree
- **WorktreeSwitch**: Switch between existing worktrees
- **WorktreeRemove**: Remove a Git worktree

## Tech Stack
- **Language**: Lua
- **Platform**: Neovim plugin
- **Testing Framework**: Busted (using nlua)
- **Formatter**: StyLua
- **Documentation**: panvimdoc (converts README to vimdoc)

## Project Structure
```
worktrees.nvim/
├── lua/worktrees/
│   ├── init.lua           # Main entry point, setup function
│   ├── config.lua         # Configuration management
│   ├── actions/           # User-facing actions
│   │   ├── init.lua       # Exports add, remove, switch
│   │   ├── add.lua
│   │   ├── remove.lua
│   │   ├── switch.lua
│   │   └── shared.lua
│   └── lib/               # Internal libraries
│       ├── git/           # Git operations
│       │   ├── init.lua
│       │   ├── branch.lua
│       │   ├── refs.lua
│       │   └── worktree.lua
│       ├── input.lua      # User input handling
│       ├── notification.lua
│       ├── parser.lua
│       └── util.lua
├── test/
│   └── plugin_spec.lua    # Busted tests
├── doc/                   # Auto-generated documentation
├── .github/workflows/
│   ├── ci.yml            # Linting and docs generation
│   └── test.yml          # Test runner
├── .stylua.toml          # Formatting configuration
└── .busted               # Test configuration
```

## Configuration
The plugin accepts a `ConfigOpts` table with:
- `level`: Log level (defaults to `vim.log.levels.INFO`)
