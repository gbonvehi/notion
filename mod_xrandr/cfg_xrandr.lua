-- For honest workspaces, the initial outputs information, which determines the
-- physical screen that a workspace wants to be on, is part of the C class
-- WGroupWS. For "full screen workspaces" and scratchpads, we only keep this
-- information in a temporary list.
InitialOutputs={}

function getInitialOutputs(ws)
    if obj_is(ws, "WGroupCW") or is_scratchpad(ws) then
        return InitialOutputs[ws:name()]
    elseif obj_is(ws, "WGroupWS") then
        return WGroupWS.get_initial_outputs(ws)
    else
        return nil
    end
end

function setInitialOutputs(ws, outputs)
    if obj_is(ws, "WGroupCW") or is_scratchpad(ws) then
        ioncore.warn('if' .. tostring(outputs))
        InitialOutputs[ws:name()] = outputs
    elseif obj_is(ws, "WGroupWS") then
        ioncore.warn('else' .. tostring(outputs))
        WGroupWS.set_initial_outputs(ws, outputs)
    end
end

function nilOrEmpty(t)
    return not t or empty(t)
end

function mod_xrandr.workspace_added(ws)
    if nilOrEmpty(getInitialOutputs(ws)) then
        outputs = mod_xrandr.get_outputs(ws:screen_of(ws))
        outputKeys = {}
        for k,v in pairs(outputs) do
            table.insert(outputKeys, k)
        end
        setInitialOutputs(ws, outputKeys)
    end
    return true
end

function for_all_workspaces_do(fn)
    local workspaces={}
    notioncore.region_i(function(scr)
        scr:managed_i(function(ws)
            table.insert(workspaces, ws)
            return true
        end)
        return true
    end, "WScreen")
    for _,ws in ipairs(workspaces) do
        fn(ws)
    end
end

function mod_xrandr.workspaces_added()
    for_all_workspaces_do(mod_xrandr.workspace_added)
end

function mod_xrandr.screenmanagedchanged(tab)
    if tab.mode == 'add' then
        mod_xrandr.workspace_added(tab.sub);
    end
end

screen_managed_changed_hook = notioncore.get_hook('screen_managed_changed_hook')
if screen_managed_changed_hook then
    screen_managed_changed_hook:add(mod_xrandr.screenmanagedchanged)
end

post_layout_setup_hook = notioncore.get_hook('ioncore_post_layout_setup_hook')
post_layout_setup_hook:add(mod_xrandr.workspaces_added)

function add_safe(t, key, value)
    if t[key] == nil then
        t[key] = {}
    end

    table.insert(t[key], value)
end

-- parameter: list of output names
-- returns: map from screen name to screen
function candidate_screens_for_output(max_screen_id, all_outputs, outputname)
    local retval = {}

    function addIfContainsOutput(screen)
        local outputs_within_screen = mod_xrandr.get_outputs_within(all_outputs, screen)
        if screen:id() <= max_screen_id and outputs_within_screen[outputname] ~= nil then
            retval[screen:name()] = screen
        end
        return true
    end
    notioncore.region_i(addIfContainsOutput, "WScreen")

    return retval
end

-- parameter: maximum screen id, list of all output names, list of output names for which we want the screens
-- returns: map from screen name to screen
function candidate_screens_for_outputs(max_screen_id, all_outputs, outputnames)
    local result = {}

    if outputnames == nil then return result end

    for i,outputname in pairs(outputnames) do
        local screens = candidate_screens_for_output(max_screen_id, all_outputs, outputname)
        for k,screen in pairs(screens) do
             result[k] = screen;
        end
    end
    return result;
end

function firstValue(t)
   local key, value = next(t)
   return value
end

function firstKey(t)
   local key, value = next(t)
   return key
end

function empty(t)
    return not next(t)
end

function singleton(t)
    local first = next(t)
    return first and not next(t, first)
end

function is_scratchpad(ws)
    return package.loaded["mod_sp"] and mod_sp.is_scratchpad(ws)
end

function find_scratchpad(screen)
    local sp
    screen:managed_i(function(ws)
        if is_scratchpad(ws) then
            sp=ws
            return false
        else
            return true
        end
    end)
    return sp
end

