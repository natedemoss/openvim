-- Persistent user settings, stored as JSON at ~/.openvim/settings.json.
-- Used to remember choices like the AI provider across sessions.

local M = {}

local function path()
  return vim.fn.expand('~/.openvim/settings.json')
end

function M.load()
  local p = path()
  if vim.fn.filereadable(p) == 0 then return {} end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), '\n'))
  if ok and type(data) == 'table' then return data end
  return {}
end

function M.save(tbl)
  local p = path()
  vim.fn.mkdir(vim.fn.fnamemodify(p, ':h'), 'p')
  vim.fn.writefile({ vim.json.encode(tbl) }, p)
end

function M.set(key, value)
  local data = M.load()
  data[key] = value
  M.save(data)
end

return M
