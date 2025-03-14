local git = require('worktrees.lib.git')

local M = {}

---@class SetUpstreamOpts
---@field cwd? string

---@param upstream string The upstream branch name
---@param opts? SetUpstreamOpts
---@return GitResult
function M.set_upstream(upstream, opts)
  opts = opts or {}
  return git.run({
    args = { 'branch', '--set-upstream-to=' .. upstream },
    cwd = opts.cwd,
  })
end

return M
