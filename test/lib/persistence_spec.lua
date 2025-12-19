describe('lib.persistence', function()
  local persistence
  local original_vim
  local original_io
  local vim_mock
  local io_mock
  local test_data_dir
  local files

  before_each(function()
    original_vim = _G.vim
    original_io = _G.io
    test_data_dir = '/tmp/worktrees-test'

    files = {}

    vim_mock = {
      fn = {
        stdpath = function()
          return '/tmp'
        end,
        isdirectory = function(path)
          if path == test_data_dir then
            return 1
          end
          return 0
        end,
        mkdir = function() end,
        filereadable = function(path)
          return files[path] and 1 or 0
        end,
        delete = function(path)
          files[path] = nil
          return 0
        end,
      },
      json = {
        encode = function(data)
          return '{"test":"data"}'
        end,
        decode = function(str)
          return { test = 'data' }
        end,
      },
      log = {
        levels = {
          WARN = 3,
          INFO = 2,
        },
      },
      notify = function() end,
      trim = function(s)
        return s:match('^%s*(.-)%s*$')
      end,
      schedule = function(fn)
        fn()
      end,
    }

    io_mock = {
      open = function(filepath, mode)
        if mode == 'r' then
          local content = files[filepath]
          if content then
            return {
              read = function()
                return content
              end,
              close = function() end,
            }
          end
          return nil
        elseif mode == 'w' then
          return {
            write = function(data)
              files[filepath] = data
            end,
            close = function() end,
          }
        end
      end,
    }

    _G.vim = vim_mock
    _G.io = io_mock

    package.loaded['worktrees.lib.persistence'] = nil
    persistence = require('worktrees.lib.persistence')
  end)

  after_each(function()
    package.loaded['worktrees.lib.persistence'] = nil
    _G.vim = original_vim
    _G.io = original_io
  end)

  it('writes JSON data to file', function()
    local data = { key = 'value' }
    local result = persistence.write_json('test.json', data)

    assert.is_true(result)
  end)

  it('reads JSON data from file', function()
    persistence.write_json('test.json', { key = 'value' })

    local result = persistence.read_json('test.json')

    assert.is_not_nil(result)
    assert.equals('data', result.test)
  end)

  it('returns nil when file does not exist', function()
    vim_mock.fn.filereadable = function()
      return 0
    end

    local result = persistence.read_json('nonexistent.json')

    assert.is_nil(result)
  end)

  it('returns nil when file is empty', function()
    files[test_data_dir .. '/empty.json'] = ''

    local result = persistence.read_json('empty.json')

    assert.is_nil(result)
  end)

  it('returns nil when JSON decode fails', function()
    files[test_data_dir .. '/invalid.json'] = 'invalid json'
    vim_mock.json.decode = function()
      error('decode failed')
    end

    local result = persistence.read_json('invalid.json')

    assert.is_nil(result)
  end)

  it('deletes file successfully', function()
    local result = persistence.delete('test.json')

    assert.is_true(result)
  end)

  it('returns true when deleting non-existent file', function()
    vim_mock.fn.filereadable = function()
      return 0
    end

    local result = persistence.delete('nonexistent.json')

    assert.is_true(result)
  end)

  it('handles write failure gracefully', function()
    vim_mock.json.encode = function()
      error('encode failed')
    end

    local result = persistence.write_json('test.json', {})

    assert.is_false(result)
  end)

  it('handles file open failure for write', function()
    io_mock.open = function()
      return nil
    end

    local result = persistence.write_json('test.json', { key = 'value' })

    assert.is_false(result)
  end)
end)
