local git = require('worktrees.lib.git')

---@class WorktreeAddOpts
---@field branch? string
---@field commitish? string
---@field track? boolean
---@field lock? boolean
---@field cwd? string

---@class WorktreeListOpts
---@field cwd? string

---@class WorktreeRemoveOpts
---@field force? boolean
---@field cwd? string

---@class Worktree
---@field path string
---@field branch string|nil
---@field head string

local M = {}

---Add a new git worktree
---@param path string
---@param opts? WorktreeAddOpts
---@return GitResult
function M.add(path, opts)
  opts = opts or {}
  local args = { 'worktree', 'add' }

  if opts.branch then
    table.insert(args, '-b')
    table.insert(args, opts.branch)
  end
  if opts.track then
    table.insert(args, '--track')
  end
  if opts.lock then
    table.insert(args, '--lock')
  end
  table.insert(args, path)
  if opts.commitish then
    table.insert(args, opts.commitish)
  end

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---List all git worktrees
---@param opts? WorktreeListOpts
---@return Worktree[]
function M.list(opts)
  opts = opts or {}
  local result = git.run({
    args = { 'worktree', 'list', '--porcelain' },
    cwd = opts.cwd,
  })

  if not result.success then
    return {}
  end

  local worktrees = {}
  local current = {}

  for _, line in ipairs(result.stdout) do
    if line:match('^worktree ') then
      if current.path then
        table.insert(worktrees, current)
      end
      current = { path = line:sub(10) }
    elseif line:match('^HEAD ') then
      current.head = line:sub(6)
    elseif line:match('^branch ') then
      current.branch = line:sub(8)
    end
  end

  if current.path then
    table.insert(worktrees, current)
  end

  return worktrees
end

---Remove a git worktree
---@param path string
---@param opts? WorktreeRemoveOpts
---@return GitResult
function M.remove(path, opts)
  opts = opts or {}
  local args = { 'worktree', 'remove' }

  if opts.force then
    table.insert(args, '--force')
  end
  table.insert(args, path)

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---Remove a git worktree asynchronously
---@param path string
---@param opts? WorktreeRemoveOpts
---@param callback fun(result: GitResult)
function M.remove_async(path, opts, callback)
  opts = opts or {}
  local args = { 'worktree', 'remove' }

  if opts.force then
    table.insert(args, '--force')
  end
  table.insert(args, path)

  git.run_async({
    args = args,
    cwd = opts.cwd,
  }, callback)
end

---@class WorktreeLockOpts
---@field reason? string Reason for locking
---@field cwd? string

---Lock a git worktree to prevent removal
---@param path string
---@param opts? WorktreeLockOpts
---@return GitResult
function M.lock(path, opts)
  opts = opts or {}
  local args = { 'worktree', 'lock' }

  if opts.reason then
    table.insert(args, '--reason')
    table.insert(args, opts.reason)
  end
  table.insert(args, path)

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---@class WorktreeUnlockOpts
---@field cwd? string

---Unlock a git worktree to allow removal
---@param path string
---@param opts? WorktreeUnlockOpts
---@return GitResult
function M.unlock(path, opts)
  opts = opts or {}
  local args = { 'worktree', 'unlock', path }

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---@class WorktreeMoveOpts
---@field cwd? string

---Move a git worktree to a new location
---@param source string Current path of the worktree
---@param destination string New path for the worktree
---@param opts? WorktreeMoveOpts
---@return GitResult
function M.move(source, destination, opts)
  opts = opts or {}
  local args = { 'worktree', 'move', source, destination }

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---@class WorktreeRepairOpts
---@field paths? string[] Specific paths to repair
---@field cwd? string

---Repair git worktree administrative files
---@param opts? WorktreeRepairOpts
---@return GitResult
function M.repair(opts)
  opts = opts or {}
  local args = { 'worktree', 'repair' }

  if opts.paths then
    for _, path in ipairs(opts.paths) do
      table.insert(args, path)
    end
  end

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---@class WorktreePruneOpts
---@field dry_run? boolean Show what would be removed
---@field verbose? boolean Report all removals
---@field expire? string Prune working trees older than given time
---@field cwd? string

---Prune stale worktree metadata
---@param opts? WorktreePruneOpts
---@return GitResult
function M.prune(opts)
  opts = opts or {}
  local args = { 'worktree', 'prune' }

  if opts.dry_run then
    table.insert(args, '--dry-run')
  end
  if opts.verbose then
    table.insert(args, '--verbose')
  end
  if opts.expire then
    table.insert(args, '--expire')
    table.insert(args, opts.expire)
  end

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

return M
