local config = require('worktrees.config')
local actions = require('worktrees.actions')

local M = {}

---@param opts? ConfigOpts
function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command('WorktreeAdd', function()
    actions.add()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeSwitch', function()
    actions.switch()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeRemove', function()
    actions.remove()
  end, { nargs = 0 })

  vim.api.nvim_create_user_command('WorktreeLock', function()
    actions.lock()
  end, { nargs = 0, desc = 'Lock a worktree to prevent removal' })

  vim.api.nvim_create_user_command('WorktreeUnlock', function()
    actions.unlock()
  end, { nargs = 0, desc = 'Unlock a worktree' })

  vim.api.nvim_create_user_command('WorktreeMove', function()
    actions.move()
  end, { nargs = 0, desc = 'Move a worktree to a new location' })

  vim.api.nvim_create_user_command('WorktreeRepair', function()
    actions.repair()
  end, { nargs = 0, desc = 'Repair worktree administrative files' })

  vim.api.nvim_create_user_command('WorktreePrune', function()
    actions.prune()
  end, { nargs = 0, desc = 'Remove stale worktree metadata' })

  -- Setup keymaps if enabled
  if config.values.keymaps.enable then
    local km = config.values.keymaps
    local prefix = km.prefix

    vim.keymap.set('n', prefix .. km.add, actions.add, { desc = 'Worktree: Add' })
    vim.keymap.set('n', prefix .. km.switch, actions.switch, { desc = 'Worktree: Switch' })
    vim.keymap.set('n', prefix .. km.remove, actions.remove, { desc = 'Worktree: Remove' })
    vim.keymap.set('n', prefix .. km.lock, actions.lock, { desc = 'Worktree: Lock' })
    vim.keymap.set('n', prefix .. km.unlock, actions.unlock, { desc = 'Worktree: Unlock' })
    vim.keymap.set('n', prefix .. km.move, actions.move, { desc = 'Worktree: Move' })
    vim.keymap.set('n', prefix .. km.repair, actions.repair, { desc = 'Worktree: Repair' })
    vim.keymap.set('n', prefix .. km.prune, actions.prune, { desc = 'Worktree: Prune' })
  end
end

-- Public API for integrations

---Get the current worktree path
---@return string|nil path The current worktree path, or nil if not in a worktree
function M.get_current_worktree()
  local cwd = vim.fn.getcwd()
  local worktree_mod = require('worktrees.lib.git.worktree')
  local worktrees = worktree_mod.list()

  if not worktrees then
    return nil
  end

  for _, wt in ipairs(worktrees) do
    if wt.path == cwd then
      return wt.path
    end
  end

  return nil
end

---Get all worktrees
---@return Worktree[] List of worktrees
function M.get_worktrees()
  local worktree_mod = require('worktrees.lib.git.worktree')
  return worktree_mod.list() or {}
end

---@class AddWorktreeOpts
---@field branch string Branch name for the worktree
---@field path? string Optional path (defaults to auto-generated)
---@field base_ref? string Base reference for new branches
---@field track_upstream? boolean Track upstream for new branches

---Programmatically add a worktree
---@param opts AddWorktreeOpts
---@param callback? fun(success: boolean, path: string|nil)
function M.add_worktree(opts, callback)
  if not opts or not opts.branch then
    if callback then
      callback(false, nil)
    end
    return
  end

  local git = require('worktrees.lib.git')
  local worktree_mod = require('worktrees.lib.git.worktree')
  local branch_mod = require('worktrees.lib.git.branch')
  local shared = require('worktrees.actions.shared')
  local notification = require('worktrees.lib.notification')

  -- Calculate path if not provided
  local path = opts.path or (git.root() .. '/../' .. opts.branch)

  -- Check if path already exists
  if vim.fn.isdirectory(path) == 1 then
    notification.error('Directory already exists: ' .. path)
    if callback then
      callback(false, nil)
    end
    return
  end

  -- Add worktree
  local result = worktree_mod.add(path, {
    branch = opts.branch,
    commitish = opts.base_ref,
  })

  if not result.success then
    notification.error('Failed to create worktree: ' .. table.concat(result.stderr, '\n'))
    if callback then
      callback(false, nil)
    end
    return
  end

  -- Set upstream if requested
  if opts.track_upstream and opts.base_ref then
    branch_mod.set_upstream(opts.base_ref, { cwd = path })
  end

  -- Switch to worktree
  local previous_path = vim.fn.getcwd()
  shared.switch_to_worktree(path)

  -- Emit event
  shared.emit_event('Created', {
    branch = opts.branch,
    path = path,
    previous_path = previous_path,
    upstream = opts.track_upstream and opts.base_ref or nil,
  })

  notification.info('Created and switched to worktree: ' .. path)

  if callback then
    callback(true, path)
  end
end

---Programmatically switch to a worktree
---@param path string Path to the worktree
---@param callback? fun(success: boolean)
function M.switch_to(path, callback)
  if not path or vim.fn.isdirectory(path) == 0 then
    if callback then
      callback(false)
    end
    return
  end

  local shared = require('worktrees.actions.shared')
  local notification = require('worktrees.lib.notification')
  local previous_path = vim.fn.getcwd()

  if previous_path == path then
    notification.warn('Already in worktree: ' .. path)
    if callback then
      callback(false)
    end
    return
  end

  shared.switch_to_worktree(path)

  shared.emit_event('Switched', {
    path = path,
    previous_path = previous_path,
  })

  notification.info('Switched to worktree: ' .. path)

  if callback then
    callback(true)
  end
end

---Programmatically remove a worktree
---@param path string Path to the worktree to remove
---@param callback? fun(success: boolean)
function M.remove_worktree(path, callback)
  if not path then
    if callback then
      callback(false)
    end
    return
  end

  local worktree_mod = require('worktrees.lib.git.worktree')
  local notification = require('worktrees.lib.notification')
  local shared = require('worktrees.actions.shared')

  -- Don't allow removing current worktree
  local cwd = vim.fn.getcwd()
  if path == cwd then
    notification.error('Cannot remove current worktree')
    if callback then
      callback(false)
    end
    return
  end

  worktree_mod.remove_async(path, {}, function(result)
    if not result.success then
      notification.error('Failed to remove worktree: ' .. table.concat(result.stderr, '\n'))
      if callback then
        callback(false)
      end
      return
    end

    shared.emit_event('Removed', { path = path })
    notification.info('Removed worktree: ' .. path)

    if callback then
      callback(true)
    end
  end)
end

return M
