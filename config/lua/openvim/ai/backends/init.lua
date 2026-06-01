-- Backend registry. Each backend exposes complete(ctx, cb).
-- Add a new provider by dropping a module here and listing it below.

local M = {
  claude = 'openvim.ai.backends.claude',
  ollama = 'openvim.ai.backends.ollama',
  openai = 'openvim.ai.backends.openai',
}

function M.get(name)
  local path = M[name]
  if not path then return nil, 'unknown provider: ' .. tostring(name) end
  local ok, mod = pcall(require, path)
  if not ok then return nil, 'failed to load ' .. path .. ': ' .. mod end
  return mod
end

function M.names()
  local out = {}
  for k in pairs(M) do
    if type(M[k]) == 'string' then out[#out + 1] = k end
  end
  table.sort(out)
  return out
end

return M
