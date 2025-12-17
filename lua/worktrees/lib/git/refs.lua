local git = require('worktrees.lib.git')

---@class ForEachRefOpts
---@field format? string
---@field points_at? string
---@field merged? string
---@field sort? string
---@field patterns? string[]
---@field cwd? string

local M = {}

---Execute git for-each-ref command
---@param opts? ForEachRefOpts
---@return GitResult
function M.for_each_ref(opts)
  opts = opts or {}
  local args = { 'for-each-ref' }

  if opts.format then
    table.insert(args, '--format=' .. opts.format)
  end
  if opts.points_at then
    table.insert(args, '--points-at=' .. opts.points_at)
  end
  if opts.merged then
    table.insert(args, '--merged=' .. opts.merged)
  end
  if opts.sort then
    table.insert(args, '--sort=' .. opts.sort)
  end

  if opts.patterns then
    for _, pattern in ipairs(opts.patterns) do
      table.insert(args, pattern)
    end
  end

  return git.run({
    args = args,
    cwd = opts.cwd,
  })
end

---List git references with optional filtering
---@param patterns? string[] Patterns to match (e.g., {'refs/heads/', 'refs/remotes/'})
---@param opts? {format?: string, sort?: string, cwd?: string}
---@return string[]
function M.list(patterns, opts)
  opts = opts or {}
  local result = M.for_each_ref({
    format = opts.format or '%(refname:short)',
    sort = opts.sort or '-committerdate',
    patterns = patterns,
    cwd = opts.cwd,
  })

  return result.success and result.stdout or {}
end

---List all tags
---@param opts? {cwd?: string}
---@return string[]
function M.list_tags(opts)
  return M.list({ 'refs/tags/' }, opts)
end

---List all branches (local and remote)
---@param opts? {cwd?: string}
---@return string[]
function M.list_branches(opts)
  local local_branches = M.list_local_branches(opts)
  local remote_branches = M.list_remote_branches(nil, opts)

  local all_branches = {}
  for _, branch in ipairs(local_branches) do
    table.insert(all_branches, branch)
  end
  for _, branch in ipairs(remote_branches) do
    table.insert(all_branches, branch)
  end

  return all_branches
end

---List local branches
---@param opts? {cwd?: string}
---@return string[]
function M.list_local_branches(opts)
  return M.list({ 'refs/heads/' }, opts)
end

---List remote branches
---@param remote? string Filter by specific remote
---@param opts? {cwd?: string}
---@return string[]
function M.list_remote_branches(remote, opts)
  local branches = M.list({ 'refs/remotes/' }, opts)

  if not remote then
    return branches
  end

  local filtered = {}
  local prefix = remote .. '/'
  for _, branch in ipairs(branches) do
    if branch:sub(1, #prefix) == prefix then
      table.insert(filtered, branch)
    end
  end

  return filtered
end

---List special HEAD references
---@param opts? {cwd?: string}
---@return string[]
function M.list_heads(opts)
  opts = opts or {}
  local heads = { 'HEAD', 'ORIG_HEAD', 'FETCH_HEAD', 'MERGE_HEAD', 'CHERRY_PICK_HEAD' }
  local present = {}

  for _, head in ipairs(heads) do
    local result = git.run({
      args = { 'rev-parse', '--verify', '--quiet', head },
      cwd = opts.cwd,
    })
    if result.success then
      table.insert(present, head)
    end
  end

  return present
end

return M
