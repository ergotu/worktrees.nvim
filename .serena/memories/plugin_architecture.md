# Plugin Architecture

## Entry Point
`lua/worktrees/init.lua` - Main module that exports the `setup()` function

### Setup Function
- Accepts optional `ConfigOpts` table
- Creates three Neovim user commands:
  - `WorktreeAdd` → calls `actions.add()`
  - `WorktreeSwitch` → calls `actions.switch()`
  - `WorktreeRemove` → calls `actions.remove()`

## Module Organization

### Actions Layer (`lua/worktrees/actions/`)
Public-facing functionality that users interact with:
- `add.lua` - Add new worktree
- `switch.lua` - Switch to existing worktree
- `remove.lua` - Remove a worktree
- `shared.lua` - Shared action utilities
- `init.lua` - Exports all actions

### Library Layer (`lua/worktrees/lib/`)
Internal utilities and helpers:

#### Git Operations (`lib/git/`)
- `init.lua` - Main git module
- `worktree.lua` - Worktree operations (add, list, remove)
- `branch.lua` - Branch operations
- `refs.lua` - Git references handling

#### Other Libraries
- `input.lua` - User input handling
- `notification.lua` - User notifications
- `parser.lua` - Parsing utilities
- `util.lua` - General utilities

### Configuration (`lua/worktrees/config.lua`)
- Manages plugin configuration
- Default options defined in `M._default_opts`
- Uses `vim.tbl_deep_extend` for merging user options

## Design Principles
1. **Layered architecture**: Actions use lib, lib uses Neovim/git APIs
2. **Single responsibility**: Each module has a focused purpose
3. **Configuration isolation**: All config in one place
4. **User command abstraction**: Actions wrapped in Neovim commands
5. **Git operations abstraction**: Git commands wrapped in lib/git modules

## Recent Commits Context
- Moved actions to separate folder (refactor)
- Added main interaction functions (feat)
- Implemented input handling methods (feat)
- Added git utility functions (bare repo check, toplevel detection)
