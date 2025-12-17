local config = require('worktrees.config')
local git = require('worktrees.lib.git')

local M = {}

---Calculate worktree path based on configured strategy
---@param branch_name string
---@return string
function M.calculate_path(branch_name)
  local strategy = config.values.path_strategy
  local root = git.root()
  local is_bare = git.is_bare()

  if not root then
    error('Not in a git repository')
  end

  if strategy.type == 'sibling' then
    -- ../branch-name (current default behavior)
    local base_path = is_bare and vim.uv.cwd() or vim.fs.normalize(root .. '/..')
    return vim.fs.normalize(base_path .. '/' .. branch_name)
  elseif strategy.type == 'nested' then
    -- ./worktrees/branch-name
    local base_path = is_bare and vim.uv.cwd() or root
    return vim.fs.normalize(base_path .. '/worktrees/' .. branch_name)
  elseif strategy.type == 'custom' then
    if not strategy.custom or type(strategy.custom) ~= 'function' then
      error('Custom path strategy requires a custom function')
    end
    local custom_path = strategy.custom(branch_name, root)
    if not custom_path then
      error('Custom path strategy function must return a valid path')
    end
    return custom_path
  else
    error('Unknown path strategy: ' .. tostring(strategy.type))
  end
end

return M
