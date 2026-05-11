-- =============================================================================
--  plugins/ui/indent.lua — lukas-reineke/indent-blankline.nvim  (ibl v3)
--  Cyberpunk: dim neon cyan guides, brighter scope highlight
-- =============================================================================
return {
  {
    "lukas-reineke/indent-blankline.nvim",
    main  = "ibl",    -- v3 API entry point
    event = { "BufReadPost", "BufNewFile" },

    keys = {
      {
        "<leader>ui",
        function()
          local ibl = require("ibl")
          -- Toggle indent guides
          vim.g.ibl_enabled = not vim.g.ibl_enabled
          ibl.update({ enabled = vim.g.ibl_enabled })
          notify("Indent guides " .. (vim.g.ibl_enabled and "on" or "off"))
        end,
        desc = "Toggle indent guides",
      },
    },

    config = function()
      -- Neon highlight colours for guide lines
      vim.api.nvim_set_hl(0, "IblIndent",     { fg = "#1e1e3a", nocombine = true })
      vim.api.nvim_set_hl(0, "IblScope",      { fg = "#00ffff", nocombine = true })
      vim.api.nvim_set_hl(0, "IblWhitespace", { fg = "#1a1a2e", nocombine = true })

      -- Rainbow indent colours (used when rainbow is enabled below)
      local rainbow = {
        "#1e1e3a",  -- lvl 1 — barely visible
        "#16213e",  -- lvl 2
        "#0f3460",  -- lvl 3
        "#1a1a4e",  -- lvl 4
        "#1e1e5a",  -- lvl 5
        "#202060",  -- lvl 6
      }
      for i, color in ipairs(rainbow) do
        vim.api.nvim_set_hl(0, "IblRainbow" .. i, { fg = color, nocombine = true })
      end

      vim.g.ibl_enabled = true

      require("ibl").setup({
        enabled = true,

        indent = {
          char      = "│",         -- thin vertical bar
          tab_char  = "│",
          highlight = "IblIndent",
          smart_indent_cap = true,
          priority  = 1,
        },

        whitespace = {
          highlight   = "IblWhitespace",
          remove_blankline_trail = true,
        },

        scope = {
          enabled    = true,
          char       = "│",
          highlight  = "IblScope",
          show_start = true,
          show_end   = false,
          -- Treesitter scope detection (wired in once TS is loaded)
          injected_languages = false,
          include = {
            node_type = {
              -- Language-agnostic scope nodes
              ["*"] = {
                "class",
                "function",
                "method",
                "block",
                "if_statement",
                "for_statement",
                "while_statement",
                "with_statement",
                "try_statement",
                "except_clause",
              },
            },
          },
        },

        exclude = {
          filetypes = {
            "help", "alpha", "dashboard", "neo-tree", "Trouble",
            "trouble", "lazy", "mason", "notify", "toggleterm",
            "lazyterm", "lspinfo", "man", "checkhealth",
          },
          buftypes = {
            "terminal", "nofile", "quickfix", "prompt",
          },
        },
      })
    end,
  },
}
