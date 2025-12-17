# worktrees.nvim

A full-featured Neovim plugin for seamless git worktree management with advanced workflow automation.

## Features

- 🌳 **Complete Worktree Operations**: Add, switch, remove, lock, unlock, move, repair, and prune
- 🔄 **Smart Buffer Mirroring**: Automatically mirrors your buffer layout when switching worktrees
- 🎨 **Flexible Path Strategies**: Choose between sibling, nested, or custom path generation
- 📋 **Worktree Templates**: Pattern-matched configurations for automatic setup
- ⚡ **Recent Tracking**: Quick access to recently used worktrees
- 🧹 **Cleanup Suggestions**: Detect and suggest removal of stale worktrees
- 🎯 **Lifecycle Hooks**: before/after hooks for switch, create, and remove operations
- ⌨️ **Optional Keymaps**: Convenient default keybindings
- 📡 **Event System**: Emit autocmd events for custom workflows
- 🚀 **Fast**: Built with `vim.system()` for optimal performance
- 🔒 **Type-Safe**: Full LuaCATS annotations throughout

## Installation

### Using lazy.nvim

```lua
{
  'ergotu/worktrees.nvim',
  config = function()
    require('worktrees').setup({
      -- Basic options
      level = vim.log.levels.INFO,
      path_strategy = 'sibling', -- or 'nested', or custom function
      auto_track_upstream = true,

      -- Buffer behavior
      buffer_behavior = {
        mirror = true,
        auto_delete_old = true,
      },

      -- Optional: Enable default keymaps
      keymaps = {
        enable = true,
        prefix = '<leader>gw',
      },

      -- Optional: Recent worktrees
      recents = {
        enabled = true,
        max_count = 10,
      },

      -- Optional: Cleanup suggestions
      cleanup = {
        suggest_stale = true,
        stale_days = 30,
      },
    })
  end,
}
```

### Using Nix

Add to your flake:

```nix
{
  inputs.worktrees-nvim.url = "github:ergotu/worktrees.nvim";

  # Then add to your Neovim plugins
  worktrees-nvim.packages.${system}.default
}
```

## Usage

### Commands

**Core Operations:**
- `:WorktreeAdd` - Create a new worktree
- `:WorktreeSwitch` - Switch to an existing worktree
- `:WorktreeRemove` - Remove a worktree

**Advanced Operations:**
- `:WorktreeLock` - Lock a worktree to prevent removal
- `:WorktreeUnlock` - Unlock a worktree
- `:WorktreeMove` - Move/rename a worktree to a new location
- `:WorktreeRepair` - Repair worktree administrative files
- `:WorktreePrune` - Remove stale worktree metadata

### Workflow

**Add a new worktree**:
```
:WorktreeAdd
```
- Enter a branch name
- If the branch exists, checkout to that branch
- If new, select a base reference (branch/tag/HEAD)

**Switch worktrees**:
```
:WorktreeSwitch
```
- Select from available worktrees
- Your buffers will be mirrored to the new worktree

**Remove a worktree**:
```
:WorktreeRemove
```
- Select the worktree to remove
- Confirm the action

### Events

Hook into worktree events for custom workflows:

```lua
vim.api.nvim_create_autocmd('User', {
  pattern = 'WorktreeCreated',
  callback = function(event)
    -- event.data: { branch, path, previous_path, upstream? }
  end
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'WorktreeSwitched',
  callback = function(event)
    -- event.data: { path, previous_path }
  end
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'WorktreeRemoved',
  callback = function(event)
    -- event.data: { path }
  end
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'WorktreeMoved',
  callback = function(event)
    -- event.data: { old_path, new_path, path }
  end
})
```

## Advanced Configuration

### Path Strategies

Control how worktree paths are generated:

```lua
require('worktrees').setup({
  -- Sibling strategy: ../branch-name (default)
  path_strategy = 'sibling',

  -- Nested strategy: ./worktrees/branch-name
  path_strategy = 'nested',

  -- Custom function
  path_strategy = {
    type = 'custom',
    custom = function(branch_name, repo_root)
      return '/tmp/worktrees/' .. branch_name
    end,
  },
})
```

### Worktree Templates

Automatically configure worktrees based on branch name patterns:

```lua
require('worktrees').setup({
  templates = {
    -- Feature branches always based on develop
    ['^feature/'] = {
      base_ref = 'origin/develop',
      auto_track = true,
    },

    -- Hotfixes based on main with urgent prefix
    ['^hotfix/'] = {
      base_ref = 'origin/main',
      path_prefix = 'urgent-',
      hooks = {
        after_create = function(branch, path)
          -- Run emergency setup
          vim.notify('Hotfix worktree ready!', vim.log.levels.WARN)
        end,
      },
    },
  },
})
```

