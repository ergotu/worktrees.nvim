local M = {}

M.add = require('worktrees.actions.add').add
M.remove = require('worktrees.actions.remove').remove
M.switch = require('worktrees.actions.switch').switch

return M
