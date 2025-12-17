---Snacks.nvim integration for worktrees.nvim
---
---Example usage:
---```lua
---require('worktrees.integrations.snacks').pick_worktree()
---require('worktrees.integrations.snacks').pick_worktree_create()
---```
---
---Or integrate with snacks.nvim picker configuration:
---```lua
---Snacks.picker.worktrees = require('worktrees.integrations.snacks').picker_config()
---```

local M = {}

---Check if snacks.nvim is available
---@return boolean
local function has_snacks()
  local ok = pcall(require, 'snacks')
  return ok
end

---Format a worktree item for display
---@param item Worktree
---@return snacks.picker.Item
local function format_worktree(item)
  local branch_display = item.branch and item.branch:match('[^/]+$') or 'detached'
  local folder = item.path:match('[^/]+$') or item.path
  local text = string.format('󰉋  %s (%s)', folder, branch_display)

  return {
    text = text,
    file = item.path,
    path = item.path,
    branch = item.branch,
    head = item.head,
  }
end

---Pick and switch to a worktree using snacks.nvim picker
---@param opts? table Additional picker options
function M.pick_worktree(opts)
  if not has_snacks() then
    vim.notify('snacks.nvim is not available', vim.log.levels.ERROR)
    return
  end

  local Snacks = require('snacks')
  local worktrees = require('worktrees')

  opts = opts or {}
  local items = worktrees.get_worktrees()

  -- Filter out current worktree if requested
  if opts.exclude_current then
    local cwd = vim.fn.getcwd()
    items = vim.tbl_filter(function(wt)
      return wt.path ~= cwd
    end, items)
  end

  Snacks.picker.pick(vim.tbl_deep_extend('force', {
    source = 'worktrees',
    items = vim.tbl_map(format_worktree, items),
    format = 'file',
    confirm = function(picker, item)
      if item and item.path then
        worktrees.switch_to(item.path)
      end
      picker:close()
    end,
    win = {
      input = {
        prompt = '  Worktrees ',
      },
    },
  }, opts))
end

---Pick and remove a worktree using snacks.nvim picker
---@param opts? table Additional picker options
function M.pick_worktree_remove(opts)
  if not has_snacks() then
    vim.notify('snacks.nvim is not available', vim.log.levels.ERROR)
    return
  end

  local Snacks = require('snacks')
  local worktrees = require('worktrees')
  local input = require('worktrees.lib.input')

  opts = opts or {}
  local items = worktrees.get_worktrees()

  -- Always exclude current worktree for removal
  local cwd = vim.fn.getcwd()
  items = vim.tbl_filter(function(wt)
    return wt.path ~= cwd
  end, items)

  if #items == 0 then
    vim.notify('No other worktrees to remove', vim.log.levels.WARN)
    return
  end

  Snacks.picker.pick(vim.tbl_deep_extend('force', {
    source = 'worktrees_remove',
    items = vim.tbl_map(format_worktree, items),
    format = 'file',
    confirm = function(picker, item)
      picker:close()
      if item and item.path then
        -- Ask for confirmation before removing
        local confirmed = input.get_confirmation('Remove worktree at ' .. item.path .. '?')
        if confirmed then
          worktrees.remove_worktree(item.path)
        end
      end
    end,
    win = {
      input = {
        prompt = '  Remove Worktree ',
      },
    },
  }, opts))
end

---Pick a git reference to create a new worktree
---@param opts? table Additional picker options
function M.pick_worktree_create(opts)
  if not has_snacks() then
    vim.notify('snacks.nvim is not available', vim.log.levels.ERROR)
    return
  end

  local Snacks = require('snacks')
  local worktrees = require('worktrees')
  local refs = require('worktrees.lib.git.refs')
  local input = require('worktrees.lib.input')

  opts = opts or {}

  -- Get all git references
  local items = {}

  -- Local branches
  for _, branch in ipairs(refs.list_local_branches()) do
    table.insert(items, {
      text = '󰘬  ' .. branch,
      ref = branch,
      type = 'branch',
    })
  end

  -- Remote branches
  for _, branch in ipairs(refs.list_remote_branches()) do
    table.insert(items, {
      text = '󰞶  ' .. branch,
      ref = branch,
      type = 'remote',
    })
  end

  -- Tags
  for _, tag in ipairs(refs.list_tags()) do
    table.insert(items, {
      text = '󰓻  ' .. tag,
      ref = tag,
      type = 'tag',
    })
  end

  -- HEAD
  for _, head in ipairs(refs.list_heads()) do
    table.insert(items, {
      text = '󰥨  ' .. head,
      ref = head,
      type = 'head',
    })
  end

  Snacks.picker.pick(vim.tbl_deep_extend('force', {
    source = 'worktrees_create',
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    preview = 'git_log',
    confirm = function(picker, item)
      picker:close()
      if item and item.ref then
        -- Prompt for branch name
        local branch_name = input.get_user_input('Branch name', {
          strip_spaces = true,
          prepend = item.ref:match('[^/]+$'),
        })

        if branch_name then
          worktrees.add_worktree({
            branch = branch_name,
            base_ref = item.ref,
            track_upstream = item.type == 'remote',
          })
        end
      end
    end,
    win = {
      input = {
        prompt = '  Create Worktree ',
      },
    },
  }, opts))
end

---Get default picker configuration for worktrees
---This can be used to integrate with snacks.nvim configuration
---@return table
function M.picker_config()
  return {
    worktrees = {
      finder = function()
        local worktrees = require('worktrees')
        return vim.tbl_map(format_worktree, worktrees.get_worktrees())
      end,
      format = 'file',
      confirm = function(picker, item)
        if item and item.path then
          require('worktrees').switch_to(item.path)
        end
        picker:close()
      end,
      win = {
        input = {
          prompt = '  Worktrees ',
        },
      },
    },
  }
end

return M
