-- =============================================================================
--  plugins/ui/colorscheme.lua
--  Primary: cyberdream (cyberpunk-native palette)
--  Fallback: tokyonight-storm (loaded but not applied)
--
--  Toggle dark/light:  <leader>ut
--  Switch theme:       :Colorscheme <name>
-- =============================================================================

-- Shared highlight overrides applied on top of any theme.
-- Keeps the neon-on-dark feel consistent regardless of which theme is active.
local function apply_cyberpunk_overrides()
  local hl = vim.api.nvim_set_hl
  -- Make active window border pop with neon cyan
  hl(0, "WinSeparator",    { fg = "#00ffff", bg = "NONE" })
  -- Floating window borders
  hl(0, "FloatBorder",     { fg = "#bd00ff", bg = "NONE" })
  -- Current search result — hot pink
  hl(0, "CurSearch",       { fg = "#000000", bg = "#ff007c" })
  -- Colour column — subtle neon line
  hl(0, "ColorColumn",     { bg = "#1a1a2e" })
end

return {
  -- -------------------------------------------------------------------------
  -- Primary: cyberdream
  -- -------------------------------------------------------------------------
  {
    "scottmckendry/cyberdream.nvim",
    lazy    = false,   -- must load at startup
    priority = 1000,   -- before any other plugin that touches colours
    opts = {
      transparent      = false,
      italic_comments  = true,
      hide_fillchars   = true,   -- cleaner splits
      borderless_telescope = false,
      terminal_colors  = true,
      theme = {
        variant = "default",   -- "default" (dark) | "light"
        overrides = function(c)
          -- c exposes the full palette; tweak individual groups here
          return {
            -- Stronger contrast on line numbers
            LineNr         = { fg = c.cyan,    bg = "NONE" },
            CursorLineNr   = { fg = c.magenta, bg = "NONE", bold = true },
            -- Git signs use neon palette
            GitSignsAdd    = { fg = c.green },
            GitSignsChange = { fg = c.yellow },
            GitSignsDelete = { fg = c.red },
          }
        end,
      },
    },
    config = function(_, opts)
      require("cyberdream").setup(opts)
      vim.cmd.colorscheme("cyberdream")
      apply_cyberpunk_overrides()
    end,
  },

  -- -------------------------------------------------------------------------
  -- Fallback / alternative: tokyonight (storm variant)
  -- Not set as active — switch with :colorscheme tokyonight-storm
  -- -------------------------------------------------------------------------
  {
    "folke/tokyonight.nvim",
    lazy     = true,
    priority = 900,
    opts = {
      style          = "storm",
      transparent    = false,
      terminal_colors = true,
      styles = {
        comments   = { italic = true },
        keywords   = { italic = true },
        functions  = {},
        variables  = {},
        sidebars   = "dark",
        floats     = "dark",
      },
      on_highlights = function(hl, c)
        hl.WinSeparator = { fg = c.blue5 }
        hl.FloatBorder  = { fg = c.magenta }
      end,
    },
  },

  -- -------------------------------------------------------------------------
  -- Icons (required by many UI plugins)
  -- -------------------------------------------------------------------------
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,   -- loaded on demand by dependents
    opts = {
      -- Cyberpunk: override a few default icons with neon versions
      override_by_extension = {
        ["py"]  = { icon = "󰌠", color = "#00d7ff", name = "Python" },
        ["rs"]  = { icon = "󱘗", color = "#ff5f00", name = "Rust" },
        ["lua"] = { icon = "󰢱", color = "#bd00ff", name = "Lua" },
        ["sql"] = { icon = "󰆼", color = "#00ffaf", name = "SQL" },
        ["toml"]= { icon = "", color = "#ff8700", name = "Toml" },
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- UI toggle keymap (dark ↔ light)  — <leader>ut
  -- -------------------------------------------------------------------------
  {
    "scottmckendry/cyberdream.nvim",   -- already defined above; this spec
    -- merges into it via lazy deduplication
    keys = {
      {
        "<leader>ut",
        function()
          local cd = require("cyberdream")
          -- Flip the variant and re-apply
          local current = vim.g.cyberdream_variant or "default"
          local next_v = current == "default" and "light" or "default"
          vim.g.cyberdream_variant = next_v
          cd.setup({ theme = { variant = next_v } })
          vim.cmd.colorscheme("cyberdream")
          apply_cyberpunk_overrides()
          notify("Cyberdream: " .. next_v)
        end,
        desc = "Toggle dark/light theme",
      },
    },
  },
}