### Branch Name Aliases

Create shortcuts for common branch naming patterns:

```lua
require('worktrees').setup({
  aliases = {
    feat = 'feature/',
    fix = 'bugfix/',
    hot = 'hotfix/',
  },
})

-- Now typing 'feat' in WorktreeAdd expands to 'feature/'
```

### Lifecycle Hooks

Execute custom logic during worktree operations:

```lua
require('worktrees').setup({
  hooks = {
    before_switch = function(new_path, old_path)
      print('Switching from ' .. old_path .. ' to ' .. new_path)
    end,

    after_create = function(branch, path)
      -- Auto-install dependencies
      vim.fn.system('cd ' .. path .. ' && npm install')
    end,

    before_remove = function(path)
      -- Backup important files
      vim.fn.system('cp ' .. path .. '/config.local /tmp/')
    end,
  },
})
```

### Default Keymaps

Enable convenient default keybindings:

```lua
require('worktrees').setup({
  keymaps = {
    enable = true,
    prefix = '<leader>gw',
    add = 'a',       -- <leader>gwa
    switch = 's',    -- <leader>gws
    remove = 'd',    -- <leader>gwd
    lock = 'l',      -- <leader>gwl
    unlock = 'u',    -- <leader>gwu
    move = 'm',      -- <leader>gwm
    repair = 'r',    -- <leader>gwr
    prune = 'p',     -- <leader>gwp
  },
})
```

## Integrations

### Snacks.nvim Picker

If you're using [snacks.nvim](https://github.com/folke/snacks.nvim), you can use the included picker integration:

```lua
-- In your config
local snacks_worktrees = require('worktrees.integrations.snacks')

-- Create keybindings
vim.keymap.set('n', '<leader>gw', snacks_worktrees.pick_worktree, { desc = 'Switch worktree' })
vim.keymap.set('n', '<leader>gW', snacks_worktrees.pick_worktree_create, { desc = 'Create worktree' })
vim.keymap.set('n', '<leader>gX', snacks_worktrees.pick_worktree_remove, { desc = 'Remove worktree' })
```

Or integrate it with snacks picker configuration:

```lua
require('snacks').setup({
  picker = {
    sources = {
      worktrees = require('worktrees.integrations.snacks').picker_config().worktrees,
    },
  },
})

-- Then use it with
vim.keymap.set('n', '<leader>gw', function()
  require('snacks').picker.pick_worktrees()
end, { desc = 'Switch worktree' })
```

### Statusline Integration

Get current worktree information for your statusline:

```lua
local worktrees = require('worktrees')

-- For lualine
require('lualine').setup({
  sections = {
    lualine_c = {
      function()
        local current = worktrees.get_current_worktree()
        if current then
          local folder = current:match('[^/]+$')
          return '󰉋 ' .. folder
        end
        return ''
      end,
    },
  },
})
```

## API Reference

worktrees.nvim exposes a public API for programmatic worktree management:

### `get_current_worktree()`

Get the path of the current worktree.

```lua
local current = require('worktrees').get_current_worktree()
-- Returns: string|nil
```

### `get_worktrees()`

Get a list of all worktrees.

```lua
local worktrees = require('worktrees').get_worktrees()
-- Returns: Worktree[]
-- Worktree = { path: string, branch: string|nil, head: string }
```

### `add_worktree(opts, callback?)`

Programmatically create a new worktree.

```lua
require('worktrees').add_worktree({
  branch = 'feature-x',           -- Required: branch name
  path = '/path/to/worktree',     -- Optional: custom path
  base_ref = 'main',              -- Optional: base reference
  track_upstream = true,          -- Optional: track upstream branch
}, function(success, path)
  if success then
    print('Created worktree at: ' .. path)
  end
end)
```

### `switch_to(path, callback?)`

Programmatically switch to a worktree.

```lua
require('worktrees').switch_to('/path/to/worktree', function(success)
  if success then
    print('Switched successfully')
  end
end)
```

### `remove_worktree(path, callback?)`

Programmatically remove a worktree.

```lua
require('worktrees').remove_worktree('/path/to/worktree', function(success)
  if success then
    print('Removed successfully')
  end
end)
```

## Development

This project uses Nix for reproducible development.

```bash
nix develop          # Enter dev shell
busted               # Run tests
stylua .             # Format code
nix flake check      # Run all checks
```

See [CLAUDE.md](./CLAUDE.md) for architecture details.

## License

MIT
