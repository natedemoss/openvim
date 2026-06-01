-- openvim: a Neovim distribution with AI built in.
-- This module sets sane defaults, branding, and wires up the AI layer.

local M = {}

-- User-tunable config. Override by passing a table to setup(), e.g.
-- require('openvim').setup({ ai = { provider = 'ollama' } })
M.config = {
  ai = {
    enabled = true,
    -- 'claude' | 'ollama' | 'openai'. Env OPENVIM_PROVIDER wins if set.
    provider = vim.env.OPENVIM_PROVIDER or 'claude',
    debounce_ms = 250, -- wait this long after typing stops before requesting
    max_tokens = 48,   -- short completions = snappy on CPU; raise for longer blocks
    prefix_lines = 60, -- context above cursor (smaller = faster prompt eval)
    suffix_lines = 15, -- context below cursor
    -- Models for inline autocomplete (FIM). Base models on Ollama.
    models = {
      claude = 'claude-haiku-4-5-20251001',
      ollama = 'qwen2.5-coder:0.5b-base', -- base (FIM) model; fastest on CPU. Use 1.5b-base for quality.
      openai = 'gpt-4o-mini',
    },
    -- Models for inline edit + agent chat (instruction-following / instruct).
    chat_models = {
      claude = 'claude-haiku-4-5-20251001',
      ollama = 'qwen2.5-coder:1.5b', -- instruct model (NOT base) for following instructions
      openai = 'gpt-4o-mini',
    },
  },
}

local function set_defaults()
  local g, opt = vim.g, vim.opt
  g.mapleader = ' '
  g.maplocalleader = ' '

  opt.number = true
  opt.relativenumber = true
  opt.expandtab = true
  opt.shiftwidth = 2
  opt.tabstop = 2
  opt.smartindent = true
  opt.termguicolors = true
  opt.signcolumn = 'yes'
  opt.updatetime = 250
  opt.ignorecase = true
  opt.smartcase = true
  opt.undofile = true
  opt.clipboard = 'unnamedplus'
  opt.scrolloff = 6
  opt.splitright = true
  opt.splitbelow = true
  opt.path:append('**') -- makes :find search recursively from the cwd

  -- Branding: hide Neovim's built-in intro and own the window title.
  opt.shortmess:append('I') -- no default ":help nvim" / "NVIM is open source" intro
  opt.title = true
  opt.titlestring = 'openvim'
end

local function deep_extend(into, from)
  for k, v in pairs(from or {}) do
    if type(v) == 'table' and type(into[k]) == 'table' then
      deep_extend(into[k], v)
    else
      into[k] = v
    end
  end
end

function M.setup(opts)
  deep_extend(M.config, opts)
  set_defaults()

  -- A provider saved via :OpenvimProvider persists across sessions and wins
  -- over the env/default (unless setup() was passed an explicit provider).
  if not (opts and opts.ai and opts.ai.provider) then
    local saved = require('openvim.settings').load()
    if saved.provider then M.config.ai.provider = saved.provider end
  end

  -- Branding: replace the default intro with the openvim dashboard.
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      require('openvim.dashboard').open(M.config.ai.provider)
    end,
  })

  if M.config.ai.enabled then
    require('openvim.ai').setup(M.config.ai)
  end
end

return M
