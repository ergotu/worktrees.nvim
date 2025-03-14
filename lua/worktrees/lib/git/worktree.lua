local git = require('worktrees.lib.git')
local notification = require('worktrees.lib.notification')

---@class WorktreeAddOpts
---@field branch? string
---@field track? boolean
---@field lock? boolean
---@field cwd? string

---@class WorktreeListOpts
---@field cwd? string

---@class WorktreeRemoveOpts
---@field force? boolean
---@field cwd? string
---@field callback? fun(result: GitResult)

local M = {}

---@param path string
---@param opts? WorktreeAddOpts
---@return string[]
function M.add(path, opts)
  opts = opts or {}
  local args = { 'worktree', 'add' }

  if opts.branch then
    table.insert(args, '--branch')
    table.insert(args, opts.branch)
  end
  if opts.track then
    table.insert(args, '--track')
  end
  if opts.lock then
    table.insert(args, '--lock')
  end
  table.insert(args, path)

  return git.run({
    args = args,
    cwd = opts.cwd,
  }).stdout
end

---@param opts? WorktreeListOpts
---@return string[]
function M.list(opts)
  opts = opts or {}
  local args = { 'worktree', 'list', '--porcelain' }

  return git.run({
    args = args,
    cwd = opts.cwd,
  }).stdout
end

---@param path string
---@param opts? WorktreeRemoveOpts
---@return GitCommand
function M.remove(path, opts)
  opts = opts or {}
  local args = { 'worktree', 'remove' }

  if opts.force then
    table.insert(args, '--force')
  end
  table.insert(args, path)

  return git.run_async({
    args = args,
    cwd = opts.cwd,
    callback = opts.callback or function(results)
      if results.code ~= 0 then
        notification.error('Failed to remove worktree')
      end
    end,
  })
end

return M
