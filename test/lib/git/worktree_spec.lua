describe('lib.git.worktree', function()
  local worktree
  local git_mock

  before_each(function()
    -- Mock the git module
    git_mock = {
      run = function(opts)
        return { success = true, stdout = {}, stderr = {} }
      end,
      run_async = function(opts, callback) end,
    }

    package.loaded['worktrees.lib.git'] = git_mock

    -- Reload the worktree module
    package.loaded['worktrees.lib.git.worktree'] = nil
    worktree = require('worktrees.lib.git.worktree')
  end)

  after_each(function()
    package.loaded['worktrees.lib.git'] = nil
    package.loaded['worktrees.lib.git.worktree'] = nil
  end)

  describe('add', function()
    it('adds a worktree with minimal options', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.add('/path/to/worktree')

      assert.are.same({ 'worktree', 'add', '/path/to/worktree' }, called_with.args)
    end)

    it('adds a worktree with branch option', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.add('/path/to/worktree', { branch = 'feature' })

      assert.are.same({ 'worktree', 'add', '-b', 'feature', '/path/to/worktree' }, called_with.args)
    end)

    it('adds a worktree with commitish', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.add('/path/to/worktree', { commitish = 'main' })

      assert.are.same({ 'worktree', 'add', '/path/to/worktree', 'main' }, called_with.args)
    end)

    it('adds a worktree with track option', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.add('/path/to/worktree', { track = true })

      assert.are.same({ 'worktree', 'add', '--track', '/path/to/worktree' }, called_with.args)
    end)

    it('adds a worktree with lock option', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.add('/path/to/worktree', { lock = true })

      assert.are.same({ 'worktree', 'add', '--lock', '/path/to/worktree' }, called_with.args)
    end)

    it('adds a worktree with cwd option', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.add('/path/to/worktree', { cwd = '/repo' })

      assert.are.equal('/repo', called_with.cwd)
    end)
  end)

  describe('list', function()
    it('lists worktrees and parses porcelain output', function()
      git_mock.run = function(opts)
        return {
          success = true,
          stdout = {
            'worktree /home/user/repo',
            'HEAD abc123',
            'branch refs/heads/main',
            '',
            'worktree /home/user/repo-feature',
            'HEAD def456',
            'branch refs/heads/feature',
          },
          stderr = {},
        }
      end

      local worktrees = worktree.list()

      assert.are.equal(2, #worktrees)
      assert.are.equal('/home/user/repo', worktrees[1].path)
      assert.are.equal('abc123', worktrees[1].head)
      assert.are.equal('refs/heads/main', worktrees[1].branch)
      assert.are.equal('/home/user/repo-feature', worktrees[2].path)
      assert.are.equal('def456', worktrees[2].head)
      assert.are.equal('refs/heads/feature', worktrees[2].branch)
    end)

    it('handles detached worktrees without branch', function()
      git_mock.run = function(opts)
        return {
          success = true,
          stdout = {
            'worktree /home/user/repo',
            'HEAD abc123',
            'detached',
          },
          stderr = {},
        }
      end

      local worktrees = worktree.list()

      assert.are.equal(1, #worktrees)
      assert.are.equal('/home/user/repo', worktrees[1].path)
      assert.is_nil(worktrees[1].branch)
    end)

    it('returns empty table on git failure', function()
      git_mock.run = function(opts)
        return { success = false, stdout = {}, stderr = { 'error' } }
      end

      local worktrees = worktree.list()

      assert.are.same({}, worktrees)
    end)

    it('passes cwd option to git', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.list({ cwd = '/repo' })

      assert.are.equal('/repo', called_with.cwd)
    end)
  end)

  describe('remove', function()
    it('removes a worktree', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.remove('/path/to/worktree')

      assert.are.same({ 'worktree', 'remove', '/path/to/worktree' }, called_with.args)
    end)

    it('removes a worktree with force option', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.remove('/path/to/worktree', { force = true })

      assert.are.same({ 'worktree', 'remove', '--force', '/path/to/worktree' }, called_with.args)
    end)

    it('removes a worktree with cwd option', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.remove('/path/to/worktree', { cwd = '/repo' })

      assert.are.equal('/repo', called_with.cwd)
    end)
  end)

  describe('remove_async', function()
    it('removes a worktree asynchronously', function()
      local called_with = nil
      local callback_called = false

      git_mock.run_async = function(opts, callback)
        called_with = opts
        callback({ success = true, stdout = {}, stderr = {} })
      end

      worktree.remove_async('/path/to/worktree', {}, function(result)
        callback_called = true
      end)

      assert.are.same({ 'worktree', 'remove', '/path/to/worktree' }, called_with.args)
      assert.is_true(callback_called)
    end)
  end)

  describe('lock', function()
    it('locks a worktree without reason', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.lock('/path/to/worktree')

      assert.are.same({ 'worktree', 'lock', '/path/to/worktree' }, called_with.args)
    end)

    it('locks a worktree with reason', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.lock('/path/to/worktree', { reason = 'in use' })

      assert.are.same(
        { 'worktree', 'lock', '--reason', 'in use', '/path/to/worktree' },
        called_with.args
      )
    end)
  end)

  describe('unlock', function()
    it('unlocks a worktree', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.unlock('/path/to/worktree')

      assert.are.same({ 'worktree', 'unlock', '/path/to/worktree' }, called_with.args)
    end)
  end)

  describe('move', function()
    it('moves a worktree to new location', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.move('/old/path', '/new/path')

      assert.are.same({ 'worktree', 'move', '/old/path', '/new/path' }, called_with.args)
    end)
  end)

  describe('repair', function()
    it('repairs all worktrees without specific paths', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.repair()

      assert.are.same({ 'worktree', 'repair' }, called_with.args)
    end)

    it('repairs specific worktree paths', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.repair({ paths = { '/path1', '/path2' } })

      assert.are.same({ 'worktree', 'repair', '/path1', '/path2' }, called_with.args)
    end)
  end)

  describe('prune', function()
    it('prunes without options', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.prune()

      assert.are.same({ 'worktree', 'prune' }, called_with.args)
    end)

    it('prunes with dry run', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.prune({ dry_run = true })

      assert.are.same({ 'worktree', 'prune', '--dry-run' }, called_with.args)
    end)

    it('prunes with verbose and expire options', function()
      local called_with = nil
      git_mock.run = function(opts)
        called_with = opts
        return { success = true, stdout = {}, stderr = {} }
      end

      worktree.prune({ verbose = true, expire = '7.days.ago' })

      assert.are.same(
        { 'worktree', 'prune', '--verbose', '--expire', '7.days.ago' },
        called_with.args
      )
    end)
  end)
end)