function move_if_needed(workspace, screen_id)
    local screen = notioncore.find_screen_id(screen_id)

    if workspace:screen_of() ~= screen then
        if is_scratchpad(workspace) then
        -- Moving a scratchpad to another screen is not meaningful, so instead we move
        -- its content
            local content={}
            workspace:bottom():managed_i(function(reg)
                table.insert(content, reg)
                return true
            end)
            local sp=find_scratchpad(screen)
            for _,reg in ipairs(content) do
                sp:bottom():attach(reg)
            end
            return
        end

        screen:attach(workspace)
    end
end

-- Arrange the workspaces over the first number_of_screens screens
function mod_xrandr.rearrangeworkspaces(max_screen_id)
    -- for each screen id, which workspaces should be on that screen
    new_mapping = {}
    -- workspaces that want to be on an output that's currently not on any screen
    orphans = {}
    -- workspaces that want to be on multiple available outputs
    wanderers = {}

    local all_outputs = mod_xrandr.get_all_outputs()

    -- When moving a "full screen workspace" to another screen, we seem to lose
    -- its placeholder and thereby the possibility to return it from full
    -- screen later. Let's therefore try to close any full screen workspace
    -- before rearranging.
    full_screen_workspaces={}
    for_all_workspaces_do(function(ws)
        if obj_is(ws, "WGroupCW") then table.insert(full_screen_workspaces, ws)
        end
        return true
    end)
    for _,ws in ipairs(full_screen_workspaces) do
        ws:set_fullscreen("false")
    end

    -- round one: divide workspaces in directly assignable,
    -- orphans and wanderers
    function roundone(workspace)
        local screens = candidate_screens_for_outputs(max_screen_id, all_outputs, getInitialOutputs(workspace))
        if nilOrEmpty(screens) then
            table.insert(orphans, workspace)
        elseif singleton(screens) then
            add_safe(new_mapping, firstValue(screens):id(), workspace)
        else
            wanderers[workspace] = screens
        end
        return true
    end
    for_all_workspaces_do(roundone)

    for workspace,screens in pairs(wanderers) do
        -- TODO add to screen with least # of workspaces instead of just the
        -- first one that applies
        if screens[workspace:screen_of():name()] then
            add_safe(new_mapping, workspace:screen_of():id(), workspace)
        else
            add_safe(new_mapping, firstValue(screens):id(), workspace)
        end
    end
    for i,workspace in pairs(orphans) do
        -- TODO add to screen with least # of workspaces instead of just the first one
        add_safe(new_mapping, 0, workspace)
    end

    for screen_id,workspaces in pairs(new_mapping) do
        -- move workspace to that
        for i,workspace in pairs(workspaces) do
            move_if_needed(workspace, screen_id)
        end
    end
end

-- DUPLICATED
-- TODO: DUPLICATED from mod_xinerama, factor to common lua code

-- Helper functions {{{

local table_maxn = table.maxn or function(tbl)
   local c=0
   for k in pairs(tbl) do c=c+1 end
   return c
end

local function max(one, other)
    if one == nil then return other end
    if other == nil then return one end

    return (one > other) and one or other
end

-- creates new table, converts {x,y,w,h} representation to {x,y,xmax,ymax}
local function to_max_representation(screen)
    return {
	x = screen.x,
	y = screen.y,
	xmax = screen.x + screen.w,
	ymax = screen.y + screen.h
    }
end

-- edits passed table, converts representation {x,y,xmax,ymax} to {x,y,w,h},
-- and sorts table of indices (entry screen.ids)
local function fix_representation(screen)
    screen.w = screen.xmax - screen.x
    screen.h = screen.ymax - screen.y
    screen.xmax = nil
    screen.ymax = nil
    table.sort(screen.ids)
end

local function fix_representations(screens)
    for _k, screen in pairs(screens) do
	fix_representation(screen)
    end
end

-- }}}

function mod_xrandr.close_invisible_screens(max_visible_screen_id)
    local invisible_screen_id = max_visible_screen_id + 1
    local invisible_screen = notioncore.find_screen_id(invisible_screen_id)
    while invisible_screen do
        -- note that this may not close the screen when it is still populated by
        -- child windows that cannot be 'rescued'
        invisible_screen:rqclose();

        invisible_screen_id = invisible_screen_id + 1
        invisible_screen = notioncore.find_screen_id(invisible_screen_id)
    end

end

-- find any screens with 0 workspaces and populate them with an empty one
function mod_xrandr.populate_empty_screens()
   local screen_id = 0;
   local screen = notioncore.find_screen_id(screen_id)
   while (screen ~= nil) do
       if screen:mx_count() == 0 then
           notioncore.create_ws(screen)
       end

       screen_id = screen_id + 1
       screen = notioncore.find_screen_id(screen_id)
   end
