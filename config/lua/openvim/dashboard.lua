-- openvim start screen. Replaces Neovim's default intro splash with our own
-- branded dashboard when launched with no file arguments.

local M = {}

local LOGO = {
  '                                  __     __            ',
  '   ____  ____  ___  ____  _   __ /_/ ___ ___          ',
  '  / __ \\/ __ \\/ _ \\/ __ \\| | / / / // __ `__ \\        ',
  ' / /_/ / /_/ /  __/ / / /| |/ / / // / / / / /        ',
  ' \\____/ .___/\\___/_/ /_/ |___/_/ /_/ /_/ /_/          ',
  '     /_/                                              ',
}

local function hints(provider)
  return {
    '',
    'AI Neovim distribution  ·  provider: ' .. provider,
    '',
    '  e   new file            ',
    '  f   find file (:find)   ',
    '  s   :OpenvimStatus      ',
    '  q   quit                ',
    '',
    'Type to start  ·  <Tab> accepts AI suggestions',
  }
end

function M.open(provider)
  -- Only take over a genuinely empty start: no args, no stdin, empty buffer.
  if vim.fn.argc() ~= 0 then return end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf) ~= '' then return end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines > 1 or (lines[1] and lines[1] ~= '') then return end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'openvim_dashboard'

  local content = {}
  for _, l in ipairs(LOGO) do content[#content + 1] = l end
  for _, l in ipairs(hints(provider)) do content[#content + 1] = l end

  -- Center vertically and horizontally.
  local win = vim.api.nvim_get_current_win()
  local w = vim.api.nvim_win_get_width(win)
  local h = vim.api.nvim_win_get_height(win)
  local width = 0
  for _, l in ipairs(content) do width = math.max(width, vim.fn.strdisplaywidth(l)) end
  local pad = string.rep(' ', math.max(0, math.floor((w - width) / 2)))

  local out = {}
  local top = math.max(0, math.floor((h - #content) / 2))
  for _ = 1, top do out[#out + 1] = '' end
  for _, l in ipairs(content) do out[#out + 1] = pad .. l end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modifiable = false
  vim.api.nvim_win_set_buf(win, buf)

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = 'no'

  local function map(lhs, rhs)
    vim.keymap.set('n', lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end
  map('e', '<cmd>enew<cr>')
  map('f', ':find ') -- ':' enters cmdline so you can type a name; <Tab> completes
  map('s', '<cmd>OpenvimStatus<cr>')
  map('q', '<cmd>qa<cr>')
  map('i', '<cmd>enew<cr>i')
end

return M
