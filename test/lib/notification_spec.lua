describe('lib.notification', function()
  local notification
  local config_mock
  local notifications

  before_each(function()
    -- Mock vim global
    notifications = {}
    _G.vim = {
      log = {
        levels = {
          TRACE = 0,
          DEBUG = 1,
          INFO = 2,
          WARN = 3,
          ERROR = 4,
        },
      },
      notify = function(msg, level, opts)
        table.insert(notifications, { msg = msg, level = level, opts = opts })
      end,
      schedule = function(fn)
        fn()
      end,
      trim = function(str)
        return str:match('^%s*(.-)%s*$')
      end,
    }

    -- Mock config
    config_mock = {
      values = {
        level = _G.vim.log.levels.INFO,
      },
    }
    package.loaded['worktrees.config'] = config_mock

    -- Reload notification module
    package.loaded['worktrees.lib.notification'] = nil
    notification = require('worktrees.lib.notification')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.config'] = nil
    package.loaded['worktrees.lib.notification'] = nil
  end)

  describe('error', function()
    it('sends error notification', function()
      notification.error('Test error')

      assert.are.equal(1, #notifications)
      assert.are.equal('Test error', notifications[1].msg)
      assert.are.equal(_G.vim.log.levels.ERROR, notifications[1].level)
      assert.are.equal('Worktrees', notifications[1].opts.title)
    end)
  end)

  describe('warn', function()
    it('sends warning notification', function()
      notification.warn('Test warning')

      assert.are.equal(1, #notifications)
      assert.are.equal('Test warning', notifications[1].msg)
      assert.are.equal(_G.vim.log.levels.WARN, notifications[1].level)
    end)
  end)

  describe('info', function()
    it('sends info notification', function()
      notification.info('Test info')

      assert.are.equal(1, #notifications)
      assert.are.equal('Test info', notifications[1].msg)
      assert.are.equal(_G.vim.log.levels.INFO, notifications[1].level)
    end)

    it('does not send when level is too low', function()
      config_mock.values.level = _G.vim.log.levels.WARN

      notification.info('Test info')

      assert.are.equal(0, #notifications)
    end)
  end)

  describe('debug', function()
    it('sends debug notification when level permits', function()
      config_mock.values.level = _G.vim.log.levels.DEBUG

      notification.debug('Test debug')

      assert.are.equal(1, #notifications)
      assert.are.equal('Test debug', notifications[1].msg)
      assert.are.equal(_G.vim.log.levels.DEBUG, notifications[1].level)
    end)

    it('does not send when level is too high', function()
      config_mock.values.level = _G.vim.log.levels.INFO

      notification.debug('Test debug')

      assert.are.equal(0, #notifications)
    end)
  end)

  describe('trace', function()
    it('sends trace notification when level permits', function()
      config_mock.values.level = _G.vim.log.levels.TRACE

      notification.trace('Test trace')

      assert.are.equal(1, #notifications)
      assert.are.equal(_G.vim.log.levels.TRACE, notifications[1].level)
    end)
  end)

  describe('command_debug', function()
    it('formats git command for debug output', function()
      config_mock.values.level = _G.vim.log.levels.DEBUG

      notification.command_debug({ 'worktree', 'add', '/path' })

      assert.are.equal(1, #notifications)
      assert.are.equal('Running command: git worktree add /path', notifications[1].msg)
    end)
  end)

  describe('message formatting', function()
    it('trims whitespace from messages', function()
      notification.error('  Test error  ')

      assert.are.equal('Test error', notifications[1].msg)
    end)

    it('handles table messages', function()
      notification.error({ 'Line 1', 'Line 2' })

      assert.are.equal('Line 1\nLine 2', notifications[1].msg)
    end)
  end)
end)
