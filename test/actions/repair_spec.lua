describe('actions.repair', function()
  local repair
  local input_mock
  local notification_mock
  local worktree_mock
  local vim_mock

  before_each(function()
    -- Reset mocks
    vim_mock = {
      fn = {
        confirm = function()
          return 1 -- Choose "All"
        end,
      },
    }

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
      repair = function(opts)
        return { success = true, stdout = { 'repaired' }, stderr = {} }
      end,
    }

    _G.vim = vim_mock
    package.loaded['worktrees.lib.input'] = input_mock
    package.loaded['worktrees.lib.notification'] = notification_mock
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    repair = require('worktrees.actions.repair')
  end)

  after_each(function()
    package.loaded['worktrees.actions.repair'] = nil
    _G.vim = nil
  end)

  it('repairs all worktrees when "All" selected', function()
    local called_with_opts = nil

    worktree_mock.repair = function(opts)
      called_with_opts = opts
      return { success = true, stdout = { 'repaired' }, stderr = {} }
    end

    repair.repair()

    assert.is_nil(called_with_opts)
  end)

  it('repairs specific worktree when "Specific" selected', function()
    vim_mock.fn.confirm = function()
      return 2 -- Choose "Specific"
    end

    local called_with_opts = nil

    worktree_mock.repair = function(opts)
      called_with_opts = opts
      return { success = true, stdout = {}, stderr = {} }
    end

    repair.repair()

    assert.is_not_nil(called_with_opts)
    assert.is_not_nil(called_with_opts.paths)
    assert.equals('/home/user/worktree1', called_with_opts.paths[1])
  end)

  it('cancels when "Cancel" selected', function()
    vim_mock.fn.confirm = function()
      return 3 -- Choose "Cancel"
    end

    local warn_called = false
    notification_mock.warn = function()
      warn_called = true
    end

    repair.repair()

    assert.is_true(warn_called)
  end)

  it('handles repair failure', function()
    worktree_mock.repair = function()
      return { success = false, stdout = {}, stderr = { 'repair failed' } }
    end

    local error_called = false
    notification_mock.error = function()
      error_called = true
    end

    repair.repair()

    assert.is_true(error_called)
  end)
end)
