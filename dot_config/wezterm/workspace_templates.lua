-- Saved templates are independent of live WezTerm workspaces.
local wezterm = require 'wezterm'
local act, mux = wezterm.action, wezterm.mux
local M = {}
local directory = wezterm.home_dir .. '/.wezterm-state/templates/'
local resurrect

local function notify(window, message)
  window:toast_notification('Templates', message, nil, 3500)
end

local function guarded(callback)
  return wezterm.action_callback(function(window, pane, ...)
    local ok, err = pcall(callback, window, pane, ...)
    if not ok then
      wezterm.log_error(tostring(err))
      notify(window, tostring(err))
    end
  end)
end

local function template_names()
  local names = {}
  for _, path in ipairs(wezterm.glob(directory .. '*.json')) do
    names[#names + 1] = path:match('([^/\\]+)%.json$')
  end
  table.sort(names)
  return names
end

local function existing_name(name)
  for _, candidate in ipairs(template_names()) do
    if candidate:lower() == name:lower() then return candidate end
  end
end

local function validate_name(name)
  name = name:match('^%s*(.-)%s*$')
  assert(name ~= '', 'Enter a template name.')
  assert(#name <= 100 and not name:find('[\\/:*?"<>|%c]') and not name:find('%.$'),
    'Use a name without path separators or Windows filename punctuation.')
  local device = name:match('^[^.]+'):upper()
  assert(not ({ CON = true, PRN = true, AUX = true, NUL = true })[device]
    and not device:match('^COM%d$') and not device:match('^LPT%d$'), 'That name is reserved by Windows.')
  return name
end

-- Keep a previous copy when replacing a template. Lua's rename on Windows
-- cannot replace an existing destination; recover the original if it fails.
local function write_template(name, state)
  name = validate_name(name)
  local path = directory .. name .. '.json'
  local temporary, previous = path .. '.tmp', path .. '.previous'
  local payload = wezterm.json_encode(state)
  local file = assert(io.open(temporary, 'wb'))
  local written, write_error = file:write(payload)
  local closed, close_error = file:close()
  assert(written and closed, write_error or close_error)
  local old = io.open(path, 'rb')
  if old then
    old:close()
    os.remove(previous)
    assert(os.rename(path, previous))
  end
  local ok, err = os.rename(temporary, path)
  if not ok and old then os.rename(previous, path) end
  assert(ok, err)
end

local function read_template(name)
  local file = assert(io.open(directory .. validate_name(name) .. '.json', 'rb'))
  local contents = file:read('*a')
  file:close()
  local state = wezterm.json_parse(contents)
  assert(type(state.window_states) == 'table' and #state.window_states > 0, 'Template has no windows.')
  for _, window in ipairs(state.window_states) do
    assert(type(window.tabs) == 'table' and #window.tabs > 0, 'Template has no tabs.')
    for _, tab in ipairs(window.tabs) do
      assert(type(tab.pane_tree) == 'table', 'Template has no pane layout.')
    end
  end
  return state
end

local function links()
  return wezterm.GLOBAL.template_instances or {}
end

local function link_instance(instance, template)
  local current = links()
  current[instance] = template
  wezterm.GLOBAL.template_instances = current
end

local function next_instance(template)
  local occupied = {}
  for _, name in ipairs(mux.get_workspace_names()) do occupied[name] = true end
  local counters = wezterm.GLOBAL.template_counters or {}
  local number = counters[template] or 0
  local name
  repeat
    number = number + 1
    name = template .. ' #' .. number
  until not occupied[name]
  counters[template] = number
  wezterm.GLOBAL.template_counters = counters
  return name
end

local function spawn_options(node)
  local opts = {}
  if node.cwd and node.cwd ~= '' then opts.cwd = node.cwd end
  if node.domain then opts.domain = { DomainName = node.domain } end
  return opts
end

local function layout_size(node)
  local width, height = node.width, node.height
  if node.right then
    local right_width, right_height = layout_size(node.right)
    width, height = math.max(width, node.width + 1 + right_width), math.max(height, right_height)
  end
  if node.bottom then
    local bottom_width, bottom_height = layout_size(node.bottom)
    width, height = math.max(width, bottom_width), math.max(height, node.height + 1 + bottom_height)
  end
  return width, height
end

local function restore_panes(node, pane, selected)
  local width, height = layout_size(node)
  if node.is_active then selected.pane = pane end
  if node.bottom then
    local opts = spawn_options(node.bottom)
    opts.direction = 'Bottom'
    local _, bottom_height = layout_size(node.bottom)
    opts.size = bottom_height / height
    selected.children[#selected.children + 1] = { node.bottom, pane:split(opts) }
  end
  if node.right then
    local opts = spawn_options(node.right)
    opts.direction = 'Right'
    local right_width = layout_size(node.right)
    opts.size = right_width / width
    selected.children[#selected.children + 1] = { node.right, pane:split(opts) }
  end
end

-- Every restore uses handles returned by spawn_window/spawn_tab. It never
-- selects an arbitrary GUI window or closes an existing pane/tab.
local function launch(name)
  local state = read_template(name)
  local instance = next_instance(name)
  link_instance(instance, name)
  for _, window_state in ipairs(state.window_states) do
    local first = window_state.tabs[1]
    local opts = spawn_options(first.pane_tree)
    opts.workspace = instance
    if window_state.size then
      opts.width, opts.height = window_state.size.cols, window_state.size.rows
    end
    local first_tab, first_pane, window = mux.spawn_window(opts)
    if window_state.title and window_state.title ~= '' then window:set_title(window_state.title) end
    local active_tab = first_tab
    for index, tab_state in ipairs(window_state.tabs) do
      local tab, pane = first_tab, first_pane
      if index > 1 then tab, pane = window:spawn_tab(spawn_options(tab_state.pane_tree)) end
      if tab_state.title then tab:set_title(tab_state.title) end
      local selected = { pane = pane, children = { { tab_state.pane_tree, pane } } }
      local cursor = 1
      while cursor <= #selected.children do
        local child = selected.children[cursor]
        restore_panes(child[1], child[2], selected)
        cursor = cursor + 1
      end
      selected.pane:activate()
      if tab_state.is_zoomed then tab:set_zoomed(true) end
      if tab_state.is_active then active_tab = tab end
    end
    active_tab:activate()
  end
  mux.set_active_workspace(instance)
  return instance
end

local function strip_runtime(node)
  if type(node) ~= 'table' then return end
  node.text, node.process, node.alt_screen_active, node.pane = nil, nil, nil, nil
  for _, value in pairs(node) do strip_runtime(value) end
end

local function capture(instance, name)
  -- Load the existing layout serializer only when saving, not on every
  -- terminal launch/config reload. Its process/text fields are not templates.
  if not resurrect then
    resurrect = wezterm.plugin.require('https://github.com/MLFlexer/resurrect.wezterm')
    resurrect.state_manager.set_max_nlines(0)
  end
  local state = { workspace = name, window_states = {}, template_version = 1 }
  for _, window in ipairs(mux.all_windows()) do
    if window:get_workspace() == instance then
      state.window_states[#state.window_states + 1] = resurrect.window_state.get_window_state(window)
    end
  end
  assert(#state.window_states > 0, 'The instance is no longer running.')
  strip_runtime(state)
  write_template(name, state)
  link_instance(instance, name)
end

M.create_instance = guarded(function(window, pane)
  local choices = {}
  for _, name in ipairs(template_names()) do choices[#choices + 1] = { id = name, label = name } end
  if #choices == 0 then return notify(window, 'No templates yet. Alt+N creates one.') end
  window:perform_action(act.InputSelector {
    title = 'Create instance from template', fuzzy = true, choices = choices,
    action = guarded(function(w, _, name)
      if name then launch(name) end
    end),
  }, pane)
end)

M.new_template = guarded(function(window, pane)
  window:perform_action(act.PromptInputLine {
    description = 'New template name (arrange its panes, then Alt+S):',
    action = guarded(function(w, p, name)
      if not name then return end
      name = validate_name(name)
      assert(not existing_name(name), 'Template already exists. Use Alt+W to create another instance.')
      local cwd = p:get_current_working_dir()
      cwd = cwd and cwd.file_path or wezterm.home_dir
      if wezterm.target_triple:find('windows') then cwd = cwd:gsub('^/([A-Za-z]):', '%1:') end
      local size = p:tab():get_size()
      write_template(name, { workspace = name, template_version = 1, window_states = {
        { size = size, tabs = { { is_active = true, pane_tree = {
          cwd = cwd, domain = p:get_domain_name(), width = size.cols, height = size.rows, is_active = true,
        } } } },
      } })
      launch(name)
    end),
  }, pane)
end)

M.save_template = guarded(function(window, pane)
  local instance = window:active_workspace()
  local origin = links()[instance]
  -- Existing workspaces created before the upgrade keep their familiar link.
  if origin == nil then origin = existing_name(instance) end
  if origin and existing_name(origin) then
    capture(instance, origin)
    return notify(window, 'Saved template: ' .. origin)
  end
  window:perform_action(act.PromptInputLine {
    description = 'Save this layout as a NEW template:',
    action = guarded(function(w, _, name)
      if not name then return end
      name = validate_name(name)
      assert(not existing_name(name), 'That template exists. Open it with Alt+W to reshape and save it.')
      capture(instance, name)
      notify(w, 'Saved template: ' .. name)
    end),
  }, pane)
end)

M.delete_template = guarded(function(window, pane)
  local choices = {}
  for _, name in ipairs(template_names()) do choices[#choices + 1] = { id = name, label = name } end
  if #choices == 0 then return notify(window, 'No templates to delete.') end
  window:perform_action(act.InputSelector {
    title = 'Delete template (running instances stay open)', fuzzy = true, choices = choices,
    action = guarded(function(w, _, name)
      if not name then return end
      local path = directory .. validate_name(name) .. '.json'
      os.remove(path .. '.deleted')
      assert(os.rename(path, path .. '.deleted'))
      local current = links()
      for instance, origin in pairs(current) do
        if origin == name then current[instance] = false end
      end
      wezterm.GLOBAL.template_instances = current
      notify(w, 'Deleted template: ' .. name .. '. Running instances kept.')
    end),
  }, pane)
end)

M.rename_instance = guarded(function(window, pane)
  local instance = window:active_workspace()
  window:perform_action(act.PromptInputLine {
    description = 'Rename running instance "' .. instance .. '" (template keeps its name):',
    action = guarded(function(w, _, name)
      if not name then return end
      name = validate_name(name)
      for _, live in ipairs(mux.get_workspace_names()) do
        assert(live ~= name or live == instance, 'Another instance already has that name.')
      end
      local current = links()
      local origin = current[instance]
      if origin == nil then origin = existing_name(instance) end
      mux.rename_workspace(instance, name)
      current[instance], current[name] = nil, origin or false
      wezterm.GLOBAL.template_instances = current
      notify(w, 'Instance: ' .. name)
    end),
  }, pane)
end)

return M
