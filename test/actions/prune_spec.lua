describe('actions.prune', function()
  local prune
  local input_mock
  local notification_mock
  local worktree_mock
  local cleanup_mock

  before_each(function()
    -- Reset mocks
    input_mock = {
      get_confirmation = function()
        return true
      end,
    }

    notification_mock = {
      warn = function() end,
      info = function() end,
      error = function() end,
    }

    worktree_mock = {
      prune = function(opts)
        if opts and opts.dry_run then
          return { success = true, stdout = { 'stale worktree found' }, stderr = {} }
        end
        return { success = true, stdout = {}, stderr = {} }
      end,
    }

    cleanup_mock = {
      suggest = function()
        return nil
      end,
    }

    package.loaded['worktrees.lib.input'] = input_mock
    package.loaded['worktrees.lib.notification'] = notification_mock
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock
    package.loaded['worktrees.lib.cleanup'] = cleanup_mock

    prune = require('worktrees.actions.prune')
  end)

  after_each(function()
    package.loaded['worktrees.actions.prune'] = nil
  end)

  it('runs dry-run first then actual prune', function()
    local calls = {}

    worktree_mock.prune = function(opts)
      table.insert(calls, opts)
      if opts and opts.dry_run then
        return { success = true, stdout = { 'stale data' }, stderr = {} }
      end
      return { success = true, stdout = {}, stderr = {} }
    end

    prune.prune()

    assert.equals(2, #calls)
    assert.is_true(calls[1].dry_run)
    assert.is_nil(calls[2].dry_run)
  end)

  it('shows cleanup suggestions if available', function()
    cleanup_mock.suggest = function()
      return 'Stale worktrees found'
    end

    local info_messages = {}
    notification_mock.info = function(msg)
      table.insert(info_messages, msg)
    end

    prune.prune()

    assert.is_true(#info_messages > 0)
  end)

  it('cancels when user declines confirmation', function()
    input_mock.get_confirmation = function()
      return false
    end

    local warn_called = false
    notification_mock.warn = function()
      warn_called = true
    end

    prune.prune()

    assert.is_true(warn_called)
  end)

  it('handles when no stale data exists', function()
    worktree_mock.prune = function(opts)
      return { success = true, stdout = {}, stderr = {} }
    end

    local info_called = false
    notification_mock.info = function(msg)
      if msg:match('No stale') then
        info_called = true
      end
    end

    prune.prune()

    assert.is_true(info_called)
  end)

  it('handles dry-run failure', function()
    worktree_mock.prune = function(opts)
      if opts and opts.dry_run then
        return { success = false, stdout = {}, stderr = { 'check failed' } }
      end
      return { success = true, stdout = {}, stderr = {} }
    end

    local error_called = false
    notification_mock.error = function()
      error_called = true
    end

    prune.prune()

    assert.is_true(error_called)
  end)
end)
