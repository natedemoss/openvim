-- openvim entry config. Booted via: nvim -u <this file>
-- Makes this repo's lua/ importable, then hands off to the openvim module.

local this = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.expand('<sfile>:p')), ':h')

vim.opt.runtimepath:prepend(this)
package.path = table.concat({
  this .. '/lua/?.lua',
  this .. '/lua/?/init.lua',
  package.path,
}, ';')

require('openvim').setup()
