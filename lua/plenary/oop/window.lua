local Window = {}

local API_NS = "nvim_win_"
local API_NS_LEN = #API_NS

-- transform builtin buffer functions to OOP
for k, v in pairs(vim.api) do
  local ns = k:sub(1, API_NS_LEN)
  if ns == API_NS then
    local cmd = k:sub(API_NS_LEN + 1)
    Window[cmd] = function(self, ...)
      v(self.handle, ...)
    end
  end
end

function Window:new(opts)
  opts = opts or {}
  opts.listed = vim.F.if_nil(opts.listed, true)
  opts.scratch = vim.F.if_nil(opts.listed, false)
  opts.handle = opts.handle or vim.api.nvim_create_buf(opts.listed, opts.scratch)
  local obj = setmetatable({
    handle = opts.handle,
  }, { __index = self })
  return obj
end

return Window
