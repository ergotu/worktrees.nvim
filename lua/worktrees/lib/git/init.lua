local Job = require('plenary.job')
local notification = require('worktrees.lib.notification')

---@class GitResult
---@field success boolean
---@field code number
---@field stdout string[]
---@field stderr string[]

---@class RunOpts
---@field args string[]
---@field cwd? string
---@field callback? fun(result: GitResult)

local M = {}

---@class GitCommand
---@field job Job
---@field result GitResult|nil
---@field callback fun(result: GitResult)|nil
local GitCommand = {}
GitCommand.__index = GitCommand

M.Command = GitCommand

---Create new GitCommand instance
---@param opts RunOpts
---@return GitCommand
function GitCommand:new(opts)
  local instance = setmetatable({}, self)
  instance.job = nil
  instance.result = nil
  instance.callback = opts.callback

  local stdout = {}
  local stderr = {}
  local code = nil

  ---@diagnostic disable-next-line: missing-fields
  instance.job = Job:new({
    command = 'git',
    args = opts.args,
    cwd = opts.cwd or vim.uv.cwd(),
    on_stdout = function(_, line)
      table.insert(stdout, line)
    end,
    on_stderr = function(_, line)
      table.insert(stderr, line)
    end,
    on_exit = function(_, exit_code, _)
      code = exit_code
      instance.result = {
        success = code == 0,
        code = code,
        stdout = stdout,
        stderr = stderr,
      }
      if instance.callback then
        instance.callback(instance.result)
      end
    end,
  })

  return instance
end

---Start async execution
function GitCommand:start()
  self.job:start()
  return self
end

---Wait for command completion
---@return GitResult
function GitCommand:wait()
  self.job:sync() -- No pcall needed
  return self.result or {
    success = false,
    code = 1,
    stdout = {},
    stderr = {},
  }
end

---@param opts RunOpts
---@return GitResult
function M.run(opts)
  notification.command_info(opts.args)
  return GitCommand:new(opts):wait()
end

---@param opts RunOpts
---@return GitCommand
function M.run_async(opts)
  notification.command_info(opts.args)
  return GitCommand:new(opts):start()
end

---@return string[]
function M.root()
  return GitCommand:new({
    args = { 'rev-parse', '--show-toplevel' },
  })
    :wait().stdout
end

function M.is_bare()
  local output = GitCommand:new({
    args = { 'rev-parse', '--is-bare-repository' },
  })
    :wait().stdout
  return output and output[1]:lower():gsub('%s+', '') == 'true'
end

return M
