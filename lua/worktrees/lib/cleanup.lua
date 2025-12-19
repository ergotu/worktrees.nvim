local worktree = require('worktrees.lib.git.worktree')
local config = require('worktrees.config')

local M = {}

---@class StaleWorktree
---@field path string
---@field branch string|nil
---@field days_stale integer

---Get stale worktrees based on config
---@return StaleWorktree[]
function M.get_stale()
  if not config.values.cleanup.suggest_stale then
    return {}
  end

  local worktrees, err = worktree.list()
  if not worktrees then
    if err then
      require('worktrees.lib.notification').warn('Failed to list worktrees: ' .. err)
    end
    return {}
  end

  local stale_days = config.values.cleanup.stale_days
  local now = os.time()
  local stale = {}

  for _, wt in ipairs(worktrees) do
    -- Check .git file modification time
    local git_file = wt.path .. '/.git'
    local stat = vim.uv.fs_stat(git_file)

    if stat then
      local mtime = stat.mtime.sec
      local days_old = math.floor((now - mtime) / 86400)

      if days_old >= stale_days then
        table.insert(stale, {
          path = wt.path,
          branch = wt.branch,
          days_stale = days_old,
        })
      end
    end
  end

  return stale
end

---Show stale worktree suggestions
---@return string|nil
function M.suggest()
  local stale = M.get_stale()

  if #stale == 0 then
    return nil
  end

  local lines = { 'Stale worktrees found:' }
  for _, wt in ipairs(stale) do
    local branch_info = wt.branch and (' (' .. wt.branch .. ')') or ''
    table.insert(lines, string.format('  %s%s - %d days old', wt.path, branch_info, wt.days_stale))
  end
  table.insert(lines, '')
  table.insert(lines, 'Run :WorktreeRemove or :WorktreePrune to clean up.')

  return table.concat(lines, '\n')
end

return M
