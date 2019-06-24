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

function return_tables(t)
    local ret = ""
    for key, value in pairs(t) do
      ret = ret .. "   " .. key .. ": " .. table_tostring(value) .. "\n"
    end
    return ret
end

-- }}}

currwin = ioncore.current()
groupcw = currwin:manager()
groupws = groupcw:manager()
frame = groupws:manager()
-- set current frame to a very small size
newgeom = frame:rqgeom({w=33})
if newgeom.w == 33 then
    return 'ok'
else
    return 'fail: ' .. tostring(frame) .. ' - ' .. tostring(return_tables(newgeom))
end

