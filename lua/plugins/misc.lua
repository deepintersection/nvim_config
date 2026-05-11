-- =============================================================================
--  plugins/ui/misc.lua — small UI utilities that don't need their own file
--
--  • vim-illuminate  — highlight other uses of the word under cursor
--  • nvim-colorizer  — inline colour previews (#hex, rgb(), etc.)
--  • which-key.nvim  — popup showing available keymaps mid-sequence
-- =============================================================================
return {
  -- -------------------------------------------------------------------------
  -- which-key: keymap discovery (essential for a config this large)
  -- -------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts  = {
      preset  = "modern",   -- "classic" | "modern" | "helix"
      delay   = 400,        -- ms before popup appears
      icons   = {
        breadcrumb = "»",
        separator  = "➜",
        group      = "+",
      },
      win = {
        border  = "rounded",
        padding = { 1, 2 },
        wo      = { winblend = 0 },
      },
      layout = {
        spacing = 3,
        align   = "left",
      },
      -- Describe keymap namespaces so the popup is readable
      spec = {
        { "<leader>b",  group = "buffers" },
        { "<leader>d",  group = "debug/diagnostics" },
        { "<leader>f",  group = "find (telescope)" },
        { "<leader>g",  group = "git" },
        { "<leader>l",  group = "lsp" },
        { "<leader>o",  group = "open" },
        { "<leader>p",  group = "plugins" },
        { "<leader>q",  group = "quit/quickfix" },
        { "<leader>s",  group = "search/replace" },
        { "<leader>t",  group = "terminal" },
        { "<leader>u",  group = "ui toggles" },
        { "<leader>x",  group = "trouble/lists" },
        { "<localleader>",    group = "local" },
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- vim-illuminate: highlight word under cursor across the buffer
  -- -------------------------------------------------------------------------
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      providers    = { "lsp", "treesitter", "regex" },
      delay        = 200,
      large_file_cutoff = 2000,
      large_file_overrides = {
        providers = { "regex" },
      },
      filetypes_denylist = {
        "alpha", "neo-tree", "Trouble", "lazy", "mason",
      },
    },
    config = function(_, opts)
      require("illuminate").configure(opts)
      -- Neon-tinted underline for illuminated words
      vim.api.nvim_set_hl(0, "IlluminatedWordText",  { underline = true })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead",  { bg = "#1a1a3a" })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = "#2a0a2a" })
    end,
    keys = {
      {
        "]]",
        function() require("illuminate").goto_next_reference(false) end,
        desc = "Next reference",
      },
      {
        "[[",
        function() require("illuminate").goto_prev_reference(false) end,
        desc = "Prev reference",
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- nvim-colorizer: show hex/rgb colours inline in the buffer
  -- Especially handy when editing this very config file
  -- -------------------------------------------------------------------------
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      filetypes = {
        "*",
        "!alpha", "!lazy", "!mason",
      },
      user_default_options = {
        RGB         = true,   -- #RGB
        RRGGBB      = true,   -- #RRGGBB
        names       = false,  -- CSS colour names (can be noisy)
        RRGGBBAA    = true,   -- #RRGGBBAA
        AARRGGBB    = false,
        rgb_fn      = true,   -- rgb() and rgba()
        hsl_fn      = true,   -- hsl() and hsla()
        mode        = "virtualtext",   -- "background" | "foreground" | "virtualtext"
        virtualtext = "■",
      },
    },
  },
}
