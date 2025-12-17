local M = {}

M.add = require('worktrees.actions.add').add
M.remove = require('worktrees.actions.remove').remove
M.switch = require('worktrees.actions.switch').switch
M.lock = require('worktrees.actions.lock').lock
M.unlock = require('worktrees.actions.unlock').unlock
M.move = require('worktrees.actions.move').move
M.repair = require('worktrees.actions.repair').repair
M.prune = require('worktrees.actions.prune').prune

return M
