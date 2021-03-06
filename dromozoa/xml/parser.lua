-- Copyright (C) 2015 Tomoyuki Fujimori <moyu@dromozoa.com>
--
-- This file is part of dromozoa-xml.
--
-- dromozoa-xml is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- dromozoa-xml is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with dromozoa-xml.  If not, see <http://www.gnu.org/licenses/>.

local empty = require "dromozoa.commons.empty"
local linked_hash_table = require "dromozoa.commons.linked_hash_table"
local sequence = require "dromozoa.commons.sequence"
local sequence_writer = require "dromozoa.commons.sequence_writer"
local string_matcher = require "dromozoa.commons.string_matcher"
local utf8 = require "dromozoa.commons.utf8"
local element = require "dromozoa.xml.element"

local ws = "[ \t\r\n]*"
local zero_width_no_break_space = string.char(0xef, 0xbb, 0xbf)

local class = {}

function class.new(this, strict)
  if type(this) == "string" then
    this = string_matcher(this)
  end
  return {
    this = this;
    strict = strict;
    stack = sequence();
  }
end

function class:raise(message)
  local this = self.this
  if message == nil then
    error("parse error at position " .. this.position)
  else
    error(message .. " at position " .. this.position)
  end
end

function class:document()
  local this = self.this
  local stack = self.stack
  self:prolog()
  if not self:element() then
    self:raise("element expected")
  end
  self:misc()
end

function class:element()
  local this = self.this
  local stack = self.stack
  if this:match("<([A-Za-z%_\128-\255][A-Za-z%_0-9%-%.\128-\255]*)") then
    local name = this[1]
    self:attribute_list()
    local attributes = stack:pop()
    if this:match(ws .. ">") then
      stack:push(element(name, attributes))
      return self:content()
    elseif this:match(ws .. "/>") then
      return stack:push(element(name, attributes, sequence()))
    else
      self:raise("unclosed tag")
    end
  end
end

function class:content()
  local this = self.this
  local stack = self.stack
  local that = sequence()
  while true do
    if this:match("</([A-Za-z%_\128-\255][A-Za-z%_0-9%-%.\128-\255]*)") then
      local name = this[1]
      if this:match(ws .. ">") then
        local tag = stack:top()
        if tag[1] == name and tag[3] == nil then
          tag[3] = that
          return true
        else
          self:raise("unmatched tags")
        end
      end
      self:raise("unclosed end tag")
    elseif self:element() then
      that:push(stack:pop())
    elseif self:comment() then
      -- comment
    else
      if not self.strict and this:lookahead("%<%!%[CDATA%[") then
        -- cdata
      elseif this:lookahead("%<") then
        self:raise("invalid content")
      end
      local out = sequence_writer()
      while true do
        if this:match("\r\n") or this:match("[\r\n]") then
          out:write("\n")
        elseif this:match("([^%z\1-\8\10-\31\127%<%>%&]+)") then
          out:write(this[1])
        elseif self:char_ref() then
          out:write(stack:pop())
        elseif self:comment() then
          -- comment
        elseif this:match("%<%!%[CDATA%[(.-)%]%]%>") then
          local cdata = this[1]
          if #cdata > 0 then
            out:write(cdata)
          end
        elseif this:lookahead("%<") then
          break
        else
          self:raise("invalid content")
        end
      end
      if not empty(out) then
        that:push(out:concat())
      end
    end
  end
end

function class:attribute_list()
  local this = self.this
  local stack = self.stack
  local that = linked_hash_table()
  while true do
    if not this:match(ws .. "([A-Za-z%_\128-\255][A-Za-z%_0-9%-%.\128-\255]*)") then
      break
    end
    local name = this[1]
    if self.strict and name == "xmlns" then
      self:raise("attribute name xmlns found")
    end
    if not this:match(ws .. "%=" .. ws) then
      self:raise("invalid attribute")
    end
    if this:match("([%\"%'])") then
      self:attribute_value(this[1])
      local value = stack:pop()
      that[name] = value
    else
      self:raise("invalid attribute value")
    end
  end
  return stack:push(that)
end

function class:attribute_value(quote)
  local this = self.this
  local stack = self.stack
  local out = sequence_writer()
  while true do
    if this:match(quote) then
      return stack:push(out:concat())
    elseif this:match("([%\"%'])") then
      out:write(this[1])
    elseif this:match("\r\n") or this:match("[\r\n]") then
      out:write("\n")
    elseif this:match("([^%z\1-\8\10-\31\127%<%>%&%\"%']+)") then
      out:write(this[1])
    elseif self:char_ref() then
      out:write(stack:pop())
    else
      self:raise("invalid attribute value")
    end
  end
end

function class:comment()
  local this = self.this
  if this:match("%<%!%-%-") then
    while true do
      if this:match("%-%-%>") then
        return true
      elseif not this:match("[^%-]") and not this:match("%-[^%-]") then
        self:raise("invalid comment")
      end
    end
  end
end

function class:char_ref()
  local this = self.this
  local stack = self.stack
  if this:match("%&%#x(%x+)%;") then
    return stack:push(utf8.char(tonumber(this[1], 16)))
  elseif this:match("%&amp%;") then
    return stack:push("&")
  elseif this:match("%&lt%;") then
    return stack:push("<")
  elseif this:match("%&gt%;") then
    return stack:push(">")
  elseif this:match("%&quot%;") then
    return stack:push("\"")
  elseif this:match("%&apos%;") then
    return stack:push("'")
  end
end

function class:prolog()
  local this = self.this
  this:match(zero_width_no_break_space)
  if not self.strict then
    this:match(ws .. "%<%?xml[ \t\r\n].-%?%>")
    self:misc()
    this:match("%<%!DOCTYPE[ \t\r\n].-%>")
  end
  self:misc()
end

function class:misc()
  local this = self.this
  repeat
    this:match(ws)
  until not self:comment()
end

function class:apply()
  local this = self.this
  local stack = self.stack
  self:document()
  if #stack == 1 then
    return stack:pop(), this
  else
    self:raise()
  end
end

local metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, this, strict)
    return setmetatable(class.new(this, strict), metatable)
  end;
})
