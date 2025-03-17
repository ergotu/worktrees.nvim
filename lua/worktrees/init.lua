local config = require('worktrees.config')
local M = {}

function M.setup(opts)
  config.setup(opts)
end

-- Core module exports for testing access
M.git = {
  worktree = require('worktrees.lib.git.worktree'),
  refs = require('worktrees.lib.git.refs'),
  git = require('worktrees.lib.git'),
  branch = require('worktrees.lib.git.branch'),
}
M.util = require('worktrees.lib.util')
M.notification = require('worktrees.lib.notification')

return M
