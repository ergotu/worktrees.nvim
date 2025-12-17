describe('actions.unlock', function()
  local unlock
  local input_mock
  local notification_mock
  local worktree_mock

  before_each(function()
    -- Reset mocks
    input_mock = {
      select_worktree = function(opts, callback)
        callback({ path = '/home/user/worktree1', branch = 'feature/test' })
      end,
    }

    notification_mock = {
      warn = function() end,
      info = function() end,
      error = function() end,
    }

    worktree_mock = {
      unlock = function(path)
        return { success = true, stdout = {}, stderr = {} }
      end,
    }

    package.loaded['worktrees.lib.input'] = input_mock
    package.loaded['worktrees.lib.notification'] = notification_mock
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    unlock = require('worktrees.actions.unlock')
  end)

  after_each(function()
    package.loaded['worktrees.actions.unlock'] = nil
  end)

  it('unlocks a worktree', function()
    local called_with_path = nil

    worktree_mock.unlock = function(path)
      called_with_path = path
      return { success = true, stdout = {}, stderr = {} }
    end

    unlock.unlock()

    assert.equals('/home/user/worktree1', called_with_path)
  end)

  it('handles unlock failure', function()
    worktree_mock.unlock = function()
      return { success = false, stdout = {}, stderr = { 'unlock failed' } }
    end

    local error_called = false
    notification_mock.error = function()
      error_called = true
    end

    unlock.unlock()

    assert.is_true(error_called)
  end)

  it('warns when no worktree selected', function()
    input_mock.select_worktree = function(opts, callback)
      callback(nil)
    end

    local warn_called = false
    notification_mock.warn = function()
      warn_called = true
    end

    unlock.unlock()

    assert.is_true(warn_called)
  end)
end)
