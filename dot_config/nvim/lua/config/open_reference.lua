-- Loaded only by a reference opened from WezTerm Copy Mode.
local M = {}
local uv = vim.uv
local extensions = { py=true, js=true, jsx=true, ts=true, tsx=true, lua=true, go=true,
  rs=true, c=true, h=true, cpp=true, hpp=true, cs=true, java=true, rb=true, php=true,
  json=true, md=true, txt=true, toml=true, yaml=true, yml=true, sql=true, sh=true,
  ps1=true, html=true, css=true, vue=true, svelte=true, xml=true }

local function clean(value)
  value = vim.trim(value)
  local first, last = value:sub(1, 1), value:sub(-1)
  if (first == '`' or first == '"' or first == "'") and first == last then value = value:sub(2, -2) end
  return vim.trim(value)
end

local function path_hint(value)
  local extension = value:match('%.([%w]+)$')
  return value:find('[/\\]') ~= nil or value:sub(1, 1) == '.' or (extension and extensions[extension:lower()])
end

function M.parse(text)
  assert(type(text) == 'string' and #text <= 2048 and not text:find('[\r\n%z]'), 'Select one reference.')
  text = clean(text)
  assert(text ~= '', 'The reference is empty.')
  text = text:match('^%[[^%]]*%]%((.-)%)$') or text
  assert(not text:match('^https?://'), 'Select the local path or function rather than a web URL.')
  local ref = { value = text }
  local path, line, col = text:match('^(.-):(%d+):(%d+)$')
  if not path then path, line = text:match('^(.-)#L(%d+)%-?L?%d*$') end
  if not path then path, line = text:match('^(.-):(%d+)%-?%d*$') end
  if path then
    ref.value, ref.line, ref.col = clean(path), math.max(1, tonumber(line)), math.max(1, tonumber(col) or 1)
  else
    local symbol
    path, symbol = text:match('^(.-)#([%w_.$:]+%(?%)?)$')
    if not path then path, symbol = text:match('^(.-)::([%w_.$:]+%(?%)?)$') end
    if not path then path, symbol = text:match('^(.-):([%w_.$]+%(?%)?)$') end
    if path and path_hint(clean(path)) then ref.value, ref.symbol = clean(path), symbol:gsub('%(%)$', '') end
  end
  if ref.value:sub(1, 7) == 'file://' then ref.value = vim.uri_to_fname(ref.value) end
  ref.value = clean(ref.value)
  ref.is_path = ref.line ~= nil or ref.symbol ~= nil or path_hint(ref.value) or false
  return ref
end

local function absolute(path, base)
  path = path:gsub('\\', '/')
  if path:sub(1, 2) == '~/' then path = vim.fn.expand('~') .. path:sub(2) end
  if not path:match('^%a:/') and path:sub(1, 1) ~= '/' then path = vim.fs.joinpath(base, path) end
  return vim.fs.normalize(path)
end

local function message(text, level)
  vim.notify(text, level or vim.log.levels.INFO, { title = 'Open reference' })
end

local function jump(item)
  vim.api.nvim_cmd({ cmd = 'edit', args = { item.filename } }, {})
  if item.lnum then
    local line = math.min(item.lnum, vim.api.nvim_buf_line_count(0))
    local contents = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ''
    vim.api.nvim_win_set_cursor(0, { line, math.min((item.col or 1) - 1, #contents) })
    vim.cmd('normal! zvzz')
  end
end

local function choose(items, title, callback)
  if #items == 0 then return message('No matches: ' .. title, vim.log.levels.WARN) end
  if #items == 1 then return callback(items[1]) end
  local ok, pickers = pcall(require, 'telescope.pickers')
  if not ok then
    return vim.ui.select(items, { prompt = title, format_item = function(item) return item.label end },
      function(item) if item then callback(item) end end)
  end
  local conf = require('telescope.config').values
  pickers.new({}, {
    prompt_title = title,
    finder = require('telescope.finders').new_table {
      results = items,
      entry_maker = function(item)
        return { value = item, display = item.label, ordinal = item.label,
          filename = item.filename, lnum = item.lnum or 1, col = item.col or 1 }
      end,
    },
    sorter = conf.generic_sorter({}),
    previewer = conf.qflist_previewer({}),
    attach_mappings = function(buffer)
      require('telescope.actions').select_default:replace(function()
        local entry = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(buffer)
        if entry then callback(entry.value) end
      end)
      return true
    end,
  }):find()
end

local function run(args, root, callback)
  if vim.fn.executable('rg') == 0 then return callback(nil, 'ripgrep is not available on PATH.') end
  vim.system(args, { cwd = root, text = true, timeout = 15000 }, function(result)
    vim.schedule(function()
      if result.code ~= 0 and result.code ~= 1 then
        local err = vim.trim(result.stderr or '')
        return callback(nil, err ~= '' and err or 'Search failed or timed out.')
      end
      callback(result.stdout or '')
    end)
  end)
end

local exclusions = { '!**/.git/**', '!**/node_modules/**', '!**/.venv/**', '!**/venv/**',
  '!**/__pycache__/**', '!**/dist/**', '!**/build/**' }
local function exclude(args)
  for _, pattern in ipairs(exclusions) do args[#args + 1] = '-g'; args[#args + 1] = pattern end
  return args
end

function M.find_files(value, root, callback)
  local name = value:gsub('\\', '/'):match('([^/]+)$') or value
  -- Quote glob metacharacters so the reference remains a literal filename.
  name = name:gsub('([*?%[%]{}\\])', '\\%1')
  local args = exclude({ 'rg', '--files', '--hidden', '-g', '**/' .. name })
  run(args, root, function(output, err)
    if err then return callback(nil, err) end
    local items = {}
    local suffix = value:gsub('\\', '/'):gsub('^%./', ''):lower()
    for relative in output:gmatch('[^\r\n]+') do
      local normalized = relative:gsub('\\', '/'):lower()
      if normalized == suffix or normalized:sub(-#suffix - 1) == '/' .. suffix then
        items[#items + 1] = { filename = absolute(relative, root), label = relative }
      end
    end
    callback(items)
  end)
end

function M.find_text(query, root, path, callback)
  query = query:gsub('%(%)$', '')
  if query:match('^[%w_.$:]+$') then query = query:match('([%w_$]+)$') or query end
  local args = exclude({ 'rg', '--json', '--fixed-strings', '--hidden', '--max-count', '30' })
  args[#args + 1] = '--'; args[#args + 1] = query
  if path then args[#args + 1] = path end
  run(args, root, function(output, err)
    if err then return callback(nil, err) end
    local items = {}
    for line in output:gmatch('[^\r\n]+') do
      local ok, result = pcall(vim.json.decode, line)
      if ok and result.type == 'match' and result.data.path.text then
        local data = result.data
        local filename = absolute(data.path.text, root)
        local snippet = vim.trim(data.lines.text or '')
        items[#items + 1] = { filename = filename, lnum = data.line_number,
          col = (data.submatches[1] and data.submatches[1].start or 0) + 1,
          label = data.path.text .. ':' .. data.line_number .. '  ' .. snippet }
        if #items >= 300 then break end
      end
    end
    callback(items)
  end)
end

function M.symbol_items(symbols, query, filename, encoding)
  local items = {}
  query = query:gsub('::', '.'):gsub('%(%)$', '')
  local function visit(nodes, parent)
    for _, symbol in ipairs(nodes or {}) do
      local qualified = parent ~= '' and (parent .. '.' .. symbol.name) or symbol.name
      local name = query:find('%.') and qualified or symbol.name
      if name == query or (query:find('%.') and name:sub(-#query - 1) == '.' .. query) then
        local location = symbol.location or { uri = vim.uri_from_fname(filename),
          range = symbol.selectionRange or symbol.range }
        if location.range then
          local item = vim.lsp.util.locations_to_items({ location }, encoding)[1]
          item.label = qualified .. '  ' .. item.filename .. ':' .. item.lnum
          items[#items + 1] = item
        end
      end
      visit(symbol.children, qualified)
    end
  end
  visit(symbols, '')
  return items
end

local function find_symbol(symbol, filename, root)
  local buffer = vim.api.nvim_get_current_buf()
  local finished, requested = false, false
  local function fallback()
    if finished then return end
    finished = true
    if vim.api.nvim_get_current_buf() ~= buffer then return end
    M.find_text(symbol, root, filename, function(items, err)
      if err then return message(err, vim.log.levels.ERROR) end
      choose(items, 'Text matches: ' .. symbol, jump)
    end)
  end
  local function request()
    if requested or finished or not vim.api.nvim_buf_is_valid(buffer) then return end
    local clients = vim.lsp.get_clients({ bufnr = buffer, method = 'textDocument/documentSymbol' })
    if #clients == 0 then return end
    requested = true
    vim.lsp.buf_request_all(buffer, 'textDocument/documentSymbol', { textDocument = { uri = vim.uri_from_bufnr(buffer) } },
      function(responses)
        if finished then return end
        local items, seen = {}, {}
        for id, response in pairs(responses) do
          local client = vim.lsp.get_client_by_id(id)
          for _, item in ipairs(M.symbol_items(response.result or {}, symbol, filename,
            client and client.offset_encoding or 'utf-16')) do
            local key = item.filename .. ':' .. item.lnum .. ':' .. item.col
            if not seen[key] then items[#items + 1] = item; seen[key] = true end
          end
        end
        if #items == 0 then return fallback() end
        finished = true
        if vim.api.nvim_get_current_buf() == buffer then choose(items, 'Function: ' .. symbol, jump) end
      end)
  end
  local event = vim.api.nvim_create_autocmd('LspAttach', { buffer = buffer, callback = request })
  request()
  local supported = { python=true, javascript=true, javascriptreact=true, typescript=true, typescriptreact=true }
  if not requested and not supported[vim.bo[buffer].filetype] then fallback() end
  vim.defer_fn(function() pcall(vim.api.nvim_del_autocmd, event); fallback() end, 2500)
end

-- Resolve references without displaying buffers or pickers. A headless
-- process uses this exact resolver before WezTerm changes the pane layout.
function M.resolve(text, cwd, callback)
  local ref = M.parse(text)
  cwd = absolute(cwd or vim.fn.getcwd(), vim.fn.getcwd())
  assert(vim.fn.isdirectory(cwd) == 1, 'Project directory does not exist: ' .. cwd)
  local root = vim.fs.root(cwd, '.git') or cwd
  local function finish(kind, items)
    callback({ kind = kind, items = items, root = root, ref = ref })
  end
  local function files_ready(items)
    if not ref.symbol then return finish('files', items) end
    -- An existing file alone is insufficient for file#missing_function.
    -- Confirm a literal match before starting the interactive editor/LSP.
    local matches, index = {}, 0
    local function next_file()
      index = index + 1
      local item = items[index]
      if not item then return finish('files', matches) end
      local stat = uv.fs_stat(item.filename)
      if not stat or stat.type ~= 'file' then return next_file() end
      M.find_text(ref.symbol, root, item.filename, function(found, err)
        if err then return callback(nil, err) end
        if #found > 0 then matches[#matches + 1] = item end
        next_file()
      end)
    end
    next_file()
  end
  for _, base in ipairs({ cwd, root }) do
    local path = absolute(ref.value, base)
    if uv.fs_stat(path) then return files_ready({ { filename = path, label = path } }) end
  end
  M.find_files(ref.value, root, function(items, err)
    if err then return callback(nil, err) end
    if #items > 0 then return files_ready(items) end
    if ref.is_path then return finish('files', {}) end
    M.find_text(ref.value, root, nil, function(matches, search_err)
      if search_err then return callback(nil, search_err) end
      finish('text', matches)
    end)
  end)
end

function M.present(resolved)
  vim.api.nvim_set_current_dir(resolved.root)
  -- A file can be removed between the probe and the editor opening it.
  local items = vim.tbl_filter(function(item) return uv.fs_stat(item.filename) ~= nil end, resolved.items)
  if #items == 0 then return message('No matches found for: ' .. resolved.ref.value, vim.log.levels.WARN) end
  if resolved.kind == 'text' then
    return choose(items, 'Text matches in ' .. resolved.root .. ': ' .. resolved.ref.value, jump)
  end
  choose(items, 'Files in ' .. resolved.root, function(item)
    item.lnum, item.col = resolved.ref.line, resolved.ref.col
    jump(item)
    if resolved.ref.symbol then find_symbol(resolved.ref.symbol, item.filename, resolved.root) end
  end)
end

function M.open(text, cwd)
  M.resolve(text, cwd, function(resolved, err)
    if err then return message(err, vim.log.levels.ERROR) end
    M.present(resolved)
  end)
end

function M.from_env()
  local payload = vim.env.NVIM_OPEN_REFERENCE
  vim.env.NVIM_OPEN_REFERENCE = nil
  if not payload then return end
  local ok, err = pcall(function()
    local request = vim.json.decode(payload)
    if request.resolved_file then
      local file = assert(io.open(request.resolved_file, 'rb'))
      local result = file:read('*a'); file:close()
      os.remove(request.resolved_file)
      local resolved = vim.json.decode(result)
      assert(resolved.ok and resolved.resolved, resolved.error or 'Reference lookup failed.')
      M.present(resolved.resolved)
    else
      M.open(request.text, request.cwd)
    end
  end)
  if not ok then message(tostring(err), vim.log.levels.ERROR) end
end

return M
