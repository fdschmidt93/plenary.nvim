M = {}

M.deepcopy = function(obj)
  local mt = getmetatable(obj)
  local copy = vim.deepcopy(obj)

  if mt then
    setmetatable(copy, mt)
  end

  return copy
end

return M
