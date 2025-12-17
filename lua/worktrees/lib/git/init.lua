---@class GitResult
---@field success boolean
---@field stdout string[]
---@field stderr string[]

---@class GitOpts
---@field args string[]
---@field cwd? string

local M = {}

---Run a git command synchronously
---@param opts GitOpts
---@return GitResult
function M.run(opts)
  local cmd = vim.list_extend({ 'git' }, opts.args)
  local system_opts = {
    text = true,
    cwd = opts.cwd,
  }

  local ok, result = pcall(function()
    return vim.system(cmd, system_opts):wait()
  end)

  if not ok then
    return {
      success = false,
      stdout = {},
      stderr = { 'Git command failed: ' .. tostring(result) },
    }
  end

  local stdout_lines = result.stdout and vim.split(result.stdout, '\n', { trimempty = true }) or {}
  local stderr_lines = result.stderr and vim.split(result.stderr, '\n', { trimempty = true }) or {}

  return {
    success = result.code == 0,
    stdout = stdout_lines,
    stderr = stderr_lines,
  }
end

---Run a git command asynchronously
---@param opts GitOpts
---@param callback fun(result: GitResult)
function M.run_async(opts, callback)
  local cmd = vim.list_extend({ 'git' }, opts.args)
  local system_opts = {
    text = true,
    cwd = opts.cwd,
  }

  local ok, err = pcall(function()
    vim.system(cmd, system_opts, function(result)
      local stdout_lines = result.stdout and vim.split(result.stdout, '\n', { trimempty = true })
        or {}
      local stderr_lines = result.stderr and vim.split(result.stderr, '\n', { trimempty = true })
        or {}

      callback({
        success = result.code == 0,
        stdout = stdout_lines,
        stderr = stderr_lines,
      })
    end)
  end)

  if not ok then
    callback({
      success = false,
      stdout = {},
      stderr = { 'Git command failed: ' .. tostring(err) },
    })
  end
end

---Get the git repository root directory
---@param cwd? string Optional working directory
---@return string|nil
function M.root(cwd)
  local result = M.run({
    args = { 'rev-parse', '--show-toplevel' },
    cwd = cwd,
  })

  if result.success and #result.stdout > 0 then
    return result.stdout[1]
  end

  return nil
end

---Check if the current repository is bare
---@param cwd? string Optional working directory
---@return boolean
function M.is_bare(cwd)
  local result = M.run({
    args = { 'rev-parse', '--is-bare-repository' },
    cwd = cwd,
  })

  if result.success and #result.stdout > 0 then
    return result.stdout[1] == 'true'
  end

  return false
end

return M
