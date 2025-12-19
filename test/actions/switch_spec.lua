describe('actions.switch', function()
  local switch_action
  local input_mock
  local notification_mock
  local shared_mock
  local config_mock
  local recents_mock
  local vim_mock
  local selected_worktree
  local before_hook_called
  local after_hook_called

  before_each(function()
    -- Reset state
    selected_worktree = { path = '/home/user/target-worktree', branch = 'feature/test' }
    before_hook_called = false
    after_hook_called = false

    vim_mock = {
      uv = {
        cwd = function()
          return '/home/user/current-worktree'
        end,
      },
    }

    _G.vim = vim_mock

    -- Mock input module
    input_mock = {
      select_worktree = function(opts, callback)
        callback(selected_worktree)
      end,
    }
    package.loaded['worktrees.lib.input'] = input_mock

    -- Mock notification module
    notification_mock = {
      warn = function() end,
    }
    package.loaded['worktrees.lib.notification'] = notification_mock

    -- Mock shared module
    shared_mock = {
      switch_to_worktree = function() end,
      emit_event = function() end,
    }
    package.loaded['worktrees.actions.shared'] = shared_mock

    -- Mock config module
    config_mock = {
      values = {
        hooks = {
          before_switch = nil,
          after_switch = nil,
        },
      },
    }
    package.loaded['worktrees.config'] = config_mock

    -- Mock recents module
    recents_mock = {
      add = function() end,
    }
    package.loaded['worktrees.lib.recents'] = recents_mock

    -- Reload module
    package.loaded['worktrees.actions.switch'] = nil
    switch_action = require('worktrees.actions.switch')
  end)

  after_each(function()
    _G.vim = nil
    package.loaded['worktrees.actions.switch'] = nil
    package.loaded['worktrees.lib.input'] = nil
    package.loaded['worktrees.lib.notification'] = nil
    package.loaded['worktrees.actions.shared'] = nil
    package.loaded['worktrees.config'] = nil
    package.loaded['worktrees.lib.recents'] = nil
  end)

  describe('switch', function()
    it('switches to selected worktree', function()
      local switched_to = nil
      shared_mock.switch_to_worktree = function(path)
        switched_to = path
      end

      switch_action.switch()
      assert.are.equal('/home/user/target-worktree', switched_to)
    end)

    it('warns when no worktree is selected', function()
      selected_worktree = nil
      local warn_called = false
      notification_mock.warn = function(msg)
        warn_called = true
        assert.is_truthy(msg:match('No worktree selected'))
      end

      switch_action.switch()
      assert.is_true(warn_called)
    end)

    it('does not switch when no worktree is selected', function()
      selected_worktree = nil
      local switch_called = false
      shared_mock.switch_to_worktree = function()
        switch_called = true
      end

      switch_action.switch()
      assert.is_false(switch_called)
    end)

    it('adds worktree to recents', function()
      local added_path = nil
      local added_branch = nil
      recents_mock.add = function(path, branch)
        added_path = path
        added_branch = branch
      end

      switch_action.switch()
      assert.are.equal('/home/user/target-worktree', added_path)
      assert.are.equal('feature/test', added_branch)
    end)

    it('emits Switched event', function()
      local emitted_event = nil
      local emitted_data = nil
      shared_mock.emit_event = function(event, data)
        emitted_event = event
        emitted_data = data
      end

      switch_action.switch()
      assert.are.equal('Switched', emitted_event)
      assert.are.equal('/home/user/target-worktree', emitted_data.path)
      assert.are.equal('/home/user/current-worktree', emitted_data.previous_path)
    end)

    it('calls before_switch hook when configured', function()
      local hook_new_path = nil
      local hook_old_path = nil
      config_mock.values.hooks.before_switch = function(new_path, old_path)
        before_hook_called = true
        hook_new_path = new_path
        hook_old_path = old_path
      end

      switch_action.switch()
      assert.is_true(before_hook_called)
      assert.are.equal('/home/user/target-worktree', hook_new_path)
      assert.are.equal('/home/user/current-worktree', hook_old_path)
    end)

    it('calls after_switch hook when configured', function()
      local hook_new_path = nil
      local hook_old_path = nil
      config_mock.values.hooks.after_switch = function(new_path, old_path)
        after_hook_called = true
        hook_new_path = new_path
        hook_old_path = old_path
      end

      switch_action.switch()
      assert.is_true(after_hook_called)
      assert.are.equal('/home/user/target-worktree', hook_new_path)
      assert.are.equal('/home/user/current-worktree', hook_old_path)
    end)

    it('calls hooks in correct order', function()
      local call_order = {}

      config_mock.values.hooks.before_switch = function()
        table.insert(call_order, 'before_hook')
      end

      shared_mock.switch_to_worktree = function()
        table.insert(call_order, 'switch')
      end

      recents_mock.add = function()
        table.insert(call_order, 'recents')
      end

      shared_mock.emit_event = function()
        table.insert(call_order, 'event')
      end

      config_mock.values.hooks.after_switch = function()
        table.insert(call_order, 'after_hook')
      end

      switch_action.switch()

      assert.are.equal('before_hook', call_order[1])
      assert.are.equal('switch', call_order[2])
      assert.are.equal('recents', call_order[3])
      assert.are.equal('event', call_order[4])
      assert.are.equal('after_hook', call_order[5])
    end)

    it('does not call hooks when no worktree is selected', function()
      selected_worktree = nil

      config_mock.values.hooks.before_switch = function()
        before_hook_called = true
      end

      config_mock.values.hooks.after_switch = function()
        after_hook_called = true
      end

      switch_action.switch()
      assert.is_false(before_hook_called)
      assert.is_false(after_hook_called)
    end)

    it('passes empty options to select_worktree', function()
      local select_opts = nil
      input_mock.select_worktree = function(opts, callback)
        select_opts = opts
        callback(selected_worktree)
      end

      switch_action.switch()
      assert.is_not_nil(select_opts)
      assert.are.same({}, select_opts)
    end)

    it('handles worktree with nil branch', function()
      selected_worktree = { path = '/home/user/detached-worktree', branch = nil }

      local added_branch = 'not-nil'
      recents_mock.add = function(path, branch)
        added_branch = branch
      end

      switch_action.switch()
      assert.is_nil(added_branch)
    end)

    it('captures previous path before switching', function()
      local captured_previous = nil
      shared_mock.emit_event = function(event, data)
        captured_previous = data.previous_path
      end

      switch_action.switch()
      assert.are.equal('/home/user/current-worktree', captured_previous)
    end)

    it('does not add to recents when worktree not selected', function()
      selected_worktree = nil
      local add_called = false
      recents_mock.add = function()
        add_called = true
      end

      switch_action.switch()
      assert.is_false(add_called)
    end)

    it('does not emit event when worktree not selected', function()
      selected_worktree = nil
      local event_called = false
      shared_mock.emit_event = function()
        event_called = true
      end

      switch_action.switch()
      assert.is_false(event_called)
    end)
  end)
end)
