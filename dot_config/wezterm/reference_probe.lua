-- Runs with `nvim --headless -u NONE -i NONE -n -l ...`; never opens a UI.
local input_path, output_path, resolver_path = arg[1], arg[2], arg[3]
local finished = false
local function finish(result)
  if finished then return end
  finished = true
  local file = assert(io.open(output_path .. '.tmp', 'wb'))
  assert(file:write(vim.json.encode(result)))
  assert(file:close())
  assert(os.rename(output_path .. '.tmp', output_path))
  vim.cmd('qa!')
end
local ok, err = pcall(function()
  local file = assert(io.open(input_path, 'rb'))
  local content = file:read('*a'); file:close()
  local request = vim.json.decode(content)
  dofile(resolver_path).resolve(request.text, request.cwd, function(resolved, lookup_error)
    if lookup_error then finish({ ok = false, error = lookup_error })
    else finish({ ok = true, resolved = resolved }) end
  end)
end)
if not ok then finish({ ok = false, error = tostring(err) }) end
vim.defer_fn(function() finish({ ok = false, error = 'Reference search timed out.' }) end, 20000)
vim.wait(21000, function() return finished end, 10)
