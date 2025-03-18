local notification = require('worktrees.lib.notification')

local M = {}

-- Store previous worktree path
M.previous_worktree_path = nil

---@param new_path string
---@param previous_path string
local function create_mirrored_buffers(new_path, previous_path)
  local buffers_to_delete = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      local filename = vim.api.nvim_buf_get_name(buf)
      if filename:find(previous_path, 1, true) == 1 then
        local relative_path = filename:sub(#previous_path + 2)
        local new_file = new_path .. '/' .. relative_path

        if vim.fn.filereadable(new_file) == 1 then
          vim.cmd('badd ' .. vim.fn.fnameescape(new_file))
        end
        table.insert(buffers_to_delete, buf)
      end
    end
  end

  -- Delete buffers after iteration to avoid issues
  for _, buf in ipairs(buffers_to_delete) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

---Switch to specified worktree directory
---@param path string Path to worktree directory
---@return nil
function M.switch_to_worktree(path)
  if not path then
    return
  end

  local previous_path = vim.uv.cwd()
  if path == previous_path then
    return notification.warn('Already in the requested worktree')
  end

  vim.schedule(function()
    -- Store previous before changing directory
    M.previous_worktree_path = previous_path

    vim.cmd('cd ' .. path)
    vim.cmd('clearjumps')

    if M.previous_worktree_path then
      create_mirrored_buffers(path, M.previous_worktree_path)
    end

    notification.info('Switched to worktree: ' .. path)
  end)
end

---@alias WorktreeEvent 'Created'|'Switched'|'Removed'
---@alias WorktreeEventData {
---  branch?: string,  -- Only for Created events
---  upstream?: string, -- Only for Created events from remotes
---  path: string }

---Emit worktree-related autocmd events
---@param event WorktreeEvent
---@param data WorktreeEventData
---@return nil
function M.emit_event(event, data)
  notification.debug('Emitting event Worktree' .. event .. ' with data: ' .. vim.inspect(data))
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'Worktree' .. event,
    data = data,
  })
end

return M
