local Component = require "neogiF.lib.ui.component"
local util = require "neogit.lib.util"

local filter = util.filter

local Element = {}

function Element.new(buf)
  local self = {
    buf = buf,
    layout = {},
  }
  setmetatable(self, { __index = Element })
  return self
end

function Element._print_component(indent, c, _options)
  local output = string.rep("  ", indent)
  if c.options.hidden then
    output = output .. "(H)"
  elseif c.position then
    local text = ""
    if c.position.row_start == c.position.row_end then
      text = c.position.row_start
    else
      text = c.position.row_start .. " - " .. c.position.row_end
    end

    if c.position.col_end ~= -1 then
      text = text .. " | " .. c.position.col_start .. " - " .. c.position.col_end
    end

    output = output .. "[" .. text .. "]"
  end

  output = output .. " " .. c:get_tag()

  if c.tag == "text" then
    output = output .. " '" .. c.value .. "'"
  end

  for k, v in pairs(c.options) do
    if k ~= "tag" and k ~= "hidden" then
      output = output .. " " .. k .. "=" .. tostring(v)
    end
  end

  print(output)
end

function Element._visualize_tree(indent, components, options)
  for _, c in ipairs(components) do
    Element._print_component(indent, c, options)
    if (c.tag == "col" or c.tag == "row") and not (options.collapse_hidden_components and c.options.hidden) then
      Element._visualize_tree(indent + 1, c.children, options)
    end
  end
end

function Element._find_component(components, f, options)
  for _, c in ipairs(components) do
    if (options.include_hidden and c.options.hidden) or not c.options.hidden then
      if c.tag == "col" or c.tag == "row" then
        local res = Element._find_component(c.children, f, options)

        if res then
          return res
        end
      end

      if f(c) then
        return c
      end
    end
  end

  return nil
end

function Element:find_component(f, options)
  return Element._find_component(self.layout, f, options or {})
end

function Element._find_components(components, f, result, options)
  for _, c in ipairs(components) do
    if c.tag == "col" or c.tag == "row" then
      Element._find_components(c.children, f, result, options)
    end

    if f(c) then
      table.insert(result, c)
    end
  end
end

function Element:find_components(f, options)
  local result = {}
  Element._find_components(self.layout, f, result, options or {})
  return result
end

function Element:get_component_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:find_component(function(c)
    return c:is_under_cursor(cursor)
  end)
end

function Element:get_component_stack_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:find_components(function(c)
    return c:is_under_cursor(cursor)
  end)
end

function Element.visualize_component(c, options)
  Element._print_component(0, c, options or {})
  if c.tag == "col" or c.tag == "row" then
    Element._visualize_tree(1, c.children, options or {})
  end
end

function Element.visualize_tree(components, options)
  print "root"
  Element._visualize_tree(1, components, options or {})
end

