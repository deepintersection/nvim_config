-- lua/config/treesitter.lua

vim.api.nvim_create_autocmd("FileType", {
  desc = "Enable native treesitter highlighting",

  callback = function(ev)
    local ok = pcall(vim.treesitter.start, ev.buf)

    if ok then
      vim.bo[ev.buf].syntax = "off"
    end
  end,
})
