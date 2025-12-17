describe('actions.shared', function()
  local shared
  local notification_mock
  local vim_mock
  local buffers
  local autocmd_events

  before_each(function()
    -- Setup mocks
    buffers = {}
    autocmd_events = {}

    vim_mock = {
      api = {
        nvim_list_bufs = function()
          local buf_ids = {}
          for id, _ in pairs(buffers) do
            table.insert(buf_ids, id)
          end
          return buf_ids
        end,
        nvim_buf_is_valid = function(buf)
          return buffers[buf] ~= nil
        end,
        nvim_buf_get_name = function(buf)
          return buffers[buf] and buffers[buf].name or ''
        end,
        nvim_buf_delete = function(buf, opts)
          buffers[buf] = nil
        end,
        nvim_exec_autocmds = function(event, opts)
          table.insert(autocmd_events, { event = event, pattern = opts.pattern, data = opts.data })
        end,
      },
      bo = setmetatable({}, {
        __index = function(t, k)
          return buffers[k] or {}
        end,
      }),
      uv = {
        cwd = function()
          return '/home/user/project'
        end,
      },
      cmd = function() end,
      schedule = function(fn)
        fn()
      end,
      fn = {
        filereadable = function(path)
          return 1
        end,
        fnameescape = function(path)
          return path:gsub(' ', '\\ ')
        end,
      },
      inspect = function(tbl)
        -- Simple mock implementation to avoid recursion
        return tostring(tbl)
      end,
    }

    _G.vim = vim_mock

    -- Mock notification
    notification_mock = {
      warn = function() end,
      info = function() end,
      debug = function() end,
    }
    package.loaded['worktrees.lib.notification'] = notification_mock

    -- Reload module
    package.loaded['worktrees.actions.shared'] = nil
    shared = require('worktrees.actions.shared')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.lib.notification'] = nil
    package.loaded['worktrees.actions.shared'] = nil
  end)

  describe('switch_to_worktree', function()
    it('switches to a new worktree', function()
      local cd_called_with = nil
      vim_mock.cmd = function(cmd)
        if type(cmd) == 'string' and cmd:match('^cd ') then
          cd_called_with = cmd:sub(4)
        end
      end

      shared.switch_to_worktree('/home/user/other-project')

      assert.are.equal('/home/user/other-project', cd_called_with)
    end)

    it('does nothing when already in target worktree', function()
      local warned = false
      notification_mock.warn = function()
        warned = true
      end

      shared.switch_to_worktree('/home/user/project')

      assert.is_true(warned)
    end)

    it('mirrors buffers from previous worktree', function()
      buffers[1] = { name = '/home/user/project/foo.lua', buflisted = true }
      buffers[2] = { name = '/home/user/project/bar.lua', buflisted = true }
      buffers[3] = { name = '/home/user/other/baz.lua', buflisted = true }

      local added_buffers = {}
      vim_mock.cmd = function(cmd)
        if type(cmd) == 'string' and cmd:match('^badd ') then
          table.insert(added_buffers, cmd:sub(6))
        end
      end

      shared.switch_to_worktree('/home/user/new-project')

      assert.are.equal(2, #added_buffers)
      assert.are.equal('/home/user/new-project/foo.lua', added_buffers[1])
      assert.are.equal('/home/user/new-project/bar.lua', added_buffers[2])
    end)

    it('deletes old buffers after mirroring', function()
      buffers[1] = { name = '/home/user/project/foo.lua', buflisted = true }
      buffers[2] = { name = '/home/user/project/bar.lua', buflisted = true }

      shared.switch_to_worktree('/home/user/new-project')

      assert.is_nil(buffers[1])
      assert.is_nil(buffers[2])
    end)

    it('only mirrors buffers if file exists in new worktree', function()
      buffers[1] = { name = '/home/user/project/exists.lua', buflisted = true }
      buffers[2] = { name = '/home/user/project/missing.lua', buflisted = true }

      local added_buffers = {}
      vim_mock.fn.filereadable = function(path)
        return path:match('exists') and 1 or 0
      end
      vim_mock.cmd = function(cmd)
        if type(cmd) == 'string' and cmd:match('^badd ') then
          table.insert(added_buffers, cmd:sub(6))
        end
      end

      shared.switch_to_worktree('/home/user/new-project')

      assert.are.equal(1, #added_buffers)
      assert.are.equal('/home/user/new-project/exists.lua', added_buffers[1])
    end)

    it('stores previous worktree path', function()
      shared.switch_to_worktree('/home/user/new-project')

      assert.are.equal('/home/user/project', shared.previous_worktree_path)
    end)
  end)

  describe('emit_event', function()
    it('emits WorktreeCreated event', function()
      shared.emit_event('Created', {
        branch = 'feature',
        path = '/home/user/feature',
        previous_path = '/home/user/main',
      })

      assert.are.equal(1, #autocmd_events)
      assert.are.equal('User', autocmd_events[1].event)
      assert.are.equal('WorktreeCreated', autocmd_events[1].pattern)
      assert.are.equal('feature', autocmd_events[1].data.branch)
      assert.are.equal('/home/user/feature', autocmd_events[1].data.path)
    end)

    it('emits WorktreeSwitched event', function()
      shared.emit_event('Switched', {
        path = '/home/user/feature',
        previous_path = '/home/user/main',
      })

      assert.are.equal(1, #autocmd_events)
      assert.are.equal('WorktreeSwitched', autocmd_events[1].pattern)
    end)

    it('emits WorktreeRemoved event', function()
      shared.emit_event('Removed', {
        path = '/home/user/feature',
      })

      assert.are.equal(1, #autocmd_events)
      assert.are.equal('WorktreeRemoved', autocmd_events[1].pattern)
    end)

    it('includes upstream in event data when provided', function()
      shared.emit_event('Created', {
        branch = 'feature',
        path = '/home/user/feature',
        previous_path = '/home/user/main',
        upstream = 'origin/feature',
      })

      assert.are.equal('origin/feature', autocmd_events[1].data.upstream)
    end)
  end)
end)