function Element:_render(first_line, first_col, parent, components, flags)
  local curr_line = first_line

  if flags.in_row then
    local col_start = first_col
    local col_end
    local highlights = {}
    local text = ""

    for i, c in ipairs(components) do
      c.parent = parent
      c.index = i
      if not c.options.hidden then
        c.position = {}
        c.position.row_start = curr_line - first_line + 1
        local highlight = c:get_highlight()
        if c.tag == "text" then
          local padding_left = flags.in_nested_row and "" or c:get_padding_left(i == 1)
          text = padding_left .. text

          col_start = col_start + #padding_left
          col_end = col_start + #c.value
          c.position.col_start = col_start
          c.position.col_end = col_end - 1
          text = text .. c.value
          if highlight then
            table.insert(highlights, {
              from = col_start,
              to = col_end,
              name = highlight,
            })
          end
          col_start = col_end
        elseif c.tag == "row" then
          flags.in_nested_row = true
          local padding_left = flags.in_nested_row and "" or c:get_padding_left(i == 1)
          local res = self:_render(curr_line, col_start, c, c.children, flags)
          flags.in_nested_row = false

          res.text = padding_left .. res.text

          if c.position.col_end then
            c.position.col_end = c.position.col_end + #padding_left
          end

          text = text .. res.text

          for _, h in ipairs(res.highlights) do
            h.to = h.to + #padding_left
            table.insert(highlights, h)
          end

          col_end = col_start + #res.text
          c.position.col_start = col_start
          c.position.col_end = col_end
          col_start = col_end
        else
          error("The row component does not support having a `" .. c.tag .. "` as child")
        end
        c.position.row_end = c.position.row_start
      end
    end

    if flags.in_nested_row then
      return {
        text = text,
        highlights = highlights,
      }
    end

    self.buf:set_lines(curr_line - 1, curr_line, false, { text })

    for _, h in ipairs(highlights) do
      self.buf:add_highlight(curr_line - 1, h.from, h.to, h.name, 0)
    end

    curr_line = curr_line + 1
  else
    for i, c in ipairs(components) do
      c.parent = parent
      c.index = i
      if not c.options.hidden then
        c.position = {}
        c.position.row_start = curr_line - first_line + 1
        c.position.col_start = 0
        c.position.col_end = -1
        local sign = c:get_sign()
        local highlight = c:get_highlight()
        if c.tag == "text" then
          local padding_left = c:get_padding_left()
          local text = padding_left .. c.value
          self.buf:set_lines(curr_line - 1, curr_line, false, { text })
          if highlight then
            self.buf:add_highlight(curr_line - 1, c.position.col_start, c.position.col_end, highlight, 0)
          end
          if sign then
            self.buf:place_sign(curr_line, sign, "hl")
          end
          curr_line = curr_line + 1
        elseif c.tag == "col" then
          curr_line = curr_line + self:_render(curr_line, 0, c, c.children, flags)
        elseif c.tag == "row" then
          flags.in_row = true
          curr_line = curr_line + self:_render(curr_line, 0, c, c.children, flags)
          if sign then
            self.buf:place_sign(curr_line - 1, sign, "hl")
          end
          flags.in_row = false
        end
        c.position.row_end = curr_line - first_line
      else
        if c.tag == "col" then
          self:_render(curr_line, 0, c, c.children, flags)
        elseif c.tag == "row" then
          flags.in_row = true
          self:_render(curr_line, 0, c, c.children, flags)
          flags.in_row = false
        end
      end
    end
  end

  return curr_line - first_line
end

function Element:render(...)
  self.layout = { ... }
  self.layout = filter(self.layout, function(x)
    return type(x) == "table"
  end)
  self:update()
end

-- self shouldn't be called often as it completely rewrites the whole buffer
function Element:update()
  self.buf:unlock()
  local lines_used = self:_render(
    1,
    0,
    Component.new(function()
      return {
        tag = "_root",
        children = self.layout,
      }
    end)(),
    self.layout,
    {}
  )
  self.buf:set_lines(lines_used, -1, false, {})
  self.buf:lock()
end

--- Will only work if something has been rendered
function Element:print_layout_tree(options)
  Element.visualize_tree(self.layout, options)
end

function Element:debug(...)
  Element.visualize_tree({ ... }, {})
end

Element.col = Component.new(function(children, options)
  return {
    tag = "col",
    children = filter(children, function(x)
      return type(x) == "table"
    end),
    options = options,
  }
end)

Element.row = Component.new(function(children, options)
  return {
    tag = "row",
    children = filter(children, function(x)
      return type(x) == "table"
    end),
    options = options,
  }
end)

Element.text = Component.new(function(value, options, ...)
  if ... then
    error "Too many arguments"
  end

  vim.validate {
    options = { options, "table", true },
  }

  return {
    tag = "text",
    value = value or "",
    options = type(options) == "table" and options or nil,
  }
end)

Element.Component = require "neogit.lib.ui.component"

return Element
