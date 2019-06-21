-- {{{ Table printing

function table_tostring (tt)
  if type(tt) == "table" then
    local sb = {}
    local first = true
    table.insert(sb, "{ ");
    for key, value in pairs (tt) do
      if first then first = false else table.insert(sb, ", ") end
      if "number" == type (key) then
	  table.insert(sb, table_tostring (value))
      else
	  table.insert(sb, key)
	  table.insert(sb, "=")
	  table.insert(sb, table_tostring (value))
      end
    end
    table.insert(sb, " }");
    return table.concat(sb)
  elseif type (tt) == "number" then
    return tostring(tt)
  else
    return '"' .. tostring(tt) .. '"'
  end
end

function print_tables(str,t)
    print(str .. ":")
    for key, value in ipairs(t) do
      print("   " .. key .. ": " .. table_tostring(value))
    end
end

-- }}}


local currwin = ioncore.current()
local groupcw = currwin:manager()
local frame = groupcw:manager()
-- set current frame to a very small size
frame.rqgeom({w=33})

