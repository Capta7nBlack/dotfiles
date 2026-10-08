local wezterm = require 'wezterm'
local act = wezterm.action
local M = {}
local request_dir = wezterm.home_dir .. '/.wezterm-state/reference-requests/'
local resolver = wezterm.home_dir .. '/.config/nvim/lua/config/open_reference.lua'
local probe = wezterm.config_dir .. '/reference_probe.lua'

local function notify(window, text)
  window:toast_notification('Open reference', text, nil, 4500)
end

local function pending()
  return wezterm.GLOBAL.reference_pending or {}
end

local function read_json(path)
  local file = io.open(path, 'rb')
  if not file then return end
  local contents = file:read('*a'); file:close()
  return wezterm.json_parse(contents)
end

local function real_pane(id)
  local ok, pane = pcall(wezterm.mux.get_pane, id)
  if ok then return pane end
end

-- Copy Mode owns an overlay with its own viewport. Close it before a split,
-- zoom or close, then perform the layout action on the underlying mux pane.
function M.layout_action(action)
  return wezterm.action_callback(function(window, pane)
    local id = window:mux_window():active_pane():pane_id()
    local source = real_pane(id)
    if not source then return end
    window:perform_action(act.CopyMode 'Close', source)
    wezterm.time.call_after(0, function()
      source = real_pane(id)
      if source then window:perform_action(action, source) end
    end)
  end)
end

function M.open(window, pane)
  -- Resolve layout actions through the mux pane rather than the GUI's
  -- current Copy Mode view.
  pane = window:mux_window():active_pane()
  local text = window:get_selection_text_for_pane(pane):match('^%s*(.-)%s*$')
  if text == '' then return notify(window, 'Select a path or function with v, then press Enter.') end
  if #text > 2048 or text:find('[\r\n%z]') then return notify(window, 'Select one path or function reference.') end
  if pane:get_domain_name() ~= 'local' then return notify(window, 'This integration currently opens local checkouts.') end
  local url = pane:get_current_working_dir()
  if not url then return notify(window, 'No project directory reported by this pane.') end
  local cwd = url.file_path
  if wezterm.target_triple:find('windows') then cwd = cwd:gsub('^/([A-Za-z]):', '%1:') end
  local pane_id = pane:pane_id()
  local key = tostring(pane_id)
  local requests = pending()
  if requests[key] and requests[key].text == text then return end
  local serial = (wezterm.GLOBAL.reference_serial or 0) + 1
  wezterm.GLOBAL.reference_serial = serial
  local id = tostring(wezterm.procinfo.pid()) .. '-' .. os.time() .. '-' .. serial
  local input_path, output_path = request_dir .. id .. '.request.json', request_dir .. id .. '.result.json'
  local function current()
    local request = pending()[key]
    return request and request.id == id
  end
  local function release()
    if current() then
      local next_requests = pending(); next_requests[key] = nil
      wezterm.GLOBAL.reference_pending = next_requests
      pcall(function() window:set_left_status('') end)
    end
  end
  local function cleanup(keep_output)
    os.remove(input_path); os.remove(output_path .. '.tmp')
    if not keep_output then os.remove(output_path) end
  end
  local ok, err = pcall(function()
    local file = assert(io.open(input_path, 'wb'))
    assert(file:write(wezterm.json_encode({ text = text, cwd = cwd })))
    assert(file:close())
    wezterm.background_child_process {
      'mise', 'exec', '--', 'nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
      '-l', probe, input_path, output_path, resolver,
    }
  end)
  if not ok then cleanup(); return notify(window, tostring(err)) end
  requests = pending()
  requests[key] = { id = id, text = text }
  wezterm.GLOBAL.reference_pending = requests
  window:set_left_status('Searching reference... ')

  local function open_result(result)
    local source = real_pane(pane_id)
    -- A delayed lookup must not open a pane in a different task or steal focus.
    if not source or window:mux_window():active_pane():pane_id() ~= pane_id then
      cleanup(); release(); return
    end
    if not result.ok then
      cleanup(); release(); return notify(window, result.error or 'Reference search failed.')
    end
    if not result.resolved or #result.resolved.items == 0 then
      cleanup(); release(); return notify(window, 'No matches found for: ' .. text)
    end
    -- Only a confirmed match may change the terminal layout.
    window:perform_action(act.CopyMode 'Close', source)
    wezterm.time.call_after(0, function()
      if not current() then cleanup(); return end
      source = real_pane(pane_id)
      if not source or window:mux_window():active_pane():pane_id() ~= pane_id then cleanup(); release(); return end
      local spawned, new_pane = pcall(function()
        return source:split {
          direction = 'Right', size = 0.5, cwd = cwd,
          args = { 'mise', 'exec', '--', 'nvim', '-c', 'lua require("config.open_reference").from_env()' },
          -- Large search results stay in the temporary result file; the editor
          -- consumes and deletes it instead of repeating the repository scan.
          set_environment_variables = { NVIM_OPEN_REFERENCE = wezterm.json_encode({ resolved_file = output_path }) },
        }
      end)
      cleanup(spawned); release()
      if not spawned then return notify(window, tostring(new_pane)) end
      new_pane:activate()
      wezterm.time.call_after(60, function() os.remove(output_path) end)
    end)
  end

  local attempts = 0
  local function poll()
    attempts = attempts + 1
    local decoded, result = pcall(read_json, output_path)
    if not decoded then cleanup(); release(); return notify(window, 'Could not read reference search results.') end
    if result then
      if not current() then cleanup(); return end
      return open_result(result)
    end
    if attempts >= 250 then
      local was_current = current()
      cleanup(); release()
      if was_current then notify(window, 'Reference search timed out; no pane was opened.') end
      return
    end
    wezterm.time.call_after(0.1, poll)
  end
  wezterm.time.call_after(0.1, poll)
end

function M.apply(config)
  if not wezterm.gui then return end
  local keys = {}
  for _, binding in ipairs(wezterm.gui.default_key_tables().copy_mode) do
    if not (binding.key == 'Enter' and binding.mods == 'NONE') then keys[#keys + 1] = binding end
  end
  keys[#keys + 1] = { key = 'Enter', mods = 'NONE', action = wezterm.action_callback(M.open) }
  config.key_tables = config.key_tables or {}
  config.key_tables.copy_mode = keys
end

return M
