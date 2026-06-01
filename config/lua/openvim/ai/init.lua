-- openvim AI layer. Wires features and exposes user commands.

local M = {}

function M.setup(cfg)
  M.cfg = cfg

  local complete = require('openvim.ai.complete')
  complete.setup(cfg)
  require('openvim.ai.edit').setup(cfg)
  require('openvim.ai.agent').setup(cfg)

  vim.api.nvim_create_user_command('OpenvimToggle', function()
    local on = complete.toggle()
    vim.notify('openvim autocomplete ' .. (on and 'enabled' or 'disabled'))
  end, { desc = 'Toggle inline autocomplete' })

  vim.api.nvim_create_user_command('OpenvimProvider', function(o)
    local backends = require('openvim.ai.backends')
    local name = o.args
    if not backends[name] then
      vim.notify('openvim: unknown provider "' .. name .. '". Available: '
        .. table.concat(backends.names(), ', '), vim.log.levels.ERROR)
      return
    end
    cfg.provider = name
    require('openvim.settings').set('provider', name)
    vim.notify('openvim provider -> ' .. name .. ' (saved)')
  end, {
    nargs = 1,
    desc = 'Switch AI provider',
    complete = function()
      return require('openvim.ai.backends').names()
    end,
  })

  vim.api.nvim_create_user_command('OpenvimStatus', function()
    vim.notify(string.format(
      'openvim ai\n  provider: %s\n  model: %s\n  debounce: %dms',
      cfg.provider, cfg.models[cfg.provider] or '?', cfg.debounce_ms))
  end, { desc = 'Show AI status' })
end

return M
