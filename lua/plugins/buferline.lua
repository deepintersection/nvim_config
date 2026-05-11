-- =============================================================================
--  plugins/ui/bufferline.lua — akinsho/bufferline.nvim
--  Shows open buffers as tabs at the top. Cyberpunk separators + neon colours.
-- =============================================================================
return {
  {
    "akinsho/bufferline.nvim",
    lazy         = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- Load after colorscheme so highlights are applied correctly
    -- (colorscheme has priority=1000, so default priority here is fine)

    keys = {
      { "<leader>bp",  "<cmd>BufferLinePick<CR>",         desc = "Pick buffer" },
      { "<leader>bP",  "<cmd>BufferLinePickClose<CR>",    desc = "Pick buffer to close" },
      { "<leader>b[",  "<cmd>BufferLineMovePrev<CR>",     desc = "Move buffer left" },
      { "<leader>b]",  "<cmd>BufferLineMoveNext<CR>",     desc = "Move buffer right" },
      { "<leader>bse", "<cmd>BufferLineSortByExtension<CR>", desc = "Sort by extension" },
      { "<leader>bsd", "<cmd>BufferLineSortByDirectory<CR>", desc = "Sort by directory" },
      -- Navigate buffers by index
      { "<leader>1",   "<cmd>BufferLineGoToBuffer 1<CR>", desc = "Buffer 1" },
      { "<leader>2",   "<cmd>BufferLineGoToBuffer 2<CR>", desc = "Buffer 2" },
      { "<leader>3",   "<cmd>BufferLineGoToBuffer 3<CR>", desc = "Buffer 3" },
      { "<leader>4",   "<cmd>BufferLineGoToBuffer 4<CR>", desc = "Buffer 4" },
      { "<leader>5",   "<cmd>BufferLineGoToBuffer 5<CR>", desc = "Buffer 5" },
    },

    opts = function()
      -- Pull colours from the active colorscheme's palette so we stay
      -- consistent regardless of theme switch
      local c = {
        bg          = "#0d0d0d",
        bg_active   = "#1a1a2e",
        bg_inactive = "#0d0d0d",
        fg_active   = "#ffffff",
        fg_inactive = "#404040",
        neon_cyan   = "#00ffff",
        neon_magenta= "#bd00ff",
        neon_green  = "#00ff87",
        red         = "#ff005f",
        separator   = "#1a1a2e",
      }

      return {
        options = {
          mode              = "buffers",
          style_preset      = require("bufferline").style_preset.no_italic,
          themable          = true,
          numbers           = "ordinal",     -- show ordinal number in buffer tab
          close_command     = function(n) require("bufferline").unpin_and_close(n) end,
          right_mouse_command = "bdelete! %d",
          left_mouse_command  = "buffer %d",
          indicator = {
            icon  = "▎",                    -- neon left-edge bar
            style = "icon",
          },
          buffer_close_icon         = "󰅖",
          modified_icon             = "●",
          close_icon                = "",
          left_trunc_marker         = "",
          right_trunc_marker        = "",
          max_name_length           = 30,
          max_prefix_length         = 15,
          truncate_names            = true,
          tab_size                  = 20,
          diagnostics               = "nvim_lsp",
          diagnostics_update_in_insert = false,
          diagnostics_indicator = function(count, level)
            local icons = { error = " ", warning = " ", info = " " }
            return (icons[level] or "") .. count
          end,
          -- Groups will be added in the LSP step (test files, etc.)
          offsets = {
            {
              filetype   = "neo-tree",
              text       = "  File Explorer",
              text_align = "center",
              separator  = true,
            },
          },
          color_icons  = true,
          show_buffer_icons        = true,
          show_buffer_close_icons  = true,
          show_close_icon          = false,
          show_tab_indicators      = true,
          show_duplicate_prefix    = true,
          persist_buffer_sort      = true,
          move_wraps_at_ends       = true,
          separator_style          = "thin",  -- "slant" | "slope" | "thin" | "thick"
          enforce_regular_tabs     = false,
          always_show_bufferline   = true,
          hover = {
            enabled = true,
            delay   = 150,
            reveal  = { "close" },
          },
          sort_by = "insert_after_current",
        },

        highlights = {
          -- Background of the whole tabline
          fill = {
            bg = c.bg,
          },
          background = {
            fg = c.fg_inactive,
            bg = c.bg_inactive,
          },
          -- Active buffer
          buffer_selected = {
            fg   = c.neon_cyan,
            bg   = c.bg_active,
            bold = true,
          },
          indicator_selected = {
            fg = c.neon_magenta,
            bg = c.bg_active,
          },
          -- Modified indicator
          modified = {
            fg = c.neon_green,
            bg = c.bg_inactive,
          },
          modified_selected = {
            fg = c.neon_green,
            bg = c.bg_active,
          },
          -- Diagnostics in tabs
          error = {
            fg = c.red,
            bg = c.bg_inactive,
          },
          error_selected = {
            fg = c.red,
            bg = c.bg_active,
            bold = true,
          },
          -- Separators
          separator = {
            fg = c.separator,
            bg = c.bg_inactive,
          },
          separator_selected = {
            fg = c.separator,
            bg = c.bg_active,
          },
          -- Tab numbers (ordinal)
          numbers = {
            fg = c.fg_inactive,
            bg = c.bg_inactive,
          },
          numbers_selected = {
            fg = c.neon_magenta,
            bg = c.bg_active,
            bold = true,
          },
          -- Close icons
          close_button = {
            fg = c.fg_inactive,
            bg = c.bg_inactive,
          },
          close_button_selected = {
            fg = c.red,
            bg = c.bg_active,
          },
        },
      }
    end,
  },
}