end

function mod_xrandr.find_max_screen_id(screens)
    local max_screen_id = 0

    for screen_index, screen in ipairs(screens) do
        local screen_id = screen_index - 1
        max_screen_id = max(max_screen_id, screen_id)
    end

    return max_screen_id;
end

--DOC
-- Perform the setup of notion screens.
--
-- The first call sets up the screens of notion, subsequent calls update the
-- current screens
--
-- Returns true on success, false on failure
--
-- Example input: {{x=0,y=0,w=1024,h=768},{x=1024,y=0,w=1280,h=1024}}
function mod_xrandr.setup_screens(screens)
    -- Update screen dimensions or create new screens
    for screen_index, screen in ipairs(screens) do
        local screen_id = screen_index - 1
        local existing_screen = notioncore.find_screen_id(screen_id)

        if existing_screen ~= nil then
            mod_xrandr.update_screen(existing_screen, screen)
        else
            mod_xrandr.setup_new_screen(screen_id, screen)
            if package.loaded["mod_sp"] then
                mod_sp.create_scratchpad(notioncore.find_screen_id(screen_id))
            end
        end
    end
end

--- {{{ Overlapping screens

-- true if [from1, to1] overlaps [from2, to2]
local function overlaps (from1, to1, from2, to2)
    return (from1 < to2) and (from2 < to1)
end

-- true if scr1 overlaps scr2
local function screen_overlaps(scr1, scr2)
    local x_in = overlaps(scr1.x, scr1.xmax, scr2.x, scr2.xmax)
    local y_in = overlaps(scr1.y, scr1.ymax, scr2.y, scr2.ymax)
    return x_in and y_in
end

--DOC
-- Merges overlapping screens. I.e. it finds set of smallest rectangles,
-- such that these rectangles do not overlap and such that they contain
-- all screens.
--
-- Example input format: \{\{x=0,y=0,w=1024,h=768\},\{x=0,y=0,w=1280,h=1024\}\}
function mod_xrandr.merge_overlapping_screens(screens)
    local ret = {}
    for _newnum, _newscreen in ipairs(screens) do
	local newscreen = to_max_representation(_newscreen)
	newscreen.ids = { _newnum }
	local overlaps = true
	local pos
	while overlaps do
	    overlaps = false
	    for prevpos, prevscreen in pairs(ret) do
		if screen_overlaps(prevscreen, newscreen) then
		    -- stabilise ordering
		    if (not pos) or (prevpos < pos) then pos = prevpos end
		    -- merge with the previous screen
		    newscreen.x = math.min(newscreen.x, prevscreen.x)
		    newscreen.y = math.min(newscreen.y, prevscreen.y)
		    newscreen.xmax = math.max(newscreen.xmax, prevscreen.xmax)
		    newscreen.ymax = math.max(newscreen.ymax, prevscreen.ymax)
		    -- merge the indices
		    for _k, _v in ipairs(prevscreen.ids) do
			table.insert(newscreen.ids, _v)
		    end

		    -- delete the merged previous screen
		    table.remove(ret, prevpos)

		    -- restart from beginning
		    overlaps = true
		    break
		end
	    end
	end
	if not pos then pos = table_maxn(ret)+1 end
	table.insert(ret, pos, newscreen)
    end
    fix_representations(ret)
    return ret
end

-- END DUPLICATED

-- refresh xinerama and rearrange workspaces on screen layout updates
function mod_xrandr.screenlayoutupdated()
    notioncore.profiling_start('notion_xrandrrefresh.prof')

    local screens = mod_xrandr.query_screens()
    if screens then
        local merged_screens = mod_xrandr.merge_overlapping_screens(screens)
        mod_xrandr.setup_screens(merged_screens)
        local max_screen_id = mod_xrandr.find_max_screen_id(screens);
        mod_xrandr.close_invisible_screens(max_screen_id)
        mod_xrandr.rearrangeworkspaces(max_screen_id)
    end

    mod_xrandr.populate_empty_screens()

    notioncore.screens_updated(notioncore.rootwin())
    notioncore.profiling_stop()
end

randr_screen_change_notify_hook = notioncore.get_hook('randr_screen_change_notify')

if randr_screen_change_notify_hook then
    randr_screen_change_notify_hook:add(mod_xrandr.screenlayoutupdated)
end
