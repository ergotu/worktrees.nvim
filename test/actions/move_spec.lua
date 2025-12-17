describe('actions.move', function()
  local move
  local input_mock
  local notification_mock
  local worktree_mock
  local shared_mock
  local vim_mock

  before_each(function()
    -- Reset mocks
    vim_mock = {
      fn = {
        isdirectory = function()
          return 0
        end,
        fnameescape = function(path)
          return path
        end,
      },
      uv = {
        cwd = function()
          return '/home/user/project'
        end,
      },
      cmd = function() end,
    }

    input_mock = {
      select_worktree = function(opts, callback)
        callback({ path = '/home/user/worktree1', branch = 'feature/test' })
      end,
      get_user_input = function(prompt, opts)
        return '/home/user/worktree2'
      end,
    }

    notification_mock = {
      warn = function() end,
      info = function() end,
      error = function() end,
    }

    worktree_mock = {
      move = function(source, destination)
        return { success = true, stdout = {}, stderr = {} }
      end,
    }

    shared_mock = {
      emit_event = function() end,
    }

    _G.vim = vim_mock
    package.loaded['worktrees.lib.input'] = input_mock
    package.loaded['worktrees.lib.notification'] = notification_mock
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock
    package.loaded['worktrees.actions.shared'] = shared_mock

    move = require('worktrees.actions.move')
  end)

  after_each(function()
    package.loaded['worktrees.actions.move'] = nil
    _G.vim = nil
  end)

  it('moves a worktree to new location', function()
    local called_source = nil
    local called_dest = nil

    worktree_mock.move = function(source, destination)
      called_source = source
      called_dest = destination
      return { success = true, stdout = {}, stderr = {} }
    end

    move.move()

    assert.equals('/home/user/worktree1', called_source)
    assert.equals('/home/user/worktree2', called_dest)
  end)

  it('emits WorktreeMoved event on success', function()
    local event_data = nil

    shared_mock.emit_event = function(event, data)
      event_data = { event = event, data = data }
    end

    move.move()

    assert.equals('Moved', event_data.event)
    assert.equals('/home/user/worktree1', event_data.data.old_path)
    assert.equals('/home/user/worktree2', event_data.data.new_path)
  end)

  it('warns when destination already exists', function()
    vim_mock.fn.isdirectory = function()
      return 1
    end

    local error_called = false
    notification_mock.error = function()
      error_called = true
    end

    move.move()

    assert.is_true(error_called)
  end)

  it('handles move failure', function()
    worktree_mock.move = function()
      return { success = false, stdout = {}, stderr = { 'move failed' } }
    end

    local error_called = false
    notification_mock.error = function()
      error_called = true
    end

    move.move()

    assert.is_true(error_called)
  end)
end)
