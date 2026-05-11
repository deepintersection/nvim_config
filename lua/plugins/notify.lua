-- =============================================================================
--  plugins/ui/notify.lua
--  nvim-notify  — replaces vim.notify with a floating notification system
--  noice.nvim   — replaces cmdline, messages, and popupmenu with styled UI
--
--  Disable noice entirely by setting NVIM_NO_NOICE=1 in your .env / launch
--  script. nvim-notify still works as the notification backend.
-- =============================================================================

local no_noice = vim.env.NVIM_NO_NOICE == "1"

return {
  -- -------------------------------------------------------------------------
  -- nvim-notify: styled floating notifications
  -- -------------------------------------------------------------------------
  {
    "rcarriga/nvim-notify",
    lazy   = false,   -- override vim.notify as early as possible
    priority = 950,   -- after colorscheme (1000), before everything else

    keys = {
      {
        "<leader>un",
        function() require("notify").dismiss({ silent = true, pending = true }) end,
        desc = "Dismiss notifications",
      },
      {
        "<leader>uh",
        "<cmd>Telescope notify<CR>",
        desc = "Notification history",
      },
    },

    opts = {
      render          = "compact",   -- "default" | "minimal" | "simple" | "compact"
      stages          = "fade",      -- "fade" | "slide" | "fade_in_slide_out" | "static"
      timeout         = 3000,
      max_height      = function() return math.floor(vim.o.lines * 0.4) end,
      max_width       = function() return math.floor(vim.o.columns * 0.5) end,
      on_open         = function(win)
        vim.api.nvim_win_set_config(win, { border = "rounded" })
      end,
      -- Cyberpunk colour palette per level
      background_colour = "#0d0d0d",
      icons = {
        ERROR = " ",
        WARN  = " ",
        INFO  = " ",
        DEBUG = "󰃤 ",
        TRACE = "✎ ",
      },
      level = vim.log.levels.INFO,
    },

    config = function(_, opts)
      local notify = require("notify")
      notify.setup(opts)

      -- Neon highlights for notification window borders
      vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = "#ff005f" })
      vim.api.nvim_set_hl(0, "NotifyWARNBorder",  { fg = "#ffaf00" })
      vim.api.nvim_set_hl(0, "NotifyINFOBorder",  { fg = "#00ffff" })
      vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { fg = "#444444" })
      vim.api.nvim_set_hl(0, "NotifyERRORTitle",  { fg = "#ff005f", bold = true })
      vim.api.nvim_set_hl(0, "NotifyWARNTitle",   { fg = "#ffaf00", bold = true })
      vim.api.nvim_set_hl(0, "NotifyINFOTitle",   { fg = "#00ffff", bold = true })

      -- Override vim.notify globally (noice will re-override if loaded)
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level, opts2)
        notify(msg, level, opts2)
      end
    end,
  },

  -- -------------------------------------------------------------------------
  -- noice.nvim: styled cmdline + messages + popup menu
  -- Skipped if NVIM_NO_NOICE=1
  -- -------------------------------------------------------------------------
  {
    "folke/noice.nvim",
    enabled      = not no_noice,
    event        = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },

    keys = {
      {
        "<leader>uN",
        "<cmd>NoiceAll<CR>",
        desc = "Noice message history",
      },
      {
        "<C-f>",
        function() if not require("noice.lsp").scroll(4)  then return "<C-f>" end end,
        silent = true, expr = true, desc = "Scroll forward in LSP doc",
        mode = { "i", "n", "s" },
      },
      {
        "<C-b>",
        function() if not require("noice.lsp").scroll(-4) then return "<C-b>" end end,
        silent = true, expr = true, desc = "Scroll back in LSP doc",
        mode = { "i", "n", "s" },
      },
    },

    opts = {
      lsp = {
        -- Override LSP progress/docs handlers
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"]                = true,
          ["cmp.entry.get_documentation"]                  = true,
        },
        progress = {
          enabled = true,
          format  = "lsp_progress",
          format_done = "lsp_progress_done",
          throttle    = 1000 / 30,
          view        = "mini",
        },
        hover         = { enabled = true },
        signature     = { enabled = true, auto_open = { enabled = true } },
        message       = { enabled = true, view = "notify" },
        documentation = { view = "hover" },
      },

      cmdline = {
        enabled  = true,
        view     = "cmdline_popup",
        format   = {
          cmdline  = { pattern = "^:",    icon = "  ", lang = "vim" },
          search_down = { kind = "search", pattern = "^/",  icon = " ", lang = "regex" },
          search_up   = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
          filter   = { pattern = "^:%s*!",  icon = " ", lang = "bash" },
          lua      = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*" }, icon = "󰢱 ", lang = "lua" },
          help     = { pattern = "^:%s*he?l?p?%s+", icon = "󰋗 " },
        },
      },

      messages    = { enabled = true, view = "notify", view_error = "notify", view_warn = "notify" },
      popupmenu   = { enabled = true, backend = "nui" },
      notify      = { enabled = true, view = "notify" },

      views = {
        cmdline_popup = {
          border   = { style = "rounded", padding = { 0, 1 } },
          position = { row = "90%", col = "50%" },
          size     = { width = 60, height = "auto" },
          win_options = {
            winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
          },
        },
        mini = {
          win_options = { winblend = 0 },
          position    = { row = -2, col = "100%" },
          size        = { width = "auto", height = "auto" },
        },
      },

      routes = {
        -- Route long messages to a split rather than notify
        {
          filter = { event = "msg_show", min_height = 5 },
          view   = "split",
        },
        -- Suppress recording noise from macro_component in statusline
        {
          filter = { event = "msg_show", find = "^/" },
          skip   = true,
        },
        -- Suppress "written" messages
        {
          filter = { event = "msg_show", kind = "", find = "written" },
          opts   = { skip = true },
        },
      },

      presets = {
        bottom_search         = false,  -- we use cmdline_popup for search too
        command_palette       = true,
        long_message_to_split = true,
        inc_rename            = false,  -- enable when inc-rename plugin is added
        lsp_doc_border        = true,
      },
    },
  },
}
