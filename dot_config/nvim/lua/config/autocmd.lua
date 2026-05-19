-- lua/config/autocmds.lua

-- Tell the terminal multiplexer to sync with Neovim's directory
vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
  callback = function()
    local cwd = vim.fn.expand("%:p:h")
    cwd = cwd:gsub("\\", "/") 
    if cwd ~= "" and vim.fn.isdirectory(cwd) == 1 then
      io.stdout:write(string.format("\x1b]7;file://%s%s\x1b\\", vim.fn.hostname(), cwd))
    end
  end,
})
