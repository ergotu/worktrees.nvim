# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Nix Development Environment
```bash
nix develop              # Enter development shell (recommended)
nix flake check          # Run all checks (tests + formatting)
```

### Testing
```bash
busted                    # Run all tests
```

### Formatting
```bash
stylua .                  # Format all files
stylua --check .          # Check formatting without modifying
```

### Configuration
- `flake.nix`: Nix flake with devShell, packages, and checks
- `.stylua.toml`: 100 char width, 2-space indent, single quotes preferred, Unix line endings
- `.busted`: Test configuration using nlua
- Pre-commit hooks: Automatically run stylua, busted, and nixpkgs-fmt

## Architecture

### Core Flow
The plugin follows a three-layer architecture:

1. **Entry point** (`lua/worktrees/init.lua`): Creates 8 user commands and optional keymaps
2. **Actions layer** (`lua/worktrees/actions/`): Orchestrates workflows combining user input, git operations, buffer management, templates, hooks, and recents tracking
3. **Library layer** (`lua/worktrees/lib/`): Provides reusable utilities for git operations, notifications, input handling, persistence, path strategies, and cleanup detection

### Key Patterns

**Action Workflow Pattern**
Actions follow a consistent pattern:
1. Get user input via `input` module
2. Expand aliases and apply templates (for add action)
3. Call before hooks if configured
4. Validate and process
5. Execute git operations via `git`/`worktree`/`branch` modules
6. Switch to worktree via `actions.shared.switch_to_worktree()`
7. Track in recents if enabled
8. Emit autocmd event via `actions.shared.emit_event()`
9. Call after hooks if configured

Example from `add.lua`:
- Get branch name → expand alias → calculate path → apply template
- Validate → check if branch exists
- Call before_create hook
- If exists: checkout existing branch
- If new: select base ref (or use template base_ref) → create with upstream tracking
- Track in recents
- Emit Created event
- Call after_create hook

**Buffer Mirroring** (`actions/shared.lua`)
When switching worktrees, the plugin mirrors buffer structure:
- Finds all buffers from previous worktree path
- Creates equivalent buffers in new worktree (if files exist)
- Deletes old buffers

This preserves the user's workspace layout across worktree switches.

**Event System**
Four autocmd events are emitted as `User` events:
- `WorktreeCreated`: Includes `branch`, `path`, `previous_path`, optionally `upstream`
- `WorktreeSwitched`: Includes `path`, `previous_path`
- `WorktreeRemoved`: Includes `path`
- `WorktreeMoved`: Includes `old_path`, `new_path`, `path`

Users can hook into these with:
```lua
vim.api.nvim_create_autocmd('User', {
  pattern = 'WorktreeCreated',
  callback = function(event)
    -- event.data contains the data table
  end
})
```

**Git Command Abstraction** (`lib/git/init.lua`)
Uses a `GitCommand` class (metatable-based OOP):
- Wraps `vim.system` with `plenary.job` integration
- Returns `{success: bool, stdout: string[], stderr: string[]}`
- Provides both sync (`run()`) and async (`run_async()`) execution

### Module Responsibilities

**`lib/input.lua`**
User interaction abstraction layer:
- `get_user_input()`: Text input with optional space stripping
- `get_confirmation()`: Yes/no prompts
- `select()`: Generic selection wrapper around `vim.ui.select`
- `select_ref()`: Git reference selection (branches/remotes/HEAD)
- `select_worktree()`: Worktree selection from git worktree list

**`lib/git/`**
- `init.lua`: Base git command runner, repository utilities (`root()`, `is_bare()`)
- `worktree.lua`: All worktree operations (`add()`, `list()`, `remove()`, `lock()`, `unlock()`, `move()`, `repair()`, `prune()`)
- `branch.lua`: Branch operations (upstream tracking)
- `refs.lua`: Reference listing (heads, remotes, tags)

**`lib/path.lua`**
Path strategy module for calculating worktree paths:
- Supports `sibling`, `nested`, and `custom` strategies
- Handles bare vs regular repositories

**`lib/persistence.lua`**
JSON-based data persistence to `~/.local/share/nvim/data/worktrees.nvim/`:
- `read_json()`: Read JSON data from file
- `write_json()`: Write JSON data to file
- `delete()`: Remove data file

**`lib/recents.lua`**
Recent worktree tracking (MRU ordering):
- `get()`: Retrieve recent worktrees
- `add()`: Track worktree access (limits to max_count)
- `remove()`: Remove from recents
- `clear()`: Clear all recents

**`lib/cleanup.lua`**
Stale worktree detection:
- `get_stale()`: Find worktrees older than stale_days
- `suggest()`: Format cleanup suggestions message

**`lib/notification.lua`**
Centralized notification system respecting config log levels.

### Advanced Features

**Templates** (`config.lua`)
Pattern-matched configurations for automatic worktree setup:
- Match branch names with Lua patterns
- Specify `base_ref`, `path_prefix`, `path_suffix`, `auto_track`
- Per-template hooks (`before_create`, `after_create`)

**Aliases** (`config.lua`)
Branch name expansion shortcuts:
- Simple string substitution (`feat` → `feature/`)
- Applied before validation in `add.lua`

**Hooks** (`config.lua`)
Lifecycle callbacks for custom workflows:
- `before_switch`, `after_switch`
- `before_create`, `after_create`
- `before_remove`, `after_remove`
- Called at appropriate points in action workflow

**Keymaps** (`init.lua`)
Optional default keybindings:
- Configurable prefix (default: `<leader>gw`)
- Individual keys for each action
- Disabled by default (`keymaps.enable = false`)

### Type Annotations
Uses LuaCATS annotations throughout:
- `---@class` for configuration objects (including `TemplateConfig`, `RecentsConfig`, etc.)
- `---@param` and `---@return` for function signatures
- `---@alias` for event types and data structures (see `actions/shared.lua`)
- All new modules fully annotated
