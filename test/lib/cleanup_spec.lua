describe('lib.cleanup', function()
  local cleanup
  local worktree_mock
  local notification_mock
  local config_mock
  local vim_mock
  local fs_stats

  before_each(function()
    -- Track fs_stat calls
    fs_stats = {}

    vim_mock = {
      uv = {
        fs_stat = function(path)
          return fs_stats[path]
        end,
      },
    }

    _G.vim = vim_mock

    -- Mock worktree module
    worktree_mock = {
      list = function()
        return {
          { path = '/home/user/worktree1', branch = 'feature/old' },
          { path = '/home/user/worktree2', branch = 'feature/new' },
          { path = '/home/user/worktree3', branch = nil },
        }
      end,
    }
    package.loaded['worktrees.lib.git.worktree'] = worktree_mock

    -- Mock notification module
    notification_mock = {
      warn = function() end,
    }
    package.loaded['worktrees.lib.notification'] = notification_mock

    -- Mock config module
    config_mock = {
      values = {
        cleanup = {
          suggest_stale = true,
          stale_days = 30,
        },
      },
    }
    package.loaded['worktrees.config'] = config_mock

    -- Mock os.time
    _G.os = {
      time = function()
        return 1000000
      end,
    }

    -- Reload module
    package.loaded['worktrees.lib.cleanup'] = nil
    cleanup = require('worktrees.lib.cleanup')
  end)

  after_each(function()
    _G.vim = nil
    _G.os = nil
    package.loaded['worktrees.lib.cleanup'] = nil
    package.loaded['worktrees.lib.git.worktree'] = nil
    package.loaded['worktrees.lib.notification'] = nil
    package.loaded['worktrees.config'] = nil
  end)

  describe('get_stale', function()
    it('returns empty table when suggest_stale is disabled', function()
      config_mock.values.cleanup.suggest_stale = false
      local stale = cleanup.get_stale()
      assert.are.same({}, stale)
    end)

    it('returns empty table when worktree.list returns nil', function()
      worktree_mock.list = function()
        return nil, 'error'
      end
      local stale = cleanup.get_stale()
      assert.are.same({}, stale)
    end)

    it('identifies worktrees older than stale_days', function()
      local now = 1000000
      local thirty_one_days_ago = now - (31 * 86400)
      local twenty_days_ago = now - (20 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = thirty_one_days_ago } }
      fs_stats['/home/user/worktree2/.git'] = { mtime = { sec = twenty_days_ago } }
      fs_stats['/home/user/worktree3/.git'] = { mtime = { sec = thirty_one_days_ago } }

      local stale = cleanup.get_stale()

      assert.are.equal(2, #stale)
      assert.are.equal('/home/user/worktree1', stale[1].path)
      assert.are.equal('feature/old', stale[1].branch)
      assert.are.equal(31, stale[1].days_stale)
      assert.are.equal('/home/user/worktree3', stale[2].path)
      assert.is_nil(stale[2].branch)
      assert.are.equal(31, stale[2].days_stale)
    end)

    it('returns empty table when no worktrees are stale', function()
      local now = 1000000
      local ten_days_ago = now - (10 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = ten_days_ago } }
      fs_stats['/home/user/worktree2/.git'] = { mtime = { sec = ten_days_ago } }
      fs_stats['/home/user/worktree3/.git'] = { mtime = { sec = ten_days_ago } }

      local stale = cleanup.get_stale()
      assert.are.same({}, stale)
    end)

    it('skips worktrees with missing .git file', function()
      local now = 1000000
      local thirty_one_days_ago = now - (31 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = thirty_one_days_ago } }
      -- worktree2 has no fs_stat (missing .git file)
      fs_stats['/home/user/worktree3/.git'] = nil

      local stale = cleanup.get_stale()

      assert.are.equal(1, #stale)
      assert.are.equal('/home/user/worktree1', stale[1].path)
    end)

    it('correctly calculates days_stale', function()
      local now = 1000000
      local sixty_days_ago = now - (60 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = sixty_days_ago } }
      fs_stats['/home/user/worktree2/.git'] = { mtime = { sec = now } }
      fs_stats['/home/user/worktree3/.git'] = { mtime = { sec = now } }

      local stale = cleanup.get_stale()

      assert.are.equal(1, #stale)
      assert.are.equal(60, stale[1].days_stale)
    end)
  end)

  describe('suggest', function()
    it('returns nil when no stale worktrees exist', function()
      local now = 1000000
      local ten_days_ago = now - (10 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = ten_days_ago } }
      fs_stats['/home/user/worktree2/.git'] = { mtime = { sec = ten_days_ago } }
      fs_stats['/home/user/worktree3/.git'] = { mtime = { sec = ten_days_ago } }

      local message = cleanup.suggest()
      assert.is_nil(message)
    end)

    it('returns formatted message with stale worktrees', function()
      local now = 1000000
      local thirty_one_days_ago = now - (31 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = thirty_one_days_ago } }
      fs_stats['/home/user/worktree2/.git'] = { mtime = { sec = now } }
      fs_stats['/home/user/worktree3/.git'] = { mtime = { sec = thirty_one_days_ago } }

      local message = cleanup.suggest()

      assert.is_not_nil(message)
      assert.is_truthy(message:match('Stale worktrees found:'))
      assert.is_truthy(message:match('/home/user/worktree1'))
      assert.is_truthy(message:match('feature/old'))
      assert.is_truthy(message:match('31 days old'))
      assert.is_truthy(message:match('/home/user/worktree3'))
      assert.is_truthy(message:match(':WorktreeRemove'))
      assert.is_truthy(message:match(':WorktreePrune'))
    end)

    it('formats worktrees with and without branch names', function()
      local now = 1000000
      local thirty_one_days_ago = now - (31 * 86400)

      fs_stats['/home/user/worktree1/.git'] = { mtime = { sec = thirty_one_days_ago } }
      fs_stats['/home/user/worktree2/.git'] = { mtime = { sec = now } }
      fs_stats['/home/user/worktree3/.git'] = { mtime = { sec = thirty_one_days_ago } }

      local message = cleanup.suggest()

      -- Check that branch is shown when present
      assert.is_truthy(message:match('/home/user/worktree1.*%(feature/old%)'))
      -- Check that no extra parentheses when branch is nil
      assert.is_truthy(message:match('/home/user/worktree3'))
      assert.is_falsy(message:match('/home/user/worktree3.*%(.*%)'))
    end)
  end)
end)
