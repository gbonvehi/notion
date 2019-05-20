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
local resizemode = WFrame.begin_kbresize(currwin)
local oldgeom = resizemode:geom()
print_tables("old", oldgeom)
WMoveresMode.resize(resizemode, 0, -1, 0, 0)
-- WMoveresMode.rqgeom(resizemode, {x=0, y=0, w=10, h=10})
local newgeom = resizemode:rqgeom({x=0, y=0, w=10, h=10})
print_tables("new", newgeom)
resizemode.resize(0, -1, 0, 0)
resizemode:finish()
-- local scr = ioncore.current():screen_of()
-- mod_query.query_workspace(scr)
local currwin = ioncore.current()
local frame=ioncore.find_manager(currwin, "WFrame")
mod_query.query_workspace(frame)

