-- Open init.lua directly

vim.api.nvim_create_user_command('EditConfig', function()
  vim.cmd('edit ' .. vim.fn.stdpath('config') )
end, {})

-- Change Disk to D

vim.api.nvim_create_user_command('Cdd', function()
	target_dir = 'D:\\'
  vim.cmd('edit ' .. target_dir )
  print("Switched to D:")
end, {})

vim.cmd([[cnoreabbrev cdd Cdd]])


-- Automatically save the current working directory to a temp file before exiting Neovim
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        local cwd = vim.fn.getcwd() -- Get current working directory
        local temp_file = os.getenv("TEMP") .. "\\nvim_cwd.txt" -- Temp file path for Windows
        local file = io.open(temp_file, "w") -- Open the file in write mode
        if file then
            file:write(cwd)
            file:close()
        end
    end,
})

