local Buffer = {}

local API_NS = "nvim_buf_"
local API_NS_LEN = #API_NS

-- transform builtin buffer functions to OOP
for fn_name, fn_ref in pairs(vim.api) do
  local ns = fn_name:sub(1, API_NS_LEN)
  if ns == API_NS then
    local shorthand = fn_name:sub(API_NS_LEN + 1)
    Buffer[shorthand] = function(self, ...)
      fn_ref(self.handle, ...)
    end
  end
end

function Buffer:lock()
  self:set_option("readonly", true)
  self:set_option("modifiable", false)
end

function Buffer:unlock()
  self:set_option("readonly", false)
  self:set_option("modifiable", true)
end

function Buffer:set_filetype(ft)
  self:call(vim.cmd("setlocal filetype=" .. ft))
end

function Buffer:new(opts)
  opts = opts or {}
  opts.listed = vim.F.if_nil(opts.listed, true)
  opts.scratch = vim.F.if_nil(opts.listed, false)
  opts.handle = opts.handle or vim.api.nvim_create_buf(opts.listed, opts.scratch)
  local obj = setmetatable({
    handle = opts.handle,
  }, { __index = self })
  return obj
end

return Buffer
