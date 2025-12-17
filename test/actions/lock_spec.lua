describe('actions.lock', function()
  local lock
  local input_mock
  local notification_mock
  local worktree_mock

  before_each(function()
    -- Reset mocks
    input_mock = {
      select_worktree = function(opts, callback)
        callback({ path = '/home/user/worktree1', branch = 'feature/test' })
      end,
      get_user_input = function(prompt, opts)
        return 'test reason'
      end,
    }

    notification_mock = {
      warn = function() end,
      info = function() end,
      error = function() end,
    }

    worktree_mock = {
      lock = function(path, opts)
        return { success = true, stdout = {}, stderr = {} }
      end,
    }

    package.loaded['worktrees.lib.input'] = input_mock
    package.loaded['worktrees.lib.notification'] = notification_mock
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    lock = require('worktrees.actions.lock')
  end)

  after_each(function()
    package.loaded['worktrees.actions.lock'] = nil
  end)

  it('locks a worktree with reason', function()
    local called_with_path = nil
    local called_with_opts = nil

    worktree_mock.lock = function(path, opts)
      called_with_path = path
      called_with_opts = opts
      return { success = true, stdout = {}, stderr = {} }
    end

    lock.lock()

    assert.equals('/home/user/worktree1', called_with_path)
    assert.equals('test reason', called_with_opts.reason)
  end)

  it('locks a worktree without reason when empty', function()
    input_mock.get_user_input = function()
      return ''
    end

    local called_with_opts = nil
    worktree_mock.lock = function(path, opts)
      called_with_opts = opts
      return { success = true, stdout = {}, stderr = {} }
    end

    lock.lock()

    assert.is_nil(called_with_opts)
  end)

  it('handles lock failure', function()
    worktree_mock.lock = function()
      return { success = false, stdout = {}, stderr = { 'lock failed' } }
    end

    local error_called = false
    notification_mock.error = function()
      error_called = true
    end

    lock.lock()

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

    lock.lock()

    assert.is_true(warn_called)
  end)
end)
